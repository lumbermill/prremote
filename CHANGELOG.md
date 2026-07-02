# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Runtime: `UDPSocket` and `TCPSocket` on the **esp32c6** build. The esp32c6 runtime now defines `HAS_SOCKET` / `HAS_UDP_SOCKET` and links picoruby-socket's `ports/esp32` (lwIP BSD sockets) plus the shared `src/mrubyc` VM bindings; `getaddrinfo` resolves plain hostnames and `.local` (mDNS) names (the sdkconfig already enables `CONFIG_LWIP_DNS_SUPPORT_MDNS_QUERIES`). The picow TCP layer is untouched: `src/socket_wrap.h` (BasicSocket + TCPSocket Ruby) is reused verbatim, and the UDPSocket Ruby layer is compiled into a separate `src/socket_wrap_udp.h` blob so the two builds never diverge. The two extra socket wrap tasks push esp32c6 past mruby/c's default 5-VM limit, so its `MAX_VM_COUNT` is raised to 8. _Both verified on a physical XIAO ESP32C6: UDPSocket (mDNS `.local` resolve → connect → send → recvfrom round-trip) and TCPSocket (connect → write → read_nonblock/gets round-trip) against echo servers._
- Example: `examples/xiao_c6/socket-udp.rb` — XIAO ESP32C6 UDPSocket round-trip: connect (with `.local` mDNS resolution), send comma-separated values, poll for a reply with `recvfrom_nonblock`. Notes the connected-UDP gotcha (the server must reply from the same port to the sender) and ships a minimal CRuby echo server to test against.
- Example: `examples/xiao_c6/spi_loopback.rb` — SPI self-test for the XIAO ESP32C6 using a single MOSI->MISO jumper (D10/GPIO18 <-> D9/GPIO20); `transfer` echoes the sent bytes. Exercises the SPI read path with no extra device (the LCD already proves the write path).
- Example: `examples/xiao_c6/pwm.rb` — breathes (fades in/out) the XIAO ESP32C6 onboard yellow LED (GPIO 15) via PWM. No external wiring needed; the active-low inversion is absorbed in the script so the ramped value matches perceived brightness. The C-layer PWM binding (LEDC, 6 channels) already existed; this adds the missing C6-specific copy-paste sample.
- Example: `examples/xiao_c6/i2c_adt7410.rb` — reads temperature from an ADT7410 I2C sensor on the XIAO ESP32C6's D4/D5 pins (GPIO22/23), ported from the existing `examples/pico/i2c_adt7410.rb` sample.
- Docs: `docs/SUPPORT.md` — board × feature support matrix (pico / picow / pico2 / esp32 / esp32c6) that doubles as a post-release manual verification checklist for physical devices.
- Development: `rake smoke[BOARD]` — semi-automated smoke test that runs the device over serial and asserts output for the checkable steps (version banner, `eval`, WiFi/IP), and prints the visual checks (LCD / LED / buttons) as a manual checklist. Configurable via `PORT` / `BAUD` / `SMOKE_WIFI` / `SMOKE_NTP` / `PRREMOTE`. Mirrors `docs/SUPPORT.md`.
- Runtime (ESP32/ESP32-C6): `LCD#draw_line`, `LCD#draw_circle`, `LCD#draw_ellipse` (with `fill:`) implemented in C (`lcd_ili9342c.c`), replacing the fill_rect-stacking approach user scripts had to do themselves. `draw_line` special-cases axis-aligned runs (one SPI transaction) and otherwise walks integer Bresenham; `draw_circle` uses the midpoint circle algorithm; `draw_ellipse` uses the two-region midpoint ellipse algorithm (Foley & van Dam) so it doesn't leave gaps near the major/minor axis tips the way a naive per-row `sqrt` scan does. Filled shapes are drawn as horizontal runs (`fill_rect` under the hood) instead of pixel-by-pixel, so they're one SPI transaction per row rather than per pixel. Verified via `idf.py build` on both esp32 and esp32c6 targets (no physical panel available for this change — visual verification pending real hardware).
- Example: `examples/m5go/lcd_shapes.rb` — exercises the new draw_line/draw_circle/draw_ellipse (outline and filled) on the M5GO's internal panel, no wiring needed.

### Fixed

