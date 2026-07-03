//
//  StoreAcMusicInfo.h
//  pop'n rhythmin
//
//  One arcade-viewer song listed inside a store pack: id, title, genre, and the
//  purchase + sample links. Built from a server dictionary.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithDictionary: @ 0x852dc).
//

#import <Foundation/Foundation.h>

@interface StoreAcMusicInfo : NSObject {
    int m_AcMusicId;
    NSString *m_Title;
    NSString *m_Genre;
    NSString *m_ItemURL;
    NSString *m_SampleURL;
}

// Returns nil if the dictionary has no positive "ID".
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@property (nonatomic, readonly) int acMusicId;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *genre;
@property (nonatomic, readonly) NSString *itemURL;
@property (nonatomic, readonly) NSString *sampleURL;

// YES if this arcade song's purchased file is already on disk. Ghidra: @ 0x85418.
- (BOOL)fileExist;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
