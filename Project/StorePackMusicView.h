//
//  StorePackMusicView.h
//  pop'n rhythmin
//
//  One song row inside the iPad pack-detail panel: a jacket (async StoreImageView with a
//  drop shadow), the title + artist labels, a "LEVEL: b / m / h" line, a sample-preview
//  button with a spinner, an iTunes-link button, and a hidden arcade-availability badge.
//  Four of these stack inside a StorePackDetailViewPad. Reconstructed from Ghidra project
//  rb420, program PopnRhythmin (initWithFrame: @ 0x50b88, setInfo: @ 0x51408,
//  sampleStop @ 0x51748).
//

#import <UIKit/UIKit.h>

@class StoreMusicInfo;
@class StoreImageView;

@interface StorePackMusicView : UIView {
    UIImageView *m_BG;                          // full-bounds background
    StoreImageView *artworkView;                // async jacket (shadowed)
    UILabel *labelName;                         // song title
    UILabel *labelArtist;                       // artist
    UILabel *labelLevels;                       // "LEVEL:  b / m / h"
    UIButton *buttonSample;                     // play/stop the preview clip
    UIButton *buttonLink;                       // open the iTunes page
    UIActivityIndicatorView *indicatorSample;   // shown over buttonSample while buffering
    UIImageView *arcadeViewer;                  // "playable in arcade" badge (hidden by default)
}

// Bind the row to a song, or clear it (title/artist/levels blanked, placeholder jacket,
// sample/link buttons hidden) when info is nil. Ghidra: setInfo: @ 0x51408.
- (void)setInfo:(StoreMusicInfo *)info;

// Reset the sample button to its idle image and stop its spinner. Ghidra: @ 0x51748.
- (void)sampleStop;

// Buffering: start the spinner, keep the idle sample glyph. Ghidra: @ 0x517bc.
- (void)sampleDownloading;

// Now playing: stop the spinner, switch to the "stop" sample glyph. Ghidra: @ 0x51830.
- (void)samplePlaying;

// The sample button (the parent compares it against a tapped control). Ghidra: @ 0x51a24.
- (UIButton *)buttonSample;

// Pick the row background variant (0 or 1, clamped): the parent alternates it so stacked
// rows read as distinct panels. Ghidra: @ 0x518a4. The sample/link buttons are exposed via
// -buttonSample / -buttonLink so the parent can wire their taps.
- (void)setBG:(int)index;

// The iTunes-link button (parent wires its tap to -handleLink:). Ghidra ivar buttonLink.
- (UIButton *)buttonLink;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
