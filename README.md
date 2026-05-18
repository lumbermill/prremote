# prremote

> ⚠️ This project is in early development. APIs and commands are subject to change.

**prremote** is a command-line tool for deploying and running Ruby scripts on a Raspberry Pi Pico W over USB serial. It ships a minimal [mruby/c](https://github.com/mrubyc/mrubyc) runtime firmware and lets you compile and send `.rb` files from your Mac or Linux machine directly to the device.

Inspired by [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) for MicroPython.

---

## Requirements

- Ruby 3.x or later
- Raspberry Pi Pico W
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

Flash the prremote runtime firmware to a Pico W or Pico.

```bash
prremote install                          # Pico W (default)
prremote install --board pico             # Pico (no wireless)
prremote install --version 0.1.1          # specify a runtime version
prremote install --board pico --version 0.1.1
```

The firmware is downloaded from GitHub Releases on first use and cached in `~/.prremote/runtime/`. Subsequent installs use the cache.

Put the device into BOOTSEL mode (hold BOOTSEL, connect USB, release) when prompted.

---

### `run FILE`

Compile a local `.rb` file to mruby bytecode and run it on the device immediately (one-shot).

```bash
prremote run app.rb
prremote run blink.rb --port /dev/tty.usbmodem101
```

The device responds with `RUNNING`, streams any output, then `DONE`.

You can find some examples in [test/samples](test/samples/).

---

### `deploy FILE`

Compile a local `.rb` file and save it to the device's flash. The script runs automatically on every boot.

```bash
prremote deploy app.rb
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
prremote eval "CYW43.init; CYW43::GPIO.new(CYW43::GPIO::LED_PIN).write 1"
```

---

### `reset`

Send `Ctrl+C` to interrupt a running program.

```bash
prremote reset
```

---

### `watch FILE`

Watch a local file for changes and automatically re-run it on the device on every save.

```bash
prremote watch app.rb
```

Useful during development — save your file and the device immediately runs the updated code.

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
# prremote: 0.1.1
# mrbc:     3.3.0 (/usr/local/bin/mrbc)
# runtime:  0.1.3
```

---

## Global Options

| Option | Description |
|---|---|
| `--port`, `-p PORT` | Serial port (default: auto-detect) |
| `--baud`, `-b N` | Baud rate (default: `115200`) |

---

## Typical Development Workflow

```bash
# First-time setup
prremote install

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

Scripts saved via `deploy` are stored in flash and run automatically on every boot. GPIO and WiFi (CYW43) C bindings are available in Ruby code running on the device.

---

## License

[MIT License](LICENSE)

---

## Related Projects

- [mruby/c](https://github.com/mrubyc/mrubyc) — Lightweight mruby implementation used in the runtime
- [picotool](https://github.com/raspberrypi/picotool) — Official Raspberry Pi tool for inspecting and managing Pico devices; useful for checking what's on flash or force-rebooting outside of prremote
- [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) — MicroPython equivalent (inspiration)
