# PLAN 将来計画

未着手・検討中の項目のみを記す。
**対応済みのボード／機能の一覧と動作確認手順は [docs/SUPPORT.md](docs/SUPPORT.md)** に移動した。
実装の経緯は CHANGELOG.md / git log を参照。

## TCPSocket.gets タイムアウト

現状の `gets` は `readpartial(1)` を 1 バイトずつ呼ぶループで、C 層に 60 秒 per-call タイムアウトがある。
サーバーが改行を送らずデータを drip-feed し続ける場合は永久ブロックし得る。

対処するなら `read_nonblock` + `ready?` + 経過時間チェックの自前ポーリングループで実装する。
mruby/c には `Timeout` モジュールもスレッドもないため Ruby 層で対処するしかない。
（2026-06-06 時点: 様子見）

## mrbc の自動取得・キャッシュ

現状は mrbc をユーザー環境に依存しているが、初回セットアップの障壁になっている。
ランタイム（`.uf2`）と同様に、実行時に GitHub Releases からダウンロードしてキャッシュする方式を採用する。

- `RUNTIME_VERSION` に対応する mrbc バイナリをランタイムと同じリリースタグに同梱する
- 対象プラットフォーム: `x86_64-darwin`, `arm64-darwin`, `x86_64-linux`, `aarch64-linux`
- Linux は glibc 互換性のため Ubuntu 20.04 系でビルドする（または musl で完全静的リンク）
- キャッシュ済みであれば再ダウンロードしない（UF2 と同じ挙動）
- `$MRBC` 環境変数による上書きは引き続き有効

## Pico / Pico W の判別サポート

BOOTSEL モードでは USB PID・ボリューム名・`INFO_UF2.TXT` がすべて同一のため、ソフトウェアによる自動判別は不可。ユーザーが自分で判断できるよう案内する方向で検討する。

候補:

- **ドキュメントページ（ウェブ）**: 外観写真付きで見分け方を解説。Pico W はボード裏面に "Pico W" のシルク印刷があり、表面に WiFi アンテナのパターン（白いジグザグ線）がある
- **`prremote install` の対話プロンプト**: ボード未指定時に "Pico W ですか？ [y/N]" と聞く。`--board` オプションと併用

## 対応ボードの拡張候補

実装済み（pico / picow / pico2 / esp32 / esp32c6）は [docs/SUPPORT.md](docs/SUPPORT.md) 参照。今後の候補:

| ターゲット | 追加コスト | 判断 |
|---|---|---|
| ESP32-S3 / C3 | sdkconfig の target 切り替え + ピンデフォルト調整（ネイティブ USB CDC あり） | 需要を見て判断 |
| STM32 | 約 2〜3 週間（HAL 細分化が多い） | 優先度低 |
| nRF52 / Zephyr | 約 2 週間（mruby/c に Zephyr HAL あり） | 優先度低 |

現実的には維持コストの観点から、ここから先はエコシステムが分散してテスト・リリース管理の負担が重くなる。

## XIAO ESP32C6 の周辺ピン確定（要・実機 + I2C デバイス）

XIAO のシルク（D0-D10）と GPIO 番号の対応を実機で確定し、全 examples のピンを揃える。
Seeed XIAO ESP32C6 の想定対応（D2/GPIO2・LED/GPIO15 以外は未検証）:

| シルク | GPIO | 用途 |
|---|---|---|
| D0/A0 | GPIO0 | |
| D1/A1 | GPIO1 | |
| D2/A2 | GPIO2 | ボタン例で確認済み |
| D3 | GPIO21 | |
| D4/SDA | GPIO22 | I2C SDA・`i2c_scan.rb` で確認済み |
| D5/SCL | GPIO23 | I2C SCL・`i2c_scan.rb` で確認済み |
| D6/TX | GPIO16 | |
| D7/RX | GPIO17 | |
| D8/SCK | GPIO19 | |
| D9/MISO | GPIO20 | |
| D10/MOSI | GPIO18 | |
| (LED) | GPIO15 | オンボード黄色 LED（確認済み） |

- ランタイムの C6 デフォルト I2C/SPI ピン（CHANGELOG: SDA=6/SCL=7, SCK=19/MOSI=18）も XIAO 実シルクに
  合わせるか要検討（デフォルトを XIAO 基準にするか、チップ汎用のままにするか）。