- Example: `examples/xiao_c6/i2c_scan.rb` — fixed the pin numbers. The sample used `sda_pin: 6, scl_pin: 7` (the ESP32C6 chip's I2C default pins), but those GPIOs aren't broken out on the XIAO ESP32C6's edge pads. The board's silkscreened D4/D5 (I2C SDA/SCL) actually map to GPIO22/GPIO23. Now uses `sda_pin: 22, scl_pin: 23`, verified against a real I2C device on a physical XIAO ESP32C6.
- Runtime (**esp32c6**): PWM no longer breaks (LED stuck on, `E ledc: ledc_set_timer_div(...): timer clock conflict, already is 9 but attempt to 4`). All ESP32-C6 LEDC low-speed timers share **one** global clock source, but the PWM class and the LCD backlight chose different ones via `LEDC_AUTO_CLK`: the backlight (5 kHz/8-bit) resolved to XTAL (clock id 9) while PWM at 1 kHz/16-bit needs PLL_F80M (id 4). Because the firmware keeps LEDC state across `prremote run` invocations (a run never resets the chip), once an LCD example had run, every later PWM script hit `ledc_timer_config()` "timer clock conflict" — the timer kept its stale resolution while `res_bits` said otherwise, so `duty_u16=` wrote a saturated value. Both the PWM binding and the LCD backlight are now pinned to `PLL_F80M` (matching PWM's existing 80 MHz resolution budget) so the clock choice is always identical, and `_pwm_set_freq` now raises instead of silently continuing if the timer config fails. Classic ESP32 (no PLL_DIV clock, proven working on M5GO) is left on `LEDC_AUTO_CLK`.

### Changed

- CLI: `install -b esp32c6` (and any USB-Serial/JTAG board routed through esptool) now flashes **hands-free** — no more manual BOOT/RST button dance. esptool is invoked with `--before usb-reset`, which drops the chip into the download ROM over USB, and `--after hard-reset`, which reboots straight into the freshly flashed firmware. If usb-reset doesn't take on some host/board, it falls back to the previous manual bootloader entry (`--before no-reset`), now with `--connect-attempts 0` (retry forever) so the manual case waits indefinitely instead of failing with "No serial data received" after esptool's default 7 attempts. _Verified hands-free end-to-end on a physical XIAO ESP32C6: `install -b esp32c6` flashed 0.2.1 with no buttons in ~4.7 s, and the board rebooted into the runtime (`prremote version` → `runtime: 0.2.1`)._
- Runtime (**breaking**): the WiFi API moved from `CYW43` to a chip-neutral `WiFi` module, and the sub-module nesting was flattened. `CYW43` was the part number of the Pico W's Infineon radio, but the same API also drives ESP32's built-in WiFi — so the chip name was misleading on every non-Pico-W board. There is no compatibility alias; user scripts must be updated:
  - `CYW43.init` → `WiFi.init`
  - `CYW43.initialized?` / `enable_sta_mode` / `disable_sta_mode` → `WiFi.*`
  - `CYW43::WiFi.connect` / `disconnect` / `link_status` → `WiFi.connect` / `disconnect` / `link_status`
  - `CYW43::WiFi.ipv4_address` / `ipv4_netmask` / `ipv4_gateway` → `WiFi.ipv4_*`
  - `CYW43::Auth::*` → `WiFi::Auth::*`
  - `CYW43::WiFi::ConnectError` / `ConnectTimeout` / `LINK_*` → `WiFi::ConnectError` / `ConnectTimeout` / `LINK_*`
  - `CYW43::GPIO` (Pico W onboard LED) → `GPIO.led` (see below). It is conceptually a GPIO, not WiFi.
  - The underlying C primitives (`_cyw43_*` / `_wifi_*`) and the `cyw43_wrap.rb` filename are unchanged — they are internal and never referenced by user scripts.

- Runtime: `GPIO.led` — board-neutral access to the onboard LED. `GPIO.led.write(1)` / `write(0)` turn it on/off the same way on every board; all hardware differences are absorbed in the C layer (new `_led_init` / `_led_put` / `_led_get` primitives):
  - Pico W / Pico 2 W: the LED hangs off the CYW43 wireless chip's GPIO0, so the chip is powered up automatically on first use (no network connection is made) — the user no longer calls `WiFi.init` to blink the LED.
  - Pico / Pico 2: `PICO_DEFAULT_LED_PIN` (GPIO 25).
  - XIAO ESP32C6: the active-low user LED on GPIO 15 — the inversion is hidden, so `write(1)` always means "on".
  - M5GO / M5Stack Core gen1: raises `RuntimeError` (no single-color onboard LED; it has an RGB LED bar instead).
  - New samples `examples/pico/led.rb` (whole Pico family) and `examples/xiao_c6/led.rb`. The Pico one replaces the now-merged `led_pico.rb` + `led_picow.rb`, which no longer need to be board-specific.

### Fixed

- Development: the `rake setup` pre-push hook scanned `test/samples` for non-placeholder WiFi credentials, but samples moved to `examples/` — the guard had been a no-op. It now scans `examples/`. Re-run `rake setup` to refresh the installed hook.
- Build: bumping `VERSION` now re-runs CMake automatically. The pico and ESP-IDF `CMakeLists.txt` read `VERSION` at configure time (to name the artifact and embed `RUNTIME_VERSION`), but a change to `VERSION` alone did not invalidate the CMake cache — so `rake cache` rebuilt with the stale value, producing an old-named `.uf2` and a stale READY banner unless the build dir was deleted by hand. `VERSION` is now registered via `CMAKE_CONFIGURE_DEPENDS`, so all boards reconfigure on a version bump.

## [0.2.1] - 2026-06-30

### Added

- CLI: `prremote install --verbose` / `-V` prints step-by-step flash diagnostics to aid debugging.

- CLI: `prremote install` now supports `esp32c6` as a board target (`-b esp32c6` / `--board esp32c6`). Running `prremote install` without `--board` prints the list of supported boards instead of defaulting to picow. ESP32-C6 is flashed via the `esptool` CLI (delegated because the ROM returns error 0x38 on FLASH_BEGIN regardless of parameters — the Seeed factory firmware sets flash block-protection bits that only esptool's RAM stub can clear). Install esptool with `brew install esptool` or `pip3 install esptool`.

- Runtime: `exit` method — stops the running script and returns the runtime to READY state (equivalent to the script finishing naturally; no reboot). Available on all platforms (Pico, ESP32, ESP32-C6). Optional argument accepted but ignored.

- Runtime: `esp32c6` build target — supports ESP32-C6 (RISC-V) boards such as the Seeed Studio XIAO ESP32C6. Console via USB Serial/JTAG (no UART-to-USB bridge); LEDC 6 channels; SPI2_HOST only; ADC on GPIO 0–6; default I2C SDA=6/SCL=7, SPI SCK=19/MOSI=18. `merge_bin` bootloader placed at `0x0` (RISC-V requirement, vs `0x1000` on Xtensa). Build: `rake build:esp32c6` (requires `./install.sh esp32c6` from ESP-IDF).

- Runtime (ESP32-C6): LCD support — the ESP32 ILI9342C/ILI9341 SPI driver (`lcd_ili9342c.c`) is now compiled into the ESP32-C6 build as well, shared verbatim with the classic ESP32 build (`LCD_HOST` switches to `SPI2_HOST` on C6, which has no SPI3). The `LCD` class (`fill`/`fill_rect`/`pixel`/`text`/`brightness=`) now works on XIAO ESP32C6.

- Runtime (ESP32): `LCD.new(invert:)` — selects INVON (`true`, default; M5Stack ILI9342C panels) vs INVOFF (`false`; standard ILI9341 panels such as MSP2807), so one driver serves both panel families.

- Runtime (ESP32): `LCD.new(madctl:)` — overrides the per-rotation MADCTL byte (memory access control). The built-in table is tuned for the ILI9342C (native landscape); portrait-native ILI9341 panels need the MV bit set for landscape. Verified on hardware: the MSP2807 ILI9341 on a XIAO ESP32C6 shows an upright, non-mirrored 320×240 landscape with `madctl: 0xE8` (and `0x28` for an upside-down 180° mount). `examples/xiao_c6/lcd_hello.rb` now passes `madctl: 0xE8`.

- Examples (XIAO ESP32C6): `examples/xiao_c6/` — five examples for the Seeed Studio XIAO ESP32C6: `gpio.rb` (onboard LED GPIO 15 active-low, button input on GPIO 2), `wifi.rb`, `i2c_scan.rb` (SDA=GPIO 6 / SCL=GPIO 7), `ntp_clock.rb` (NTP-synced JST clock printed to serial), `lcd_hello.rb` (ILI9341 2.8" SPI TFT / MSP2807: solid fill, rectangles, 8x8 text; SCK=GPIO 19 / MOSI=GPIO 18 / CS=GPIO 21 / DC=GPIO 1 / RST=GPIO 0 / BL=GPIO 16).

- Tool: `tools/img2rle.rb` — converts an image (JPEG, PNG, etc.) to RLE-encoded RGB565 Ruby source via ImageMagick; outputs a packed binary string constant (~4 bytes/segment) suitable for `fill_rect`-based playback on the device LCD. Run `ruby tools/img2rle.rb INPUT [OUTPUT] [options]`.

- Sample (ESP32 / M5GO): `rubykaigi27.rb` — RubyKaigi 2027 (2027-04-13) countdown; shows days relative to the event (negative = before, 0 = event day, positive = after) in large text (scale 6) on the M5GO LCD with a Ruby gem logo (top-left), "RubyKaigi 2027" title (top-right), and a gray timestamp footer; syncs date/time via NTP.
- Sample (ESP32 / M5GO): `savao.rb` — singing face animated on the M5GO LCD; ANGLE SENSOR (PORT B / GPIO36) controls speaker pitch (200–2000 Hz) and mouth opening simultaneously; BtnA mutes, BtnB inverts colors, BtnC exits.

### Changed

- Runtime (ESP32): `MRB_BUFFER_SIZE_KB` increased to 64 (was 32); made overridable via compile-time define so Pico builds retain 32 KB. Enables bytecode files with large embedded string constants (e.g. RLE image data ~45 KB).
- Runtime (ESP32): `MRBC_SUPPORT_OP_EXT` enabled; required for bytecode generated from files with many string literals.

- Runtime (ESP32): `LCD_MAX_SCALE` raised from 4 to 6 and `LCD_MAX_CHUNK` from 2048 to 4608 bytes, enabling `lcd.text(..., scale: 5)` and `scale: 6` (48×48 px per glyph).

- Samples (ESP32 / M5GO): five new samples for the M5Stack ecosystem.
  - `angle_meter.rb` — ANGLE SENSOR unit (PORT B / GPIO36) displayed as a real-time bar meter + percentage on the M5GO LCD.
  - `angle_theremin.rb` — ANGLE SENSOR knob controls the built-in speaker (GPIO25) pitch via PWM (200–2000 Hz); BtnA mutes, BtnC exits.
  - `motion_counter.rb` — MOTION SENSOR unit (PIR, PORT B / GPIO36) counts rising-edge events; large count on LCD, BtnA resets.
  - `whack_a_mole.rb` — Whack-a-Mole game: moles appear in left/center/right columns, press A/B/C to whack; 20 rounds, score on LCD.
  - `imu_level.rb` — Digital spirit level using the built-in MPU6886 IMU (I2C 0x68); a bubble moves with tilt, turns green when level.

- Sample (`ntp_clock.rb`): center date and time horizontally on the 320×240 LCD; add a Ruby gem logo (flat-top faceted diamond silhouette, red with white glint) in the bottom-right corner; move "JST (UTC+9)" label up and add "by prremote" footer.

- Examples: `examples/esp32/` renamed to `examples/m5go/`; `_m5go` suffix dropped from all filenames (folder name now conveys the board context).

### Fixed

- Runtime (ESP32-C6): scripts failed to run with `Not support such type (IREP_TT=...)` / `ERROR exec`. The console used ESP-IDF's default non-driver USB Serial/JTAG VFS, whose `getchar()` is non-blocking and returns EOF for bytes not yet arrived; `recv_exact` stored those as 0xFF, desyncing the binary `.mrb` stream. `prr_console_init()` now installs the interrupt-driven driver and calls `usb_serial_jtag_vfs_use_driver()` so reads block until each byte is available (as the classic ESP32 build does for UART). RX line-ending conversion is also disabled (`ESP_LINE_ENDINGS_LF`) so a CR byte in the bytecode is not turned into LF. Installing the driver additionally makes the in-script Ctrl+C reset detection (`usb_serial_jtag_read_bytes`) functional.

- CLI (ESP32-C6): even with blocking reads, the device then stalled (no `RUNNING`/`ERROR`) because the host wrote the whole `.mrb` in one burst, overflowing the USB Serial/JTAG 256-byte driver RX ring (the controller applies no USB backpressure, so the excess is dropped and `recv_exact` blocks forever). `run`/`deploy` now send the payload via `write_chunked` in ≤256-byte chunks with a 4 ms gap. The pacing is negligible on the baud-limited transports (Pico USB-CDC / ESP32 UART bridge), where a 256-byte chunk already takes ~22 ms to clock out at 115200 baud.

- Runtime (ESP32-C6): intermittent hard wedge — `run` occasionally timed out with `Timeout waiting for device to start execution`, and once wedged the device stopped answering anything (even `version`) until a physical reset. Under sustained back-to-back receives the USB Serial/JTAG still drops a byte every so often despite the host-side chunking; `recv_exact` then blocked in `getchar()` forever waiting for a byte that had already passed, and because that loop never inspects the stream, the `0x03` sent by `reset`/`version` could not break it out. Two-part fix: (1) the payload receive path now reads with a 2 s per-byte timeout (new `prr_getchar_timeout`, implemented on all platforms) — a dropped byte now aborts the transfer with `ERROR recv` and returns to READY, so the next `run` recovers without a physical reset; (2) the C6 USB Serial/JTAG RX ring is enlarged from 256 B to 4096 B to absorb drain-stall transients and make the drop far rarer in the first place.

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
