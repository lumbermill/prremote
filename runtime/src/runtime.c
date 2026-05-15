#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "hardware/gpio.h"
#include "hardware/watchdog.h"
#include "lwip/ip_addr.h"
#include "lwip/netif.h"
#include <mrubyc.h>
#include <string.h>

#define MRB_BUFFER_SIZE (32 * 1024)
#define HEAP_SIZE       (96 * 1024)

static uint8_t mrb_buffer[MRB_BUFFER_SIZE];
static uint8_t memory_pool[HEAP_SIZE];

/* CYW43 state survives VM re-initialization across runs */
static bool s_cyw43_initialized = false;

/* ------------------------------------------------------------------ */
/* C bindings: CYW43 (merged from led.c / gpio.c / wifi.c)            */
/* ------------------------------------------------------------------ */

static void c_cyw43_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  if (!s_cyw43_initialized) {
    cyw43_arch_init();
    s_cyw43_initialized = true;
  }
}

static void c_cyw43_initialized(mrbc_vm *vm, mrbc_value v[], int argc)
{
  SET_BOOL_RETURN(s_cyw43_initialized);
}

static void c_cyw43_enable_sta_mode(mrbc_vm *vm, mrbc_value v[], int argc)
{
  cyw43_arch_enable_sta_mode();
}

static void c_cyw43_disable_sta_mode(mrbc_vm *vm, mrbc_value v[], int argc)
{
  cyw43_wifi_leave(&cyw43_state, CYW43_ITF_STA);
}

static void c_cyw43_gpio_put(mrbc_vm *vm, mrbc_value v[], int argc)
{
  cyw43_arch_gpio_put(GET_INT_ARG(1), GET_INT_ARG(2));
}

static void c_cyw43_gpio_get(mrbc_vm *vm, mrbc_value v[], int argc)
{
  SET_INT_RETURN(cyw43_arch_gpio_get(GET_INT_ARG(1)));
}

/* ------------------------------------------------------------------ */
/* C bindings: WiFi                                                    */
/* ------------------------------------------------------------------ */

static void c_wifi_connect(mrbc_vm *vm, mrbc_value v[], int argc)
{
  const char *ssid     = RSTRING_PTR(v[1]);
  const char *pass     = RSTRING_PTR(v[2]);
  int         timeout  = GET_INT_ARG(3);
  int result = cyw43_arch_wifi_connect_timeout_ms(ssid, pass, CYW43_AUTH_WPA2_AES_PSK, timeout);
  SET_INT_RETURN(result);
}

static void c_wifi_disconnect(mrbc_vm *vm, mrbc_value v[], int argc)
{
  cyw43_wifi_leave(&cyw43_state, CYW43_ITF_STA);
}

static void c_wifi_link_status(mrbc_vm *vm, mrbc_value v[], int argc)
{
  cyw43_arch_lwip_begin();
  int status = cyw43_tcpip_link_status(&cyw43_state, CYW43_ITF_STA);
  cyw43_arch_lwip_end();
  SET_INT_RETURN(status);
}

static void c_wifi_ipv4_address(mrbc_vm *vm, mrbc_value v[], int argc)
{
  char buf[16];
  cyw43_arch_lwip_begin();
  snprintf(buf, sizeof(buf), "%s",
    ip4addr_ntoa(netif_ip4_addr(&cyw43_state.netif[CYW43_ITF_STA])));
  cyw43_arch_lwip_end();
  SET_RETURN(mrbc_string_new_cstr(vm, buf));
}

static void c_wifi_ipv4_netmask(mrbc_vm *vm, mrbc_value v[], int argc)
{
  char buf[16];
  cyw43_arch_lwip_begin();
  snprintf(buf, sizeof(buf), "%s",
    ip4addr_ntoa(netif_ip4_netmask(&cyw43_state.netif[CYW43_ITF_STA])));
  cyw43_arch_lwip_end();
  SET_RETURN(mrbc_string_new_cstr(vm, buf));
}

static void c_wifi_ipv4_gateway(mrbc_vm *vm, mrbc_value v[], int argc)
{
  char buf[16];
  cyw43_arch_lwip_begin();
  snprintf(buf, sizeof(buf), "%s",
    ip4addr_ntoa(netif_ip4_gw(&cyw43_state.netif[CYW43_ITF_STA])));
  cyw43_arch_lwip_end();
  SET_RETURN(mrbc_string_new_cstr(vm, buf));
}

/* ------------------------------------------------------------------ */
/* C bindings: GPIO                                                    */
/* ------------------------------------------------------------------ */

static void c_gpio_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_init(GET_INT_ARG(1));
}

static void c_gpio_set_dir(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_set_dir(GET_INT_ARG(1), GET_INT_ARG(2));
}

static void c_gpio_pull_up(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_pull_up(GET_INT_ARG(1));
}

