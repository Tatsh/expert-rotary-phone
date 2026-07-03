//
//  StorePackDetailViewPad.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePackDetailViewPad.h"
#import "StorePackInfo.h"
#import "StorePackInfoDownloader.h"
#import "StorePackMusicView.h"
#import "StoreImageView.h"
#import "StoreMusicInfo.h"
#import "Downloader.h"
#import "AudioManager.h"
#import "MusicManager.h"
#import "StoreUtil.h"
#import "CommonAlertView.h"
#import "PurchaseManager.h"
#import "AppDelegate.h"
#import "BirthDayViewController.h"
#import <StoreKit/StoreKit.h>
#import <QuartzCore/QuartzCore.h>   // CALayer shadow/rasterize

@implementation StorePackDetailViewPad

@synthesize packInfo = m_PackInfo;   // getter @ 0x50b48, setter @ 0x50b58 (objc_setProperty)
@synthesize delegate = m_Delegate;   // getter @ 0x50b68, setter @ 0x50b78

// @ 0x4dae8 — build the whole iPad pack-detail panel: a grey, soft-shadowed card holding the
// pack header (jacket + name + comment + copyright + buy button), a 2x2 grid of song rows, a
// centred loading spinner + caption, a hidden "web/artist-site" button, and a hidden dummy
// cover VC (shown during the recommend-pack POST). Geometry decoded from the NEON disassembly.
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return self;
    }

    // Match the main-screen scale on Retina (guarded so it is a no-op on pre-2x OSes).
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
        [self respondsToSelector:@selector(contentScaleFactor)]) {
        self.contentScaleFactor = [UIScreen mainScreen].scale;
    }
    self.userInteractionEnabled = YES;
    self.opaque = YES;

    // Soft drop shadow around the whole card.
    self.layer.shadowRadius = 8.0f;
    self.layer.shadowOffset = CGSizeZero;
    self.layer.shadowOpacity = 0.5f;
    self.layer.shouldRasterize = YES;
    self.backgroundColor = [UIColor grayColor];

    // --- pack header container (packView) with a stretchable background image ---
    UIImage *bg = [UIImage imageNamed:@"store_pack_bg_2.png"];
    packView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 650.0f, 226.0f)];
    UIImageView *bgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 650.0f, 226.0f)];
    [bgView setImage:[bg stretchableImageWithLeftCapWidth:4 topCapHeight:4]];
    [packView addSubview:bgView];

    // --- pack jacket (async), white bordered, drop-shadowed ---
    packArtworkView = [[StoreImageView alloc]
        initWithFrame:CGRectMake(18.0f, 33.0f, 160.0f, 160.0f)];
    packArtworkView.layer.borderWidth = 1.0f;
    packArtworkView.layer.borderColor = [UIColor whiteColor].CGColor;
    packArtworkView.backgroundColor = [UIColor whiteColor];
    packArtworkView.layer.shadowOffset = CGSizeMake(2.0f, 2.0f);
    packArtworkView.layer.shadowColor = [UIColor blackColor].CGColor;
    packArtworkView.layer.shadowOpacity = 0.6f;
    packArtworkView.layer.shadowRadius = 2.0f;
    packArtworkView.layer.shouldRasterize = YES;
    [packView addSubview:packArtworkView];

    // --- pack name (single line, shrinks to fit) ---
    labelPackName = [[UILabel alloc] initWithFrame:CGRectMake(195.0f, 30.0f, 420.0f, 28.0f)];
    labelPackName.backgroundColor = [UIColor clearColor];
    labelPackName.font = [UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:22.0f];
    labelPackName.adjustsFontSizeToFitWidth = YES;
    labelPackName.minimumScaleFactor = 18.0f;   // raw 0x41900000 in the binary (minimum-font-size semantics)
    [packView addSubview:labelPackName];

    // --- pack description (multi-line) ---
    labelComment = [[UILabel alloc] initWithFrame:CGRectMake(195.0f, 58.0f, 420.0f, 90.0f)];
    labelComment.backgroundColor = [UIColor clearColor];
    labelComment.numberOfLines = 0;
    labelComment.baselineAdjustment = UIBaselineAdjustmentNone;   // 2
    labelComment.font = [UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:13.0f];
    labelComment.textColor = [UIColor colorWithWhite:0.196f alpha:1.0f];   // 0x3e48c8c9
    [packView addSubview:labelComment];

    // --- copyright (small, non-editable text view) ---
    copyrightView = [[UITextView alloc] initWithFrame:CGRectMake(195.0f, 155.0f, 220.0f, 50.0f)];
    copyrightView.backgroundColor = [UIColor clearColor];
    copyrightView.editable = NO;
    copyrightView.font = [UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:10.0f];
    [packView addSubview:copyrightView];

    // --- buy / INSTALLED button (custom, three stretchable state backgrounds) ---
    buttonPurchase = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonPurchase.frame = CGRectMake(480.0f, 165.0f, 140.0f, 30.0f);
    [buttonPurchase setBackgroundImage:[[UIImage imageNamed:@"store_btn_normal_2.png"]
                                           stretchableImageWithLeftCapWidth:6 topCapHeight:6]
                              forState:UIControlStateNormal];
    [buttonPurchase setBackgroundImage:[[UIImage imageNamed:@"store_btn_clicked_2.png"]
                                           stretchableImageWithLeftCapWidth:6 topCapHeight:6]
                              forState:UIControlStateHighlighted];
    [buttonPurchase setBackgroundImage:[[UIImage imageNamed:@"store_btn_disabled.png"]
                                           stretchableImageWithLeftCapWidth:6 topCapHeight:6]
                              forState:UIControlStateDisabled];
    buttonPurchase.exclusiveTouch = YES;
    buttonPurchase.adjustsImageWhenDisabled = NO;
    buttonPurchase.titleLabel.textColor = [UIColor whiteColor];
    buttonPurchase.titleLabel.font = [UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:16.0f];
    buttonPurchase.titleLabel.shadowOffset = CGSizeMake(0, -1.0f);
    [buttonPurchase setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [buttonPurchase setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.6f]
                               forState:UIControlStateNormal];
    [buttonPurchase setTitleColor:[UIColor colorWithWhite:0.62f alpha:1.0f]
                         forState:UIControlStateDisabled];
    [buttonPurchase setTitleShadowColor:[UIColor colorWithWhite:1.0f alpha:0.6f]
                               forState:UIControlStateDisabled];
    [buttonPurchase addTarget:self action:@selector(doPurchase:)
             forControlEvents:UIControlEventTouchUpInside];
    [packView addSubview:buttonPurchase];
    [self addSubview:packView];

    // --- the up-to-4 song rows, laid out as a 2x2 grid below the 226-tall header ---
    for (int i = 0; i < 4; i++) {
        CGRect rowFrame = CGRectMake((i % 2) * 325.0f, (i / 2) * 212.0f + 226.0f, 325.0f, 212.0f);
        StorePackMusicView *row = [[StorePackMusicView alloc] initWithFrame:rowFrame];
        musicView[i] = row;
        [row setBG:(i > 1)];   // top rows use bg 0, bottom rows bg 1
        [row.buttonLink addTarget:self action:@selector(handleLink:)
                 forControlEvents:UIControlEventTouchUpInside];
        [row.buttonSample addTarget:self action:@selector(handleSample:)
                   forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:row];
    }

    // Start blank/hidden (nils the labels, hides the rows, resets the buy button, etc.).
    [self removePackInfo];

    const CGFloat selfW = self.frame.size.width;
    const CGFloat selfH = self.frame.size.height;

    // --- loading spinner, centred a little above the middle (attached when a fetch begins) ---
    indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];   // 1
    indicator.frame = CGRectMake(0, 0, 24.0f, 24.0f);
    indicator.center = CGPointMake(selfW * 0.5f, selfH * 0.5f - 15.0f);

    // --- "読み込み中..." caption, centred a little below the middle ---
    labelLoading = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200.0f, 24.0f)];
    labelLoading.backgroundColor = [UIColor clearColor];
    labelLoading.font = [UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:18.0f];
    labelLoading.textColor = [UIColor whiteColor];
    labelLoading.shadowColor = [UIColor colorWithWhite:0 alpha:0.4f];   // 0x3ecccccd
    labelLoading.shadowOffset = CGSizeMake(0, -1.0f);
    labelLoading.textAlignment = NSTextAlignmentCenter;   // 1
    labelLoading.text = @"読み込み中...";
    labelLoading.center = CGPointMake(selfW * 0.5f, selfH * 0.5f + 15.0f);
    isInfoLoaded = NO;

    // --- artist-site "web" button, right-anchored at x=628, hidden until a URL is present ---
    UIButton *webButton = [UIButton buttonWithType:UIButtonTypeCustom];
    webButton.backgroundColor = [UIColor clearColor];
    UIImage *webImg = [UIImage imageNamed:@"store_web.png"];
    [webButton setImage:webImg forState:UIControlStateNormal];
    [webButton sizeToFit];
    CGSize webSize = webImg ? webImg.size : CGSizeZero;
    webButton.frame = CGRectMake(628.0f - webSize.width, 18.0f, webSize.width, webSize.height);
    [webButton addTarget:self action:@selector(selectWebButton)
        forControlEvents:UIControlEventTouchUpInside];
    webButton.hidden = YES;
    [packView addSubview:webButton];
    m_ArtistSiteButton = webButton;

    // --- dummy cover VC: a 325x212 transparent panel (centred on self) with a 2x grey spinner,
    //     shown over a song row while a recommend-pack registration POST is in flight ---
    dummyView = [[UIViewController alloc] init];
    dummyView.view.frame = CGRectMake(325.0f, 438.0f, 325.0f, 212.0f);   // overridden by the centre below
    dummyView.view.center = CGPointMake(selfW * 0.5f, selfH * 0.5f);
    dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
    dummyView.view.hidden = YES;
    [self addSubview:dummyView.view];

    UIActivityIndicatorView *coverSpinner = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
    coverSpinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;   // 2
    coverSpinner.center = CGPointMake(162.5f, 96.0f);
    // The binary factors this into a -[UIView setAutoresizingCenter] category (keep the loading
    // spinner centred on resize); inlined here as the equivalent flexible-margin mask.
    indicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                 UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    coverSpinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    [coverSpinner startAnimating];
    [dummyView.view addSubview:coverSpinner];

    return self;
}

