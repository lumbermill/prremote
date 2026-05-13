# prremote

**prremote** is a command-line tool for remotely interacting with [PicoRuby](https://github.com/picoruby/picoruby) / [R2P2](https://github.com/picoruby/R2P2) devices over a serial connection — inspired by [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) for MicroPython.

> ⚠️ This project is in early development. APIs and commands are subject to change.

---

## Features

- 🔌 Auto-detect and connect to R2P2 devices over USB serial
- 💎 REPL access to the PicoRuby shell
- 📁 File transfer (upload / download) to/from the device
- ▶️ Run local `.rb` scripts on the device
- 🧪 Evaluate Ruby expressions remotely
- 📂 Mount local directory on the device _(planned)_

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

## Requirements

- Ruby 3.x
- A Raspberry Pi Pico / Pico W running [R2P2 / PicoRuby](https://picoruby.org/setup)

---

## Usage

### Connect and open REPL

```bash
prremote repl
```

### List files on device

```bash
prremote ls
prremote ls /home
```

### Upload a file to device

```bash
prremote put script.rb
prremote put script.rb /home/script.rb
```

### Download a file from device

```bash
prremote get /home/script.rb
prremote get /home/script.rb ./local_copy.rb
```

### Run a local Ruby script on device

```bash
prremote run script.rb
```

### Evaluate a Ruby expression on device

```bash
prremote eval "puts 1 + 1"
```

### Specify a serial port explicitly

```bash
prremote --port /dev/ttyACM0 repl
prremote --port COM3 ls
```

---

## Command Reference

| Command | Description |
|---|---|
| `repl` | Open interactive REPL on device |
| `ls [path]` | List files on device |
| `put <local> [remote]` | Upload file to device |
| `get <remote> [local]` | Download file from device |
| `run <file.rb>` | Run local script on device |
| `eval <expr>` | Evaluate Ruby expression on device |
| `rm <path>` | Remove file on device |
| `mkdir <path>` | Create directory on device |
| `version` | Show prremote and device firmware version |

### Global Options

| Option | Description |
|---|---|
| `--port`, `-p` | Serial port to connect to (default: auto-detect) |
| `--baud`, `-b` | Baud rate (default: `115200`) |
| `--help`, `-h` | Show help |
| `--version` | Show prremote version |

---

## Auto-detection

By default, prremote scans available USB serial ports and connects to the first R2P2 device found. If multiple devices are connected, use `--port` to specify which one to use.

```bash
prremote list          # Show available devices
prremote --port /dev/ttyACM1 repl
```

---

## Comparison with mpremote

| Feature | prremote (PicoRuby) | mpremote (MicroPython) |
|---|---|---|
| Target runtime | PicoRuby / R2P2 | MicroPython |
| Language | Ruby | Python |
| REPL access | ✅ | ✅ |
| File transfer | ✅ | ✅ |
| Run local script | ✅ | ✅ |
| Directory mount | 🚧 Planned | ✅ |
| Package install | 🚧 Planned | ✅ (`mip`) |

---

## Contributing

Bug reports and pull requests are welcome on GitHub.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

---

## License

[MIT License](LICENSE)

---

## Related Projects

- [PicoRuby](https://github.com/picoruby/picoruby) — Ruby implementation for microcontrollers
- [R2P2](https://github.com/picoruby/R2P2) — PicoRuby shell for Raspberry Pi Pico
- [mpremote](https://docs.micropython.org/en/latest/reference/mpremote.html) — MicroPython remote control tool (inspiration)
- [mpr](https://github.com/bulletmark/mpr) — mpremote wrapper with conventional CLI interface
