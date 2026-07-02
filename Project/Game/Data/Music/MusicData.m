//
//  MusicData.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "UnZipArchive.h"   // ZipArchive library

#import "BFCodec.h"
#import "MusicData.h"
#import "RhCrypto.h"
#import "RhUtil.h"

// The .orb is a ZIP; the encrypted payload lives in its "info" entry
// (Ghidra: entry-name string @ 0x137a78).
static NSString *const kOrbInfoEntry = @"info";

// Obfuscated 25-byte key for the "info" entry (Ghidra: literal in
// +getZipData:Path:DecodeType: @ 0xc71ec). decodeBF: deobfuscates it as
// (byte + index) -> "Popn Orbit Note. xjr1300." -> MD5 -> Blowfish key.
static const char kOrbKeyObfuscated[25] = {
    0x50, 0x6e, 0x6e, 0x6b, 0x1c, 0x4a, 0x6c, 0x5b, 0x61, 0x6b, 0x16, 0x43, 0x63,
    0x67, 0x57, 0x1f, 0x10, 0x67, 0x58, 0x5f, 0x1d, 0x1e, 0x1a, 0x19, 0x16
};

// Default artist initial used when the artist reading is empty
// (Ghidra: DAT_0018829c). TODO: confirm exact string (likely a kana "other").
static NSString *const kDefaultInitial = @"";

@implementation MusicData

// Kana "yomi" (reading-row) initial mapping — pending dedicated reconstruction.
+ (int)GetYomiIndex:(NSString *)ch;      // fwd
+ (NSString *)GetYomiString:(int)index;  // fwd

// @ 0xc71ec — the .orb is a ZIP; read + BF-decrypt its "info" entry.
+ (NSData *)getZipData:(NSString *)entry Path:(NSString *)path DecodeType:(int)type {
    if (type != 0) {
        return nil;
    }
    UnZipArchive *zip = [[UnZipArchive alloc] init];
    if (![zip openFile:path]) {
        return nil;
    }
    NSData *data = [zip getData:entry];
    NSData *result = nil;
    if (data != nil) {
        result = [self decodeBF:data Key:kOrbKeyObfuscated KeyLength:25];
    }
    [zip closeFile];
    return result;
}

// @ 0xc788c — decode an entry using this record's stored path + decode type.
- (NSData *)getZipData:(NSString *)entry {
    return [MusicData getZipData:entry Path:self.filePath DecodeType:self.decodeType];
}

// @ 0xc7104 — deobfuscate key (byte + index), MD5 it, Blowfish-decrypt in place.
+ (NSData *)decodeBF:(NSData *)data Key:(const char *)key KeyLength:(int)keyLen {
    char *buf = (char *)malloc(keyLen);
    for (int i = 0; i < keyLen; i++) {
        buf[i] = key[i] + (char)i;
    }
    unsigned char digest[16];
    RhMD5(buf, keyLen, digest);
    free(buf);

    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:(const char *)digest keyLength:16];
    NSMutableData *mutable = [data mutableCopy];
    BOOL ok = [codec decipher:mutable];
    return ok ? mutable : nil;
}

// @ 0xc72c8
+ (instancetype)dataWithPath:(NSString *)path ID:(int)musicId {
    NSData *raw = [self getZipData:kOrbInfoEntry Path:path DecodeType:0];
    if (raw == nil) {
        return nil;
    }
    NSDictionary *dict = RhParsePlistDict(raw);   // .orb payload is a property list
    if (dict == nil) {
        return nil;
    }
    NSNumber *idNum = dict[@"ID"];
    if (idNum == nil || idNum.intValue != musicId) {
        return nil;
    }

    NSString *musicName = dict[@"MusicName"];
    NSString *musicHira = dict[@"MusicNameHira"];
    NSString *artistName = dict[@"ArtistName"];
    NSString *artistHira = dict[@"ArtistNameHira"];
    int n = [dict[@"Normal"] intValue];
    int h = [dict[@"Hyper"] intValue];
    int ex = [dict[@"Ex"] intValue];

    // Validate difficulty ranges: Normal/Hyper 1..10, Ex 1..11.
    if (!(n - 1 < 10 && h - 1 < 10 && ex - 1 < 11)) {
        return nil;
    }

    MusicData *data = [[MusicData alloc] init];
    data.MusicID = musicId;
    data.musicName = musicName;
    data.musicHira = musicHira;
    data.artistName = artistName;
    data.artistHira = artistHira;
    data.lvNormal = n;
    data.lvHyper = h;
    data.lvEx = ex;
    data.bpmMin = [dict[@"BpmMin"] intValue];
    data.bpmMax = [dict[@"BpmMax"] intValue];
    data.filePath = path;
    data.decodeType = 0;

    // Sort keys are the reading (hira) strings; initials come from the kana row.
    data.musicSortName = musicHira;
    data.artistSortName = artistHira;

    NSString *musicHead = [data.musicSortName substringToIndex:1];
    data.musicNameInitial = [self GetYomiString:[self GetYomiIndex:musicHead]];

    if (data.artistSortName.length == 0) {
        data.artistNameInitial = kDefaultInitial;
    } else {
        NSString *artistHead = [data.artistSortName substringToIndex:1];
        data.artistNameInitial = [self GetYomiString:[self GetYomiIndex:artistHead]];
    }
    return data;
}

// @ 0xc776c
- (void)setLevelN:(int)n H:(int)h Ex:(int)ex {
    self.lvNormal = n;
    self.lvHyper = h;
    self.lvEx = ex;
}

@end
