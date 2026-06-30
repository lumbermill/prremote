/* ESP32-C6 implementations of the C primitives used by hw_wrap.rb.
 * Same method names and signatures as the classic ESP32 versions in
 * esp32/main/bindings_esp32.c; see that file for the canonical semantics.
 *
 * Differences from the classic ESP32 build:
 *   ADC     — ADC1 is on GPIO 0-6 (not 32-39); adc_oneshot_io_to_channel()
 *              handles the mapping; only the error message changes.
 *   PWM     — ESP32-C6 LEDC has 6 channels (not 8); PWM_SLOTS reduced to 6.
 *   I2C     — XIAO default pins: SDA=6 (D4), SCL=7 (D5).
 *   SPI     — ESP32-C6 only has SPI2_HOST; SPI3_HOST does not exist.
 *             XIAO default pins: SCK=19 (D8), MOSI=18 (D10).
 *   LCD     — HAS_LCD is defined; the shared ILI9342C/ILI9341 driver
 *             (esp32/main/lcd_ili9342c.c) is compiled in, with LCD_HOST
 *             switched to SPI2_HOST. register_lcd_methods() is called below. */

#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_timer.h"
#include "esp_log.h"
#include "driver/gpio.h"
#include "driver/ledc.h"
#include "driver/i2c_master.h"
#include "driver/spi_master.h"
#include "esp_adc/adc_oneshot.h"
#include <mrubyc.h>

/* ------------------------------------------------------------------ */
/* sleep(seconds)  — float or integer                                  */
/* ------------------------------------------------------------------ */

static void c_sleep(mrbc_vm *vm, mrbc_value v[], int argc)
{
  uint32_t ms;
  if (v[1].tt == MRBC_TT_FLOAT) {
    ms = (uint32_t)(v[1].d * 1000.0);
  } else {
    ms = (uint32_t)(v[1].i * 1000);
  }
  vTaskDelay(pdMS_TO_TICKS(ms ? ms : 1));
}

/* ------------------------------------------------------------------ */
/* uptime_ms — milliseconds since boot (wraps ~49 days)               */
/* ------------------------------------------------------------------ */

static void c_uptime_ms(mrbc_vm *vm, mrbc_value v[], int argc)
{
  SET_INT_RETURN((mrbc_int_t)(esp_timer_get_time() / 1000));
}

/* ------------------------------------------------------------------ */
/* exit([code])  — stop the current script and return to READY        */
/* ------------------------------------------------------------------ */

static void c_exit(mrbc_vm *vm, mrbc_value v[], int argc)
{
  vm->flag_stop = 1;
  vm->flag_preemption = 1;
}

/* ------------------------------------------------------------------ */
/* Raw GPIO bindings                                                   */
/* All ESP32-C6 GPIOs support input and output; no input-only pins.   */
/* ------------------------------------------------------------------ */

static void c_gpio_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_reset_pin(GET_INT_ARG(1));
}

static void c_gpio_set_dir(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_set_direction(GET_INT_ARG(1),
                     GET_INT_ARG(2) ? GPIO_MODE_OUTPUT : GPIO_MODE_INPUT);
}

static void c_gpio_pull_up(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_set_pull_mode(GET_INT_ARG(1), GPIO_PULLUP_ONLY);
}

static void c_gpio_pull_down(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_set_pull_mode(GET_INT_ARG(1), GPIO_PULLDOWN_ONLY);
}

static void c_gpio_put(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_set_level(GET_INT_ARG(1), GET_INT_ARG(2));
}

static void c_gpio_get(mrbc_vm *vm, mrbc_value v[], int argc)
{
  SET_INT_RETURN(gpio_get_level(GET_INT_ARG(1)) ? 1 : 0);
}

/* ------------------------------------------------------------------ */
/* Onboard LED (GPIO.led) — Seeed XIAO ESP32C6 user LED on GPIO 15,    */
/* active-low (driving the pin low turns the LED on). The active-low   */
/* inversion is hidden here so write(1) always means "on".            */
/* ------------------------------------------------------------------ */

#define BOARD_LED_GPIO 15

