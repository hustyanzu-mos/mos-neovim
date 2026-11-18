# Neovim MOS Plugin

在 **MOS NAS**（不可变、运行于 RAM 的 Devuan 系统）上安装并管理
[Neovim](https://neovim.io) 的插件实现仓库。

- Hub 索引条目在：[hustyanzu-mos/mos-templates](https://github.com/hustyanzu-mos/mos-templates)
- 本仓库只负责插件实现和 release `.deb`

---

## 它做什么

- 从官方 GitHub Releases 下载 Neovim Linux tarball（`amd64` / `arm64`）
- 把完整 release 树持久化到 `/boot/optional/plugins/neovim/nvim`
- 把运行树复制到 `/usr/lib/neovim`（RAM），避免 `/boot` noexec 的限制
- 安装 `/usr/bin/nvim` 包装脚本
- 配置固定持久化；data 可选持久化；state/cache 默认放 `/run`（RAM）
  - config: `/boot/optional/plugins/neovim/config/nvim`
  - data: `data_dir`，留空时 `/run/neovim/data`
  - state: `/run/neovim/state`
  - cache: `/run/neovim/cache`
- 提供 MOS 插件页面：安装 / 更新 / 状态 / 创建默认 `init.lua`

配置本身**不需要**一个完整的 Web 编辑器：`init.lua` 在持久化目录里，
通过 SSH、MOS Terminal 或 Filebrowser 编辑即可。Vue 页面是 MOS 插件规范
要求的入口，这里只提供路径显示和“创建默认配置”按钮。

---

## 仓库结构

```text
mos-neovim/
├── functions
├── settings.json
├── neovim-backend                  # /usr/bin/plugins/neovim
├── neovim-wrapper                  # /usr/bin/nvim
├── images/
│   └── neovim.png
├── page/                           # Vue 插件页面
├── build.sh
└── .github/workflows/build-plugin.yml
```

---

## 构建

```bash
./build.sh 0.1.0
```

输出：

```text
build/neovim-0.1.0-1+mos-plugin_all.deb
build/neovim-0.1.0-1+mos-plugin_all.deb.md5
```

---

## 发布与安装

```bash
git tag 0.1.0
git push origin 0.1.0
```

GitHub Actions 构建 `.deb` + `.md5` 并创建 Release。

在 MOS 添加索引仓库：

**Settings → System Configuration → MOS Hub Settings → Add Repository**

```text
https://github.com/hustyanzu-mos/mos-templates
```

Refresh 后到 **Docker → MOS Hub → Plugins** 安装 **Neovim**，然后在插件页
点击 **Install**。

也可以手动安装：

```bash
dpkg -i neovim-0.1.0-1+mos-plugin_all.deb
/usr/bin/plugins/neovim install_binary
```

---

## 使用

```bash
nvim
nvim /mnt/cache/some-file.txt
```

包装脚本会设置：

```text
XDG_CONFIG_HOME=/boot/optional/plugins/neovim/config
XDG_STATE_HOME=/run/neovim/state        # RAM，重启清空（命令历史/undo/shada）
XDG_DATA_HOME=/run/neovim/data          # 默认 RAM；设置 data_dir 后改为持久路径
XDG_CACHE_HOME=/run/neovim/cache        # 默认 RAM；设置 data_dir 后改为 <data_dir>/cache
VIMRUNTIME=/usr/lib/neovim/share/nvim/runtime
```

默认配置路径：

```text
/boot/optional/plugins/neovim/config/nvim/init.lua
```

插件页可以创建一份基础的 `init.lua`；之后用 SSH 或 Filebrowser 编辑。
配置会持久保留；state/cache 默认在 `/run/neovim`（内存），
如果填了 `data_dir`（例如 `/mnt/cache/appdata/neovim`），data/cache 会持久化。
state 丢失只会影响命令历史、marks、寄存器和 undo，不影响配置或插件。

---

## 持久化

MOS 的 Hub 安装器会把 `.deb` 和 `functions` 放到：

```text
/boot/optional/plugins/neovim/<version>/
```

并在插件根目录写 `template.json`。启动时 `installplugins-mos` 会重新安装该
`.deb`，`mos_start` 会恢复 `/usr/bin`/`/usr/lib` 里的运行时。

- 配置：`/boot/optional/plugins/neovim/config`
- 数据：`data_dir`；留空时是 `/run/neovim/data`（RAM，重启清空）
- state/cache：`/run/neovim/state`、`/run/neovim/cache`（RAM，重启清空）
- 运行时：`/usr/lib/neovim`（RAM，重启后从持久化树复制）
- `/boot/optional/plugins/neovim/nvim`：官方 release 树（持久化）

如果手动 `dpkg -i`，插件只对当前运行有效；要让它重启后仍然存在，请使用
MOS Hub，或把 `.deb`/`functions` 放到版本目录并补上 `template.json`。

---

## 设置

| 键 | 默认 | 说明 |
| --- | --- | --- |
| `auto_install` | `true` | 二进制缺失时自动下载 |
| `pin_version` | `""` | 固定 Neovim 版本，例如 `0.12.6`；空为最新 |
| `version` | `""` | 已安装版本，由插件维护 |
| `data_dir` | `""` | 可选。留空则 data/cache 在 `/run/neovim`（内存，重启清空）；填了则持久化到该路径（pool 如 `/mnt/cache/appdata/neovim`，或 `/boot/optional/plugins/neovim/data`） |

MOS 建议把会持续增长或频繁写入的数据放到 pool/appdata，而不是 USB 的
`/boot`。配置很小，留在 `/boot`；state/cache 默认在 RAM，`data_dir` 留空时
数据也在 RAM，填了才持久化到 pool。

`config`、`data`、`state`、`cache` 是四个独立的 XDG 根，不会互相覆盖。
但 `data_dir` 必须是绝对路径，并且不能指向插件根目录
（`/boot/optional/plugins/neovim`）、release 树（`.../nvim`）或配置目录
（`.../config`）；页面和后端会拒绝这种填法，避免和插件文件混在一起。

### config 与 data 的依赖

路径上不冲突，但依赖上会：如果 `init.lua` 是持久的，而插件装在 RAM 的
`data` 里，重启后 `init.lua` 引用的插件会消失。

- **插件型配置**：把 `data_dir` 设成持久路径。推荐 pool appdata，例如
  `/mnt/cache/appdata/neovim`；也可以退回 `/boot/optional/plugins/neovim/data`，
  但会占 USB 空间/写入。
- **空 `data_dir`（RAM）**：适合不依赖外部插件的配置，或者 `init.lua` 自带
  lazy.nvim 自举、每次启动重新安装插件（需要网络）。
- 插件页在检测到 `init.lua` 存在且 data 在 RAM 时会显示警告，并提供
  **Use persistent data** 按钮；它会先填 `/boot/optional/plugins/neovim/data`，
  你可以改成 pool 路径再保存。

插件页的 **Install/Update** 始终安装最新 release；`pin_version` 只影响
`functions install` 的自动安装。

---

## 升级 / 卸载

**升级**：插件页 **Check updates** → **Update**。
后端会下载新 tarball、校验 sha256、替换持久化树，并刷新 `/usr/lib/neovim`。

**卸载**：卸载插件会移除 `/usr/bin/nvim` 和 `/usr/lib/neovim`；
`/boot/optional/plugins/neovim` 里的配置会保留，需要时手动删除。
如果设置过 `data_dir`，那份数据在 pool 上，不会自动删除；state 在 RAM，重启即消失。

---

## 排错

```bash
/usr/bin/plugins/neovim status
/usr/bin/plugins/neovim version
/usr/bin/plugins/neovim install_binary latest
```

- 确认 `/usr/lib/neovim/bin/nvim` 存在；缺失时执行
  `/usr/bin/plugins/neovim ensure_runtime`。
- 确认架构：`uname -m`（`x86_64` / `aarch64`）。
- `/boot` 不可执行是正常的；实际运行的是 `/usr/lib/neovim` 的 RAM 副本。

---

## 许可证

插件代码使用 MIT License。Neovim 由其官方 release 提供，遵循 Neovim 的上游许可。