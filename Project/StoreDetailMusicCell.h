//
//  StoreDetailMusicCell.h
//  pop'n rhythmin
//
//  One song row in the iPhone StoreDetailViewController table: jacket + name + artist + a
//  "LEVEL b/m/h" line, an optional arcade-viewer badge, an iTunes link, and a sample-play
//  button with buffering / playing states. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithStyle:reuseIdentifier: @ 0x7457c, setLink: @ 0x7501c, sampleStop @
//  0x75094). The view build lives in StoreDetailMusicCell.m.
//

#import <UIKit/UIKit.h>

@interface StoreDetailMusicCell : UITableViewCell

@property (nonatomic, retain) UILabel *labelName;       // song title — getter @ 0x752c4
@property (nonatomic, retain) UILabel *labelArtist;     // artist — getter @ 0x752d4
@property (nonatomic, retain) UILabel *labelLevels;     // "LEVEL b/m/h" — getter @ 0x752e4
@property (nonatomic, retain) UIImageView *artworkView; // jacket — getter @ 0x752b4
@property (nonatomic, retain) UIView *arcadeViewer;     // arcade-chart badge — getter @ 0x75314

// The fixed content height of a song cell (the row height adds padding). Ghidra: +cellHeight.
+ (CGFloat)cellHeight;

// The row's stretchable background (even/odd alternates packBgImage0/1). Ghidra: setBgImage:.
- (void)setBgImage:(UIImage *)image;

// The song's iTunes page URL (the sample/link button opens it).
- (void)setLink:(NSString *)url;

// Sample-button state: idle, buffering the clip, or playing it.
- (void)sampleStop;
- (void)sampleDownloading;
- (void)samplePlaying;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
