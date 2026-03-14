#!/bin/bash
# ================================================
# 🦞 龍蝦巡檢員啟動腳本 v1.2
# Cron 每 30 分鐘執行一次
# ================================================

# --- Cron 環境：補全 PATH（與 content-mill 同步）---
export PATH="$HOME/.openclaw/bin:$HOME/.nvm/versions/node/v22.22.0/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

set -euo pipefail

# --- 載入環境變數（Telegram token 等）---
ENV_FILE="$(dirname "$0")/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

# --- 設定 ---
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$REPO_DIR/logs"
LOG_FILE="$LOG_DIR/inspect.log"
LOCK_FILE="$LOG_DIR/inspect.lock"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# --- 確保 logs 資料夾存在 ---
mkdir -p "$LOG_DIR"

# ================================================
# Telegram 通知函式
# ================================================
telegram_notify() {
  local message="$1"
  if [ -n "${TG_BOT_TOKEN:-}" ] && [ -n "${TG_CHAT_ID:-}" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TG_CHAT_ID}" \
      -d "text=${message}" \
      -d "parse_mode=HTML" > /dev/null 2>&1 || true
  fi
}

# ================================================
# 防止重複執行（鎖定機制）
# ================================================
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
  if [ "$LOCK_AGE" -lt 1800 ]; then
    echo "[$TIMESTAMP] 上一次巡檢仍在執行中（鎖定 ${LOCK_AGE}s），跳過本次" >> "$LOG_FILE"
    exit 0
  else
    echo "[$TIMESTAMP] 偵測到殘留鎖定（${LOCK_AGE}s），強制清除" >> "$LOG_FILE"
    rm -f "$LOCK_FILE"
  fi
fi

touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# ================================================
echo "[$TIMESTAMP] ====== 巡檢開始 ======" >> "$LOG_FILE"

# --- 拉取最新文件 ---
cd "$REPO_DIR"
echo "[$TIMESTAMP] git pull..." >> "$LOG_FILE"
git pull origin main >> "$LOG_FILE" 2>&1 || {
  echo "[$TIMESTAMP] ⚠️ git pull 失敗，使用本地版本繼續" >> "$LOG_FILE"
  telegram_notify "⚠️ <b>龍蝦巡檢員</b> git pull 失敗（$TIMESTAMP），使用本地版本繼續"
}

# --- 啟動 Claude Code 執行巡檢 ---
echo "[$TIMESTAMP] 啟動 Claude Code..." >> "$LOG_FILE"

claude --dangerously-skip-permissions -p "
你是龍蝦巡檢員。現在是 $TIMESTAMP，開始例行巡檢。
工作目錄：$REPO_DIR

請依序執行以下流程：

【第一步】讀取 MASTER.md，了解全局狀態、優先級、紅線定義、互動準則。

【第二步】讀取 INBOX.md（主人指令收件匣）：
- 若有未處理指令，優先理解並執行
- 執行完畢後，將 INBOX.md 清空，恢復為：
  「（目前無待處理指令）」
- 若有需要回報結果，透過 Telegram 通知主人

【第三步】讀取 RED_FLAGS.md：
- URGENT 項目：記錄於 CHANGELOG，觸發 Telegram 通知
- PENDING 項目：整理摘要，加入本次 CHANGELOG

【第四步】依序巡檢所有營運單位（shiftautomate → techtodaily → daliypluslife → music-production → yt-pipeline）：
  a. 讀取 STATUS.md / TODO.md / DONE.md
  b. 讀取 tasks/completed/ 和 tasks/failed/，處理龍蝦回報
  c. 決定本次行動，透過 openclaw agent 或 swarm-task.sh 下達指令給龍蝦
  d. 更新 STATUS.md、TODO.md、DONE.md
  e. 清理已處理的 tasks/completed/ 和 tasks/failed/ 文件

【第五步】CHANGELOG.md 開頭新增本次巡檢紀錄

【第六步】更新 MASTER.md 第三區狀態快覽

【第七步】提交所有變更：
  git add .
  git commit -m '[巡檢] $TIMESTAMP 摘要'
  git push origin main

不需要請示，直接行動。紅線內容以 MASTER.md 第五區為準。
" >> "$LOG_FILE" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "[$TIMESTAMP] ✅ 巡檢完成" >> "$LOG_FILE"
else
  echo "[$TIMESTAMP] ❌ 巡檢異常，exit code: $EXIT_CODE" >> "$LOG_FILE"
  telegram_notify "🔴 <b>龍蝦巡檢員異常</b>
時間：$TIMESTAMP
錯誤：exit code $EXIT_CODE
請檢查 logs/inspect.log"
fi

echo "[$TIMESTAMP] ====== 巡檢結束 ======" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
