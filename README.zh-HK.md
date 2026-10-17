<div align="center">

# tmux-reorder-revamped

<strong>用滑鼠在 tmux 狀態列上拖動視窗標籤來移動該視窗。</strong>

[English](README.md) | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | 繁體中文（香港）

[![Tests](https://github.com/tmux-revamped/tmux-reorder-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/tmux-revamped/tmux-reorder-revamped/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)

<p align="center">
  <a href="#what-it-does">功能</a> |
  <a href="#installation">安裝</a> |
  <a href="#usage">用法</a> |
  <a href="#configuration">設定</a> |
  <a href="#key-bindings">按鍵綁定</a> |
  <a href="#how-it-works">運作原理</a>
</p>

</div>

**9 個根表滑鼠綁定。不輪詢。每次滑動只用一條 tmux 指令。已在 macOS 及 Linux 上測試。**

---

<a id="what-it-does"></a>

## 功能

按住一個標籤並沿狀態列拖動。標籤會跟隨指標移動：每當指標進入另一個標籤，被抓住的標籤便佔據它的位置，其他標籤向旁邊讓開，就像瀏覽器標籤一樣。在你看到的位置放開即可。在 `status-left` 上放開會令它成為第一個視窗，在最後一個標籤之後放開會令它成為最後一個視窗。

它只用原生 tmux，沒有修補，亦不輪詢。移動檢測在 tmux 內部進行，只有當標籤進入另一個標籤時才執行一個簡短的腳本。

## 系統要求

| 項目 | 版本或說明 |
|:------------|:----------------|
| tmux | 3.2 或以上。較舊的 tmux 上插件不會綁定任何東西。所有支援的版本上標籤都會滑到指標下方，3.8 或以上透過量度位置來判斷 |
| 滑鼠 | `set -g mouse on` |
| bash | 3.2 或以上，因此 macOS 內置的 `/bin/bash` 可以使用 |
| 作業系統 | Apple Silicon 及 Intel 上的 macOS，x86_64 及 arm64 上的 Linux |
| 核心工具 | BSD、GNU 或 uutils coreutils |

<a id="installation"></a>

## 安裝

使用 [TPM](https://github.com/tmux-plugins/tpm) 時，把插件加入 `~/.tmux.conf`，然後按 `prefix + I`：

```tmux
set -g mouse on
set -g @plugin 'tmux-revamped/tmux-reorder-revamped'
```

不使用 TPM 時，複製儲存庫，並在 `~/.tmux.conf` 中執行入口腳本：

```sh
git clone https://github.com/tmux-revamped/tmux-reorder-revamped ~/.tmux/plugins/tmux-reorder-revamped
```

```tmux
run-shell ~/.tmux/plugins/tmux-reorder-revamped/reorder-revamped.tmux
```

<a id="usage"></a>

## 用法

| 手勢 | 結果 |
|:--------|:-------|
| 把一個標籤拖到另一個標籤上 | 按住按鈕期間，被抓住的標籤滑到該位置 |
| 在另一個標籤上放開 | 視窗停留在它滑到的位置 |
| 在 `status-left` 上放開 | 視窗成為第一個視窗 |
| 在 `status-right` 上放開 | 視窗成為最後一個視窗 |
| 在最後一個標籤之後的空白處放開 | 當 `status-justify` 為 `left` 時，視窗成為最後一個視窗 |
| 在抓住的標籤上放開 | 甚麼都不會移動 |

被拖動的視窗保持為目前視窗。視窗索引之間的空缺維持不變：視窗只是交換位置，不會重新編號。

<a id="configuration"></a>

## 設定

在插件載入之前於 `~/.tmux.conf` 中設定選項。模式、即時及邊緣三個選項在載入時讀取，修改後請重新載入設定。

| 選項 | 預設值 | 含義 |
|:-------|:--------|:--------|
| `@reorder_revamped_mode` | `insert` | `insert` 移動視窗並令中間的視窗依次移位。`swap` 只在放開時交換兩個視窗，沒有即時滑動 |
| `@reorder_revamped_live` | `on` | `off` 在拖動時保持標籤不動，只在放開時移動視窗 |
| `@reorder_revamped_edges` | `on` | `off` 不在 `status-left`、`status-right` 及空白處綁定任何東西 |
| `@reorder_revamped_timeout` | `10` | 用戶端活動超過這麼多秒後，已記錄的拖動會被忽略，因此在窗格上放棄的拖動不會在之後放開時移動視窗 |
| `@reorder_revamped_enable_logging` | 未設定 | `1` 把失敗的移動寫入 `~/.tmux/reorder-revamped-logs/` |

```tmux
set -g @reorder_revamped_mode 'swap'
set -g @reorder_revamped_edges 'off'
```

### 內部狀態

以下選項由插件自行管理，請勿設定。

| 選項 | 內容 |
|:-------|:------|
| `@reorder_revamped_source` | 拖動進行中被抓住的視窗 |
| `@reorder_revamped_seen` | 拖動最近一次移動時的用戶端活動時間 |
| `@reorder_revamped_hit` | 把指標所在欄對應到其下方標籤的格式 |
| `@reorder_revamped_probe` | 最近一次移動時指標下方的標籤 |
| `@reorder_revamped_hover` | 被抓住的標籤最近一次滑到的標籤 |
| `@reorder_revamped_pressed` | 最近一次在狀態列上按下時下方的標籤 |
| `@reorder_revamped_pressed_at` | 那次按下時的用戶端活動時間 |
| `@reorder_revamped_press_original` | 插件包裝的 `MouseDown1Status` 指令 |

<a id="key-bindings"></a>

## 按鍵綁定

滑鼠手勢沒有前綴，所以所有綁定都位於根表中。插件不綁定任何前綴鍵。

| 按鍵 | 作用 |
|:----|:-------|
| `MouseDown1Status` | 記錄你按下的標籤，然後執行原來的按下指令 |
| `SecondClick1Status`、`TripleClick1Status` | 同樣記錄按下，因為點擊後很快的按下會被 tmux 報告為重複點擊。如你已自行綁定，則不改動 |
| `MouseUp1Status` | 普通點擊時清除按下的紀錄。如你已自行綁定，則不改動 |
| `MouseDrag1Status` | 第一次移動時記錄被抓住的標籤，之後每當指標進入另一個標籤就滑動它 |
| `MouseDragEnd1Status` | 把被抓住的視窗移到指標下方的標籤處 |
| `MouseDragEnd1StatusLeft` | 邊緣啟用時，把它移到最前 |
| `MouseDragEnd1StatusRight` | 邊緣啟用時，把它移到最後 |
| `MouseDragEnd1StatusDefault` | 邊緣啟用而視窗清單靠左對齊時，把它移到最後 |

只涉及一個 tmux 內置綁定 `MouseDown1Status`，插件包裝它而不是取代它。原指令，預設是 `switch-client -t =`，在記錄按下之後仍會執行，所以按下標籤依然會選取視窗。原指令儲存在 `@reorder_revamped_press_original` 中，因此重新載入不會把它包裝兩次。

<a id="how-it-works"></a>

## 運作原理

**抓取。** 拖動的第一次移動確定你按下的標籤，插件用 `set-option -F` 把它存入伺服器選項，這一步不會啟動任何進程。

**找出指標下方的標籤。** 在 tmux 3.2 至 3.7 上，tmux 直接報告指標下方的標籤。在 tmux 3.8 或以上，tmux 在整個拖動過程中一直報告拖動開始時的標籤，而用 `mouse_x` 追蹤真實的欄。因此在這些版本上開始拖動時，`src/reorder.sh grab` 會用 tmux 自己的 `#{w:}` 闊度修飾符量度每個標籤，這與狀態列本身使用的計算相同，並儲存一個把 `mouse_x` 轉換為指標下方標籤的格式。每次移動都在 tmux 內部計算這個格式。

**滑動。** 只有當指標進入另一個標籤時，插件才執行 `src/reorder.sh slide`。它用一條由相鄰 `swap-window -d` 步驟組成的 tmux 指令移動被抓住的視窗，並在同一條指令中重新量度標籤。量度需要靠左對齊、單行而且容得下整個視窗清單的狀態列。否則視窗只在放開時移動。

**忽略無關的拖動。** 只有在最近 10 秒內由按下標籤開始的拖動才算數。由窗格內開始的拖動，例如在 vim 中選取文字，從未按下標籤，因此經過或在狀態列上放開都不會移動任何東西。

## 開發

| 指令 | 作用 |
|:--------|:-------------|
| `make test` | 執行 bats 測試套件 |
| `make lint` | 對所有 shell 檔案執行 shellcheck |
| `make coverage` | 用 kcov 量度行覆蓋率，低於 95% 時失敗，在 Linux 上執行 |

整合測試在使用空設定的私人 socket 上啟動自己的 tmux 伺服器。滑鼠測試把一個測試伺服器的用戶端連接到另一個伺服器內部，並向其中輸入 SGR 滑鼠序列。

## 授權條款

[MIT](LICENSE)

<!-- family:begin -->

## tmux-revamped 插件家族

本插件是 tmux-revamped 插件家族的成員。每個成員都帶有 [`FAMILY.md`](FAMILY.md) 中的同一份約定、`family/` 下的同一套工具和同一個共用程式庫，並由校驗和清單確保逐位元組一致。這些成員可以一併安裝：任何成員都不會佔用其他成員使用的按鍵或 tmux 選項。

在一個成員中發現的缺陷，要在全部成員中排查後才算修正完成。這項責任寫在約定之中，而不是依靠記憶，`family/bin/sweep` 負責執行。

| 成員 | 功能 |
|---|---|
| [`tmux-autoreload-revamped`](https://github.com/tmux-revamped/tmux-autoreload-revamped) | 編輯並儲存 tmux 設定後，它會自動重新載入，毋須按鍵，也毋須指令 |
| [`tmux-battery-revamped`](https://github.com/tmux-revamped/tmux-battery-revamped) | 在 tmux 狀態列顯示電池狀態，從不阻塞狀態列繪製 |
| [`tmux-bluetooth-revamped`](https://github.com/tmux-revamped/tmux-bluetooth-revamped) | 在 tmux 狀態列顯示每部已連接的藍牙裝置及其電量，不阻塞繪製 |
| [`tmux-cpu-revamped`](https://github.com/tmux-revamped/tmux-cpu-revamped) | 在 tmux 狀態列顯示 CPU 負載、溫度及頻率，從不阻塞繪製 |
| [`tmux-disk-revamped`](https://github.com/tmux-revamped/tmux-disk-revamped) | 在 tmux 狀態列顯示磁碟用量，從不阻塞狀態列繪製 |
| [`tmux-extract-revamped`](https://github.com/tmux-revamped/tmux-extract-revamped) | 用 fzf 從畫面上揀選 URL、路徑、雜湊值或任何其他字詞，並輸入到游標位置，全部以純 shell 實現 |
| [`tmux-fzf-revamped`](https://github.com/tmux-revamped/tmux-fzf-revamped) | 在彈出視窗的 fzf 選擇器中切換、關閉、重新命名或建立 tmux 工作階段、視窗和窗格 |
| [`tmux-git-revamped`](https://github.com/tmux-revamped/tmux-git-revamped) | 在 tmux 狀態列顯示當前窗格的 git 分支、改動和託管平台數目，而不會阻塞顯示 |
| [`tmux-gpu-revamped`](https://github.com/tmux-revamped/tmux-gpu-revamped) | 在 tmux 狀態列顯示 NVIDIA、AMD、Intel 及 Apple GPU 的負載、溫度、時脈、功耗及記憶體 |
| [`tmux-kube-revamped`](https://github.com/tmux-revamped/tmux-kube-revamped) | 在 tmux 狀態列顯示目前的 Kubernetes 上下文及命名空間，毋須 kubectl，直接解析 kubeconfig |
| [`tmux-launcher-revamped`](https://github.com/tmux-revamped/tmux-launcher-revamped) | 在彈出視窗或新視窗中啟動任何 TUI 應用程式，從目前窗格的目錄開始，每個應用程式可設定一個按鍵 |
| [`tmux-logging-revamped`](https://github.com/tmux-revamped/tmux-logging-revamped) | 將任何窗格儲存到檔案：即時記錄、完整捲動緩衝區或一次性截圖 |
| [`tmux-music-revamped`](https://github.com/tmux-revamped/tmux-music-revamped) | 在 tmux 狀態列顯示正在播放的歌曲，從不阻塞狀態列的繪製 |
| [`tmux-network-revamped`](https://github.com/tmux-revamped/tmux-network-revamped) | 在 tmux 狀態列顯示網絡傳輸量，從不阻塞繪製 |
| [`tmux-pain-control-revamped`](https://github.com/tmux-revamped/tmux-pain-control-revamped) | tmux 的窗格和視窗管理按鍵，配合 tmux 版本，與 vim 相容，每個 prefix 按鍵都可停用 |
| [`tmux-persist-revamped`](https://github.com/tmux-revamped/tmux-persist-revamped) | 儲存 tmux 的所有工作階段、視窗及窗格，按計時器自動儲存，並在重新開機後全部還原 |
| [`tmux-plugin-template`](https://github.com/tmux-revamped/tmux-plugin-template) | tmux-revamped 插件的起點：共用程式庫、bats 測試框架、CI 和系列工具 |
| [`tmux-pomodoro-revamped`](https://github.com/tmux-revamped/tmux-pomodoro-revamped) | tmux 狀態列中的番茄鐘計時器，所有狀態都儲存在 tmux 選項中，不使用暫存檔 |
| [`tmux-ram-revamped`](https://github.com/tmux-revamped/tmux-ram-revamped) | 在 tmux 狀態列顯示記憶體、交換空間及記憶體壓力，在背景取樣，繪製從不等待 |
| [`tmux-reorder-revamped`](https://github.com/tmux-revamped/tmux-reorder-revamped) | **本插件**，用滑鼠在 tmux 狀態列上拖動視窗標籤來移動該視窗 |
| [`tmux-scroll-revamped`](https://github.com/tmux-revamped/tmux-scroll-revamped) | 將滑鼠滾輪交給能自行捲動的應用程式，其他情況下進入 tmux 複製模式 |
| [`tmux-sensible-revamped`](https://github.com/tmux-revamped/tmux-sensible-revamped) | 按 tmux 版本和終端機區分的合理預設設定，不會改動你自己設定的選項 |
| [`tmux-tiling-revamped`](https://github.com/tmux-revamped/tmux-tiling-revamped) | tmux 的平鋪視窗管理：八種版面，包括 BSP dwindle 和 spiral，並支援復原版面 |
| [`tmux-time-revamped`](https://github.com/tmux-revamped/tmux-time-revamped) | 狀態列中的本地時鐘和世界時鐘，按一天中的時段著色，並提供倒數和夏令時間提示 |
| [`tmux-weather-revamped`](https://github.com/tmux-revamped/tmux-weather-revamped) | 在背景從 wttr.in 取得天氣並顯示在狀態列，狀態列毋須等待 |

### 檢查安裝

所有成員都在磁碟上時，一個指令即可報告它們之間的任何衝突：

```sh
family/bin/doctor --live
```

它讀取每個成員和正在運行的 tmux 伺服器，報告重複的按鍵、重複的狀態佔位符、不符合命名規則的選項，以及約定版本落後的成員。

<!-- family:end -->
