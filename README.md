# Neovim MOS Plugin

在 **MOS NAS**（不可变、运行于 RAM 的 Devuan 系统）上安装并管理
[Neovim](https://neovim.io) 的插件实现仓库。

- Hub 索引条目在：[hustyanzu/mos-templates](https://github.com/hustyanzu/mos-templates)
- 本仓库只负责插件实现和 release `.deb`

---

## 它做什么

- 从官方 GitHub Releases 下载 Neovim Linux tarball（`amd64` / `arm64`）
- 把完整 release 树持久化到 `/boot/optional/plugins/neovim/nvim`
- 把运行树复制到 `/usr/lib/neovim`（RAM），避免 `/boot` noexec 的限制
- 安装 `/usr/bin/nvim` 包装脚本
- 把配置、数据、状态、缓存固定到持久化目录：
  - config: `/boot/optional/plugins/neovim/config/nvim`
  - data: `/boot/optional/plugins/neovim/data`
  - state: `/boot/optional/plugins/neovim/state`
  - cache: `/boot/optional/plugins/neovim/cache`
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
https://github.com/hustyanzu/mos-templates
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
XDG_DATA_HOME=/boot/optional/plugins/neovim/data
XDG_STATE_HOME=/boot/optional/plugins/neovim/state
XDG_CACHE_HOME=/boot/optional/plugins/neovim/cache
VIMRUNTIME=/usr/lib/neovim/share/nvim/runtime
```

默认配置路径：

```text
/boot/optional/plugins/neovim/config/nvim/init.lua
```

插件页可以创建一份基础的 `init.lua`；之后用 SSH 或 Filebrowser 编辑。
配置、插件数据和撤销历史都会在重启后保留。

---

## 设置

| 键 | 默认 | 说明 |
| --- | --- | --- |
| `auto_install` | `true` | 二进制缺失时自动下载 |
| `pin_version` | `""` | 固定 Neovim 版本，例如 `0.12.6`；空为最新 |
| `version` | `""` | 已安装版本，由插件维护 |

插件页的 **Install/Update** 始终安装最新 release；`pin_version` 只影响
`functions install` 的自动安装。

---

## 升级 / 卸载

**升级**：插件页 **Check updates** → **Update**。
后端会下载新 tarball、校验 sha256、替换持久化树，并刷新 `/usr/lib/neovim`。

**卸载**：卸载插件会移除 `/usr/bin/nvim` 和 `/usr/lib/neovim`；
`/boot/optional/plugins/neovim` 里的配置和数据会保留，需要时手动删除。

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