// packInfo (@ 0x50b48) / setPackInfo: (@ 0x50b58, objc_setProperty) are synthesized in the
// binary; the addresses are annotated on the @property in the header.

// @ 0x4f680 — kick the pack-detail download. No-op without a bound pack. If the pack already
// carries its song list (musicInfos != nil), just tint the card and show it; otherwise grey the
// card, attach + spin the loading spinner/label, drop any in-flight detail fetch, and start a
// fresh StorePackInfoDownloader (self is its delegate) fetching the full detail.
- (void)loadInfo {
    if (m_PackInfo == nil) {
        return;
    }
    if ([m_PackInfo musicInfos] == nil) {
        self.backgroundColor = [UIColor grayColor];
        [self addSubview:indicator];
        [self addSubview:labelLoading];
        [indicator startAnimating];
        if (m_StorePackInfoDownloader != nil) {
            [m_StorePackInfoDownloader cancel];
            m_StorePackInfoDownloader = nil;
        }
        m_StorePackInfoDownloader =
            [[StorePackInfoDownloader alloc] initWithStorePackInfo:m_PackInfo];
        [m_StorePackInfoDownloader setDelegate:(id)self];
        [m_StorePackInfoDownloader downloadDetail];
    } else {
        self.backgroundColor = [UIColor colorWithWhite:0.863f alpha:1.0f];   // raw 0x3f5ced91
        [self showPackInfo];
    }
}

