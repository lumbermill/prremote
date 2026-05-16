# prremote

> ⚠️ This project is in early development. APIs and commands are subject to change.

**prremote** is a command-line tool for deploying and running Ruby scripts on a Raspberry Pi Pico W over USB serial. It ships a minimal [mruby/c](https://github.com/mrubyc/mrubyc) runtime firmware and lets you compile and send `.rb` files from your Mac or Linux machine directly to the device.

Inspired by [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) for MicroPython.

---

## Requirements

- Ruby 3.x or later
- Raspberry Pi Pico W
- `mrbc` in your PATH (for `deploy` and `eval`) — install via `brew install mruby` on macOS

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

# 3. Deploy and run
prremote deploy app.rb
```

---

## Commands

### `install`

Flash the prremote runtime firmware to a Pico W.

```bash
prremote install
prremote install --version 0.1.1   # specify a runtime version
```

The firmware is downloaded from GitHub Releases on first use and cached in `~/.prremote/runtime/`. Subsequent installs use the cache.

Put the Pico W into BOOTSEL mode (hold BOOTSEL, connect USB, release) when prompted.

---

### `deploy FILE`

Compile a local `.rb` file to mruby bytecode and send it to the device for immediate execution.

```bash
prremote deploy app.rb
prremote deploy blink.rb --port /dev/tty.usbmodem101
```

The device responds with `RUNNING`, streams any output, then `DONE`. If the program loops forever, use `prremote reset` to stop it.

---

### `eval EXPR`

Evaluate a Ruby one-liner on the device.

```bash
prremote eval "puts 1 + 1"
prremote eval "CYW43.init; CYW43::GPIO.new(CYW43::GPIO::LED_PIN).write 1"
```

---

### `reset`

Interrupt a running program and reboot the device.

```bash
prremote reset
```

Sends `Ctrl+C` (`0x03`) over the serial connection. The runtime's watchdog fires within 1 ms and the device restarts, ready for the next `deploy`.

---

### `watch FILE`

Watch a local file for changes and automatically run `deploy` + `reset` on every save.

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

Show the gem version and, if a device is connected and idle, its runtime version.

```bash
prremote version
# prremote 0.1.0
# Device runtime: 0.1.1
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
prremote deploy app.rb    # compile + send + run
prremote reset            # stop running program

# Automated cycle (recommended)
prremote watch app.rb     # auto-deploy on every file save
```

---

## How It Works

prremote flashes a minimal C firmware (built on mruby/c) onto the Pico W. The firmware:

1. Waits for a USB serial connection and sends `READY prremote-runtime/VERSION`
2. Receives compiled mruby bytecode (`.mrb`) from the host
3. Executes it with the mruby/c VM and streams output back
4. Waits for the next deploy

There is no persistent file storage — every `deploy` starts a fresh execution. GPIO and WiFi (CYW43) C bindings are available in Ruby code running on the device.

---

## License

[MIT License](LICENSE)

---

## Related Projects

- [mruby/c](https://github.com/mrubyc/mrubyc) — Lightweight mruby implementation used in the runtime
- [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) — MicroPython equivalent (inspiration)