static void c_led_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_reset_pin(BOARD_LED_GPIO);
  gpio_set_direction(BOARD_LED_GPIO, GPIO_MODE_OUTPUT);
  gpio_set_level(BOARD_LED_GPIO, 1); /* active-low: start off */
}

static void c_led_put(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_set_level(BOARD_LED_GPIO, GET_INT_ARG(1) ? 0 : 1); /* active-low */
}

static void c_led_get(mrbc_vm *vm, mrbc_value v[], int argc)
{
  SET_INT_RETURN(gpio_get_level(BOARD_LED_GPIO) == 0 ? 1 : 0); /* active-low */
}

/* ------------------------------------------------------------------ */
/* ADC bindings — ADC1 only (GPIO 0-6 on ESP32-C6)                   */
/* ------------------------------------------------------------------ */

static adc_oneshot_unit_handle_t s_adc1;

static bool adc_channel_for_pin(int pin, adc_channel_t *out)
{
  adc_unit_t unit;
  if (adc_oneshot_io_to_channel(pin, &unit, out) != ESP_OK) return false;
  return unit == ADC_UNIT_1;
}

static void c_adc_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int pin = GET_INT_ARG(1);
  adc_channel_t ch;

  if (!adc_channel_for_pin(pin, &ch)) {
    mrbc_raise(vm, MRBC_CLASS(RuntimeError),
               "ADC requires GPIO 0-6 (ADC1) on ESP32-C6");
    return;
  }
  if (s_adc1 == NULL) {
    adc_oneshot_unit_init_cfg_t cfg = { .unit_id = ADC_UNIT_1 };
    adc_oneshot_new_unit(&cfg, &s_adc1);
  }
  adc_oneshot_chan_cfg_t ccfg = {
    .atten    = ADC_ATTEN_DB_12,   /* full 0-3.3 V range */
    .bitwidth = ADC_BITWIDTH_12,   /* 0-4095, same scale as the Pico */
  };
  adc_oneshot_config_channel(s_adc1, ch, &ccfg);
}

/* _adc_read_pin(pin) → raw 12-bit sample */
static void c_adc_read_pin(mrbc_vm *vm, mrbc_value v[], int argc)
{
  adc_channel_t ch;
  int raw = 0;

  if (s_adc1 == NULL || !adc_channel_for_pin(GET_INT_ARG(1), &ch)) {
    mrbc_raise(vm, MRBC_CLASS(RuntimeError), "ADC not initialized");
    return;
  }
  adc_oneshot_read(s_adc1, ch, &raw);
  SET_INT_RETURN(raw);
}

/* RP2040-only primitives (used by the Temperature class). */
static void c_not_on_esp32(mrbc_vm *vm, mrbc_value v[], int argc)
{
  mrbc_raise(vm, MRBC_CLASS(RuntimeError), "not supported on ESP32-C6");
}

/* ------------------------------------------------------------------ */
/* PWM bindings — LEDC                                                 */
/* ESP32-C6 has 6 LEDC channels (vs 8 on classic ESP32), low-speed   */
/* mode only.  Channels n and n+3 share a timer (4 timers total).     */
/* ------------------------------------------------------------------ */

#define PWM_SLOTS 6

static struct {
  int  pin;
  int  res_bits;
  bool used;
} s_pwm[PWM_SLOTS];

static int pwm_slot(int pin, bool alloc)
{
  for (int i = 0; i < PWM_SLOTS; i++) {
    if (s_pwm[i].used && s_pwm[i].pin == pin) return i;
  }
  if (!alloc) return -1;
  for (int i = 0; i < PWM_SLOTS; i++) {
    if (!s_pwm[i].used) {
      s_pwm[i].used = true;
      s_pwm[i].pin  = pin;
      return i;
    }
  }
  return -1;
}

static void c_pwm_gpio_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  if (pwm_slot(GET_INT_ARG(1), true) < 0) {
    mrbc_raise(vm, MRBC_CLASS(RuntimeError), "too many PWM pins (max 6 on ESP32-C6)");
  }
}

