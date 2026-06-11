/* prremote runtime — serial protocol core (platform-neutral).
 *
 * Receives .mrb bytecode over the console and runs it on mruby/c:
 *   READY <version>  emitted when idle, waiting for a command
 *   RITE ...         run a .mrb one-shot
 *   DPLY META ...    save a .mrb to persistent storage (auto-runs on boot)
 *   ERSE             erase the stored script
 *   QURY             report the stored script's timestamp and filenames
 *   0x03 (Ctrl+C)    restart the READY loop / reboot while running
 *
 * All board-specific behavior (console, storage, reset) lives behind
 * prr_platform.h. */

#include <mrubyc.h>
#include <stdio.h>
#include <string.h>

#include "prr_platform.h"
#include "hw_wrap.h"
#ifdef HAS_WIFI
#include "cyw43_wrap.h"
#include "time_wrap.h"
#endif
#ifdef HAS_SOCKET
#include "socket_wrap.h"
#endif
#ifdef HAS_LCD
#include "lcd_wrap.h"
#endif

#define MRB_BUFFER_SIZE (32 * 1024)
#define HEAP_SIZE       (96 * 1024)

static uint8_t mrb_buffer[MRB_BUFFER_SIZE];
static uint8_t memory_pool[HEAP_SIZE];

void runtime_define_methods(void);

/* ── recv helpers ────────────────────────────────────────────────────────── */

static void recv_exact(uint8_t *buf, uint32_t n)
{
  for (uint32_t i = 0; i < n; i++) buf[i] = (uint8_t)prr_getchar();
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
    prr_flush();
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
    prr_flush();
    return;
  }
#ifdef HAS_WIFI
  if (mrbc_create_task(cyw43_wrap, NULL) == NULL) {
    printf("ERROR cyw43_wrap\n");
    prr_flush();
    return;
  }
  if (mrbc_create_task(time_wrap, NULL) == NULL) {
    printf("ERROR time_wrap\n");
    prr_flush();
    return;
  }
#endif
#ifdef HAS_SOCKET
  if (mrbc_create_task(socket_wrap, NULL) == NULL) {
    printf("ERROR socket_wrap\n");
    prr_flush();
    return;
  }
#endif
#ifdef HAS_LCD
  if (mrbc_create_task(lcd_wrap, NULL) == NULL) {
    printf("ERROR lcd_wrap\n");
    prr_flush();
    return;
  }
#endif
  if (mrbc_create_task(mrb_buffer, NULL) == NULL) {
    printf("ERROR exec\n");
    prr_flush();
    return;
  }

  printf("RUNNING\n");
  prr_flush();

  prr_reset_monitor_start();
  mrbc_run();
  prr_reset_monitor_stop();

  printf("DONE\n");
  prr_flush();
}

int prr_main(void)
{
  /* On boot: run deployed script only on clean boot, not after a Ctrl+C reset.
   * Run before waiting for the host so the script works standalone. */
  if (prr_storage_has_script() && !prr_was_soft_reset()) {
    uint32_t size = prr_storage_script_size();
    if (size > 0 && size <= MRB_BUFFER_SIZE &&
        prr_storage_load(mrb_buffer, size)) {
      exec_mrb();
    }
  }

  while (!prr_host_connected()) prr_sleep_ms(10);

  while (1) {
    printf("READY prremote-runtime/" RUNTIME_VERSION "\n");
    prr_flush();

    /* Scan a 4-byte sliding window for:
     *   "RITE" — run .mrb now (one-shot)
     *   "DPLY" — save .mrb to storage (deploy), then loop back to READY
     * 0x03 (Ctrl+C) while idle restarts the loop. */
    uint8_t win[4] = {0};
    bool restart = false;
    for (;;) {
      win[0] = win[1]; win[1] = win[2]; win[2] = win[3];
      win[3] = (uint8_t)prr_getchar();

      if (win[3] == 0x03) { restart = true; break; }

      if (memcmp(win, "RITE", 4) == 0) break;  /* proceed to run */

      if (memcmp(win, "DPLY", 4) == 0) {
        /* Expect META packet: "META" + 1-byte name_len + name_bytes
         * + 4-byte big-endian Unix timestamp. */
        uint8_t win2[4] = {0};
        for (;;) {
          win2[0] = win2[1]; win2[1] = win2[2]; win2[2] = win2[3];
          win2[3] = (uint8_t)prr_getchar();
          if (memcmp(win2, "META", 4) == 0) break;
        }
        uint8_t name_len_byte = (uint8_t)prr_getchar();
        if (name_len_byte > 240) name_len_byte = 240;
        uint8_t names_buf[241] = {0};
        if (name_len_byte > 0) recv_exact(names_buf, name_len_byte);
        uint8_t ts_bytes[4];
        recv_exact(ts_bytes, 4);
        uint32_t ts = ((uint32_t)ts_bytes[0] << 24) | ((uint32_t)ts_bytes[1] << 16)
                    | ((uint32_t)ts_bytes[2] <<  8) |  (uint32_t)ts_bytes[3];

        /* The .mrb data follows; scan for its "RITE" magic. */
        uint8_t win3[4] = {0};
        for (;;) {
          win3[0] = win3[1]; win3[1] = win3[2]; win3[2] = win3[3];
          win3[3] = (uint8_t)prr_getchar();
          if (memcmp(win3, "RITE", 4) == 0) break;
        }

        uint32_t size = 0;
        if (recv_mrb(mrb_buffer, MRB_BUFFER_SIZE, &size)) {
          prr_storage_save(mrb_buffer, size, ts, names_buf, name_len_byte);
          printf("DEPLOYED\n");
          prr_flush();
        }
        restart = true;
        break;
      }

      if (memcmp(win, "ERSE", 4) == 0) {
        prr_storage_erase();
        printf("ERASED\n");
        prr_flush();
        restart = true;
        break;
      }

      if (memcmp(win, "QURY", 4) == 0) {
        uint8_t header[PRR_STORAGE_HEADER_SIZE];
        if (prr_storage_read_header(header)) {
          uint32_t ts = ((uint32_t)header[8]  << 24) | ((uint32_t)header[9]  << 16)
                      | ((uint32_t)header[10] <<  8) |  (uint32_t)header[11];
          header[PRR_STORAGE_HEADER_SIZE - 1] = '\0';
          const char *names = (const char *)(header + 12);
          printf("DEPLOYED %u %s\n", (unsigned)ts,
                 *names ? names : "(unknown)");
        } else {
          printf("NONE\n");
        }
        prr_flush();
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
