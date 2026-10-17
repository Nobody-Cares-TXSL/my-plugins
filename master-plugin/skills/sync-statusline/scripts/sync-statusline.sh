#!/usr/bin/env bash
# sync-statusline.sh — 自动同步 ~/.claude/statusline.zsh 的斜杠命令速查行
#
# 原理：
#   命令名   自动扫描（读 settings.json 的 enabledPlugins + 扫 cache 下已启用 mod 的源码；
#                        本插件技能则扫 skills/ 目录）
#   显示文本  人工维护（scripts/labels.txt 的「命令名<TAB>显示文本」映射表）
#   显示顺序  也由 labels.txt 的行序决定
#
# 用法：bash sync-statusline.sh [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABELS="$SCRIPT_DIR/labels.txt"
STATUSLINE="$HOME/.claude/statusline.zsh"
SETTINGS="$HOME/.claude/settings.json"
CACHE="$HOME/.claude/plugins/cache"
SKILLS_DIR="$SCRIPT_DIR/../.."   # scripts/ -> sync-statusline/ -> skills/

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

for f in "$LABELS" "$STATUSLINE" "$SETTINGS"; do
    [[ -f "$f" ]] || { echo "缺少文件: $f" >&2; exit 1; }
done

# ---------- 1. 扫描命令名 ----------

mod_cmds=$(python3 - "$SETTINGS" "$CACHE" <<'PYEOF'
import json, re, sys
from pathlib import Path

settings_path, cache_path = Path(sys.argv[1]), Path(sys.argv[2])
enabled = json.loads(settings_path.read_text(encoding="utf-8")).get("enabledPlugins", {})

names, seen = [], set()
for d in sorted(cache_path.glob("*/*/*/")):
    parts = d.parts
    pid = f"{parts[-2]}@{parts[-3]}"
    if not enabled.get(pid) or parts[-2] in seen:
        continue
    hj = d / "hooks" / "hooks.json"
    if not hj.is_file():
        continue
    try:
        mods = json.loads(hj.read_text(encoding="utf-8")).get("modules")
    except Exception:
        continue
    if not mods:
        continue  # 不是 mod
    for mp in mods:
        src = d / "hooks" / mp
        if not src.is_file():
            continue
        text = src.read_text(encoding="utf-8")
        for m in re.finditer(r"command\.register\(\s*\{(.*?)\}", text, re.S):
            nm = re.search(r"name:\s*'([^']+)'", m.group(1))
            if nm and nm.group(1) not in names:
                names.append(nm.group(1))
    seen.add(parts[-2])
print("\n".join(names))
PYEOF
)

plugin_cmds=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort || true)

# ---------- 2. 按 labels.txt 的分节与行序生成两行 ----------
# labels.txt 用 "# --- mods ---" / "# --- plugin ---" 标记分节，
# 节内行序即状态栏里的顺序。未出现在映射表里的命令追加到该行末尾。

build_line() {
    local detected="$1" section="$2"
    local out="" cur="" c label
    # 先按 labels.txt 顺序输出本节的条目（仅当该命令确实被检测到）
    while IFS=$'\t' read -r c label; do
        case "$c" in
            "# --- mods ---")   cur=mods;   continue ;;
            "# --- plugin ---") cur=plugin; continue ;;
            \#*) continue ;;
        esac
        [[ -z "$c" || "$cur" != "$section" ]] && continue
        grep -qxF "$c" <<<"$detected" || continue
        out="${out:+$out · }$label"
    done < "$LABELS"
    # labels.txt 即白名单：未列出的命令不显示（想显示就补一行）
    printf '%s' "$out"
}

line2=$(build_line "$mod_cmds" mods)
line3=$(build_line "$plugin_cmds" plugin)

# ---------- 3. 写回 statusline.zsh（哨兵注释之间替换） ----------

BEGIN_MODS="# >>> sync-statusline: mods >>>"
END_MODS="# <<< sync-statusline: mods <<<"
BEGIN_PLUGIN="# >>> sync-statusline: plugin >>>"
END_PLUGIN="# <<< sync-statusline: plugin <<<"

for marker in "$BEGIN_MODS" "$END_MODS" "$BEGIN_PLUGIN" "$END_PLUGIN"; do
    grep -qF "$marker" "$STATUSLINE" || {
        echo "哨兵注释缺失: $marker" >&2
        echo "请先在 statusline.zsh 里给第 2、3 行加上成对标记。" >&2
        exit 1
    }
done

echo "第 2 行: $line2"
echo "第 3 行: $line3"

if (( DRY_RUN )); then
    echo "（--dry-run：未写入）"
    exit 0
fi

tmp=$(mktemp)
awk -v bm="$BEGIN_MODS" -v em="$END_MODS" -v bp="$BEGIN_PLUGIN" -v ep="$END_PLUGIN" -v l2="$line2" -v l3="$line3" '
    $0 == bm { print; print "local line2=\"" l2 "\""; skip=1; next }
    $0 == em { skip=0 }
    $0 == bp { print; print "local line3=\"" l3 "\""; skip=1; next }
    $0 == ep { skip=0 }
    !skip { print }
' "$STATUSLINE" > "$tmp"

mv "$tmp" "$STATUSLINE"
echo "已写入 $STATUSLINE"
