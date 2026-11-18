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
- `/boot` 只存 `.deb`、`settings.json` 和 `packages`，不存 Neovim 配置/数据
- 配置和数据默认持久化到 `/mnt` 的 pool
- state/cache 放在 `/run/neovim`（RAM）
- 提供 MOS 插件页面：状态、pool 路径、配置/数据目录、创建默认 `init.lua`

编辑器更新通过新的插件 Release（和 `mos-vim` 一样），页面不单独下载 Neovim。

---

## 仓库结构

```text
mos-neovim/
├── functions
├── settings.json
├── neovim-env                     # 共享路径解析
├── neovim-backend                 # /usr/bin/plugins/neovim
├── neovim-wrapper                 # /usr/bin/nvim
├── debian/
│   ├── postinst
│   └── postrm
├── images/
│   └── neovim.png
├── page/                          # Vue 插件页面
├── build.sh
└── .github/workflows/build-plugin.yml
```

---

## 持久化位置

配置和数据不再放 `/boot`，默认自动选择：

```text
/mnt/cache/appdata/neovim/config
/mnt/cache/appdata/neovim/data
```

如果没有 `/mnt/cache`，会依次尝试：

```text
/mnt/user/appdata/neovim
/mnt/disk*/appdata/neovim
```

如果都没有检测到可写 pool，才退回 `/run/neovim`（RAM），页面会显示警告。

- 配置根：`.../neovim/config`，`init.lua` 在 `.../config/nvim/init.lua`
- 数据根：`.../neovim/data`
- state：`/run/neovim/state`（RAM，命令历史/undo 会丢）
- cache：`/run/neovim/cache`（RAM）

`config`、`data`、`state`、`cache` 是四个独立的 XDG 根，不会互相覆盖。

### 旧版本迁移

从 0.2.0 升级时：

- `/boot/optional/plugins/neovim/config` 会复制到新的 pool 配置根
- `/boot/optional/plugins/neovim/data` 会复制到新的 pool 数据根
- 旧文件不会删除，确认新位置正常后可以手动清理

---

## 构建

本地（当前架构）：

```bash
./build.sh 0.2.1
```

输出：

```text
build/neovim-0.2.1-1+mos-plugin_amd64.deb
build/neovim-0.2.1-1+mos-plugin_amd64.deb.md5
```

GitHub Actions 会同时构建：

```text
neovim-0.2.1-1+mos-plugin_amd64.deb
neovim-0.2.1-1+mos-plugin_arm64.deb
```

Hub 会根据机器架构选择对应的 `.deb`。

---

## 发布与安装

```bash
git tag 0.2.1
git push origin 0.2.1
```

在 MOS 添加索引仓库：

```text
https://github.com/hustyanzu-mos/mos-templates
```

Refresh 后到 **Docker → MOS Hub → Plugins** 安装 **Neovim**。

安装后：

- `/usr/lib/neovim`：Neovim release 树
- `/usr/bin/nvim`：包装脚本
- 配置：`/mnt/cache/appdata/neovim/config/nvim/init.lua`（自动检测）
- data：`/mnt/cache/appdata/neovim/data`（自动检测）
- state/cache：`/run/neovim`（RAM）

---

## 设置

| 键 | 默认 | 说明 |
| --- | --- | --- |
| `config_dir` | `""` | 留空使用自动检测的 pool 路径；填了用该绝对路径作为 XDG 配置根 |
| `data_dir` | `""` | 留空使用自动检测的 pool 路径；填 `/run/neovim/data` 可显式改回 RAM |

页面会显示实际的 `config_root`、`data_root` 和 Persistent/RAM 状态。
路径必须是绝对路径，不能指向 `/boot`、插件目录、release 树或 state/cache。

---

## 升级 / 卸载

**升级**：MOS Hub 里刷新并更新 Neovim 插件，或安装新的插件 Release。
编辑器版本随 `.deb` 更新。

**卸载**：卸载插件会移除 `/usr/lib/neovim` 和 `/usr/bin/nvim`；
pool 上的配置和数据不会删除。`/boot/optional/plugins/neovim/settings.json`
也会保留。

---

## 排错

```bash
/usr/bin/plugins/neovim status
/usr/bin/plugins/neovim version
ls -la /usr/lib/neovim/bin/nvim
```

`nvim: command not found` 时重新安装 Neovim 插件，让 MOS 重新安装 `.deb`。

页面显示 Storage 为 RAM 时：

1. 确认 `/mnt/cache` 或 `/mnt/user` 已经挂载
2. 在页面点 **Use pool defaults**，保存
3. 或手动填入 `/mnt/cache/appdata/neovim/config` 和
   `/mnt/cache/appdata/neovim/data`

---

## 许可证

插件代码使用 MIT License。Neovim 由其官方 release 提供，遵循 Neovim 的上游许可。