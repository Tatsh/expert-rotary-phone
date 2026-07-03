//
//  StorePackMusicView.m
//  pop'n rhythmin
//
//  See StorePackMusicView.h. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePackMusicView.h"

#import "StoreImageView.h"
#import "StoreMusicInfo.h"

// The app's Japanese UI font (Ghidra: FUN_0005ef9c returns cf_DFSoGei_W5_WIN_RKSJ_H).
static NSString *const kStoreFontName = @"DFSoGei-W5-WIN-RKSJ-H";

// Ghidra: FUN_00051370 — the row's little factory for a transparent, non-opaque label.
static UILabel *MakeClearLabel(CGRect frame) {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.opaque = NO;
    label.backgroundColor = [UIColor clearColor];
    return label;   // +1, caller owns
}

@implementation StorePackMusicView

// Ghidra: initWithFrame: @ 0x50b88 — build the row's subview tree. All frames are byte-
// verified from the decompile; the buttons are laid out but NOT wired here (the parent
// pack-detail view handles their taps), so there are no action targets to install.
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }

    // Background fills the row (added first, released — the view hierarchy owns it).
    m_BG = [[UIImageView alloc] initWithFrame:self.bounds];
    [self addSubview:m_BG];

    // Jacket: async image, white backing, 1pt white border + soft drop shadow.
    artworkView = [[StoreImageView alloc] initWithFrame:CGRectMake(18.0f, 76.0f, 110.0f, 110.0f)];
    artworkView.backgroundColor = [UIColor whiteColor];
    artworkView.image = [UIImage imageNamed:@"store_jacket_100.png"];
    artworkView.layer.borderWidth = 1.0f;
    artworkView.layer.borderColor = [UIColor whiteColor].CGColor;
    artworkView.layer.shadowOffset = CGSizeMake(2.0f, 2.0f);
    artworkView.layer.shadowColor = [UIColor blackColor].CGColor;
    artworkView.layer.shadowOpacity = 0.6f;         // 0x3f19999a
    artworkView.layer.shadowRadius = 2.0f;
    artworkView.layer.shouldRasterize = YES;

    // Title.
    labelName = MakeClearLabel(CGRectMake(18.0f, 15.0f, 244.0f, 22.0f));
    labelName.font = [UIFont fontWithName:kStoreFontName size:16.0f];

    // Artist (dark grey).
    labelArtist = MakeClearLabel(CGRectMake(18.0f, 35.0f, 244.0f, 20.0f));
    labelArtist.font = [UIFont fontWithName:kStoreFontName size:13.0f];
    labelArtist.textColor = [UIColor colorWithWhite:0.196f alpha:1.0f];   // 0x3e48c8c9

    // Sample-preview button + its buffering spinner (spinner is a subview of the button).
    buttonSample = [UIButton buttonWithType:UIButtonTypeCustom];
    [buttonSample setFrame:CGRectMake(277.0f, 20.0f, 32.0f, 35.0f)];
    buttonSample.contentMode = UIViewContentModeScaleAspectFit;
    [buttonSample setImage:[UIImage imageNamed:@"store_sample_1.png"] forState:UIControlStateNormal];

    indicatorSample = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
    indicatorSample.center = CGPointMake(buttonSample.frame.size.width * 0.5f,
                                         buttonSample.frame.size.height * 0.5f);
    indicatorSample.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;   // raw 2
    indicatorSample.hidesWhenStopped = YES;
    [buttonSample addSubview:indicatorSample];

    // iTunes-link button (background = the iTunes glyph, sized to the image).
    buttonLink = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *itunesImage = [UIImage imageNamed:@"store_itunes.png"];
    [buttonLink setFrame:CGRectMake(146.0f, 120.0f, itunesImage.size.width, itunesImage.size.height)];
    [buttonLink setBackgroundImage:itunesImage forState:UIControlStateNormal];

    // Level line.
    labelLevels = MakeClearLabel(CGRectMake(146.0f, 76.0f, 160.0f, 20.0f));
    labelLevels.font = [UIFont fontWithName:kStoreFontName size:15.0f];
    labelLevels.textColor = [UIColor colorWithRed:0.333f green:0.035f blue:0.471f alpha:1.0f];

    // Arcade-availability badge (hidden until setInfo: decides).
    UIImage *arcadeImage = [UIImage imageNamed:@"store_arcade_view_ic"];
    arcadeViewer = [[UIImageView alloc] initWithImage:arcadeImage];
    [arcadeViewer setFrame:CGRectMake(142.0f, 165.0f, arcadeImage.size.width, arcadeImage.size.height)];
    arcadeViewer.hidden = YES;

    // Assemble (matching the binary's add order / z-order).
    [self addSubview:artworkView];
    [self addSubview:labelName];
    [self addSubview:labelArtist];
    [self addSubview:labelLevels];
    [self addSubview:arcadeViewer];
    [self addSubview:buttonSample];
    [self addSubview:buttonLink];

    return self;
}

