//
//  StoreDetailViewController.m
//  pop'n rhythmin
//
//  See StoreDetailViewController.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. -init and -loadView are byte/disasm-reconstructed; the table data-source /
//  delegate rows, sample playback and StoreDetailHeaderView build are a separate piece (see
//  HANDOFF.md), stubbed here so the class is well-formed.
//

#import "StoreDetailViewController.h"
#import "StoreDetailHeaderView.h"
#import "StorePackInfo.h"
#import "StorePackInfoDownloader.h"
#import "ImageDownloader.h"
#import "Downloader.h"
#import "MusicManager.h"
#import "AudioManager.h"
#import "PurchaseManager.h"
#import "StoreUtil.h"
#import "CommonAlertView.h"
#import "StoreDetailCopyrightCell.h"
#import "StoreDetailMusicCell.h"
#import "StoreMusicInfo.h"
#import "StoreAcMusicInfo.h"
#import "UserSettingData.h"
#import "AppDelegate.h"
#import "BirthDayViewController.h"
#import "System/src/neEngineBridge.h"   // neEngine::playSystemSe (decide SE)
#import <StoreKit/StoreKit.h>   // SKProduct.price

// Private methods reconstructed alongside the content-load flow.
@interface StoreDetailViewController ()
- (void)selfCheckButtonText;
- (void)storePackInfoDownloaderFinished:(id)downloader;
- (void)storePackInfoDownloaderError:(id)downloader;
- (void)birthDayViewClose;
- (void)setButtonTextInstalledForce;
- (void)downloaderFinished:(id)downloader;
- (void)downloaderError:(id)downloader;
- (void)downloaderProceed:(id)downloader;
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath;
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath;
- (void)stopDownloadArtworks;
- (void)setButtonTextBuy;
- (void)setButtonTextInstall;
- (void)setButtonTextInstalling;
- (void)setButtonTextInstalled;
- (void)setButtonTextInstalledForce;
- (void)setButtonTextRecommend;
@end

@implementation StoreDetailViewController

@synthesize packInfo;
@synthesize delegate;

// @ 0x6f8c0 — a plain view controller with a custom "back" button (navi_btn_back) installed as
// the navigation item's left bar button.
- (id)init {
    self = [super init];
    if (self != nil) {
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        CGSize sz = backImg ? backImg.size : CGSizeZero;
        UIButton *backBtn = [[[UIButton alloc]
            initWithFrame:CGRectMake(0, 0, sz.width, sz.height)] autorelease];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(backButtonFunc)
          forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *item = [[[UIBarButtonItem alloc]
            initWithCustomView:backBtn] autorelease];
        self.navigationItem.leftBarButtonItem = item;
    }
    return self;
}

