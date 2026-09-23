# prremote

> ⚠️ This project is in early development. APIs and commands are subject to change.

**prremote** is a command-line tool for deploying and running Ruby scripts on a Raspberry Pi Pico W or ESP32 (e.g. M5Stack) over USB serial. It ships a minimal [mruby/c](https://github.com/mrubyc/mrubyc) runtime firmware and lets you compile and send `.rb` files from your Mac, Linux or Windows machine directly to the device.

Inspired by [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) for MicroPython.


[![Gem Version](https://img.shields.io/gem/v/prremote)](https://rubygems.org/gems/prremote)
[![CI](https://github.com/lumbermill/prremote/actions/workflows/ci.yml/badge.svg)](https://github.com/lumbermill/prremote/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/ruby-3.4%20%7C%204.0-red)](https://github.com/lumbermill/prremote)

---

## Requirements

- Ruby 3.4 or later
- Supported hosts: macOS, Linux, Windows, and WSL2 — see [Windows and WSL](#windows-and-wsl) for the extra setup each of the last two needs
- Supported boards:
  - [Raspberry Pi Pico W](https://www.raspberrypi.com/products/raspberry-pi-pico-w/) / [Pico](https://www.raspberrypi.com/products/raspberry-pi-pico/)
  - ESP32 (classic) — e.g. [M5GO / M5Stack Core gen1](https://docs.m5stack.com/en/core/m5go), generic [ESP32](https://www.espressif.com/en/products/socs/esp32) dev boards
  - ESP32-C6 (RISC-V) — e.g. [Seeed Studio XIAO ESP32C6](https://wiki.seeedstudio.com/xiao_esp32c6_getting_started/)
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
prremote install -b esp32c6               # ESP32-C6 (e.g. XIAO ESP32C6)
prremote install -b picow --version 0.1.1 # specify a runtime version
```

`-b` / `--board` selects the target board. Running `install` without `--board` prints the list of supported boards.

The firmware is downloaded from GitHub Releases on first use and cached in `~/.prremote/runtime/`. Subsequent installs use the cache.

Pico boards: put the device into BOOTSEL mode (hold BOOTSEL, connect USB, release) when prompted.

ESP32 (classic): no button dance and no extra tools needed — the firmware is written over the serial port by prremote's pure-Ruby implementation of the Espressif bootloader protocol (the chip is reset into its boot ROM automatically, and the write is verified with an on-chip MD5).

ESP32-C6: flashing is delegated to [esptool](https://docs.espressif.com/projects/esptool/en/latest/), because the C6 boot ROM rejects the direct write the classic ESP32 accepts. Install it first (`brew install esptool`, or `pip3 install esptool`), and put the board into bootloader mode when prompted — on the XIAO ESP32C6, hold **BOOT**, press **RST**, then release both.

Reflashing the runtime does not erase a deployed script on either chip.

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
# prremote: 0.3.2
# runtime:  0.3.2 (/dev/tty.usbmodem101)
# mrbc: mruby 4.0.0 (2026-04-20) (/opt/homebrew/bin/mrbc)
```

---

## Windows and WSL

prremote runs on both, but each needs a little setup that macOS and Linux do not.

### Windows

Ruby 3.4 or later is required; [RubyInstaller](https://rubyinstaller.org/) is the usual way to get it. Boards appear as `COM3`, `COM4` and so on rather than as `/dev/tty*`, and are matched by USB vendor id the same way they are elsewhere, so auto-detection picks the board over any virtual COM ports the machine happens to have:

```powershell
prremote list
# COM5  (unknown)
# COM7  (Pico (prremote/R2P2))

prremote run app.rb              # picks COM7
prremote run app.rb --port COM7  # or name it
```

For Pico boards, `install` copies the UF2 to whichever drive letter the BOOTSEL volume lands on — there is nothing to mount or configure.

Flashing an ESP32 board from Windows is not supported yet: the bootloader reset in `EspFlasher` drives DTR/RTS through POSIX ioctls. Use `install` from macOS, Linux or WSL for those.

### WSL

Two things are not automatic inside WSL.

**USB serial devices are not forwarded.** WSL2 does not pass USB through to the guest, so a board Windows sees perfectly well has no `/dev/ttyACM*` on the Linux side. Install [usbipd-win](https://github.com/dorssel/usbipd-win) on the Windows side and attach the board:

```powershell
winget install --exact dorssel.usbipd-win
usbipd list                              # note the BUSID of your board
usbipd bind --busid <BUSID>              # once, as Administrator
usbipd attach --wsl --busid <BUSID>      # after every reconnect
```

Then, in WSL:

```bash
prremote list        # /dev/ttyACM0 should now show up
```

If the port is there but cannot be opened, add yourself to the `dialout` group (`sudo usermod -aG dialout $USER`) and restart WSL with `wsl --shutdown`.

**Removable drives are not mounted.** For Pico boards, the BOOTSEL volume arrives as a Windows drive letter, which WSL does not mount on its own. Mount it before running `install`:

```bash
sudo mkdir -p /mnt/d
sudo mount -t drvfs D: /mnt/d    # use the drive letter RPI-RP2 was assigned
prremote install -b picow
```

`install` scans `/mnt/d` through `/mnt/z` for the BOOTSEL volume, so the mount point only has to match the drive letter.

ESP32 boards need neither step in WSL beyond the usbipd attach, since they are flashed over the serial port.

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

## How It Works

prremote flashes a minimal C firmware (built on mruby/c) onto the Pico W. The firmware:

1. Waits for a USB serial connection and sends `READY prremote-runtime/VERSION`
2. Receives a command from the host:
   - Raw `.mrb` bytecode → execute immediately and stream output (`run` / `eval` / `watch`)
   - `DPLY` + `.mrb` bytecode → save to flash and confirm with `DEPLOYED` (`deploy`)
3. Waits for the next command

Scripts saved via `deploy` are stored in flash and run automatically on every boot. GPIO / ADC / PWM / I2C / SPI bindings are available on all boards; a `WiFi` module on boards with a radio (Pico W and ESP32); an `LCD` class (ILI9342C) on ESP32 / M5Stack.

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