// @ 0x4f318 — populate the detail card from the bound pack (once). Tint the background, fill in
// the name / comment / copyright / jacket URL, pick the right buy-button label, reveal the pack
// header, then for each of the 4 rows: if a song exists at that index bind it (flagging whether a
// playable .acv chart is present by matching acMusicId against the pack's acvMusicInfos) and show
// the row, else clear + hide it. Finally kick every artwork download, hide the artist button when
// there is no artist URL, and latch isInfoLoaded so this only runs once.
- (void)showPackInfo {
    if (isInfoLoaded) {
        return;
    }
    self.backgroundColor = [UIColor colorWithWhite:0.863f alpha:1.0f];   // raw 0x3f5ced91
    labelPackName.text = [m_PackInfo packName];
    labelComment.text = [m_PackInfo comment];
    copyrightView.text = [m_PackInfo copyright];
    packArtworkView.imageURL = [m_PackInfo artworkURL];
    [self selfCheckButtonText];
    packView.hidden = NO;

    NSArray *musicInfos = [m_PackInfo musicInfos];
    for (int i = 0; i < 4; i++) {
        if (i < [musicInfos count]) {
            StoreMusicInfo *info = [musicInfos objectAtIndex:i];

            // Is there an .acv (playable chart) for this song? Scan the pack's acvMusicInfos for
            // one whose acMusicId matches this song's musicID.
            BOOL isExistAcv = NO;
            if ([[m_PackInfo acvMusicInfos] count] != 0) {
                NSUInteger j = 0;
                do {
                    id acv = [[m_PackInfo acvMusicInfos] objectAtIndexedSubscript:j];
                    if ([acv acMusicId] == [info musicID]) {
                        isExistAcv = YES;
                        break;
                    }
                    j++;
                } while (j < [[m_PackInfo acvMusicInfos] count]);
            }

            [musicView[i] setIsExistAcv:isExistAcv];
            [musicView[i] setInfo:info];
            musicView[i].hidden = NO;
        } else {
            [musicView[i] setInfo:nil];
            musicView[i].hidden = YES;
        }
    }

    [packArtworkView startDownloadImage];
    for (int i = 0; i < 4; i++) {
        [musicView[i].artworkView startDownloadImage];
    }
    m_ArtistSiteButton.hidden = ([m_PackInfo artistURL] == nil);
    isInfoLoaded = YES;
}

