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

# 判断是否散装：非符号链接 + 不属于 dpkg + 是 ELF
is_standalone() {
  local f="$1"
  [ -f "$f" ] || return 1
  [ -L "$f" ] && return 1
  # 排除下载/备份残留（如 magpie.new、foo.bak-20261109-012336），它们不是已安装的软件。
  # 注意 *.bak 匹配不到带时间戳后缀的 .bak-2026...，所以用 *.bak* 兜住两种形态。
  case "$(basename "$f")" in
    *.new|*.bak*|*.old|*.tmp|*.download) return 1 ;;
  esac
  dpkg -S "$f" >/dev/null 2>&1 && return 1
  file -b "$f" 2>/dev/null | grep -q '^ELF' || return 1
  return 0
}

probe_version() {
  local f="$1"
  timeout 5 "$f" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "?"
}

SELF_UPDATE_TOOLS=("uv" "uvx" "magpie" "rustup" "gh")

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
  [fzf]="junegunn/fzf"
  [uv]="self: uv self update --dry-run"
  [uvx]="self: uv self update --dry-run"
  [magpie]="self: magpie update check"
  [rustup]="self: rustup check"
  # cargo 不单列：它是 rustup 的符号链接，is_standalone 会直接排除，版本随 rustup toolchain 走
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

# 判断更新方式：自更新 / uv tool / cargo 更新 / 本地源码 / 手动下载
#
# cargo 一条不能只看路径：~/.cargo/bin/ 下混着 registry 安装和 --path 本地源码安装，
# 后者若按 `cargo install <名>` 更新，会从 crates.io 装回同名上游版本（可能是降级）。
# 权威判据是 ~/.cargo/.crates.toml 里的来源标记。
cargo_source_of() {
  local bin="$1"
  local toml="$HOME/.cargo/.crates.toml"
  [ -f "$toml" ] || return 0
  # 每行形如 "name ver (registry+https://...)" = ["bin1", "bin2"]
  # 找出 bins 列表里包含该命令名的行，回显其括号内来源
  while IFS= read -r line; do
    case "$line" in
      *"\"$bin\""*)
        printf '%s\n' "$line" | grep -oE '\((registry\+|path\+)[^)]*\)' | head -1 | tr -d '()'
        return 0
        ;;
    esac
  done < "$toml"
}

update_method() {
  local name="$1" path="$2"
  if has_self_update "$name"; then echo "自更新"
  elif [[ "$path" == *"/.local/share/uv/tools/"* ]]; then echo "uv tool"
  elif [[ "$path" == *"/.cargo/bin/"* ]]; then
    local src
    src=$(cargo_source_of "$name")
    case "$src" in
      path+file://*) echo "本地源码" ;;
      registry+*)    echo "cargo 更新" ;;
      *)             echo "cargo 更新" ;;
    esac
  else echo "手动下载"
  fi
}

# 本地源码安装的包，其源码目录（用于给出正确更新命令）
cargo_path_source_of() {
  local bin="$1"
  local toml="$HOME/.cargo/.crates.toml"
  [ -f "$toml" ] || return 0
  while IFS= read -r line; do
    case "$line" in
      *"\"$bin\""*)
        printf '%s\n' "$line" | grep -oE 'path\+file://[^)]*' | sed 's|^path+file://||' | head -1
        return 0
        ;;
    esac
  done < "$toml"
}

# uv tool 安装的命令是 ~/.local/bin 下的符号链接，is_standalone 会以 [ -L ] 排除，
# 因此单独扫描。用 `uv tool list` 取工具级清单——不要遍历 tools/*/bin/，
# 那里混着每个工具的全部依赖包可执行文件（python、tqdm、typer 等），会淹没有效信息。
discover_uv_tools() {
  command -v uv >/dev/null 2>&1 || return 0
  local line tool ver
  while IFS= read -r line; do
    case "$line" in
      # 工具行形如 "harlequin v2.16.2"，命令行以 "- " 开头
      -*) continue ;;
      "") continue ;;
    esac
    tool=$(printf '%s' "$line" | awk '{print $1}')
    ver=$(printf '%s' "$line" | awk '{print $2}' | tr -d 'v')
    [ -n "$tool" ] || continue
    local path
    path="$HOME/.local/bin/$tool"
    printf '%-14s %-34s %-9s %-6s %-9s %s\n' \
      "$tool" "$path" "$ver" "duan" "uv tool" "self: uv tool upgrade $tool"
  done < <(uv tool list 2>/dev/null)
}

