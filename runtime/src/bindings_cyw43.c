#include "pico/cyw43_arch.h"
#include "lwip/ip_addr.h"
#include "lwip/netif.h"
#include <mrubyc.h>

/* Survives VM re-initialization across deploy cycles */
static bool s_cyw43_initialized = false;

/* ------------------------------------------------------------------ */
/* CYW43 chip / LED                                                    */
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
/* WiFi                                                                */
/* ------------------------------------------------------------------ */

static void c_wifi_connect(mrbc_vm *vm, mrbc_value v[], int argc)
{
  const char *ssid    = RSTRING_PTR(v[1]);
  const char *pass    = RSTRING_PTR(v[2]);
  int         timeout = GET_INT_ARG(3);
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
}
