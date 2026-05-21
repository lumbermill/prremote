#ifndef MDNS_RESOLVER_H
#define MDNS_RESOLVER_H
#include "lwip/ip_addr.h"
/* Returns 0 and fills *out on success; returns -1 on failure or timeout (3 s). */
int mdns_resolve(const char *hostname, ip_addr_t *out);
#endif /* MDNS_RESOLVER_H */
