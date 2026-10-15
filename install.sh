#!/usr/bin/env bash
# install.sh —— 安装「外语译词」功能到鼠鬚管（Squirrel）
#
# 作用：
#   1. 把 fanyi.lua 复制到 ~/Library/Rime/lua/
#   2. 把 cn2en.tsv 复制到 ~/Library/Rime/
#   3. 在各输入方案的 .custom.yaml 中挂载 lua 滤镜与配置
#   4. 触发重新部署
#
# 用法：
#   ./install.sh              # 安装/更新
#   ./install.sh --uninstall  # 卸载（移除挂载，保留词典与 lua 文件）
#
# 设计说明：
#   Rime 的 default.custom.yaml 补丁只作用于 default.yaml，
#   不会作用于各输入方案。因此译词配置与滤镜挂载必须写入
#   各方案的 .custom.yaml（wubi86.custom.yaml 等）。
#
#   本脚本用「清洗 + 追加」的方式保证幂等：每次安装都会先移除
#   文件中已有的 fanyi 相关行（fanyi/* 键、lua_filter@*fanyi 行、
#   以及本脚本生成的标记行），再追加一份干净区块。
#
# 重要：
#   挂载必须写 lua_filter@*fanyi，不能写 lua_filter@*fanyi.filter
#   （librime 会把 ".filter" 当成子目录/子表路径解析，导致组件异常、
#   候选栏变空）。

set -euo pipefail

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$PROJ_DIR"
DICT_DIR="$PROJ_DIR/dict"
RIME_DIR="$HOME/Library/Rime"
SQUIRREL_BIN="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"

# 需要挂载译词功能的方案。
# 可用环境变量 FANYI_SCHEMAS="rime_ice double_pinyin" 覆盖；
# 否则尝试从 ~/Library/Rime/default.custom.yaml 的 schema_list 自动探测；
# 都失败则用下面的默认值。
DEFAULT_SCHEMAS="wubi86 wubi_pinyin"

detect_schemas() {
  # 1) 环境变量优先
  if [ -n "${FANYI_SCHEMAS:-}" ]; then
    echo "$FANYI_SCHEMAS"
    return
  fi
  # 2) 从 default.custom.yaml 探测 schema_list
  local dc="$RIME_DIR/default.custom.yaml"
  if [ -f "$dc" ]; then
    local found
    found="$(grep -E '^[[:space:]]*-[[:space:]]*schema:' "$dc" \
      | sed -E 's/.*schema:[[:space:]]*//; s/[[:space:]]*#.*//' \
      | tr -d '"' | tr '\n' ' ')"
    if [ -n "$found" ]; then
      echo "$found"
      return
    fi
  fi
  # 3) 默认
  echo "$DEFAULT_SCHEMAS"
}

# 标记行（缩进位于 patch: 之下）
BEGIN_MARK="  ## >>> fanyi:begin (auto-generated)"
END_MARK="  ## <<< fanyi:end"

# 注入的配置键（已带缩进，位于 patch: 之下）
FANYI_KEYS='  fanyi/enabled: true
  fanyi/mode: replace
  fanyi/separator: " · "
  fanyi/dictionary: cn2en
  fanyi/overrides: cn_overrides
  fanyi/commit_enabled: true
  fanyi/commit_key: "Control+Return"
  engine/filters:
    - lua_filter@*fanyi
  "engine/processors/@before 0": lua_processor@*fanyi_commit'

log()  { printf "\033[32m[fanyi]\033[0m %s\n" "$*"; }
warn() { printf "\033[33m[fanyi]\033[0m %s\n" "$*"; }
err()  { printf "\033[31m[fanyi]\033[0m %s\n" "$*" >&2; }

# 清洗：移除文件中所有 fanyi 相关内容（键、filter 行、标记行、空 filters 行）
strip_fanyi() {
  local f="$1"
  [ -f "$f" ] || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0==b {next}
    $0==e {next}
    /^[[:space:]]*fanyi\// {next}
    /^[[:space:]]*engine\/filters:[[:space:]]*$/ {next}
    /^[[:space:]]*-[[:space:]]*lua_filter@\*fanyi[[:space:]]*$/ {next}
    /^[[:space:]]*"?engine\/processors\/@before 0"?[[:space:]]*:/ {next}
    {print}
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
}

# 卸载单方案
uninstall_from_schema() {
  local f="$RIME_DIR/${1}.custom.yaml"
  [ -f "$f" ] || return 0
  strip_fanyi "$f"
  log "已从 $f 移除 fanyi 配置"
}

# 安装单方案
install_to_schema() {
  local schema="$1"
  local f="$RIME_DIR/${schema}.custom.yaml"

  [ -f "$f" ] || { printf 'patch:\n' > "$f"; log "已创建 $f"; }

  # 先清洗旧内容，保证幂等
  strip_fanyi "$f"

  # 确保有顶层 patch:
  if ! grep -qE '^patch:[[:space:]]*$' "$f"; then
    printf '\npatch:\n' >> "$f"
  fi

  # 追加干净区块
  {
    printf '\n%s\n' "$BEGIN_MARK"
    printf '%s\n' "$FANYI_KEYS"
    printf '%s\n' "$END_MARK"
  } >> "$f"
  log "已挂载到 $f"
}

# 触发重新部署
redeploy() {
  if [ -x "$SQUIRREL_BIN" ]; then
    "$SQUIRREL_BIN" --reload >/dev/null 2>&1 || true
    log "已触发重新部署"
  else
    warn "未找到 Squirrel，请手动「重新部署」"
  fi
}

main() {
  # 解析要挂载的方案列表
  local schemas_str
  schemas_str="$(detect_schemas)"
  read -r -a SCHEMAS <<< "$schemas_str"
  log "目标方案: ${SCHEMAS[*]}"

  if [ "${1:-}" = "--uninstall" ]; then
    for s in "${SCHEMAS[@]}"; do
      uninstall_from_schema "$s"
    done
    redeploy
    log "卸载完成（词典与 lua 文件保留，如需彻底清理：rm $RIME_DIR/cn2*.tsv $RIME_DIR/cn_overrides.tsv $RIME_DIR/lua/fanyi*.lua）"
    exit 0
  fi

  mkdir -p "$RIME_DIR/lua"
  for lf in "$SRC_DIR"/lua/*.lua; do
    [ -f "$lf" ] || continue
    cp -f "$lf" "$RIME_DIR/lua/$(basename "$lf")"
    log "已安装 lua/$(basename "$lf")"
  done

  # 部署所有词典（cn2en.tsv、cn2ja.tsv、cn_overrides.tsv ...）
  for tsv in "$DICT_DIR"/*.tsv; do
    [ -f "$tsv" ] || continue
    cp -f "$tsv" "$RIME_DIR/$(basename "$tsv")"
    log "已安装 $(basename "$tsv")"
  done

  for s in "${SCHEMAS[@]}"; do
    install_to_schema "$s"
  done

  redeploy
  log "安装完成！切到目标方案输入几个字即可看到译词。"
  log "配置见 ~/Library/Rime/<方案>.custom.yaml 的 fanyi 区块。"
}

main "$@"
