# twoAgent Protocol

**兩個 AI coding agent 在同一個 working tree 上跑 TDD／BDD 的檔案系統協定。**
Claude Code 當實作者（綠燈），Codex CLI 當出題者與驗收者（紅燈），角色固定不輪替。

語言無關 —— 選定技術棧後只需填 `.twoagent/config.sh` 的兩行指令。

---

## 為什麼需要協定層

Claude Code 與 Codex CLI 之間**沒有任何原生通訊管道**：Claude 的 session 訊息送不到 Codex，Codex 也不對外開埠。
兩者唯一共享的東西是**同一個檔案系統**。

所以「互相知道彼此在做什麼」必須被做出來，而不是假設它存在：

| 檔案 | 作用 |
|---|---|
| `.twoagent/state.json` | 狀態機：現在是誰的回合、哪個 feature、哪個 phase |
| `.twoagent/mailbox/to-claude/`、`to-codex/` | 非同步信箱 |
| `.twoagent/log/handoff.log` | append-only 交棒紀錄 |
| `.twoagent/protocol.md` | 兩邊共讀的契約（唯一真相來源） |
| `CLAUDE.md` / `AGENTS.md` | 各自的角色指令（兩家 CLI 會自動載入自己那份） |
| `.githooks/pre-commit` | **路徑歸屬守門員**，擋下越界改動 |
| `scripts/ta` | 唯一被允許修改狀態的 CLI |

---

## 核心設計：讓「改測試讓它過」在結構上不可能

這是整套協定存在的理由。

```
Codex（出題／紅燈）  只能寫  features/  tests/
Claude（實作／綠燈）  只能寫  src/
```

`.githooks/pre-commit` 在 commit 時檢查改動路徑，越界就擋下來。

- Claude 認為測試本身有錯時，**唯一正當手段**是寫信給 Codex 並把回合交還 RED —— 不准自己改測試
- Codex 想示範寫法時只能放在信件內文，**不准直接落地到 `src/`**

→ 因為實作方碰不到驗收標準，**REVIEW 階段才是真的獨立驗證**。
這跟團隊為什麼要 code review 是同一個理由：自己出題自己答，審查就只是形式。

### 狀態機

```
        ┌───────────────────── REVIEW 不通過 ─────────────────────┐
        │                                                        │
   ┌────▼─────┐   ┌─────────┐   ┌──────────┐   ┌────────────┐   ┌─┴────────┐
   │   SPEC   │──►│   RED   │──►│  GREEN   │──►│  REFACTOR  │──►│  REVIEW  │
   │  codex   │   │  codex  │   │  claude  │   │   claude   │   │  codex   │
   └──────────┘   └─────────┘   └──────────┘   └────────────┘   └─┬────────┘
                                                                  │ 通過
                                                             下一個 feature
```

| Phase | Owner | 完成條件（沒達成不准交棒） |
|---|---|---|
| `SPEC` | codex | `features/<slug>.feature` 存在，Gherkin 寫的是**行為與可觀察結果**，不是實作步驟 |
| `RED` | codex | 測試已寫、`ta test` **必須是紅的**，且失敗訊息是「功能未實作」而非語法／import 錯 |
| `GREEN` | claude | `ta test` 全綠，且只動了 `src/` |
| `REFACTOR` | claude | 重構後仍全綠；沒東西可重構就交棒並註明 `no-op` |
| `REVIEW` | codex | 逐條檢查 scenario 是否真的被滿足；通過 → `ta cycle-next`，不通過 → `ta handoff RED` 並附理由 |

**紅燈驗證是硬性要求。** RED 階段若 `ta test` 是綠的，代表測試沒真的測到東西，Codex 必須重寫而不是交棒 ——
這是整個迴圈唯一能防止空轉的檢查點。

---

## 起步

```bash
git clone <this repo> my-project && cd my-project
git config core.hooksPath .githooks     # 啟用守門員（clone 後要做一次）

# 接上你的技術棧：編輯 .twoagent/config.sh 兩行
#   TEST_CMD="uv run pytest -q"      # 或 npx vitest run / go test ./...
#   BDD_CMD="uv run behave -q"       # 沒有就留空

./scripts/start.sh                      # 開 tmux：左上 Claude、右 Codex、左下監看列
```

然後在左上窗格輸入 `claude`、右窗格輸入 `codex`，兩邊各自會載入自己的角色檔。

第一輪由 Codex 起跑：

```bash
ta cycle-next user-login      # 開 cycle 1，phase=SPEC
```

Claude 那側只要 `ta wait`，輪到它時會自動醒來並印出收件匣。

### 交棒流程（每次動作結束都要做完）

1. 完成本 phase 的工作
2. `ta test` — 確認結果符合本 phase 的完成條件
3. `git add -A && git commit -m "[PHASE] 摘要"` — **先 commit 再交棒**，交付物先落地
4. `ta msg "<主旨>"` — 從 stdin 寫信，說明做了什麼、對方該注意什麼
5. `ta handoff <下一個 phase>` — 更新 state、寫 log、切換 turn

順序不能反：先交棒再 commit，對方會讀到一個還沒定案的 working tree。
**沒有交棒 = 對方不會動**（`ta wait` 只認 `state.json` 的 `turn`）。

### 指令速查

```
ta status      ta wait        ta inbox --archive    ta msg "主旨"
ta test        ta handoff <PHASE>    ta cycle-next <feature>
ta log 20      ta force-turn <agent>
```

人類介入：`ta force-turn claude`，或直接編輯 `state.json`。
緊急繞過 hook：`TA_OVERRIDE=1 git commit ...`，但必須在 commit message 說明理由。

---

## 不變量

1. 沒有先紅過的測試，不算數 —— 不准先寫實作再補測試
2. Claude 不碰 `tests/` `features/`；Codex 不碰 `src/`
3. 每個 phase 結束都要 commit，前綴 `[SPEC]` `[RED]` `[GREEN]` `[REFACTOR]` `[REVIEW]`
4. `state.json` 只透過 `ta` 指令修改（人類介入除外）
5. 卡住超過 3 個來回：寫信給對方並在信中 cc 人類（開頭寫 `@human`），然後停手等人介入

---

## 跟 Spec-Driven Development 的關係

這套協定是 **SDD（Spec-Driven Development）＋ TDD** 的落地實作：規格先行、規格進版控、驗收回頭對規格。

與 [OpenSpec](https://github.com/Fission-AI/OpenSpec)、GitHub Spec Kit 這類工具的差異：
它們負責**把規格談清楚**（proposal → spec → tasks），
這套協定多做一層**權限隔離**——用版控 hook 確保實作方事後碰不到驗收標準。
兩者可以疊：用 OpenSpec 產出 spec，再用這套協定跑實作與驗收。

---

## 現狀（誠實說明）

- ✅ 協定、狀態機、信箱、交棒紀錄、pre-commit 路徑守門員**都已可運作**
- ⚠️ 本 repo 是**乾淨的協定骨架**（`state.json` 為 `cycle 0 / IDLE`）；完整 feature 循環的實跑紀錄在另一個私有專案
- 📌 技術棧的接點只有 `.twoagent/config.sh` 兩行，Python／Node／Go 都能用

## 授權

MIT
