# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Runtime: `Temperature` class for reading the RP2040 on-chip temperature sensor (ADC channel 4). `Temperature.new.celsius` / `.fahrenheit` — no external wiring needed.
- Sample: `test/samples/temperature.rb` — on-chip temperature, 10 readings with 1-second interval.
- Sample: `test/samples/i2c_adt7410.rb` (renamed from `i2c.rb`) — ADT7410 I2C temperature sensor; fixed byte extraction to use `String#bytes` for correct integer values.
- Sample: `test/samples/i2c_scan.rb` — scan all I2C addresses and print responding ones.

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
