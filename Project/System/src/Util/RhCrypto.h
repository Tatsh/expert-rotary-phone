//
//  RhCrypto.h
//  pop'n rhythmin
//
//  Small crypto helpers over CommonCrypto used by the app.
//

#ifndef RHCRYPTO_H
#define RHCRYPTO_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// One-shot MD5. Writes a 16-byte digest into `out16`.
// Ghidra: RhMD5 (FUN_0005b484) (project rb420, program PopnRhythmin) —
// a thin wrapper around CC_MD5_Init/Update/Final.
void RhMD5(const void *data, uint32_t len, unsigned char out16[16]);

#ifdef __cplusplus
}
#endif

#endif /* RHCRYPTO_H */
