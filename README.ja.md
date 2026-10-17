<div align="center">

# tmux-reorder-revamped

<strong>tmuxのステータスバー上でウィンドウのタブをマウスでドラッグして、そのウィンドウを移動します。</strong>

[English](README.md) &nbsp;|&nbsp; 日本語 &nbsp;|&nbsp; [简体中文](README.zh-Hans.md) &nbsp;|&nbsp; [繁體中文（香港）](README.zh-HK.md)

[![Tests](https://github.com/tmux-revamped/tmux-reorder-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/tmux-revamped/tmux-reorder-revamped/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)

<p align="center">
  <a href="#what-it-does">概要</a> &nbsp;|&nbsp;
  <a href="#installation">インストール</a> &nbsp;|&nbsp;
  <a href="#usage">使い方</a> &nbsp;|&nbsp;
  <a href="#configuration">設定</a> &nbsp;|&nbsp;
  <a href="#key-bindings">キーバインド</a> &nbsp;|&nbsp;
  <a href="#how-it-works">仕組み</a>
</p>

</div>

**ルートテーブルのマウスバインドは9個です。ポーリングはしません。スライド1回につきtmuxコマンドは1つです。macOSとLinuxでテストしています。**

---

<a id="what-it-does"></a>

## 概要

タブを押してバーに沿ってドラッグします。タブはポインターと一緒に動きます。ポインターが別のタブに入るたびに、つかんだタブがその位置に入り、他のタブは横にずれます。ブラウザーのタブと同じ動きです。見えている位置で離してください。`status-left`の上で離すと最初のウィンドウに、最後のタブより右で離すと最後のウィンドウになります。

パッチもポーリングもない、素のtmuxで動きます。動きの判定はtmuxの中で行い、タブが別のタブに入ったときだけ短いスクリプトが動きます。

## 必要なもの

| 項目 | バージョンや補足 |
|:------------|:----------------|
| tmux | 3.2以降。それより古いtmuxでは何も割り当てません。対応するすべてのバージョンでタブはポインターの下へスライドし、3.8以降では位置を測って判定します |
| マウス | `set -g mouse on` |
| bash | 3.2以降。macOS標準の`/bin/bash`で動きます |
| OS | Apple SiliconとIntelのmacOS、x86_64とarm64のLinux |
| 基本コマンド | BSD、GNU、uutilsのいずれのcoreutilsでも動きます |

<a id="installation"></a>

## インストール

[TPM](https://github.com/tmux-plugins/tpm)を使う場合は、`~/.tmux.conf`にプラグインを追加して`prefix + I`を押します。

```tmux
set -g mouse on
set -g @plugin 'tmux-revamped/tmux-reorder-revamped'
```

TPMを使わない場合は、リポジトリをクローンし、`~/.tmux.conf`からエントリーポイントを実行します。

```sh
git clone https://github.com/tmux-revamped/tmux-reorder-revamped ~/.tmux/plugins/tmux-reorder-revamped
```

```tmux
run-shell ~/.tmux/plugins/tmux-reorder-revamped/reorder-revamped.tmux
```

<a id="usage"></a>

## 使い方

| 操作 | 結果 |
|:--------|:-------|
| タブを別のタブの上へドラッグする | ボタンを押している間に、つかんだタブがその位置へスライドします |
| 別のタブの上で離す | ウィンドウはスライドした位置に留まります |
| `status-left`の上で離す | ウィンドウが最初のウィンドウになります |
| `status-right`の上で離す | ウィンドウが最後のウィンドウになります |
| 最後のタブの後ろの空白で離す | `status-justify`が`left`のとき、ウィンドウが最後のウィンドウになります |
| つかんだタブの上で離す | 何も動きません |

ドラッグしたウィンドウは現在のウィンドウのままです。ウィンドウのインデックスの欠番はそのまま残ります。ウィンドウ同士が位置を入れ替えるだけで、インデックスの振り直しはしません。

<a id="configuration"></a>

## 設定

オプションはプラグインを読み込む前に`~/.tmux.conf`で設定します。モード、ライブ、端の設定は読み込み時に読むので、変更したら設定を再読み込みしてください。

| オプション | 既定値 | 意味 |
|:-------|:--------|:--------|
| `@reorder_revamped_mode` | `insert` | `insert`はウィンドウを移動し、間にあるウィンドウをずらします。`swap`は離したときに2つのウィンドウだけを入れ替え、ライブのスライドはしません |
| `@reorder_revamped_live` | `on` | `off`にするとドラッグ中はタブを動かさず、離したときだけウィンドウを移動します |
| `@reorder_revamped_edges` | `on` | `off`にすると`status-left`、`status-right`、空白部分に何も割り当てません |
| `@reorder_revamped_timeout` | `10` | クライアントの操作がこの秒数を超えると、記録したドラッグを無視します。ペインの上で放棄したドラッグが、後の無関係な離す操作でウィンドウを動かすことはありません |
| `@reorder_revamped_enable_logging` | 未設定 | `1`で失敗した移動を`~/.tmux/reorder-revamped-logs/`に書きます |

```tmux
set -g @reorder_revamped_mode 'swap'
set -g @reorder_revamped_edges 'off'
```

### 内部状態

以下のオプションはプラグインが自分で管理します。設定しないでください。

| オプション | 内容 |
|:-------|:------|
| `@reorder_revamped_source` | ドラッグ中につかんでいるウィンドウです |
| `@reorder_revamped_seen` | ドラッグの最新の動きの時点でのクライアントの操作時刻です |
| `@reorder_revamped_hit` | ポインターの列をその下のタブに対応させる書式です |
| `@reorder_revamped_probe` | 最新の動きの時点でポインターの下にあったタブです |
| `@reorder_revamped_hover` | つかんだタブが最後にスライドした先のタブです |
| `@reorder_revamped_pressed` | ステータスバーで最後に押したときの下にあったタブです |
| `@reorder_revamped_pressed_at` | その押下の時点でのクライアントの操作時刻です |
| `@reorder_revamped_press_original` | プラグインが包み込む`MouseDown1Status`のコマンドです |

<a id="key-bindings"></a>

## キーバインド

マウスの操作にはプレフィックスがないため、すべてのバインドはルートテーブルにあります。プレフィックスキーは割り当てません。

| キー | 動作 |
|:----|:-------|
| `MouseDown1Status` | 押したタブを記録し、元の押下コマンドを実行します |
| `SecondClick1Status`、`TripleClick1Status` | クリック直後の押下をtmuxは連続クリックとして報告するため、これらでも押下を記録します。自分で割り当てている場合は触れません |
| `MouseUp1Status` | 単なるクリックでは押下の記録を消します。自分で割り当てている場合は触れません |
| `MouseDrag1Status` | 最初の動きでつかんだタブを記録し、ポインターが別のタブに入るたびにスライドさせます |
| `MouseDragEnd1Status` | つかんだウィンドウをポインターの下のタブの位置へ移動します |
| `MouseDragEnd1StatusLeft` | 端の設定が有効なとき、最初へ移動します |
| `MouseDragEnd1StatusRight` | 端の設定が有効なとき、最後へ移動します |
| `MouseDragEnd1StatusDefault` | 端の設定が有効で、ウィンドウの一覧が左寄せのとき、最後へ移動します |

関わる標準のバインドは`MouseDown1Status`だけで、プラグインはそれを置き換えずに包み込みます。元のコマンド、既定では`switch-client -t =`は押下を記録した後も実行されるので、タブを押せば今までどおりウィンドウを選べます。元のコマンドは`@reorder_revamped_press_original`に保存するため、再読み込みしても二重に包むことはありません。

<a id="how-it-works"></a>

## 仕組み

**つかむ。** ドラッグの最初の動きで押したタブが分かり、プラグインはそれを`set-option -F`でサーバーのオプションに保存します。これはプロセスを起動しません。

**ポインターの下のタブを見つける。** tmux 3.2から3.7では、tmuxがポインターの下のタブを直接報告します。tmux 3.8以降では、ドラッグを始めたタブを報告し続け、実際の列は`mouse_x`で追います。そのため、そこでドラッグが始まると`src/reorder.sh grab`がtmux自身の`#{w:}`幅修飾子ですべてのタブを測ります。これはステータス行自体が使う計算と同じです。そして`mouse_x`をポインターの下のタブに変える書式を保存します。動くたびに、その書式をtmuxの中で評価します。

**スライド。** ポインターが別のタブに入ったときだけ、プラグインは`src/reorder.sh slide`を実行します。隣り合う`swap-window -d`の手順からなる1つのtmuxコマンドでつかんだウィンドウを動かし、同じコマンドでタブを測り直します。測定には、左寄せで1行のステータスバーと、収まりきるウィンドウの一覧が必要です。そうでない場合、ウィンドウは離したときだけ動きます。

**関係ないドラッグを無視する。** ドラッグは、直近10秒以内にタブを押して始まった場合だけ有効です。vimでのテキスト選択のようにペインの中で始まったドラッグはタブを押していないので、バーを横切っても離しても何も動きません。

## 開発

| コマンド | 内容 |
|:--------|:-------------|
| `make test` | batsのテストスイートを実行します |
| `make lint` | すべてのシェルファイルにshellcheckを実行します |
| `make coverage` | kcovで行カバレッジを測り、95パーセント未満なら失敗します。Linuxで動きます |

統合テストは、空の設定を使うプライベートなソケットで独自のtmuxサーバーを起動します。マウスのテストでは、あるテスト用サーバーのクライアントを別のサーバーの中で接続し、SGRのマウスシーケンスを入力します。

## ライセンス

[MIT](LICENSE)

<!-- family:begin -->

## tmux-revamped ファミリー

このプラグインはtmux-revampedファミリーの一員です。すべてのメンバーは[`FAMILY.md`](FAMILY.md)にある同じ規約、`family/`配下の同じツール、同じ共有ライブラリを持ち、それらはチェックサムのマニフェストによってバイト単位で同一に保たれています。メンバーは一緒にインストールする前提で作られており、あるメンバーが使うキーやtmuxオプションを別のメンバーが使うことはありません。

あるメンバーで見つかった不具合は、修正完了とする前にすべてのメンバーで探します。この義務は記憶に頼らず規約に書かれており、`family/bin/sweep`がそれを果たす手段です。

| メンバー | 内容 |
|---|---|
| [`tmux-autoreload-revamped`](https://github.com/tmux-revamped/tmux-autoreload-revamped) | tmuxの設定を編集して保存するだけで、キーもコマンドも使わずに自動で再読み込みされます |
| [`tmux-battery-revamped`](https://github.com/tmux-revamped/tmux-battery-revamped) | ステータスの描画を止めずに、tmuxのステータスバーにバッテリーの状態を表示します |
| [`tmux-bluetooth-revamped`](https://github.com/tmux-revamped/tmux-bluetooth-revamped) | 接続中のすべてのBluetoothデバイスとそのバッテリーを、描画を止めずにtmuxのステータスバーに表示します |
| [`tmux-cpu-revamped`](https://github.com/tmux-revamped/tmux-cpu-revamped) | CPUの負荷、温度、周波数を、描画を止めずにtmuxのステータスバーに表示します |
| [`tmux-disk-revamped`](https://github.com/tmux-revamped/tmux-disk-revamped) | ステータスの描画を止めずに、tmuxのステータスバーにディスク使用量を表示します |
| [`tmux-extract-revamped`](https://github.com/tmux-revamped/tmux-extract-revamped) | 画面上のURL、パス、ハッシュなどのトークンをfzfで選び、カーソル位置に入力します。シェルだけで動きます |
| [`tmux-fzf-revamped`](https://github.com/tmux-revamped/tmux-fzf-revamped) | ポップアップのfzfピッカーから、tmuxのセッション、ウィンドウ、ペインの切り替え、終了、名前の変更、作成を行います |
| [`tmux-git-revamped`](https://github.com/tmux-revamped/tmux-git-revamped) | アクティブなペインのgitブランチ、変更、プロバイダーの件数を、描画を止めずにtmuxのステータスバーに表示します |
| [`tmux-gpu-revamped`](https://github.com/tmux-revamped/tmux-gpu-revamped) | NVIDIA、AMD、Intel、AppleのGPUの負荷、温度、クロック、電力、メモリをtmuxのステータスバーに表示します |
| [`tmux-kube-revamped`](https://github.com/tmux-revamped/tmux-kube-revamped) | 現在のKubernetesのコンテキストとネームスペースを、kubectlを使わずkubeconfigから読み取ってtmuxのステータスバーに表示します |
| [`tmux-launcher-revamped`](https://github.com/tmux-revamped/tmux-launcher-revamped) | 任意のTUIアプリを、現在のペインのディレクトリでポップアップかウィンドウとして起動します。キーは1つで、変更できます |
| [`tmux-logging-revamped`](https://github.com/tmux-revamped/tmux-logging-revamped) | 任意のペインをファイルに保存します。ライブのログ、スクロールバック全体、1回限りのスクリーンショットに対応します |
| [`tmux-music-revamped`](https://github.com/tmux-revamped/tmux-music-revamped) | 再生中の曲を、ステータスの描画を止めずにtmuxのステータスバーに表示します |
| [`tmux-network-revamped`](https://github.com/tmux-revamped/tmux-network-revamped) | ネットワークのスループットを、描画を止めずにtmuxのステータスバーに表示します |
| [`tmux-pain-control-revamped`](https://github.com/tmux-revamped/tmux-pain-control-revamped) | tmuxの標準的なペインとウィンドウ操作のキーバインドです。バージョンに対応し、vimと相性がよく、すべて設定できます |
| [`tmux-persist-revamped`](https://github.com/tmux-revamped/tmux-persist-revamped) | tmuxのすべてのセッション、ウィンドウ、ペインを保存し、タイマーで自動保存して、再起動後にすべて復元します |
| [`tmux-plugin-template`](https://github.com/tmux-revamped/tmux-plugin-template) | tmux-revampedプラグインの出発点です。共有ライブラリ、batsのテスト環境、CI、ファミリーのツールを含みます |
| [`tmux-pomodoro-revamped`](https://github.com/tmux-revamped/tmux-pomodoro-revamped) | すべての状態をtmuxオプションに保持し、一時ファイルを使わない、tmuxステータスバーのポモドーロタイマーです |
| [`tmux-ram-revamped`](https://github.com/tmux-revamped/tmux-ram-revamped) | RAM、スワップ、メモリプレッシャーをtmuxのステータスバーに表示します。計測はバックグラウンドで行うため描画を待たせません |
| [`tmux-reorder-revamped`](https://github.com/tmux-revamped/tmux-reorder-revamped) | **このプラグイン**。tmuxのステータスバー上でウィンドウのタブをマウスでドラッグして、そのウィンドウを移動します |
| [`tmux-scroll-revamped`](https://github.com/tmux-revamped/tmux-scroll-revamped) | 自分でスクロールできるアプリにはマウスホイールを渡し、それ以外ではtmuxのコピーモードに入ります |
| [`tmux-sensible-revamped`](https://github.com/tmux-revamped/tmux-sensible-revamped) | tmuxのバージョンと端末に応じて適用され、あなたが設定したオプションには触れない、tmuxの妥当な既定値です |
| [`tmux-tiling-revamped`](https://github.com/tmux-revamped/tmux-tiling-revamped) | tmuxのタイル型ウィンドウ管理です。BSPのdwindleとspiralを含む8つのレイアウトがあり、レイアウトを元に戻せます |
| [`tmux-time-revamped`](https://github.com/tmux-revamped/tmux-time-revamped) | 時間帯で色分けされたローカル時計と世界時計を、カウントダウンと夏時間の警告付きでtmuxのステータスバーに表示します |
| [`tmux-weather-revamped`](https://github.com/tmux-revamped/tmux-weather-revamped) | wttr.inから取得した天気をtmuxのステータスバーに表示します。取得はバックグラウンドで行うためステータス行を待たせません |

### インストールの確認

すべてのメンバーがディスク上にあれば、1つのコマンドでメンバー間の衝突を報告できます。

```sh
family/bin/doctor --live
```

各メンバーと稼働中のtmuxサーバーを読み取り、重複したキー、重複したステータスのプレースホルダー、命名規則に沿わないオプション、規約のバージョンが遅れているメンバーを報告します。

<!-- family:end -->
