/**
 * @file
 * One song row in the iPhone StoreDetailViewController table.
 *
 * It carries the jacket, name, artist, and a "LEVEL b/m/h" line, an optional arcade-viewer badge,
 * an iTunes link, and a sample-play button with buffering and playing states. Reconstructed from
 * Ghidra project rb420, program PopnRhythmin (initWithStyle:reuseIdentifier: @ 0x7457c, setLink: @
 * 0x7501c, sampleStop @ 0x75094). The view build lives in StoreDetailMusicCell.m.
 */

#import <UIKit/UIKit.h>

/**
 * One song row of the phone pack-detail screen.
 */
@interface StoreDetailMusicCell : UITableViewCell

/** The song title. Getter @ 0x752c4. */
@property(nonatomic, retain) UILabel *labelName;
/** The artist. Getter @ 0x752d4. */
@property(nonatomic, retain) UILabel *labelArtist;
/** The "LEVEL b/m/h" line. Getter @ 0x752e4. */
@property(nonatomic, retain) UILabel *labelLevels;
/** The jacket. Getter @ 0x752b4. */
@property(nonatomic, retain) UIImageView *artworkView;
/** The arcade-chart badge. Getter @ 0x75314. */
@property(nonatomic, retain) UIView *arcadeViewer;

/**
 * The fixed content height of a song cell; the row height adds padding.
 * @return The content height.
 */
+ (CGFloat)cellHeight;

/**
 * Set the row's stretchable background; the caller alternates packBgImage0 and
 * packBgImage1.
 * @param image The background image.
 */
- (void)setBgImage:(UIImage *)image;

/**
 * Set the song's iTunes page URL, which the link button opens.
 * @param url The iTunes URL.
 */
- (void)setLink:(NSString *)url;

/**
 * Put the sample button in its idle state.
 */
- (void)sampleStop;
/**
 * Put the sample button in its buffering state.
 */
- (void)sampleDownloading;
/**
 * Put the sample button in its playing state.
 */
- (void)samplePlaying;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