// @ 0x4ef54 — pick the purchase button's label for the current state: no pack or not owned -> buy;
// owned but not fully downloaded -> install; owned + downloaded -> installed.
- (void)selfCheckButtonText {
    if (m_PackInfo != nil) {
        NSString *productID = [StoreUtil productIDForPackID:m_PackInfo.packID];
        if ([[PurchaseManager sharedManager] isPurchased:productID]) {
            if ([self allDownloaded]) {
                [self setButtonTextInstalled];
            } else {
                [self setButtonTextInstall];
            }
            return;
        }
    }
    [self setButtonTextBuy];
}

// @ 0x4f024 — "buy" state: title "購入 (<price>)", button enabled.
- (void)setButtonTextBuy {
    [buttonPurchase setTitle:[NSString stringWithFormat:@"購入 (%@)", m_PackInfo.priceString]
                    forState:UIControlStateNormal];
    [buttonPurchase setEnabled:YES];
}

// @ 0x4f0b8 — "install" state: localized "INSTALL", button enabled.
- (void)setButtonTextInstall {
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:@"INSTALL" value:@"" table:nil];
    [buttonPurchase setTitle:title forState:UIControlStateNormal];
    [buttonPurchase setEnabled:YES];
}

// @ 0x4f144 — "installing" state: localized "INSTALLING" on the disabled state, button disabled.
- (void)setButtonTextInstalling {
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:@"INSTALLING" value:@"" table:nil];
    [buttonPurchase setTitle:title forState:UIControlStateDisabled];
    [buttonPurchase setEnabled:NO];
}

