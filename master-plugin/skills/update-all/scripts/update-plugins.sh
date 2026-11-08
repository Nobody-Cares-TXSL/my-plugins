#!/usr/bin/env bash
# update-plugins.sh — 更新所有已启用的 Claude Code 插件
set -euo pipefail

export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890

SETTINGS="$HOME/.claude/settings.json"

echo "--- Updating enabled Claude Code plugins ---"

# 读取已启用插件列表并逐个更新
# enabledPlugins 的值是布尔状态，只取明确为 true 的；只读键名会把禁用的也更新一遍
PLUGINS=$(python3 -c "
import json, sys
d = json.load(open('$SETTINGS'))
for k, v in d.get('enabledPlugins', {}).items():
    if v is True:
        print(k)
")

for plugin in $PLUGINS; do
  echo ">>> Updating $plugin"
  claude plugin update "$plugin" 2>&1
  echo ""
done

echo "--- Plugin update complete ---"
