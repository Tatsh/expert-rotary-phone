//
//  AcMusicData.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "UnZipArchive.h"   // ZipArchive library

#import "AcMusicData.h"
#import "BFCodec.h"
#import "RhCrypto.h"
#import "RhUtil.h"

// The .orb is a ZIP; encrypted payload lives in its "info" entry (Ghidra:
// entry-name string @ 0x137a78). Same key/scheme as MusicData.
static NSString *const kOrbInfoEntry = @"info";
static const char kOrbKeyObfuscated[25] = {
    0x50, 0x6e, 0x6e, 0x6b, 0x1c, 0x4a, 0x6c, 0x5b, 0x61, 0x6b, 0x16, 0x43, 0x63,
    0x67, 0x57, 0x1f, 0x10, 0x67, 0x58, 0x5f, 0x1d, 0x1e, 0x1a, 0x19, 0x16
};

@implementation AcMusicData

// Kana-row ("gyo") initial mapping — pending dedicated reconstruction.
+ (int)GetGyoIndex:(NSString *)ch;      // fwd
+ (NSString *)GetGyoName:(int)index;    // fwd

// @ 0x65d54 — .orb ZIP -> BF-decrypt its "info" entry.
+ (NSData *)getZipData:(NSString *)entry Path:(NSString *)path {
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

// @ 0x66364 — decode an entry using this record's stored path.
- (NSData *)getZipData:(NSString *)entry {
    return [AcMusicData getZipData:entry Path:self.filePath];
}

// The per-difficulty note charts: each is a BF-decrypted ZIP entry of the .acv.
// Ghidra: sheetEasy @ 0x66418 / sheetNormal @ 0x66434 / sheetHyper @ 0x66450 /
// sheetEx @ 0x6646c.
- (NSData *)sheetEasy {
    return [self getZipData:@"sheet_es"];
}

- (NSData *)sheetNormal {
    return [self getZipData:@"sheet_n"];
}

- (NSData *)sheetHyper {
    return [self getZipData:@"sheet_h"];
}

- (NSData *)sheetEx {
    return [self getZipData:@"sheet_ex"];
}

// @ 0x65c6c — deobfuscate key (byte + index), MD5 it, Blowfish-decrypt in place.
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

// @ 0x65e2c
+ (instancetype)dataWithPath:(NSString *)path ID:(int)acMusicId {
    NSData *raw = [self getZipData:kOrbInfoEntry Path:path];
    if (raw == nil) {
        return nil;
    }
    NSDictionary *dict = RhParsePlistDict(raw);   // .orb payload is a property list
    if (dict == nil) {
        return nil;
    }
    NSNumber *idNum = dict[@"ID"];
    if (idNum == nil || idNum.intValue != acMusicId) {
        return nil;
    }

    AcMusicData *data = [[AcMusicData alloc] init];
    data.acMusicId = acMusicId;
    data.musicName = dict[@"MusicName"];
    data.musicNameKana = dict[@"MusicNameKana"];
    data.genreName = dict[@"GenreName"];
    data.genreNameKana = dict[@"GenreNameKana"];
    data.lvEasy = [dict[@"Easy"] intValue];
    data.lvNormal = [dict[@"Normal"] intValue];
    data.lvHyper = [dict[@"Hyper"] intValue];
    data.lvEx = [dict[@"Ex"] intValue];
    data.bpmEasy = dict[@"BpmEs"];
    data.bpmNormal = dict[@"BpmN"];
    data.bpmHyper = dict[@"BpmH"];
    data.bpmEx = dict[@"BpmEx"];

    int category = [dict[@"Category"] intValue];
    if (category > 23) {
        category = 0; // clamp out-of-range categories (Ghidra: > 0x17 -> 0)
    }
    data.category = category;
    data.filePath = path;

    // Sort initials from the kana readings (music name + genre).
    NSString *musicHead = [data.musicNameKana substringToIndex:1];
    data.musicNameInitial = [self GetGyoName:[self GetGyoIndex:musicHead]];
    NSString *genreHead = [data.genreNameKana substringToIndex:1];
    data.genreNameInitial = [self GetGyoName:[self GetGyoIndex:genreHead]];
    return data;
}

@end