// @ 0x4f1d0 — "installed" state: if already recommended, fall through to the greyed-out
// "INSTALLED" (setButtonTextInstalledForce); otherwise offer the still-tappable "友達に勧める"
// ("recommend to friends") label so the user can register the pack as recommended.
- (void)setButtonTextInstalled {
    if ([self isRecommended]) {
        [self setButtonTextInstalledForce];
        return;
    }
    NSString *title =
        [[NSBundle mainBundle] localizedStringForKey:@"友達に勧める" value:@"" table:nil];
    [buttonPurchase setTitle:title forState:UIControlStateNormal];
    [buttonPurchase setEnabled:YES];
}

// @ 0x4ecd0 — abort a pending pack-detail fetch. Re-points the downloader's delegate at
// this view (so any late callback is handled here, not by a stale delegate) before
// cancelling, then releases + nils it. The (id) cast keeps the assignment protocol-clean
// (the full detail view — StorePackInfoDownloaderDelegate conformance — is reconstructed
// with setPackInfo: @ 0x50b58).
- (void)cancelLoading {
    if (m_StorePackInfoDownloader != nil) {
        [m_StorePackInfoDownloader setDelegate:(id)self];
        [m_StorePackInfoDownloader cancel];
        m_StorePackInfoDownloader = nil;
    }
}

// @ 0x4ed28 — stop the preview clip and reset the rows.
- (void)stopSample {
    [m_SampleDownloader cancel];
    if (m_SampleDownloader != nil) {
        m_SampleDownloader = nil;
    }
    for (int i = 0; i < 4; i++) {
        [musicView[i] sampleStop];
    }
    samplePlaying = -1;
}

// @ 0x4fdf0 — a row's sample button was tapped. Find the row, then toggle: stop if it is
// already sampling, otherwise stop whatever is sampling and start fetching this row's clip
// (the Downloader callback plays it once the bytes arrive). BGM fades over 0.2s (DAT_00050078).
- (void)handleSample:(id)sender {
    for (int i = 0; i < 4; i++) {
        if ([musicView[i] buttonSample] != sender) {
            continue;
        }
        if (samplePlaying == i) {
            // Tapped the currently-playing row: stop it.
            [[AudioManager sharedManager] stopBgm:0.2f];
            [m_SampleDownloader cancel];
            if (m_SampleDownloader != nil) {
                m_SampleDownloader = nil;
            }
            [musicView[samplePlaying] sampleStop];
            samplePlaying = -1;
            return;
        }
        if (samplePlaying >= 0) {
            // A different row is playing: stop it first.
            [[AudioManager sharedManager] stopBgm:0.2f];
            [m_SampleDownloader cancel];
            if (m_SampleDownloader != nil) {
                m_SampleDownloader = nil;
            }
            [musicView[samplePlaying] sampleStop];
        }
        // Begin fetching this row's preview clip.
        StoreMusicInfo *info = [[m_PackInfo musicInfos] objectAtIndex:i];
        samplePlaying = i;
        [musicView[i] sampleDownloading];
        [m_SampleDownloader cancel];
        if (m_SampleDownloader != nil) {
            m_SampleDownloader = nil;
        }
        m_SampleDownloader =
            [[Downloader alloc] initWithURL:[NSURL URLWithString:info.sampleURL]
                                   delegate:(id)self];
        [m_SampleDownloader startDownloading];
        return;
    }
}

// @ 0x4fd04 — find the row whose iTunes button was tapped and open its song's iTunes page.
- (void)handleLink:(id)sender {
    for (int i = 0; i < 4; i++) {
        if ([musicView[i] buttonLink] != sender) {
            continue;
        }
        NSString *url = [[[m_PackInfo musicInfos] objectAtIndex:i] iTunesURL];
        if (url != nil) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
        }
        return;
    }
}

