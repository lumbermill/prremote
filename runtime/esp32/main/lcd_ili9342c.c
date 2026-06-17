/* ILI9342C LCD driver and _lcd_* bindings (ESP32 builds).
 *
 * Targets the M5GO / M5Stack Core gen1 panel (320x240 on VSPI) but all pins
 * are parameterized through _lcd_init, so any ILI9342C/ILI9341-class panel
 * wired to the GPIO matrix works. No full framebuffer: pixels are streamed
 * through two small ping-pong DMA buffers, so a fill or a text cell is the
 * largest single allocation (2 KB).
 *
 * Init command sequence and the inversion-on quirk follow M5GFX's
 * Panel_ILI9342 (https://github.com/m5stack/M5GFX) — M5Stack panels show
 * inverted colors unless INVON is set.
 *
 * Note: the LCD claims SPI3_HOST (VSPI), which is also what SPI.new(unit: 1)
 * uses — on boards with the panel attached (M5GO), unit 1 is the panel bus
 * anyway, so use SPI.new(unit: 0) for external devices. */

#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "driver/ledc.h"
#include "driver/spi_master.h"
#include "esp_lcd_panel_io.h"
#include <mrubyc.h>

#include "font8x8.h"

#define LCD_HOST       SPI3_HOST
#define LCD_PCLK_HZ    (40 * 1000 * 1000)
#define LCD_MAX_CHUNK  4608   /* fits an 8x8 glyph at scale 6 (48*48*2) */
#define LCD_MAX_SCALE  6

/* Backlight PWM: top LEDC channel/timer to stay clear of the PWM class,
 * which allocates channels 0..7 and timers 0..3 from the bottom. */
#define LCD_BL_CHANNEL LEDC_CHANNEL_7
#define LCD_BL_TIMER   LEDC_TIMER_3

static esp_lcd_panel_io_handle_t s_io;
static int s_width;
static int s_height;
static int s_bl_pin = -1;

/* Two ping-pong buffers: esp_lcd_panel_io_tx_color() queues the transfer
 * (queue depth 1), so the buffer in flight must not be refilled until the
 * next tx_color call has implicitly waited for it. */
static uint8_t s_txbuf[2][LCD_MAX_CHUNK];
static int     s_txidx;

static uint8_t *next_txbuf(void)
{
  s_txidx ^= 1;
  return s_txbuf[s_txidx];
}

static void lcd_cmd(uint8_t cmd, const uint8_t *data, size_t len)
{
  esp_lcd_panel_io_tx_param(s_io, cmd, data, len);
}

static void lcd_set_window(int x0, int y0, int x1, int y1)
{
  uint8_t caset[4] = { x0 >> 8, x0 & 0xFF, x1 >> 8, x1 & 0xFF };
  uint8_t raset[4] = { y0 >> 8, y0 & 0xFF, y1 >> 8, y1 & 0xFF };
  lcd_cmd(0x2A, caset, 4);   /* CASET */
  lcd_cmd(0x2B, raset, 4);   /* RASET */
}

static void lcd_backlight_init(int bl_pin)
{
  s_bl_pin = bl_pin;
  if (bl_pin < 0) return;

  ledc_timer_config_t tcfg = {
    .speed_mode      = LEDC_LOW_SPEED_MODE,
    .timer_num       = LCD_BL_TIMER,
    .duty_resolution = LEDC_TIMER_8_BIT,
    .freq_hz         = 5000,
    .clk_cfg         = LEDC_AUTO_CLK,
  };
  ledc_timer_config(&tcfg);

  ledc_channel_config_t ccfg = {
    .gpio_num   = bl_pin,
    .speed_mode = LEDC_LOW_SPEED_MODE,
    .channel    = LCD_BL_CHANNEL,
    .timer_sel  = LCD_BL_TIMER,
    .duty       = 0,
    .hpoint     = 0,
  };
  ledc_channel_config(&ccfg);
}

