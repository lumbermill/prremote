/* ESP32 WiFi + NTP bindings for prremote.
 *
 * Provides the same C primitives as bindings_cyw43.c on the Pico W so that
 * cyw43_wrap.rb and time_wrap.rb can be shared without modification:
 *   _cyw43_init / _cyw43_initialized / _cyw43_enable_sta_mode / _cyw43_disable_sta_mode
 *   _wifi_connect / _wifi_disconnect / _wifi_link_status
 *   _wifi_ipv4_address / _wifi_ipv4_netmask / _wifi_ipv4_gateway
 *   _ntp_gettime
 *
 * CYW43::GPIO is not implemented on ESP32 (M5Stack has no CYW43 LED).
 *
 * WiFi event loop is created once inside _cyw43_init and guarded against
 * double-init; subsequent calls to _cyw43_init are no-ops.
 *
 * NTP uses esp_sntp (ESP-IDF 5.x) instead of the lwIP raw-UDP client in
 * ntp.c, which is Pico W only. */

#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_wifi.h"
#include "esp_netif.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "lwip/ip4_addr.h"
#include "esp_sntp.h"
#include <time.h>
#include <mrubyc.h>

/* Link status codes — mirror cyw43_wrap.rb LINK_* constants. */
#define LINK_DOWN     0
#define LINK_UP       3
#define LINK_FAIL    -1
#define LINK_BADAUTH -3

static bool              s_wifi_initialized = false;
static EventGroupHandle_t s_wifi_eg;
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1
#define WIFI_BADAUTH_BIT   BIT2

static volatile int s_link_status = LINK_DOWN;

/* ------------------------------------------------------------------ */
/* Event handlers                                                      */
/* ------------------------------------------------------------------ */

static void on_wifi_event(void *arg, esp_event_base_t base,
                          int32_t id, void *data)
{
  if (id == WIFI_EVENT_STA_DISCONNECTED) {
    wifi_event_sta_disconnected_t *d = data;
    if (d->reason == WIFI_REASON_AUTH_FAIL ||
        d->reason == WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT ||
        d->reason == WIFI_REASON_AUTH_EXPIRE) {
      s_link_status = LINK_BADAUTH;
      xEventGroupSetBits(s_wifi_eg, WIFI_BADAUTH_BIT);
    } else {
      s_link_status = LINK_FAIL;
      xEventGroupSetBits(s_wifi_eg, WIFI_FAIL_BIT);
    }
  }
}

static void on_ip_event(void *arg, esp_event_base_t base,
                        int32_t id, void *data)
{
  if (id == IP_EVENT_STA_GOT_IP) {
    s_link_status = LINK_UP;
    xEventGroupSetBits(s_wifi_eg, WIFI_CONNECTED_BIT);
  }
}

/* ------------------------------------------------------------------ */
/* _cyw43_init([country_str])                                          */
/* ------------------------------------------------------------------ */

static void c_cyw43_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  if (s_wifi_initialized) { SET_TRUE_RETURN(); return; }

  /* NVS is required by the WiFi driver; ignore "already initialized" error. */
  esp_err_t err = nvs_flash_init();
  if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    nvs_flash_erase();
    nvs_flash_init();
  }

  ESP_ERROR_CHECK(esp_netif_init());
  ESP_ERROR_CHECK(esp_event_loop_create_default());
  esp_netif_create_default_wifi_sta();

  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  ESP_ERROR_CHECK(esp_wifi_init(&cfg));

  s_wifi_eg = xEventGroupCreate();

  ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID,
                                             on_wifi_event, NULL));
  ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP,
                                             on_ip_event, NULL));

  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
  ESP_ERROR_CHECK(esp_wifi_start());

  s_wifi_initialized = true;
  SET_TRUE_RETURN();
}

static void c_cyw43_initialized(mrbc_vm *vm, mrbc_value v[], int argc)
{
  SET_BOOL_RETURN(s_wifi_initialized);
}

/* STA mode is set in _cyw43_init; these are kept for API symmetry. */
static void c_cyw43_enable_sta_mode(mrbc_vm *vm, mrbc_value v[], int argc) {}
static void c_cyw43_disable_sta_mode(mrbc_vm *vm, mrbc_value v[], int argc)
{
  esp_wifi_disconnect();
  s_link_status = LINK_DOWN;
}

/* ------------------------------------------------------------------ */
/* _wifi_connect(ssid, pass, auth, timeout_ms) → 0 on success         */
/* ------------------------------------------------------------------ */

