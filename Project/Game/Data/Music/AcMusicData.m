//
//  AcMusicData.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "UnZipArchive.h" // ZipArchive library

#import "AcMusicData.h"
#import "BFCodec.h"
#import "RhCrypto.h"
#import "RhUtil.h"

// The .orb is a ZIP; encrypted payload lives in its "info" entry (Ghidra:
// entry-name string @ 0x137a78). Same key/scheme as MusicData.
static NSString *const kOrbInfoEntry = @"info";
static const char kOrbKeyObfuscated[25] = {0x50, 0x6e, 0x6e, 0x6b, 0x1c, 0x4a, 0x6c, 0x5b, 0x61,
                                           0x6b, 0x16, 0x43, 0x63, 0x67, 0x57, 0x1f, 0x10, 0x67,
                                           0x58, 0x5f, 0x1d, 0x1e, 0x1a, 0x19, 0x16};

// The ten gojuon rows as katakana membership sets and their hiragana labels
// (Ghidra: DAT_00131d64 / PTR_cf_B0_00131d8c — the same constant strings the
// standard-mode MusicData yomi index uses).
static NSString *const kGyoRows[10] = {
    @"ァアィイゥウェエォオ",           // a-row
    @"カガキギクグケゲコゴ",           // ka-row
    @"サザシジスズセゼソゾ",           // sa-row
    @"タダチヂッツヅテデトド",         // ta-row (incl. small tsu)
    @"ナニヌネノ",                     // na-row
    @"ハバパヒビピフブプヘベペホボポ", // ha-row (dakuten + handakuten)
    @"マミムメモ",                     // ma-row
    @"ャヤュユョヨ",                   // ya-row (incl. small)
    @"ラリルレロ",                     // ra-row
    @"ヮワヰヱヲンヴヵヶ",             // wa-row / other
};

static NSString *const kGyoLabels[10] = {
    @"あ",
    @"か",
    @"さ",
    @"た",
    @"な",
    @"は",
    @"ま",
    @"や",
    @"ら",
    @"わ",
};

@implementation AcMusicData

// @ 0x65bbc — map a reading's first character to its gojuon row 0..9 (9 =
// other, -1 for nil/empty), scanning each row's katakana membership set.
//
// @complete
+ (int)GetGyoIndex:(NSString *)ch {
    if (ch == nil || ch.length == 0) {
        return -1;
    }
    unichar c = [ch characterAtIndex:0];
    for (int row = 0; row < 10; row++) {
        NSString *members = kGyoRows[row];
        NSUInteger n = members.length;
        for (NSUInteger i = 0; i < n; i++) {
            if ([members characterAtIndex:i] == c) {
                return row;
            }
        }
    }
    return 9;
}

// @ 0x65c54 — the display label (hiragana) for a gojuon row; nil past the end.
// The binary compares the index unsigned (cmp #0x9 / hi -> nil), so a negative
// index also yields nil; the `index < 10` guard here is equivalent for the
// 0..9 values actually passed (GetGyoIndex never returns > 9).
//
// @complete
+ (NSString *)GetGyoName:(int)index {
    if (index < 10) {
        return kGyoLabels[index];
    }
    return nil;
}

// @ 0x65d54 — .orb ZIP -> BF-decrypt its "info" entry.
//
// @complete
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
//
// @complete
- (NSData *)getZipData:(NSString *)entry {
    return [AcMusicData getZipData:entry Path:self.filePath];
}

// The per-difficulty note charts: each is a BF-decrypted ZIP entry of the .acv.
// Ghidra: sheetEasy @ 0x66418 / sheetNormal @ 0x66434 / sheetHyper @ 0x66450 /
// sheetEx @ 0x6646c.
//
// @complete
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

// @ 0x66394 — the difficulty's backing (BGM) track: "bgm_es"/"bgm_h"/"bgm_ex"
// for Easy/Hyper/Ex, falling back to "bgm_n" if that entry is missing (and for
// any other difficulty, i.e. Normal).
//
// @complete
- (NSData *)getBackTrack:(int)difficulty {
    NSString *entry;
    if (difficulty == 3) {
        entry = @"bgm_ex";
    } else if (difficulty == 2) {
        entry = @"bgm_h";
    } else if (difficulty == 0) {
        entry = @"bgm_es";
    } else {
        return [self getZipData:@"bgm_n"];
    }
    NSData *data = [self getZipData:entry];
    if (data != nil) {
        return data;
    }
    return [self getZipData:@"bgm_n"];
}

// @ 0x66488 — order by the katakana music-name reading; on an equal compare,
// tie-break so the shorter reading sorts first.
//
// @complete
- (NSComparisonResult)compare:(AcMusicData *)other {
    NSString *a = [self musicNameKana];
    NSString *b = [other musicNameKana];
    NSComparisonResult result = [a compare:b];
    if (result != NSOrderedSame) {
        return result;
    }
    NSUInteger la = a.length;
    NSUInteger lb = b.length;
    if (lb > la) {
        return NSOrderedAscending;
    }
    return (la != lb) ? NSOrderedDescending : NSOrderedSame;
}