// @ 0x6fa3c — build the view tree. (setAutoresizingSize / setAutoresizingCenter are UIView
// category helpers in the app; inlined here as the equivalent autoresizing masks.)
- (void)loadView {
    [super loadView];

    if (recommendPackIdArr == nil) {
        recommendPackIdArr = [[[MusicManager getInstance] getRecommendPackArray] retain];
    }

    self.view.opaque = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor grayColor];
    const CGRect bounds = self.view ? self.view.bounds : CGRectZero;
    const CGFloat cx = bounds.size.width * 0.5f;
    const CGFloat cy = bounds.size.height * 0.5f;

    // --- the song table (hidden until the detail loads) ---
    UITableView *table = [[[UITableView alloc]
        initWithFrame:bounds style:UITableViewStylePlain] autorelease];
    table.opaque = YES;
    table.backgroundColor = [UIColor colorWithWhite:0.4f alpha:1.0f];   // 0x3ecccccd
    table.separatorStyle = UITableViewCellSeparatorStyleNone;
    table.dataSource = self;
    table.delegate = self;
    table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    table.hidden = YES;
    [self.view addSubview:table];
    m_PackTableView = table;

    // --- table header: jacket + name + buy button ---
    m_HeaderView = [[StoreDetailHeaderView alloc] initWithFrame:m_PackTableView.bounds];
    m_HeaderView.autoresizingMask = UIViewAutoresizingFlexibleWidth;   // raw mask 2
    UIButton *buy = [m_HeaderView buttonPurchase];
    [buy setTitle:[NSString stringWithFormat:@"¥%@", packInfo.priceString]
         forState:UIControlStateNormal];
    buy.exclusiveTouch = YES;
    [buy addTarget:self action:@selector(onPurchaseButton:)
        forControlEvents:UIControlEventTouchUpInside];
    [buy setTitle:@"購入済み" forState:UIControlStateDisabled];   // best-effort (owned-state title)

    // --- "読み込み中..." overlay with a spinner ---
    UILabel *accessing = [[[UILabel alloc] initWithFrame:bounds] autorelease];
    accessing.backgroundColor = [UIColor clearColor];
    accessing.font = [UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:18.0f];
    accessing.textColor = [UIColor colorWithWhite:0.2f alpha:1.0f];    // 0x3e4ccccd
    accessing.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.3f];  // 0x3e99999a
    accessing.shadowOffset = CGSizeMake(0, 1.0f);
    accessing.textAlignment = NSTextAlignmentCenter;
    accessing.center = CGPointMake(cx, cy + 20.0f);
    accessing.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    accessing.text = @"読み込み中...";
    accessing.hidden = YES;
    [self.view addSubview:accessing];
    m_AccessingLabel = accessing;

    UIActivityIndicatorView *spin = [[[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)] autorelease];
    spin.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    spin.center = CGPointMake(cx, cy - 10.0f);
    spin.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [spin startAnimating];
    [m_AccessingLabel addSubview:spin];
    m_AccessingIndicator = spin;

    // --- stretchable per-row backgrounds (even/odd) ---
    packBgImage0 = [[[UIImage imageNamed:@"store_pack_bg_0"]
        stretchableImageWithLeftCapWidth:4 topCapHeight:4] retain];
    packBgImage1 = [[[UIImage imageNamed:@"store_pack_bg_1"]
        stretchableImageWithLeftCapWidth:4 topCapHeight:4] retain];

    artworkDownloaders = [[NSMutableDictionary alloc] initWithCapacity:32];

    // --- dummy cover (transparent, hidden) with a 2x spinner, shown during purchase work ---
    dummyView = [[UIViewController alloc] init];
    dummyView.view.frame = bounds;
    dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
    dummyView.view.hidden = YES;
    [self.view addSubview:dummyView.view];

    UIActivityIndicatorView *coverSpin = [[[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)] autorelease];
    coverSpin.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    coverSpin.center = CGPointMake(cx, cy - 10.0f);
    coverSpin.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                 UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    coverSpin.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    [coverSpin startAnimating];
    [dummyView.view addSubview:coverSpin];

    rowSamplePlayed = -1;
}

// @ 0x7286c — nothing beyond the superclass hook.
- (void)viewDidLoad {
    [super viewDidLoad];
}

// @ 0x72970 — release every owned ivar (the table / labels / spinners are hierarchy-owned and
// are not released here). Cancels the in-flight detail + sample downloads first.
- (void)dealloc {
    if (m_HeaderView != nil) {
        [m_HeaderView release];
        m_HeaderView = nil;
    }
    [m_StorePackInfoDownloader setDelegate:nil];
    [m_StorePackInfoDownloader cancel];
    if (m_StorePackInfoDownloader != nil) {
        [m_StorePackInfoDownloader release];
        m_StorePackInfoDownloader = nil;
    }
    [sampleDownloader cancel];
    [sampleDownloader release];
    [packBgImage0 release];
    [packBgImage1 release];
    [self stopDownloadArtworks];
    [artworkDownloaders release];
    [packInfo release];
    [dummyView release];
    if (recommendPackIdArr != nil) {
        [recommendPackIdArr release];
    }
    [super dealloc];
}

