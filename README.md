# Actions-OpenWrt-MT798X

基于 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) 模板，参考 Actions-OpenWrt-AN758X 项目的「源码基座 + 机型 diffconfig + diy 脚本」结构：

**一个 workflow，下拉选择机型，支持单个机型编译或三个机型全部编译；只用 padavanonly 源码和源码自带 feeds，不添加任何第三方插件源。**

## 支持的机型

| 机型 | 设备 profile | USB | `CONFIG_PACKAGE_autosamba` |
|------|--------------|-----|----------------------------|
| 锐捷 X60 | `ruijie_rg-x60-new-expand` | 无 | 关闭 |
| 锐捷 X60 Pro | `ruijie_rg-x60-pro-107m` | 无 | 关闭 |
| 磊科 N60 Pro | `netcore_n60-pro` | 有 | 启用 |

三个机型都是 `mediatek/filogic`（MT7986）。

## 源码

只用这一个：

| 仓库 | 分支 |
|------|------|
| https://github.com/padavanonly/immortalwrt-mt798x-6.6.git | `openwrt-24.10-6.6` |

不添加 helloworld、OpenClash、passwall 等第三方 feed；固件里的包全部来自源码自带的
`packages` / `luci` / `routing` / `telephony` 四个 feed。

## 目录结构

```
.github/workflows/build-immortalwrt.yml   # 唯一的构建 workflow
configs/
├── base/mt7986-ax6000.config             # 源码基座的仓库副本（源码里没有时兜底）
├── x60.config                            # 锐捷 X60 的机型 diffconfig
├── x60-pro.config                        # 锐捷 X60 Pro 的机型 diffconfig
└── n60-pro.config                        # 磊科 N60 Pro 的机型 diffconfig
scripts/
└── prepare-config.sh                     # 源码基座 + 机型 diffconfig -> .config
diy-part1.sh                              # feeds 之前：手工钩子（默认空文件）
diy-part2.sh                              # 配置载入后：手工钩子（默认空文件）
files/                                    # 可选：整目录覆盖到 openwrt/files
```

## 配置是怎么生效的

`configs/<机型>.config` 是 **diffconfig（只写非默认值）**，不是可以直接 `make` 的完整 `.config`。每次构建时：

1. 克隆 `padavanonly` 源码；
2. `scripts/prepare-config.sh` 用源码自带的 `defconfig/mt7986-ax6000.config` 打底；
3. 追加 `configs/<机型>.config`；
4. 强制只保留当前机型（关闭 `MULTI_PROFILE` / `PER_DEVICE_ROOTFS`，清掉其它设备）；
5. 执行 `diy-part2.sh`（默认空文件）；
6. `make defconfig` 展开成最终 `.config`。

所以：**配置都在仓库里，不需要手动上传 `.config`。**

## 和手动编译的对应关系

你的手动流程：

1. `git clone -b openwrt-24.10-6.6 ... https://github.com/padavanonly/immortalwrt-mt798x-6.6.git`
2. `./scripts/feeds update -a` / `./scripts/feeds install -a`
3. `cp -f defconfig/mt7986-ax6000.config .config`
4. `make menuconfig` 勾选插件
5. `make`

workflow 的对应步骤：

1. 克隆同一个仓库、同一个分支；
2. 执行同样的 `feeds update -a` / `feeds install -a`；
3. `prepare-config.sh` 做第 3 步（铺源码基座），并追加 `configs/<机型>.config`；
4. 你手动勾选的包已经写进 `configs/<机型>.config`，等价于 `make menuconfig`；
5. `make defconfig` 展开后编译。

你列出的勾选项在配置文件里的状态：

| 手动勾选 | x60 | x60-pro | n60-pro |
|----------|-----|---------|---------|
| `autocore-arm` | ✅ | ✅ | ✅ |
| `automount` | ✅ | ✅ | ✅ |
| `autosamba` | — | — | ✅ |
| `luci-app-autoreboot` | ✅ | ✅ | ✅ |
| `luci-app-ddns` | ✅ | ✅ | ✅ |
| `luci-app-homeproxy` | ✅ | ✅ | ✅ |
| `luci-app-ttyd` | ✅ | ✅ | ✅ |
| `luci-app-upnp` | ✅ | ✅ | ✅ |
| `luci-app-wechatpush` | ✅ | ✅ | ✅ |
| `luci-app-wol` | ✅ | ✅ | ✅ |
| `luci-theme-argon` | ✅ | ✅ | ✅ |
| `ddns-scripts-cloudflare` | ✅ | ✅ | ✅ |