static void c_pwm_set_freq(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int pin  = GET_INT_ARG(1);
  int freq = GET_INT_ARG(2);
  int slot = pwm_slot(pin, false);
  if (slot < 0 || freq <= 0) return;

  /* Maximize duty resolution for the requested frequency.  The source clock is
   * pinned to PLL_F80M (80 MHz) below, so budget the resolution against 80 MHz. */
  int bits = 0;
  while (bits < 16 && ((uint32_t)freq << (bits + 1)) <= 80000000u) bits++;
  if (bits < 1) bits = 1;

  /* On the ESP32-C6 every LEDC low-speed timer shares ONE global clock source.
   * LEDC_AUTO_CLK derives that source from freq+resolution, so two timers (or
   * two `prremote run` invocations, since the firmware keeps LEDC state between
   * runs) that resolve to different clocks make ledc_timer_config() fail with
   * "timer clock conflict"; the timer then keeps its stale resolution while our
   * res_bits says otherwise, so duty_u16= writes a mis-scaled (saturated) value
   * and the LED is stuck on.  Pin every timer to PLL_F80M so the source clock
   * is always identical and no conflict can arise. */
  ledc_timer_config_t tcfg = {
    .speed_mode      = LEDC_LOW_SPEED_MODE,
    .timer_num       = slot % LEDC_TIMER_MAX,
    .duty_resolution = bits,
    .freq_hz         = freq,
    .clk_cfg         = LEDC_USE_PLL_DIV_CLK,
  };
  if (ledc_timer_config(&tcfg) != ESP_OK) {
    mrbc_raise(vm, MRBC_CLASS(RuntimeError), "PWM timer config failed");
    return;
  }
  s_pwm[slot].res_bits = bits;

  ledc_channel_config_t ccfg = {
    .gpio_num   = pin,
    .speed_mode = LEDC_LOW_SPEED_MODE,
    .channel    = slot,
    .timer_sel  = slot % LEDC_TIMER_MAX,
    .duty       = 0,
    .hpoint     = 0,
  };
  ledc_channel_config(&ccfg);
}

static void c_pwm_set_duty_u16(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int pin  = GET_INT_ARG(1);
  int duty = GET_INT_ARG(2);
  int slot = pwm_slot(pin, false);
  if (slot < 0) return;

  /* Scale 0-65535 → 0-(2^bits - 1). */
  uint32_t scaled = ((uint32_t)duty) >> (16 - s_pwm[slot].res_bits);
  ledc_set_duty(LEDC_LOW_SPEED_MODE, slot, scaled);
  ledc_update_duty(LEDC_LOW_SPEED_MODE, slot);
}

/* ------------------------------------------------------------------ */
/* I2C bindings — i2c_master driver                                    */
/* Default pins: SDA=6 (XIAO D4), SCL=7 (XIAO D5).                   */
/* ------------------------------------------------------------------ */

#define I2C_TIMEOUT_MS 500

static i2c_master_bus_handle_t s_i2c_bus[2];
static uint32_t                s_i2c_freq[2];
static i2c_master_dev_handle_t s_i2c_dev[2];
static uint8_t                 s_i2c_dev_addr[2];

static uint8_t s_i2c_pending[2][64];
static int     s_i2c_pending_len[2];
static uint8_t s_i2c_pending_addr[2];

static i2c_master_dev_handle_t i2c_dev(int unit, uint8_t addr)
{
  if (s_i2c_dev[unit] != NULL && s_i2c_dev_addr[unit] == addr) {
    return s_i2c_dev[unit];
  }
  if (s_i2c_dev[unit] != NULL) {
    i2c_master_bus_rm_device(s_i2c_dev[unit]);
    s_i2c_dev[unit] = NULL;
  }
  i2c_device_config_t cfg = {
    .dev_addr_length = I2C_ADDR_BIT_LEN_7,
    .device_address  = addr,
    .scl_speed_hz    = s_i2c_freq[unit],
  };
  if (i2c_master_bus_add_device(s_i2c_bus[unit], &cfg, &s_i2c_dev[unit]) != ESP_OK) {
    return NULL;
  }
  s_i2c_dev_addr[unit] = addr;
  return s_i2c_dev[unit];
}