// Ghidra: selector backButtonFunc. Best-effort: pop this detail screen off the nav stack (the
// method body is not yet decompiled; this is the standard custom-back-button behaviour).
- (void)backButtonFunc {
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0x706a4 — the buy button decision tree (phone parallel of StorePackDetailViewPad -doPurchase:).
// Owned: re-download the missing songs, or register the pack as "recommended" (a POST). Not owned:
// once a birthday is on record, spending-limit-check -> StoreKit purchase (or an over-limit alert);
// otherwise show the age gate first.
- (void)onPurchaseButton:(id)sender {
    neEngine::playSystemSe(1);   // decide SE (Ghidra: SysSePlayIntoSlot(1))

    NSString *productID = [StoreUtil productIDForPackID:[packInfo packID]];
    if ([[PurchaseManager sharedManager] isPurchased:productID]) {
        // --- already owned ---
        if (![self allDownloaded]) {
            if ([delegate respondsToSelector:@selector(reDownloadPackMusics:)]) {
                [delegate performSelector:@selector(reDownloadPackMusics:) withObject:packInfo];
            }
            return;
        }
        if ([self isRecommended]) {
            return;   // already recommended
        }
        if (recommendDownloader != nil) {
            return;   // a recommend POST is already in flight
        }
        // register this pack as a recommended pack (POST uuid + pack id)
        dummyView.view.hidden = NO;
        NSString *uuid = [[AppDelegate appDelegate] uuId];
        NSString *body = [NSString stringWithFormat:@"uuid=%@&pack_id=%d", uuid, [packInfo packID]];
        recommendDownloader = [[Downloader alloc]
            initWithURL:[StoreUtil recommendPackURL]
               delegate:self
                   Post:[body dataUsingEncoding:NSUTF8StringEncoding]
            ContextType:@"application/json"];
        [recommendDownloader startDownloading];
        return;
    }

    // --- not owned ---
    [self stopSample];
    NSDate *birthday = [UserSettingData birthDay];
    BOOL canceled = [UserSettingData isBirthDayCanceled];
    if (birthday != nil || canceled) {
        unsigned int price = 0x23d;   // 573 default when no product is bound
        if (packInfo.product != nil) {
            price = (unsigned int)[[packInfo.product price] intValue];
        }
        if ([StoreUtil isPurchasable:price]) {
            [self doPurchase];
            return;
        }
        if (birthday != nil) {
            CommonAlertView *alert = [[[CommonAlertView alloc]
                initWithTitle:nil
                      message:@"今月は、これ以上購入することは\nできません。"
                     delegate:nil
            cancelButtonTitle:@"OK"
            otherButtonTitles:nil] autorelease];
            [alert show];
            return;
        }
        // (declined but no birthday recorded) -> fall through to the age gate
    }

    // no birthday on record -> show the age gate
    if (m_BirthDayView != nil) {
        return;
    }
    m_BirthDayView = [[BirthDayViewController alloc] init];
    [m_BirthDayView setDelegate:self];
    [self.view addSubview:[m_BirthDayView view]];
    [m_BirthDayView startOpenAnimation];
}

// @ 0x70af4 — not-owned purchase: forward to the store delegate's StoreKit purchase.
- (void)doPurchase {
    if ([delegate respondsToSelector:@selector(detailViewStartPurchase:)]) {
        [delegate performSelector:@selector(detailViewStartPurchase:) withObject:packInfo];
    }
}

// @ 0x70600 — the preview clip finished playing: tell the sampling row's cell to reset, then
// clear the sampling index.
- (void)finishBgm:(id)sender {
    if (rowSamplePlayed >= 0 && (NSUInteger)rowSamplePlayed < [[packInfo musicInfos] count]) {
        NSIndexPath *ip = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
        id cell = [m_PackTableView cellForRowAtIndexPath:ip];
        [cell sampleStop];
    }
    rowSamplePlayed = -1;
}

// @ 0x7048c — start the detail load: show it now if the songs are already attached, else fetch
// them once via a StorePackInfoDownloader (delegate callbacks drive -showPackInfo).
- (void)loadInfo {
    if (packInfo == nil) {
        return;
    }
    if ([packInfo musicInfos] != nil) {
        [self showPackInfo];
        return;
    }
    if (m_StorePackInfoDownloader != nil) {
        return;   // a fetch is already in flight
    }
    m_StorePackInfoDownloader =
        [[StorePackInfoDownloader alloc] initWithStorePackInfo:packInfo];
    [m_StorePackInfoDownloader setDelegate:self];
    [m_StorePackInfoDownloader downloadDetail:NO];   // auto-load (not a user-initiated open)
}

// @ 0x702bc — the detail is ready: size + fill the header, refresh the buy button, install it as
// the table header, start the jacket download, and reveal + reload the table.
- (void)showPackInfo {
    CGRect b = m_PackTableView ? m_PackTableView.bounds : CGRectZero;
    m_HeaderView.bounds = CGRectMake(0, 0, b.size.width, 120.0f);   // 0x42f00000
    [m_HeaderView loadPackInfo:packInfo];
    [self selfCheckButtonText];
    m_PackTableView.tableHeaderView = m_HeaderView;

    // Kick off the pack jacket download (keyed by an index path, row 0 / section 1).
    NSIndexPath *ip = [NSIndexPath indexPathForRow:0 inSection:1];
    ImageDownloader *dl = [[ImageDownloader alloc] init];
    [dl setImageURL:packInfo.artworkURL];
    [dl setIndexPathInTableView:ip];
    [dl setDelegate:self];
    [artworkDownloaders setObject:dl forKey:ip];
    [dl startDownload];
    [dl release];

    m_PackTableView.hidden = NO;
    [m_PackTableView reloadData];
}

// @ 0x70550 — stop the preview clip: fade the BGM out, cancel + drop the sample download, clear
// the sampling row, and reload the table.
- (void)stopSample {
    [[AudioManager sharedManager] stopBgm:0.2f];   // DAT_000705f8 fade
    [sampleDownloader cancel];
    if (sampleDownloader != nil) {
        [sampleDownloader release];
        sampleDownloader = nil;
    }
    rowSamplePlayed = -1;
    [m_PackTableView reloadData];
}

// @ 0x70d54 — pick the buy button's text/state from the pack's owned + downloaded status.
- (void)selfCheckButtonText {
    if (packInfo != nil) {
        NSString *productID = [StoreUtil productIDForPackID:[packInfo packID]];
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

// @ 0x70e24 — not owned: show the price ("¥<price>") and enable the button.
- (void)setButtonTextBuy {
    UIButton *buy = [m_HeaderView buttonPurchase];
    [buy setTitle:[NSString stringWithFormat:@"¥%@", packInfo.priceString]
         forState:UIControlStateNormal];
    [buy setEnabled:YES];
}

// @ 0x70ed4 — owned but not all downloaded: "INSTALL" (localized), enabled (re-download).
- (void)setButtonTextInstall {
    UIButton *buy = [m_HeaderView buttonPurchase];
    NSString *t = [[NSBundle mainBundle] localizedStringForKey:@"INSTALL" value:@"" table:nil];
    [buy setTitle:t forState:UIControlStateNormal];
    [buy setEnabled:YES];
}

// @ 0x70f80 — a download is in progress: "INSTALLING" (localized, disabled state), disabled.
- (void)setButtonTextInstalling {
    UIButton *buy = [m_HeaderView buttonPurchase];
    NSString *t = [[NSBundle mainBundle] localizedStringForKey:@"INSTALLING" value:@"" table:nil];
    [buy setTitle:t forState:UIControlStateDisabled];
    [buy setEnabled:NO];
}

// @ 0x7102c — owned + all downloaded: offer to recommend the pack, or show it's already
// recommended.
- (void)setButtonTextInstalled {
    if ([self isRecommended]) {
        [self setButtonTextInstalledForce];
    } else {
        [self setButtonTextRecommend];
    }
}

// @ 0x7106c — owned, downloaded, already recommended: "INSTALLED" (localized, disabled), disabled.
- (void)setButtonTextInstalledForce {
    UIButton *buy = [m_HeaderView buttonPurchase];
    NSString *t = [[NSBundle mainBundle] localizedStringForKey:@"INSTALLED" value:@"" table:nil];
    [buy setTitle:t forState:UIControlStateDisabled];
    [buy setEnabled:NO];
}

// @ 0x71118 — owned + downloaded, not yet recommended: the "recommend this pack" button, enabled.
// (The localization key is a Japanese string in the binary; best-effort key here.)
- (void)setButtonTextRecommend {
    UIButton *buy = [m_HeaderView buttonPurchase];
    NSString *t = [[NSBundle mainBundle] localizedStringForKey:@"おすすめに追加" value:@"" table:nil];
    [buy setTitle:t forState:UIControlStateNormal];
    [buy setEnabled:YES];
}

// @ 0x70b9c — YES only when the pack has songs (local or arcade) and every one is downloaded.
- (BOOL)allDownloaded {
    if (packInfo == nil || [packInfo musicInfos] == nil) {
        return NO;
    }
    if ([[packInfo musicInfos] count] == 0 && [[packInfo acvMusicInfos] count] == 0) {
        return NO;   // an empty pack has nothing to "have downloaded"
    }
    return [packInfo allDownloaded];
}

// @ 0x70c14 — YES if this pack's id appears in the (lazily fetched) recommended-pack list.
- (BOOL)isRecommended {
    if (recommendPackIdArr == nil) {
        recommendPackIdArr = [[[MusicManager getInstance] getRecommendPackArray] retain];
    }
    int packID = [packInfo packID];
    for (NSNumber *n in recommendPackIdArr) {
        if ([n intValue] == packID) {
            return YES;
        }
    }
    return NO;
}

// @ 0x70b54 — reflect the owned state on the buy button (owned packs disable the button).
- (void)setPurchaseState:(BOOL)owned {
    if (m_HeaderView == nil) {
        return;
    }
    [[m_HeaderView buttonPurchase] setEnabled:(owned == NO)];
}

// @ 0x711c4 — the pack detail finished downloading: show it, hide the loading overlay, and drop
// the downloader.
- (void)storePackInfoDownloaderFinished:(id)downloader {
    [self showPackInfo];
    m_AccessingLabel.hidden = YES;
    if (m_StorePackInfoDownloader == downloader) {
        [downloader setDelegate:nil];
        [m_StorePackInfoDownloader autorelease];
        m_StorePackInfoDownloader = nil;
    }
}

// @ 0x71248 — the pack detail failed to download: hide the overlay, show a network-error alert,
// and drop the downloader. (Alert strings byte-verified: title "Error", message @0x12bec4.)
- (void)storePackInfoDownloaderError:(id)downloader {
    m_AccessingLabel.hidden = YES;
    CommonAlertView *alert = [[CommonAlertView alloc]
        initWithTitle:@"Error"
              message:@"サーバに接続できません。\nネットワーク接続をご確認下さい。"
             delegate:self
    cancelButtonTitle:@"OK"
    otherButtonTitles:nil];
    [alert show];
    [alert release];
    if (m_StorePackInfoDownloader == downloader) {
        [downloader setDelegate:nil];
        [m_StorePackInfoDownloader autorelease];
        m_StorePackInfoDownloader = nil;
    }
}

// @ 0x71334 — the age gate closed: drop it, then re-run the spending-limit check now that a
// birthday is on record (over the limit -> alert, else proceed to the StoreKit purchase).
- (void)birthDayViewClose {
    [m_BirthDayView release];
    m_BirthDayView = nil;

    unsigned int price = 0x23d;   // 573: default when no product is bound
    if (packInfo.product != nil) {
        price = (unsigned int)[[packInfo.product price] intValue];
    }
    if (![StoreUtil isPurchasable:price]) {
        CommonAlertView *alert = [[[CommonAlertView alloc]
            initWithTitle:nil
                  message:@"今月は、これ以上購入することは\nできません。"   // byte-verified @0x12c0b4
                 delegate:nil
        cancelButtonTitle:@"OK"
        otherButtonTitles:nil] autorelease];
        [alert show];
    } else {
        [self doPurchase];
    }
}

// @ 0x71458 — a Downloader finished. Two flows: (a) the sample clip -> load it as looping BGM,
// play it, mark the row playing; (b) the recommend-pack POST result -> on success register the
// pack + award a +300 treasure bonus (capped 9999), else a network-error alert; drop the
// downloader and hide the dummy cover either way.
- (void)downloaderFinished:(id)downloader {
    if (sampleDownloader == downloader) {
        if (rowSamplePlayed >= 0) {
            AudioManager *am = [AudioManager sharedManager];
            [am loadBgmData:[sampleDownloader getData] isLoop:YES];
            [am playBgm:0];
            NSIndexPath *ip = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
            [[m_PackTableView cellForRowAtIndexPath:ip] samplePlaying];
            isDownloadingSample = NO;
        }
        [sampleDownloader autorelease];
        sampleDownloader = nil;
    } else if (recommendDownloader == downloader) {
        NSDictionary *json = [downloader getDataInJSON];
        CommonAlertView *alert;
        if ([json objectForKey:@"ErrorCode"] == nil) {
            [[MusicManager getInstance] saveRecommendedPack:[packInfo packID]];
            [self setButtonTextInstalledForce];
            // The treasure-bonus body (cf_000000000, UTF-16) resisted extraction; best-effort text.
            NSString *msg = [NSString stringWithFormat:@"おすすめに追加しました。\nトレジャーを%dP獲得しました。", 300];
            alert = [[CommonAlertView alloc] initWithTitle:@"成功"
                                                   message:msg
                                                  delegate:nil
                                         cancelButtonTitle:nil
                                         otherButtonTitles:@"OK", nil];
            int tp = [UserSettingData treasurePoint] + 300;
            if (tp > 9999) {
                tp = 9999;
            }
            [UserSettingData saveTreasurePoint:(short)tp];
        } else {
            alert = [[CommonAlertView alloc] initWithTitle:@"Error"
                    message:@"サーバに接続できません。\nネットワーク接続をご確認下さい。"
                                                  delegate:nil
                                         cancelButtonTitle:@"OK"
                                         otherButtonTitles:nil];
        }
        [alert show];
        [alert release];
        [recommendDownloader release];
        recommendDownloader = nil;
        dummyView.view.hidden = YES;
    }
}

// @ 0x717b0 — a Downloader failed. Sample clip: stop the row + drop the downloader; recommend POST:
// drop the downloader + hide the cover. Either way, show the network-error alert.
- (void)downloaderError:(id)downloader {
    if (sampleDownloader == downloader) {
        if (rowSamplePlayed >= 0) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
            [[m_PackTableView cellForRowAtIndexPath:ip] sampleStop];
            rowSamplePlayed = -1;
        }
        [sampleDownloader autorelease];
        sampleDownloader = nil;
    } else if (recommendDownloader == downloader) {
        [recommendDownloader release];
        recommendDownloader = nil;
        dummyView.view.hidden = YES;
    } else {
        return;
    }
    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"Error"
            message:@"サーバに接続できません。\nネットワーク接続をご確認下さい。"
                                                          delegate:nil
                                                 cancelButtonTitle:@"OK"
                                                 otherButtonTitles:nil];
    [alert show];
    [alert release];
}

// @ 0x719a8 — DownloaderDelegate progress hook (no-op in this controller).
- (void)downloaderProceed:(id)downloader {
}

// @ 0x72600 — an async jacket finished: a song-row jacket (section 0) refreshes that cell's
// artwork; the pack-header jacket (section 1, row 0) is handed to the header view.
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        StoreDetailMusicCell *cell =
            (StoreDetailMusicCell *)[m_PackTableView cellForRowAtIndexPath:indexPath];
        UIImage *img = [downloader getImage];
        if (cell == nil || img == nil) {
            return;
        }
        [cell.artworkView setImage:img];
    } else {
        if (indexPath.section != 1 || indexPath.row != 0) {
            return;
        }
        [m_HeaderView setArtwork:[downloader getImage]];
    }
}

