# runtime

Build directory for the "reflash-once" runtime firmware for Raspberry Pi Pico W.

Running `rake runtime` produces `build/runtime.uf2`. Flash this UF2 to the Pico W once, and it will loop waiting to receive `.mrb` bytecode over USB serial and execute it. The `prremote` command uses this mechanism to send scripts to the device.

## Source

Extracted from the `mrubyc-pico-w` repository (commit `f0b1018`), keeping only what is needed for the `runtime` target. Sample targets (led / wifi / gpio) are excluded.

- mrubyc submodule: `aa226b51de4c95be5296a71be3d74cac2eb61471` (tag: `release3.4.1-57-gaa226b5`)
- `src/lwipopts.h`: LwIP configuration required by `pico_cyw43_arch_lwip_threadsafe_background` (copied from `src/samples/lwipopts.h` in mrubyc-pico-w)

## Prerequisites

| Requirement | Details |
|-------------|---------|
| `PICO_SDK_PATH` | Environment variable pointing to the Raspberry Pi Pico SDK |
| mruby-4.0.0 | `rbenv install mruby-4.0.0` — used by the autogen / mrblib build steps |
| cmake | Version 3.12 or later |
| make | GNU make |
| arm-none-eabi-gcc | ARM cross-compiler available on `PATH` |
| git submodule | Run `git submodule update --init runtime/mrubyc` after a fresh clone |

## Build

```bash
cd runtime/
PICO_SDK_PATH=/path/to/pico-sdk rake runtime
# → build/prremote-picow-runtime-0.1.0.uf2
```

## Version

The version is defined in one place — `RUNTIME_VERSION` in `CMakeLists.txt` (mirrored in `Rakefile`). Bumping it changes both the UF2 filename and the string the firmware broadcasts.

Once flashed, the device announces its version on every ready cycle:
```
READY prremote-runtime/0.1.0
```
`prremote` can read this line on connect to detect the installed runtime version.

## Flashing

1. Hold the BOOTSEL button on the Pico W while connecting it via USB.
2. It will appear as a `RPI-RP2` drive — copy `build/runtime.uf2` to it.
3. The device reboots automatically and starts sending `READY` over USB serial.