static void lcd_set_brightness(int pct)
{
  if (s_bl_pin < 0) return;
  if (pct < 0)   pct = 0;
  if (pct > 100) pct = 100;
  ledc_set_duty(LEDC_LOW_SPEED_MODE, LCD_BL_CHANNEL, (255 * pct) / 100);
  ledc_update_duty(LEDC_LOW_SPEED_MODE, LCD_BL_CHANNEL);
}

/* ------------------------------------------------------------------ */
/* _lcd_init(rotation, sck, mosi, miso, cs, dc, rst, bl) → true/false  */
/* ------------------------------------------------------------------ */

static void c_lcd_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int rotation = GET_INT_ARG(1) & 0x03;
  int sck      = GET_INT_ARG(2);
  int mosi     = GET_INT_ARG(3);
  int miso     = GET_INT_ARG(4);
  int cs       = GET_INT_ARG(5);
  int dc       = GET_INT_ARG(6);
  int rst      = GET_INT_ARG(7);
  int bl       = GET_INT_ARG(8);

  if (s_io != NULL) {
    esp_lcd_panel_io_del(s_io);
    s_io = NULL;
    spi_bus_free(LCD_HOST);
  }

  /* Hardware reset (panel needs ≥10 µs low, then 120 ms to settle). */
  if (rst >= 0) {
    gpio_reset_pin(rst);
    gpio_set_direction(rst, GPIO_MODE_OUTPUT);
    gpio_set_level(rst, 1);
    vTaskDelay(pdMS_TO_TICKS(10));
    gpio_set_level(rst, 0);
    vTaskDelay(pdMS_TO_TICKS(10));
    gpio_set_level(rst, 1);
    vTaskDelay(pdMS_TO_TICKS(120));
  }

  spi_bus_config_t bus = {
    .sclk_io_num     = sck,
    .mosi_io_num     = mosi,
    .miso_io_num     = miso,
    .quadwp_io_num   = -1,
    .quadhd_io_num   = -1,
    .max_transfer_sz = LCD_MAX_CHUNK,
  };
  if (spi_bus_initialize(LCD_HOST, &bus, SPI_DMA_CH_AUTO) != ESP_OK) {
    SET_FALSE_RETURN();
    return;
  }

  esp_lcd_panel_io_spi_config_t io_cfg = {
    .cs_gpio_num       = cs,
    .dc_gpio_num       = dc,
    .pclk_hz           = LCD_PCLK_HZ,
    .spi_mode          = 0,
    .trans_queue_depth = 1,
    .lcd_cmd_bits      = 8,
    .lcd_param_bits    = 8,
  };
  if (esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)LCD_HOST,
                               &io_cfg, &s_io) != ESP_OK) {
    spi_bus_free(LCD_HOST);
    SET_FALSE_RETURN();
    return;
  }

  /* MADCTL per rotation; 0x08 = BGR, native M5Stack orientation
   * (buttons at the bottom). Odd rotations swap width/height. */
  static const uint8_t madctl[4] = { 0x08, 0x68, 0xC8, 0xA8 };
  bool swap = (rotation & 1) != 0;
  s_width  = swap ? 240 : 320;
  s_height = swap ? 320 : 240;

  lcd_cmd(0x01, NULL, 0);                          /* SWRESET */
  vTaskDelay(pdMS_TO_TICKS(120));
  lcd_cmd(0x11, NULL, 0);                          /* SLPOUT */
  vTaskDelay(pdMS_TO_TICKS(120));
  lcd_cmd(0x3A, (uint8_t[]){0x55}, 1);             /* COLMOD: RGB565 */
  lcd_cmd(0x36, &madctl[rotation], 1);             /* MADCTL */
  lcd_cmd(0x21, NULL, 0);                          /* INVON (M5Stack quirk) */
  lcd_cmd(0x29, NULL, 0);                          /* DISPON */
  vTaskDelay(pdMS_TO_TICKS(20));

  lcd_backlight_init(bl);
  lcd_set_brightness(80);

  SET_TRUE_RETURN();
}

/* ------------------------------------------------------------------ */
/* _lcd_fill_rect(x, y, w, h, color565)                                */
/* ------------------------------------------------------------------ */

