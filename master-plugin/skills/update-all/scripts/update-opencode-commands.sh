#!/usr/bin/env bash
# update-opencode-commands.sh — 同步所有 skills + 插件 commands 到 opencode.jsonc 的 command 配置
# 中文描述从 commands-desc.txt 读取，skill 名称从 SKILL.md frontmatter 提取
set -euo pipefail

: "${TMPDIR:=/tmp}"

OCCONFIG="$HOME/.config/opencode/opencode.jsonc"
CLAUDE_SKILLS="$HOME/.claude/skills"
AGENTS_SKILLS="$HOME/.agents/skills"
PLUGIN_SKILLS="$HOME/plugins/master-plugin/skills"
PLUGIN_COMMANDS="$HOME/plugins/master-plugin/commands"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DESC_MAP="$SCRIPT_DIR/../commands-desc.txt"

if [ ! -f "$OCCONFIG" ]; then
  echo "  opencode config not found at $OCCONFIG, skipping"
  exit 0
fi

echo "--- Syncing commands to opencode.jsonc ---"

extract_name() {
  local skill_file="$1"
  [ -f "$skill_file" ] || return 1
  awk '/^name:/{print $2; exit}' "$skill_file"
}

# 从 SKILL.md 提取 description frontmatter
extract_description() {
  local skill_file="$1"
  awk '/^description:/{found=1; sub(/^description:[[:space:]]*/, ""); sub(/^[[:space:]]*\|[[:space:]]*/, ""); if(found) {gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print; exit}} found{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print}' "$skill_file"
}

