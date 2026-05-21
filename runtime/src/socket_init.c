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