static void c_lcd_fill_rect(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int x = GET_INT_ARG(1);
  int y = GET_INT_ARG(2);
  int w = GET_INT_ARG(3);
  int h = GET_INT_ARG(4);
  uint16_t color = (uint16_t)GET_INT_ARG(5);

  if (s_io == NULL) return;

  /* Clip to the panel. */
  if (x < 0) { w += x; x = 0; }
  if (y < 0) { h += y; y = 0; }
  if (x + w > s_width)  w = s_width - x;
  if (y + h > s_height) h = s_height - y;
  if (w <= 0 || h <= 0) return;

  lcd_set_window(x, y, x + w - 1, y + h - 1);

  int rows_per_chunk = LCD_MAX_CHUNK / (w * 2);
  if (rows_per_chunk < 1) rows_per_chunk = 1;

  int sent_rows = 0;
  bool first = true;
  while (sent_rows < h) {
    int rows = h - sent_rows;
    if (rows > rows_per_chunk) rows = rows_per_chunk;

    uint8_t *buf = next_txbuf();
    for (int i = 0; i < w * rows; i++) {
      buf[i * 2]     = color >> 8;   /* RGB565 big-endian on the wire */
      buf[i * 2 + 1] = color & 0xFF;
    }
    /* RAMWR on the first chunk; -1 continues it (the write pointer
     * survives CS toggling between transactions). */
    esp_lcd_panel_io_tx_color(s_io, first ? 0x2C : -1, buf, w * rows * 2);
    first = false;
    sent_rows += rows;
  }
}

/* ------------------------------------------------------------------ */
/* _lcd_text(x, y, str, fg565, bg565, scale)                           */
/* ------------------------------------------------------------------ */

static void c_lcd_text(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int x = GET_INT_ARG(1);
  int y = GET_INT_ARG(2);
  uint16_t fg = (uint16_t)GET_INT_ARG(4);
  uint16_t bg = (uint16_t)GET_INT_ARG(5);
  int scale   = GET_INT_ARG(6);

  if (s_io == NULL || v[3].tt != MRBC_TT_STRING) return;
  if (scale < 1) scale = 1;
  if (scale > LCD_MAX_SCALE) scale = LCD_MAX_SCALE;

  const char *str = mrbc_string_cstr(&v[3]);
  int len         = mrbc_string_size(&v[3]);
  int cell        = 8 * scale;

  for (int ci = 0; ci < len; ci++) {
    if (x + cell > s_width || y + cell > s_height) break;

    uint8_t ch = (uint8_t)str[ci];
    if (ch > 0x7F) ch = '?';
    const unsigned char *glyph = font8x8_basic[ch];

    uint8_t *buf = next_txbuf();
    int o = 0;
    for (int row = 0; row < cell; row++) {
      uint8_t bits = glyph[row / scale];
      for (int col = 0; col < cell; col++) {
        /* font8x8 stores rows LSB-first (bit 0 = leftmost pixel). */
        uint16_t c = (bits >> (col / scale)) & 1 ? fg : bg;
        buf[o++] = c >> 8;
        buf[o++] = c & 0xFF;
      }
    }

    lcd_set_window(x, y, x + cell - 1, y + cell - 1);
    esp_lcd_panel_io_tx_color(s_io, 0x2C, buf, o);
    x += cell;
  }
}

/* ------------------------------------------------------------------ */
/* _lcd_brightness(pct)                                                */
/* ------------------------------------------------------------------ */

static void c_lcd_brightness(mrbc_vm *vm, mrbc_value v[], int argc)
{
  lcd_set_brightness(GET_INT_ARG(1));
}

/* ------------------------------------------------------------------ */

void register_lcd_methods(void)
{
  mrbc_define_method(0, mrbc_class_object, "_lcd_init",       c_lcd_init);
  mrbc_define_method(0, mrbc_class_object, "_lcd_fill_rect",  c_lcd_fill_rect);
  mrbc_define_method(0, mrbc_class_object, "_lcd_text",       c_lcd_text);
  mrbc_define_method(0, mrbc_class_object, "_lcd_brightness", c_lcd_brightness);
}
