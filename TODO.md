# prremote TODO

## コマンド実装

- [x] `install`      — UF2ダウンロード（初回）＋キャッシュ＋BOOTSEL書き込み
- [x] `list`         — シリアルデバイス一覧
- [x] `version`      — prremote / mrbc（パス＋バージョン）/ デバイスランタイム（ベストエフォート）
- [x] `run FILE`     — `.rb` → `.mrb` コンパイル＋シリアル送信＋RUNNING/DONE待機（即時実行・保存なし）
- [x] `deploy FILE`  — `.rb` → `.mrb` コンパイル＋フラッシュ書き込み（次回電源投入時に自動実行）
- [x] `undeploy`     — フラッシュのスクリプトを消去して自動起動を無効化（`ERSE` プロトコル、ランタイム変更含む）
- [x] `eval EXPR`    — ワンライナーを一時ファイルに書いて run と同じ流れ
- [x] `reset`        — シリアルに `0x03` を送信してデバイスをリブート
- [x] `watch FILE`   — ファイル変更監視 → auto run（polling、0.5秒間隔）

## サンプルコード

凡例: [W] = Pico W のみ、[*] = Pico / Pico W 共通

- [x] `samples/led.rb`    — [W] CYW43 オンボード LED 点滅
- [x] `samples/gpio.rb`   — [*] 外部 GPIO 出力／入力
- [x] `samples/wifi.rb`   — [W] WiFi 接続・IP 取得
- [x] `samples/adc.rb`    — [*] アナログ入力読み取り（GPIO 26–28）
- [x] `samples/pwm.rb`    — [*] PWM で LED フェード
- [ ] `samples/led_pico.rb` — [Pico] GPIO 25 オンボード LED 点滅（Pico 向けサンプル）

## ランタイム拡張（上記サンプルの前提）

- [x] `GPIO` クラス追加（`_gpio_*` ラッパー、PicoRuby 互換 API）
- [x] `ADC` C バインディング＋Rubyクラス追加（`hardware_adc`）
- [x] `PWM` C バインディング＋Rubyクラス追加（`hardware_pwm`）

## ランタイム既知の問題

- [ ] **`puts` 出力がリアルタイムに届かない**: mruby/c の標準出力（`mrbc_putchar` / `console_putchar`）が USB CDC バッファに溜まり、`DONE` 直前にまとめて流れてくる。対策候補:
  - `hal.c` の `mrbc_putchar` 内で `stdio_flush()` を毎回呼ぶ
  - Ruby 側で `$stdout.flush` 相当のバインディングを追加し、ループ末尾で呼ぶ
  - `pico_enable_stdio_usb` の送信タイムアウトを短くする（`PICO_STDIO_USB_STDOUT_TIMEOUT_US`）

## ランタイム (runtime/)

- [ ] **ファームウェア再ビルド・再書き込みが必要**: `undeploy`（`ERSE`）の追加はランタイム変更を含む。現行デバイスには `prremote install` で新ファームを焼き直す必要あり。
- [ ] version プローブ対応: デバイスが実行中でも特定バイトに `READY` を返す仕組み（現状はアイドル時のみ取得可能）

## mrbc の扱い

- [x] 利用する mrbc のパス・バージョンを version コマンドで表示（`Mrbc` モジュールに共通化、`$MRBC` 環境変数で上書き可）
- [ ] **将来: プラットフォームgem として mrbc バイナリを同梱**
  - `rake-compiler-dock` でmrubyをクロスコンパイルし、プラットフォーム別gemに焼き込む
  - 対象: `x86_64-darwin`, `arm64-darwin`, `x86_64-linux`
  - 参考: nokogiri / grpc のgemspec・CI設定

## 旧コードの整理

- [x] 旧コマンド群（`ls` / `put` / `get` / `run` / `rm` / `mkdir` / `repl` / `irb` / `open`）を削除
- [x] 旧実装でしか使わない箇所を削除
- [x] `Connection` クラスを削除（新プロトコルでは各コマンドが Serial を直接使用）
- [x] 新コマンドのテストを追加（`run` / `deploy` / `eval` / `undeploy`）

## Raspberry Pi Pico（W なし）対応

（テスト完了後に着手）

### ランタイム

- [ ] `PICO_BOARD=pico` でビルドできることを確認（`HAS_CYW43` なし）
- [ ] Pico 向け UF2 を GitHub Releases に追加（`prremote-pico-runtime-x.x.x.uf2`）
- [ ] `runtime_manager.rb` でボード種別を判別してダウンロード先を切り替える
  - BOOTSEL マウント時に `RP2040` か `RP2350` かでボードを特定する仕組みが必要

### CLI

- [ ] `prremote install` でボード（`pico` / `pico_w`）を選択または自動検出できるようにする
  - `--board pico` / `--board picow` オプション案
  - マウントボリューム名（`RPI-RP2` は共通）では区別できないため、手動指定が現実的

### サンプル

- [ ] `samples/led_pico.rb` — GPIO 25 オンボード LED（Pico 向け）

## パッケージング・CI

- [x] RuboCop lint パス確認（22 files, no offenses）
- [x] CHANGELOG.md
- [x] GitHub Actions CI を新コマンド構成に合わせて更新