// @ 0x726ec — jacket download failed (no-op; the placeholder stays).
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
}

// @ 0x726f0 — an alert button was tapped: ask the store delegate to close this detail screen.
- (void)commonAlertView:(id)alertView clickedButtonAtIndex:(NSInteger)index {
    if ([delegate respondsToSelector:@selector(detailViewClose)]) {
        [delegate performSelector:@selector(detailViewClose)];
    }
}

// @ 0x72744 — cancel every in-flight jacket download and clear the map (on teardown / navigation).
- (void)stopDownloadArtworks {
    if ([artworkDownloaders count] != 0) {
        for (ImageDownloader *dl in [artworkDownloaders objectEnumerator]) {
            [dl cancelDownload];
            [dl setDelegate:nil];
        }
        [artworkDownloaders removeAllObjects];
    }
}

// @ 0x72860 — support all interface orientations (legacy rotation hook).
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return YES;
}

#pragma mark - UITableViewDataSource

// @ 0x719ac — a single section.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x719b0 — one row per song, plus a trailing copyright row.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[[packInfo musicInfos] count] + 1;
}

// @ 0x719e8 — build a song row (jacket + name + artist + "LEVEL b/m/h" + arcade badge + sample
// state), or the trailing copyright row.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    const NSInteger row = indexPath.row;
    const NSUInteger songCount = [[packInfo musicInfos] count];

    if ((NSUInteger)row >= songCount) {
        // --- trailing copyright row ---
        StoreDetailCopyrightCell *cell =
            [tableView dequeueReusableCellWithIdentifier:@"StoreDetailTableCopyrightCell"];
        if (cell == nil) {
            cell = [[[StoreDetailCopyrightCell alloc]
                initWithStyle:UITableViewCellStyleDefault
              reuseIdentifier:@"StoreDetailTableCopyrightCell"] autorelease];
            cell.labelCopyright.font = [UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:10.0f];
        }
        NSString *copyright = [packInfo copyright];
        if (copyright == nil) {
            cell.labelCopyright.text = @"";
        } else {
            UIFont *f = [UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:10.0f];
            CGSize sz = [copyright sizeWithFont:f
                              constrainedToSize:CGSizeMake(300.0f, 9000.0f)
                                  lineBreakMode:NSLineBreakByWordWrapping];
            cell.labelCopyright.frame = CGRectMake(10.0f, 10.0f, sz.width, sz.height);
            cell.labelCopyright.text = copyright;
        }
        return cell;
    }

    // --- song row ---
    [tableView dequeueReusableCellWithIdentifier:@"StoreDetailTableMusicCell"];  // (always builds fresh)
    StoreDetailMusicCell *cell = [[[StoreDetailMusicCell alloc]
        initWithStyle:UITableViewCellStyleDefault
      reuseIdentifier:@"StoreDetailTableMusicCell"] autorelease];

    StoreMusicInfo *music = [[packInfo musicInfos] objectAtIndex:row];
    if (music != nil) {
        cell.labelName.text = music.name;
        cell.labelArtist.text = music.artist;
        NSString *hard = (music.lvHard == 11) ? @"10+"
                                              : [NSString stringWithFormat:@"%d", music.lvHard];
        cell.labelLevels.text = [NSString stringWithFormat:@"LEVEL %d/%d/%@",
                                 music.lvBasic, music.lvMedium, hard];
        [cell setLink:music.iTunesURL];   // Ghidra selector itunesURL

        // Jacket: cached/in-flight downloader if present, else start one; placeholder meanwhile.
        ImageDownloader *dl = [artworkDownloaders objectForKey:indexPath];
        UIImage *img = nil;
        if (dl == nil) {
            if (music.artworkURL != nil) {
                ImageDownloader *nd = [[ImageDownloader alloc] init];
                [nd setImageURL:music.artworkURL];
                [nd setIndexPathInTableView:indexPath];
                [nd setDelegate:self];
                [artworkDownloaders setObject:nd forKey:indexPath];
                [nd startDownload];
                [nd release];
            }
            img = [UIImage imageNamed:@"store_jacket_128"];
        } else {
            img = [dl getImage];
            if (img == nil) {
                img = [UIImage imageNamed:@"store_jacket_128"];
            }
        }
        cell.artworkView.image = img;

        // Arcade badge: show if any arcade chart references this song id.
        NSUInteger acCount = [[packInfo acvMusicInfos] count];
        for (NSUInteger i = 0; i < acCount; i++) {
            StoreAcMusicInfo *ac = [[packInfo acvMusicInfos] objectAtIndex:i];
            if (ac != nil && ac.acMusicId == music.musicID) {
                cell.arcadeViewer.hidden = NO;
                break;
            }
        }
    }

    // Reflect the current sample state on the row's sample button.
    if (rowSamplePlayed == row) {
        if (isDownloadingSample) {
            [cell sampleDownloading];
        } else {
            [cell samplePlaying];
        }
    } else {
        [cell sampleStop];
    }
    return cell;
}