static void c_wifi_connect(mrbc_vm *vm, mrbc_value v[], int argc)
{
  const char *ssid    = (const char *)RSTRING_PTR(v[1]);
  const char *pass    = (const char *)RSTRING_PTR(v[2]);
  int         timeout = GET_INT_ARG(4);  /* auth (v[3]) is not used on ESP32 */

  /* Already connected — reuse the session (same behavior as Pico W). */
  if (s_link_status == LINK_UP) { SET_INT_RETURN(0); return; }

  s_link_status = LINK_DOWN;
  xEventGroupClearBits(s_wifi_eg, WIFI_CONNECTED_BIT | WIFI_FAIL_BIT | WIFI_BADAUTH_BIT);

  wifi_config_t wc = {0};
  strlcpy((char *)wc.sta.ssid,     ssid, sizeof(wc.sta.ssid));
  strlcpy((char *)wc.sta.password, pass, sizeof(wc.sta.password));
  wc.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;

  esp_wifi_set_config(WIFI_IF_STA, &wc);
  esp_wifi_connect();

  TickType_t ticks = (timeout <= 0) ? portMAX_DELAY
                                    : pdMS_TO_TICKS((uint32_t)timeout);
  EventBits_t bits = xEventGroupWaitBits(
      s_wifi_eg,
      WIFI_CONNECTED_BIT | WIFI_FAIL_BIT | WIFI_BADAUTH_BIT,
      pdFALSE, pdFALSE, ticks);

  if (bits & WIFI_CONNECTED_BIT) { SET_INT_RETURN(0); return; }
  SET_INT_RETURN(-1);
}

static void c_wifi_disconnect(mrbc_vm *vm, mrbc_value v[], int argc)
{
  esp_wifi_disconnect();
  s_link_status = LINK_DOWN;
}

static void c_wifi_link_status(mrbc_vm *vm, mrbc_value v[], int argc)
{
  SET_INT_RETURN(s_link_status);
}

/* ------------------------------------------------------------------ */
/* IP address helpers                                                  */
/* ------------------------------------------------------------------ */

static esp_netif_t *sta_netif(void)
{
  return esp_netif_get_handle_from_ifkey("WIFI_STA_DEF");
}

static void c_wifi_ipv4_address(mrbc_vm *vm, mrbc_value v[], int argc)
{
  esp_netif_ip_info_t info = {0};
  esp_netif_get_ip_info(sta_netif(), &info);
  char buf[16];
  snprintf(buf, sizeof(buf), IPSTR, IP2STR(&info.ip));
  SET_RETURN(mrbc_string_new_cstr(vm, buf));
}

static void c_wifi_ipv4_netmask(mrbc_vm *vm, mrbc_value v[], int argc)
{
  esp_netif_ip_info_t info = {0};
  esp_netif_get_ip_info(sta_netif(), &info);
  char buf[16];
  snprintf(buf, sizeof(buf), IPSTR, IP2STR(&info.netmask));
  SET_RETURN(mrbc_string_new_cstr(vm, buf));
}

static void c_wifi_ipv4_gateway(mrbc_vm *vm, mrbc_value v[], int argc)
{
  esp_netif_ip_info_t info = {0};
  esp_netif_get_ip_info(sta_netif(), &info);
  char buf[16];
  snprintf(buf, sizeof(buf), IPSTR, IP2STR(&info.gw));
  SET_RETURN(mrbc_string_new_cstr(vm, buf));
}

/* ------------------------------------------------------------------ */
/* _ntp_gettime(host, timeout_ms) → Integer (Unix epoch UTC) or 0     */
/* ------------------------------------------------------------------ */

static void c_ntp_gettime(mrbc_vm *vm, mrbc_value v[], int argc)
{
  const char *host       = (argc >= 1) ? (const char *)RSTRING_PTR(v[1]) : "pool.ntp.org";
  int         timeout_ms = (argc >= 2) ? GET_INT_ARG(2) : 10000;

  esp_sntp_setoperatingmode(SNTP_OPMODE_POLL);
  esp_sntp_setservername(0, host);
  esp_sntp_init();

  int elapsed = 0;
  time_t now = 0;
  while (elapsed < timeout_ms) {
    time(&now);
    if (now > 1000000000L) break;  /* valid epoch (post-2001) */
    vTaskDelay(pdMS_TO_TICKS(200));
    elapsed += 200;
  }

  esp_sntp_stop();
  SET_INT_RETURN((mrbc_int_t)now);
}

/* ------------------------------------------------------------------ */
/* Registration — called from runtime_define_methods() in             */
/* bindings_esp32.c after register_wifi_methods() is declared there.  */
/* ------------------------------------------------------------------ */

void register_wifi_methods(void)
{
  mrbc_define_method(0, mrbc_class_object, "_cyw43_init",            c_cyw43_init);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_initialized",     c_cyw43_initialized);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_enable_sta_mode", c_cyw43_enable_sta_mode);
  mrbc_define_method(0, mrbc_class_object, "_cyw43_disable_sta_mode",c_cyw43_disable_sta_mode);
  mrbc_define_method(0, mrbc_class_object, "_wifi_connect",          c_wifi_connect);
  mrbc_define_method(0, mrbc_class_object, "_wifi_disconnect",       c_wifi_disconnect);
  mrbc_define_method(0, mrbc_class_object, "_wifi_link_status",      c_wifi_link_status);
  mrbc_define_method(0, mrbc_class_object, "_wifi_ipv4_address",     c_wifi_ipv4_address);
  mrbc_define_method(0, mrbc_class_object, "_wifi_ipv4_netmask",     c_wifi_ipv4_netmask);
  mrbc_define_method(0, mrbc_class_object, "_wifi_ipv4_gateway",     c_wifi_ipv4_gateway);
  mrbc_define_method(0, mrbc_class_object, "_ntp_gettime",           c_ntp_gettime);
}
