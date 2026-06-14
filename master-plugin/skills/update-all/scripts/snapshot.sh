#!/usr/bin/env bash
# snapshot.sh — 检测所有工具链的当前版本
# 用法: bash snapshot.sh [before|after]
set -euo pipefail

: "${TMPDIR:=/tmp}"

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

LABEL="${1:-snapshot}"
SETTINGS="$HOME/.claude/settings.json"
PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
GSTACK_VER="$HOME/.claude/skills/gstack/VERSION"
AGENT_SKILLS="$HOME/.agents/skills"
REACH_SKILL="$HOME/.claude/skills/agent-reach"

echo "=== 版本快照 ($LABEL) ==="
echo ""

# Claude Code 插件
if [ -f "$PLUGINS" ]; then
  echo "--- Claude Code Plugins ---"
  python3 -c "
import json, sys
plugins_path = '$PLUGINS'
settings_path = '$SETTINGS'
try:
    with open(plugins_path) as f:
        plugins = json.load(f)['plugins']
except (json.JSONDecodeError, KeyError):
    print('  Error: installed_plugins.json is malformed or missing plugins key')
    sys.exit(0)
enabled = set(json.load(open(settings_path)).get('enabledPlugins', {}).keys())
for k, v in sorted(plugins.items()):
    ver = v[0]['version']
    status = 'enabled' if k in enabled else 'disabled'
    print(f'  {k}: {ver} ({status})')
"
  echo ""
fi

# gstack
echo "--- gstack ---"
if [ -f "$GSTACK_VER" ]; then
  echo "  $(cat "$GSTACK_VER")"
  gstack_count=$(ls -d "$HOME/.claude/skills/gstack"/*/SKILL.md 2>/dev/null | wc -l)
  echo "  skills: $gstack_count"
else
  echo "  not installed"
fi
echo ""

# opencode CLI
echo "--- opencode ---"
if command -v opencode &>/dev/null; then
  echo "  CLI: $(opencode --version 2>&1 | head -1)"
  opencode_skills=$(ls -d "$HOME/.config/opencode/skills"/*/SKILL.md 2>/dev/null | wc -l)
  echo "  skills: $opencode_skills"
else
  echo "  not installed"
fi
echo ""

# opencli CLI + 站点/命令统计
echo "--- opencli CLI ---"
if command -v opencli &>/dev/null; then
  opencli_ver=$(opencli --version 2>&1 | head -1)
  echo "  $opencli_ver"
  opencli_stats=$(opencli list 2>&1 | grep -E '[0-9]+ built-in commands' | head -1 | sed 's/^ *//')
  echo "  $opencli_stats"
else
  echo "  not installed"
fi
echo ""

# Agent skills（~/.agents/skills/ 是通用目录，含 opencli 生态与独立来源的 skill）
echo "--- Agent Skills (~/.agents/skills) ---"
if [ -d "$AGENT_SKILLS" ]; then
  # opencli 生态：opencli-* 前缀 + smart-search（frontmatter 声明"基于 opencli 命令"）
  echo "  [opencli 生态]"
  ls -1 "$AGENT_SKILLS" 2>/dev/null | grep -E '^(opencli-|smart-search$)' | sed 's/^/    /'
  echo "  [独立]"
  ls -1 "$AGENT_SKILLS" 2>/dev/null | grep -vE '^(opencli-|smart-search$)' | sed 's/^/    /'
else
  echo "  not installed"
fi
echo ""

# agent-reach CLI + skill
echo "--- agent-reach ---"
if command -v agent-reach &>/dev/null; then
  echo "  CLI: $(agent-reach --version 2>&1 | head -1)"
fi
if [ -f "$REACH_SKILL/SKILL.md" ]; then
  skill_date=$(stat -c '%Y' "$REACH_SKILL/SKILL.md" 2>/dev/null)
  echo "  skill: $(date -d "@$skill_date" '+%Y-%m-%d %H:%M')"
else
  echo "  skill: not installed"
fi

echo ""

# notebooklm
echo "--- notebooklm ---"
if command -v notebooklm &>/dev/null; then
  echo "  CLI: $(notebooklm --version 2>&1 | head -1)"
else
  echo "  CLI: not installed"
fi
if [ -f "$HOME/.claude/skills/notebooklm/SKILL.md" ]; then
  skill_date=$(stat -c '%Y' "$HOME/.claude/skills/notebooklm/SKILL.md" 2>/dev/null)
  echo "  skill: $(date -d "@$skill_date" '+%Y-%m-%d %H:%M')"
else
  echo "  skill: not installed"
fi

echo ""
echo "=== 快照结束 ($LABEL) ==="
