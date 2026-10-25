#!/usr/bin/env bash
# snapshot.sh — 检测所有工具链的当前版本
# 用法: bash snapshot.sh [before|after]
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

LABEL="${1:-snapshot}"
SETTINGS="$HOME/.claude/settings.json"
PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
AGENT_SKILLS="$HOME/.agents/skills"
REACH_SKILL="$HOME/.agents/skills/agent-reach"

# 落盘：输出同时写入文件，供更新后对比（防上下文丢失）
SNAP_FILE="${TMPDIR:-$HOME/.cache/tmp}/update-all-snapshot-$LABEL.txt"
mkdir -p "$(dirname "$SNAP_FILE")"
exec > >(tee "$SNAP_FILE")

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

# opencode CLI
echo "--- opencode ---"
if command -v opencode &>/dev/null; then
  echo "  CLI: $(opencode --version 2>&1 | head -1)"
  opencode_skills=$(ls -d "$HOME/.config/opencode/skills"/*/SKILL.md 2>/dev/null | wc -l || true)
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
  # 2.x 输出 JSON，1.x 输出人类可读统计行；两种都取，取不到不致命
  opencli_sites=$(opencli --help 2>&1 | grep -oE 'Site adapters \([0-9]+\)' | head -1 || true)
  opencli_cmds=$(opencli list --limit 1 -f json 2>&1 | grep -oE '"total":[0-9]+' | head -1 | cut -d: -f2 || true)
  echo "  ${opencli_sites:-站点数未知}${opencli_cmds:+, ${opencli_cmds} commands}"
else
  echo "  not installed"
fi
echo ""

# Agent skills（~/.agents/skills/ 是通用目录，含 opencli 生态与独立来源的 skill）
echo "--- Agent Skills (~/.agents/skills) ---"
if [ -d "$AGENT_SKILLS" ]; then
  # opencli 生态：opencli-* 前缀 + smart-search（frontmatter 声明"基于 opencli 命令"）
  echo "  [opencli 生态]"
  # grep 无匹配在 set -euo pipefail 下会终止整个快照，必须兜底
  ls -1 "$AGENT_SKILLS" 2>/dev/null | grep -E '^(opencli-|smart-search$)' | sed 's/^/    /' || true
  echo "  [独立]"
  ls -1 "$AGENT_SKILLS" 2>/dev/null | grep -vE '^(opencli-|smart-search$)' | sed 's/^/    /' || true
else
  echo "  not installed"
fi
echo ""

# agent-reach CLI + skill
echo "--- agent-reach ---"
if command -v agent-reach &>/dev/null; then
  # 1.6+ 移除了 --version，版本改从 doctor 的 JSON 取
  reach_ver=$(agent-reach doctor 2>/dev/null | grep -oE '"version": *"[^"]+"' | head -1 | cut -d'"' -f4 || true)
  echo "  CLI: ${reach_ver:-未知}"
fi
if [ -f "$REACH_SKILL/SKILL.md" ]; then
  skill_date=$(stat -c '%Y' "$REACH_SKILL/SKILL.md" 2>/dev/null)
  echo "  skill: $(date -d "@$skill_date" '+%Y-%m-%d %H:%M')"
  # 双份真目录会导致同名 skill 内容分裂，链接形态才是预期
  if [ -L "$HOME/.claude/skills/agent-reach" ]; then
    echo "  link:  ~/.claude/skills/agent-reach ✓"
  elif [ -d "$HOME/.claude/skills/agent-reach" ]; then
    echo "  link:  ⚠️ ~/.claude/skills/agent-reach 是独立副本（应为符号链接）"
  fi
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

# npm 全局包
echo "--- npm global packages ---"
if command -v npm &>/dev/null; then
  npm ls -g --depth=0 2>/dev/null | tail -n +2 | sed 's/^/  /'
else
  echo "  not installed"
fi
echo ""

# pipx
echo "--- pipx ---"
if command -v pipx &>/dev/null; then
  pipx list --short 2>/dev/null | sed 's/^/  /'
else
  echo "  not installed"
fi

echo ""
echo "=== 快照结束 ($LABEL) ==="
