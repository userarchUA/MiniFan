// Minimal AppleSMC user-client access (read needs no root, write needs root).
#include <IOKit/IOKitLib.h>
#include <string.h>
#include <stdint.h>
#include "smc.h"

typedef struct { uint8_t major, minor, build, reserved; uint16_t release; } SMCVers;
typedef struct { uint16_t version, length; uint32_t cpuPLimit, gpuPLimit, memPLimit; } SMCPLimit;
typedef struct { uint32_t dataSize, dataType; uint8_t dataAttributes; } SMCKeyInfo;
typedef struct {
    uint32_t key; SMCVers vers; SMCPLimit pLimitData; SMCKeyInfo keyInfo;
    uint8_t result, status, data8; uint32_t data32; uint8_t bytes[32];
} SMCKeyData;
_Static_assert(sizeof(SMCKeyData) == 80, "SMCKeyData must be 80 bytes");

enum { K_READ = 5, K_WRITE = 6, K_INDEX = 8, K_INFO = 9, K_CALL = 2 };
static io_connect_t conn = 0;

static uint32_t str2key(const char *s) {
    uint32_t k = 0; size_t n = strlen(s);
    for (size_t i = 0; i < 4; i++) k = (k << 8) | (uint8_t)(i < n ? s[i] : ' ');
    return k;
}
static void key2str(uint32_t k, char *out) {
    for (int i = 3; i >= 0; i--) { out[i] = (char)(k & 0xff); k >>= 8; }
    out[4] = 0;
}
static kern_return_t call(SMCKeyData *in, SMCKeyData *out) {
    size_t os = sizeof(SMCKeyData);
    return IOConnectCallStructMethod(conn, K_CALL, in, sizeof(SMCKeyData), out, &os);
}

int smc_open(void) {
    if (conn) return 0;
    io_service_t dev = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleSMC"));
    if (!dev) return -1;
    kern_return_t r = IOServiceOpen(dev, mach_task_self(), 0, &conn);
    IOObjectRelease(dev);
    if (r != KERN_SUCCESS) { conn = 0; return -2; }
    return 0;
}
void smc_close(void) { if (conn) { IOServiceClose(conn); conn = 0; } }

int smc_key_info(const char *key, uint32_t *size, char *type) {
    SMCKeyData in, out; memset(&in, 0, sizeof in); memset(&out, 0, sizeof out);
    in.key = str2key(key); in.data8 = K_INFO;
    if (call(&in, &out) != KERN_SUCCESS || out.result != 0) return -1;
    *size = out.keyInfo.dataSize; key2str(out.keyInfo.dataType, type);
    return 0;
}
int smc_read(const char *key, uint8_t *buf, uint32_t *size, char *type) {
    uint32_t sz = 0;
    if (smc_key_info(key, &sz, type) != 0) return -1;
    SMCKeyData in, out; memset(&in, 0, sizeof in); memset(&out, 0, sizeof out);
    in.key = str2key(key); in.keyInfo.dataSize = sz; in.data8 = K_READ;
    if (call(&in, &out) != KERN_SUCCESS || out.result != 0) return -2;
    if (sz > 32) sz = 32;
    memcpy(buf, out.bytes, sz); *size = sz;
    return 0;
}
int smc_write(const char *key, const uint8_t *buf, uint32_t size) {
    char type[5]; uint32_t sz = 0;
    if (smc_key_info(key, &sz, type) != 0) return -1;
    if (size != sz || size > 32) return -3;
    SMCKeyData in, out; memset(&in, 0, sizeof in); memset(&out, 0, sizeof out);
    in.key = str2key(key); in.keyInfo.dataSize = sz; in.data8 = K_WRITE;
    memcpy(in.bytes, buf, size);
    if (call(&in, &out) != KERN_SUCCESS || out.result != 0) return -2;
    return 0;
}
int smc_key_at(uint32_t index, char *key) {
    SMCKeyData in, out; memset(&in, 0, sizeof in); memset(&out, 0, sizeof out);
    in.data8 = K_INDEX; in.data32 = index;
    if (call(&in, &out) != KERN_SUCCESS || out.result != 0) return -1;
    key2str(out.key, key);
    return 0;
}
