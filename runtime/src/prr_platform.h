/* Platform abstraction for the prremote runtime.
 *
 * runtime.c implements the serial protocol (READY / RITE / DPLY / ERSE / QURY)
 * on top of this interface. Each target provides an implementation:
 *   - platform_pico.c  (pico-sdk: USB CDC stdio, XIP flash, watchdog reset)
 *   - esp32/main/platform_esp32.c (ESP-IDF: UART0 console, esp_partition)
 */

#ifndef PRR_PLATFORM_H_
#define PRR_PLATFORM_H_

#include <stdbool.h>
#include <stdint.h>

#define PRR_NO_CHAR (-1)

/* The storage header occupies this many bytes; the .mrb payload follows.
 * Header layout:
 *   [0-3]    : "PRRD" magic
 *   [4-7]    : .mrb size (big-endian uint32)
 *   [8-11]   : Unix timestamp (big-endian uint32)
 *   [12-251] : null-terminated deployed filenames string (max 240 bytes)
 *   [252-255]: unused */
#define PRR_STORAGE_HEADER_SIZE 256

/* ── console ─────────────────────────────────────────────────────────────── */
void prr_console_init(void);
/* pico: USB CDC connected; esp32: always true (UART bridge, not detectable) */
bool prr_host_connected(void);
/* Blocking read of one byte. */
int  prr_getchar(void);
void prr_flush(void);

/* ── persistent script storage ───────────────────────────────────────────── */
bool     prr_storage_has_script(void);
uint32_t prr_storage_script_size(void);
/* Copies the raw header into out; returns false if no script is stored. */
bool     prr_storage_read_header(uint8_t out[PRR_STORAGE_HEADER_SIZE]);
/* Copies `size` bytes of .mrb payload (which starts right after the header)
 * into buf; returns false on read failure. */
bool     prr_storage_load(uint8_t *buf, uint32_t size);
void     prr_storage_save(const uint8_t *data, uint32_t size,
                          uint32_t ts, const uint8_t *names, uint8_t name_len);
void     prr_storage_erase(void);

/* ── reset handling ──────────────────────────────────────────────────────── */
/* True when the board rebooted because of a Ctrl+C-triggered reset; the
 * deployed script must not auto-run in that case. */
bool prr_was_soft_reset(void);
/* Watches the console for 0x03 (~100 ms period) while a script is running
 * and reboots the board when it arrives. */
void prr_reset_monitor_start(void);
void prr_reset_monitor_stop(void);

void prr_sleep_ms(uint32_t ms);

/* Protocol entry point implemented by runtime.c; called from platform main
 * after prr_console_init(). */
int prr_main(void);

#endif /* PRR_PLATFORM_H_ */
