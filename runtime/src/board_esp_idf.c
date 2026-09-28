/* Board identity for the ESP-IDF builds (esp32 / esp32c6), kept in NVS so it
 * survives reflashing the app and deploy/undeploy (which only touch the
 * "prremote" partition). See prr_board_get / prr_board_set in prr_platform.h. */

#include <string.h>
#include "nvs_flash.h"
#include "nvs.h"
#include "prr_platform.h"

#define BOARD_NVS_NAMESPACE "prremote"
#define BOARD_NVS_KEY       "board"

static char s_board[PRR_BOARD_NAME_MAX];
static bool s_loaded;

/* Same recovery as the WiFi binding: a full/old-format NVS is wiped. Calling
 * nvs_flash_init again later (WiFi.init) is harmless. */
static bool nvs_ready(void)
{
  esp_err_t err = nvs_flash_init();
  if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    nvs_flash_erase();
    err = nvs_flash_init();
  }
  return err == ESP_OK;
}

const char *prr_board_get(void)
{
  if (!s_loaded) {
    s_loaded = true;
    nvs_handle_t h;
    size_t len = sizeof(s_board);
    if (!nvs_ready() || nvs_open(BOARD_NVS_NAMESPACE, NVS_READONLY, &h) != ESP_OK) {
      s_board[0] = '\0';
    } else {
      if (nvs_get_str(h, BOARD_NVS_KEY, s_board, &len) != ESP_OK) s_board[0] = '\0';
      nvs_close(h);
    }
  }
  return s_board[0] ? s_board : PRR_DEFAULT_BOARD;
}

bool prr_board_set(const char *name)
{
  nvs_handle_t h;
  if (strlen(name) >= PRR_BOARD_NAME_MAX) return false;
  if (!nvs_ready() || nvs_open(BOARD_NVS_NAMESPACE, NVS_READWRITE, &h) != ESP_OK) {
    return false;
  }
  esp_err_t err = name[0] ? nvs_set_str(h, BOARD_NVS_KEY, name)
                          : nvs_erase_key(h, BOARD_NVS_KEY);
  if (err == ESP_ERR_NVS_NOT_FOUND) err = ESP_OK;  /* clearing an unset key */
  if (err == ESP_OK) err = nvs_commit(h);
  nvs_close(h);
  if (err != ESP_OK) return false;

  strcpy(s_board, name);
  s_loaded = true;
  return true;
}
