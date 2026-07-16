//
//  StoreMusicInfo.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreMusicInfo.h"
#import "MusicManager.h"
#import "RhUtil.h"
#import "StoreUtil.h"

// Clamp a level into [lo, hi]; sub-range values pass through.
static int ClampLevel(int value, int lo, int hi) {
    if (value < lo) {
        return lo;
    }
    if (value > hi) {
        return hi;
    }
    return value;
}

@implementation StoreMusicInfo

// @ 0x56398
// @complete
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    // Reject entries without a positive id before allocating anything real.
    if ([dictionary[@"ID"] intValue] < 1) {
        return nil;
    }
    if ((self = [super init])) {
        m_MusicID = [dictionary[@"ID"] intValue];
        m_Name = dictionary[@"Name"];
        m_Artist = dictionary[@"Artist"];
        m_ItemURL = dictionary[@"ItemURL"];

        NSString *sample = dictionary[@"SampleURL"];
        if ([StoreUtil isValidURL:sample]) {
            m_SampleURL = sample;
        }
        NSString *artwork = dictionary[@"ArtworkURL"];
        if ([StoreUtil isValidURL:artwork]) {
            m_ArtworkURL = artwork;
        }
        NSString *itunes = dictionary[@"iTunesURL"];
        if ([StoreUtil isValidURL:itunes]) {
            m_iTunesURL = itunes;
        }

        // Difficulty triple lives in "Level" = [basic, medium, hard].
        NSArray *level = dictionary[@"Level"];
        if (level.count > 2) {
            m_LvBasic = [level[0] intValue];
            m_LvMedium = [level[1] intValue];
            m_LvHard = [level[2] intValue];
        }
        m_LvBasic = ClampLevel(m_LvBasic, 1, 10);
        m_LvMedium = ClampLevel(m_LvMedium, 1, 10);
        m_LvHard = ClampLevel(m_LvHard, 1, 11);
    }
    return self;
}

// Each getter below is a plain ivar load at its cited address (verified against
// the disassembly).
// @complete
- (int)musicID {
    return m_MusicID;
} // @ 0x5676c
- (NSString *)name {
    return m_Name;
} // @ 0x5677c
- (NSString *)artist {
    return m_Artist;
} // @ 0x5678c
- (NSString *)itemURL {
    return m_ItemURL;
} // @ 0x5679c
- (NSString *)artworkURL {
    return m_ArtworkURL;
} // @ 0x567ac
- (NSString *)sampleURL {
    return m_SampleURL;
} // @ 0x567bc
- (NSString *)iTunesURL {
    return m_iTunesURL;
} // @ 0x567cc
- (int)lvBasic {
    return m_LvBasic;
} // @ 0x567dc
- (int)lvMedium {
    return m_LvMedium;
} // @ 0x567ec
- (int)lvHard {
    return m_LvHard;
} // @ 0x567fc

// @ 0x56678 — the purchased song file exists on disk (path resolved by
// MusicManager).
// @complete
- (BOOL)fileExist {
    return RhFileExists([[MusicManager getInstance] getPathFromPurchased:m_MusicID]);
}

// dealloc @ 0x566b8 — ARC-omitted (object ivars only).

@end
