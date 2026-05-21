#ifndef PRREMOTE_PICORUBY_COMPAT_H
#define PRREMOTE_PICORUBY_COMPAT_H

/*
 * Thin adapter so picoruby-socket C sources compile against the plain mruby/c
 * submodule in this project without requiring picoruby.h / picoruby/debug.h.
 * Included automatically via -include compiler flag for all translation units.
 */

/* Tells socket.h to take the mrubyc branch for picorb_state / socket_wrapper_t */
#ifndef PICORB_VM_MRUBYC
#define PICORB_VM_MRUBYC
#endif

#include <mrubyc.h>

#define picorb_alloc  mrbc_alloc

static inline void _prremote_picorb_free(mrbc_vm *vm, void *ptr) {
  if (ptr) mrbc_free(vm, ptr);
}
#define picorb_free _prremote_picorb_free

/* Silence picoruby/debug.h D() macro (no debug output in this build) */
#ifndef D
#define D(...)
#endif

#endif /* PRREMOTE_PICORUBY_COMPAT_H */
