# .twoagent/config.sh — 語言無關的接點。
#
# TEST_CMD : TDD 單元測試指令。exit 0 = 綠，非 0 = 紅。
# BDD_CMD  : BDD scenario 指令。留空代表這個專案還沒接 BDD runner。

TEST_CMD="uv run --frozen pytest"

# behave 需要 features/steps/ 才跑得動，該目錄由 codex 建立（features/ 是 codex 的路徑）。
# 在它存在之前優雅跳過，避免 GREEN 階段被誤判為紅。
BDD_CMD='if [ -d features/steps ]; then uv run --frozen behave -q; else echo "(尚無 features/steps，跳過 BDD)"; fi'

# 路徑歸屬（pre-commit hook 用來擋越界改動）
CODEX_PATHS="features tests"
CLAUDE_PATHS="src"
