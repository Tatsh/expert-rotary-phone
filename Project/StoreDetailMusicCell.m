//
//  StoreDetailMusicCell.m
//  pop'n rhythmin
//
//  See StoreDetailMusicCell.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0x7457c, setLink: @ 0x7501c, sampleStop @ 0x75094). The row
//  shows the song jacket (shadowed) over a tappable sample overlay (spinner while buffering, a
//  "play" glyph while playing), the name / artist / "LEVEL b/m/h" labels, an arcade badge, and an
//  iTunes-link button. Some frame origins are content-view-relative and NEON-spilled in the binary;
//  reconstructed with the byte-verified sizes and best-effort origins.
//

#import "StoreDetailMusicCell.h"

static NSString *const kCellFont = @"DFSoGei-W5-WIN-RKSJ-H";

@implementation StoreDetailMusicCell {
    UIImageView *bgView;                    // stretchable row background (the cell's backgroundView)
    UIView *sampleView;                     // dimmed overlay on the jacket while sampling
    UIActivityIndicatorView *indicator;     // buffering spinner (inside sampleView)
    UIImageView *playingView;               // "play" glyph shown while the clip plays
    UIButton *buttonLink;                   // iTunes-link button
    NSURL *linkURL;                         // the resolved iTunes URL (nil hides buttonLink)
}
@synthesize labelName, labelArtist, labelLevels, artworkView, arcadeViewer;

// @ 0x7501c — set the iTunes link (hides the link button when there is none).
- (void)setLink:(NSString *)url {
    linkURL = url ? [NSURL URLWithString:url] : nil;
    buttonLink.hidden = (linkURL == nil);
}

// The iTunes-link button opens the stored URL. Ghidra selector handleLink:.
- (void)handleLink:(id)sender {
    if (linkURL != nil) {
        [[UIApplication sharedApplication] openURL:linkURL];
    }
}

// @ 0x75094 — reset the sample overlay: stop the spinner and hide the overlay.
- (void)sampleStop {
    [indicator stopAnimating];
    sampleView.hidden = YES;
}

// Buffering the clip: show the dimmed overlay + spinner, hide the play glyph. Ghidra:
// sampleDownloading.
- (void)sampleDownloading {
    sampleView.hidden = NO;
    playingView.hidden = YES;
    [indicator startAnimating];
}

// The clip is playing: show the overlay + play glyph, stop the spinner. Ghidra: samplePlaying.
- (void)samplePlaying {
    sampleView.hidden = NO;
    [indicator stopAnimating];
    playingView.hidden = NO;
}

// The stretchable even/odd row background. Ghidra: setBgImage:.
- (void)setBgImage:(UIImage *)image {
    bgView.image = image;
}

// The fixed content height of a song cell (heightForRow adds padding). Best-effort constant
// matching the jacket area; Ghidra +cellHeight returns a fixed value.
+ (CGFloat)cellHeight {
    return 88.0f;
}

// @ 0x7457c — build the row's subviews inside the content view.
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
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;   // 0x12

    // Jacket (88x88) with a soft drop shadow.
    artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(8.0f, 8.0f, 88.0f, 88.0f)];
    [artworkView setImage:[UIImage imageNamed:@"store_jacket_128"]];
    artworkView.layer.shadowOffset = CGSizeMake(2.0f, 2.0f);
    artworkView.layer.shadowColor = [UIColor blackColor].CGColor;
    artworkView.layer.shadowOpacity = 0.6f;
    artworkView.layer.shadowRadius = 2.0f;
    artworkView.layer.shouldRasterize = YES;

    // Name (shrinks to fit), artist, and the level line — all to the right of the jacket.
    const CGFloat labelX = 110.0f;   // 0x42dc0000
    const CGFloat labelW = content.frame.size.width - labelX - 30.0f;   // content-relative in the binary
    labelName = [[UILabel alloc] initWithFrame:CGRectMake(labelX, 8.0f, labelW, 18.0f)];
    labelName.backgroundColor = [UIColor clearColor];
    labelName.font = [UIFont fontWithName:kCellFont size:14.0f];   // size dropped by the decompiler
    labelName.numberOfLines = 2;
    labelName.adjustsFontSizeToFitWidth = YES;
    labelName.minimumScaleFactor = 0.8f;   // 0x3f4ccccd

    labelArtist = [[UILabel alloc] initWithFrame:CGRectMake(labelX, 26.0f, labelW, 15.0f)];
    labelArtist.backgroundColor = [UIColor clearColor];
    labelArtist.font = [UIFont fontWithName:kCellFont size:12.0f];
    labelArtist.numberOfLines = 2;
    labelArtist.adjustsFontSizeToFitWidth = YES;
    labelArtist.minimumScaleFactor = 0.8f;

    labelLevels = [[UILabel alloc] initWithFrame:CGRectMake(labelX, 50.0f, labelX, 14.0f)];
    labelLevels.backgroundColor = [UIColor clearColor];
    labelLevels.font = [UIFont fontWithName:kCellFont size:12.0f];

    // Dimmed sample overlay covering the jacket: a spinner (buffering) + a play glyph (playing).
    sampleView = [[UIView alloc] initWithFrame:artworkView.frame];
    sampleView.opaque = NO;
    sampleView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8f];   // 0x3ecccccd
    CGPoint sampleCenter = CGPointMake(sampleView.frame.size.width * 0.5f,
                                       sampleView.frame.size.height * 0.5f);
    indicator = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, sampleCenter.x, sampleCenter.y)];
    indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;   // 0
    indicator.hidesWhenStopped = YES;
    indicator.center = sampleCenter;
    [sampleView addSubview:indicator];
    playingView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"store_play"]];
    playingView.center = sampleCenter;
    playingView.hidden = YES;
    [sampleView addSubview:playingView];

    // Arcade badge (hidden unless the song has an arcade chart) — bottom-right of the content.
    UIImage *arcadeImg = [UIImage imageNamed:@"store_arcade_view_ic"];
    arcadeViewer = [[UIImageView alloc] initWithImage:arcadeImg];
    arcadeViewer.frame = CGRectMake(content.frame.size.width - arcadeImg.size.width - 10.0f,
                                    75.0f, arcadeImg.size.width, arcadeImg.size.height);
    arcadeViewer.hidden = YES;

    // iTunes-link button — to the left of the arcade badge.
    buttonLink = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *itunesImg = [UIImage imageNamed:@"store_itunes"];
    buttonLink.frame = CGRectMake(content.frame.size.width - itunesImg.size.width - 10.0f,
                                  -15.0f, itunesImg.size.width, itunesImg.size.height);
    buttonLink.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin; // 9
    [buttonLink setBackgroundImage:itunesImg forState:UIControlStateNormal];
    [buttonLink addTarget:self action:@selector(handleLink:)
         forControlEvents:UIControlEventTouchUpInside];

    // Add everything to the content view (jacket, overlay, labels, link, arcade badge).
    [content addSubview:artworkView];
    [content addSubview:sampleView];
    [content addSubview:labelName];
    [content addSubview:labelArtist];
    [content addSubview:labelLevels];
    [content addSubview:buttonLink];
    [content addSubview:arcadeViewer];

    return self;
}

// dealloc — ARC-omitted (released object ivars only).

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