static void c_i2c_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int      unit_num = GET_INT_ARG(1) ? 1 : 0;
  uint32_t freq     = (uint32_t)GET_INT_ARG(2);
  int      sda      = GET_INT_ARG(3);
  int      scl      = GET_INT_ARG(4);

  /* XIAO ESP32C6 I2C pins: D4=GPIO6 (SDA), D5=GPIO7 (SCL). */
  if (sda < 0) sda = 6;
  if (scl < 0) scl = 7;

  esp_log_level_set("i2c.master", ESP_LOG_NONE);

  if (s_i2c_dev[unit_num] != NULL) {
    i2c_master_bus_rm_device(s_i2c_dev[unit_num]);
    s_i2c_dev[unit_num] = NULL;
  }
  if (s_i2c_bus[unit_num] != NULL) {
    i2c_del_master_bus(s_i2c_bus[unit_num]);
    s_i2c_bus[unit_num] = NULL;
  }

  i2c_master_bus_config_t cfg = {
    .i2c_port          = unit_num,
    .sda_io_num        = sda,
    .scl_io_num        = scl,
    .clk_source        = I2C_CLK_SRC_DEFAULT,
    .glitch_ignore_cnt = 7,
    .flags.enable_internal_pullup = true,
  };
  if (i2c_new_master_bus(&cfg, &s_i2c_bus[unit_num]) != ESP_OK) {
    mrbc_raise(vm, MRBC_CLASS(RuntimeError), "i2c init failed");
    return;
  }
  s_i2c_freq[unit_num]        = freq;
  s_i2c_pending_len[unit_num] = 0;
  SET_INT_RETURN(unit_num);
}

/* _i2c_write(unit_num, addr, data_array, nostop_int) */
static void c_i2c_write(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int     unit_num = GET_INT_ARG(1) ? 1 : 0;
  uint8_t addr     = (uint8_t)GET_INT_ARG(2);
  bool    nostop   = GET_INT_ARG(4) != 0;

  uint8_t buf[64];
  int n = 0;
  if (v[3].tt == MRBC_TT_ARRAY) {
    mrbc_array *ary = v[3].array;
    n = ary->n_stored < 64 ? (int)ary->n_stored : 64;
    for (int i = 0; i < n; i++) buf[i] = (uint8_t)mrbc_integer(ary->data[i]);
  }

  if (nostop) {
    memcpy(s_i2c_pending[unit_num], buf, n);
    s_i2c_pending_len[unit_num]  = n;
    s_i2c_pending_addr[unit_num] = addr;
    SET_INT_RETURN(n);
    return;
  }

  i2c_master_dev_handle_t dev = i2c_dev(unit_num, addr);
  if (dev == NULL ||
      i2c_master_transmit(dev, buf, n, I2C_TIMEOUT_MS) != ESP_OK) {
    SET_INT_RETURN(-1);
    return;
  }
  SET_INT_RETURN(n);
}

/* _i2c_read(unit_num, addr, len) → String or nil */
static void c_i2c_read(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int     unit_num = GET_INT_ARG(1) ? 1 : 0;
  uint8_t addr     = (uint8_t)GET_INT_ARG(2);
  int     len      = GET_INT_ARG(3);
  if (len > 256) len = 256;

  uint8_t buf[256];
  esp_err_t err;
  i2c_master_dev_handle_t dev = i2c_dev(unit_num, addr);
  if (dev == NULL) { SET_NIL_RETURN(); return; }

  if (s_i2c_pending_len[unit_num] > 0 && s_i2c_pending_addr[unit_num] == addr) {
    err = i2c_master_transmit_receive(dev,
                                      s_i2c_pending[unit_num],
                                      s_i2c_pending_len[unit_num],
                                      buf, len, I2C_TIMEOUT_MS);
    s_i2c_pending_len[unit_num] = 0;
  } else {
    err = i2c_master_receive(dev, buf, len, I2C_TIMEOUT_MS);
  }

  if (err != ESP_OK) { SET_NIL_RETURN(); return; }
  mrbc_value s = mrbc_string_new(vm, buf, len);
  SET_RETURN(s);
}

