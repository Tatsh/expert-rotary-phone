//
//  StoreAcMusicInfo.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreAcMusicInfo.h"

@implementation StoreAcMusicInfo

// @ 0x852dc
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ([dictionary[@"ID"] intValue] <= 0) {
        [self release];
        return nil;
    }
    if ((self = [super init])) {
        m_AcMusicId = [dictionary[@"ID"] intValue];
        m_Title = [dictionary[@"Title"] retain];
        m_Genre = [dictionary[@"Genre"] retain];
        m_ItemURL = [dictionary[@"ItemURL"] retain];
        m_SampleURL = [dictionary[@"SampleURL"] retain];
    }
    return self;
}

- (int)acMusicId        { return m_AcMusicId; }
- (NSString *)title      { return m_Title; }
- (NSString *)genre      { return m_Genre; }
- (NSString *)itemURL    { return m_ItemURL; }
- (NSString *)sampleURL  { return m_SampleURL; }

- (void)dealloc {
    [m_Title release];
    [m_Genre release];
    [m_ItemURL release];
    [m_SampleURL release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