// @ 0x50080 — open the pack's artist website.
- (void)selectWebButton {
    NSString *url = [m_PackInfo artistURL];
    if (url == nil) {
        return;
    }
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

// @ 0x4fca4 — the actual "buy" entry point: forward to the delegate, which owns the
// StoreKit transaction (the big doPurchase: dispatcher decides whether to reach here).
- (void)doPurchase {
    if ([m_Delegate respondsToSelector:@selector(detailViewStartPurchase:)]) {
        [m_Delegate performSelector:@selector(detailViewStartPurchase:) withObject:m_PackInfo];
    }
}

// @ 0x4edb8 — the pack has songs and they are all downloaded (guards against an empty pack).
- (BOOL)allDownloaded {
    if (m_PackInfo != nil && [m_PackInfo musicInfos] != nil && [[m_PackInfo musicInfos] count] != 0) {
        return [m_PackInfo allDownloaded];
    }
    return NO;
}

// @ 0x50154 — the age-gate modal closed with a birthday now on record. Drop the modal and
// re-run the spending-limit gate: if the price is within limit, hand off to the delegate;
// otherwise show the "can't purchase any more this month" alert. Default price 573 yen when
// the pack has no bound product.
- (void)birthDayViewClose {
    m_BirthDayView = nil;

    int price = (m_PackInfo.product != nil) ? [m_PackInfo.product.price intValue] : 573;
    if ([StoreUtil isPurchasable:price]) {
        [self doPurchase];
    } else {
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:nil
                                            message:@"今月は、これ以上購入することは\nできません。"
                                           delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alert show];
    }
}

// @ 0x50278 — Downloader delegate: a fetch finished. Two flows share this callback:
//   * the sample-preview downloader -> play the clip as looping BGM (no fade) and flip the
//     row to its "playing" state, then drop the downloader;
//   * the recommend-registration POST -> on success persist the pack as recommended, mark the
//     button installed, award 300 treasure points (capped 9999) and show a success alert; on
//     an error-code response show a connection-error alert; either way drop the downloader and
//     hide the cover.
- (void)downloaderFinished:(Downloader *)downloader {
    if (m_SampleDownloader == downloader) {
        if (samplePlaying >= 0) {
            AudioManager *audio = [AudioManager sharedManager];
            [audio loadBgmData:[m_SampleDownloader getData] isLoop:YES];
            [audio playBgm:0.0f];
            [musicView[samplePlaying] samplePlaying];
        }
        m_SampleDownloader = nil;
        return;
    }

    if (recommendDownloader != downloader) {
        return;
    }

    NSDictionary *json = [downloader getDataInJSON];
    CommonAlertView *alert;
    if ([json objectForKey:@"ErrorCode"] == nil) {
        [[MusicManager getInstance] saveRecommendedPack:m_PackInfo.packID];
        [self setButtonTextInstalledForce];

        // Award 300 treasure points, capped at 9999 (Ghidra: (tp+300)<<16 vs 9999<<16).
        int tp = [UserSettingData treasurePoint] + 300;
        if (tp >= 9999) {
            tp = 9999;
        }
        [UserSettingData saveTreasurePoint:tp];

        recommendPackIdArr = nil;

        // NOTE: the success message is a treasure-bonus notice with the awarded amount (300);
        // the exact CFString (Ghidra cf_000000000, UTF-16) resisted clean extraction, so the
        // body here is best-effort. Title "成功" and the "OK" button are byte-verified.
        alert = [[CommonAlertView alloc]
            initWithTitle:@"成功"
                  message:[NSString stringWithFormat:@"宝箱ポイントを%dP獲得しました。", 300]
                 delegate:nil
        cancelButtonTitle:nil
        otherButtonTitles:@"OK"];
    } else {
        // Byte-verified: title "Error", message the network-connection failure text.
        alert = [[CommonAlertView alloc]
            initWithTitle:@"Error"
                  message:@"サーバに接続できません。\nネットワーク接続をご確認下さい。"
                 delegate:nil
        cancelButtonTitle:@"OK"
        otherButtonTitles:nil];
    }
    [alert show];

    recommendDownloader = nil;
    [dummyView.view setHidden:YES];
}

