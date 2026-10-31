#!/usr/bin/env bash
# check-hard-updates.sh — 发现并检查非包管理器安装的散装二进制
#
# 用法:
#   check-hard-updates.sh                              自动发现所有散装二进制（只读）
#   check-hard-updates.sh --download <url> [目标路径]   下载到 ~/下载 并生成安装命令（通用下载器）
#
# 设计原则：
#   - 软件列表不写死，自动扫描 + dpkg 归属判断得出
#   - 只读检查；下载后由用户手动安装，脚本不安装、不 sudo
set -euo pipefail

DL_DIR="$HOME/下载"
SCAN_DIRS=("/usr/local/bin" "$HOME/.local/bin" "$HOME/.cargo/bin" "/opt")

mkdir -p "$DL_DIR"

# 判断是否散装：非符号链接 + 不属于 dpkg + 是 ELF
is_standalone() {
  local f="$1"
  [ -f "$f" ] || return 1
  [ -L "$f" ] && return 1
  # 排除下载/备份残留（如 magpie.new），它们不是已安装的软件
  case "$(basename "$f")" in
    *.new|*.bak|*.old|*.tmp|*.download) return 1 ;;
  esac
  dpkg -S "$f" >/dev/null 2>&1 && return 1
  file -b "$f" 2>/dev/null | grep -q '^ELF' || return 1
  return 0
}

probe_version() {
  local f="$1"
  timeout 5 "$f" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "?"
}

SELF_UPDATE_TOOLS=("uv" "uvx" "magpie" "rustup" "cargo" "gh")

# 已知散装工具的上游：owner/repo 走 gh release；self: <cmd> 走工具自带检查。
# 未列出的显示 "-"，先用 gh search repos <name> 定位，不要猜仓库名。
declare -A UPSTREAM=(
  [lazygit]="jesseduffield/lazygit"
  [starship]="starship/starship"
  [ya]="sxyazi/yazi"
  [yazi]="sxyazi/yazi"
  [px0]="px0-ai/px0"
  [rtk]="rtk-ai/rtk"
  [alacritty]="alacritty/alacritty"
  [uv]="self: uv self update --dry-run"
  [uvx]="self: uv self update --dry-run"
  [magpie]="self: magpie update check"
  [rustup]="self: rustup check"
  [cargo]="self: rustup check"
)

upstream_info() {
  local name="$1"
  echo "${UPSTREAM[$name]:--}"
}

has_self_update() {
  local name="$1"
  for t in "${SELF_UPDATE_TOOLS[@]}"; do [ "$name" = "$t" ] && return 0; done
  return 1
}

# 判断更新方式：自更新 / cargo 更新 / 手动下载
update_method() {
  local name="$1" path="$2"
  if has_self_update "$name"; then echo "自更新"
  elif [[ "$path" == *"/.cargo/bin/"* ]]; then echo "cargo 更新"
  else echo "手动下载"
  fi
}

discover() {
  printf '%-14s %-34s %-9s %-6s %-9s %s\n' "软件" "路径" "版本" "属主" "更新方式" "上游/查新版"
  printf '%-14s %-34s %-9s %-6s %-9s %s\n' "----" "----" "----" "----" "--------" "----------"
  for dir in "${SCAN_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*; do
      is_standalone "$f" || continue
      local name ver owner how up
      name=$(basename "$f")
      ver=$(probe_version "$f")
      owner=$(stat -c '%U' "$f" 2>/dev/null || echo "?")
      how=$(update_method "$name" "$f")
      up=$(upstream_info "$name")
      printf '%-14s %-34s %-9s %-6s %-9s %s\n' "$name" "$f" "$ver" "$owner" "$how" "$up"
    done
  done
}

download_url() {
  local url="$1" target="${2:-}"
  [ -n "$url" ] || { echo "用法: check-hard-updates.sh --download <url> [目标路径]"; exit 1; }
  local fname="${url%%\?*}"
  fname="${fname##*/}"
  [ -n "$fname" ] || { echo "无法从 URL 推断文件名"; exit 1; }
  export http_proxy="${http_proxy:-http://127.0.0.1:7890}"
  export https_proxy="${https_proxy:-http://127.0.0.1:7890}"
  echo "下载: $url"
  echo "到:   $DL_DIR/$fname"
  timeout 600 curl -L --progress-bar -o "$DL_DIR/$fname" "$url"
  echo "完成: $DL_DIR/$fname"
  echo ""

  # 目标路径决定安装命令：目录可写则免 sudo，否则加 sudo
  local dir="" name="" sudo=""
  if [ -n "$target" ]; then
    dir=$(dirname "$target")
    name=$(basename "$target")
    [ -w "$dir" ] || sudo="sudo "
  fi

  echo "下一步（脚本不安装，请手动执行）："
  case "$fname" in
    *.tar.gz|*.tgz)
      if [ -n "$dir" ]; then
        echo "  ${sudo}tar -xzf ~/下载/$fname -C $dir $name"
      else
        echo "  解包后按包内结构替换目标二进制，例如："
        echo "    tar -xzf ~/下载/$fname -C /usr/local/bin <二进制名>   # 属主 root 时需 sudo"
      fi
      ;;
    *.tar.xz)
      if [ -n "$dir" ]; then
        echo "  ${sudo}tar -xJf ~/下载/$fname -C $dir $name"
      else
        echo "    tar -xJf ~/下载/$fname -C /usr/local/bin <二进制名>"
      fi
      ;;
    *.zip)
      if [ -n "$dir" ]; then
        echo "  unzip -o ~/下载/$fname $name -d $dir && ${sudo}chmod +x $target"
      else
        echo "    unzip ~/下载/$fname <二进制名> -d /usr/local/bin"
      fi
      ;;
    *.deb)
      echo "  sudo dpkg -i ~/下载/$fname"
      ;;
    *.rpm)
      echo "  sudo rpm -i ~/下载/$fname"
      ;;
    *)
      if [ -n "$dir" ]; then
        echo "  ${sudo}install -m755 ~/下载/$fname $target"
      else
        echo "    chmod +x ~/下载/$fname && sudo mv ~/下载/$fname <目标路径>"
      fi
      ;;
  esac
}

case "${1:-}" in
  --download) download_url "${2:-}" "${3:-}" ;;
  "")         discover ;;
  *)          echo "未知参数: $1"; echo "用法: check-hard-updates.sh [--download <url> [目标路径]]"; exit 1 ;;
esac
