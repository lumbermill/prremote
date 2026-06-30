# PLAN 将来計画

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

## ESP32 対応

**2026-06-11: ESP32 classic 対応を実装済み**（WiFi を除く）。構成:

- `runtime/src/prr_platform.h` — プラットフォーム抽象。`runtime.c`（プロトコル本体）は中立化し、`platform_pico.c` / `runtime/esp32/main/platform_esp32.c` がボード固有部を実装
- `runtime/esp32/` — ESP-IDF v5.3 プロジェクト（UART0 コンソール、RX の行末変換無効化でバイナリ安全）。ESP-IDF は vendored しない（~/sources/esp/esp-idf、IDF_PATH で変更可）
- deploy 保存先はカスタム data パーティション `prremote`（64KB、PRRD ヘッダは Pico とバイト互換 → gem の deploy/ls/undeploy 無修正）
- `bindings_esp32.c` — GPIO/ADC(oneshot)/PWM(LEDC)/I2C(i2c_master)/SPI(spi_master)。`hw_wrap.rb` は両ビルド共有（ADC の pin→ch 変換は C 層へ、unit シンボル汎用化）
- Ctrl+C リセット: esp_timer 監視 + `esp_restart()`、`ESP_RST_SW` で自動実行抑止。ポート open 時の DTR/RTS リセットは「自動実行→0x03→READY」に収束
- gem: `--board esp32`（esptool で merged bin を 0x0 に書き込み）、detector に CP210x/CH910x VID 追加
- ビルド: `cd runtime && rake build:esp32`、`rake cache` / `rake release` は 3 ボード対応

### 残タスク

- **WiFi / SNTP**: esp_wifi + picoruby-socket `ports/esp32/`（取り込みは rp2040 と同じ `-include picoruby_compat.h` 方式）。Ruby API は汎用 `WiFi` モジュール新設、picow は CYW43 互換を残して委譲。SNTP は esp_sntp で `_time_*` を別実装
- **ESP32-S3 / C3**: sdkconfig の target 切り替え + ピンデフォルト調整でいけるはず（ネイティブ USB CDC あり）。需要を見て判断

### 対応ボード数の現実的な上限

| ターゲット | 追加コスト | 判断 |
|---|---|---|
| RP2350（Pico 2 / Pico 2W） | 極小（同じ Pico SDK、CMake ターゲット追加のみ） | やる価値あり |
| ESP32 | 約 2 週間 | ユーザー数が多く費用対効果あり |
| STM32 | 約 2〜3 週間（HAL 細分化が多い） | 優先度低 |
| nRF52 / Zephyr | 約 2 週間（mruby/c に Zephyr HAL あり） | 優先度低 |

現実的には **RP2350 + ESP32 まで** が維持コストとのバランスが取れる上限と思われる。それ以上はエコシステムが分散してテスト・リリース管理の負担が重くなる。

## XIAO ESP32C6 周辺ピンの実機検証

**2026-06-27: esp32c6 ランタイム＋ `examples/xiao_c6/` を実装。GPIO（LED 出力 / ボタン入力）まで実機確認済み。**

このコミットで修正済み:

- コンソール（`runtime/esp32c6/main/platform_esp32c6.c`）: USB Serial/JTAG ドライバを install し
  `usb_serial_jtag_vfs_use_driver()` でブロッキング read 化。デフォルトの非ドライバ VFS は getchar が
  非ブロッキングで EOF を返し、`recv_exact` が 0xFF を書き込んで `.mrb` が壊れていた（`IREP_TT=...`）。
  RX 改行変換も `ESP_LINE_ENDINGS_LF` で無効化。
- CLI（`SerialHelpers#write_chunked`）: USB Serial/JTAG は 256B RX リングを一括バーストで溢れさせると
  取りこぼす（USB バックプレッシャなし）。run / deploy は ≤256B チャンク + 4ms 間隔で送信。baud 律速の
  Pico / ESP32(UART) では 256B が既に約 22ms かかるため実質ノーコスト。
- `examples/xiao_c6/gpio.rb`: ボタンのパッド記載を D0 → **D2** に修正（実機で GPIO2=D2 を確認）。