static void c_gpio_pull_down(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_pull_down(GET_INT_ARG(1));
}

static void c_gpio_put(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_put(GET_INT_ARG(1), GET_INT_ARG(2));
}

static void c_gpio_get(mrbc_vm *vm, mrbc_value v[], int argc)
{
  SET_INT_RETURN(gpio_get(GET_INT_ARG(1)) ? 1 : 0);
}

/* ------------------------------------------------------------------ */
/* Register all methods — must be called after every mrbc_init()      */
/* ------------------------------------------------------------------ */

static void runtime_define_methods(void)
{
  mrbc_define_method(0, mrbc_class_object, "_cyw43_init",            c_cyw43_init);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_initialized",     c_cyw43_initialized);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_enable_sta_mode", c_cyw43_enable_sta_mode);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_disable_sta_mode",c_cyw43_disable_sta_mode);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_gpio_put",        c_cyw43_gpio_put);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_gpio_get",        c_cyw43_gpio_get);
  mrbc_define_method(0, mrbc_class_object, "_wifi_connect",          c_wifi_connect);
  mrbc_define_method(0, mrbc_class_object, "_wifi_disconnect",       c_wifi_disconnect);
  mrbc_define_method(0, mrbc_class_object, "_wifi_link_status",      c_wifi_link_status);
  mrbc_define_method(0, mrbc_class_object, "_wifi_ipv4_address",     c_wifi_ipv4_address);
  mrbc_define_method(0, mrbc_class_object, "_wifi_ipv4_netmask",     c_wifi_ipv4_netmask);
  mrbc_define_method(0, mrbc_class_object, "_wifi_ipv4_gateway",     c_wifi_ipv4_gateway);
  mrbc_define_method(0, mrbc_class_object, "_gpio_init",             c_gpio_init);
  mrbc_define_method(0, mrbc_class_object, "_gpio_set_dir",          c_gpio_set_dir);
  mrbc_define_method(0, mrbc_class_object, "_gpio_pull_up",          c_gpio_pull_up);
  mrbc_define_method(0, mrbc_class_object, "_gpio_pull_down",        c_gpio_pull_down);
  mrbc_define_method(0, mrbc_class_object, "_gpio_put",              c_gpio_put);
  mrbc_define_method(0, mrbc_class_object, "_gpio_get",              c_gpio_get);
}

/* ------------------------------------------------------------------ */
/* Reset watchdog: fires when Ctrl+C (0x03) is received mid-run      */
/* ------------------------------------------------------------------ */

static bool check_reset_cb(repeating_timer_t *t)
{
  int c = getchar_timeout_us(0);
  if (c == 0x03) {
    watchdog_enable(1, 1);
    while (1) tight_loop_contents();
  }
  return true;
}

/* ------------------------------------------------------------------ */
/* Read exactly n bytes from USB serial (blocking)                    */
/* ------------------------------------------------------------------ */

static void recv_exact(uint8_t *buf, uint32_t n)
{
  for (uint32_t i = 0; i < n; i++) {
    buf[i] = (uint8_t)getchar();
  }
}

/* ------------------------------------------------------------------ */
/* main                                                                */
/* ------------------------------------------------------------------ */

int main(void)
{
  stdio_init_all();

  /* Wait until the USB CDC host opens the port */
  while (!stdio_usb_connected()) {
    sleep_ms(10);
  }

  while (1) {
    printf("READY prremote-runtime/" RUNTIME_VERSION "\n");
    stdio_flush();

    /* Scan for "RITE" magic using a 4-byte sliding window.
     * This tolerates any garbage bytes that arrive before the .mrb data. */
    uint8_t win[4] = {0};
    do {
      win[0] = win[1];
      win[1] = win[2];
      win[2] = win[3];
      win[3] = (uint8_t)getchar();
    } while (memcmp(win, "RITE", 4) != 0);

    /* Read the remaining 16 bytes to complete the 20-byte RITE header */
    uint8_t header[20];
    memcpy(header, "RITE", 4);
    recv_exact(header + 4, 16);

    /* total_size is a big-endian uint32 at header bytes 8–11 */
    uint32_t total_size = ((uint32_t)header[8]  << 24)
                        | ((uint32_t)header[9]  << 16)
                        | ((uint32_t)header[10] <<  8)
                        |  (uint32_t)header[11];

    if (total_size < 20 || total_size > MRB_BUFFER_SIZE) {
      printf("ERROR size\n");
      stdio_flush();
      continue;
    }

    /* Copy header into buffer then receive the rest of the bytecode */
    memcpy(mrb_buffer, header, 20);
    recv_exact(mrb_buffer + 20, total_size - 20);

    /* Re-initialize VM for each run */
    mrbc_cleanup();
    mrbc_init(memory_pool, HEAP_SIZE);
    runtime_define_methods();

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
