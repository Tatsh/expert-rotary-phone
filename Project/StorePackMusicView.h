/**
 * @file
 * One song row inside the iPad pack-detail panel.
 *
 * A jacket (an async StoreImageView with a drop shadow), the title and artist labels, a
 * "LEVEL: b / m / h" line, a sample-preview button with a spinner, an iTunes-link button, and a
 * hidden arcade-availability badge. Four of these stack inside a StorePackDetailViewPad.
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (initWithFrame: @ 0x50b88,
 * setInfo: @ 0x51408, sampleStop @ 0x51748).
 */

#import <UIKit/UIKit.h>

@class StoreMusicInfo;
@class StoreImageView;

/**
 * One song row inside a store pack's detail card.
 */
@interface StorePackMusicView : UIView {
    UIImageView *m_BG;           /**< The full-bounds background. */
    StoreImageView *artworkView; /**< The asynchronously-loaded, shadowed jacket. */
    UILabel *labelName;          /**< The song title. */
    UILabel *labelArtist;        /**< The artist. */
    UILabel *labelLevels;        /**< The "LEVEL: b / m / h" line. */
    UIButton *buttonSample;      /**< Plays or stops the preview clip. */
    UIButton *buttonLink;        /**< Opens the iTunes page. */
    /** Shown over buttonSample while the clip buffers. */
    UIActivityIndicatorView *indicatorSample;
    UIImageView *arcadeViewer; /**< The "playable in arcade" badge; hidden by default. */
}

/**
 * Bind the row to a song, or clear it.
 * @param info The song to show; nil blanks the title, artist and levels, shows a placeholder
 * jacket, and hides the sample and link buttons.
 * @ghidraAddress 0x51408
 */
- (void)setInfo:(StoreMusicInfo *)info;

/**
 * Show or hide the arcade-availability badge.
 * @param isExistAcv YES when the song also exists in the arcade.
 * @ghidraAddress 0x5171c
 */
- (void)setIsExistAcv:(BOOL)isExistAcv;

/**
 * Reset the sample button to its idle image and stop its spinner.
 * @ghidraAddress 0x51748
 */
- (void)sampleStop;

/**
 * Enter the buffering state: start the spinner and keep the idle sample glyph.
 * @ghidraAddress 0x517bc
 */
- (void)sampleDownloading;

/**
 * Enter the playing state: stop the spinner and switch to the "stop" sample glyph.
 * @ghidraAddress 0x51830
 */
- (void)samplePlaying;

/**
 * The sample button; the parent compares it against a tapped control.
 * @return The button.
 * @ghidraAddress 0x51a24
 */
- (UIButton *)buttonSample;

/**
 * Pick the row background variant; the parent alternates it so stacked rows read as
 * distinct panels.
 * @param index 0 or 1; the value is clamped.
 * @ghidraAddress 0x518a4
 */
- (void)setBG:(int)index;

/**
 * The iTunes-link button; the parent wires its tap to -handleLink:.
 * @return The button.
 * @ghidraAddress 0x51a34
 */
- (UIButton *)buttonLink;

/**
 * The jacket view.
 * @return The image view.
 * @ghidraAddress 0x519e4
 */
- (StoreImageView *)artworkView;
/**
 * The song-title label.
 * @return The label.
 * @ghidraAddress 0x519f4
 */
- (UILabel *)labelName;
/**
 * The artist label.
 * @return The label.
 * @ghidraAddress 0x51a04
 */
- (UILabel *)labelArtist;
/**
 * The difficulty-levels label.
 * @return The label.
 * @ghidraAddress 0x51a14
 */
- (UILabel *)labelLevels;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
