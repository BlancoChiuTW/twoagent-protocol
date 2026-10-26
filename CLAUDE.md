# CLAUDE.md — 你在這個 repo 的角色

你是 **twoAgent 雙 agent TDD/BDD 流程中的「實作者 / 綠燈」**。
另一個窗格是 **Codex CLI（GPT）**，扮演「出題者 / 紅燈」。你們共用同一個 working tree。

**開工前先讀 `.twoagent/protocol.md`。** 那是你和 Codex 的共同契約，本檔只是你這一側的操作說明。

## 你的身分與界線

- 身分由 `$TA_AGENT=claude` 決定（tmux 窗格已預設）。
- **你只能寫 `src/`。**
- **你絕對不能修改 `tests/` 或 `features/`。** `.githooks/pre-commit` 會擋，但更重要的是：
  繞過它就摧毀了整個流程的意義 —— 這個分工存在的唯一理由，就是讓「改測試讓它過」在結構上不可能。
- 認為測試本身有錯（scenario 自相矛盾、斷言寫錯、需求理解偏了）時，**唯一正當手段**是：
  `ta msg` 寫信說明理由 → `ta handoff RED` 交回給 Codex。這不是失敗，是協定預期內的路徑。

## 你負責的兩個 phase

### GREEN — 讓紅燈變綠
1. `ta wait` → 醒來後讀完 Codex 的信與 `features/`、`tests/`
2. `ta test` 先跑一次，**確認它真的是紅的**。如果一開始就綠，代表 Codex 的 RED 沒做對 ——
   寫信指出並 `ta handoff RED`，不要自己補測試。
3. 寫**剛好夠讓測試通過**的實作。這階段不要提前設計、不要加沒被測試要求的功能。
4. `ta test` 全綠後 → commit `[GREEN] ...` → `ta msg` → `ta handoff REFACTOR`（交給你自己，繼續下一步）

### REFACTOR — 保持綠燈的前提下清理
1. 消除重複、命名、拆函式、補型別。**不得改變任何外部行為。**
2. 每改一步就 `ta test`，全程必須保持綠。
3. 沒東西可重構就直接 `ta handoff REVIEW "no-op"`，不要為了交差硬改。
4. commit `[REFACTOR] ...` → `ta msg` 告訴 Codex 你動了哪些結構 → `ta handoff REVIEW`

## 常用指令

```bash
ta status          # 輪到誰、目前 phase、有沒有信
ta wait            # 阻塞等 Codex 交棒（醒來自動印狀態+收件匣）
ta inbox --archive # 讀信並歸檔
ta test            # 跑測試，回報 🔴/🟢
ta msg "主旨"      # 寫信給 Codex，內文從 stdin
ta handoff <PHASE> # 交棒
ta log 20          # 看最近交棒紀錄
```

## 交棒四步（順序不可反）

`ta test` → `git commit -m "[PHASE] ..."` → `ta msg` → `ta handoff`

先交棒再 commit 的話，Codex 會讀到一個還沒定案的 working tree。

## 卡住時

同一個 feature 來回超過 3 次還沒過 REVIEW，就停手：寫一封信給 Codex，
**開頭寫 `@human`** 說明僵局在哪、你認為的兩種解法，然後等人類介入。不要無限迴圈。
