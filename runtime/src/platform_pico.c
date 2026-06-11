/* Pico / Pico W implementation of the prremote platform interface.
 * Console is USB CDC stdio; script storage is the last 64 KB of the on-board
 * flash, read back directly through XIP. */

#include "pico/stdlib.h"
#include "pico/stdio.h"
#include "pico/stdio_usb.h"
#include "tusb.h"
#include "hardware/watchdog.h"
#include "hardware/timer.h"
#include "hardware/flash.h"
#include "hardware/sync.h"
#include <stdio.h>
#include <string.h>

#include "prr_platform.h"

#ifndef PICO_FLASH_SIZE_BYTES
#define PICO_FLASH_SIZE_BYTES (2 * 1024 * 1024)
#endif
#define FLASH_STORAGE_SIZE   (64 * 1024)
#define FLASH_STORAGE_OFFSET (PICO_FLASH_SIZE_BYTES - FLASH_STORAGE_SIZE)
#define FLASH_STORAGE_ADDR   (XIP_BASE + FLASH_STORAGE_OFFSET)
#define FLASH_MAGIC          "PRRD"

/* PRR_STORAGE_HEADER_SIZE must equal one flash page: the header is written
 * as a single page and the payload starts on the next page boundary. */
_Static_assert(PRR_STORAGE_HEADER_SIZE == FLASH_PAGE_SIZE,
               "storage header must be one flash page");

/* ── console ─────────────────────────────────────────────────────────────── */

void prr_console_init(void) { stdio_init_all(); }
bool prr_host_connected(void) { return stdio_usb_connected(); }
int  prr_getchar(void) { return getchar(); }
void prr_flush(void) { stdio_flush(); }
void prr_sleep_ms(uint32_t ms) { sleep_ms(ms); }

/* ── persistent script storage ───────────────────────────────────────────── */

bool prr_storage_has_script(void)
{
  return memcmp((const void *)FLASH_STORAGE_ADDR, FLASH_MAGIC, 4) == 0;
}

uint32_t prr_storage_script_size(void)
{
  const uint8_t *h = (const uint8_t *)FLASH_STORAGE_ADDR + 4;
  return ((uint32_t)h[0] << 24) | ((uint32_t)h[1] << 16)
       | ((uint32_t)h[2] <<  8) |  (uint32_t)h[3];
}

bool prr_storage_read_header(uint8_t out[PRR_STORAGE_HEADER_SIZE])
{
  if (!prr_storage_has_script()) return false;
  memcpy(out, (const void *)FLASH_STORAGE_ADDR, PRR_STORAGE_HEADER_SIZE);
  return true;
}

bool prr_storage_load(uint8_t *buf, uint32_t size)
{
  memcpy(buf, (const void *)(FLASH_STORAGE_ADDR + PRR_STORAGE_HEADER_SIZE),
         size);
  return true;
}

/* Must run from RAM: erases and programs flash while XIP is suspended. */
static void __not_in_flash_func(flash_save)(
    const uint8_t *data, uint32_t size,
    uint32_t ts, const uint8_t *names, uint8_t name_len)
{
  uint32_t ints = save_and_disable_interrupts();

  flash_range_erase(FLASH_STORAGE_OFFSET, FLASH_STORAGE_SIZE);

  uint8_t page[FLASH_PAGE_SIZE] = {0};
  memcpy(page, FLASH_MAGIC, 4);
  page[4] = (size >> 24) & 0xFF;
  page[5] = (size >> 16) & 0xFF;
  page[6] = (size >>  8) & 0xFF;
  page[7] =  size        & 0xFF;
  page[8]  = (ts >> 24) & 0xFF;
  page[9]  = (ts >> 16) & 0xFF;
  page[10] = (ts >>  8) & 0xFF;
  page[11] =  ts        & 0xFF;
  if (name_len > 0) memcpy(page + 12, names, name_len);
  flash_range_program(FLASH_STORAGE_OFFSET, page, FLASH_PAGE_SIZE);

  /* Remaining pages: .mrb data. */
  uint32_t written = 0;
  while (written < size) {
    memset(page, 0xFF, FLASH_PAGE_SIZE);
    uint32_t chunk = size - written;
    if (chunk > FLASH_PAGE_SIZE) chunk = FLASH_PAGE_SIZE;
    memcpy(page, data + written, chunk);
    flash_range_program(FLASH_STORAGE_OFFSET + FLASH_PAGE_SIZE + written,
                        page, FLASH_PAGE_SIZE);
    written += chunk;
  }

  restore_interrupts(ints);
}

void prr_storage_save(const uint8_t *data, uint32_t size,
                      uint32_t ts, const uint8_t *names, uint8_t name_len)
{
  flash_save(data, size, ts, names, name_len);
}

void prr_storage_erase(void)
{
  uint32_t ints = save_and_disable_interrupts();
  flash_range_erase(FLASH_STORAGE_OFFSET, FLASH_STORAGE_SIZE);
  restore_interrupts(ints);
}

/* ── reset handling ──────────────────────────────────────────────────────── */

bool prr_was_soft_reset(void) { return watchdog_caused_reboot(); }

static bool check_reset_cb(repeating_timer_t *t)
{
  int c = getchar_timeout_us(0);
  if (c == 0x03) {
    /* Disconnect USB cleanly before resetting — equivalent to unplugging the
     * cable — so the host's USB stack is not left in a confused state. */
    tud_disconnect();
    busy_wait_ms(500);
    watchdog_enable(1, 1);
    while (1) tight_loop_contents();
  }
  return true;
}

static repeating_timer_t s_reset_timer;

void prr_reset_monitor_start(void)
{
  add_repeating_timer_ms(100, check_reset_cb, NULL, &s_reset_timer);
}

void prr_reset_monitor_stop(void)
{
  cancel_repeating_timer(&s_reset_timer);
}

/* ── entry point ─────────────────────────────────────────────────────────── */

int main(void)
{
  prr_console_init();
  return prr_main();
}
