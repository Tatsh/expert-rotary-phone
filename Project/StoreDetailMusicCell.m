//
//  StoreDetailMusicCell.m
//  pop'n rhythmin
//
//  See StoreDetailMusicCell.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin (initWithStyle:reuseIdentifier: @ 0x7457c, setLink: @ 0x7501c,
//  sampleStop @ 0x75094). The row shows the song jacket (shadowed) over a
//  tappable sample overlay (spinner while buffering, a "play" glyph while
//  playing), the name / artist / "LEVEL b/m/h" labels, an arcade badge, and an
//  iTunes-link button. All frame constants are byte-verified from the literal
//  pool.
//

#import "StoreDetailMusicCell.h"

static NSString *const kCellFont = @"DFSoGei-W5-WIN-RKSJ-H";

@interface StoreDetailMusicCell ()
// The resolved iTunes URL (nil hides buttonLink). Backed by the `linkURL` ivar.
@property(nonatomic, retain) NSURL *linkURL; // getter @ 0x752f4, setter @ 0x75304
@end

@implementation StoreDetailMusicCell {
    UIImageView *bgView;                // stretchable row background (the cell's backgroundView)
    UIView *sampleView;                 // dimmed overlay on the jacket while sampling
    UIActivityIndicatorView *indicator; // buffering spinner (inside sampleView)
    UIImageView *playingView;           // "play" glyph shown while the clip plays
    UIButton *buttonLink;               // iTunes-link button
}
// linkURL is a private @property (accessors below); the other views are
// @synthesize'd.
@synthesize labelName, labelArtist, labelLevels, artworkView, arcadeViewer, linkURL;

// @ 0x7501c — set the iTunes link (hides the link button when there is none).
// @complete
- (void)setLink:(NSString *)url {
    linkURL = url ? [NSURL URLWithString:url] : nil;
    buttonLink.hidden = (linkURL == nil);
}

// @ 0x74fb0 — the iTunes-link button opens the stored URL. Ghidra selector
// handleLink:.
// @complete
- (void)handleLink:(id)sender {
    if (linkURL != nil) {
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        [[UIApplication sharedApplication] openURL:linkURL options:@{} completionHandler:nil];
#else
        [[UIApplication sharedApplication] openURL:linkURL];
#endif
    }
}

// @ 0x75094 — reset the sample overlay: stop the spinner and hide the overlay.
// @complete
- (void)sampleStop {
    [indicator stopAnimating];
    sampleView.hidden = YES;
}

// @ 0x750dc — buffering the clip: start the spinner, hide the play glyph, show
// the overlay.
// @complete
- (void)sampleDownloading {
    [indicator startAnimating];
    playingView.hidden = YES;
    sampleView.hidden = NO;
}

// @ 0x7513c — the clip is playing: stop the spinner, show the play glyph +
// overlay.
// @complete
- (void)samplePlaying {
    [indicator stopAnimating];
    playingView.hidden = NO;
    sampleView.hidden = NO;
}

// @ 0x74ffc — the stretchable even/odd row background. Ghidra: setBgImage:.
// @complete
- (void)setBgImage:(UIImage *)image {
    bgView.image = image;
}

// The fixed content height of a song cell (heightForRow adds padding).
// @ 0x74574 — returns the immediate 0x42a00000 (movt r0,#0x42a0; softfp float
// in r0).
// @complete
+ (CGFloat)cellHeight {
    return 80.0f;
}

