#!/usr/bin/env bash
# ================================================================
# diy-part3.sh —— 将手动勾选的源码内插件写入当前机型 .config
# 运行目录：ImmortalWrt 源码根目录；应在配置载入后、make defconfig 前运行。
#
# 新增/删除源码内插件时，只需编辑 PLUGINS 数组。
# 插件应来自本源码或已安装的 feeds；本脚本不会添加第三方 feed。
# ================================================================
set -euo pipefail

echo "=========================================="
echo "追加手动插件 (diy-part3.sh)"
echo "=========================================="

if [ ! -f .config ]; then
  echo "::error::未找到 .config；请在源码根目录、配置载入后运行"
  exit 1
fi

# 自定义插件
PLUGINS=(
  luci-app-autoreboot
  luci-app-ddns
  luci-app-homeproxy
  luci-app-ttyd
  luci-app-upnp
  luci-app-wechatpush
  luci-app-wol
  luci-theme-argon
  ddns-scripts-cloudflare
)

# 直接写入配置，最终由 workflow 在 defconfig
# 之后检查 CONFIG_PACKAGE_* 是否仍然保留；不存在的包会在那里给出明确错误。

set_package() {
  local pkg="$1" sym="CONFIG_PACKAGE_$1"
  sed -i -e "/^${sym}=/d" \
         -e "/^#[[:space:]]*${sym}[[:space:]=]/d" .config
  printf '%s=y\n' "$sym" >> .config
}

for pkg in "${PLUGINS[@]}"; do
  set_package "$pkg"
  echo "  + $pkg"
done

printf '%s\n' "${PLUGINS[@]}" > .diy-part3-packages
echo "已追加 ${#PLUGINS[@]} 个插件；make defconfig 后可据此复核。"