# 收集所有 skill name（去重），同时输出 name<TAB>skill_md_path
collect_skill_entries() {
  for d in "$CLAUDE_SKILLS"/*/; do
    [ -d "$d" ] || continue
    [ -L "$d" ] && continue
    case "$(basename "$d")" in update-all|CLAUDE.md|README.md|skills-dashboard.html) continue;; esac
    name=$(extract_name "${d}SKILL.md") && printf '%s\t%s\n' "$name" "${d}SKILL.md"
  done
  for d in "$AGENTS_SKILLS"/*/; do
    [ -d "$d" ] || continue
    name=$(extract_name "${d}SKILL.md") && printf '%s\t%s\n' "$name" "${d}SKILL.md"
  done
  # 插件仓库 skills（master-plugin）
  for d in "$PLUGIN_SKILLS"/*/; do
    [ -d "$d" ] || continue
    name=$(extract_name "${d}SKILL.md") && printf '%s\t%s\n' "$name" "${d}SKILL.md"
  done
}

# 收集插件仓库 commands/*.md：name<TAB>path<TAB>描述（描述已是中文，直接可用）
collect_command_entries() {
  for f in "$PLUGIN_COMMANDS"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print; exit}' "$f")
    printf '%s\t%s\t%s\n' "$name" "$f" "$desc"
  done
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 写入临时文件供 Python 读取
collect_skill_entries | sort -u -t$'\t' -k1,1 > "$TMP/all_entries.txt"
cut -f1 "$TMP/all_entries.txt" > "$TMP/all_names.txt"
collect_command_entries > "$TMP/cmd_entries.txt"

# 自动为新 skill 生成中文描述并追加到 commands-desc.txt
new_entries=()
while IFS=$'\t' read -r name path; do
  grep -qF "${name}|" "$DESC_MAP" 2>/dev/null || new_entries+=("$name"$'\t'"$path")
done < "$TMP/all_entries.txt"

if [ ${#new_entries[@]} -gt 0 ]; then
  echo "  Auto-translating ${#new_entries[@]} new skill description(s)..."
  # 构建翻译输入
  translate_input=""
  for entry in "${new_entries[@]}"; do
    name="${entry%%$'\t'*}"
    path="${entry#*$'\t'}"
    desc=$(extract_description "$path")
    translate_input+="${name}|${desc}"$'\n'
  done

  # 用 claude -p 翻译
  prompt="将以下 skill 描述翻译为简洁的中文（一行），保持 input 格式 skill-name|中文描述，只输出结果不要解释：

${translate_input}"
  translation_result=$(claude -p "$prompt" 2>/dev/null)

  if [ -n "$translation_result" ]; then
    # 只保留符合 name|desc 格式的行，过滤掉 Claude 的对话性输出；去除反引号包裹
    echo "$translation_result" | grep '|' | sed -E 's/^[[:space:]]*`//; s/`[[:space:]]*$//' >> "$DESC_MAP"
    # 统计成功追加的数量
    added=$(echo "$translation_result" | grep -c '|')
    echo "  Added $added description(s) to commands-desc.txt"
  else
    echo "  Warning: translation failed, new commands will be skipped"
    for entry in "${new_entries[@]}"; do
      name="${entry%%$'\t'*}"
      echo "    Missing: $name"
    done
  fi
fi

python3 -c "
import json

config_path = '$OCCONFIG'
tmp = '$TMP'

# 读取现有 commands
with open(config_path, 'r') as f:
    lines = [l for l in f if not l.strip().startswith('//')]
clean = '\n'.join(lines)
s = clean.index('{')
d, e, depth = s, 0, 0
for i in range(s, len(clean)):
    if clean[i] == '{': depth += 1
    elif clean[i] == '}': depth -= 1
    if depth == 0: e = i + 1; break
data = json.loads(clean[s:e])
cmds = data.get('command', {})

existing = {n: {'description': info.get('description', ''), 'template': info.get('template', '')} for n, info in cmds.items()}

# 读取中文描述映射
zh_map = {}
try:
    with open('$DESC_MAP', 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'): continue
            parts = line.split('|', 1)
            if len(parts) == 2 and parts[0].strip():
                zh_map[parts[0].strip()] = parts[1].strip()
except FileNotFoundError:
    pass

# 读取所有 skill names
with open(f'{tmp}/all_names.txt') as f:
    all_names = sorted([n.strip() for n in f if n.strip()])

# 插件 commands：name<TAB>path<TAB>desc
cmd_entries = {}
with open(f'{tmp}/cmd_entries.txt') as f:
    for line in f:
        parts = line.rstrip('\n').split('\t')
        if len(parts) >= 2:
            cmd_entries[parts[0]] = {'path': parts[1], 'desc': parts[2] if len(parts) > 2 else ''}

# 读取命令 body（去掉 frontmatter）作为 opencode template
def read_cmd_template(path):
    try:
        with open(path) as f:
            content = f.read()
        if content.startswith('---'):
            parts = content.split('---', 2)
            if len(parts) == 3:
                content = parts[2]
        content = content.replace('AskUserQuestion', 'question')
        return content.strip()
    except Exception:
        return None

# 检测变更
existing_names = sorted(existing.keys())
new_names = sorted(set(all_names) - set(existing_names))
removed_names = sorted(set(existing_names) - set(all_names))

if new_names:
    print(f'  New commands: {\" \".join(new_names)}')
if removed_names:
    print(f'  Removed commands: {\" \".join(removed_names)}')
if not new_names and not removed_names:
    print('  No changes')

# 构建 commands
# 只保留已存在的 OR commands-desc.txt 中有中文描述的 skill
commands = {}
skipped = []
for name in all_names:
    if name in existing:
        commands[name] = {'description': existing[name]['description'], 'template': existing[name].get('template', f'/{name}')}
    elif name in zh_map:
        commands[name] = {'description': zh_map[name], 'template': f'/{name}'}
    else:
        skipped.append(name)

# 插件 commands（无同名 skill 时使用 body 作为 template）
for name, info in cmd_entries.items():
    if name in commands:
        continue
    if name in existing:
        commands[name] = existing[name]
        continue
    template = read_cmd_template(info['path'])
    if template is None:
        continue
    desc = info['desc'] or existing.get(name, {}).get('description', '')
    commands[name] = {'description': desc, 'template': template}

# 写入（保留原有所有顶层 key，只更新 command）
data['command'] = commands
with open(config_path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print('  opencode.jsonc updated')
if skipped:
    print(f'  Skipped (not in commands-desc.txt): {\" \".join(skipped)}')
    print(f'  Add them to commands-desc.txt to appear in / command menu')
" 2>&1

echo "--- opencode commands sync complete ---"
