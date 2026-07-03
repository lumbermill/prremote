/*
 * Socket class hierarchy initialization for the prremote runtime.
 *
 * The Ruby bytecode (socket_wrap.h) is compiled directly from picoruby-socket:
 *   mrbgems/picoruby-socket/mrblib/basic_socket.rb
 *   mrbgems/picoruby-socket/mrblib/tcp_socket.rb
 *
 * The C layer uses the picoruby-socket port sources unchanged:
 *   mrbgems/picoruby-socket/ports/rp2040/tcp_socket.c  (lwip implementation)
 * The TCP/UDP VM bindings are vendored copies with refcount fixes:
 *   runtime/src/tcp_socket_binding.c / udp_socket_binding.c
 *
 * This file provides only the glue: mrbc_socket_init() is a trimmed copy of
 * picoruby-socket/src/mrubyc/socket.c — SSL/TCPServer stubs removed because
 * those gems are not included in this build. UDPSocket is wired in only when
 * HAS_UDP_SOCKET is defined (esp32c6 build); picow stays TCP-only.
 * picoruby_compat.h bridges the picorb_alloc / picorb_free symbols that those
 * sources expect from picoruby.h to the plain mruby/c API.
 */

#include "picoruby_compat.h"
/* Explicit path: a bare "socket.h" resolves to lwIP's sys/socket.h on ESP-IDF
 * (earlier on the include path) instead of picoruby-socket's. See picoruby.h. */
#include "../picoruby/mrbgems/picoruby-socket/include/socket.h"

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
 * Initialize the socket class hierarchy.
 * TCPSocket is always defined; UDPSocket is added on builds that pull in the
 * UDP port (HAS_UDP_SOCKET). Add ssl_socket_init / tcp_server_init here as
 * additional picoruby gems are integrated.
 */
void mrbc_socket_init(mrbc_vm *vm)
{
  mrbc_class *class_BasicSocket = mrbc_define_class(vm, "BasicSocket", mrbc_class_object);
  tcp_socket_init(vm, class_BasicSocket);
#ifdef HAS_UDP_SOCKET
  udp_socket_init(vm, class_BasicSocket);
#endif
}
