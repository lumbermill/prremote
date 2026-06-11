#pragma once
#include "lwip/ip_addr.h"

void Net_busy_wait_ms(int ms);
void lwip_begin(void);
void lwip_end(void);
int  Net_get_ip(const char *name, void *ip);
