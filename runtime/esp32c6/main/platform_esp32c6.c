/* ESP32-C6 implementation of the prremote platform interface.
 * The XIAO ESP32C6 routes its USB-C port directly to the ESP32-C6 native USB
 * Serial/JTAG peripheral — there is no separate USB-UART bridge chip.
 * ESP-IDF auto-installs the USB Serial/JTAG driver when
 * CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG=y, so prr_console_init() only needs to
 * disable stdio buffering.  Script storage is the same "prremote" data
 * partition as the classic ESP32 build. */

#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/usb_serial_jtag.h"
#include "driver/usb_serial_jtag_vfs.h"
#include "esp_timer.h"
#include "esp_partition.h"
#include "esp_system.h"

#include "prr_platform.h"

#define PRR_PARTITION_SUBTYPE 0x40

/* ── console ─────────────────────────────────────────────────────────────── */

void prr_console_init(void)
{
  /* The console VFS registered by ESP-IDF startup
   * (CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG=y) is the non-driver, *non-blocking*
   * implementation: getchar() returns EOF (stored by recv_exact as 0xFF) for
   * any byte not yet arrived, which desyncs the binary .mrb stream. Install
   * the interrupt-driven driver and route the VFS through it so getchar()
   * BLOCKS until each byte is available — mirrors the UART driver setup on the
   * classic ESP32 build. RX line-ending conversion must be disabled: the .mrb
   * payload is binary and a CR->LF translation would corrupt it. TX stays
   * CRLF, which the host's serial_helpers normalize() already handles. */
  usb_serial_jtag_driver_config_t cfg = USB_SERIAL_JTAG_DRIVER_CONFIG_DEFAULT();
  /* Enlarge the RX ring (default 256 B). The host paces .mrb writes in 256-byte
   * chunks, but the controller applies no USB backpressure: if the firmware
   * stalls briefly while draining byte-by-byte, the default ring overflows and
   * silently drops bytes, which used to wedge recv_exact forever. A larger ring
   * absorbs those transients; recv's timeout (see runtime.c) is the backstop. */
  cfg.rx_buffer_size = 4096;
  usb_serial_jtag_driver_install(&cfg);
  usb_serial_jtag_vfs_use_driver();
  usb_serial_jtag_vfs_set_rx_line_endings(ESP_LINE_ENDINGS_LF);
  usb_serial_jtag_vfs_set_tx_line_endings(ESP_LINE_ENDINGS_CRLF);
  setvbuf(stdin, NULL, _IONBF, 0);
  setvbuf(stdout, NULL, _IONBF, 0);
}

/* USB CDC connection cannot be reliably detected at this level; always report
 * connected (same assumption as the classic ESP32 UART build). */
bool prr_host_connected(void) { return true; }

int prr_getchar(void) { return getchar(); }

/* Reads straight from the USB Serial/JTAG driver buffer (the same buffer
 * getchar() drains via the VFS) with a tick-based timeout; returns PRR_NO_CHAR
 * on timeout. RX line-ending conversion is off, so the bytes match getchar()'s. */
int prr_getchar_timeout(uint32_t ms)
{
  uint8_t c;
  return usb_serial_jtag_read_bytes(&c, 1, pdMS_TO_TICKS(ms)) == 1 ? c : PRR_NO_CHAR;
}

void prr_flush(void)
{
  fflush(stdout);
  /* The USB TX FIFO drains asynchronously.  A short yield gives the driver
   * time to push any remaining bytes before the next protocol byte is read. */
  vTaskDelay(pdMS_TO_TICKS(2));
}

void prr_sleep_ms(uint32_t ms) { vTaskDelay(pdMS_TO_TICKS(ms ? ms : 1)); }

/* ── persistent script storage ───────────────────────────────────────────── */

static const esp_partition_t *storage(void)
{
  static const esp_partition_t *p;
  if (p == NULL) {
    p = esp_partition_find_first(ESP_PARTITION_TYPE_DATA,
                                 PRR_PARTITION_SUBTYPE, "prremote");
  }
  return p;
}

