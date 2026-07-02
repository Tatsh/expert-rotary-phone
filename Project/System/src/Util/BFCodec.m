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
//  ORIG_S @ DAT_0012e6c8 (4x256); identical to bfcodec's bf_init_bytes.inc.
//  Library-standard, so referenced here rather than transcribed.
//

#import "BFCodec.h"

typedef struct {
    uint32_t P[18];
    uint32_t S[4][256];
} BlowfishCtx;

// Canonical Blowfish initial values (see header note). Populate from the
// standard reference tables / from the binary's DAT_0012f6c8 & DAT_0012e6c8.
extern const uint32_t kBlowfishInitP[18];        // Ghidra: DAT_0012f6c8
extern const uint32_t kBlowfishInitS[4][256];    // Ghidra: DAT_0012e6c8

// Fixed CBC IV (Ghidra: DAT_0012e6c0). Confirmed constant, matches bfcodec's
// kDefaultIv.
static const uint8_t kInitialIV[8] = { 0xE3, 0x66, 0x31, 0xDA, 0x2C, 0x85, 0xA0, 0x64 };

// NON-STANDARD F: the ONLY deviation from textbook Blowfish. It combines the
// S-box outputs as (S0[a] + S1[b]) ^ (S2[c] + S3[d]); standard Blowfish would be
// ((S0[a] + S1[b]) ^ S2[c]) + S3[d]. Confirmed against the RB-derived reference
// (~/dev-paused/bfcodec/src/bfcodec.c: bf_f) and Ghidra FUN_0005b40c.
static inline uint32_t BF_F(const BlowfishCtx *c, uint32_t x) {
    uint32_t a = (x >> 24) & 0xff;
    uint32_t b = (x >> 16) & 0xff;
    uint32_t cc = (x >> 8) & 0xff;
    uint32_t d = x & 0xff;
    return (c->S[0][a] + c->S[1][b]) ^ (c->S[2][cc] + c->S[3][d]);
}

// Ghidra: FUN_0005b390 (block encrypt). Note the halves are swapped on output.
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
    BlowfishCtx *_blf;   // Ghidra ivar _blf
    uint8_t _iv[8];      // Ghidra ivar _iv
}

- (instancetype)init {
    if ((self = [super init])) {
        _blf = (BlowfishCtx *)calloc(1, sizeof(BlowfishCtx)); // Ghidra: FUN_0005b234
    }
    return self;
}

- (void)dealloc {
    free(_blf);
}

// @ 0x5ad64
- (void)cipherInit:(NSData *)key {
    if (key == nil) {
        return;
    }
    [self cipherInit:(const char *)key.bytes keyLength:(int)key.length];
}

// @ 0x5ad0c — standard Blowfish key schedule.
- (void)cipherInit:(const char *)key keyLength:(int)length {
    memcpy(_iv, kInitialIV, 8);

    // Seed S-boxes and P-array from the canonical constants.
    memcpy(_blf->S, kBlowfishInitS, sizeof(_blf->S));

    // XOR the key (cycled) into the P-array.
    int j = 0;
    for (int i = 0; i < 18; i++) {
        uint32_t data = ((uint32_t)(uint8_t)key[j % length] << 24) |
                        ((uint32_t)(uint8_t)key[(j + 1) % length] << 16) |
                        ((uint32_t)(uint8_t)key[(j + 2) % length] << 8) |
                        ((uint32_t)(uint8_t)key[(j + 3) % length]);
        _blf->P[i] = kBlowfishInitP[i] ^ data;
        j = (j + 4) % length;
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
- (unsigned int)encipher:(NSMutableData *)data {
    NSUInteger origLen = data.length;
    NSUInteger padded = (origLen + 7) & ~7u;
    data.length = padded + 8;
    uint8_t *bytes = (uint8_t *)data.mutableBytes;

    uint32_t cl = ((uint32_t)_iv[0] << 24) | ((uint32_t)_iv[1] << 16) |
                  ((uint32_t)_iv[2] << 8) | _iv[3];
    uint32_t cr = ((uint32_t)_iv[4] << 24) | ((uint32_t)_iv[5] << 16) |
                  ((uint32_t)_iv[6] << 8) | _iv[7];

    NSUInteger in = 0, out = 0;
    while (in < origLen) {
        uint32_t l = 0, r = 0;
        for (int k = 0; k < 4; k++) { l <<= 8; if (in < origLen) l |= bytes[in++]; }
        for (int k = 0; k < 4; k++) { r <<= 8; if (in < origLen) r |= bytes[in++]; }
        l ^= cl; r ^= cr;                 // CBC chain
        BF_EncryptBlock(_blf, &l, &r);
        bytes[out] = l >> 24; bytes[out + 1] = l >> 16; bytes[out + 2] = l >> 8; bytes[out + 3] = l;
        bytes[out + 4] = r >> 24; bytes[out + 5] = r >> 16; bytes[out + 6] = r >> 8; bytes[out + 7] = r;
        cl = l; cr = r;
        out += 8;
    }
    // Trailer: original length, then padded length (low 3 bits cleared).
    bytes[out] = origLen >> 24; bytes[out + 1] = origLen >> 16;
    bytes[out + 2] = origLen >> 8; bytes[out + 3] = origLen;
    uint32_t pl = (uint32_t)(origLen + 7);
    bytes[out + 4] = pl >> 24; bytes[out + 5] = pl >> 16;
    bytes[out + 6] = pl >> 8; bytes[out + 7] = pl & 0xf8;
    return (unsigned int)padded;
}

// @ 0x5af78 — validate trailer, CBC decrypt in place, truncate to origLen.
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
    uint32_t cl = ((uint32_t)_iv[0] << 24) | ((uint32_t)_iv[1] << 16) |
                  ((uint32_t)_iv[2] << 8) | _iv[3];
    uint32_t cr = ((uint32_t)_iv[4] << 24) | ((uint32_t)_iv[5] << 16) |
                  ((uint32_t)_iv[6] << 8) | _iv[7];

    NSUInteger in = 0, out = 0;
    while (in < body) {
        uint32_t l = 0, r = 0;
        for (int k = 0; k < 4; k++) { l <<= 8; if (in < body) l |= bytes[in++]; }
        for (int k = 0; k < 4; k++) { r <<= 8; if (in < body) r |= bytes[in++]; }
        uint32_t cipherL = l, cipherR = r;
        BF_DecryptBlock(_blf, &l, &r);
        l ^= cl; r ^= cr;                 // CBC chain (previous ciphertext)
        bytes[out] = l >> 24; bytes[out + 1] = l >> 16; bytes[out + 2] = l >> 8; bytes[out + 3] = l;
        bytes[out + 4] = r >> 24; bytes[out + 5] = r >> 16; bytes[out + 6] = r >> 8; bytes[out + 7] = r;
        cl = cipherL; cr = cipherR;
        out += 8;
    }
    data.length = origLen;
    return YES;
}

@end
