#include "pico/stdlib.h"
#include "hardware/gpio.h"
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
#ifdef HAS_CYW43
  register_cyw43_methods();
#endif
}