// @ 0x664f8 — ascending by arcade music id.
//
// @complete
- (NSComparisonResult)compareAcMusicId:(AcMusicData *)other {
    int a = [self acMusicId];
    int b = [other acMusicId];
    if (b <= a) {
        return (b < a) ? NSOrderedDescending : NSOrderedSame;
    }
    return NSOrderedAscending;
}

// @ 0x66530 — like -compare: but a literal (NSLiteralSearch) comparison of the
// music-name reading, with the same shorter-first length tie-break.
//
// @complete
- (NSComparisonResult)compareMusicNameCustom:(AcMusicData *)other {
    NSString *a = [self musicNameKana];
    NSString *b = [other musicNameKana];
    NSComparisonResult result = [a compare:b options:NSLiteralSearch];
    if (result != NSOrderedSame) {
        return result;
    }
    NSUInteger la = a.length;
    NSUInteger lb = b.length;
    if (lb > la) {
        return NSOrderedAscending;
    }
    return (la != lb) ? NSOrderedDescending : NSOrderedSame;
}

// @ 0x665a4 — literal comparison of the genre-name reading; defers to the music
// name on a tie.
//
// @complete
- (NSComparisonResult)compareGenreNameCustom:(AcMusicData *)other {
    NSComparisonResult result = [[self genreNameKana] compare:[other genreNameKana]
                                                      options:NSLiteralSearch];
    if (result == NSOrderedSame) {
        return [self compareMusicNameCustom:other];
    }
    return result;
}

// @ 0x6660c — ascending by Easy level.
//
// @complete
- (NSComparisonResult)compareLvEasy:(AcMusicData *)other {
    int a = [self lvEasy];
    int b = [other lvEasy];
    if (b <= a) {
        return (b < a) ? NSOrderedDescending : NSOrderedSame;
    }
    return NSOrderedAscending;
}

// @ 0x66644 — ascending by Normal level.
//
// @complete
- (NSComparisonResult)compareLvNormal:(AcMusicData *)other {
    int a = [self lvNormal];
    int b = [other lvNormal];
    if (b <= a) {
        return (b < a) ? NSOrderedDescending : NSOrderedSame;
    }
    return NSOrderedAscending;
}

// @ 0x6667c — ascending by Hyper level.
//
// @complete
- (NSComparisonResult)compareLvHyper:(AcMusicData *)other {
    int a = [self lvHyper];
    int b = [other lvHyper];
    if (b <= a) {
        return (b < a) ? NSOrderedDescending : NSOrderedSame;
    }
    return NSOrderedAscending;
}

// @ 0x666b4 — ascending by Ex level.
//
// @complete
- (NSComparisonResult)compareLvEx:(AcMusicData *)other {
    int a = [self lvEx];
    int b = [other lvEx];
    if (b <= a) {
        return (b < a) ? NSOrderedDescending : NSOrderedSame;
    }
    return NSOrderedAscending;
}

// @ 0x6629c — dealloc only releases its object ivars (musicName, musicNameKana,
// genreName, genreNameKana, filePath, musicNameInitial, genreNameInitial) then
// calls [super dealloc]; ARC synthesizes this, so no body is written here.
// Verified @ 0x6629c: releases exactly those seven ivars in that order, then
// [super dealloc]. @complete

// @ 0x65c6c — deobfuscate key (byte + index), MD5 it, Blowfish-decrypt the
// passed data in place.
//
// @complete
// The binary deciphers the argument object directly and returns that same
// object on success (nil on failure); it does not make a mutable copy (no
// -mutableCopy message is emitted @ 0x65c6c). The caller therefore passes a
// mutable buffer. Verified: r8 holds param_2 throughout, is passed to
// -decipher: unchanged @ 0x65d10, and is the return value @ 0x65d46 (cleared to
// nil @ 0x65d38 when -decipher: returned NO). -[BFCodec decipher:] mutates its
// argument, so the passed NSData must be a mutable instance.
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
    BOOL ok = [codec decipher:(NSMutableData *)data];
    return ok ? data : nil;
}

// @ 0x65e2c
//
// @complete
// Verified: key read order (MusicName, MusicNameKana, GenreName,
// GenreNameKana, Easy, Normal, Hyper, Ex, BpmEs, BpmN, BpmH, BpmEx, Category)
// matches; the string fields are stored via -[NSString initWithString:] copies;
// the category clamp is `>= 0x18 -> 0` @ 0x66190 (equivalent to `> 23`).
+ (instancetype)dataWithPath:(NSString *)path ID:(int)acMusicId {
    NSData *raw = [self getZipData:kOrbInfoEntry Path:path];
    if (raw == nil) {
        return nil;
    }
    NSDictionary *dict = RhParsePlistDict(raw); // .orb payload is a property list
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
