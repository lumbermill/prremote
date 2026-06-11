#pragma once
#include <stdint.h>

/* SNTP (RFC 4330) over UDP port 123.
 * Returns UTC Unix epoch seconds on success, 0 on failure.
 * Pass timeout_ms <= 0 to use the default (10 s). */
uint32_t ntp_get_unix_time(const char *host, int timeout_ms);
