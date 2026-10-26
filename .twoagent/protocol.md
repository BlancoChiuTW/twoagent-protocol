# twoAgent 協定 v1（Claude ⇄ Codex 共同契約）

這份檔案是兩個 agent 唯一的共同真相來源。`CLAUDE.md` 與 `AGENTS.md` 都指向這裡。
任何一方對協定有異議，**改協定要先在 mailbox 提案並取得對方回覆**，不得片面修改。

## 1. 為什麼需要協定

Claude Code 與 Codex CLI 之間沒有任何原生 IPC：Claude 的 SendMessage 只送得到 Claude session，
Codex 也不對外開埠。兩者唯一共享的東西是**同一個 working tree**。
因此本協定把「誰現在該動手、動了什麼、要交棒給誰」全部落成檔案：

- `.twoagent/state.json` — 狀態機（誰的回合）
- `.twoagent/mailbox/` — 非同步訊息
- `.twoagent/log/handoff.log` — append-only 交棒紀錄
- `git` commit — 實際產出的交付單位

## 2. 角色（固定，不輪替）

| Agent | 身分 | 職責 | **可寫路徑** |
|---|---|---|---|
| **Codex**（GPT） | 出題者 / 紅燈 | 寫 `.feature`、寫失敗測試、驗收 | `features/`、`tests/` |
| **Claude** | 實作者 / 綠燈 | 讓測試通過、重構 | `src/` |

**這個分工的重點是防止「改測試讓它過」。**
Claude 永遠不得修改 `tests/` 或 `features/`；認為測試本身有錯時，唯一手段是寫信給 Codex 並交棒回去。
Codex 永遠不得修改 `src/`；想示範寫法時放在信件內文，不得直接落地。
`.githooks/pre-commit` 會在 commit 時擋下越界改動。

## 3. 狀態機

```
        ┌──────────────────────── REVIEW 不通過 ────────────────────────┐
        │                                                              │
   ┌────▼─────┐    ┌─────────┐    ┌──────────┐    ┌────────────┐    ┌──┴───────┐
   │   SPEC   │───►│   RED   │───►│  GREEN   │───►│  REFACTOR  │───►│  REVIEW  │
   │  codex   │    │  codex  │    │  claude  │    │   claude   │    │  codex   │
   └──────────┘    └─────────┘    └──────────┘    └────────────┘    └────┬─────┘
                                                                        │ 通過
                                                                   下一個 feature
```

| Phase | Owner | 完成條件（沒達成不准交棒） |
|---|---|---|
| `SPEC` | codex | `features/<slug>.feature` 存在，Gherkin 寫的是**行為與可觀察結果**，不是實作步驟 |
| `RED` | codex | 測試已寫、`ta test` **必須是紅的**，且失敗訊息是「功能未實作」而非語法錯／import 錯 |
| `GREEN` | claude | `ta test` 全綠，且只動了 `src/` |
| `REFACTOR` | claude | 重構後 `ta test` 仍全綠。沒東西可重構就直接交棒並註明 `no-op` |
| `REVIEW` | codex | 逐條檢查 scenario 是否真的被滿足；通過→`ta cycle-next`，不通過→`ta handoff RED` 並附理由 |

**紅燈驗證是硬性要求。** RED 階段若 `ta test` 是綠的，代表測試沒真的測到東西，
Codex 必須重寫而不是交棒。這是整個 TDD 迴圈唯一能防止空轉的檢查點。

## 4. 交棒流程（每次動作結束都要做完四步）

1. 完成本 phase 的工作
2. `ta test` — 確認結果符合本 phase 的完成條件
3. `git add -A && git commit -m "[PHASE] 摘要"` — **先 commit 再交棒**，交付物先落地
4. `ta msg "<主旨>"` — 從 stdin 寫信，說明做了什麼、對方該注意什麼
5. `ta handoff <下一個 phase>` — 更新 state、寫 log、切換 turn

順序不能反：先交棒再 commit 的話，對方會讀到一個還沒定案的 working tree。

**沒有交棒 = 對方不會動。** 對方的 `ta wait` 只認 `state.json` 裡的 `turn`。

## 5. 訊息格式

信件是 `.twoagent/mailbox/to-<agent>/<timestamp>-<slug>.md`，`ta msg` 會自動命名。內文請包含：

```
## 做了什麼
## 對方要注意什麼
## 已知問題 / 待確認
```

讀完信用 `ta inbox --archive` 歸檔，避免下一輪重複讀到舊信。

## 6. 衝突與例外

- **測試有爭議**：Claude 寫信說明「這個 scenario 與 X 矛盾」→ `ta handoff RED`。不准自行改測試。
- **卡住超過 3 個來回**：任一方寫信給對方並在信中 cc 人類（開頭寫 `@human`），然後停手等人介入。
- **人類介入**：人類可直接編輯 `state.json` 或用 `ta force-turn <agent>` 強制切換。
- **緊急繞過 hook**：`TA_OVERRIDE=1 git commit ...`，但必須在 commit message 說明理由。

## 7. 不變量（任何一方都不得違反）

1. 沒有先紅過的測試，不算數 — 不准先寫實作再補測試
2. Claude 不碰 `tests/` `features/`；Codex 不碰 `src/`
3. 每個 phase 結束都要 commit，commit message 前綴 `[SPEC]` `[RED]` `[GREEN]` `[REFACTOR]` `[REVIEW]`
4. `state.json` 只透過 `ta` 指令修改（人類介入除外）
