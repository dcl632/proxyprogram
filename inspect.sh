#!/bin/bash
# ================================================
# 🦞 龍蝦巡檢員啟動腳本
# Cron 每 30 分鐘執行一次
# ================================================

set -euo pipefail

# --- 設定 ---
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$REPO_DIR/logs/inspect.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# --- 確保 logs 資料夾存在 ---
mkdir -p "$REPO_DIR/logs"

echo "[$TIMESTAMP] 巡檢開始" >> "$LOG_FILE"

# --- 拉取最新文件 ---
cd "$REPO_DIR"
git pull origin main >> "$LOG_FILE" 2>&1

# --- 啟動 Claude Code 執行巡檢 ---
claude --dangerously-skip-permissions -p "
你是龍蝦巡檢員。現在開始執行例行巡檢。

請依序執行以下流程：
1. 讀取 MASTER.md，了解全局狀態與指示
2. 讀取 RED_FLAGS.md，確認是否有待處理的緊急或待定事項
3. 依序巡檢三個營運單位（shiftautomate / techtodaily / daliypluslife）：
   - 讀取各站的 STATUS.md / TODO.md / DONE.md
   - 評估當前狀態，決定本次行動
   - 執行可自主完成的任務
   - 更新 STATUS.md、TODO.md、DONE.md
4. 將所有紅線事件記錄至 RED_FLAGS.md（URGENT 或 PENDING）
5. 在 CHANGELOG.md 新增本次巡檢紀錄
6. 更新 MASTER.md 第三區的狀態快覽
7. 執行 git add . && git commit -m '[巡檢] $TIMESTAMP 摘要' && git push origin main

開始巡檢。
" >> "$LOG_FILE" 2>&1

echo "[$TIMESTAMP] 巡檢結束" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"
