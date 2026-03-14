#!/bin/bash
# ================================================
# 📊 龍蝦巡檢員 — 週報腳本
# Cron 每週日 21:00 執行
# ================================================

export PATH="$HOME/.openclaw/bin:$HOME/.nvm/versions/node/v22.22.0/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

ENV_FILE="$(dirname "$0")/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$REPO_DIR/logs"
LOG_FILE="$LOG_DIR/weekly-report.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
WEEK=$(date '+%Y-W%V')

mkdir -p "$LOG_DIR"

telegram_notify() {
  local message="$1"
  if [ -n "${TG_BOT_TOKEN:-}" ] && [ -n "${TG_CHAT_ID:-}" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TG_CHAT_ID}" \
      -d "text=${message}" \
      -d "parse_mode=HTML" > /dev/null 2>&1 || true
  fi
}

echo "[$TIMESTAMP] ====== 週報開始（$WEEK）======" >> "$LOG_FILE"

cd "$REPO_DIR"
git pull origin main >> "$LOG_FILE" 2>&1 || true

# ------------------------------------------------
# 啟動 Claude Code 產出週報並推送 Telegram
# ------------------------------------------------
claude --dangerously-skip-permissions -p "
你是龍蝦巡檢員。現在是 $TIMESTAMP，執行每週例行週報。
工作目錄：$REPO_DIR
本週週次：$WEEK

請依序執行：

【第一步】讀取以下文件，整理本週狀況：
- MASTER.md（全局優先級與設備分工）
- CHANGELOG.md（本週巡檢記錄，取最近 7 天）
- 所有單位的 STATUS.md 和 DONE.md
- RED_FLAGS.md（本週異常事件）

【第二步】根據以上資訊，撰寫週報，格式如下：

📊 <b>週報 $WEEK</b>
$TIMESTAMP

<b>【各單位本週狀態】</b>
• shiftautomate：（一行摘要）
• techtodaily：（一行摘要）
• daliypluslife：（一行摘要）
• music-production：（一行摘要）
• yt-pipeline：（一行摘要）

<b>【本週完成事項】</b>
（列出主要完成項目，最多 5 條）

<b>【本週異常與警示】</b>
（若無則填「無」）

<b>【待主人決策事項】</b>
（PENDING 中需要主人拍板的，若無則填「無」）

<b>【下週建議重點】</b>
（根據現況給出 2-3 個建議）

<b>【請回覆指示】</b>
如有調整全局優先級或新指令，請直接回覆此訊息。

【第三步】將以上週報內容透過以下指令發送到 Telegram：
curl -s -X POST \"https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage\" \\
  -d \"chat_id=${TG_CHAT_ID}\" \\
  --data-urlencode \"text=<週報內容>\" \\
  -d \"parse_mode=HTML\"

【第四步】將週報內容存入 archive/weekly-reports/${WEEK}.md

【第五步】git add . && git commit -m '[週報] $WEEK' && git push origin main

不需要請示，直接行動。
" >> "$LOG_FILE" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "[$TIMESTAMP] ✅ 週報完成" >> "$LOG_FILE"
else
  echo "[$TIMESTAMP] ❌ 週報異常，exit code: $EXIT_CODE" >> "$LOG_FILE"
  telegram_notify "🔴 <b>週報腳本異常</b>
時間：$TIMESTAMP
請檢查 logs/weekly-report.log"
fi

echo "[$TIMESTAMP] ====== 週報結束 ======" >> "$LOG_FILE"