// @ 0x4eaa0 — clear the panel back to its empty state (before binding a new pack, and on
// teardown): stop the preview BGM, drop the bound pack, blank every text/image field, hide
// the sub-views, reset each song row, and pull the loading spinner + label out.
- (void)removePackInfo {
    [[AudioManager sharedManager] stopBgm:0.2f];
    self.packInfo = nil;
    self.backgroundColor = [UIColor grayColor];

    labelPackName.text = nil;
    labelComment.text = nil;
    copyrightView.text = nil;

    packArtworkView.image = [UIImage imageNamed:@"store_jacket_160.png"];
    packArtworkView.imageURL = nil;

    packView.hidden = YES;
    m_ArtistSiteButton.hidden = YES;

    for (int i = 0; i < 4; i++) {
        [musicView[i] setInfo:nil];
        musicView[i].hidden = YES;
    }

    [self stopSample];
    [indicator stopAnimating];
    [indicator removeFromSuperview];
    [labelLoading removeFromSuperview];
    isInfoLoaded = NO;
}

// @ 0x4f28c — mark the pack as installed: set the disabled-state title to the localized
// "INSTALLED" string and disable the button (called once a re-download / registration succeeds).
- (void)setButtonTextInstalledForce {
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:@"INSTALLED" value:@"" table:nil];
    [buttonPurchase setTitle:title forState:UIControlStateDisabled];
    [buttonPurchase setEnabled:NO];
}

// @ 0x4f828 — the purchase button's decision tree. Stop the preview audio, then branch on
// whether the pack is already owned:
//   * owned but not fully downloaded -> ask the host to re-download it;
//   * owned + downloaded + not yet recommended -> POST it to the "recommend" endpoint;
//   * not owned -> if a birthday is on record (or the gate was cancelled) run the spending-
//     limit check (buy, or show the "over limit" alert); otherwise show the age gate.
- (void)doPurchase:(id)sender {
    [[AudioManager sharedManager] stopBgm:0.2f];
    [self stopSample];

    PurchaseManager *pm = [PurchaseManager sharedManager];
    NSString *productID = [StoreUtil productIDForPackID:m_PackInfo.packID];
    if ([pm isPurchased:productID]) {
        if (![self allDownloaded]) {
            if ([m_Delegate respondsToSelector:@selector(reDownloadPackMusics:)]) {
                [m_Delegate performSelector:@selector(reDownloadPackMusics:) withObject:m_PackInfo];
            }
        } else if (![self isRecommended] && recommendDownloader == nil) {
            [dummyView.view setHidden:NO];
            NSString *uuid = [AppDelegate appDelegate].uuId;
            NSString *body = [NSString stringWithFormat:@"uuid=%@&pack_id=%d", uuid, m_PackInfo.packID];
            recommendDownloader =
                [[Downloader alloc] initWithURL:[StoreUtil recommendPackURL]
                                       delegate:(id)self
                                           Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                    ContextType:@"application/json"];
            [recommendDownloader startDownloading];
        }
        return;
    }

    // Not owned.
    [self stopSample];
    NSDate *bday = [UserSettingData birthDay];
    if (bday != nil || [UserSettingData isBirthDayCanceled]) {
        int price = (m_PackInfo.product != nil) ? [m_PackInfo.product.price intValue] : 573;
        if ([StoreUtil isPurchasable:price]) {
            [self doPurchase];
        } else if (bday != nil) {
            CommonAlertView *alert =
                [[CommonAlertView alloc] initWithTitle:nil
                                                message:@"今月は、これ以上購入することは\nできません。"
                                               delegate:nil
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil];
            [alert show];
        }
    } else if (m_BirthDayView == nil) {
        m_BirthDayView = [[BirthDayViewController alloc] init];
        m_BirthDayView.delegate = (id)self;
        [self addSubview:m_BirthDayView.view];
        [m_BirthDayView startOpenAnimation];
    }
}

