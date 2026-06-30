#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "hardware/adc.h"
#include "hardware/pwm.h"
#include "hardware/clocks.h"
#include "hardware/i2c.h"
#include "hardware/spi.h"
#include <mrubyc.h>

#ifdef HAS_WIFI
#include "pico/cyw43_arch.h"
void register_cyw43_methods(void);
bool prr_cyw43_ensure_arch_init(void);
#endif
#ifdef HAS_SOCKET
void mrbc_socket_init(mrbc_vm *vm);
#endif

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
  sleep_ms(ms);
}

/* ------------------------------------------------------------------ */
/* uptime_ms — milliseconds since boot (wraps ~49 days)               */
/* ------------------------------------------------------------------ */

static void c_uptime_ms(mrbc_vm *vm, mrbc_value v[], int argc)
{
  SET_INT_RETURN((mrbc_int_t)(time_us_64() / 1000));
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
/* Onboard LED — board differences are absorbed here (see GPIO.led).   */
/* Pico W / Pico 2 W: the LED hangs off the CYW43 wireless chip's      */
/* GPIO0, so the chip must be powered up first (no network connection  */
/* is made). Pico / Pico 2: PICO_DEFAULT_LED_PIN.                      */
/* ------------------------------------------------------------------ */

static void c_led_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
#ifdef HAS_WIFI
  if (!prr_cyw43_ensure_arch_init()) {
    mrbc_raise(vm, MRBC_CLASS(RuntimeError), "CYW43 init failed");
  }
#elif defined(PICO_DEFAULT_LED_PIN)
  gpio_init(PICO_DEFAULT_LED_PIN);
  gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
#else
  mrbc_raise(vm, MRBC_CLASS(RuntimeError), "no onboard LED on this board");
#endif
}

static void c_led_put(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int val = GET_INT_ARG(1);
#ifdef HAS_WIFI
  cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, val);
#elif defined(PICO_DEFAULT_LED_PIN)
  gpio_put(PICO_DEFAULT_LED_PIN, val);
#else
  (void)val;
  mrbc_raise(vm, MRBC_CLASS(RuntimeError), "no onboard LED on this board");
#endif
}

static void c_led_get(mrbc_vm *vm, mrbc_value v[], int argc)
{
#ifdef HAS_WIFI
  SET_INT_RETURN(cyw43_arch_gpio_get(CYW43_WL_GPIO_LED_PIN) ? 1 : 0);
#elif defined(PICO_DEFAULT_LED_PIN)
  SET_INT_RETURN(gpio_get(PICO_DEFAULT_LED_PIN) ? 1 : 0);
#else
  mrbc_raise(vm, MRBC_CLASS(RuntimeError), "no onboard LED on this board");
#endif
}

/* ------------------------------------------------------------------ */
/* ADC bindings                                                        */
/* ------------------------------------------------------------------ */

static bool s_adc_initialized = false;

static void c_adc_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  if (!s_adc_initialized) {
    adc_init();
    s_adc_initialized = true;
  }
  adc_gpio_init(GET_INT_ARG(1));
}

static void c_adc_select_input(mrbc_vm *vm, mrbc_value v[], int argc)
{
  adc_select_input(GET_INT_ARG(1));
}

static void c_adc_read(mrbc_vm *vm, mrbc_value v[], int argc)
{
  SET_INT_RETURN((int)adc_read());
}

/* _adc_read_pin(pin) → raw 12-bit sample. The pin→channel mapping lives in
 * the C layer so hw_wrap.rb stays platform-neutral (GPIO26 = channel 0). */
static void c_adc_read_pin(mrbc_vm *vm, mrbc_value v[], int argc)
{
  adc_select_input(GET_INT_ARG(1) - 26);
  SET_INT_RETURN((int)adc_read());
}

/* Enable the on-chip temperature sensor (ADC channel 4).
 * RP2040 datasheet §4.9.5: T(°C) = 27 - (Vbe - 0.706) / 0.001721
 * where Vbe = raw * 3.3 / 4096. */
static void c_adc_temp_enable(mrbc_vm *vm, mrbc_value v[], int argc)
{
  if (!s_adc_initialized) {
    adc_init();
    s_adc_initialized = true;
  }
  adc_set_temp_sensor_enabled(true);
}

/* ------------------------------------------------------------------ */
/* PWM bindings                                                        */
/* ------------------------------------------------------------------ */

