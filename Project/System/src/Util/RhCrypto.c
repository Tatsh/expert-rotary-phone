//
//  RhCrypto.c
//  pop'n rhythmin
//
//  Ghidra: RhMD5 (FUN_0005b484) (project rb420, program PopnRhythmin).
//

#include "RhCrypto.h"
#include <CommonCrypto/CommonDigest.h>

void RhMD5(const void *data, uint32_t len, unsigned char out16[16]) {
    CC_MD5_CTX ctx;
    CC_MD5_Init(&ctx);
    CC_MD5_Update(&ctx, data, len);
    CC_MD5_Final(out16, &ctx);
}
