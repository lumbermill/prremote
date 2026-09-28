# Support matrix & release smoke test

prremote が対応しているボード × 機能の一覧と、リリース後に実機で行う動作確認（スモークテスト）手順。
物理デバイスが相手なので完全自動化はできないが、**シリアル出力で判定できる項目は `rake smoke[BOARD]` で半自動化**している。
残り（LCD 表示・LED・ボタン・実センサー値）は目視で確認する。

> 実装の経緯・設計判断は [CHANGELOG.md](../CHANGELOG.md) と git log を、未着手の将来計画は [PLAN.md](../PLAN.md) を参照。

## Support matrix

| 機能 | pico | picow | pico2 (RP2350) | esp32 (M5GO) | M5StickC PLUS⁵ | esp32c6 (XIAO) |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| install（書き込み） | ✅ UF2 | ✅ UF2 | ✅ UF2 | ✅ EspFlasher | ✅ EspFlasher⁵ | ✅ esptool¹ |
| run / eval / watch | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| deploy / undeploy | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| GPIO | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ADC | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| PWM | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| I2C | ✅ | ✅ | ✅ | ✅ | ✅ | ✅² |
| SPI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| WiFi | — | ✅ | — | ✅ | ✅ | ✅ |
| NTP（時刻同期） | — | ✅ | — | ✅ | ✅ | ✅ |
| TCPSocket | — | ✅ | — | ✅⁴ | ✅⁴ | ✅⁴ |
| UDPSocket | — | — | — | ✅⁴ | ✅⁴ | ✅⁴ |
| LCD | — | — | — | ✅ ILI9342C | ✅ ST7789v2⁵ | ✅ ILI9341³ |
| IR 送信（`IR`） | — | — | — | —⁶ | ✅⁶ | — |

✅ = 実装済み・実機確認済み / 🧪 = 実装済み・実機未確認 / — = 非対応（ハード非搭載 または 未実装）