/* Per-slice wrap value, needed to scale duty_u16 correctly. */
static uint32_t s_pwm_wrap[8] = {0};

static void c_pwm_gpio_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  gpio_set_function(GET_INT_ARG(1), GPIO_FUNC_PWM);
}

static void c_pwm_set_freq(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int pin  = GET_INT_ARG(1);
  int freq = GET_INT_ARG(2);
  uint slice = pwm_gpio_to_slice_num(pin);
  uint32_t sys = clock_get_hz(clk_sys);

  /* Maximize wrap (resolution) while keeping divider in [1, 255]. */
  uint32_t wrap_p1 = sys / freq;
  float    div     = 1.0f;
  if (wrap_p1 > 65536) {
    div      = (float)wrap_p1 / 65536.0f;
    wrap_p1  = 65536;
  } else if (wrap_p1 < 2) {
    wrap_p1 = 2;
  }

  uint32_t wrap = wrap_p1 - 1;
  s_pwm_wrap[slice] = wrap;
  pwm_set_clkdiv(slice, div);
  pwm_set_wrap(slice, wrap);
  pwm_set_enabled(slice, true);
}

static void c_pwm_set_duty_u16(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int pin  = GET_INT_ARG(1);
  int duty = GET_INT_ARG(2);
  uint slice   = pwm_gpio_to_slice_num(pin);
  uint channel = pwm_gpio_to_channel(pin);
  uint32_t wrap = s_pwm_wrap[slice];
  /* Scale 0-65535 → 0-wrap. */
  uint16_t level = (uint16_t)(((uint32_t)duty * (wrap + 1)) >> 16);
  pwm_set_chan_level(slice, channel, level);
}

/* ------------------------------------------------------------------ */
/* I2C bindings                                                        */
/* ------------------------------------------------------------------ */

static i2c_inst_t *i2c_unit(int n) { return n == 0 ? i2c0 : i2c1; }

static void c_i2c_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int      unit_num = GET_INT_ARG(1);
  uint32_t freq     = (uint32_t)GET_INT_ARG(2);
  int      sda      = GET_INT_ARG(3);
  int      scl      = GET_INT_ARG(4);

  i2c_init(i2c_unit(unit_num), freq);
  if (sda < 0) sda = PICO_DEFAULT_I2C_SDA_PIN;
  if (scl < 0) scl = PICO_DEFAULT_I2C_SCL_PIN;
  gpio_set_function(sda, GPIO_FUNC_I2C);
  gpio_set_function(scl, GPIO_FUNC_I2C);
  gpio_pull_up(sda);
  gpio_pull_up(scl);
  SET_INT_RETURN(unit_num);
}

/* _i2c_write(unit_num, addr, data_array, nostop_int) */
static void c_i2c_write(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int     unit_num = GET_INT_ARG(1);
  uint8_t addr     = (uint8_t)GET_INT_ARG(2);
  bool    nostop   = GET_INT_ARG(4) != 0;

  uint8_t buf[64];
  int n = 0;
  if (v[3].tt == MRBC_TT_ARRAY) {
    mrbc_array *ary = v[3].array;
    n = ary->n_stored < 64 ? (int)ary->n_stored : 64;
    for (int i = 0; i < n; i++) buf[i] = (uint8_t)mrbc_integer(ary->data[i]);
  }

  int ret = i2c_write_timeout_us(i2c_unit(unit_num), addr, buf, n, nostop, 500000);
  SET_INT_RETURN(ret);
}

/* _i2c_read(unit_num, addr, len) → String or nil */
static void c_i2c_read(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int     unit_num = GET_INT_ARG(1);
  uint8_t addr     = (uint8_t)GET_INT_ARG(2);
  int     len      = GET_INT_ARG(3);
  if (len > 256) len = 256;

  uint8_t buf[256];
  int ret = i2c_read_timeout_us(i2c_unit(unit_num), addr, buf, len, false, 500000);
  if (ret <= 0) { SET_NIL_RETURN(); return; }
  mrbc_value s = mrbc_string_new(vm, buf, ret);
  SET_RETURN(s);
}

/* ------------------------------------------------------------------ */
/* SPI bindings                                                        */
/* ------------------------------------------------------------------ */

static spi_inst_t *spi_unit(int n) { return n == 0 ? spi0 : spi1; }

