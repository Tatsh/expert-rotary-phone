//
//  StoreMusicInfo.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreMusicInfo.h"
#import "StoreUtil.h"
#import "MusicManager.h"
#import "RhUtil.h"

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
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    // Reject entries without a positive id before allocating anything real.
    if ([dictionary[@"ID"] intValue] < 1) {
        [self release];
        return nil;
    }
    if ((self = [super init])) {
        m_MusicID = [dictionary[@"ID"] intValue];
        m_Name = [dictionary[@"Name"] retain];
        m_Artist = [dictionary[@"Artist"] retain];
        m_ItemURL = [dictionary[@"ItemURL"] retain];

        NSString *sample = dictionary[@"SampleURL"];
        if ([StoreUtil isValidURL:sample]) {
            m_SampleURL = [sample retain];
        }
        NSString *artwork = dictionary[@"ArtworkURL"];
        if ([StoreUtil isValidURL:artwork]) {
            m_ArtworkURL = [artwork retain];
        }
        NSString *itunes = dictionary[@"iTunesURL"];
        if ([StoreUtil isValidURL:itunes]) {
            m_iTunesURL = [itunes retain];
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

- (int)musicID       { return m_MusicID; }
- (NSString *)name       { return m_Name; }
- (NSString *)artist     { return m_Artist; }
- (NSString *)itemURL    { return m_ItemURL; }
- (NSString *)sampleURL  { return m_SampleURL; }
- (NSString *)artworkURL { return m_ArtworkURL; }
- (NSString *)iTunesURL  { return m_iTunesURL; }
- (int)lvBasic  { return m_LvBasic; }
- (int)lvMedium { return m_LvMedium; }
- (int)lvHard   { return m_LvHard; }

// @ 0x56678 — the purchased song file exists on disk (path resolved by MusicManager).
- (BOOL)fileExist {
    return RhFileExists([[MusicManager getInstance] getPathFromPurchased:m_MusicID]);
}

- (void)dealloc {
    [m_Name release];
    [m_Artist release];
    [m_ItemURL release];
    [m_SampleURL release];
    [m_ArtworkURL release];
    [m_iTunesURL release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