/* ------------------------------------------------------------------ */
/* SPI bindings — spi_master driver                                    */
/* ESP32-C6 only has SPI2_HOST; unit 1 (SPI3_HOST) is not available. */
/* Default XIAO pins: SCK=19 (D8), MOSI=18 (D10). CS via GPIO.       */
/* ------------------------------------------------------------------ */

static spi_device_handle_t s_spi_dev[2];

static void c_spi_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int unit_num = GET_INT_ARG(1) ? 1 : 0;
  int freq     = GET_INT_ARG(2);
  int sck      = GET_INT_ARG(3);
  int cipo     = GET_INT_ARG(4);
  int copi     = GET_INT_ARG(5);
  int mode     = GET_INT_ARG(6);

  if (unit_num != 0) {
    mrbc_raise(vm, MRBC_CLASS(RuntimeError),
               "SPI unit 1 (SPI3_HOST) does not exist on ESP32-C6; use unit 0");
    return;
  }

  /* XIAO ESP32C6 SPI pins: D8=GPIO19 (SCK), D10=GPIO18 (MOSI). */
  if (sck  < 0) sck  = 19;
  if (copi < 0) copi = 18;

  if (s_spi_dev[unit_num] != NULL) {
    spi_bus_remove_device(s_spi_dev[unit_num]);
    spi_bus_free(SPI2_HOST);
    s_spi_dev[unit_num] = NULL;
  }

  spi_bus_config_t bus = {
    .sclk_io_num   = sck,
    .mosi_io_num   = copi,
    .miso_io_num   = cipo,   /* -1 = unused */
    .quadwp_io_num = -1,
    .quadhd_io_num = -1,
  };
  if (spi_bus_initialize(SPI2_HOST, &bus, SPI_DMA_CH_AUTO) != ESP_OK) {
    mrbc_raise(vm, MRBC_CLASS(RuntimeError), "spi init failed");
    return;
  }

  spi_device_interface_config_t dev = {
    .clock_speed_hz = freq,
    .mode           = mode & 0x03,
    .spics_io_num   = -1,
    .queue_size     = 1,
  };
  if (spi_bus_add_device(SPI2_HOST, &dev, &s_spi_dev[unit_num]) != ESP_OK) {
    spi_bus_free(SPI2_HOST);
    mrbc_raise(vm, MRBC_CLASS(RuntimeError), "spi init failed");
    return;
  }
  SET_INT_RETURN(unit_num);
}

static int spi_xfer(int unit_num, const uint8_t *tx, uint8_t *rx, int n)
{
  spi_transaction_t t = {
    .length    = (size_t)n * 8,
    .tx_buffer = tx,
    .rx_buffer = rx,
  };
  if (s_spi_dev[unit_num] == NULL) return -1;
  return spi_device_polling_transmit(s_spi_dev[unit_num], &t) == ESP_OK ? n : -1;
}

/* _spi_write(unit_num, data_array) → bytes written */
static void c_spi_write(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int unit_num = GET_INT_ARG(1) ? 1 : 0;

  uint8_t buf[64];
  int n = 0;
  if (v[2].tt == MRBC_TT_ARRAY) {
    mrbc_array *ary = v[2].array;
    n = ary->n_stored < 64 ? (int)ary->n_stored : 64;
    for (int i = 0; i < n; i++) buf[i] = (uint8_t)mrbc_integer(ary->data[i]);
  }
  SET_INT_RETURN(spi_xfer(unit_num, buf, NULL, n));
}

/* _spi_read(unit_num, len, repeated_tx_byte) → String or nil */
static void c_spi_read(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int     unit_num    = GET_INT_ARG(1) ? 1 : 0;
  int     len         = GET_INT_ARG(2);
  uint8_t repeated_tx = (uint8_t)GET_INT_ARG(3);
  if (len > 256) len = 256;

  uint8_t tx[256], rx[256];
  memset(tx, repeated_tx, len);
  if (spi_xfer(unit_num, tx, rx, len) < 0) { SET_NIL_RETURN(); return; }
  mrbc_value s = mrbc_string_new(vm, rx, len);
  SET_RETURN(s);
}

