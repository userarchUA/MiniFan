#ifndef SMC_H
#define SMC_H
#include <stdint.h>
int  smc_open(void);
void smc_close(void);
int  smc_key_info(const char *key, uint32_t *size, char *type);
int  smc_read(const char *key, uint8_t *buf, uint32_t *size, char *type);
int  smc_write(const char *key, const uint8_t *buf, uint32_t size);
int  smc_key_at(uint32_t index, char *key);
#endif
