#!/usr/bin/env bash
# 開一個 tmux session，左窗格 Claude Code（綠燈）、右窗格 Codex CLI（紅燈）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="${TA_SESSION:-twoagent}"

command -v tmux  >/dev/null || { echo "需要 tmux" >&2; exit 1; }
command -v codex >/dev/null || { echo "需要 codex CLI" >&2; exit 1; }

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "session '$SESSION' 已存在，直接接上。（要重開：tmux kill-session -t $SESSION）"
  exec tmux attach -t "$SESSION"
fi

# 左：Claude
tmux new-session -d -s "$SESSION" -c "$ROOT" -n agents
tmux send-keys -t "$SESSION:agents.0" \
  "export TA_AGENT=claude PATH=\"$ROOT/scripts:\$PATH\"; clear; ta status; echo; echo '你是 GREEN（實作者）。讀 CLAUDE.md 與 .twoagent/protocol.md，然後 ta wait'" C-m

# 右：Codex
tmux split-window -h -t "$SESSION:agents" -c "$ROOT"
tmux send-keys -t "$SESSION:agents.1" \
  "export TA_AGENT=codex PATH=\"$ROOT/scripts:\$PATH\"; clear; ta status; echo; echo '你是 RED（出題者）。讀 AGENTS.md 與 .twoagent/protocol.md，然後 ta cycle-next <feature>'" C-m

# 下方橫向監看列：state + 交棒紀錄，每 3 秒刷新
tmux split-window -v -t "$SESSION:agents.0" -l 12 -c "$ROOT"
tmux send-keys -t "$SESSION:agents.2" \
  "export TA_AGENT=human PATH=\"$ROOT/scripts:\$PATH\"; watch -n3 -t 'jq -r \"[.cycle,.feature,.phase,.turn]|@tsv\" .twoagent/state.json; echo; tail -8 .twoagent/log/handoff.log'" C-m

tmux select-pane -t "$SESSION:agents.0"

cat <<EOF
tmux session '$SESSION' 已開好：
  左上  TA_AGENT=claude  → 在這個窗格啟動 \`claude\`
  右    TA_AGENT=codex   → 在這個窗格啟動 \`codex\`
  左下  監看列（state + 交棒 log，3 秒刷新）

切換窗格：Ctrl-b 方向鍵    卸離：Ctrl-b d    收掉：tmux kill-session -t $SESSION
EOF

exec tmux attach -t "$SESSION"
