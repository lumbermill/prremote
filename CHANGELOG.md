# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Sample (ESP32 / M5GO): `rubykaigi27_m5go.rb` — RubyKaigi 2027 (2027-04-13) countdown; shows days relative to the event (negative = before, 0 = event day, positive = after) in large text (scale 6) on the M5GO LCD with a Ruby gem logo (top-left), "RubyKaigi 2027" title (top-right), and a gray timestamp footer; syncs date/time via NTP.

### Changed

- Runtime (ESP32): `LCD_MAX_SCALE` raised from 4 to 6 and `LCD_MAX_CHUNK` from 2048 to 4608 bytes, enabling `lcd.text(..., scale: 5)` and `scale: 6` (48×48 px per glyph).

- Samples (ESP32 / M5GO): five new samples for the M5Stack ecosystem.
  - `angle_meter_m5go.rb` — ANGLE SENSOR unit (PORT B / GPIO36) displayed as a real-time bar meter + percentage on the M5GO LCD.
  - `angle_theremin_m5go.rb` — ANGLE SENSOR knob controls the built-in speaker (GPIO25) pitch via PWM (200–2000 Hz); BtnA mutes, BtnC exits.
  - `motion_counter_m5go.rb` — MOTION SENSOR unit (PIR, PORT B / GPIO36) counts rising-edge events; large count on LCD, BtnA resets.
  - `whack_a_mole_m5go.rb` — Whack-a-Mole game: moles appear in left/center/right columns, press A/B/C to whack; 20 rounds, score on LCD.
  - `imu_level_m5go.rb` — Digital spirit level using the built-in MPU6886 IMU (I2C 0x68); a bubble moves with tilt, turns green when level.

### Changed

- Sample (`ntp_clock_m5go.rb`): center date and time horizontally on the 320×240 LCD; add a Ruby gem logo (flat-top faceted diamond silhouette, red with white glint) in the bottom-right corner; move "JST (UTC+9)" label up and add "by prremote" footer.

## [0.2.0] - 2026-06-12

### Changed

- Samples reorganized by platform: `test/samples/pico/` (Pico / Pico W) and `test/samples/esp32/`.
- Runtime: platform abstraction layer (`prr_platform.h`) — the serial protocol core (`runtime.c`) is now platform-neutral; all pico-sdk specifics (USB CDC stdio, XIP flash storage, watchdog reset) moved to `platform_pico.c`. No behavior change; groundwork for ESP32 support.
- Runtime: `hw_wrap.rb` is now shared between the Pico and ESP32 builds. `I2C.new` / `SPI.new` accept `unit: 0` / `1` or `:I2C0` / `:SPI0` style symbols (`:RP2040_I2C0` etc. still work); the ADC pin→channel mapping moved to the C layer (`_adc_read_pin`).

### Added

- Runtime: `Integer#zero?` — returns `true` if the receiver is 0 (mruby/c does not include this by default).