#pragma mark - UITableViewDelegate

// @ 0x720b4 — song rows use the cell's content height + 24pt padding; the copyright row is sized
// to its wrapped text + 20pt (10pt when empty).
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ((NSUInteger)indexPath.row < [[packInfo musicInfos] count]) {
        return [StoreDetailMusicCell cellHeight] + 24.0f;
    }
    NSString *copyright = [packInfo copyright];
    if (copyright == nil) {
        return 10.0f;
    }
    UIFont *f = [UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:10.0f];
    CGSize sz = [copyright sizeWithFont:f
                      constrainedToSize:CGSizeMake(300.0f, 9000.0f)
                          lineBreakMode:NSLineBreakByWordWrapping];
    return sz.height + 20.0f;
}

// @ 0x721cc — alternate the stretchable row background on song rows (even -> packBgImage0, odd ->
// packBgImage1); the copyright row gets a flat grey.
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ((NSUInteger)indexPath.row < [[packInfo musicInfos] count]) {
        UIImage *bg = ((indexPath.row & 1) == 0) ? packBgImage0 : packBgImage1;
        [(StoreDetailMusicCell *)cell setBgImage:bg];
    } else {
        cell.backgroundColor = [UIColor colorWithWhite:0.6f alpha:1.0f];   // 0x3f19999a
    }
}

