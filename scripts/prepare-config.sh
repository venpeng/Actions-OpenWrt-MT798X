#!/usr/bin/env bash
# ================================================================
# prepare-config.sh —— 组装 .config（CI 和本地共用）
#
# 用法：
#   ./scripts/prepare-config.sh <机型> [源码目录]
#
# 机型：x60 / x60-pro
# 源码目录：默认当前目录（应指向 openwrt 源码根）
#
# 做的事：
#   1) 用源码自带的 defconfig/mt7986-ax6000.config 打底
#      （源码没有时回退到本仓库 configs/base/ 的副本）
#   2) 追加 configs/<机型>.config（唯一的一份机型配置）
#   3) 强制只保留一个机型（关掉 MULTI_PROFILE / PER_DEVICE_ROOTFS）
#
# 只用 padavanonly 一个源码：机型配置只有一份，
# 源码自带的 defconfig/mt7986-ax6000.config 负责目标平台默认值。
#
# diy-part1.sh / diy-part2.sh 默认留空，是 feeds 前 / 配置载入后的手工钩子。
# 本脚本只负责把 .config 拼好，之后统一 make defconfig。
# ================================================================
set -euo pipefail

DEVICE="${1:-}"
OPENWRT="${2:-.}"

if [ -z "$DEVICE" ]; then
    echo "用法: $0 <x60|x60-pro> [源码目录]" >&2
    exit 1
fi

case "$DEVICE" in
    x60)     PROFILE="ruijie_rg-x60-new-expand" ;;
    x60-pro) PROFILE="ruijie_rg-x60-pro-107m" ;;
    *)
        echo "::error::未知机型: ${DEVICE}（可选 x60 / x60-pro）" >&2
        exit 1
        ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/configs/${DEVICE}.config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "::error::机型配置不存在: ${CONFIG_FILE}" >&2
    exit 1
fi

cd "$OPENWRT"
if [ ! -f Makefile ] || [ ! -d scripts ]; then
    echo "::error::${OPENWRT} 看起来不是 OpenWrt 源码根目录" >&2
    exit 1
fi

# ----------------------------------------------------------------
# 1. 源码基座（各源码自己的 WiFi 固件等默认值就在这里）
# ----------------------------------------------------------------
BASE=""
for cand in configs/mt7986-ax6000.config defconfig/mt7986-ax6000.config; do
    if [ -f "$cand" ]; then
        BASE="$cand"
        break
    fi
done
if [ -z "$BASE" ] && [ -f "${REPO_ROOT}/configs/base/mt7986-ax6000.config" ]; then
    BASE="${REPO_ROOT}/configs/base/mt7986-ax6000.config"
fi

if [ -n "$BASE" ]; then
    cp "$BASE" .config
    echo "✅ 基座配置: ${BASE}"
else
    : > .config
    echo "::warning::源码和仓库都没有 mt7986-ax6000.config 基座，仅使用机型配置" >&2
fi

# ----------------------------------------------------------------
# 2. 机型 diffconfig
# ----------------------------------------------------------------
cat "$CONFIG_FILE" >> .config
echo "✅ 机型配置: ${CONFIG_FILE}"

# ----------------------------------------------------------------
# 3. 只保留一个机型
# ----------------------------------------------------------------
sed -i '/^CONFIG_TARGET_PROFILE=/d' .config
sed -i '/^CONFIG_TARGET_MULTI_PROFILE=/d; /^# CONFIG_TARGET_MULTI_PROFILE is not set/d' .config
sed -i '/^CONFIG_TARGET_PER_DEVICE_ROOTFS=/d; /^# CONFIG_TARGET_PER_DEVICE_ROOTFS is not set/d' .config
sed -i '/^CONFIG_TARGET_DEVICE_PACKAGES_/d' .config
sed -i '/^CONFIG_TARGET_mediatek_filogic_DEVICE_/d; /^# CONFIG_TARGET_mediatek_filogic_DEVICE_/d' .config

{
    echo '# CONFIG_TARGET_MULTI_PROFILE is not set'
    echo '# CONFIG_TARGET_PER_DEVICE_ROOTFS is not set'
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_${PROFILE}=y"
    echo "CONFIG_TARGET_PROFILE=\"DEVICE_${PROFILE}\""
} >> .config

echo "✅ 目标机型: ${PROFILE}"
echo "prepare-config.sh 完成；下一步执行 diy-part2.sh，再 make defconfig"
