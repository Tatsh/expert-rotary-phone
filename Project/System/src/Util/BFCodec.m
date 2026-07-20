//
//  BFCodec.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  This is Blowfish in CBC mode with ONE deviation from the textbook cipher:
//  the F-function (see BF_F). Cross-checked against the RB-derived reference
//  implementation ~/dev-paused/bfcodec (src/bfcodec.c), which is confirmed to
//  decode this game's .orb/mulist data given the right key.
//
//  Key/IV in practice (see MusicManager.loadPurchasedMusics):
//    key = MD5(device UUID) (16 bytes)   IV = E3 66 31 DA 2C 85 A0 64 (fixed).
//
//  The initial P-array and S-boxes are the canonical Blowfish constants
//  (fractional digits of pi): Ghidra ORIG_P @ DAT_0012f6c8 (18 words),
//  ORIG_S @ DAT_0012e6c8 (4x256). Vendored verbatim as bf_init_bytes.inc.
//

#import "BFCodec.h"

typedef struct {
    uint32_t P[18];
    uint32_t S[4][256];
} BlowfishCtx;

// Zero the entire Blowfish context (P-array + S-boxes), wiping any key
// material. This trivial memset over the whole 0x1048-byte context was emitted
// by the compiler as three separate entry points, one per call site
// (-init, -cipherInit:keyLength:, -dealloc); they are one logical clear.
// @ 0x5b234 / 0x5b244 / 0x5b258
// All three verified: `movs r1,#0; movw r2,#0x1048; blx memset` — a zero-fill
// of the whole 0x1048-byte context.
static inline void blowfishCtxClear(BlowfishCtx *ctx) {
    memset(ctx, 0, sizeof(BlowfishCtx)); // 0x1048 bytes
}

// Canonical Blowfish initial P-array (18) + S-boxes (4x256), fractional digits
// of pi. Vendored as big-endian bytes from bf_init_bytes.inc — identical to the
// binary's DAT_0012f6c8 / DAT_0012e6c8 (confirmed to decode the game's data).
static const unsigned char kBFInitBytes[] = {
#include "bf_init_bytes.inc"
};