- **`wifi.rb` / `ntp_clock.rb`**: ピン依存はないが C6 での WiFi 接続・NTP 同期は実機未確認
  （M5GO=ESP32 classic では確認済みだが C6 は別チップ）。

## XIAO ESP32C6 の PWM / SPI サンプル（追加済み・実機未検証）

`examples/xiao_c6/` に `pwm.rb` / `spi_loopback.rb` を追加済み。いずれもピン確定（上記の D↔GPIO 表）後に
実機検証する。

- **`pwm.rb`（PWM）**: オンボード黄色 LED（GPIO15）を PWM でブリージング。active-low の反転はスクリプト内で
  吸収。余裕があれば外部 LED 版（明るさ）・サーボ版（50Hz / duty で角度）も検討。
- **`spi_loopback.rb`（SPI 自己テスト）**: **MOSI→MISO をジャンパ直結**したループバックで `transfer` が
  エコーを返すことを確認。C6 デフォルトは SPI2_HOST・SCK=GPIO19(D8) / MOSI=GPIO18(D10) / MISO=GPIO20(D9)。
  実デバイス版（SPI フラッシュや SD の JEDEC ID 読み出し）はデバイスが手に入ってから別途。

## classic esp32（M5GO）への TCP/UDPSocket 展開（任意）

esp32c6 の TCPSocket / UDPSocket は実機検証済み（[docs/SUPPORT.md](docs/SUPPORT.md) 参照）。
classic esp32 にも同じ層を載せられる（`ports/esp32` は共通、`esp32/main/CMakeLists.txt` と
`bindings_esp32.c` に esp32c6 と同じ socket 配線＋`MAX_VM_COUNT` 引き上げを足すだけ）。
需要を見て判断する。

## ESP32 LCD の向き自動補正（任意・優先度低）

パネル種別ごとの向き補正は現状 `LCD.new(madctl:)` 手動指定で吸収している（ILI9341/MSP2807 は `madctl: 0xE8`）。
ILI9341 を既定で正しい向きにする C 層のパネル種別フラグ化は、必要になれば検討（現状は手動指定で足りている）。

## M5Stack Core2 対応（将来）

同じ esp32 ランタイムで射程内。差分は LCD ピン（CS=5, DC=15, RST なし）と
**AXP192 電源初期化**（LDO2/DCDC3/GPIO4 を叩かないと画面が点かない）の追加のみ。
タッチ（FT6336U、I2C 0x38）は I2C バインディングで Ruby から読める。

## LCD クラスの拡張

現状の `LCD` は `fill` / `fill_rect` / `pixel` / `text` のみ。以下を C 層に追加したい。

- `draw_line(x0, y0, x1, y1, color)` — Bresenham の線分アルゴリズム
- `draw_ellipse(cx, cy, a, b, color)` — Midpoint ellipse algorithm（塗りつぶし版も）
- `draw_circle(cx, cy, r, color)` — 同上、円特化版

現状はこれらをユーザースクリプト側で `fill_rect` の積み上げにより実装しているが、
C 層に持つと速度・コード量とも改善できる。

## 画像表示（`draw_image`）の実装方法検討

現状の `examples/tools/img2rle.rb` は RGB565 RLE をバイナリ文字列定数として `.rb` ファイルに埋め込み、
`String#getbyte` で走査して `fill_rect` を呼ぶアプローチ。

**懸念点:**

- RLE データが大きいと mrb バッファを圧迫する（現状 64 KB に拡張して対応しているが綱渡り）
- Ruby バイトコードへの埋め込みが本来の用途外
- 単色域が少ない写真では圧縮率が低く、バッファに入りきらない可能性がある

**検討すべき代替案:**

- **deploy 経由でバイナリを Flash に置く**: `prremote deploy` で `.bin` をパーティションに書き込み、
  デバイス側で Flash から直接読む。mrb バッファを消費しない。Ruby API は `LCD.draw_image(name)` 程度で済む。
- **SPIFFS / LittleFS 上のファイル**: ESP-IDF の VFS でファイルとして扱い、
  ストリーム読み込みで描画。汎用性が高いが実装コストも大きい。
- **現行 RLE + デバイス側定数参照（現状維持）**: シンプルだが大きな画像には不向き。

→ **方針未定。実装前に上記トレードオフを再評価する。**
