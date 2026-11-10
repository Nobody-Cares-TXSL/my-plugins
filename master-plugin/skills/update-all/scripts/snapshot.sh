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
enabled = {k for k, v in json.load(open(settings_path)).get('enabledPlugins', {}).items() if v is True}
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
  # opencode 从 opencode.jsonc 的 skills.paths 加载 skill，不读 ~/.config/opencode/skills（常为空）
  # 注释先剥掉（jsonc 允许 // 行注释），再用 raw_decode 取第一个完整 JSON 值：
  # 它和手写括号配平语义相同，但对字符串里出现的 "}" 不会误判
  OC_SKILL_PATHS=$(python3 -c '
import json, sys, os
p = os.path.expanduser("~/.config/opencode/opencode.jsonc")
try:
    raw = open(p).read()
except OSError:
    sys.exit(0)
raw = "\n".join(l for l in raw.splitlines() if not l.strip().startswith("//"))
try:
    data, _ = json.JSONDecoder().raw_decode(raw[raw.find("{"):])
except ValueError:
    sys.exit(0)
for pth in data.get("skills", {}).get("paths", []):
    print(os.path.expanduser(pth))
' 2>/dev/null)
  opencode_skills=0
  while IFS= read -r p; do
    [ -n "$p" ] && [ -d "$p" ] || continue
    n=$(ls -d "$p"/*/SKILL.md 2>/dev/null | wc -l)
    opencode_skills=$((opencode_skills + n))
  done <<< "$OC_SKILL_PATHS"
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

# pipx 安装的 CLI 版本：一次取全，后面 agent-reach / notebooklm 段直接复用。
# `pipx list --short` 已经输出 "agent-reach 1.6.1" 这样的行，
# 不必再启动 agent-reach doctor（0.3s）或 notebooklm --version（1-2s）问一遍。
pipx_ver() {
  command -v pipx >/dev/null 2>&1 || return 0
  pipx list --short 2>/dev/null | awk -v p="$1" '$1 == p {print $2; exit}'
}

# agent-reach CLI + skill
echo "--- agent-reach ---"
if command -v agent-reach &>/dev/null; then
  reach_ver=$(pipx_ver agent-reach)
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
  echo "  CLI: $(pipx_ver notebooklm-py)"
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
# 直接读 package.json，不用 `npm ls -g`：后者实测 1.2-6.8 秒（每次重新解析依赖树），
# 直读 88 毫秒且输出等价。快照要跑 before/after 两遍，这里省得最多。
echo "--- npm global packages ---"
if command -v npm &>/dev/null; then
  NPM_ROOT="$(npm root -g 2>/dev/null)"
  if [ -n "$NPM_ROOT" ] && [ -d "$NPM_ROOT" ]; then
    # 一层 scope 目录（@scope/pkg）也要展开
    for pkg_json in "$NPM_ROOT"/*/package.json "$NPM_ROOT"/@*/*/package.json; do
      [ -f "$pkg_json" ] || continue
      name=$(sed -n 's/^ *"name": *"\([^"]*\)".*/\1/p' "$pkg_json" | head -1)
      ver=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$pkg_json" | head -1)
      [ -n "$name" ] && printf '  %s@%s\n' "$name" "$ver"
    done | sort
  fi
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

# uv tool（与 pipx 并列的独立安装渠道，不归 pipx/npm/apt 管）
echo "--- uv tool ---"
if command -v uv &>/dev/null; then
  # `uv tool list` 输出工具行 + 缩进的命令列表；只取工具行，避免把依赖包算进去
  uv tool list 2>/dev/null | grep -vE '^\s*-\s' | grep -vE '^\s*$' | sed 's/^/  /' || true
else
  echo "  not installed"
fi

echo ""
echo "=== 快照结束 ($LABEL) ==="