// Read a big-endian uint32 from a 4-byte buffer.
static inline uint32_t BF_ReadU32BE(const unsigned char *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

// Fixed CBC IV (Ghidra: DAT_0012e6c0). Confirmed constant, matches bfcodec's
// kDefaultIv. Byte-verified via read_memory @ 0x12e6c0: e3 66 31 da 2c 85 a0 64.
static const uint8_t kInitialIV[8] = {0xE3, 0x66, 0x31, 0xDA, 0x2C, 0x85, 0xA0, 0x64};

// NON-STANDARD F: the ONLY deviation from textbook Blowfish. It combines the
// S-box outputs as (S0[a] + S1[b]) ^ (S2[c] + S3[d]); standard Blowfish would
// be
// ((S0[a] + S1[b]) ^ S2[c]) + S3[d]. Confirmed against the RB-derived reference
// (~/dev-paused/bfcodec/src/bfcodec.c: bf_f) and Ghidra FUN_0005b40c.
// Verified against the S-box loads inside FUN_0005b390: S0 at ctx+0x48+0,
// S1 at +0x400, S2 at +0x800, S3 at +0xc00; the two sums are XORed.
static inline uint32_t BF_F(const BlowfishCtx *c, uint32_t x) {
    uint32_t a = (x >> 24) & 0xff;
    uint32_t b = (x >> 16) & 0xff;
    uint32_t cc = (x >> 8) & 0xff;
    uint32_t d = x & 0xff;
    return (c->S[0][a] + c->S[1][b]) ^ (c->S[2][cc] + c->S[3][d]);
}

// Ghidra: FUN_0005b390 (block encrypt). Note the halves are swapped on output.
// Verified: the binary runs 16 single-round iterations (this unrolls 8 by two);
// the tail xors P[16]/P[17] and writes *xl = (right ^ P[17]), *xr = (left ^
// P[16]).
static void BF_EncryptBlock(const BlowfishCtx *c, uint32_t *xl, uint32_t *xr) {
    uint32_t l = *xl, r = *xr;
    for (int i = 0; i < 16; i += 2) {
        l ^= c->P[i];
        r ^= BF_F(c, l);
        r ^= c->P[i + 1];
        l ^= BF_F(c, r);
    }
    l ^= c->P[16];
    r ^= c->P[17];
    *xl = r;
    *xr = l;
}

// Ghidra: FUN_0005b40c (block decrypt).
// Verified: the binary loops the P index from 17 down to 2, then xors P[1]/P[0]
// and writes *xl = (right ^ P[0]), *xr = (left ^ P[1]).
static void BF_DecryptBlock(const BlowfishCtx *c, uint32_t *xl, uint32_t *xr) {
    uint32_t l = *xl, r = *xr;
    for (int i = 16; i >= 2; i -= 2) {
        l ^= c->P[i + 1];
        r ^= BF_F(c, l);
        r ^= c->P[i];
        l ^= BF_F(c, r);
    }
    l ^= c->P[1];
    r ^= c->P[0];
    *xl = r;
    *xr = l;
}

@implementation BFCodec {
    BlowfishCtx *_blf; // Ghidra ivar _blf
    uint8_t _iv[8];    // Ghidra ivar _iv
}

// @ 0x5ac14
// Verified: [super init]; zero the 8-byte _iv ivar; malloc(0x1048) into _blf;
// then the 0x5b244 clear entry.
- (instancetype)init {
    if ((self = [super init])) {
        memset(_iv, 0, sizeof(_iv));                       // Ghidra: _iv zeroed
        _blf = (BlowfishCtx *)malloc(sizeof(BlowfishCtx)); // operator new(0x1048)
        blowfishCtxClear(_blf);                            // @ 0x5b244
    }
    return self;
}

// @ 0x5b154 — KEEP: frees the malloc'd Blowfish context (wipes key material
// first).
// Verified: if _blf non-null, 0x5b258 clear then free; then [super dealloc].
- (void)dealloc {
    if (_blf) {
        blowfishCtxClear(_blf); // @ 0x5b258 — zeroize key material before releasing
        free(_blf);             // operator delete
    }
}

// @ 0x5ad64
// Verified: nil-guard, then tail-calls -cipherInit:keyLength: with key.bytes /
// key.length.
- (void)cipherInit:(NSData *)key {
    if (key == nil) {
        return;
    }
    [self cipherInit:(const char *)key.bytes keyLength:(int)key.length];
}

// @ 0x5ad0c — standard Blowfish key schedule (the body is the tail-call target
// FUN_0005b26c; 0x5ad0c is the clear + IV-copy prologue that jumps into it).
// Verified: clear (0x5b234); copy the 8-byte IV; load ORIG_S (0x12e6c8) into the
// S-boxes; load ORIG_P (0x12f6c8) fused with the XOR of the cycled key into the
// P-array; diffuse P, then the S-boxes, by repeatedly encrypting a running
// zero block. The P/S load and key-XOR are three loops here versus the binary's
// two (S-load, then a fused P-load + key-XOR); the per-index writes are
// independent, so the resulting state is identical. Constant tables byte-checked
// via read_memory: P[0]=0x243f6a88, S[0][0]=0xd1310ba6 (canonical, stored
// little-endian words; the .inc vendors them big-endian and BF_ReadU32BE reads
// them back to the same words).
- (void)cipherInit:(const char *)key keyLength:(int)length {
    blowfishCtxClear(_blf); // @ 0x5b234 — wipe the context before loading the schedule
    memcpy(_iv, kInitialIV, 8);

    // Load the canonical P-array (18) then S-boxes (4x256) from the init table.
    size_t idx = 0;
    for (int i = 0; i < 18; i++) {
        _blf->P[i] = BF_ReadU32BE(&kBFInitBytes[idx]);
        idx += 4;
    }
    for (int box = 0; box < 4; box++) {
        for (int i = 0; i < 256; i++) {
            _blf->S[box][i] = BF_ReadU32BE(&kBFInitBytes[idx]);
            idx += 4;
        }
    }

    // XOR the cycled key into the P-array.
    int j = 0;
    for (int i = 0; i < 18; i++) {
        uint32_t data = ((uint32_t)(uint8_t)key[j % length] << 24) |
                        ((uint32_t)(uint8_t)key[(j + 1) % length] << 16) |
                        ((uint32_t)(uint8_t)key[(j + 2) % length] << 8) |
                        ((uint32_t)(uint8_t)key[(j + 3) % length]);
        _blf->P[i] ^= data;
        j += 4;
    }

    // Diffuse: repeatedly encrypt the running block through P then all S-boxes.
    uint32_t l = 0, r = 0;
    for (int i = 0; i < 18; i += 2) {
        BF_EncryptBlock(_blf, &l, &r);
        _blf->P[i] = l;
        _blf->P[i + 1] = r;
    }
    for (int box = 0; box < 4; box++) {
        for (int i = 0; i < 256; i += 2) {
            BF_EncryptBlock(_blf, &l, &r);
            _blf->S[box][i] = l;
            _blf->S[box][i + 1] = r;
        }
    }
}

// @ 0x5adb4 — CBC encrypt in place + append [origLen BE][paddedLen BE] trailer.
// Verified: setLength to (origLen + 0xf) & ~7 (== padded + 8); IV -> cl/cr;
// per-block read 4+4 bytes (zero-padding the final partial block via the
// in<origLen guard), XOR the chain, encrypt, store big-endian, chain forward;
// trailer = origLen BE then (origLen + 7) BE with the low byte masked & 0xf8;
// return (origLen + 0xf) & ~7.
- (unsigned int)encipher:(NSMutableData *)data {
    NSUInteger origLen = data.length;
    NSUInteger padded = (origLen + 7) & ~7u;
    data.length = padded + 8;
    uint8_t *bytes = (uint8_t *)data.mutableBytes;

    uint32_t cl =
        ((uint32_t)_iv[0] << 24) | ((uint32_t)_iv[1] << 16) | ((uint32_t)_iv[2] << 8) | _iv[3];
    uint32_t cr =
        ((uint32_t)_iv[4] << 24) | ((uint32_t)_iv[5] << 16) | ((uint32_t)_iv[6] << 8) | _iv[7];

    NSUInteger in = 0, out = 0;
    while (in < origLen) {
        uint32_t l = 0, r = 0;
        for (int k = 0; k < 4; k++) {
            l <<= 8;
            if (in < origLen) {
                l |= bytes[in++];
            }
        }
        for (int k = 0; k < 4; k++) {
            r <<= 8;
            if (in < origLen) {
                r |= bytes[in++];
            }
        }
        l ^= cl;
        r ^= cr; // CBC chain
        BF_EncryptBlock(_blf, &l, &r);
        bytes[out] = l >> 24;
        bytes[out + 1] = l >> 16;
        bytes[out + 2] = l >> 8;
        bytes[out + 3] = l;
        bytes[out + 4] = r >> 24;
        bytes[out + 5] = r >> 16;
        bytes[out + 6] = r >> 8;
        bytes[out + 7] = r;
        cl = l;
        cr = r;
        out += 8;
    }
    // Trailer: original length, then padded length (low 3 bits cleared).
    bytes[out] = origLen >> 24;
    bytes[out + 1] = origLen >> 16;
    bytes[out + 2] = origLen >> 8;
    bytes[out + 3] = origLen;
    uint32_t pl = (uint32_t)(origLen + 7);
    bytes[out + 4] = pl >> 24;
    bytes[out + 5] = pl >> 16;
    bytes[out + 6] = pl >> 8;
    bytes[out + 7] = pl & 0xf8;
    // Ghidra returns (origLen + 0xf) & ~7 == padded + 8: the full ciphertext
    // length including the 8-byte trailer, not the padded body alone.
    return (unsigned int)(padded + 8);
}

// @ 0x5af78 — validate trailer, CBC decrypt in place, truncate to origLen.
// Verified: reject len < 8; read origLen BE at [body] and paddedLen BE at
// [len-4]; reject unless paddedLen == body and body == (origLen + 7) & ~7;
// IV -> cl/cr; per-block read the ciphertext, decrypt, XOR the previous
// ciphertext (IV first), store, chain from the saved ciphertext; setLength to
// origLen; return YES.
- (BOOL)decipher:(NSMutableData *)data {
    NSUInteger len = data.length;
    if (len < 8) {
        return NO;
    }
    NSUInteger body = len - 8;

    uint32_t origLenBE = 0, paddedLenBE = 0;
    [data getBytes:&origLenBE range:NSMakeRange(body, 4)];
    [data getBytes:&paddedLenBE range:NSMakeRange(len - 4, 4)];
    uint32_t origLen = CFSwapInt32BigToHost(origLenBE);
    uint32_t paddedLen = CFSwapInt32BigToHost(paddedLenBE);
    if (paddedLen != body || body != ((origLen + 7) & ~7u)) {
        return NO;
    }

    uint8_t *bytes = (uint8_t *)data.mutableBytes;
    uint32_t cl =
        ((uint32_t)_iv[0] << 24) | ((uint32_t)_iv[1] << 16) | ((uint32_t)_iv[2] << 8) | _iv[3];
    uint32_t cr =
        ((uint32_t)_iv[4] << 24) | ((uint32_t)_iv[5] << 16) | ((uint32_t)_iv[6] << 8) | _iv[7];

    NSUInteger in = 0, out = 0;
    while (in < body) {
        uint32_t l = 0, r = 0;
        for (int k = 0; k < 4; k++) {
            l <<= 8;
            if (in < body) {
                l |= bytes[in++];
            }
        }
        for (int k = 0; k < 4; k++) {
            r <<= 8;
            if (in < body) {
                r |= bytes[in++];
            }
        }
        uint32_t cipherL = l, cipherR = r;
        BF_DecryptBlock(_blf, &l, &r);
        l ^= cl;
        r ^= cr; // CBC chain (previous ciphertext)
        bytes[out] = l >> 24;
        bytes[out + 1] = l >> 16;
        bytes[out + 2] = l >> 8;
        bytes[out + 3] = l;
        bytes[out + 4] = r >> 24;
        bytes[out + 5] = r >> 16;
        bytes[out + 6] = r >> 8;
        bytes[out + 7] = r;
        cl = cipherL;
        cr = cipherR;
        out += 8;
    }
    data.length = origLen;
    return YES;
}

@end
