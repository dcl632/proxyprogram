#!/bin/bash
# ================================================
# 📬 Telegram 長輪詢 Daemon
# 持續運行，訊息秒到秒處理
# 由 launchd 管理（開機自動啟動、崩潰自動重啟）
# ================================================

export PATH="$HOME/.openclaw/bin:$HOME/.nvm/versions/node/v22.22.0/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

ENV_FILE="$(dirname "$0")/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INBOX="$REPO_DIR/INBOX.md"
OFFSET_FILE="$REPO_DIR/logs/.tg_offset"
LOG_FILE="$REPO_DIR/logs/telegram-listener.log"

mkdir -p "$REPO_DIR/logs"

telegram_send() {
  local text="$1"
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_CHAT_ID}" \
    --data-urlencode "text=${text}" \
    -d "parse_mode=HTML" > /dev/null 2>&1 || true
}

write_inbox() {
  local dt="$1"
  local text="$2"
  if grep -q "目前無待處理指令" "$INBOX" 2>/dev/null; then
    cat > "$INBOX" <<EOF
# INBOX.md — 主人指令收件匣

> 由 telegram-listener.sh 寫入，巡檢員每次巡檢開頭優先處理，處理後清空。

---
EOF
  fi
  cat >> "$INBOX" <<EOF

## 📩 $dt
$text

EOF
}

# --- 讀取 offset ---
OFFSET=0
[ -f "$OFFSET_FILE" ] && OFFSET=$(cat "$OFFSET_FILE")

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 Telegram daemon 啟動（offset: $OFFSET）" >> "$LOG_FILE"

# ================================================
# 主循環：長輪詢（timeout=30 秒）
# ================================================
while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

  # 長輪詢：最多等 30 秒，有訊息立刻返回
  RESPONSE=$(curl -s --max-time 35 \
    "https://api.telegram.org/bot${TG_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=30&allowed_updates=message" \
    2>/dev/null)

  # 解析失敗就等 5 秒重試
  OK=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok',False))" 2>/dev/null)
  if [ "$OK" != "True" ]; then
    sleep 5
    continue
  fi

  # 逐筆處理
  echo "$RESPONSE" | python3 -c "
import sys, json
from datetime import datetime, timezone

data = json.load(sys.stdin)
for update in data.get('result', []):
    uid = update.get('update_id', 0)
    msg = update.get('message', {})
    chat_id = str(msg.get('chat', {}).get('id', ''))
    text = msg.get('text', '').strip()
    date = msg.get('date', 0)
    dt = datetime.fromtimestamp(date, tz=timezone.utc).strftime('%Y-%m-%d %H:%M')

    if chat_id != '${TG_CHAT_ID}':
        print(f'SKIP\t{uid}')
        continue

    if text:
        # 跳脫特殊字元避免 bash 解析問題
        safe_text = text.replace('\t', ' ')
        print(f'MSG\t{uid}\t{dt}\t{safe_text}')
    else:
        print(f'SKIP\t{uid}')
" 2>/dev/null | while IFS=$'\t' read -r TYPE UID_VAL DT TEXT; do

    # 更新 offset
    NEW_OFFSET=$((UID_VAL + 1))
    echo "$NEW_OFFSET" > "$OFFSET_FILE"
    OFFSET=$NEW_OFFSET

    [ "$TYPE" != "MSG" ] && continue

    echo "[$TIMESTAMP] 📩 收到：$TEXT" >> "$LOG_FILE"

    # --- /now：立即觸發巡檢 ---
    if [ "$TEXT" = "/now" ]; then
      telegram_send "⚡ <b>立即啟動巡檢中...</b>"
      /bin/bash "$REPO_DIR/inspect.sh" >> "$LOG_FILE" 2>&1 &
      continue
    fi

    # --- /status：快速查看狀態 ---
    if [ "$TEXT" = "/status" ]; then
      STATUS_CONTENT=$(grep -A 20 "第三區" "$REPO_DIR/MASTER.md" 2>/dev/null | head -15)
      telegram_send "📊 <b>目前狀態快覽</b>

$STATUS_CONTENT

詳細請查看 GitHub 或等週報。"
      continue
    fi

    # --- 一般指令：寫入 INBOX ---
    write_inbox "$DT" "$TEXT"
    telegram_send "📬 <b>已收到指令</b>

「$TEXT」

巡檢員下次醒來會處理（最多 30 分鐘）。
急用請發 /now 立即觸發。"

  done

  # 更新主循環的 offset
  OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo "$OFFSET")

done