¹ esp32c6 は USB Serial/JTAG のため `esptool` 必須（`brew install esptool`）。`--before usb-reset` によるハンズフリー書き込み（手動 hold BOOT → press RST はフォールバック時のみ）。他ボードは追加ツール不要。
² esp32c6 チップの I2C デフォルトピンは GPIO6/7 だが JTAG 用で XIAO のエッジパッドに出ていないため、ランタイムのデフォルトを XIAO の D4=GPIO22 / D5=GPIO23 に変更済み。`examples/xiao_c6/i2c_scan.rb` は同ピンを明示指定しており、実機で I2C デバイス検出を確認済み。
³ MSP2807（ILI9341）は `LCD.new(invert: false, madctl: 0xE8)`。M5Stack ILI9342C は既定（INVON）。
⁴ esp32c6 の TCPSocket / UDPSocket は ESP-IDF lwIP の BSD ソケットで実装（picoruby-socket の ports/esp32 を流用）。ホスト名・`.local`（mDNS）解決は `getaddrinfo` 経由。UDP サンプルは [examples/xiao_c6/socket-udp.rb](../examples/xiao_c6/socket-udp.rb)。**両方とも XIAO ESP32C6 実機で疎通確認済み**（UDP: connect → send → recvfrom_nonblock、TCP: connect → write → read_nonblock/gets、いずれもエコーサーバと往復）。classic esp32 にも同じ配線を展開済みで、**M5GO 実機で TCP・UDP とも確認済み**（2026-09-27: TCP は time.nist.gov:13 の daytime 受信、UDP は pool.ntp.org:123 への SNTP 問い合わせと [examples/m5go/socket_udp.rb](../examples/m5go/socket_udp.rb) による LAN 内エコーサーバとの 5 往復）。M5StickC PLUS 実機でも同じ 3 項目を確認済み。
⁵ M5StickC PLUS（ESP32-PICO-D4、内蔵フラッシュ）は M5GO と**同じ esp32 ランタイム**で動く。0.4.1 からは `install -b m5stickc_plus` で esp32 イメージを焼いたうえでボード名を NVS に記録し（READY 行に `board=m5stickc_plus`）、スクリプトが `M5StickCPlus` を参照すると CLI がボードライブラリ（[lib/prremote/boards/m5stickc_plus.rb](../lib/prremote/boards/m5stickc_plus.rb)。電源・LCD プリセット・ボタン・LED・ブザー・IR・RTC）を自動で一緒にコンパイルする。サンプルは [examples/m5stickc_plus/](../examples/m5stickc_plus/)。以下の低レベルの詳細はボードライブラリが吸収している。install は eFuse の SPI pad 設定を読んで SPI_ATTACH するので内蔵フラッシュ機も `EspFlasher` で書ける。LCD は ST7789v2 135x240 で `LCD.new` に `width:`/`height:`/`offset_x:`/`offset_y:` と `madctl:`（BGR ビットを落とす）を渡す。135px 側は 240px の RAM 窓の中で片側 52・反対側 53 の余白なので、その軸をミラーする回転（1 と 2）では offset が 53 になる（52 のままだと端の 1 ライン分が描かれずノイズが見える）。バックライト/パネル電源・Grove 5V は GPIO ではなく AXP192（I2C `0x34`）の LDO2/LDO3/EXTEN で、明示的な有効化が要る（`lcd_hello.rb` / `adc.rb` 参照）。内蔵デバイスはすべて SDA=21/SCL=22 の同一 I2C バス上: AXP192 `0x34`・IMU MPU6886 `0x68`（`imu.rb`）・RTC BM8563 `0x51`（`rtc.rb` / `rtc_sync.rb`、Ruby の `I2C` だけで実装。電源断＋USB 抜去後も時刻保持・VL なしを確認済み）。ボタン A = GPIO37 / B = GPIO39、赤 LED = GPIO10（active-low）、ブザー = GPIO2（パッシブ、PWM で音程）。外部ピンはヘッダ G0/G26/G36-G25（G36 と G25 は同一パッド）と Grove G32/G33。SPI のデフォルトピン（18/23）は M5GO の VSPI で、このボードでは LCD の RST/DC なので**必ずピンを明示**（`spi_loopback.rb` は SPI2 を G26/G32/G33 で使用）。**全項目を実機確認済み**（2026-09-27）。
⁶ `IR` クラスは classic ESP32 の RMT で搬送波付きパルス列を送る（NEC エンコードは `hw_wrap.rb`）ので、ランタイムとしては M5GO でも任意ピンで動くが、IR LED を搭載しているのは M5StickC PLUS（GPIO9）のみ。pico 系・esp32c6 では `IR.new` が `RuntimeError` を出す。M5StickC PLUS 実機でスマホカメラ越しに IR LED の発光を確認済み（受信機による NEC デコードは未確認）。

## Post-release smoke test

リリース（gem + runtime）を publish した後、手元の実機で以下を確認する。
`rake smoke[BOARD]` が `PASS`/`FAIL` を出す自動項目を実行し、`[ ]` の目視項目は人手で確認する。

```bash
# 例: picow を指定ポートで確認。WiFi はクレデンシャル入りスクリプトを指す
PORT=/dev/tty.usbmodem101 SMOKE_WIFI=wk/wifi.rb rake "smoke[picow]"
```

環境変数:

- `PORT` / `BAUD` — 未指定なら gem の auto-detect に委ねる。
- `SMOKE_WIFI` / `SMOKE_NTP` — `examples/*/wifi.rb` は placeholder クレデンシャルなので、実 SSID/パスワードを入れたコピー（`wk/` など git 管理外）を指すと auto 判定が通る。
- `PRREMOTE` — 既定はワーキングツリーの `ruby -Ilib bin/prremote`。インストール済み gem で確認したいときは `PRREMOTE=prremote`。

### 共通（全ボード）

- auto: `version` が runtime バージョンを返す / `eval "puts 6*7"` → `42`

### pico / pico2

- [ ] `install -b pico`（または `pico2`）→ BOOTSEL から書き込み、READY バナー
- auto: version / eval
- [ ] `examples/pico/gpio.rb`: LED 点滅、ボタン押下で "pressed"
- [ ] `examples/pico/i2c_scan.rb`: 接続センサーのアドレスが出る（`rake smoke` が出力を表示）
- [ ] `adc.rb` / `pwm.rb` / `spi_*.rb`: 期待値・点灯を目視

