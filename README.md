# prremote

> ⚠️ This project is in early development. APIs and commands are subject to change.

**prremote** is a command-line tool for deploying and running Ruby scripts on a Raspberry Pi Pico W or ESP32 (e.g. M5Stack) over USB serial. It ships a minimal [mruby/c](https://github.com/mrubyc/mrubyc) runtime firmware and lets you compile and send `.rb` files from your Mac or Linux machine directly to the device.

Inspired by [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) for MicroPython.


[![Gem Version](https://img.shields.io/gem/v/prremote)](https://rubygems.org/gems/prremote)
[![CI](https://github.com/lumbermill/prremote/actions/workflows/ci.yml/badge.svg)](https://github.com/lumbermill/prremote/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/ruby-3.4%20%7C%204.0-red)](https://github.com/lumbermill/prremote)

---

## Requirements

- Ruby 3.4 or later
- Supported boards:
  - [Raspberry Pi Pico W](https://www.raspberrypi.com/products/raspberry-pi-pico-w/) / [Pico](https://www.raspberrypi.com/products/raspberry-pi-pico/)
  - ESP32 (classic) — e.g. [M5GO / M5Stack Core gen1](https://docs.m5stack.com/en/core/m5go), [M5StickC PLUS](https://docs.m5stack.com/en/core/m5stickc_plus), generic [ESP32](https://www.espressif.com/en/products/socs/esp32) dev boards
  - ESP32-C6 (RISC-V) — e.g. [Seeed Studio XIAO ESP32C6](https://wiki.seeedstudio.com/xiao_esp32c6_getting_started/)
  - Per-board feature status (GPIO / ADC / PWM / I2C / SPI / WiFi / sockets / LCD / IR): [docs/SUPPORT.md](docs/SUPPORT.md)
- `mrbc` (mruby 4.x) for `run`, `deploy`, and `eval`
  - macOS: `brew install mruby`
  - Linux: build from source — [github.com/mruby/mruby/releases](https://github.com/mruby/mruby/releases)
    (`sudo apt install mruby` installs mruby 3.x which is **not compatible**)
  - If `mrbc` is not on your PATH, set the `MRBC` environment variable:
    `MRBC=/path/to/mrbc prremote run app.rb`

---

## Installation

```bash
gem install prremote
```

---

## Quick Start

```bash
# 1. Flash the prremote runtime to your Pico W (one-time setup)
prremote install

# 2. Write your app
echo 'puts "Hello from Pico W!"' > app.rb

# 3. Run it
prremote run app.rb
```

---

## Commands

### `install`

Flash the prremote runtime firmware to a supported board.

```bash
prremote install                          # show supported boards
prremote install -b picow                 # Pico W
prremote install -b pico                  # Pico (no wireless)
prremote install -b esp32                 # ESP32 (M5GO / M5Stack Core, etc.)
prremote install -b m5stickc_plus         # M5StickC PLUS (esp32 runtime + board library)
prremote install -b esp32c6               # ESP32-C6 (e.g. XIAO ESP32C6)
prremote install -b picow --version 0.1.1 # specify a runtime version
```

`-b` / `--board` selects the target board. Running `install` without `--board` prints the list of supported boards.

The firmware is downloaded from GitHub Releases on first use and cached in `~/.prremote/runtime/`. Subsequent installs use the cache.

Pico boards: put the device into BOOTSEL mode (hold BOOTSEL, connect USB, release) when prompted.

ESP32 (classic): no button dance and no extra tools needed — the firmware is written over the serial port by prremote's pure-Ruby implementation of the Espressif bootloader protocol (the chip is reset into its boot ROM automatically, and the write is verified with an on-chip MD5).

ESP32-C6: flashing is delegated to [esptool](https://docs.espressif.com/projects/esptool/en/latest/), because the C6 boot ROM rejects the direct write the classic ESP32 accepts. Install it first (`brew install esptool`, or `pip3 install esptool`). The C6's USB Serial/JTAG port is reset into the boot ROM over USB, so no buttons are needed; only if that fails does prremote fall back to waiting for manual bootloader mode — on the XIAO ESP32C6, hold **BOOT**, press **RST**, then release both.

Reflashing the runtime does not erase a deployed script on either chip.

Board names such as `m5stickc_plus` install the runtime image of their chip (esp32) and record the board name on the device, which the runtime then reports (`prremote version` shows `board=m5stickc_plus`). That name decides which [board libraries](#board-libraries) scripts can use; installing with the plain chip name (`-b esp32`) clears it.

---

### `run FILE [FILE ...]`

Compile one or more local `.rb` files to mruby bytecode and run them on the device immediately (one-shot).

```bash
prremote run app.rb
prremote run blink.rb --port /dev/tty.usbmodem101
```

Multiple files are compiled in order into a single `.mrb`. Classes and methods defined in earlier files are available to later ones — this is the recommended alternative to `require`, which is not available in mruby/c.

```bash
prremote run lib.rb main.rb
```

The device responds with `RUNNING`, streams any output, then `DONE`.

You can find some examples in [examples](examples/).

---

### `deploy FILE [FILE ...]`

Compile one or more local `.rb` files and save them to the device's flash. The script runs automatically on every boot.

```bash
prremote deploy app.rb
prremote deploy lib.rb main.rb
```

The device responds with `DEPLOYED` when the write is complete.

---

### `undeploy`

Erase the deployed script from flash. After this, the device boots into idle mode.

```bash
prremote undeploy
```

---

### `eval EXPR`

Evaluate a Ruby one-liner on the device.

```bash
prremote eval "puts 1 + 1"
prremote eval "GPIO.led.write 1"
```

---

### `reset`

Send `Ctrl+C` to interrupt a running program.

```bash
prremote reset
```

---

### `watch FILE [FILE ...]`

Watch one or more local files for changes and automatically re-run them on the device on every save.

```bash
prremote watch app.rb
prremote watch lib.rb main.rb
```

Useful during development — save any watched file and the device immediately runs the updated code.

---

### `list`

List USB serial devices that may be prremote-compatible.

```bash
prremote list
```

---

### `version`

Show the gem version, mrbc version, and the connected device's runtime version.

```bash
prremote version
# prremote: 0.4.1
# runtime:  0.4.1 board=picow (/dev/tty.usbmodem101)
# mrbc: mruby 4.0.0 (2026-04-20) (/opt/homebrew/bin/mrbc)
```

---

## Global Options

| Option | Description |
|---|---|
| `--port`, `-p PORT` | Serial port (default: auto-detect) |
| `--baud N` | Baud rate (default: `115200`) |

---

## Typical Development Workflow

```bash
# First-time setup
prremote install -b picow     # or: pico / esp32 / esp32c6

# Manual cycle
prremote run app.rb       # compile + run (one-shot)
prremote reset            # interrupt a running program

# Automated cycle (recommended)
prremote watch app.rb     # auto-run on every file save

# Persistent deployment (auto-runs on boot)
prremote deploy app.rb
prremote undeploy         # remove from flash
```

---

## Board libraries

Some boards come with a Ruby library for their built-in hardware. You don't load it yourself: when a script mentions one of its classes, `run` / `deploy` / `watch` / `eval` compile the library in ahead of your files (it prints `Adding board library: ...`). Scripts that don't mention it pay nothing on the device.

| Board (`install -b`) | Classes | Covers |
|---|---|---|
| `m5stickc_plus` | `M5StickCPlus`, `BM8563` | AXP192 power-on, LCD preset per rotation, buttons A/B, red LED, buzzer, IR LED, BM8563 RTC (as `Time`) |

```ruby
stick = M5StickCPlus.new            # powers the LCD
lcd = stick.lcd(rotation: 1)        # pins / size / RAM offset / color order preset
lcd.text(4, 4, stick.rtc.time.to_s, scale: 1)
stick.led.on if stick.button_a.pressed?
```

A board library is refused if the device reports a different board (e.g. `M5StickCPlus` on an esp32c6). Chip drivers such as `BM8563` work on any board. The library sources live in [lib/prremote/boards/](lib/prremote/boards/) and double as the reference for driving the hardware directly.

---

## How It Works

prremote flashes a minimal C firmware (built on mruby/c) onto the board. The firmware:

1. Waits for a USB serial connection and sends `READY prremote-runtime/VERSION`
2. Receives a command from the host:
   - Raw `.mrb` bytecode → execute immediately and stream output (`run` / `eval` / `watch`)
   - `DPLY` + `.mrb` bytecode → save to flash and confirm with `DEPLOYED` (`deploy`)
3. Waits for the next command

Scripts saved via `deploy` are stored in flash and run automatically on every boot. GPIO / ADC / PWM / I2C / SPI bindings are available on all boards; `WiFi`, `Time` (NTP) and `TCPSocket` on boards with a radio (Pico W, ESP32, ESP32-C6), plus `UDPSocket` on ESP32 / ESP32-C6; an `LCD` class (ILI9342C / ILI9341 / ST7789) on ESP32 / ESP32-C6; and an `IR` transmitter class on classic ESP32 (e.g. the M5StickC PLUS IR LED). See [docs/SUPPORT.md](docs/SUPPORT.md) for the full board × feature matrix and [examples/](examples/) for copy-paste samples per board.

---

## Development

### Clone

This repository uses Git submodules (mruby/c, picoruby, pico-sdk, etc.).
Clone with:

```bash
git clone --recurse-submodules https://github.com/lumbermill/prremote.git
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

### Build the runtime firmware

Pico boards require the ARM cross-compiler (`arm-none-eabi-gcc`) and CMake.

```bash
cd runtime/
rake build   # UF2 for pico and picow
```

The ESP32 runtime requires ESP-IDF v5.3, which is not vendored (it is several
GB and installs its own toolchains). One-time setup:

```bash
mkdir -p ~/sources/esp
git clone -b v5.3.2 --recursive --shallow-submodules \
    https://github.com/espressif/esp-idf.git ~/sources/esp/esp-idf
cd ~/sources/esp/esp-idf && ./install.sh esp32
```

Then (set `IDF_PATH` if you installed somewhere else):

```bash
cd runtime/
rake build:esp32   # merged .bin for esp32
rake cache         # build all boards → ~/.prremote/runtime/
```

### Run the tests

```bash
bundle exec rake test
```

---

## License

[MIT License](LICENSE)

---

## Related Projects

- [mruby/c](https://github.com/mrubyc/mrubyc) — Lightweight mruby implementation used in the runtime
- [picotool](https://github.com/raspberrypi/picotool) — Official Raspberry Pi tool for inspecting and managing Pico devices; useful for checking what's on flash or force-rebooting outside of prremote
- [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) — MicroPython equivalent (inspiration)