/*
 * ntp.c — SNTP (RFC 4330) time sync over UDP port 123.
 *
 * Sends a 48-byte client request and extracts the Transmit Timestamp
 * (bytes 40–43) from the server response.  The 32-bit NTP epoch
 * (seconds since 1900-01-01) is converted to Unix epoch by subtracting
 * 2208988800 (= 70 years of seconds including 17 leap years).
 */

#include <string.h>
#include "pico/cyw43_arch.h"
#include "lwip/udp.h"
#include "lwip/pbuf.h"
#include "net_helpers.h"   /* Net_get_ip, Net_busy_wait_ms, lwip_begin/end */
#include "ntp.h"

#define NTP_PORT             123
#define NTP_PACKET_SIZE       48
#define NTP_EPOCH_DELTA  2208988800UL   /* seconds 1900-01-01 → 1970-01-01 */
#define NTP_DEFAULT_TIMEOUT  10000      /* ms */

typedef struct {
  struct udp_pcb *pcb;
  uint32_t        unix_time;
  bool            done;
} ntp_ctx_t;

static void
ntp_recv(void *arg, struct udp_pcb *pcb, struct pbuf *p,
         const ip_addr_t *addr, u16_t port)
{
  (void)pcb; (void)addr; (void)port;
  ntp_ctx_t *ctx = (ntp_ctx_t *)arg;
  if (p->tot_len >= NTP_PACKET_SIZE) {
    uint8_t buf[NTP_PACKET_SIZE];
    pbuf_copy_partial(p, buf, NTP_PACKET_SIZE, 0);
    /* Transmit Timestamp: bytes 40–43, big-endian NTP seconds */
    uint32_t ntp_sec = ((uint32_t)buf[40] << 24) | ((uint32_t)buf[41] << 16)
                     | ((uint32_t)buf[42] <<  8) |  (uint32_t)buf[43];
    if (ntp_sec > NTP_EPOCH_DELTA)
      ctx->unix_time = ntp_sec - NTP_EPOCH_DELTA;
  }
  pbuf_free(p);
  ctx->done = true;
}

uint32_t
ntp_get_unix_time(const char *host, int timeout_ms)
{
  ip_addr_t addr;
  if (Net_get_ip(host, &addr) != 0) return 0;

  if (timeout_ms <= 0) timeout_ms = NTP_DEFAULT_TIMEOUT;

  ntp_ctx_t ctx = { .pcb = NULL, .unix_time = 0, .done = false };

  lwip_begin();
  ctx.pcb = udp_new_ip_type(IPADDR_TYPE_V4);
  if (!ctx.pcb) { lwip_end(); return 0; }
  udp_recv(ctx.pcb, ntp_recv, &ctx);

  uint8_t pkt[NTP_PACKET_SIZE];
  memset(pkt, 0, NTP_PACKET_SIZE);
  pkt[0] = 0x23;  /* LI=0, VN=4 (SNTPv4), Mode=3 (client) */

  struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, NTP_PACKET_SIZE, PBUF_RAM);
  if (!p) { udp_remove(ctx.pcb); lwip_end(); return 0; }
  memcpy(p->payload, pkt, NTP_PACKET_SIZE);
  err_t err = udp_sendto(ctx.pcb, p, &addr, NTP_PORT);
  pbuf_free(p);
  lwip_end();

  if (err != ERR_OK) {
    lwip_begin();
    udp_remove(ctx.pcb);
    lwip_end();
    return 0;
  }

  /* Busy-wait for the server response */
  int waited = 0;
  while (!ctx.done && waited < timeout_ms) {
    Net_busy_wait_ms(10);
    waited += 10;
  }

  lwip_begin();
  udp_remove(ctx.pcb);
  lwip_end();

  return ctx.unix_time;
}
