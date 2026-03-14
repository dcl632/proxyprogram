# Cron 設定說明

## 目標
每 30 分鐘自動叫醒巡檢員，執行 inspect.sh。

---

## 步驟一：確認 Claude Code CLI 可用

```bash
which claude
claude --version
```

若未安裝：
```bash
npm install -g @anthropic-ai/claude-code
```

---

## 步驟二：確認腳本有執行權限

```bash
chmod +x /path/to/proxyprogram/inspect.sh
```

---

## 步驟三：設定 Cron

```bash
crontab -e
```

加入以下這行（每 30 分鐘執行）：

```
*/30 * * * * /path/to/proxyprogram/inspect.sh
```

**實際路徑範例（依你的機器調整）：**

```
*/30 * * * * /Users/alan_dingchaoliao/proxyprogram/inspect.sh
```

---

## 步驟四：確認 Cron 有權限執行

macOS 需要給 cron 完整磁碟存取權限：

1. 系統設定 → 隱私權與安全性 → 完整磁碟存取權限
2. 新增 `/usr/sbin/cron`

---

## 步驟五：驗證

```bash
# 手動測試腳本是否正常
bash /path/to/proxyprogram/inspect.sh

# 查看 cron 執行記錄
tail -f /path/to/proxyprogram/logs/inspect.log

# 查看 cron 系統記錄
grep cron /var/log/system.log
```

---

## 注意事項

- **電腦需保持開機** — cron 只在機器運行時執行，睡眠中不會觸發
- **Anthropic API Key** — 需設定環境變數 `ANTHROPIC_API_KEY`（或 Claude Max 登入狀態）
- **網路連線** — 巡檢員需要能連到 GitHub 和 Claude API

---

## 設定 ANTHROPIC_API_KEY（如果用 API 計費）

```bash
# 加入 ~/.zshrc 或 ~/.bash_profile
export ANTHROPIC_API_KEY="sk-ant-xxxxxxxx"
```

若使用 Claude Max 訂閱，登入後直接可用，無需 API Key。

---

## Cron 的環境變數問題（常見坑）

Cron 不會繼承你的 shell 環境變數。在 inspect.sh 開頭加上：

```bash
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.nvm/versions/node/$(node -v)/bin"
export ANTHROPIC_API_KEY="sk-ant-xxxxxxxx"
```

或在 crontab 頂端定義：

```
PATH=/usr/local/bin:/usr/bin:/bin
ANTHROPIC_API_KEY=sk-ant-xxxxxxxx
*/30 * * * * /path/to/proxyprogram/inspect.sh
```
