# Support matrix & release smoke test

prremote が対応しているボード × 機能の一覧と、リリース後に実機で行う動作確認（スモークテスト）手順。
物理デバイスが相手なので完全自動化はできないが、**シリアル出力で判定できる項目は `rake smoke[BOARD]` で半自動化**している。
残り（LCD 表示・LED・ボタン・実センサー値）は目視で確認する。

> 実装の経緯・設計判断は [CHANGELOG.md](../CHANGELOG.md) と git log を、未着手の将来計画は [PLAN.md](../PLAN.md) を参照。

## Support matrix

| 機能 | pico | picow | pico2 (RP2350) | esp32 (M5GO) | esp32c6 (XIAO) |
|---|:--:|:--:|:--:|:--:|:--:|
| install（書き込み） | ✅ UF2 | ✅ UF2 | ✅ UF2 | ✅ EspFlasher | ✅ esptool¹ |
| run / eval / watch | ✅ | ✅ | ✅ | ✅ | ✅ |
| deploy / undeploy | ✅ | ✅ | ✅ | ✅ | ✅ |
| GPIO | ✅ | ✅ | ✅ | ✅ | ✅ |
| ADC | ✅ | ✅ | ✅ | ✅ | ✅ |
| PWM | ✅ | ✅ | ✅ | ✅ | ✅ |
| I2C | ✅ | ✅ | ✅ | ✅ | ✅² |
| SPI | ✅ | ✅ | ✅ | ✅ | ✅ |
| WiFi | — | ✅ | — | ✅ | ✅ |
| NTP（時刻同期） | — | ✅ | — | ✅ | ✅ |
| TCPSocket | — | ✅ | — | — | — |
| LCD | — | — | — | ✅ ILI9342C | ✅ ILI9341³ |

✅ = 実装済み・実機確認済み / — = 非対応（ハード非搭載 または 未実装）

¹ esp32c6 は USB Serial/JTAG のため `esptool` 必須（`brew install esptool`）＋手動 bootloader モード（hold BOOT → press RST）。他ボードは追加ツール不要。
² esp32c6 の I2C デフォルトピンは GPIO6/7。XIAO のエッジパッド（D4=GPIO22 / D5=GPIO23）とは食い違っており実機未確定（[PLAN.md](../PLAN.md) の「XIAO ESP32C6 の周辺ピン確定」参照）。
³ MSP2807（ILI9341）は `LCD.new(invert: false, madctl: 0xE8)`。M5Stack ILI9342C は既定（INVON）。

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

- [ ] `install -b esp32c6` → esptool ＋ hold BOOT→press RST で書き込み、READY
- auto: version / eval / wifi
- [ ] `gpio.rb`: 黄色 LED（GPIO15）点滅、ボタン（GPIO2）で "pressed"
- [ ] `led.rb`: 黄色 LED（`GPIO.led` → GPIO15 active-low）が点滅
- [ ] `pwm.rb`: 黄色 LED（GPIO15）がブリージング（明→暗を繰り返す）
- [ ] `spi_loopback.rb`: D10(MOSI/GPIO18)↔D9(MISO/GPIO20) をジャンパ直結で "OK: loopback matched"
- [ ] `lcd_hello.rb`: MSP2807 が正立 320×240（`invert: false` / `madctl: 0xE8`）
- [ ] `i2c_scan.rb`: ※デフォルトピン GPIO6/7 は実機未確定（[PLAN.md](../PLAN.md) 参照）
- [ ] `ntp_clock.rb`: シリアルに JST が出る

---

> このチェックリストは [`tasks/smoke.rake`](../tasks/smoke.rake) の手順と対応している。項目を増やしたら両方を更新する。
