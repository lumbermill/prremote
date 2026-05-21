/*
 * Socket class hierarchy initialization for the prremote runtime.
 *
 * The Ruby bytecode (socket_wrap.h) is compiled directly from picoruby-socket:
 *   mrbgems/picoruby-socket/mrblib/basic_socket.rb
 *   mrbgems/picoruby-socket/mrblib/tcp_socket.rb
 *
 * The C layer also uses picoruby-socket sources unchanged:
 *   mrbgems/picoruby-socket/src/mrubyc/tcp_socket.c   (VM bindings)
 *   mrbgems/picoruby-socket/ports/rp2040/tcp_socket.c  (lwip implementation)
 *
 * This file provides only the glue: mrbc_socket_init() is a trimmed copy of
 * picoruby-socket/src/mrubyc/socket.c — UDP/SSL/TCPServer stubs removed
 * because those gems are not included in this build.
 * picoruby_compat.h bridges the picorb_alloc / picorb_free symbols that those
 * sources expect from picoruby.h to the plain mruby/c API.
 */

#include "picoruby_compat.h"
#include "socket.h"

/* Destructor called when a TCPSocket instance is GC'd or goes out of scope. */
void mrbc_socket_free(mrbc_value *self)
{
  socket_wrapper_t *wrapper = (socket_wrapper_t *)self->instance->data;
  if (!wrapper) return;
  picorb_socket_t *sock = wrapper->ptr;
  if (!sock) return;
  if (!sock->closed) {
    TCPSocket_close(wrapper->vm, sock);
  }
  picorb_free(wrapper->vm, sock);
}

/*
 * Initialize only the TCP socket class hierarchy.
 * Add udp_socket_init / ssl_socket_init / tcp_server_init here
 * as additional picoruby gems are integrated.
 */
void mrbc_socket_init(mrbc_vm *vm)
{
  mrbc_class *class_BasicSocket = mrbc_define_class(vm, "BasicSocket", mrbc_class_object);
  tcp_socket_init(vm, class_BasicSocket);
}