// Ghidra: setInfo: @ 0x51408 — bind or clear the row from a StoreMusicInfo.
- (void)setInfo:(StoreMusicInfo *)info {
    if (info == nil) {
        labelName.text = nil;
        labelArtist.text = nil;
        labelLevels.text = nil;
        artworkView.imageURL = nil;
        artworkView.image = [UIImage imageNamed:@"store_jacket_100.png"];
        buttonLink.hidden = YES;
        buttonSample.hidden = YES;
        return;
    }

    labelName.text = info.name;
    labelArtist.text = info.artist;

    // Hard level 11 displays as "10+" (Ghidra cf_10_; the exact glyph is obscured by the
    // decompiler, "10+" is the conventional bonus-level label — best effort).
    NSString *hard = (info.lvHard == 11) ? @"10+"
                                         : [NSString stringWithFormat:@"%d", info.lvHard];
    labelLevels.text = [NSString stringWithFormat:@"LEVEL:  %d / %d / %@",
                                                  info.lvBasic, info.lvMedium, hard];

    artworkView.imageURL = info.artworkURL;
    artworkView.image = [UIImage imageNamed:@"store_jacket_100.png"];

    buttonSample.hidden = (info.sampleURL == nil);
    buttonLink.hidden = (info.iTunesURL == nil);
}

// Ghidra: sampleStop @ 0x51748 — return the sample button to idle.
- (void)sampleStop {
    [indicatorSample stopAnimating];
    [buttonSample setImage:[UIImage imageNamed:@"store_sample_1.png"] forState:UIControlStateNormal];
}

// Ghidra: sampleDownloading @ 0x517bc — buffering: spinner on, button stays the idle glyph.
- (void)sampleDownloading {
    [indicatorSample startAnimating];
    [buttonSample setImage:[UIImage imageNamed:@"store_sample_1.png"] forState:UIControlStateNormal];
}

// Ghidra: samplePlaying @ 0x51830 — playback started: spinner off, button shows the "stop"
// glyph (store_sample_2).
- (void)samplePlaying {
    [indicatorSample stopAnimating];
    [buttonSample setImage:[UIImage imageNamed:@"store_sample_2.png"] forState:UIControlStateNormal];
}

// Ghidra: setIsExistAcv: @ 0x5171c — toggle the arcade-availability badge: the badge is
// shown iff the song is playable in the arcade (arcadeViewer.hidden = NO when isExistAcv is
// YES). Byte-verified: [arcadeViewer setHidden:(isExistAcv == 0)].
- (void)setIsExistAcv:(BOOL)isExistAcv {
    arcadeViewer.hidden = (isExistAcv == NO);
}

// Ghidra: buttonSample @ 0x51a24 — the sample button accessor.
- (UIButton *)buttonSample {
    return buttonSample;
}

// Plain ivar accessors (parent reads these to configure the row).
- (StoreImageView *)artworkView {   // @ 0x519e4
    return artworkView;
}

- (UILabel *)labelName {   // @ 0x519f4
    return labelName;
}

- (UILabel *)labelArtist {   // @ 0x51a04
    return labelArtist;
}

- (UILabel *)labelLevels {   // @ 0x51a14
    return labelLevels;
}

// The iTunes-link button accessor (parent wires its tap). Ghidra: @ 0x51a34.
- (UIButton *)buttonLink {
    return buttonLink;
}

// Ghidra: setBG: @ 0x518a4 — choose the stretchable row-background image (index clamped to
// 0/1). The table is inverted in the binary: index 0 -> store_pack_bg_1, index 1 ->
// store_pack_bg_0 (byte-verified via the DAT_00131cb8 pointer table).
- (void)setBG:(int)index {
    if (index < 0) {
        index = 0;
    } else if (index > 1) {
        index = 1;
    }
    static NSString *const kRowBGNames[2] = { @"store_pack_bg_1.png", @"store_pack_bg_0.png" };
    UIImage *bg = [[UIImage imageNamed:kRowBGNames[index]] stretchableImageWithLeftCapWidth:4
                                                                              topCapHeight:4];
    m_BG.image = bg;
}

// dealloc @ 0x5191c — ARC-omitted (released object ivars only: artworkView, labelName,
// labelArtist, labelLevels, buttonSample, indicatorSample, buttonLink).

@end