### 残タスク（要・実機 + I2C デバイス）

XIAO のシルク（D0-D10）と GPIO 番号の対応を実機で確定し、全 examples のピンを揃える。
Seeed XIAO ESP32C6 の想定対応（D2/GPIO15 以外は未検証）:

| シルク | GPIO | 用途 |
|---|---|---|
| D0/A0 | GPIO0 | |
| D1/A1 | GPIO1 | |
| D2/A2 | GPIO2 | ボタン例で確認済み |
| D3 | GPIO21 | |
| D4/SDA | GPIO22 | I2C SDA |
| D5/SCL | GPIO23 | I2C SCL |
| D6/TX | GPIO16 | |
| D7/RX | GPIO17 | |
| D8/SCK | GPIO19 | |
| D9/MISO | GPIO20 | |
| D10/MOSI | GPIO18 | |
| (LED) | GPIO15 | オンボード黄色 LED（確認済み） |

- **`examples/xiao_c6/i2c_scan.rb`**: 現状 `sda_pin: 6, scl_pin: 7`（GPIO6/7）だが、XIAO のエッジパッドに
  GPIO6/7 は出ていないと思われる。正しくは **D4=GPIO22 / D5=GPIO23** のはず。I2C デバイスを D4/D5 に
  繋いでアドレスが出るか確認してから値とコメントを修正する。
- ランタイムの C6 デフォルト I2C/SPI ピン（CHANGELOG: SDA=6/SCL=7, SCK=19/MOSI=18）も XIAO 実シルクに
  合わせるか要検討（デフォルトを XIAO 基準にするか、チップ汎用のままにするか）。
- **`wifi.rb` / `ntp_clock.rb`**: ピン依存はないが C6 での WiFi 接続・NTP 同期は実機未確認
  （M5GO=ESP32 classic では確認済みだが C6 は別チップ）。

### SPI / PWM サンプルの追加（未実装）

現状 `examples/xiao_c6/` は gpio / i2c_scan / ntp_clock / wifi のみ。`hw_wrap.rb` には PWM・SPI の
API があるが C6 向けサンプルが無い。CLAUDE.md の方針（サンプルが唯一の参照、コピペで動く、配線情報を
コメントに明記）に沿って追加する。いずれもピン確定（上記の D↔GPIO 表）後に実機検証する。

- **`pwm.rb`（PWM）**: オンボード黄色 LED（GPIO15）を PWM で**ブリージング（明滅）**させる。外部配線不要で
  コピペ即動作になるのが利点。`PWM.new(15, frequency: 1000, duty_u16: 0)` → `duty_u16=` を 0↔65535 で
  ランプ。**注意**: LED は active-low なので duty と明るさが反転する（duty 大 = 暗い）。サンプル内で
  反転を吸収するか、外部 LED（任意の D ピン + 抵抗）方式にするか実機で決める。C6 は LEDC 6ch まで。
  余裕があれば外部 LED 版（明るさ）・サーボ版（50Hz / duty で角度）も検討。
- **`spi_loopback.rb`（SPI 自己テスト）**: 外部デバイス不要で確認できるよう、**MOSI→MISO をジャンパで
  直結**したループバックで `transfer` がエコーを返すことを確認する。C6 デフォルトは SPI2_HOST・
  SCK=GPIO19(D8) / MOSI=GPIO18(D10) / MISO=GPIO20(D9)。配線: D10(MOSI)↔D9(MISO) を直結、SCK は未接続でよい。
  `SPI.new(sck_pin: 19, copi_pin: 18, cipo_pin: 20)` → `transfer([0x01,0x02,0x03])` が同じ並びで返れば OK。
  ピン番号は上記表の確定後に合わせる。実デバイス版（例: SPI フラッシュや SD の JEDEC ID 読み出し）は
  デバイスが手に入ってから別途。

### LCD（ILI9341 / MSP2807）— 実装済み・実機検証待ち

**2026-06-30: ESP32 classic 用 LCD ドライバ（`esp32/main/lcd_ili9342c.c`）を C6 ビルドにも
組み込み、`examples/xiao_c6/lcd_hello.rb` を追加。実機表示はまだ未確認。**

