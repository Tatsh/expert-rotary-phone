//
//  StoreMusicInfo.h
//  pop'n rhythmin
//
//  One playable song listed inside a store pack: id, title/artist, purchase +
//  sample + artwork + iTunes links, and the three difficulty levels (Basic /
//  Medium / Hard, each clamped to a valid range). Built from a server dictionary.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithDictionary: @ 0x56398).
//

#import <Foundation/Foundation.h>

@interface StoreMusicInfo : NSObject {
    int m_MusicID;
    NSString *m_Name;
    NSString *m_Artist;
    NSString *m_ItemURL;      // pack/product link
    NSString *m_SampleURL;    // preview clip (only kept if a valid http(s) URL)
    NSString *m_ArtworkURL;   // jacket (only kept if valid)
    NSString *m_iTunesURL;    // iTunes link (only kept if valid)
    int m_LvBasic;            // 1..10
    int m_LvMedium;           // 1..10
    int m_LvHard;             // 1..11
}

// Returns nil if the dictionary has no positive "ID".
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@property (nonatomic, readonly) int musicID;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *artist;
@property (nonatomic, readonly) NSString *itemURL;
@property (nonatomic, readonly) NSString *sampleURL;
@property (nonatomic, readonly) NSString *artworkURL;
@property (nonatomic, readonly) NSString *iTunesURL;
@property (nonatomic, readonly) int lvBasic;
@property (nonatomic, readonly) int lvMedium;
@property (nonatomic, readonly) int lvHard;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
