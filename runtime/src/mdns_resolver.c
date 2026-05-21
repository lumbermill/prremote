/*
 * Simple mDNS (.local) resolver using LwIP raw UDP API.
 * Sends a QU (unicast-preferred) DNS query to 224.0.0.251:5353 and waits
 * up to MDNS_TIMEOUT_MS for a response containing an A record.
 *
 * Requires: LWIP_UDP=1, LWIP_IGMP=1 in lwipopts.h
 */

#include <string.h>
#include <stdint.h>
#include "mdns_resolver.h"
#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include "pico/time.h"
#include "lwip/udp.h"
#include "lwip/igmp.h"
#include "lwip/netif.h"
#include "lwip/pbuf.h"
#include "lwip/err.h"

#define MDNS_PORT        5353
#define MDNS_GROUP_ADDR  "224.0.0.251"
#define MDNS_TIMEOUT_MS  3000

typedef struct {
  ip_addr_t result;
  int       done;
} mdns_query_t;

/* Encode hostname into DNS wire-format labels; returns bytes written, -1 on overflow. */
static int encode_dns_name(const char *hostname, uint8_t *buf, int buf_len)
{
  int pos = 0;
  const char *p = hostname;
  while (*p) {
    const char *dot = strchr(p, '.');
    int llen = dot ? (int)(dot - p) : (int)strlen(p);
    if (pos + 1 + llen >= buf_len) return -1;
    buf[pos++] = (uint8_t)llen;
    memcpy(buf + pos, p, llen);
    pos += llen;
    if (!dot) break;
    p = dot + 1;
  }
  if (pos >= buf_len) return -1;
  buf[pos++] = 0;  /* root label */
  return pos;
}

/* Advance past a DNS name (labels or pointer); returns new position, -1 on error. */
static int skip_dns_name(const uint8_t *buf, int len, int pos)
{
  while (pos < len) {
    if ((buf[pos] & 0xC0) == 0xC0) return pos + 2;  /* compression pointer */
    if (buf[pos] == 0)              return pos + 1;  /* root label */
    pos += buf[pos] + 1;
  }
  return -1;
}

static void mdns_recv(void *arg, struct udp_pcb *pcb,
                      struct pbuf *p, const ip_addr_t *addr, u16_t port)
{
  (void)pcb; (void)addr; (void)port;
  mdns_query_t *q = (mdns_query_t *)arg;

  if (!p) return;
  if (q->done) { pbuf_free(p); return; }

  uint8_t buf[512];
  u16_t len = p->tot_len < sizeof(buf) ? p->tot_len : (u16_t)sizeof(buf);
  pbuf_copy_partial(p, buf, len, 0);
  pbuf_free(p);

  if (len < 12) return;
  uint16_t flags   = (uint16_t)((buf[2] << 8) | buf[3]);
  if (!(flags & 0x8000)) return;  /* not a response */
  uint16_t qdcount = (uint16_t)((buf[4] << 8) | buf[5]);
  uint16_t ancount = (uint16_t)((buf[6] << 8) | buf[7]);
  if (ancount == 0) return;

  int pos = 12;
  for (int i = 0; i < qdcount; i++) {
    pos = skip_dns_name(buf, len, pos);
    if (pos < 0 || pos + 4 > len) return;
    pos += 4;  /* type + class */
  }
  for (int i = 0; i < ancount; i++) {
    pos = skip_dns_name(buf, len, pos);
    if (pos < 0 || pos + 10 > len) return;
    uint16_t rtype = (uint16_t)((buf[pos] << 8) | buf[pos+1]); pos += 2;
    pos += 6;  /* class (2) + ttl (4) */
    uint16_t rdlen = (uint16_t)((buf[pos] << 8) | buf[pos+1]); pos += 2;

    if (rtype == 1 && rdlen == 4 && pos + 4 <= len) {  /* A record */
      IP4_ADDR(ip_2_ip4(&q->result),
               buf[pos], buf[pos+1], buf[pos+2], buf[pos+3]);
      q->done = 1;
      return;
    }
    pos += rdlen;
  }
}

int mdns_resolve(const char *hostname, ip_addr_t *out)
{
  ip_addr_t group_addr;
  ipaddr_aton(MDNS_GROUP_ADDR, &group_addr);

  struct netif *netif = netif_default;
  if (!netif) return -1;

  cyw43_arch_lwip_begin();
  igmp_joingroup_netif(netif, ip_2_ip4(&group_addr));
  struct udp_pcb *pcb = udp_new();
  cyw43_arch_lwip_end();

  if (!pcb) return -1;

  mdns_query_t q;
  ip_addr_set_zero(&q.result);
  q.done = 0;

  cyw43_arch_lwip_begin();
  udp_recv(pcb, mdns_recv, &q);
  err_t err = udp_bind(pcb, IP_ADDR_ANY, MDNS_PORT);
  cyw43_arch_lwip_end();

  if (err != ERR_OK) {
    cyw43_arch_lwip_begin();
    udp_remove(pcb);
    cyw43_arch_lwip_end();
    return -1;
  }

  /* Build DNS query packet */
  uint8_t pkt[300];
  int pos = 0;
  pkt[pos++] = 0; pkt[pos++] = 0;    /* Transaction ID = 0 (mDNS convention) */
  pkt[pos++] = 0; pkt[pos++] = 0;    /* Flags: standard query */
  pkt[pos++] = 0; pkt[pos++] = 1;    /* QDCOUNT = 1 */
  pkt[pos++] = 0; pkt[pos++] = 0;    /* ANCOUNT = 0 */
  pkt[pos++] = 0; pkt[pos++] = 0;    /* NSCOUNT = 0 */
  pkt[pos++] = 0; pkt[pos++] = 0;    /* ARCOUNT = 0 */
  int nlen = encode_dns_name(hostname, pkt + pos, (int)sizeof(pkt) - pos - 4);
  if (nlen < 0) {
    cyw43_arch_lwip_begin();
    udp_remove(pcb);
    cyw43_arch_lwip_end();
    return -1;
  }
  pos += nlen;
  pkt[pos++] = 0;    pkt[pos++] = 1;    /* QTYPE  = A */
  pkt[pos++] = 0x80; pkt[pos++] = 0x01; /* QCLASS = IN | QU (prefer unicast response) */

  struct pbuf *pb = pbuf_alloc(PBUF_TRANSPORT, (u16_t)pos, PBUF_RAM);
  if (!pb) {
    cyw43_arch_lwip_begin();
    udp_remove(pcb);
    cyw43_arch_lwip_end();
    return -1;
  }
  memcpy(pb->payload, pkt, pos);

  cyw43_arch_lwip_begin();
  err = udp_sendto(pcb, pb, &group_addr, MDNS_PORT);
  cyw43_arch_lwip_end();
  pbuf_free(pb);

  if (err != ERR_OK) {
    cyw43_arch_lwip_begin();
    udp_remove(pcb);
    cyw43_arch_lwip_end();
    return -1;
  }

  absolute_time_t deadline = make_timeout_time_ms(MDNS_TIMEOUT_MS);
  while (!q.done && !time_reached(deadline)) {
    cyw43_arch_poll();
    busy_wait_ms(10);
  }

  cyw43_arch_lwip_begin();
  udp_remove(pcb);
  cyw43_arch_lwip_end();

  if (q.done) {
    ip_addr_copy(*out, q.result);
    return 0;
  }
  return -1;
}
