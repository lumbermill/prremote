/*
 * CYW43 / WiFi C bindings for the prremote runtime.
 *
 * Design reference: picoruby-cyw43/ports/rp2040/cyw43.c
 *   The overall structure (init guard, arch_init_with_country, wifi_connect,
 *   ipv4_address / netmask / gateway) mirrors that file.  Key differences:
 *   - No DHCP-explicit start: pico_cyw43_arch_lwip_threadsafe_background
 *     already handles DHCP, so the extra dhcp_start() call is omitted.
 *   - All methods are registered as plain mruby/c object methods (_foo style)
 *     rather than as picoruby class methods; cyw43_wrap.rb provides the class
 *     facade on top.
 *   - LED sanity-check on init (cyw43_arch_gpio_put/get) is omitted for brevity.
 */

#include "pico/cyw43_arch.h"
#include "lwip/ip_addr.h"
#include "lwip/netif.h"
#include <mrubyc.h>
#include "ntp.h"

/* Survives VM re-initialization across deploy cycles */
static bool s_cyw43_initialized = false;

/* ------------------------------------------------------------------ */
/* CYW43 chip / LED                                                    */
/* ------------------------------------------------------------------ */

static void c_cyw43_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  if (!s_cyw43_initialized) {
    int res;
    /* Country-code handling adapted from picoruby-cyw43/ports/rp2040/cyw43.c
     * CYW43_arch_init_with_country(): passes a 2-char ISO string as a
     * CYW43_COUNTRY(A, B, rev) macro to the pico-sdk. */
    if (argc >= 1 && v[1].tt == MRBC_TT_STRING) {
      const uint8_t *cc = (const uint8_t *)RSTRING_PTR(v[1]);
      res = cyw43_arch_init_with_country(CYW43_COUNTRY(cc[0], cc[1], 0));
    } else {
      res = cyw43_arch_init();
    }
    if (res != 0) { SET_FALSE_RETURN(); return; }
    s_cyw43_initialized = true;
  }
  SET_TRUE_RETURN();
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
/* WiFi                                                                */
/* ------------------------------------------------------------------ */

static void c_wifi_connect(mrbc_vm *vm, mrbc_value v[], int argc)
{
  const char *ssid     = RSTRING_PTR(v[1]);
  const char *pass     = RSTRING_PTR(v[2]);
  uint32_t    auth     = (uint32_t)GET_INT_ARG(3);
  int         timeout  = GET_INT_ARG(4);
  int result = cyw43_arch_wifi_connect_timeout_ms(ssid, pass, auth, timeout);
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
/* NTP / SNTP                                                          */
/* ------------------------------------------------------------------ */

/* _ntp_gettime(host, timeout_ms) → Integer (Unix epoch UTC) or 0 on failure */
static void c_ntp_gettime(mrbc_vm *vm, mrbc_value v[], int argc)
{
  const char *host       = (argc >= 1) ? (const char *)RSTRING_PTR(v[1]) : "pool.ntp.org";
  int         timeout_ms = (argc >= 2) ? GET_INT_ARG(2) : 10000;
  SET_INT_RETURN((mrbc_int_t)ntp_get_unix_time(host, timeout_ms));
}

/* ------------------------------------------------------------------ */
/* Registration — called from runtime_define_methods() in bindings.c  */
/* ------------------------------------------------------------------ */

void register_cyw43_methods(void)
{
  mrbc_define_method(0, mrbc_class_object, "_cyw43_init",             c_cyw43_init);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_initialized",      c_cyw43_initialized);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_enable_sta_mode",  c_cyw43_enable_sta_mode);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_disable_sta_mode", c_cyw43_disable_sta_mode);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_gpio_put",         c_cyw43_gpio_put);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_gpio_get",         c_cyw43_gpio_get);
  mrbc_define_method(0, mrbc_class_object, "_wifi_connect",           c_wifi_connect);
  mrbc_define_method(0, mrbc_class_object, "_wifi_disconnect",        c_wifi_disconnect);
  mrbc_define_method(0, mrbc_class_object, "_wifi_link_status",       c_wifi_link_status);
  mrbc_define_method(0, mrbc_class_object, "_wifi_ipv4_address",      c_wifi_ipv4_address);
  mrbc_define_method(0, mrbc_class_object, "_wifi_ipv4_netmask",      c_wifi_ipv4_netmask);
  mrbc_define_method(0, mrbc_class_object, "_wifi_ipv4_gateway",      c_wifi_ipv4_gateway);
  mrbc_define_method(0, mrbc_class_object, "_ntp_gettime",            c_ntp_gettime);
}
