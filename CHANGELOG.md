# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.5] - unreleased

### Added

- `run`, `deploy`, `watch` now accept multiple files: `prremote run lib.rb main.rb`
  Files are compiled in order by mrbc into a single `.mrb`; classes defined in earlier
  files are available to later ones (no `require` needed in mruby/c).
- `watch` re-runs when any of the watched files changes.
- Sample: `test/samples/multi/` — demonstrates splitting a script into `blinker.rb` (class) and `main.rb` (entry point).

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

[Unreleased]: https://github.com/lumbermill/prremote/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/lumbermill/prremote/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/lumbermill/prremote/releases/tag/v0.1.0
