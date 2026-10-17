<div align="center">

# tmux-reorder-revamped

<strong>用鼠标在 tmux 状态栏上拖动窗口标签来移动该窗口。</strong>

[English](README.md) &nbsp;|&nbsp; [日本語](README.ja.md) &nbsp;|&nbsp; 简体中文 &nbsp;|&nbsp; [繁體中文（香港）](README.zh-HK.md)

[![Tests](https://github.com/tmux-revamped/tmux-reorder-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/tmux-revamped/tmux-reorder-revamped/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)

<p align="center">
  <a href="#what-it-does">功能</a> &nbsp;|&nbsp;
  <a href="#installation">安装</a> &nbsp;|&nbsp;
  <a href="#usage">用法</a> &nbsp;|&nbsp;
  <a href="#configuration">配置</a> &nbsp;|&nbsp;
  <a href="#key-bindings">按键绑定</a> &nbsp;|&nbsp;
  <a href="#how-it-works">工作原理</a>
</p>

</div>

**9 个根表鼠标绑定。不轮询。每次滑动只用一条 tmux 命令。已在 macOS 和 Linux 上测试。**

---

<a id="what-it-does"></a>

## 功能

按住一个标签并沿状态栏拖动。标签会跟随指针移动：每当指针进入另一个标签，被抓住的标签就占据它的位置，其他标签向旁边让开，就像浏览器标签一样。在你看到的位置松开即可。在 `status-left` 上松开会让它成为第一个窗口，在最后一个标签之后松开会让它成为最后一个窗口。

它只用原生 tmux，没有补丁，也不轮询。移动检测在 tmux 内部进行，只有当标签进入另一个标签时才运行一个简短的脚本。

## 环境要求

| 项目 | 版本或说明 |
|:------------|:----------------|
| tmux | 3.2 或更高版本。更旧的 tmux 上插件不绑定任何内容。所有支持的版本上标签都会滑到指针下方，3.8 及更高版本通过测量位置来判断 |
| 鼠标 | `set -g mouse on` |
| bash | 3.2 或更高版本，因此 macOS 自带的 `/bin/bash` 可以使用 |
| 操作系统 | Apple Silicon 和 Intel 上的 macOS，x86_64 和 arm64 上的 Linux |
| 核心工具 | BSD、GNU 或 uutils coreutils |

<a id="installation"></a>

## 安装

使用 [TPM](https://github.com/tmux-plugins/tpm) 时，把插件加入 `~/.tmux.conf`，然后按 `prefix + I`：

```tmux
set -g mouse on
set -g @plugin 'tmux-revamped/tmux-reorder-revamped'
```

不使用 TPM 时，克隆仓库，并在 `~/.tmux.conf` 中运行入口脚本：

```sh
git clone https://github.com/tmux-revamped/tmux-reorder-revamped ~/.tmux/plugins/tmux-reorder-revamped
```

```tmux
run-shell ~/.tmux/plugins/tmux-reorder-revamped/reorder-revamped.tmux
```

<a id="usage"></a>

## 用法

| 手势 | 结果 |
|:--------|:-------|
| 把一个标签拖到另一个标签上 | 按住按钮期间，被抓住的标签滑到该位置 |
| 在另一个标签上松开 | 窗口停留在它滑到的位置 |
| 在 `status-left` 上松开 | 窗口成为第一个窗口 |
| 在 `status-right` 上松开 | 窗口成为最后一个窗口 |
| 在最后一个标签之后的空白处松开 | 当 `status-justify` 为 `left` 时，窗口成为最后一个窗口 |
| 在抓住的标签上松开 | 什么都不移动 |

被拖动的窗口保持为当前窗口。窗口索引之间的空缺保持不变：窗口只是交换位置，不会重新编号。

<a id="configuration"></a>

## 配置

在插件加载之前于 `~/.tmux.conf` 中设置选项。模式、实时和边缘三个选项在加载时读取，修改后请重新加载配置。

| 选项 | 默认值 | 含义 |
|:-------|:--------|:--------|
| `@reorder_revamped_mode` | `insert` | `insert` 移动窗口并让中间的窗口依次移位。`swap` 只在松开时交换两个窗口，没有实时滑动 |
| `@reorder_revamped_live` | `on` | `off` 在拖动时保持标签不动，只在松开时移动窗口 |
| `@reorder_revamped_edges` | `on` | `off` 不在 `status-left`、`status-right` 和空白处绑定任何内容 |
| `@reorder_revamped_timeout` | `10` | 客户端活动超过这么多秒后，已记录的拖动会被忽略，因此在窗格上放弃的拖动不会在之后的松开时移动窗口 |
| `@reorder_revamped_enable_logging` | 未设置 | `1` 把失败的移动写入 `~/.tmux/reorder-revamped-logs/` |

```tmux
set -g @reorder_revamped_mode 'swap'
set -g @reorder_revamped_edges 'off'
```

### 内部状态

以下选项由插件自行管理，请勿设置。

| 选项 | 内容 |
|:-------|:------|
| `@reorder_revamped_source` | 拖动进行中被抓住的窗口 |
| `@reorder_revamped_seen` | 拖动最近一次移动时的客户端活动时间 |
| `@reorder_revamped_hit` | 把指针所在列映射到其下方标签的格式 |
| `@reorder_revamped_probe` | 最近一次移动时指针下方的标签 |
| `@reorder_revamped_hover` | 被抓住的标签最近一次滑到的标签 |
| `@reorder_revamped_pressed` | 最近一次在状态栏上按下时下方的标签 |
| `@reorder_revamped_pressed_at` | 那次按下时的客户端活动时间 |
| `@reorder_revamped_press_original` | 插件包装的 `MouseDown1Status` 命令 |

<a id="key-bindings"></a>

## 按键绑定

鼠标手势没有前缀，所以所有绑定都位于根表中。插件不绑定任何前缀键。

| 按键 | 作用 |
|:----|:-------|
| `MouseDown1Status` | 记录你按下的标签，然后运行原来的按下命令 |
| `SecondClick1Status`、`TripleClick1Status` | 同样记录按下，因为点击后很快的按下会被 tmux 报告为重复点击。如果你自己绑定过，则不改动 |
| `MouseUp1Status` | 普通点击时清除按下的记录。如果你自己绑定过，则不改动 |
| `MouseDrag1Status` | 第一次移动时记录被抓住的标签，之后每当指针进入另一个标签就滑动它 |
| `MouseDragEnd1Status` | 把被抓住的窗口移到指针下方的标签处 |
| `MouseDragEnd1StatusLeft` | 边缘启用时，把它移到最前 |
| `MouseDragEnd1StatusRight` | 边缘启用时，把它移到最后 |
| `MouseDragEnd1StatusDefault` | 边缘启用且窗口列表左对齐时，把它移到最后 |

只涉及一个 tmux 自带绑定 `MouseDown1Status`，插件包装它而不是替换它。原命令，默认是 `switch-client -t =`，在记录按下之后仍会运行，所以按下标签依然会选中窗口。原命令保存在 `@reorder_revamped_press_original` 中，因此重新加载不会把它包装两次。

<a id="how-it-works"></a>

## 工作原理

**抓取。** 拖动的第一次移动确定你按下的标签，插件用 `set-option -F` 把它存入服务器选项，这一步不启动任何进程。

**找到指针下方的标签。** 在 tmux 3.2 到 3.7 上，tmux 直接报告指针下方的标签。在 tmux 3.8 及更高版本上，tmux 在整个拖动过程中一直报告拖动开始时的标签，而用 `mouse_x` 跟踪真实的列。因此在这些版本上开始拖动时，`src/reorder.sh grab` 会用 tmux 自己的 `#{w:}` 宽度修饰符测量每个标签，这与状态栏本身使用的计算相同，并保存一个把 `mouse_x` 转换为指针下方标签的格式。每次移动都在 tmux 内部计算这个格式。

**滑动。** 只有当指针进入另一个标签时，插件才运行 `src/reorder.sh slide`。它用一条由相邻 `swap-window -d` 步骤组成的 tmux 命令移动被抓住的窗口，并在同一条命令中重新测量标签。测量需要左对齐、单行且能容纳整个窗口列表的状态栏。否则窗口只在松开时移动。

**忽略无关的拖动。** 只有在最近 10 秒内由按下标签开始的拖动才算数。从窗格内开始的拖动，例如在 vim 中选择文本，从未按下标签，因此经过或在状态栏上松开都不会移动任何东西。

## 开发

| 命令 | 作用 |
|:--------|:-------------|
| `make test` | 运行 bats 测试套件 |
| `make lint` | 对所有 shell 文件运行 shellcheck |
| `make coverage` | 用 kcov 测量行覆盖率，低于 95% 时失败，在 Linux 上运行 |

集成测试在使用空配置的私有套接字上启动自己的 tmux 服务器。鼠标测试把一个测试服务器的客户端连接到另一个服务器内部，并向其中输入 SGR 鼠标序列。

## 许可证

[MIT](LICENSE)

<!-- family:begin -->

## tmux-revamped 插件家族

本插件是 tmux-revamped 插件家族的一员。每个成员都带有 [`FAMILY.md`](FAMILY.md) 中的同一份约定、`family/` 下的同一套工具和同一个共享库，并由校验和清单保证逐字节一致。这些成员可以一起安装：任何成员都不会占用其他成员使用的按键或 tmux 选项。

在一个成员中发现的缺陷，要在全部成员中排查之后才算修复完成。这项义务写在约定里，而不是靠记忆，`family/bin/sweep` 负责执行它。

| 成员 | 功能 |
|---|---|
| [`tmux-autoreload-revamped`](https://github.com/tmux-revamped/tmux-autoreload-revamped) | 编辑并保存 tmux 配置后，它会自动重新加载，无需按键，也无需命令 |
| [`tmux-battery-revamped`](https://github.com/tmux-revamped/tmux-battery-revamped) | 在 tmux 状态栏显示电池状态，从不阻塞状态栏渲染 |
| [`tmux-bluetooth-revamped`](https://github.com/tmux-revamped/tmux-bluetooth-revamped) | 在 tmux 状态栏显示每个已连接的蓝牙设备及其电量，不阻塞渲染 |
| [`tmux-cpu-revamped`](https://github.com/tmux-revamped/tmux-cpu-revamped) | 在 tmux 状态栏显示 CPU 负载、温度和频率，从不阻塞渲染 |
| [`tmux-disk-revamped`](https://github.com/tmux-revamped/tmux-disk-revamped) | 在 tmux 状态栏显示磁盘用量，从不阻塞状态栏渲染 |
| [`tmux-extract-revamped`](https://github.com/tmux-revamped/tmux-extract-revamped) | 用 fzf 从屏幕上挑选 URL、路径、哈希或任意其他词元，并输入到光标处，全部用纯 shell 实现 |
| [`tmux-fzf-revamped`](https://github.com/tmux-revamped/tmux-fzf-revamped) | 在弹出窗口中的 fzf 选择器里切换、关闭、重命名或创建 tmux 会话、窗口和窗格 |
| [`tmux-git-revamped`](https://github.com/tmux-revamped/tmux-git-revamped) | 在 tmux 状态栏中显示活动窗格的 git 分支、改动和托管平台计数，且不阻塞渲染 |
| [`tmux-gpu-revamped`](https://github.com/tmux-revamped/tmux-gpu-revamped) | 在 tmux 状态栏中显示 NVIDIA、AMD、Intel 和 Apple GPU 的负载、温度、频率、功耗和显存 |
| [`tmux-kube-revamped`](https://github.com/tmux-revamped/tmux-kube-revamped) | 在 tmux 状态栏中显示当前的 Kubernetes 上下文和命名空间，不依赖 kubectl，直接解析 kubeconfig |
| [`tmux-launcher-revamped`](https://github.com/tmux-revamped/tmux-launcher-revamped) | 在弹出窗口或新窗口中启动任意 TUI 应用，从当前窗格的目录开始，每个应用可配置一个按键 |
| [`tmux-logging-revamped`](https://github.com/tmux-revamped/tmux-logging-revamped) | 将任意窗格保存到文件：实时日志、完整回滚缓冲区或一次性截图 |
| [`tmux-music-revamped`](https://github.com/tmux-revamped/tmux-music-revamped) | 在 tmux 状态栏显示正在播放的曲目，从不阻塞状态栏渲染 |
| [`tmux-network-revamped`](https://github.com/tmux-revamped/tmux-network-revamped) | 在 tmux 状态栏显示网络吞吐量，从不阻塞渲染 |
| [`tmux-pain-control-revamped`](https://github.com/tmux-revamped/tmux-pain-control-revamped) | tmux 的窗格和窗口管理按键，适配 tmux 版本，兼容 vim，每个 prefix 按键都可禁用 |
| [`tmux-persist-revamped`](https://github.com/tmux-revamped/tmux-persist-revamped) | 保存 tmux 的所有会话、窗口和窗格，按定时器自动保存，并在重启后全部恢复 |
| [`tmux-plugin-template`](https://github.com/tmux-revamped/tmux-plugin-template) | tmux-revamped 插件的起点：共享库、bats 测试框架、CI 和系列工具 |
| [`tmux-pomodoro-revamped`](https://github.com/tmux-revamped/tmux-pomodoro-revamped) | tmux 状态栏中的番茄钟计时器，所有状态都保存在 tmux 选项中，不使用临时文件 |
| [`tmux-ram-revamped`](https://github.com/tmux-revamped/tmux-ram-revamped) | 在 tmux 状态栏显示内存、交换空间和内存压力，在后台采样，渲染从不等待 |
| [`tmux-reorder-revamped`](https://github.com/tmux-revamped/tmux-reorder-revamped) | **本插件**，用鼠标在 tmux 状态栏上拖动窗口标签来移动该窗口 |
| [`tmux-scroll-revamped`](https://github.com/tmux-revamped/tmux-scroll-revamped) | 将鼠标滚轮交给能自行滚动的应用，其他情况下进入 tmux 复制模式 |
| [`tmux-sensible-revamped`](https://github.com/tmux-revamped/tmux-sensible-revamped) | 按 tmux 版本和终端区分的合理默认设置，不改动你自己设置的选项 |
| [`tmux-tiling-revamped`](https://github.com/tmux-revamped/tmux-tiling-revamped) | tmux 的平铺窗口管理：八种布局，包括 BSP dwindle 和 spiral，并支持撤销布局 |
| [`tmux-time-revamped`](https://github.com/tmux-revamped/tmux-time-revamped) | 状态栏中的本地时钟和世界时钟，按一天中的时段着色，并提供倒计时和夏令时提醒 |
| [`tmux-weather-revamped`](https://github.com/tmux-revamped/tmux-weather-revamped) | 在后台从 wttr.in 获取天气并显示在状态栏，状态栏无需等待 |

### 检查安装

所有成员都在磁盘上时，一条命令即可报告它们之间的任何冲突：

```sh
family/bin/doctor --live
```

它读取每个成员和正在运行的 tmux 服务器，报告重复的按键、重复的状态占位符、不符合命名规则的选项，以及约定版本落后的成员。

<!-- family:end -->
