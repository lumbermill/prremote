/*
 * Project-local net_helpers.c — replaces picoruby's ports/rp2040/net_helpers.c.
 * Extends Net_get_ip() to route .local hostnames through the mDNS resolver.
 */

#include <string.h>
#include "mdns_resolver.h"
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "lwip/dns.h"
#include "lwip/err.h"
#include "lwip/ip_addr.h"

void
Net_busy_wait_ms(int ms)
{
  cyw43_arch_poll();
  busy_wait_ms(ms);
  cyw43_arch_poll();
}

void
lwip_begin(void)
{
  cyw43_arch_lwip_begin();
}

void
lwip_end(void)
{
  cyw43_arch_lwip_end();
}

static void
dns_callback(const char *name, const ip_addr_t *ip, void *arg)
{
  (void)name;
  ip_addr_t *result = (ip_addr_t *)arg;
  if (ip) ip_addr_copy(*result, *ip);
  else    ip_addr_set_zero(result);
}

int
Net_get_ip(const char *name, void *ip)
{
  if (!name || !ip) return -1;

  ip_addr_t *addr = (ip_addr_t *)ip;
  ip_addr_set_zero(addr);

  if (ip4addr_aton(name, addr)) return 0;

  /* Route .local hostnames through mDNS (standard DNS cannot resolve them) */
  size_t len = strlen(name);
  if (len > 6 && strcmp(name + len - 6, ".local") == 0) {
    return mdns_resolve(name, addr);
  }

  cyw43_arch_lwip_begin();
  err_t err = dns_gethostbyname(name, addr, dns_callback, addr);
  cyw43_arch_lwip_end();

  if (err == ERR_OK) return 0;

  if (err == ERR_INPROGRESS) {
    int max_wait = 100;  /* 10 seconds */
    while (ip_addr_isany(addr) && max_wait-- > 0) {
      Net_busy_wait_ms(100);
    }
    if (!ip_addr_isany(addr)) return 0;
  }

  return -1;
}