/* _spi_init(unit_num, freq, sck, cipo, copi, mode) → unit_num */
static void c_spi_init(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int      unit_num = GET_INT_ARG(1);
  uint32_t freq     = (uint32_t)GET_INT_ARG(2);
  int      sck      = GET_INT_ARG(3);
  int      cipo     = GET_INT_ARG(4);
  int      copi     = GET_INT_ARG(5);
  int      mode     = GET_INT_ARG(6);

  spi_inst_t *unit = spi_unit(unit_num);
  spi_init(unit, freq);
  spi_set_format(unit, 8,
                 (mode & 0x02) ? SPI_CPOL_1 : SPI_CPOL_0,
                 (mode & 0x01) ? SPI_CPHA_1 : SPI_CPHA_0,
                 SPI_MSB_FIRST);

  if (sck  < 0) sck  = PICO_DEFAULT_SPI_SCK_PIN;
  if (copi < 0) copi = PICO_DEFAULT_SPI_TX_PIN;
  gpio_set_function(sck,  GPIO_FUNC_SPI);
  gpio_set_function(copi, GPIO_FUNC_SPI);
  if (cipo >= 0) gpio_set_function(cipo, GPIO_FUNC_SPI);

  SET_INT_RETURN(unit_num);
}

/* _spi_write(unit_num, data_array) → bytes written */
static void c_spi_write(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int unit_num = GET_INT_ARG(1);

  uint8_t buf[64];
  int n = 0;
  if (v[2].tt == MRBC_TT_ARRAY) {
    mrbc_array *ary = v[2].array;
    n = ary->n_stored < 64 ? (int)ary->n_stored : 64;
    for (int i = 0; i < n; i++) buf[i] = (uint8_t)mrbc_integer(ary->data[i]);
  }
  int ret = spi_write_blocking(spi_unit(unit_num), buf, n);
  SET_INT_RETURN(ret);
}

/* _spi_read(unit_num, len, repeated_tx_byte) → String or nil */
static void c_spi_read(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int     unit_num    = GET_INT_ARG(1);
  int     len         = GET_INT_ARG(2);
  uint8_t repeated_tx = (uint8_t)GET_INT_ARG(3);
  if (len > 256) len = 256;

  uint8_t buf[256];
  int ret = spi_read_blocking(spi_unit(unit_num), repeated_tx, buf, len);
  if (ret <= 0) { SET_NIL_RETURN(); return; }
  mrbc_value s = mrbc_string_new(vm, buf, ret);
  SET_RETURN(s);
}

/* _spi_transfer(unit_num, data_array) → String or nil */
static void c_spi_transfer(mrbc_vm *vm, mrbc_value v[], int argc)
{
  int unit_num = GET_INT_ARG(1);
  uint8_t tx[64], rx[64];
  int n = 0;
  if (v[2].tt == MRBC_TT_ARRAY) {
    mrbc_array *ary = v[2].array;
    n = ary->n_stored < 64 ? (int)ary->n_stored : 64;
    for (int i = 0; i < n; i++) tx[i] = (uint8_t)mrbc_integer(ary->data[i]);
  }
  int ret = spi_write_read_blocking(spi_unit(unit_num), tx, rx, n);
  if (ret <= 0) { SET_NIL_RETURN(); return; }
  mrbc_value s = mrbc_string_new(vm, rx, ret);
  SET_RETURN(s);
}

/* ------------------------------------------------------------------ */
/* Register all methods — called after every mrbc_init()              */
/* ------------------------------------------------------------------ */

void runtime_define_methods(void)
{
  mrbc_define_method(0, mrbc_class_object, "sleep",           c_sleep);
  mrbc_define_method(0, mrbc_class_object, "uptime_ms",      c_uptime_ms);
  mrbc_define_method(0, mrbc_class_object, "exit",            c_exit);
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
  mrbc_define_method(0, mrbc_class_object, "_adc_select_input", c_adc_select_input);
  mrbc_define_method(0, mrbc_class_object, "_adc_read",         c_adc_read);
  mrbc_define_method(0, mrbc_class_object, "_adc_read_pin",     c_adc_read_pin);
  mrbc_define_method(0, mrbc_class_object, "_adc_temp_enable",  c_adc_temp_enable);
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
  register_cyw43_methods();
#endif
#ifdef HAS_SOCKET
  mrbc_socket_init(0);
#endif
}
