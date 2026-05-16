#include "pico/stdlib.h"
#include "pico/stdio.h"
#include "hardware/watchdog.h"
#include <mrubyc.h>
#include <stdio.h>
#include <string.h>

#ifdef HAS_CYW43
#include "cyw43_wrap.h"
#endif

#define MRB_BUFFER_SIZE (32 * 1024)
#define HEAP_SIZE       (96 * 1024)

static uint8_t mrb_buffer[MRB_BUFFER_SIZE];
static uint8_t memory_pool[HEAP_SIZE];

void runtime_define_methods(void);

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

int main(void)
{
  stdio_init_all();
  while (!stdio_usb_connected()) sleep_ms(10);

  while (1) {
    printf("READY prremote-runtime/" RUNTIME_VERSION "\n");
    stdio_flush();

    /* Scan for "RITE" magic using a 4-byte sliding window.
     * 0x03 (Ctrl+C) while idle restarts the loop so READY is re-announced. */
    uint8_t win[4] = {0};
    bool restarted = false;
    do {
      win[0] = win[1]; win[1] = win[2]; win[2] = win[3];
      win[3] = (uint8_t)getchar();
      if (win[3] == 0x03) { restarted = true; break; }
    } while (memcmp(win, "RITE", 4) != 0);
    if (restarted) continue;

    /* Read the remaining 16 bytes to complete the 20-byte RITE header */
    uint8_t header[20];
    memcpy(header, "RITE", 4);
    recv_exact(header + 4, 16);

    /* total_size is a big-endian uint32 at header bytes 8-11 */
    uint32_t total_size = ((uint32_t)header[8]  << 24)
                        | ((uint32_t)header[9]  << 16)
                        | ((uint32_t)header[10] <<  8)
                        |  (uint32_t)header[11];

    if (total_size < 20 || total_size > MRB_BUFFER_SIZE) {
      printf("ERROR size\n");
      stdio_flush();
      continue;
    }

    memcpy(mrb_buffer, header, 20);
    recv_exact(mrb_buffer + 20, total_size - 20);

    mrbc_cleanup();
    mrbc_init(memory_pool, HEAP_SIZE);
    runtime_define_methods();

#ifdef HAS_CYW43
    if (mrbc_create_task(cyw43_wrap, NULL) == NULL) {
      printf("ERROR wrap\n");
      stdio_flush();
      continue;
    }
#endif

    if (mrbc_create_task(mrb_buffer, NULL) == NULL) {
      printf("ERROR exec\n");
      stdio_flush();
      continue;
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

  return 0;
}
