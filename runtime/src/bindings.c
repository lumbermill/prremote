#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "hardware/adc.h"
#include "hardware/pwm.h"
#include "hardware/clocks.h"
#include <mrubyc.h>

#ifdef HAS_CYW43
void register_cyw43_methods(void);
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
/* Register all methods — called after every mrbc_init()              */
/* ------------------------------------------------------------------ */

void runtime_define_methods(void)
{
  mrbc_define_method(0, mrbc_class_object, "sleep",           c_sleep);
  mrbc_define_method(0, mrbc_class_object, "_gpio_init",      c_gpio_init);
  mrbc_define_method(0, mrbc_class_object, "_gpio_set_dir",   c_gpio_set_dir);
  mrbc_define_method(0, mrbc_class_object, "_gpio_pull_up",   c_gpio_pull_up);
  mrbc_define_method(0, mrbc_class_object, "_gpio_pull_down", c_gpio_pull_down);
  mrbc_define_method(0, mrbc_class_object, "_gpio_put",       c_gpio_put);
  mrbc_define_method(0, mrbc_class_object, "_gpio_get",       c_gpio_get);
  mrbc_define_method(0, mrbc_class_object, "_adc_init",         c_adc_init);
  mrbc_define_method(0, mrbc_class_object, "_adc_select_input", c_adc_select_input);
  mrbc_define_method(0, mrbc_class_object, "_adc_read",         c_adc_read);
  mrbc_define_method(0, mrbc_class_object, "_pwm_gpio_init",    c_pwm_gpio_init);
  mrbc_define_method(0, mrbc_class_object, "_pwm_set_freq",     c_pwm_set_freq);
  mrbc_define_method(0, mrbc_class_object, "_pwm_set_duty_u16", c_pwm_set_duty_u16);
#ifdef HAS_CYW43
  register_cyw43_methods();
#endif
}
