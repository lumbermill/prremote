#include "pico/stdlib.h"
#include "pico/stdio.h"
#include "hardware/watchdog.h"
#include "hardware/flash.h"
#include "hardware/sync.h"
#include <mrubyc.h>
#include <stdio.h>
#include <string.h>

#include "hw_wrap.h"
#ifdef HAS_CYW43
#include "cyw43_wrap.h"
#include "socket_wrap.h"
#endif

#define MRB_BUFFER_SIZE (32 * 1024)
#define HEAP_SIZE       (96 * 1024)

/* Last 64 KB of the 2 MB flash reserved for user script storage.
 * Stored format: 4-byte magic "PRRD" + 4-byte big-endian size + .mrb data.
 * The header occupies one full flash page (256 bytes); data follows. */
#ifndef PICO_FLASH_SIZE_BYTES
#define PICO_FLASH_SIZE_BYTES (2 * 1024 * 1024)
#endif
#define FLASH_STORAGE_SIZE   (64 * 1024)
#define FLASH_STORAGE_OFFSET (PICO_FLASH_SIZE_BYTES - FLASH_STORAGE_SIZE)
#define FLASH_STORAGE_ADDR   (XIP_BASE + FLASH_STORAGE_OFFSET)
#define FLASH_MAGIC          "PRRD"

static uint8_t mrb_buffer[MRB_BUFFER_SIZE];
static uint8_t memory_pool[HEAP_SIZE];

void runtime_define_methods(void);

/* ── flash helpers ───────────────────────────────────────────────────────── */

static bool flash_has_script(void)
{
  return memcmp((const void *)FLASH_STORAGE_ADDR, FLASH_MAGIC, 4) == 0;
}

static uint32_t flash_script_size(void)
{
  const uint8_t *h = (const uint8_t *)FLASH_STORAGE_ADDR + 4;
  return ((uint32_t)h[0] << 24) | ((uint32_t)h[1] << 16)
       | ((uint32_t)h[2] <<  8) |  (uint32_t)h[3];
}

