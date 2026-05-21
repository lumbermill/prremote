/*
 * Stub picoruby.h for prremote builds.
 * picoruby_compat.h is pre-injected via the -include compiler flag and handles
 * picorb_alloc, picorb_free, PICORB_VM_MRUBYC, and D().
 * This stub also includes socket.h so that picoruby-socket source files that
 * rely on picoruby.h for picorb_socket_t / socket_wrapper_t types still compile.
 */
#ifndef PICORUBY_H
#define PICORUBY_H
#include "socket.h"
#endif /* PICORUBY_H */