另外：`passwall` 不在你的手动勾选列表里，源码 feeds 里也没有，所以没有保留。

## 换插件 / 改包

只允许使用源码 feeds 里已有的包。要增删 `configs/<机型>.config` 里的选项时：

```bash
# 在源码目录里
make menuconfig
make defconfig
./scripts/diffconfig.sh > /path/to/Actions-OpenWrt-MT798X/configs/<机型>.config
```

然后按需要保留文件顶部的机型/profile 注释和 `CONFIG_TARGET_*` 行。
`prepare-config.sh` 会强制写回目标机型，所以即使 diffconfig 里没有这些行也能构建。

如果配置里选了源码 feeds 中不存在的包，`make defconfig` 会把它静默剔除；
workflow 会在日志里用 `::warning` 列出被剔除的包，不会静默编出一个缺菜单的固件。

## 两个 diy 钩子

| 脚本 | 执行时机 | 作用 |
|------|----------|------|
| `diy-part1.sh` | `feeds update` 之前 | 默认空文件；需要改源码/加 feed 时再写 |
| `diy-part2.sh` | `.config` 载入后、`defconfig` 前 | 默认空文件；需要改默认值时再写 |

两个文件保持为空（只有 shebang），不改变源码默认值；workflow 仍然会调用它们，
方便以后需要时直接往里写内容。

`autosamba` 直接写在 `configs/<机型>.config` 里：

- `n60-pro`（有 USB）→ `CONFIG_PACKAGE_autosamba=y`
- `x60` / `x60-pro`（无 USB）→ `# CONFIG_PACKAGE_autosamba is not set`

workflow 在 `make defconfig` 后会校验一次，防止配置被 Kconfig 静默改掉。

## 使用方法

1. 打开仓库 **Actions** → **Build ImmortalWrt MT798X** → **Run workflow**。
2. 选择：

   | 输入项 | 说明 |
   |--------|------|
   | `device` | `all` / `x60` / `x60-pro` / `n60-pro` |
   | `branch` | 默认 `openwrt-24.10-6.6` |
   | `upload_release` | `true` 发布到 Release；`false` 只留 Artifact |
   | `ssh` | 调试用，仅仓库所有者，会阻塞构建 |

3. 产物：
   - **Artifact**：`OpenWrt_<机型>_<日期时间>`，保留 30 天。
   - **Release**：tag 为 `<机型>`，例如 `x60`；
     同一机型重复编译会更新同一个 Release 并覆盖同名固件。

### `device=all` 时会发生什么

`all` 展开成 **3 个并行 job**，每个机型一个 job：各自克隆源码、各自用 `configs/<机型>.config`、
各自产出 Artifact 和 Release。因此 N60 Pro 的 `autosamba` 不会被带进两个锐捷固件。

代价是消耗 3 份 Actions 分钟数；只编一台时直接选具体机型即可。

## 本地编译

```bash
cd /path/to/immortalwrt-mt798x-6.6
bash /path/to/Actions-OpenWrt-MT798X/scripts/prepare-config.sh x60 .
bash /path/to/Actions-OpenWrt-MT798X/diy-part2.sh
make defconfig
make download -j$(nproc)
make -j$(nproc)
```

## 缓存

- 只缓存 `dl/`（源码包），key 为 `mt798x-dl-<分支>-<年周>`，`all` 的三个 job 共享。
- 不缓存 `staging_dir` / `ccache`：三个机型配置不同，共享工具链缓存收益有限，缓存错代反而难查。
- 仓库 Actions 缓存配额 10GB，超出后 GitHub 按最近最少使用自动淘汰。

## 已知限制

- 单个 job 超时 350 分钟；MT7986 冷编译接近这个上限。
- 只用源码自带 feeds，不提供第三方 feed 开关；确实需要额外包时，请自行修改 workflow 或源码。
- `make defconfig` 会把 feeds 里不存在的包静默剔除。workflow 会列出被剔除的包，
  并强校验机型与 `autosamba`。
- `repository_dispatch` 触发时会用默认值（`all` + `upload_release=true`）。

## Credits

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI)
- [padavanonly/immortalwrt-mt798x-6.6](https://github.com/padavanonly/immortalwrt-mt798x-6.6)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)

## License

[MIT](LICENSE) © P3TERX
