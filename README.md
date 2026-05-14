# prremote

**prremote** is a command-line tool for remotely interacting with Raspberry Pi Pico devices over USB serial — inspired by [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) for MicroPython.

prremote ships its own minimal firmware (**prremote-agent**) and a lightweight custom serial protocol, so it works without any existing shell environment on the device.

> ⚠️ This project is in early development. APIs and commands are subject to change.

---

## Architecture

```
prremote (Ruby gem)          ← host side (this repository)
  ↕ custom text protocol
prremote-agent firmware      ← device side (distributed by this project)
  mruby/c VM on RP2040
```

The custom protocol is intentionally simple — no shell prompts, no ANSI escapes, no echo parsing. Just plain request/response lines over serial.

---

## Requirements

- Ruby 3.0+
- Raspberry Pi Pico or Pico W (RP2040)
- prremote-agent firmware (installed via `prremote install`)

---

## Installation

```bash
gem install prremote
```

Or add to your Gemfile:

```ruby
gem 'prremote'
```

---

## Quick Start

### 1. Flash the firmware

Put your Pico into BOOTSEL mode, then:

```bash
prremote install             # Pico
prremote install --board pico_w  # Pico W
```

### 2. Check the connection

```bash
prremote list
```

### 3. Transfer and run a file

```bash
prremote put app.rb && prremote reset
```

### 4. Watch mode (auto-upload on save)

```bash
prremote watch app.rb
```

---

## Command Reference

### Firmware

| Command | Description |
|---|---|
| `install` | Download and flash prremote-agent firmware to Pico |
| `version` | Show prremote and device firmware version |

```bash
prremote install                   # latest, auto-detect board
prremote install --board pico_w    # specify board
prremote install --list            # list available firmware versions
```

### File Operations

| Command | Description |
|---|---|
| `put LOCAL [REMOTE]` | Upload file to device |
| `get REMOTE [LOCAL]` | Download file from device |
| `cp SRC DEST` | Copy a file on the device |
| `rm PATH` | Remove a file on device |
| `mkdir PATH` | Create directory on device |
| `ls [PATH]` | List files on device (default: `/home`) |

```bash
prremote put app.rb                      # → /home/app.rb
prremote put app.rb /home/app.rb
prremote get /home/app.rb ./backup.rb
prremote cp /home/a.rb /home/b.rb
prremote rm /home/old.rb
prremote mkdir /home/lib
prremote ls
prremote ls /home
```

### Development

| Command | Description |
|---|---|
| `watch LOCAL [REMOTE]` | Watch file for changes and auto-upload + reset |
| `eval EXPR` | Evaluate a Ruby expression on device |
| `reset` | Reboot the device |

```bash
prremote watch app.rb                              # watches app.rb → /home/app.rb
prremote watch app.rb /home/app.rb
prremote eval "GPIO.new(25, GPIO::OUT).write(1)"
prremote reset
```

### Device Discovery

```bash
prremote list                    # list connected prremote-compatible devices
prremote --port /dev/ttyACM0 ls  # specify port explicitly
```

### Global Options

| Option | Description |
|---|---|
| `--port`, `-p` | Serial port (default: auto-detect) |
| `--baud`, `-b` | Baud rate (default: `115200`) |

---

## Protocol Overview

prremote uses a plain text protocol over serial. Each command is a single line; responses are one or more lines terminated by `OK`, `ERROR <msg>`, or `END`.

| Direction | Example |
|---|---|
| Host → Device | `PUT /home/app.rb 1024` |
| Device → Host | `READY` |
| Host → Device | `<1024 bytes of binary data>` |
| Device → Host | `OK` |

| Command | Response |
|---|---|
| `PUT /path SIZE` | `READY` → binary → `OK\|ERROR` |
| `GET /path` | `SIZE n` → binary |
| `LS [/path]` | entries… → `END` |
| `RM /path` | `OK\|ERROR` |
| `MKDIR /path` | `OK\|ERROR` |
| `CP src dst` | `OK\|ERROR` |
| `EVAL expr` | `OK result\|ERROR msg` |
| `RESET` | *(no response, device reboots)* |
| `VERSION` | version string |

---

## Typical Workflow

### Initial setup

```bash
prremote install
prremote list          # confirm device is recognised
```

### Manual development cycle

```bash
prremote put app.rb && prremote reset
# /home/app.rb is executed automatically on boot
```

### Automatic development cycle

```bash
prremote watch app.rb
# saves trigger an automatic put + reset
```

### Debugging

```bash
prremote eval "GPIO.new(25, GPIO::OUT).write(1)"
prremote ls
prremote get /home/app.rb ./app_backup.rb
```

---

## Comparison with mpremote

| Feature | prremote (PicoRuby) | mpremote (MicroPython) |
|---|---|---|
| Target runtime | PicoRuby (mruby/c) | MicroPython |
| Language | Ruby | Python |
| Firmware bundled | ✅ (`prremote install`) | — |
| File transfer | ✅ | ✅ |
| Watch mode | ✅ | ✅ |
| Eval expression | ✅ | ✅ |
| Interactive REPL | — | ✅ |
| Package install | 🚧 Planned | ✅ (`mip`) |

---

## Building the Firmware

### Clone with submodules

`firmware/picoruby` is managed as a git submodule (which itself has nested submodules). Always clone with:

```bash
git clone --recurse-submodules https://github.com/your-org/prremote
```

If you already cloned without `--recurse-submodules`, run:

```bash
git submodule update --init --recursive
```

### Dependencies (macOS)

```bash
brew install --cask gcc-arm-embedded   # ARM cross-compiler (includes newlib)
brew install cmake ninja openssl
```

### Build

```bash
cd firmware
LDFLAGS="-L$(brew --prefix openssl)/lib" \
CPPFLAGS="-I$(brew --prefix openssl)/include" \
rake prremote:pico:prod       # Pico
rake prremote:pico_w:prod     # Pico W
```

The resulting `.uf2` file is written to `firmware/build/<board>/prod/`.

---

## Contributing

Bug reports and pull requests are welcome on GitHub.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push to the branch and open a Pull Request

---

## License

[MIT License](LICENSE)

---

## Related Projects

- [PicoRuby](https://github.com/picoruby/picoruby) — Ruby implementation for microcontrollers
- [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) — MicroPython remote control tool (inspiration)
