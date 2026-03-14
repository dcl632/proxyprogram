#!/bin/bash
# ================================================
# 🗂️ 龍蝦巡檢員 — 每月歸檔腳本
# Cron 每月 1 日 02:00 執行
# ================================================

export PATH="$HOME/.openclaw/bin:$HOME/.nvm/versions/node/v22.22.0/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

ENV_FILE="$(dirname "$0")/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$REPO_DIR/logs"
LOG_FILE="$LOG_DIR/archive.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# 歸檔到「上個月」的資料夾
LAST_MONTH=$(date -v-1m '+%Y-%m')
ARCHIVE_DIR="$REPO_DIR/archive/$LAST_MONTH"
mkdir -p "$ARCHIVE_DIR"
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

echo "[$TIMESTAMP] ====== 月度歸檔開始（$LAST_MONTH）======" >> "$LOG_FILE"

cd "$REPO_DIR"

# ------------------------------------------------
# 1. 歸檔 CHANGELOG.md（保留最近 14 天）
# ------------------------------------------------
if [ -f "CHANGELOG.md" ]; then
  cp "CHANGELOG.md" "$ARCHIVE_DIR/CHANGELOG.md"
  # 只保留最近 14 天（用 Claude Code 重寫）
  claude --dangerously-skip-permissions -p "
工作目錄：$REPO_DIR
請執行以下操作：
1. 讀取 CHANGELOG.md
2. 只保留最近 14 天（$(date -v-14d '+%Y-%m-%d') 之後）的巡檢記錄
3. 將保留後的內容覆蓋寫回 CHANGELOG.md，開頭加上一行：
   > 本文件只保留最近 14 天記錄，完整歸檔請見 archive/ 資料夾
4. 不要做其他任何事
" >> "$LOG_FILE" 2>&1
  echo "[$TIMESTAMP] ✅ CHANGELOG.md 歸檔完成" >> "$LOG_FILE"
fi

# ------------------------------------------------
# 2. 歸檔各單位 DONE.md
# ------------------------------------------------
UNITS="shiftautomate techtodaily daliypluslife music-production yt-pipeline"
for unit in $UNITS; do
  if [ -f "$unit/DONE.md" ] && [ -s "$unit/DONE.md" ]; then
    cp "$unit/DONE.md" "$ARCHIVE_DIR/${unit}-DONE.md"
    # 清空 DONE.md，只保留表頭
    cat > "$unit/DONE.md" <<EOF
# DONE.md — $unit 已完成事項

> 本文件由巡檢員確認任務完成後更新
> 舊記錄已歸檔至 archive/$LAST_MONTH/${unit}-DONE.md

---
*最後清理：$TIMESTAMP*
EOF
    echo "[$TIMESTAMP] ✅ $unit/DONE.md 歸檔完成" >> "$LOG_FILE"
  fi
done

# ------------------------------------------------
# 3. 清理 RED_FLAGS.md 中已處理的 PENDING 項目
# ------------------------------------------------
if [ -f "RED_FLAGS.md" ]; then
  cp "RED_FLAGS.md" "$ARCHIVE_DIR/RED_FLAGS.md"
  claude --dangerously-skip-permissions -p "
工作目錄：$REPO_DIR
請執行以下操作：
1. 讀取 RED_FLAGS.md
2. 移除所有標記為「已處理」或「已解決」的 PENDING 項目
3. 保留所有 URGENT 和尚未處理的 PENDING 項目
4. 覆蓋寫回 RED_FLAGS.md
5. 不要做其他任何事
" >> "$LOG_FILE" 2>&1
  echo "[$TIMESTAMP] ✅ RED_FLAGS.md 清理完成" >> "$LOG_FILE"
fi

# ------------------------------------------------
# 4. 寫入歸檔說明
# ------------------------------------------------
cat > "$ARCHIVE_DIR/README.md" <<EOF
# 歸檔：$LAST_MONTH

歸檔時間：$TIMESTAMP
包含內容：
- CHANGELOG.md（$LAST_MONTH 完整巡檢記錄）
- 各單位 DONE.md（$LAST_MONTH 完成事項）
- RED_FLAGS.md（$LAST_MONTH 事件快照）
EOF

# ------------------------------------------------
# 5. Git commit + push
# ------------------------------------------------
git add .
git commit -m "[歸檔] $LAST_MONTH 月度歸檔完成" >> "$LOG_FILE" 2>&1
git push origin main >> "$LOG_FILE" 2>&1

echo "[$TIMESTAMP] ====== 月度歸檔完成 ======" >> "$LOG_FILE"

telegram_notify "🗂️ <b>月度歸檔完成</b>
月份：$LAST_MONTH
內容：CHANGELOG / 各站 DONE.md / RED_FLAGS 快照
位置：archive/$LAST_MONTH/"
