/*
 * Stub picoruby.h for prremote builds.
 * picoruby_compat.h is pre-injected via the -include compiler flag and handles
 * picorb_alloc, picorb_free, PICORB_VM_MRUBYC, and D().
 * This stub also includes socket.h so that picoruby-socket source files that
 * rely on picoruby.h for picorb_socket_t / socket_wrapper_t types still compile.
 */
#ifndef PICORUBY_H
#define PICORUBY_H
/* Reach picoruby-socket's socket.h by explicit path rather than relying on an
 * -I search: on ESP-IDF a bare "socket.h" would resolve to lwIP's
 * port/esp32xx/include/sys/socket.h (earlier on the include path) instead. */
#include "../picoruby/mrbgems/picoruby-socket/include/socket.h"
#endif /* PICORUBY_H */
