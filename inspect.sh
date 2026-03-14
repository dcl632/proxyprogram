#!/bin/bash
# ================================================
# 🦞 龍蝦巡檢員啟動腳本 v1.1
# Cron 每 30 分鐘執行一次
# ================================================

# --- Cron 環境：手動補全 PATH ---
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$HOME/.nvm/versions/node/$(node --version 2>/dev/null || echo 'v20')/bin"

set -euo pipefail

# --- 設定 ---
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$REPO_DIR/logs"
LOG_FILE="$LOG_DIR/inspect.log"
LOCK_FILE="$LOG_DIR/inspect.lock"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# --- 確保 logs 資料夾存在 ---
mkdir -p "$LOG_DIR"

# --- 防止重複執行（鎖定機制）---
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

# --- 建立鎖定，結束時自動清除 ---
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# ------------------------------------------------
echo "[$TIMESTAMP] ====== 巡檢開始 ======" >> "$LOG_FILE"

# --- 拉取最新文件 ---
cd "$REPO_DIR"
echo "[$TIMESTAMP] git pull..." >> "$LOG_FILE"
git pull origin main >> "$LOG_FILE" 2>&1 || {
  echo "[$TIMESTAMP] ⚠️ git pull 失敗，使用本地版本繼續" >> "$LOG_FILE"
}

# --- 啟動 Claude Code 執行巡檢 ---
echo "[$TIMESTAMP] 啟動 Claude Code..." >> "$LOG_FILE"

claude --dangerously-skip-permissions -p "
你是龍蝦巡檢員。現在是 $TIMESTAMP，開始例行巡檢。

工作目錄：$REPO_DIR

請依序執行以下流程：

【第一步】讀取 MASTER.md，了解全局狀態、優先級、紅線定義、互動準則。

【第二步】讀取 RED_FLAGS.md，處理待定事項：
- URGENT 項目：立即通知（Telegram），記錄處置動作
- PENDING 項目：整理成摘要，加入本次 CHANGELOG

【第三步】依序巡檢三個營運單位（shiftautomate → techtodaily → daliypluslife）：
每站執行：
  a. 讀取 STATUS.md / TODO.md / DONE.md
  b. 讀取 tasks/completed/ 和 tasks/failed/，處理龍蝦回報
  c. 評估當前狀態，決定本次行動
  d. 將可執行的 TODO 轉換為任務文件，寫入 tasks/pending/
  e. 更新該站的 STATUS.md（更新指標狀態）
  f. 更新 TODO.md（移除已完成項目，新增發現的問題）
  g. 更新 DONE.md（記錄本次完成的事項）
  h. 清理 tasks/completed/ 和 tasks/failed/ 中已處理的文件

【第四步】在 CHANGELOG.md 開頭新增本次巡檢紀錄（格式參考 MASTER.md 第六區）

【第五步】更新 MASTER.md 第三區的狀態快覽表（各站最後巡檢時間和狀態）

【第六步】提交所有變更：
git add .
git commit -m '[巡檢] $TIMESTAMP 摘要（一行）'
git push origin main

開始執行，不需要請示，直接行動。
" >> "$LOG_FILE" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "[$TIMESTAMP] ✅ 巡檢完成" >> "$LOG_FILE"
else
  echo "[$TIMESTAMP] ❌ 巡檢異常，exit code: $EXIT_CODE" >> "$LOG_FILE"
fi

echo "[$TIMESTAMP] ====== 巡檢結束 ======" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
