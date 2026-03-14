# PROTOCOL.md — 巡檢員 × 龍蝦叢集 溝通協議

> 定義 Claude Code 巡檢員與 OpenClaw 龍蝦 agents 之間的任務交換格式

---

## 架構概覽

```
Claude Code 巡檢員（決策層）
        ↕ 讀寫 tasks/ 資料夾
OpenClaw 龍蝦叢集（執行層）
        ↕ 操作各平台（WordPress / FB / etc）
```

---

## 任務佇列結構

```
tasks/
├── pending/       ← 巡檢員派發，龍蝦待執行
├── running/       ← 龍蝦執行中（移入後代表已接單）
├── completed/     ← 龍蝦完成後移入
└── failed/        ← 執行失敗，含錯誤原因
```

---

## 任務文件格式

每個任務是一個獨立的 `.md` 文件，命名規則：

```
{YYYYMMDD-HHMM}-{站點}-{任務類型}-{編號}.md
例：20260314-1430-techtodaily-post-001.md
```

### 任務文件模板

```markdown
# 任務：{任務標題}

## 基本資訊
- 任務ID：{YYYYMMDD-HHMM}-{站點}-{類型}-{編號}
- 站點：shiftautomate / techtodaily / daliypluslife
- 類型：post（發文）/ seo（SEO）/ social（社群）/ monitor（監控）
- 優先級：🔴 緊急 / 🟡 一般 / 🟢 低
- 派發時間：{YYYY-MM-DD HH:MM}
- 截止時間：{YYYY-MM-DD HH:MM}（若有）

## 任務描述
{具體說明要做什麼}

## 執行參數
- 目標網址：
- 文章標題：
- 關鍵字：
- 其他參數：

## 成功條件
{龍蝦如何判斷任務完成}

## 執行記錄
（由龍蝦填入）
- 開始時間：
- 完成時間：
- 執行結果：
- 備註：
```

---

## 任務類型定義

### `post` — 發文任務
```
執行內容：生成文章 → 發布至 WordPress → 同步 FB（daliypluslife）
所需參數：站點、標題、關鍵字、分類、文章大綱或素材
```

### `seo` — SEO 任務
```
執行內容：關鍵字研究、內部連結優化、meta 設定
所需參數：目標頁面、目標關鍵字
```

### `social` — 社群任務
```
執行內容：FB 貼文撰寫、排程發布
所需參數：FB 專頁、貼文內容、發布時間
```

### `monitor` — 監控任務
```
執行內容：網站可用性確認、關鍵指標回報
回傳格式：狀態碼、回應時間、異常描述
```

---

## 龍蝦執行流程

```
1. 掃描 tasks/pending/ 取得待執行任務
2. 選擇任務 → 移入 tasks/running/（代表已接單，防止重複執行）
3. 執行任務
4. 完成 → 填寫執行記錄 → 移入 tasks/completed/
   失敗 → 填寫錯誤原因 → 移入 tasks/failed/
5. 重複，直到 pending/ 清空
```

---

## 巡檢員派發流程

```
1. 巡檢員讀取各站 TODO.md
2. 轉換待辦為任務文件 → 寫入 tasks/pending/
3. 下次巡檢讀取 tasks/completed/ 和 tasks/failed/
4. completed → 更新 DONE.md，刪除任務文件
5. failed → 評估是否重試 or 記入 RED_FLAGS.md
6. 清理 completed/ 和 failed/ 文件
```

---

## 緊急通報

龍蝦遇到以下情況，**直接寫入 RED_FLAGS.md** 並標記 URGENT：

- WordPress API 回傳 500 / 503
- FB 發文失敗（帳號異常）
- 任務連續失敗 3 次以上
- 網站無法訪問（timeout）

---

## 文件更新規則

| 文件 | 誰更新 | 時機 |
|------|--------|------|
| tasks/pending/ | 巡檢員 | 每次巡檢派發任務 |
| tasks/running/ | 龍蝦 | 接單時 |
| tasks/completed/ | 龍蝦 | 完成時 |
| tasks/failed/ | 龍蝦 | 失敗時 |
| STATUS.md | 巡檢員 | 每次巡檢結束 |
| TODO.md | 巡檢員 | 新增/完成待辦時 |
| DONE.md | 巡檢員 | 確認 completed 後 |
| CHANGELOG.md | 巡檢員 | 每次巡檢結束 |
| RED_FLAGS.md | 巡檢員 + 龍蝦 | 發現異常時 |

---

*最後更新：2026-03-14*
*版本：v1.0*
