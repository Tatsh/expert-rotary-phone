//
//  StoreAcMusicInfo.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreAcMusicInfo.h"

#import "MusicManager.h"
#import "RhUtil.h"

@implementation StoreAcMusicInfo

// @ 0x852dc
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ([dictionary[@"ID"] intValue] <= 0) {
        return nil;
    }
    if ((self = [super init])) {
        m_AcMusicId = [dictionary[@"ID"] intValue];
        m_Title = dictionary[@"Title"];
        m_Genre = dictionary[@"Genre"];
        m_ItemURL = dictionary[@"ItemURL"];
        m_SampleURL = dictionary[@"SampleURL"];
    }
    return self;
}

// Trivial ivar getters. Ghidra: acMusicId @ 0x854e4, title @ 0x854f4, genre @
// 0x85504, itemURL @ 0x85514, sampleURL @ 0x85524.
- (int)acMusicId {
    return m_AcMusicId;
}
- (NSString *)title {
    return m_Title;
}
- (NSString *)genre {
    return m_Genre;
}
- (NSString *)itemURL {
    return m_ItemURL;
}
- (NSString *)sampleURL {
    return m_SampleURL;
}

// @ 0x85418 — the purchased arcade-music file exists on disk.
- (BOOL)fileExist {
    return RhFileExists([[MusicManager getInstance] getAcPathFromPurchased:m_AcMusicId]);
}

// dealloc @ 0x85458 — ARC-omitted (object ivars only).

@end
