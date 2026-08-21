# Support matrix & release smoke test

prremote が対応しているボード × 機能の一覧と、リリース後に実機で行う動作確認（スモークテスト）手順。
物理デバイスが相手なので完全自動化はできないが、**シリアル出力で判定できる項目は `rake smoke[BOARD]` で半自動化**している。
残り（LCD 表示・LED・ボタン・実センサー値）は目視で確認する。

> 実装の経緯・設計判断は [CHANGELOG.md](../CHANGELOG.md) と git log を、未着手の将来計画は [PLAN.md](../PLAN.md) を参照。

## Support matrix

| 機能 | pico | picow | pico2 (RP2350) | esp32 (M5GO) | esp32c6 (XIAO) |
|---|:--:|:--:|:--:|:--:|:--:|
| install（書き込み） | ✅ UF2 | ✅ UF2 | ✅ UF2 | ✅ EspFlasher⁵ | ✅ esptool¹ |
| run / eval / watch | ✅ | ✅ | ✅ | ✅ | ✅ |
| deploy / undeploy | ✅ | ✅ | ✅ | ✅ | ✅ |
| GPIO | ✅ | ✅ | ✅ | ✅ | ✅ |
| ADC | ✅ | ✅ | ✅ | ✅ | ✅ |
| PWM | ✅ | ✅ | ✅ | ✅ | ✅ |
| I2C | ✅ | ✅ | ✅ | ✅ | ✅² |
| SPI | ✅ | ✅ | ✅ | ✅ | ✅ |
| WiFi | — | ✅ | — | ✅ | ✅ |
| NTP（時刻同期） | — | ✅ | — | ✅ | ✅ |
| TCPSocket | — | ✅ | — | — | ✅⁴ |
| UDPSocket | — | — | — | — | ✅⁴ |
| LCD | — | — | — | ✅ ILI9342C⁵ | ✅ ILI9341³ |

✅ = 実装済み・実機確認済み / 🧪 = 実装済み・実機未確認 / — = 非対応（ハード非搭載 または 未実装）

¹ esp32c6 は USB Serial/JTAG のため `esptool` 必須（`brew install esptool`）。`--before usb-reset` によるハンズフリー書き込み（手動 hold BOOT → press RST はフォールバック時のみ）。他ボードは追加ツール不要。
² esp32c6 チップの I2C デフォルトピンは GPIO6/7 だが JTAG 用で XIAO のエッジパッドに出ていないため、ランタイムのデフォルトを XIAO の D4=GPIO22 / D5=GPIO23 に変更済み。`examples/xiao_c6/i2c_scan.rb` は同ピンを明示指定しており、実機で I2C デバイス検出を確認済み。
³ MSP2807（ILI9341）は `LCD.new(invert: false, madctl: 0xE8)`。M5Stack ILI9342C は既定（INVON）。
⁴ esp32c6 の TCPSocket / UDPSocket は ESP-IDF lwIP の BSD ソケットで実装（picoruby-socket の ports/esp32 を流用）。ホスト名・`.local`（mDNS）解決は `getaddrinfo` 経由。UDP サンプルは [examples/xiao_c6/socket-udp.rb](../examples/xiao_c6/socket-udp.rb)。**両方とも XIAO ESP32C6 実機で疎通確認済み**（UDP: connect → send → recvfrom_nonblock、TCP: connect → write → read_nonblock/gets、いずれもエコーサーバと往復）。
⁵ M5StickC PLUS（ESP32-PICO-D4、内蔵フラッシュ）は同じ esp32 ランタイムで動く。install は eFuse の SPI pad 設定を読んで SPI_ATTACH するようになったため M5GO と同じ `EspFlasher` で書き込める（内蔵フラッシュ機は以前 `SPI_ATTACH(0)` だと `FLASH_BEGIN` が無応答のままハングしていた）。LCD は ST7789v2 135x240 で `LCD.new` に `width:`/`height:`/`offset_x:`/`offset_y:` を渡す（`examples/m5stickc_plus/lcd_hello.rb` 参照）。バックライト/パネル電源は GPIO PWM ではなく AXP192（I2C アドレス `0x34`）の LDO2/LDO3 で、明示的な有効化が要る。WiFi/NTP は M5GO と同じ API がそのまま動く（`examples/m5stickc_plus/wifi.rb` / `ntp_clock.rb`）。ボタン A は GPIO37（`examples/m5stickc_plus/buttons.rb`）；ボタン B は情報源間でピン番号が食い違い（M5Stack Arduino ライブラリの Config.h は GPIO39、他ドキュメントは GPIO2）、実機でもどちらも確認できず未実装。**install・LCD・WiFi・NTP・GPIO(ボタン A のみ)を実機確認済み**（M5StickC PLUS）。ADC/PWM/I2C(汎用センサ)/SPI(外部デバイス)/ボタン B は未検証で、独立したボード列としてはまだ扱っていない。

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