/* _spi_transfer(unit_num, data_array) → String or nil */
static void c_spi_transfer(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int unit_num = GET_INT_ARG(1) ? 1 : 0;

  uint8_t tx[64], rx[64];
  int n = 0;
  if (v[2].tt == MRBC_TT_ARRAY) {
    mrbc_array *ary = v[2].array;
    n = ary->n_stored < 64 ? (int)ary->n_stored : 64;
    for (int i = 0; i < n; i++) tx[i] = (uint8_t)mrbc_integer(ary->data[i]);
  }
  if (spi_xfer(unit_num, tx, rx, n) < 0) { SET_NIL_RETURN(); return; }
  mrbc_value s = mrbc_string_new(vm, rx, n);
  SET_RETURN(s);
}

/* ------------------------------------------------------------------ */
/* Register all methods — called after every mrbc_init()              */
/* ------------------------------------------------------------------ */

#ifdef HAS_WIFI
void register_wifi_methods(void);
#endif
#ifdef HAS_LCD
void register_lcd_methods(void);
#endif
#ifdef HAS_SOCKET
void mrbc_socket_init(mrbc_vm *vm);
#endif

void runtime_define_methods(void)
{
  mrbc_define_method(0, mrbc_class_object, "sleep",           c_sleep);
  mrbc_define_method(0, mrbc_class_object, "uptime_ms",       c_uptime_ms);
  mrbc_define_method(0, mrbc_class_object, "exit",             c_exit);
  mrbc_define_method(0, mrbc_class_object, "_gpio_init",      c_gpio_init);
  mrbc_define_method(0, mrbc_class_object, "_gpio_set_dir",   c_gpio_set_dir);
  mrbc_define_method(0, mrbc_class_object, "_gpio_pull_up",   c_gpio_pull_up);
  mrbc_define_method(0, mrbc_class_object, "_gpio_pull_down", c_gpio_pull_down);
  mrbc_define_method(0, mrbc_class_object, "_gpio_put",       c_gpio_put);
  mrbc_define_method(0, mrbc_class_object, "_gpio_get",       c_gpio_get);
  mrbc_define_method(0, mrbc_class_object, "_led_init",        c_led_init);
  mrbc_define_method(0, mrbc_class_object, "_led_put",         c_led_put);
  mrbc_define_method(0, mrbc_class_object, "_led_get",         c_led_get);
  mrbc_define_method(0, mrbc_class_object, "_adc_init",         c_adc_init);
  mrbc_define_method(0, mrbc_class_object, "_adc_read_pin",     c_adc_read_pin);
  mrbc_define_method(0, mrbc_class_object, "_adc_select_input", c_not_on_esp32);
  mrbc_define_method(0, mrbc_class_object, "_adc_read",         c_not_on_esp32);
  mrbc_define_method(0, mrbc_class_object, "_adc_temp_enable",  c_not_on_esp32);
  mrbc_define_method(0, mrbc_class_object, "_pwm_gpio_init",    c_pwm_gpio_init);
  mrbc_define_method(0, mrbc_class_object, "_pwm_set_freq",     c_pwm_set_freq);
  mrbc_define_method(0, mrbc_class_object, "_pwm_set_duty_u16", c_pwm_set_duty_u16);
  mrbc_define_method(0, mrbc_class_object, "_i2c_init",         c_i2c_init);
  mrbc_define_method(0, mrbc_class_object, "_i2c_write",        c_i2c_write);
  mrbc_define_method(0, mrbc_class_object, "_i2c_read",         c_i2c_read);
  mrbc_define_method(0, mrbc_class_object, "_spi_init",         c_spi_init);
  mrbc_define_method(0, mrbc_class_object, "_spi_write",        c_spi_write);
  mrbc_define_method(0, mrbc_class_object, "_spi_read",         c_spi_read);
  mrbc_define_method(0, mrbc_class_object, "_spi_transfer",     c_spi_transfer);
#ifdef HAS_WIFI
  register_wifi_methods();
#endif
#ifdef HAS_LCD
  register_lcd_methods();
#endif
#ifdef HAS_SOCKET
  mrbc_socket_init(0);
#endif
}