discover() {
  printf '%-14s %-34s %-9s %-6s %-9s %s\n' "软件" "路径" "版本" "属主" "更新方式" "上游/查新版"
  printf '%-14s %-34s %-9s %-6s %-9s %s\n' "----" "----" "----" "----" "--------" "----------"
  discover_uv_tools
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
      # 本地源码安装没有 crates.io 上游可查。最后一列只放短标记保证表格对齐，
      # 完整命令另起一行输出——塞进表格会把 180+ 字符的行撑破对齐。
      local extra=""
      if [ "$how" = "本地源码" ]; then
        local src
        src=$(cargo_path_source_of "$name")
        up="⚠ 见下方"
        extra="         └ 源码: ${src:-未知}  →  cargo install --force --path ."
      fi
      printf '%-14s %-34s %-9s %-6s %-9s %s\n' "$name" "$f" "$ver" "$owner" "$how" "$up"
      [ -n "$extra" ] && printf '%s\n' "$extra"
    done
  done
}

download_url() {
  local url="$1" target="${2:-}"
  [ -n "$url" ] || { echo "用法: check-hard-updates.sh --download <url> [目标路径]"; exit 1; }
  local fname="${url%%\?*}"
  fname="${fname##*/}"
  [ -n "$fname" ] || { echo "无法从 URL 推断文件名"; exit 1; }
  mkdir -p "$DL_DIR"
  export http_proxy="${http_proxy:-http://127.0.0.1:7890}"
  export https_proxy="${https_proxy:-http://127.0.0.1:7890}"
  local dest="$DL_DIR/$fname"
  # 先下到临时文件再原子替换：curl -o 会先截断目标，下载失败会把已有的同名文件一起毁掉
  local tmp
  tmp="$(mktemp "$DL_DIR/.$fname.XXXXXX")"
  # 双引号：trap 在脚本退出时才执行，那时 local 已出作用域，必须当场展开路径
  trap "rm -f '$tmp'" EXIT
  echo "下载: $url"
  echo "到:   $dest"
  # -f 必不可少：GitHub 对不存在的 release 资产返回 404 页面而不是错误码，
  # 不加 -f 会把 "Not Found" 这几个字节当二进制存下来，还打印"完成"，
  # 照此安装会把目标程序替换成 9 字节的文本文件。
  if ! timeout 600 curl -fL --progress-bar -o "$tmp" "$url"; then
    echo "下载失败：$url" >&2
    echo "常见原因：资产名与版本不匹配（如该版本只发 musl 未发 gnu）。" >&2
    echo "先查实际资产名：" >&2
    echo "  gh release view --repo <owner/repo> --json assets -q '.assets[].name'" >&2
    echo "已保留原有文件：$dest" >&2
    exit 1
  fi
  # 双重保险：下载结果必须是可识别的包/可执行文件，不能是 HTML 或纯文本
  local size
  size="$(stat -c '%s' "$tmp")"
  if [ "$size" -lt 1024 ]; then
    echo "下载内容异常（$size 字节），已丢弃：$tmp" >&2
    echo "已保留原有文件：$dest" >&2
    exit 1
  fi
  mv -f "$tmp" "$dest"
  trap - EXIT
  echo "完成: $dest"
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
        # unzip 自己就要写 $dir，sudo 不能只加在后面的 chmod 上
        echo "  ${sudo}unzip -o ~/下载/$fname $name -d $dir && ${sudo}chmod +x $target"
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