### picow

- pico の項目 +
- auto: `wifi.rb` → "Connected!" / IP 表示
- [ ] `ntp_clock_picow.rb`: 同期時刻が出る
- [ ] `led.rb`: オンボード LED（`GPIO.led` → CYW43 経由）が点滅

### esp32（M5GO / M5Stack Core 初代）

- [ ] `install -b esp32` → EspFlasher（自動リセット、追加ツール不要）で書き込み、READY
- auto: version / eval / wifi
- [ ] `lcd_hello.rb`: 塗り＋矩形＋文字、色が正しい
- [ ] `ntp_clock.rb`: パネルに時計が動く
- [ ] `buttons.rb`: A/B/C が反応
- [ ] `i2c_scan.rb` / `imu_level.rb` など周辺デバイス
- [ ] `socket_udp.rb`: エコーサーバ（スクリプト冒頭コメントの CRuby 版）と UDP 往復

### M5StickC PLUS（esp32 ランタイム）

`rake smoke[m5stickc_plus]`。

- [ ] `install -b m5stickc_plus` → EspFlasher（自動リセット）で書き込み、`Board: m5stickc_plus`、READY
- auto: `version` が `board=m5stickc_plus` を返す
- auto: version / eval / wifi
- [ ] `rtc.rb`: 日時が 1 秒ずつ進み「not set yet」が出ない（出たら `rtc_sync.rb` で NTP から設定）
- [ ] `led.rb` / `pwm.rb`: 赤 LED（GPIO10）が点滅 / ブリージング
- [ ] `buzzer.rb`: ドレミファソラシドが鳴る
- [ ] `ir_send.rb`: スマホカメラ越しに IR LED（上端）が 1 秒ごとに光る
- [ ] `lcd_hello.rb` / `ntp_clock.rb`: 色が正しく（赤が赤）、はみ出しなし
- [ ] `lcd_rotations.rb`: 4 回転すべてで白枠の 4 辺が見え、どの辺にもノイズの線がない
- [ ] `buttons.rb` / `imu.rb`: A/B が反応、静止で Z≈1.0g
- [ ] `pin_check.rb`: ヘッダ G26↔G36/G25 + Grove G32↔G33 で OK → ヘッダを G36/G25↔G0 に替えて G0 行が OK
- [ ] `spi_loopback.rb`: Grove G32↔G33 ジャンパで "OK: loopback matched"
- [ ] `adc.rb`: Grove に ANGLE ユニット（または G33 を GND/3V3 へ）でつまみに追従

### esp32c6（XIAO ESP32C6）

- [ ] `install -b esp32c6` → esptool（usb-reset、ハンズフリー）で書き込み、READY
- auto: version / eval / wifi
- [ ] `gpio.rb`: 黄色 LED（GPIO15）点滅、ボタン（GPIO2）で "pressed"
- [ ] `led.rb`: 黄色 LED（`GPIO.led` → GPIO15 active-low）が点滅
- [ ] `pwm.rb`: 黄色 LED（GPIO15）がブリージング（明→暗を繰り返す）
- [ ] `pin_check.rb`: 隣接ペアをジャンパ直結し全ペア OK（配線はスクリプト冒頭コメント参照）
- [ ] `spi_loopback.rb`: D10(MOSI/GPIO18)↔D9(MISO/GPIO20) をジャンパ直結で "OK: loopback matched"
- [ ] `lcd_hello.rb`: MSP2807 が正立 320×240（`invert: false` / `madctl: 0xE8`）
- [ ] `i2c_scan.rb`: D4/D5 のセンサーが検出される（デフォルトピンも同じ 22/23 になった）
- [ ] `ntp_clock.rb`: シリアルに JST が出る

---

> このチェックリストは [`tasks/smoke.rake`](../tasks/smoke.rake) の手順と対応している。項目を増やしたら両方を更新する。
