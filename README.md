# Neovim MOS Plugin

在 **MOS NAS**（不可变、运行于 RAM 的 Devuan 系统）上安装并管理
[Neovim](https://neovim.io) 的插件实现仓库。

- Hub 索引条目在：[hustyanzu-mos/mos-templates](https://github.com/hustyanzu-mos/mos-templates)
- 本仓库只负责插件实现和架构对应的 release `.deb`

---

## 它做什么

- 在构建时把 Neovim 官方 release 树打进插件 `.deb`
- `.deb` 安装 Neovim 到 `/usr/lib/neovim`，安装 `/usr/bin/nvim` 包装脚本
- MOS 启动时重新安装 `.deb`，恢复 `/usr/lib` 和 `/usr/bin`
- `/boot` 只存 `.deb`、配置和数据，不存 Neovim 文件树
- 提供 MOS 插件页面：状态、配置路径、data_dir、创建默认 `init.lua`

编辑器更新通过新的插件 Release（和 `mos-vim` 一样），页面不再单独下载 Neovim。

---

## 仓库结构

```text
mos-neovim/
├── functions
├── settings.json
├── neovim-backend                 # /usr/bin/plugins/neovim
├── neovim-wrapper                 # /usr/bin/nvim
├── images/
│   └── neovim.png
├── page/                          # Vue 插件页面
├── build.sh
└── .github/workflows/build-plugin.yml
```

---

## 构建

本地（当前架构）：

```bash
./build.sh 0.2.0
```

输出：

```text
build/neovim-0.2.0-1+mos-plugin_amd64.deb
build/neovim-0.2.0-1+mos-plugin_amd64.deb.md5
```

GitHub Actions 会同时构建：

```text
neovim-0.2.0-1+mos-plugin_amd64.deb
neovim-0.2.0-1+mos-plugin_arm64.deb
```

Hub 会根据机器架构选择对应的 `.deb`。

---

## 发布与安装

```bash
git tag 0.2.0
git push origin 0.2.0
```

在 MOS 添加索引仓库：

```text
https://github.com/hustyanzu-mos/mos-templates
```

Refresh 后到 **Docker → MOS Hub → Plugins** 安装 **Neovim**。

安装后：

- `/usr/lib/neovim`：Neovim release 树
- `/usr/bin/nvim`：包装脚本
- 配置：`/boot/optional/plugins/neovim/config/nvim/init.lua`
- data：默认 `/run/neovim/data`（RAM），可设置 `data_dir` 持久化
- state/cache：默认 `/run/neovim`（RAM）

---

## 持久化

Hub 安装器会把 `.deb` 和 `functions` 放到：

```text
/boot/optional/plugins/neovim/<version>/
```

启动时 `installplugins-mos` 重新安装该 `.deb`，恢复 `/usr/lib/neovim` 和
`/usr/bin/nvim`。

- `/boot` 只放 `.deb` 和配置/数据，不放假 Neovim 树
- 配置持久化在 `/boot/optional/plugins/neovim/config`
- `data_dir` 留空时 data/cache 在 `/run/neovim`（RAM）
- 设置 `data_dir`（建议 pool appdata）后 data/cache 持久化
- state 始终在 `/run/neovim/state`（RAM，命令历史/undo 会丢）

`config`、`data`、`state`、`cache` 是四个独立的 XDG 根，不会互相覆盖。
但 `data_dir` 必须是绝对路径，且不能指向插件根目录/release 树/config；
页面和后端会拒绝。

### config 与 data 的依赖

如果 `init.lua` 持久化、插件在 RAM 的 data 里，重启后插件会消失。
插件型配置请设置持久 `data_dir`；空值适合不依赖外部插件的配置。

---

## 设置

| 键 | 默认 | 说明 |
| --- | --- | --- |
| `data_dir` | `""` | 留空则 data/cache 在 `/run/neovim`（RAM）；填了则持久化到该路径 |

---

## 升级 / 卸载

**升级**：MOS Hub 里刷新并更新 Neovim 插件，或安装新的插件 Release。
编辑器版本随 `.deb` 更新。

**卸载**：卸载插件会移除 `/usr/lib/neovim` 和 `/usr/bin/nvim`；
`/boot/optional/plugins/neovim` 里的配置和设置会保留。
如果设置过 `data_dir`，那份数据在 pool 上，不会自动删除。

---

## 排错

```bash
/usr/bin/plugins/neovim status
/usr/bin/plugins/neovim version
ls -la /usr/lib/neovim/bin/nvim
```

`nvim: command not found` 时重新安装 Neovim 插件，让 MOS 重新安装 `.deb`。

---

## 许可证

插件代码使用 MIT License。Neovim 由其官方 release 提供，遵循 Neovim 的上游许可。