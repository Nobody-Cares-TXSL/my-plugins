#!/usr/bin/env bash
# update-agent-skills.sh — 用 npx skills 更新 ~/.agents/skills 下由它管理的 skill
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

AGENT_SKILLS="$HOME/.agents/skills"
LOCK="$HOME/.agents/.skill-lock.json"

# 没有 lock 文件说明 npx skills 没在这个 HOME 装过东西，跳过而不是报错
if [ ! -f "$LOCK" ]; then
  echo "--- npx skills: 未安装（$LOCK 不存在），跳过 ---"
  exit 0
fi

echo "--- Updating npx-managed skills ($AGENT_SKILLS) ---"
# -g 必须显式指定：cwd 是 $HOME 时 $HOME/.agents/skills 会被 hasProjectSkills() 认成 project skills
# stdin 非 TTY 时上游已删除的 skill 只提示不删除，不会误删本地目录
# 退出码 1 表示有 skill 更新失败，不是「没有可更新项」
rc=0
npx -y skills@latest update -g || rc=$?
if [ "$rc" -ne 0 ]; then
  echo "  ⚠️  npx skills update 退出码 $rc：部分 skill 更新失败，详见上方输出"
  exit "$rc"
fi

echo ""
echo "--- npx skills update complete ---"