- Runtime (ESP32): WiFi support — `CYW43::WiFi.connect/disconnect`, `ipv4_address/netmask/gateway`, `CYW43::WiFi::ConnectError/ConnectTimeout` — same API as Pico W. Implemented via ESP-IDF `esp_wifi` + FreeRTOS EventGroup; `cyw43_wrap.rb` is now shared between both platforms. `CYW43.init` initialises NVS, netif, and the WiFi driver (idempotent). `connect` retries transient disconnects until the timeout (matching Pico W's `cyw43_arch_wifi_connect_timeout_ms`) and maps `CYW43::Auth::*` to the ESP-IDF authmode threshold — use `WPA2_MIXED_PSK` for WPA/WPA2 mixed-mode APs, which a hard `WPA2` threshold rejects (disconnect reason 211).
- Runtime (ESP32): NTP / `Time` class — `_ntp_gettime` implemented with `esp_sntp` (ESP-IDF 5.x); `time_wrap.rb` is now shared with the Pico W build. `Time.new(offset: 9).sync(host)` works identically on both platforms.
- Samples: `test/samples/esp32/wifi.rb` — connect and print IP info. `test/samples/esp32/ntp_clock_m5go.rb` — NTP-synced JST clock on the M5GO LCD with hourly re-sync.
- Build: `HAS_CYW43` compile flag renamed to `HAS_WIFI`; socket layer now guarded by separate `HAS_SOCKET` flag. Pico W sets both; ESP32 sets `HAS_WIFI` only (TCP socket support is a future task).

- Runtime: ESP32 (classic) support — new ESP-IDF project under `runtime/esp32/` implementing the same serial protocol (READY/RITE/DPLY/ERSE/QURY) on the UART0 console. Deployed scripts are stored in a dedicated `prremote` flash partition, byte-compatible with the Pico layout. GPIO / ADC / PWM (LEDC) / I2C / SPI bindings via ESP-IDF drivers in `bindings_esp32.c`. Requires ESP-IDF v5.3 to build.
- Samples: `test/samples/esp32/` — `gpio.rb`, `i2c_scan_m5go.rb`, `buttons_m5go.rb` (M5GO / M5Stack Core)
- Runtime (ESP32): `LCD` class for ILI9342C SPI panels (M5GO / M5Stack Core gen1 pin defaults, all pins configurable). `fill` / `fill_rect` / `pixel` / `text` (built-in 8x8 font, scale 1-4) / `brightness=`. RGB565 colors via constants or `LCD.rgb(r, g, b)`. No framebuffer — pixels stream through 2 KB DMA buffers.
- Samples: `test/samples/esp32/lcd_hello.rb`, `test/samples/esp32/lcd_demo.rb` (color swatches + live counter, deployable)
- `install --board esp32` — flashes the ESP32 runtime (single merged `.bin` at 0x0) over the serial port with a **pure-Ruby implementation of the Espressif bootloader protocol** (`EspFlasher`): DTR/RTS auto-reset via ioctl, SLIP framing, ROM-loader FLASH_BEGIN/DATA, on-chip MD5 verification, 230400 baud transfer. No esptool / Python required (macOS/Linux). Reflashing the runtime preserves the deployed script (separate flash partition).
- `list` / port auto-detection now recognizes ESP32 USB-UART bridges (CP210x `10c4`, CH910x `1a86`) alongside the Raspberry Pi VID.
- `run` / `deploy` etc.: `wait_for_ready` re-sends Ctrl+C every second — ESP32 boards reset when the port opens (DTR/RTS auto-reset) and the initial Ctrl+C could be lost during boot. Harmless on Pico.
- `runtime/Rakefile`: `rake build:esp32` (ESP-IDF + esptool merge_bin), `rake build_all`; `rake cache` / `rake release` now cover esp32.

- Runtime (Pico W): `Time` class — SNTP-synced wall clock. `Time.new(offset: 9)` creates a JST clock; `.sync(host, interval: N, timeout: N)` fetches time via SNTP (UDP port 123, RFC 4330) with optional retry (`interval: nil` = single attempt, `timeout: nil` = no limit, `timeout: N` uses wall-clock via `uptime_ms`); `.sleep(n)` sleeps and advances the clock; `.epoch` returns seconds since Unix epoch (Integer); `t - epoch_int` / `t - other_time` returns elapsed seconds; `.year` / `.month` / `.day` / `.hour` / `.min` / `.sec` accessors; `.to_s` formats as `YYYY-MM-DDTHH:MM:SS±offset`.
- Runtime: `uptime_ms` — milliseconds since boot (`Kernel` method, wraps at ~49 days). Uses `time_us_64()` from pico-sdk.
- Runtime (Pico W): `ntp.c` — SNTP client over lwIP UDP raw API (`ntp_get_unix_time`). Exposed as `_ntp_gettime(host, timeout_ms)` Kernel method.
- Sample: `test/samples/pico/ntp_clock_picow.rb` — displays JST time with hourly NTP re-sync (rewritten to use `Time` class).
- Runtime: `Temperature` class for reading the RP2040 on-chip temperature sensor (ADC channel 4). `Temperature.new.celsius` / `.fahrenheit` — no external wiring needed.
- Sample: `test/samples/pico/temperature.rb` — on-chip temperature, 10 readings with 1-second interval.
- Sample: `test/samples/pico/i2c_adt7410.rb` (renamed from `i2c.rb`) — ADT7410 I2C temperature sensor; fixed byte extraction to use `String#bytes` for correct integer values.
- Sample: `test/samples/pico/i2c_scan.rb` — scan all I2C addresses and print responding ones.

### Fixed

- Samples / `Time`: embed `Time` in strings with an explicit `.to_s` — mruby/c's `OP_STRCAT` does not call a Ruby-defined `#to_s` (upstream `vm.c` TODO), so `"#{t}"` silently interpolated as an empty string. Samples updated; `Lint/RedundantStringCoercion` disabled in `.rubocop.yml` because the explicit call is required in device code.
- Runtime: wrapper tasks (`hw_wrap` etc.) now run at a higher mruby/c scheduler priority than the user script. Previously all tasks shared the default priority and round-robined on timeslice expiry, so the user script could start while a wrapper class was only half defined and fail with `NoMethodError` (e.g. `GPIO#initialize` present but `GPIO#write` missing). The window widens with each additional wrapper task, which is how the ESP32 WiFi work exposed it.
- Runtime: `mrb_buffer` (32 KB) and `memory_pool` (96 KB) are heap-allocated at startup instead of static arrays. As `.bss` data they shared the ESP32's ~180 KB static DRAM segment with the WiFi stack, exhausting it — the firmware boot-looped (`assert failed: esp_startup_start_app`) before printing `READY`. No functional change on Pico.

## [0.1.7] - 2026-06-06

### Added

- `run`, `deploy`: warn when the runtime firmware version is older than the gem and prompt the user to run `prremote install`.

### Fixed

- `run`, `deploy`: device disconnect during execution (e.g. ENXIO on macOS when the Pico resets unexpectedly) now shows a human-readable error instead of a bare errno name.
- `prremote run`: flush output line-by-line instead of waiting for 512-byte buffer, so `puts` results appear immediately during debugging.
- Runtime: `CYW43::WiFi.connect` no longer calls `disconnect` before connecting. If already connected the existing session is reused; call `disconnect` explicitly to force reconnection.

## [0.1.6] - 2026-06-05

### Changed

- Runtime: CYW43 WiFi methods moved into `CYW43::WiFi` sub-module to prepare for future Bluetooth support (`CYW43::BT`).
  - `CYW43.connect_timeout` → `CYW43::WiFi.connect`
  - `CYW43.disconnect` → `CYW43::WiFi.disconnect`
  - `CYW43.tcpip_link_status` → `CYW43::WiFi.link_status`
  - `CYW43.ipv4_address/netmask/gateway` → `CYW43::WiFi.ipv4_address/netmask/gateway`
  - `CYW43::ConnectTimeout` → `CYW43::WiFi::ConnectTimeout`
  - New: `CYW43::WiFi::ConnectError` raised on authentication failure (previously subsumed into `ConnectTimeout`)
  - New: `CYW43::WiFi::LINK_*` constants for link status codes
  - `CYW43::WiFi.connect` now calls `enable_sta_mode` internally; callers no longer need to call `CYW43.enable_sta_mode` before connecting
  - `CYW43.init`, `CYW43.enable_sta_mode`, `CYW43::Auth`, `CYW43::GPIO` are unchanged.

### Fixed

- `run`, `deploy`, `ls`: send `\x03` (Ctrl+C) immediately after opening the serial port to force the device to re-emit `READY`. On macOS, USB CDC TX buffers are dropped when the host closes the port, leaving the device waiting in `getchar()` without re-sending `READY`, causing a "Timeout waiting for device" error on the next invocation.

## [0.1.5] - 2026-05-27

### Added

- `ls` — Show the script currently deployed to flash: filenames and deploy timestamp.
  Requires `prremote reset` first if a script is actively running.
- `deploy` now records filenames and timestamp in the flash header (runtime protocol extended with `META` + `QURY` commands); **runtime firmware must be updated** (`prremote install`).
- `run`, `deploy`, `watch` now accept multiple files: `prremote run lib.rb main.rb`
  Files are compiled in order by mrbc into a single `.mrb`; classes defined in earlier
  files are available to later ones (no `require` needed in mruby/c).
- `watch` re-runs when any of the watched files changes.
- Sample: `test/samples/multi/` — demonstrates splitting a script into `blinker.rb` (class) and `main.rb` (entry point).

### Fixed

- `run`: Ctrl+C now sends `\x03` to the device before closing the serial port, preventing `ENXIO` on the next `run` invocation.
- `run`, `deploy`, `ls`: now wait for the device's `READY` message before sending data, eliminating intermittent "Timeout waiting for device to start execution" errors caused by the fixed 0.5 s sleep being too short.
- Runtime: on receiving `\x03` (Ctrl+C), `tud_disconnect()` is called first to cleanly detach from the host (equivalent to unplugging the cable), followed by a watchdog reset. This prevents the host USB stack from getting confused by a reset without prior detach.

## [0.1.1] - 2026-05-17

### Fixed

- Default runtime version updated to 0.1.3 (0.1.0 shipped with 0.1.2, which is missing `undeploy` support and standalone auto-run on boot)
- `RubySerial::Error` is now caught correctly in all commands (`run`, `deploy`, `eval`, `watch`, `reset`, `install`); previously `rescue RuntimeError` failed to catch it

## [0.1.0] - 2026-05-16

### Added

- `install` — Download UF2 firmware (with local cache) and flash via BOOTSEL mode
- `run FILE` — Compile `.rb` to `.mrb` with mrbc and execute on device (one-shot, not saved)
- `deploy FILE` — Compile and write script to flash; auto-runs on next boot
- `undeploy` — Erase deployed script from flash via `ERSE` protocol; disables auto-run
- `eval EXPR` — Compile and run a one-liner expression on the device
- `reset` — Send `0x03` (Ctrl+C) over serial to reboot the device
- `list` — List detected serial devices
- `version` — Show prremote version, mrbc path/version, and device runtime version
- `watch FILE` — Watch a file for changes and re-run automatically (0.5 s polling)
- `Mrbc` module — Shared mrbc binary lookup; overridable via `$MRBC` environment variable
- mruby/c runtime (`runtime/`) for Raspberry Pi Pico W

[Unreleased]: https://github.com/lumbermill/prremote/compare/v0.1.5...HEAD
[0.1.5]: https://github.com/lumbermill/prremote/compare/v0.1.1...v0.1.5
[0.1.1]: https://github.com/lumbermill/prremote/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/lumbermill/prremote/releases/tag/v0.1.0