// @ 0x722a0 — tap a song row to toggle its preview clip: re-tapping the sampling row stops it;
// tapping another stops the current one and starts downloading the new clip (played on completion
// by the Downloader delegate). Copyright-row taps are ignored.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    const NSInteger row = indexPath.row;
    if ((NSUInteger)row >= [[packInfo musicInfos] count]) {
        return;   // copyright row
    }

    if (row == rowSamplePlayed) {
        // re-tap the sampling row -> stop
        [[AudioManager sharedManager] stopBgm:0.2f];   // DAT_000725f8 fade
        if (sampleDownloader != nil) {
            [sampleDownloader cancel];
            [sampleDownloader release];
            sampleDownloader = nil;
        }
        NSIndexPath *ip = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
        [[tableView cellForRowAtIndexPath:ip] sampleStop];
        rowSamplePlayed = -1;
        [tableView reloadData];
        return;
    }

    // tapping a different row: stop any current sample first
    if (rowSamplePlayed >= 0 && (NSUInteger)rowSamplePlayed < [[packInfo musicInfos] count]) {
        [[AudioManager sharedManager] stopBgm:0.2f];
        if (sampleDownloader != nil) {
            [sampleDownloader cancel];
            [sampleDownloader release];
            sampleDownloader = nil;
        }
        NSIndexPath *ip = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
        [[tableView cellForRowAtIndexPath:ip] sampleStop];
    }

    StoreMusicInfo *music = [[packInfo musicInfos] objectAtIndex:row];
    if (music.sampleURL == nil) {
        return;   // nothing to preview
    }
    StoreDetailMusicCell *cell =
        (StoreDetailMusicCell *)[tableView cellForRowAtIndexPath:indexPath];
    rowSamplePlayed = row;
    isDownloadingSample = YES;
    [cell sampleDownloading];
    sampleDownloader = [[Downloader alloc]
        initWithURL:[NSURL URLWithString:music.sampleURL] delegate:self];
    [sampleDownloader startDownloading];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
