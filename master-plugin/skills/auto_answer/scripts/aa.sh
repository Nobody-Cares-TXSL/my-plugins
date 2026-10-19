#!/usr/bin/env bash
# aa.sh — auto_answer 单入口脚本
#
# 用法（会话名走环境变量 AA_SESSION，默认 auto）：
#   aa.sh doctor
#   aa.sh bind
#   aa.sh hide-dialogs
#   aa.sh read-questions
#   aa.sh answer-choice <答案.json>       # { choice:{...}, judge:{...} }
#   aa.sh answer-fill   <答案.json>       # { fill:{...} }
#   aa.sh verify
#   aa.sh eval <js文件>
#   aa.sh raw <js字符串>
#
# 设计要点：JS 从文件读入后作为单个 argv 传给 opencli，shell 不二次解析
# → 消除内联长 JS 的转义问题（引号/换行/反斜杠都不再需要转义）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

SESSION="${AA_SESSION:-auto}"
cmd="${1:-}"; shift || true

case "$cmd" in
  doctor)
    opencli doctor
    ;;

  bind)
    opencli browser "$SESSION" unbind 2>/dev/null || true
    opencli browser "$SESSION" bind
    ;;

  hide-dialogs)
    aa_eval "$SESSION" "$(build_js "$SCRIPT_DIR/js/hide_dialogs.js")"
    ;;

  read-questions)
    aa_eval "$SESSION" "$(build_js "$SCRIPT_DIR/js/read_questions.js")"
    ;;

  answer-choice)
    ans="${1:-}"
    [ -f "$ans" ] || { echo "用法: aa.sh answer-choice <答案.json>" >&2; exit 2; }
    aa_eval "$SESSION" "$(build_js "$SCRIPT_DIR/js/answer_choice.js" "$ans")"
    ;;

  answer-fill)
    ans="${1:-}"
    [ -f "$ans" ] || { echo "用法: aa.sh answer-fill <答案.json>" >&2; exit 2; }
    aa_eval "$SESSION" "$(build_js "$SCRIPT_DIR/js/answer_fill.js" "$ans")"
    ;;

  verify)
    aa_eval "$SESSION" "$(build_js "$SCRIPT_DIR/js/verify.js")"
    ;;

  # eval <js文件>：直接执行一个 JS 文件（临时脚本用）
  eval)
    f="${1:-}"
    [ -f "$f" ] || { echo "用法: aa.sh eval <js文件>" >&2; exit 2; }
    aa_eval "$SESSION" "$(build_js "$f")"
    ;;

  # raw <js字符串>：逃生口，直接透传 JS
  raw)
    aa_eval "$SESSION" "$1"
    ;;

  *)
    sed -n '3,20p' "$0"
    exit 2
    ;;
esac