- C ドライバは esp_lcd / spi_master / ledc のみ使用するため両 ESP32 ビルドで共有。
  `LCD_HOST` だけターゲット別マクロ化（C6 は SPI3 が無いので `SPI2_HOST`）。
- `LCD.new(invert:)` を追加。M5Stack ILI9342C は INVON（`true`, デフォルト）、
  標準 ILI9341（MSP2807）は INVOFF（`false`）。
- サンプルの配線（XIAO ←→ MSP2807）: SCK=D8/GPIO19, MOSI=D10/GPIO18, CS=D3/GPIO21,
  DC=D1/GPIO1, RST=D0/GPIO0, BL=D6/GPIO16, MISO 未接続。CS/DC/RST/BL のピンは未検証。

#### 実機検証で確定すべき点（焼いてから順に）

1. **点灯**: `fill_rect(0,0,320,320,RED)` で全面赤になるか（配線・電源の一次確認）。
2. **色反転**: ネガ表示なら `invert:` を切替（MSP2807 は `false` の想定）。
3. **色順 RGB/BGR**: 赤が青に出るなら `madctl[]` の BGR ビット（0x08）を要調整。
4. **向き・解像度**: ILI9341 はネイティブ 240×320 で、ILI9342C（320×240）と縦横が 90° 違う。
   現状の `madctl[]` テーブルと `s_width/s_height` の swap 判定は ILI9342C 前提なので、ILI9341 を
   ランドスケープに正しく収めると rotation の意味がずれる可能性がある。実機で「全面塗り＋文字正立」に
   なる rotation を確定し、必要なら C 層にパネル種別フラグ（ネイティブ向き補正）を追加する。
   サンプルは点灯確認を向き非依存にするため `fill_rect(0,0,320,320,...)` で全面塗りしている。

## M5Stack 対応

**2026-06-11: M5GO（M5Stack Core 初代系）を検証実機として LCD まで実装済み。**
手元の実機は Core2 ではなく M5GO だった（ESP32 classic / ILI9342C 320×240 /
電源 IC は IP5306 でタッチなし・物理ボタン 3 個 / USB-UART CP2104）。

### 実装済み

- `LCD` クラス（`runtime/src/lcd_wrap.rb` + `esp32/main/lcd_ili9342c.c`）:
  `fill` / `fill_rect` / `pixel` / `text`（内蔵 8x8 フォント、scale 1〜4）/ `brightness=`。
  esp_lcd_panel_io_spi ベース、フレームバッファなし（2KB ピンポン DMA バッファ）。
  ピンは `LCD.new` で変更可、デフォルトは M5Stack Core 初代（CS=14, DC=27, RST=33, BL=32）
- バックライトは GPIO32 を LEDC PWM（AXP192 不要なのが Core2 との違い）
- サンプル: `test/samples/esp32/`（lcd_hello / lcd_demo / i2c_scan_m5go / buttons_m5go / gpio）

### M5Stack Core2 対応（将来）

同じ esp32 ランタイムで射程内。差分は LCD ピン（CS=5, DC=15, RST なし）と
**AXP192 電源初期化**（LDO2/DCDC3/GPIO4 を叩かないと画面が点かない）の追加のみ。
タッチ（FT6336U、I2C 0x38）は I2C バインディングで Ruby から読める。

### LCD クラスの拡張

現状の `LCD` は `fill` / `fill_rect` / `pixel` / `text` のみ。以下を C 層に追加したい。

- `draw_line(x0, y0, x1, y1, color)` — Bresenham の線分アルゴリズム
- `draw_ellipse(cx, cy, a, b, color)` — Midpoint ellipse algorithm（塗りつぶし版も）
- `draw_circle(cx, cy, r, color)` — 同上、円特化版

現状はこれらをユーザースクリプト側で `fill_rect` の積み上げにより実装しているが、
C 層に持つと速度・コード量とも改善できる。

### 画像表示（`draw_image`）の実装方法検討

現状の `tools/img2rle.rb` は RGB565 RLE をバイナリ文字列定数として `.rb` ファイルに埋め込み、
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
