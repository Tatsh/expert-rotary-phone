// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef RHCRYPTO_H
#define RHCRYPTO_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Computes the MD5 hash of the given data.
 * @param data Pointer to the input data to hash.
 * @param len Length of the input data in bytes.
 * @param out16 Pointer to a buffer where the 16-byte MD5 digest will be stored.
 * @ghidraAddress 0x0005b484
 */
void RhMD5(const void *data, uint32_t len, unsigned char out16[16]);

#ifdef __cplusplus
}
#endif

#endif /* RHCRYPTO_H */