bool prr_storage_has_script(void)
{
  const esp_partition_t *p = storage();
  uint8_t magic[4];
  if (p == NULL || esp_partition_read(p, 0, magic, 4) != ESP_OK) return false;
  return memcmp(magic, "PRRD", 4) == 0;
}

uint32_t prr_storage_script_size(void)
{
  const esp_partition_t *p = storage();
  uint8_t h[4];
  if (p == NULL || esp_partition_read(p, 4, h, 4) != ESP_OK) return 0;
  return ((uint32_t)h[0] << 24) | ((uint32_t)h[1] << 16)
       | ((uint32_t)h[2] <<  8) |  (uint32_t)h[3];
}

bool prr_storage_read_header(uint8_t out[PRR_STORAGE_HEADER_SIZE])
{
  if (!prr_storage_has_script()) return false;
  return esp_partition_read(storage(), 0, out, PRR_STORAGE_HEADER_SIZE) == ESP_OK;
}

bool prr_storage_load(uint8_t *buf, uint32_t size)
{
  const esp_partition_t *p = storage();
  if (p == NULL) return false;
  return esp_partition_read(p, PRR_STORAGE_HEADER_SIZE, buf, size) == ESP_OK;
}

void prr_storage_save(const uint8_t *data, uint32_t size,
                      uint32_t ts, const uint8_t *names, uint8_t name_len)
{
  const esp_partition_t *p = storage();
  if (p == NULL) return;

  esp_partition_erase_range(p, 0, p->size);

  uint8_t header[PRR_STORAGE_HEADER_SIZE] = {0};
  memcpy(header, "PRRD", 4);
  header[4] = (size >> 24) & 0xFF;
  header[5] = (size >> 16) & 0xFF;
  header[6] = (size >>  8) & 0xFF;
  header[7] =  size        & 0xFF;
  header[8]  = (ts >> 24) & 0xFF;
  header[9]  = (ts >> 16) & 0xFF;
  header[10] = (ts >>  8) & 0xFF;
  header[11] =  ts        & 0xFF;
  if (name_len > 0) memcpy(header + 12, names, name_len);

  esp_partition_write(p, 0, header, sizeof(header));
  esp_partition_write(p, PRR_STORAGE_HEADER_SIZE, data, size);
}

void prr_storage_erase(void)
{
  const esp_partition_t *p = storage();
  if (p != NULL) esp_partition_erase_range(p, 0, p->size);
}

/* ── reset handling ──────────────────────────────────────────────────────── */

/* Same reset strategy as the classic ESP32 build: a DTR/RTS-triggered reset
 * reports ESP_RST_POWERON so the deployed script auto-runs on connect; the
 * 0x03 sent by the host immediately after triggers esp_restart(), and
 * ESP_RST_SW then skips autorun. */
bool prr_was_soft_reset(void) { return esp_reset_reason() == ESP_RST_SW; }

static void reset_check_cb(void *arg)
{
  /* Read directly from the USB Serial/JTAG driver buffer (non-blocking,
   * timeout 0) so the VFS read path is not disturbed. */
  uint8_t c;
  while (usb_serial_jtag_read_bytes(&c, 1, 0) == 1) {
    if (c == 0x03) esp_restart();
  }
}

static esp_timer_handle_t s_reset_timer;

void prr_reset_monitor_start(void)
{
  if (s_reset_timer == NULL) {
    const esp_timer_create_args_t args = {
      .callback = reset_check_cb,
      .name     = "prr_reset",
    };
    esp_timer_create(&args, &s_reset_timer);
  }
  esp_timer_start_periodic(s_reset_timer, 100 * 1000);
}

void prr_reset_monitor_stop(void)
{
  if (s_reset_timer != NULL) esp_timer_stop(s_reset_timer);
}

/* ── entry point ─────────────────────────────────────────────────────────── */

void app_main(void)
{
  prr_console_init();
  prr_main();
}