// @ 0x4ee14 — is this pack recommended? Lazily fetch + cache the recommended-id list, then
// test this pack's id against it.
- (BOOL)isRecommended {
    if (recommendPackIdArr == nil) {
        recommendPackIdArr = [[MusicManager getInstance] getRecommendPackArray];
    }
    int packID = [m_PackInfo packID];
    for (NSNumber *num in recommendPackIdArr) {
        if (packID == [num intValue]) {
            return YES;
        }
    }
    return NO;
}

// @ 0x50100 — AudioManager BGM-finished callback (a looping preview clip reached its end): reset
// every row's sample button and mark nothing playing. No BGM stop here (the clip already ended).
- (void)finishBgm:(id)sender {
    for (int i = 0; i < 4; i++) {
        [musicView[i] sampleStop];
    }
    samplePlaying = -1;
}

// @ 0x505d8 — Downloader delegate: a fetch failed. For the preview downloader, reset the playing
// row and drop it; for the recommend-registration POST, drop it and hide the cover. Either way show
// the network-connection-error alert.
- (void)downloaderError:(Downloader *)downloader {
    if (m_SampleDownloader == downloader) {
        if (samplePlaying >= 0) {
            [musicView[samplePlaying] sampleStop];
            samplePlaying = -1;
        }
        m_SampleDownloader = nil;
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:@"Error"
                                            message:@"サーバに接続できません。\nネットワーク接続をご確認下さい。"
                                           delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alert show];
    } else if (recommendDownloader == downloader) {
        recommendDownloader = nil;
        [dummyView.view setHidden:YES];
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:@"Error"
                                            message:@"サーバに接続できません。\nネットワーク接続をご確認下さい。"
                                           delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alert show];
    }
}

// @ 0x507a4 — Downloader delegate: incremental progress. No-op in this view.
- (void)downloaderProceed:(Downloader *)downloader {
}

// @ 0x507a8 — StorePackInfoDownloader delegate: the pack detail arrived. Populate the card, stop
// and pull the loading spinner + caption, then unhook + drop the downloader.
- (void)storePackInfoDownloaderFinished:(StorePackInfoDownloader *)downloader {
    [self showPackInfo];
    [indicator stopAnimating];
    [indicator removeFromSuperview];
    [labelLoading removeFromSuperview];
    [m_StorePackInfoDownloader setDelegate:nil];
    m_StorePackInfoDownloader = nil;
}

// @ 0x50840 — StorePackInfoDownloader delegate: the detail fetch failed. Stop + pull the spinner
// and caption, show the network-error alert (self is the alert delegate, so tapping OK closes the
// detail view via commonAlertView:clickedButtonAtIndex:), then unhook + drop the downloader.
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)downloader {
    [indicator stopAnimating];
    [indicator removeFromSuperview];
    [labelLoading removeFromSuperview];
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"Error"
                                        message:@"サーバに接続できません。\nネットワーク接続をご確認下さい。"
                                       delegate:(id)self
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
    [alert show];
    [m_StorePackInfoDownloader setDelegate:nil];
    m_StorePackInfoDownloader = nil;
}

// @ 0x5093c — CommonAlertView delegate: a button was tapped. Ask the host to close the detail view.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if ([m_Delegate respondsToSelector:@selector(detailViewClose)]) {
        [m_Delegate performSelector:@selector(detailViewClose)];
    }
}

// @ 0x50990 — teardown. The binary is MRC: it releases packView, the 4 song rows, the jacket,
// the labels, the copyright/loading views and spinner, both downloaders, packInfo, the birthday
// modal and the cached recommend-id array, then calls [super dealloc]. Under ARC only the
// download-cancelling side effects are kept: unhook + cancel the in-flight detail fetch and cancel
// the in-flight preview clip.
- (void)dealloc {
    [m_StorePackInfoDownloader setDelegate:nil];
    [m_StorePackInfoDownloader cancel];
    [m_SampleDownloader cancel];
}

@end