// @ 0x7457c — build the row's subviews inside the content view.
// @complete
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self == nil) {
        return self;
    }
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    UIView *content = self.contentView;

    // Stretchable row background.
    bgView = [[UIImageView alloc] initWithFrame:self.bounds];
    self.backgroundView = bgView;
    self.backgroundView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; // 0x12

    // Jacket (88x88) with a soft drop shadow.
    artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(8.0f, 8.0f, 88.0f, 88.0f)];
    [artworkView setImage:[UIImage imageNamed:@"store_jacket_128"]];
    artworkView.layer.shadowOffset = CGSizeMake(2.0f, 2.0f);
    artworkView.layer.shadowColor = [UIColor blackColor].CGColor;
    artworkView.layer.shadowOpacity = 0.6f;
    artworkView.layer.shadowRadius = 2.0f;
    artworkView.layer.shouldRasterize = YES;

    // Name (shrinks to fit), artist, and the level line — all to the right of the
    // jacket.
    const CGFloat labelX = 110.0f; // 0x42dc0000
    // @ 0x749c0: vldr.32 s0,[pc,#0x3a4] → literal@0x74b84 = 0xc2f00000 = −120.0;
    // vadd content.width + (−120) → labelW = content.width − 120.
    const CGFloat labelW = content.frame.size.width - 120.0f; // 0xc2f00000
    labelName = [[UILabel alloc] initWithFrame:CGRectMake(labelX, 8.0f, labelW, 18.0f)];
    labelName.backgroundColor = [UIColor clearColor];
    labelName.font = [UIFont fontWithName:kCellFont size:15.0f]; // @ 0x748c8 movt #0x4170 = 15.0
    // Ghidra sel_setAutoresizingMask_ with arg 2, not setNumberOfLines:; the
    // binary emits it twice for this label (a redundant repeat), modelled once.
    labelName.autoresizingMask = UIViewAutoresizingFlexibleWidth; // 0x2
    labelName.adjustsFontSizeToFitWidth = YES;
    labelName.minimumScaleFactor = 0.8f; // 0x3f4ccccd

    labelArtist = [[UILabel alloc] initWithFrame:CGRectMake(labelX, 26.0f, labelW, 15.0f)];
    labelArtist.backgroundColor = [UIColor clearColor];
    labelArtist.font = [UIFont fontWithName:kCellFont size:12.0f];
    labelArtist.autoresizingMask =
        UIViewAutoresizingFlexibleWidth; // 0x2 (sel_setAutoresizingMask_)
    labelArtist.adjustsFontSizeToFitWidth = YES;
    labelArtist.minimumScaleFactor = 0.8f;

    labelLevels = [[UILabel alloc] initWithFrame:CGRectMake(labelX, 50.0f, labelX, 14.0f)];
    labelLevels.backgroundColor = [UIColor clearColor];
    labelLevels.font = [UIFont fontWithName:kCellFont size:12.0f];

    // Dimmed sample overlay covering the jacket: a spinner (buffering) + a play
    // glyph (playing).
    sampleView = [[UIView alloc] initWithFrame:artworkView.frame];
    sampleView.opaque = NO;
    sampleView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4f]; // 0x3ecccccd
    CGPoint sampleCenter =
        CGPointMake(sampleView.frame.size.width * 0.5f, sampleView.frame.size.height * 0.5f);
    indicator = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, sampleCenter.x, sampleCenter.y)];
    indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge; // 0
    indicator.hidesWhenStopped = YES;
    indicator.center = sampleCenter;
    [sampleView addSubview:indicator];
    playingView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"store_play"]];
    playingView.center = sampleCenter;
    playingView.hidden = YES;
    [sampleView addSubview:playingView];

    // Arcade badge (hidden unless the song has an arcade chart) — bottom-right of
    // the content.
    UIImage *arcadeImg = [UIImage imageNamed:@"store_arcade_view_ic"];
    arcadeViewer = [[UIImageView alloc] initWithImage:arcadeImg];
    arcadeViewer.frame = CGRectMake(content.frame.size.width - arcadeImg.size.width - 10.0f,
                                    75.0f,
                                    arcadeImg.size.width,
                                    arcadeImg.size.height);
    arcadeViewer.hidden = YES;

    // iTunes-link button — to the left of the arcade badge.
    buttonLink = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *itunesImg = [UIImage imageNamed:@"store_itunes"];
    buttonLink.frame = CGRectMake(content.frame.size.width - itunesImg.size.width - 10.0f,
                                  -15.0f,
                                  itunesImg.size.width,
                                  itunesImg.size.height);
    buttonLink.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin; // 9
    [buttonLink setBackgroundImage:itunesImg forState:UIControlStateNormal];
    [buttonLink addTarget:self
                   action:@selector(handleLink:)
         forControlEvents:UIControlEventTouchUpInside];

    // Add everything to the content view (jacket, overlay, labels, link, arcade
    // badge).
    [content addSubview:artworkView];
    [content addSubview:sampleView];
    [content addSubview:labelName];
    [content addSubview:labelArtist];
    [content addSubview:labelLevels];
    [content addSubview:buttonLink];
    [content addSubview:arcadeViewer];

    return self;
}

// dealloc @ 0x7519c — ARC-omitted: the binary only -releases object ivars
// (bgView, artworkView, labelName, labelArtist, labelLevels, sampleView,
// indicator, playingView, buttonLink, linkURL, arcadeViewer) before [super
// dealloc]; nothing to cancel.

@end
