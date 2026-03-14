#!/bin/bash
# ================================================
# 📬 Telegram 雙向指令監聽器
# Cron 每分鐘執行一次
# 接收主人指令 → 寫入 INBOX.md → 巡檢員下次處理
# ================================================

export PATH="$HOME/.openclaw/bin:$HOME/.nvm/versions/node/v22.22.0/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

ENV_FILE="$(dirname "$0")/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INBOX="$REPO_DIR/INBOX.md"
OFFSET_FILE="$REPO_DIR/logs/.tg_offset"
LOG_FILE="$REPO_DIR/logs/telegram-listener.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

mkdir -p "$REPO_DIR/logs"

# --- 讀取上次的 offset（避免重複處理舊訊息）---
OFFSET=0
[ -f "$OFFSET_FILE" ] && OFFSET=$(cat "$OFFSET_FILE")

# --- 取得新訊息 ---
RESPONSE=$(curl -s "https://api.telegram.org/bot${TG_BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=5&allowed_updates=message")

# --- 確認 API 回應正常 ---
OK=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok','false'))" 2>/dev/null)
[ "$OK" != "True" ] && exit 0

# --- 取得訊息數量 ---
COUNT=$(echo "$RESPONSE" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('result',[])))" 2>/dev/null)
[ "$COUNT" = "0" ] && exit 0

# --- 逐筆處理訊息 ---
NEW_MESSAGES=""
NEW_OFFSET=$OFFSET

echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for update in data.get('result', []):
    uid = update.get('update_id', 0)
    msg = update.get('message', {})
    chat_id = str(msg.get('chat', {}).get('id', ''))
    text = msg.get('text', '').strip()
    date = msg.get('date', 0)

    # 只接受授權的 chat ID
    if chat_id != '${TG_CHAT_ID}':
        print(f'SKIP:{uid}')
        continue

    if text:
        from datetime import datetime, timezone
        dt = datetime.fromtimestamp(date, tz=timezone.utc).strftime('%Y-%m-%d %H:%M')
        print(f'MSG:{uid}:{dt}:{text}')
    else:
        print(f'SKIP:{uid}')
" | while IFS= read -r line; do
    TYPE="${line%%:*}"
    REST="${line#*:}"
    UID_VAL="${REST%%:*}"
    REST2="${REST#*:}"

    NEW_OFFSET=$((UID_VAL + 1))
    echo "$NEW_OFFSET" > "$OFFSET_FILE"

    if [ "$TYPE" = "MSG" ]; then
        DT="${REST2%%:*}"
        TEXT="${REST2#*:}"

        echo "[$TIMESTAMP] 收到指令：$TEXT" >> "$LOG_FILE"

        # --- 寫入 INBOX.md ---
        # 如果是初始狀態，先清空
        if grep -q "目前無待處理指令" "$INBOX" 2>/dev/null; then
            cat > "$INBOX" << INBOXEOF
# INBOX.md — 主人指令收件匣

> 由 telegram-listener.sh 寫入，巡檢員每次巡檢開頭優先處理，處理後清空。

---
INBOXEOF
        fi

        # 追加新指令
        cat >> "$INBOX" << INBOXEOF

## 📩 $DT
$TEXT

INBOXEOF

        # --- 立即回覆確認收到 ---
        curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TG_CHAT_ID}" \
            --data-urlencode "text=📬 已收到你的指令，巡檢員下次醒來（最多 30 分鐘）會處理：

「${TEXT}」

如需立即執行，發送：/now" \
            -d "parse_mode=HTML" > /dev/null 2>&1 || true
    fi
done

# --- 特殊指令：/now 立即觸發巡檢 ---
echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for update in data.get('result', []):
    msg = update.get('message', {})
    chat_id = str(msg.get('chat', {}).get('id', ''))
    text = msg.get('text', '').strip()
    if chat_id == '${TG_CHAT_ID}' and text == '/now':
        print('TRIGGER')
        break
" | grep -q "TRIGGER" && {
    echo "[$TIMESTAMP] /now 指令：立即觸發巡檢" >> "$LOG_FILE"
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        -d "text=⚡ 立即啟動巡檢中..." \
        -d "parse_mode=HTML" > /dev/null 2>&1 || true
    /bin/bash "$REPO_DIR/inspect.sh" &
}
