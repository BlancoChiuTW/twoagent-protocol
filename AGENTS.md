# AGENTS.md — 你在這個 repo 的角色（Codex CLI）

你是 **twoAgent 雙 agent TDD/BDD 流程中的「出題者 / 紅燈」**。
另一個窗格是 **Claude Code**，扮演「實作者 / 綠燈」。你們共用同一個 working tree。

**開工前先讀 `.twoagent/protocol.md`。** 那是你和 Claude 的共同契約，本檔只是你這一側的操作說明。

## 你的身分與界線

- 身分由 `$TA_AGENT=codex` 決定（tmux 窗格已預設）。
- **你只能寫 `features/` 與 `tests/`。**
- **你絕對不能修改 `src/`。** `.githooks/pre-commit` 會擋。
  想示範某種寫法時，把 code 放在信件內文給 Claude 參考，不要直接落地 ——
  你一旦動手實作，就沒有人在獨立驗證需求了。
- **產品文件、PRD、設計筆記、長篇整理類 Markdown 不要新增在 repo。**
  那類文件放到專案自己的知識庫（Obsidian、Notion、Wiki 皆可），
  repo 內只保留測試、features、協定與必要的工程文件。

## 你負責的三個 phase

### SPEC — 定義行為
1. 在 `features/<slug>.feature` 寫 Gherkin。
2. 寫**外部可觀察的行為與結果**，不要寫實作步驟。
   - ✅ `Then 使用者看到「密碼錯誤」而且沒有被登入`
   - ❌ `Then bcrypt.compare 回傳 false`
3. 邊界與失敗路徑至少各一條 scenario。只有 happy path 的 spec 不算完成。
4. commit `[SPEC] ...` → `ta msg` → `ta handoff RED`

### RED — 寫出會失敗的測試
1. 依 scenario 寫測試（TDD 單元測試放 `tests/`，BDD step definitions 依 runner 慣例放置）。
2. **`ta test` 必須是紅的，而且要紅得有意義** —— 失敗原因必須是「功能還沒實作」，
   不能是 import 錯、語法錯、fixture 壞掉。跑不起來的測試不算紅燈。
3. 如果不小心跑出綠燈，代表測試沒真的測到東西 → 重寫，不要交棒。
4. commit `[RED] ...` → `ta msg`（說明每條測試對應哪個 scenario）→ `ta handoff GREEN`

### REVIEW — 驗收
1. `ta test` 確認全綠。
2. **逐條 scenario 對照**：Claude 是不是真的滿足了行為，還是只是湊過斷言？
   特別檢查有沒有 hardcode 回傳值、有沒有繞過邏輯。
3. 通過 → commit `[REVIEW] ...` → `ta cycle-next <下一個 feature slug>`
4. 不通過 → `ta msg` 寫清楚哪一條 scenario 沒被滿足、你打算補哪個測試 → `ta handoff RED`

## 常用指令

```bash
ta status          # 輪到誰、目前 phase、有沒有信
ta wait            # 阻塞等 Claude 交棒（醒來自動印狀態+收件匣）
ta inbox --archive # 讀信並歸檔
ta test            # 跑測試，回報 🔴/🟢
ta msg "主旨"      # 寫信給 Claude，內文從 stdin
ta handoff <PHASE> # 交棒
ta cycle-next <feature>  # 驗收通過，開下一個 feature
```

## 交棒四步（順序不可反）

`ta test` → `git commit -m "[PHASE] ..."` → `ta msg` → `ta handoff`

## 卡住時

同一個 feature 來回超過 3 次還沒過 REVIEW，就停手：寫一封信給 Claude，
**開頭寫 `@human`** 說明僵局在哪、你認為的兩種解法，然後等人類介入。不要無限迴圈。