/* Must run from RAM: erases and programs flash while XIP is suspended. */
static void __not_in_flash_func(save_to_flash)(const uint8_t *data, uint32_t size)
{
  uint32_t ints = save_and_disable_interrupts();

  flash_range_erase(FLASH_STORAGE_OFFSET, FLASH_STORAGE_SIZE);

  /* First page: magic + big-endian size, rest zeroed. */
  uint8_t page[FLASH_PAGE_SIZE] = {0};
  memcpy(page, FLASH_MAGIC, 4);
  page[4] = (size >> 24) & 0xFF;
  page[5] = (size >> 16) & 0xFF;
  page[6] = (size >>  8) & 0xFF;
  page[7] =  size        & 0xFF;
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

/* ── reset / recv helpers ────────────────────────────────────────────────── */

static bool check_reset_cb(repeating_timer_t *t)
{
  int c = getchar_timeout_us(0);
  if (c == 0x03) {
    watchdog_enable(1, 1);
    while (1) tight_loop_contents();
  }
  return true;
}

static void recv_exact(uint8_t *buf, uint32_t n)
{
  for (uint32_t i = 0; i < n; i++) buf[i] = (uint8_t)getchar();
}

/* Receives a full .mrb into buf after the "RITE" magic has been detected.
 * Returns true and sets *out_size on success; prints ERROR and returns false
 * if the size field is out of range. */
static bool recv_mrb(uint8_t *buf, uint32_t buf_size, uint32_t *out_size)
{
  uint8_t header[20];
  memcpy(header, "RITE", 4);
  recv_exact(header + 4, 16);

  uint32_t total = ((uint32_t)header[8]  << 24) | ((uint32_t)header[9]  << 16)
                 | ((uint32_t)header[10] <<  8) |  (uint32_t)header[11];

  if (total < 20 || total > buf_size) {
    printf("ERROR size\n");
    stdio_flush();
    return false;
  }

  memcpy(buf, header, 20);
  recv_exact(buf + 20, total - 20);
  *out_size = total;
  return true;
}

/* ── execute whatever is in mrb_buffer ──────────────────────────────────── */

static void exec_mrb(void)
{
  mrbc_cleanup();
  mrbc_init(memory_pool, HEAP_SIZE);
  runtime_define_methods();

  if (mrbc_create_task(hw_wrap, NULL) == NULL) {
    printf("ERROR hw_wrap\n");
    stdio_flush();
    return;
  }
#ifdef HAS_CYW43
  if (mrbc_create_task(cyw43_wrap, NULL) == NULL) {
    printf("ERROR cyw43_wrap\n");
    stdio_flush();
    return;
  }
  if (mrbc_create_task(socket_wrap, NULL) == NULL) {
    printf("ERROR socket_wrap\n");
    stdio_flush();
    return;
  }
#endif

  if (mrbc_create_task(mrb_buffer, NULL) == NULL) {
    printf("ERROR exec\n");
    stdio_flush();
    return;
  }

  printf("RUNNING\n");
  stdio_flush();

  repeating_timer_t reset_timer;
  add_repeating_timer_ms(100, check_reset_cb, NULL, &reset_timer);
  mrbc_run();
  cancel_repeating_timer(&reset_timer);

  printf("DONE\n");
  stdio_flush();
}

int main(void)
{
  stdio_init_all();

  /* On boot: run deployed script only on clean boot, not after a Ctrl+C reset.
   * Run before waiting for USB so the script works standalone (no host needed). */
  if (flash_has_script() && !watchdog_caused_reboot()) {
    uint32_t size = flash_script_size();
    if (size > 0 && size <= MRB_BUFFER_SIZE) {
      memcpy(mrb_buffer,
             (const void *)(FLASH_STORAGE_ADDR + FLASH_PAGE_SIZE),
             size);
      exec_mrb();
    }
  }

  while (!stdio_usb_connected()) sleep_ms(10);

  while (1) {
    printf("READY prremote-runtime/" RUNTIME_VERSION "\n");
    stdio_flush();

    /* Scan a 4-byte sliding window for:
     *   "RITE" — run .mrb now (one-shot)
     *   "DPLY" — save .mrb to flash (deploy), then loop back to READY
     * 0x03 (Ctrl+C) while idle restarts the loop. */
    uint8_t win[4] = {0};
    bool restart = false;
    for (;;) {
      win[0] = win[1]; win[1] = win[2]; win[2] = win[3];
      win[3] = (uint8_t)getchar();

      if (win[3] == 0x03) { restart = true; break; }

      if (memcmp(win, "RITE", 4) == 0) break;  /* proceed to run */

      if (memcmp(win, "DPLY", 4) == 0) {
        /* The .mrb data follows; scan for its "RITE" magic. */
        uint8_t win2[4] = {0};
        for (;;) {
          win2[0] = win2[1]; win2[1] = win2[2]; win2[2] = win2[3];
          win2[3] = (uint8_t)getchar();
          if (memcmp(win2, "RITE", 4) == 0) break;
        }

        uint32_t size = 0;
        if (recv_mrb(mrb_buffer, MRB_BUFFER_SIZE, &size)) {
          save_to_flash(mrb_buffer, size);
          printf("DEPLOYED\n");
          stdio_flush();
        }
        restart = true;
        break;
      }

      if (memcmp(win, "ERSE", 4) == 0) {
        uint32_t ints = save_and_disable_interrupts();
        flash_range_erase(FLASH_STORAGE_OFFSET, FLASH_STORAGE_SIZE);
        restore_interrupts(ints);
        printf("ERASED\n");
        stdio_flush();
        restart = true;
        break;
      }
    }
    if (restart) continue;

    uint32_t size = 0;
    if (!recv_mrb(mrb_buffer, MRB_BUFFER_SIZE, &size)) continue;

    exec_mrb();
  }

  return 0;
}
