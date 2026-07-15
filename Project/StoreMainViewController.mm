//
//  StoreMainViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreMainViewController.h"
#import "AppDelegate.h"
#import "AppFont.h" // AppFontName() == getFontNameDFSoGei() -> @"DFSoGei-W5-WIN-RKSJ-H"
#import "CharaTicketData+Store.h" // isExistData:... / addRecordWithProductId:...
#import "CharaTicketData.h"
#import "DownloadProgresView.h" // the shared modal dialog: layout: / labelMessage / progressView
#import "MusicManager.h"        // getInstance / getPathFromPurchased: / addPurchasedMusic: ...
#import "PurchaseManager.h"     // sharedManager / beginPurchase: / beginRestore ...
#import "RhUtil.h"              // RhFileExists()
#import "StoreAcMusicInfo.h"
#import "StoreDetailViewController.h"
#import "StoreDownloadTask.h"
#import "StoreMusicInfo.h"
#import "StorePackCell.h"
#import "StorePackDetailViewPad.h"
#import "StorePackInfo.h"
#import "StorePackView.h"
#import "StorePromotionTableCell.h"
#import "StorePromotionView.h" // getPackID / stopAnimation / getImageCount (promo banner)
#import "StoreTableCell.h"
#import "StoreUtil.h"
#import "StoreViewController.h"
#import "UserSettingData.h" // addCharaTicket: / sumPurchase / saveSumPurchase: ...
#import "neEngineBridge.h"
#import <QuartzCore/QuartzCore.h> // CALayer cornerRadius / borderColor / borderWidth
#import <StoreKit/StoreKit.h>     // SKProduct.price

// StoreMainViewController is the delegate for the pack views, the detail
// controllers and the purchase manager (it implements their callbacks below);
// declare the conformances privately.
@interface StoreMainViewController () <StorePackViewDelegate,
                                       StorePackDetailViewPadDelegate,
                                       StoreDetailViewControllerDelegate,
                                       PurchaseManagerMusicDelegate>
// Inlined lazy-jacket loader used by tableView:cellForRowAtIndexPath: (see @
// 0x4837c).
- (UIImage *)artworkForInfo:(StorePackInfo *)info atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation StoreMainViewController

// @ 0x42b40 — set up the tab item, the two pack-list controllers, the artwork
// cache, and the per-OS layout offset.
- (instancetype)initWithParent:(StoreViewController *)parent {
    if ((self = [super init])) {
        m_StoreViewCtrl = parent;

        // Tab item: "購入" ("Purchase") — Ghidra CFString @ 0x136728.
        self.tabBarItem.title = @"購入";
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
        self.tabBarItem.image = [[UIImage imageNamed:@"store_icon_store"]
            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        self.tabBarItem.selectedImage = [[UIImage imageNamed:@"store_icon_store"]
            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
#else
        [self.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"store_icon_store"]
                      withFinishedUnselectedImage:[UIImage imageNamed:@"store_icon_store"]];
#endif

        m_PackListCtrl = [[StorePackListController alloc] init];
        m_PackListCtrl.delegate = self;
        m_RecommendPackListCtrl = [[StorePackListController alloc] init];
        m_RecommendPackListCtrl.delegate = self;

        m_ArtworkDownloaders = [[NSMutableDictionary alloc] initWithCapacity:32];

        neSceneManager::shared();
        m_IsPad = neSceneManager::isPadDisplay();
        m_OffsetForOS = 0;
        // On iOS 7+ the phone layout nudges content down by 46pt (status/nav bar).
        if (UIDevice.currentDevice.systemVersion.floatValue >= 7.0f) {
            m_OffsetForOS = m_IsPad ? 0 : 46;
        }
    }
    return self;
}

// @ 0x42d48 — root view backdrop. Phone: opaque light-grey table backdrop.
// iPad: a clear view over a tiled "friman_bg" pattern image.
- (void)loadView {
    [super loadView];
    self.view.opaque = YES;

    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        // RGB 226/227/228 (Ghidra 0x3f62e2e3 / 0x3f63e3e4 / 0x3f64e4e5).
        self.view.backgroundColor = [UIColor colorWithRed:226.0f / 255.0f
                                                    green:227.0f / 255.0f
                                                     blue:228.0f / 255.0f
                                                    alpha:1.0f];
    } else {
        self.view.backgroundColor = [UIColor clearColor];
        UIImageView *bg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"friman_bg"]];
        [self.view addSubview:bg];
    }
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.exclusiveTouch = YES;
}

// @ 0x42eec — viewDidLoad builds the full pack-browser hierarchy: the pack
// UITableView (tag 10000) with its "show more" button + spinner + "push up to
// show more" label (tag 100000) + store_fun image (tag 0x186a1), a loading
// label (tag 0x2711) with a spinner, an empty-state label (tag 0x2712), the
// promotion banner (StorePromotionView, tag 0x2775) + its dummy, and — on iPad
// — an inset table, a dim cover view (handleTapCoverView:) and an embedded
// StorePackDetailViewPad; plus the stretchable pack-cell backgrounds
// (store_pack_bg_0/1). Fixed float constants are byte-decoded from the
// disassembly; bounds-relative rects are kept structural.
- (void)viewDidLoad {
    [super viewDidLoad];

    const CGRect bounds = self.view ? self.view.bounds : CGRectZero;

    // Common autoresizing recipes used below (numeric masks from the binary).
    const UIViewAutoresizing kBottomAnchored = UIViewAutoresizingFlexibleLeftMargin |
                                               UIViewAutoresizingFlexibleRightMargin |
                                               UIViewAutoresizingFlexibleBottomMargin; // 0x25
    const UIViewAutoresizing kCentered =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin; // 0x2d
    const UIViewAutoresizing kFill =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin; // setAutoresizingAll

    if (!m_IsPad) {
        // ---- Phone: the promotion banner + its dummy live inside a table cell
        // (added
        //      in tableView:cellForRowAtIndexPath:); here we only build +
        //      configure. ----
        if (m_PromotionView == nil) {
            StorePromotionView *promo = [[StorePromotionView alloc]
                initWithFrame:CGRectMake(0.0f,
                                         0.0f,
                                         480.0f,
                                         105.0f)]; // 0x43f00000 / 0x42d20000
            promo.autoresizingMask = kBottomAnchored;
            promo.tag = 0x2775;
            promo.delegate = self;
            [promo setImageViewSize:CGSizeMake(320.0f,
                                               105.0f)]; // 0x43a00000 / 0x42d20000
            m_PromotionView = promo;
        }

        m_PromotionViewDummy =
            [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"p_store_pro"]];
        [m_PromotionViewDummy setFrame:CGRectMake(0.0f,
                                                  0.0f,
                                                  365.0f,
                                                  105.0f)]; // 0x43b68000 / 0x42d20000
        m_PromotionViewDummy.autoresizingMask = kBottomAnchored;
        m_PromotionViewDummy.hidden = YES;

        // Pack catalogue table (tag 10000) filling the view.
        if ([self.view viewWithTag:10000] == nil) {
            UITableView *table = [[UITableView alloc] initWithFrame:bounds
                                                              style:UITableViewStylePlain];
            table.opaque = YES;
            table.tag = 10000;
            table.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleHeight; // setAutoresizingSize
            table.backgroundColor = [UIColor colorWithRed:226.0f / 255.0f
                                                    green:227.0f / 255.0f
                                                     blue:228.0f / 255.0f
                                                    alpha:1.0f];
            table.separatorStyle = UITableViewCellSeparatorStyleNone;
            table.dataSource = self;
            table.delegate = self;
            [self.view addSubview:table];
        }
    } else {
        // ---- iPad: promo banner pinned at the top, a rounded translucent inset
        // table,
        //      a dim cover, and an embedded detail card. ----
        if (m_PromotionView == nil) {
            StorePromotionView *promo = [[StorePromotionView alloc]
                initWithFrame:CGRectMake(0.0f,
                                         0.0f,
                                         730.0f,
                                         240.0f)]; // 0x44368000 / 0x43700000
            m_PromotionView = promo;
            promo.center = CGPointMake(bounds.size.width * 0.5f,
                                       promo.bounds.size.height * 0.5f + 20.0f); // 0x41a00000
            promo.autoresizingMask = kBottomAnchored;
            promo.delegate = self;
        }
        [self.view addSubview:m_PromotionView];

        m_PromotionViewDummy =
            [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"p_store_pro"]];
        [m_PromotionViewDummy setFrame:CGRectMake(0.0f, 0.0f, 730.0f, 240.0f)];
        m_PromotionViewDummy.layer.cornerRadius = 10.0f; // 0x41200000
        m_PromotionViewDummy.clipsToBounds = YES;
        m_PromotionViewDummy.center = CGPointMake(
            bounds.size.width * 0.5f, m_PromotionView.bounds.size.height * 0.5f + 20.0f);
        m_PromotionViewDummy.autoresizingMask = kBottomAnchored;
        m_PromotionViewDummy.hidden = YES;
        [self.view addSubview:m_PromotionViewDummy];

        // "楽曲パック" ("Song pack") section label above the pack table. The binary
        // seeds the initial origin from
        // self.tabBarController.rotatingHeaderView.frame (x=27=0x41d80000,
        // y=331=0x43a58000 minus the header height), but the
        // -setBounds:/-setCenter: below fully redefine the frame, so the header
        // term has no effect on the final layout.
        UILabel *packLabel = [[UILabel alloc] initWithFrame:CGRectMake(27.0f, 331.0f, 0.0f, 0.0f)];
        m_PackTableLabel = packLabel;
        packLabel.backgroundColor = [UIColor clearColor];
        packLabel.textColor = [UIColor blackColor];
        packLabel.shadowColor = [UIColor lightGrayColor];
        packLabel.shadowOffset = CGSizeMake(1.0f, 1.0f);
        packLabel.font = [UIFont fontWithName:AppFontName() size:18.0f]; // 0x41900000
        packLabel.text = @"楽曲パック";
        [packLabel sizeToFit];
        packLabel.bounds = CGRectMake(0.0f,
                                      0.0f,
                                      720.0f,
                                      packLabel.bounds.size.height); // 0x44340000
        packLabel.center = CGPointMake(bounds.size.width * 0.5f,
                                       packLabel.bounds.size.height * 0.5f + 280.0f); // 0x438c0000
        packLabel.autoresizingMask = kBottomAnchored;
        [self.view addSubview:packLabel];

        // "▼ SHOW MORE ▼" footer button, anchored 15pt above the bottom.
        UIButton *showMore = [UIButton buttonWithType:UIButtonTypeCustom];
        [showMore setTitle:@"▼ SHOW MORE ▼" forState:UIControlStateNormal];
        [showMore setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [showMore sizeToFit];
        showMore.center = CGPointMake(bounds.size.width * 0.5f,
                                      bounds.size.height - showMore.bounds.size.height * 0.5f -
                                          15.0f); // 0xc1700000
        showMore.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                    UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleTopMargin; // 0xd
        showMore.hidden = YES;
        [showMore addTarget:self
                      action:@selector(selectShowMore)
            forControlEvents:UIControlEventTouchUpInside]; // 0x40
        [self.view addSubview:showMore];
        m_ShowMoreButton = showMore;

        // Spinner riding just right of the show-more button title.
        UIActivityIndicatorView *showMoreSpinner = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray]; // 2
        showMoreSpinner.bounds = CGRectMake(0.0f, 0.0f, 24.0f, 24.0f);        // 0x41c00000
        showMoreSpinner.center = CGPointMake(m_ShowMoreButton.bounds.size.width * 0.5f +
                                                 showMoreSpinner.bounds.size.width,
                                             m_ShowMoreButton.bounds.size.height * 0.5f);
        showMoreSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                           UIViewAutoresizingFlexibleTopMargin |
                                           UIViewAutoresizingFlexibleBottomMargin; // 0x29
        [showMoreSpinner startAnimating];
        showMoreSpinner.hidden = YES;
        [m_ShowMoreButton addSubview:showMoreSpinner];
        m_ShowMoreIndicator = showMoreSpinner;

        // Rounded, translucent inset pack table (tag 10000).
        if ([self.view viewWithTag:10000] == nil) {
            CGFloat tableHeight =
                bounds.size.height - 316.0f -
                (m_ShowMoreButton.bounds.size.height + 32.0f); // -0x439e0000 / 0x42000000
            UITableView *table =
                [[UITableView alloc] initWithFrame:CGRectMake(0.0f,
                                                              0.0f,
                                                              728.0f,
                                                              tableHeight) // 0x44360000
                                             style:UITableViewStylePlain];
            table.tag = 10000;
            table.center = CGPointMake(bounds.size.width * 0.5f,
                                       table.bounds.size.height * 0.5f + 316.0f); // 0x439e0000
            table.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                     UIViewAutoresizingFlexibleRightMargin |
                                     UIViewAutoresizingFlexibleHeight; // 0x15
            table.opaque = YES;
            table.backgroundColor = [UIColor colorWithWhite:1.0f
                                                      alpha:0.8f]; // 0x3f800000 / 0x3f4ccccd
            table.layer.cornerRadius = 8.0f;                       // 0x41000000
            table.layer.borderColor =
                [UIColor colorWithWhite:0.56f alpha:1.0f].CGColor;                  // 0x3f0f8f90
            table.layer.borderWidth = 1.5f;                                         // 0x3fc00000
            table.scrollIndicatorInsets = UIEdgeInsetsMake(4.0f, 0.0f, 4.0f, 0.0f); // 0x40800000
            table.separatorStyle = UITableViewCellSeparatorStyleNone;
            table.dataSource = self;
            table.delegate = self;
            [self.view addSubview:table];
        }

        // Dim cover over the catalogue while the detail card is up.
        UIView *cover = [[UIView alloc] initWithFrame:bounds];
        m_CoverViewPad = cover;
        cover.autoresizingMask = kFill;
        cover.opaque = NO;
        cover.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f]; // 0x3f000000
        cover.userInteractionEnabled = YES;
        cover.exclusiveTouch = YES;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(handleTapCoverView:)];
        [cover addGestureRecognizer:tap];
        cover.hidden = YES;
        [self.view addSubview:cover];

        // Embedded detail card, centred over the cover (44pt above centre).
        StorePackDetailViewPad *detail = [[StorePackDetailViewPad alloc]
            initWithFrame:CGRectMake(0.0f, 0.0f, 650.0f, 650.0f)]; // 0x44228000
        m_PackDetailViewPad = detail;
        CGPoint coverCenter = m_CoverViewPad.center;
        detail.center = CGPointMake(roundf(coverCenter.x),
                                    roundf(coverCenter.y - 44.0f)); // 0xc2300000
        detail.autoresizingMask = kCentered;
        [detail setDelegate:self];
        detail.hidden = YES;
        [self.view addSubview:detail];
    }

    // ---- Shared: the table's "push up to show more" hint (tag 100000) + the
    // pinned
    //      store_fun banner (tag 0x186a1) live inside whichever table exists.
    //      ----
    UITableView *table = (UITableView *)[self.view viewWithTag:10000];
    if (table != nil) {
        if ([table viewWithTag:100000] == nil) {
            UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(0.0f,
                                                                      0.0f,
                                                                      bounds.size.width,
                                                                      25.0f)]; // 0x41c80000
            hint.tag = 100000;
            hint.backgroundColor = [UIColor clearColor];
            hint.text = [[NSBundle mainBundle] localizedStringForKey:@"Push up to show more"
                                                               value:@""
                                                               table:nil];
            hint.font = [UIFont fontWithName:AppFontName() size:15.0f]; // 0x41700000
            hint.textColor = [UIColor whiteColor];
            hint.textAlignment = NSTextAlignmentCenter; // 1
            hint.hidden = YES;
            [table addSubview:hint];
        }
        if ([table viewWithTag:0x186a1] == nil) {
            UIImageView *banner =
                [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"store_fun.png"]];
            banner.tag = 0x186a1;
            banner.hidden = YES;
            [table addSubview:banner];
        }
    }

    // Loading placeholder (tag 0x2711): a light label carrying a centred spinner.
    if ([self.view viewWithTag:0x2711] == nil) {
        UILabel *loading = [[UILabel alloc] initWithFrame:bounds];
        loading.tag = 0x2711;
        loading.backgroundColor = [UIColor colorWithRed:226.0f / 255.0f
                                                  green:227.0f / 255.0f
                                                   blue:228.0f / 255.0f
                                                  alpha:1.0f];
        loading.font = [UIFont fontWithName:AppFontName() size:18.0f];  // 0x41900000
        loading.textColor = [UIColor colorWithWhite:0.62f alpha:1.0f];  // 0x3f1e9e9f
        loading.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.3f]; // 0x3e99999a
        loading.shadowOffset = CGSizeMake(0.0f, 1.0f);
        loading.textAlignment = NSTextAlignmentCenter; // 1
        loading.center = CGPointMake(bounds.size.width * 0.5f, roundf(bounds.size.height * 0.5f));
        loading.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; // 0x12
        loading.text = @"読み込み中...";                                        // "Loading..."
        loading.hidden = NO;
        [self.view addSubview:loading];

        UIView *spinnerBox =
            [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 40.0f, 40.0f)]; // 0x42200000
        spinnerBox.backgroundColor = [UIColor clearColor];
        spinnerBox.autoresizingMask = kCentered;
        spinnerBox.center =
            CGPointMake(loading.bounds.size.width * 0.5f, loading.bounds.size.height * 0.5f);
        [loading addSubview:spinnerBox];

        UIActivityIndicatorView *spinner =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite; // 1
        // The binary derives the spinner's centre from spinnerBox.bounds (square
        // 40pt box).
        spinner.center =
            CGPointMake(spinnerBox.bounds.size.width * 0.5f, spinnerBox.bounds.size.height * 0.5f);
        spinner.autoresizingMask = kBottomAnchored;
        [spinner startAnimating];
        [spinnerBox addSubview:spinner];
    }

    // Empty-state label (tag 0x2712): centred 20pt above the middle, wired later
    // by -showError:.
    if ([self.view viewWithTag:0x2712] == nil) {
        UILabel *empty = [[UILabel alloc] initWithFrame:bounds];
        empty.tag = 0x2712;
        empty.backgroundColor = self.view.backgroundColor;
        empty.font = [UIFont fontWithName:AppFontName()
                                     size:(m_IsPad ? 18.0f : 16.0f)]; // 0x41900000 / 0x41800000
        empty.textColor = [UIColor colorWithWhite:0.62f alpha:1.0f];  // 0x3f1e9e9f
        empty.textAlignment = NSTextAlignmentCenter;                  // 1
        empty.numberOfLines = 0;
        empty.center = CGPointMake(bounds.size.width * 0.5f,
                                   roundf(bounds.size.height * 0.5f) - 20.0f); // 0x14
        empty.autoresizingMask = kFill;
        empty.hidden = YES;
        [self.view addSubview:empty];
    }

    // Alternating stretchable pack-cell backdrops (4pt caps).
    if (m_PackBgImage0 == nil) {
        m_PackBgImage0 =
            [[UIImage imageNamed:@"store_pack_bg_0.png"] stretchableImageWithLeftCapWidth:4
                                                                             topCapHeight:4];
    }
    if (m_PackBgImage1 == nil) {
        m_PackBgImage1 =
            [[UIImage imageNamed:@"store_pack_bg_1.png"] stretchableImageWithLeftCapWidth:4
                                                                             topCapHeight:4];
    }
}

// @ 0x4a2d8
- (void)startStoreClose {
    m_IsStoreClosing = YES;
}

// @ 0x4a2ec
- (BOOL)isAlertViewShowing {
    return _isAlertViewShowing;
}

// @ 0x494cc — tapped the pack table's "show more" footer button. Guarded so a
// second tap while a fetch is in flight is ignored. Swaps the button caption to
// the loading text (byte-verified CFString @ 0x136798) without moving it
// (capture the centre, -sizeToFit to the new title, then restore the centre),
// reveals the spinner, hides the "push up to show more" hint label (tag
// 100000), and asks the pack list for the next page (-1 = "the page after the
// last one loaded").
- (void)selectShowMore {
    if (m_IsLoadingMoreList) {
        return;
    }
    m_IsLoadingMoreList = YES;

    [m_ShowMoreButton setTitle:@"読み込み中..." forState:UIControlStateNormal]; // "Loading..."
    CGPoint center = m_ShowMoreButton ? m_ShowMoreButton.center : CGPointZero;
    [m_ShowMoreButton sizeToFit];
    m_ShowMoreButton.center = center;

    m_ShowMoreIndicator.hidden = NO;
    [[self.view viewWithTag:100000] setHidden:YES];

    [m_PackListCtrl startFetchingPack:-1];
}

#pragma mark - Pack-list controller callbacks

// @ 0x449e0 — a catalogue page finished. The recommend list feeds straight into
// a detail open (deep-link); the normal list rebuilds the table, adds the
// restore bar button on first success, repositions the store_fun banner,
// refreshes the "show more" footer + promotion header, and — if a recommend
// pack is still pending — starts the recommend fetch.
- (void)packListDownloadSuccess:(StorePackListController *)controller {
    if (controller != m_PackListCtrl) {
        // The recommend (deep-link) list arrived: open the requested pack's detail.
        NSArray *ids = [m_RecommendPackListCtrl packIDList];
        int recommendPackId = [m_StoreViewCtrl recommendPackId];
        for (NSUInteger i = 0; i < [ids count]; i++) {
            if ([[ids objectAtIndex:i] intValue] == recommendPackId) {
                if (!m_IsPad) {
                    [self showDetailViewForPhone:recommendPackId];
                } else {
                    StorePackInfo *info = [m_RecommendPackListCtrl getPackInfo:recommendPackId];
                    StorePackView *packView = [[StorePackView alloc] init];
                    [packView loadPackInfo:info index:static_cast<unsigned int>(i)];
                    [self packViewSelected:packView];
                }
                break;
            }
        }
        [m_StoreViewCtrl setRecommendPackId:-1];
        return;
    }

    UITableView *table = (UITableView *)[self.view viewWithTag:10000];
    [table setHidden:NO];
    [[self.view viewWithTag:0x2711] setHidden:YES];
    if (m_PackTableLabel) {
        [m_PackTableLabel setHidden:NO];
    }
    m_IsLoadingMoreList = NO;
    table.allowsSelection = YES;
    [table reloadData];

    // Lazily install the "復元" (restore) right bar button the first time a page
    // lands.
    if (m_RestoreButton == nil) {
        UIImage *img = [UIImage imageNamed:@"p_store_btnrestore"];
        CGSize size = img ? img.size : CGSizeZero;
        UIButton *button =
            [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
        [button setBackgroundImage:img forState:UIControlStateNormal];
        [button addTarget:self
                      action:@selector(pushBarBtnRestore:)
            forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:button];
        m_RestoreButton = button;
    }

    // Pin the decorative "store_fun" banner (tag 0x186a1) below the content.
    // @ 0x44e18: slack iPad=mov.ne.w r5,#0x12c=300, phone=movs r5,#0x64=100
    // (integer); origin.x @ 0x44e24: movt r2,#0x4248 → 0x42480000=50.0
    // (byte-exact).
    UIView *banner = [table viewWithTag:0x186a1];
    CGFloat slack = m_IsPad ? 300.0f : 100.0f;
    CGRect bannerFrame = banner ? banner.frame : CGRectZero;
    CGFloat bannerY = (table.contentSize.height < table.bounds.size.height) ?
                          slack + table.bounds.size.height :
                          slack + table.contentSize.height;
    bannerFrame.origin.y = bannerY;
    bannerFrame.origin.x = 50.0f; // 0x42480000
    [banner setFrame:bannerFrame];
    [banner setHidden:NO];

    if (m_ShowMoreIndicator) {
        [m_ShowMoreIndicator setHidden:YES];
    }

    if (![m_PackListCtrl packlistContinued]) {
        if (m_ShowMoreButton) {
            [m_ShowMoreButton setHidden:YES];
        }
        [[table viewWithTag:100000] setHidden:YES];
    } else {
        if (m_ShowMoreButton) {
            [m_ShowMoreButton setTitle:@"▼ SHOW MORE ▼" forState:UIControlStateNormal];
            CGPoint center = m_ShowMoreButton ? m_ShowMoreButton.center : CGPointZero;
            [m_ShowMoreButton sizeToFit];
            m_ShowMoreButton.center = center;
        }
        UIView *hint = [table viewWithTag:100000];
        [hint setHidden:NO];
        // Hint centred under the content.
        // @ 0x4540c: 0.5 from vmov.f32 d16,#0x3f000000; 25 from vmov.f32
        // d18,#0x41c80000 (byte-exact).
        [hint setCenter:CGPointMake(table.bounds.size.width * 0.5f,
                                    table.contentSize.height + 25.0f)];
    }

    // Promotion header: show the real banner when a promotion exists, else the
    // dummy.
    if (m_PromotionView) {
        NSArray *promotionList = [m_PackListCtrl promotionList];
        [m_PromotionViewDummy setHidden:(promotionList != nil)];
        [m_PromotionView setHidden:(![m_PromotionViewDummy isHidden])];
        [m_PromotionView setImageURLs:[m_PackListCtrl promotionList]];
    }

    if ([m_StoreViewCtrl recommendPackId] != -1) {
        [m_RecommendPackListCtrl startFetchingPack:[m_StoreViewCtrl recommendPackId]];
    }
}

// @ 0x45108 — a page fetch failed. Before any row is on screen (table still
// hidden) route through the empty-state label; once rows exist, pop an alert
// and re-enable the table. Either way clear the host's pending recommend-pack
// id.
- (void)packListDownloadError:(StorePackListController *)controller
                 errorMessage:(NSString *)message {
    UITableView *table = (UITableView *)[self.view viewWithTag:10000];
    NSString *text = message ? message : @"サーバに接続できません。\n";
    if ([table isHidden]) {
        [self showError:text];
    } else {
        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"Error"
                                                                message:text
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
        [alert show];
        m_IsLoadingMoreList = NO;
        table.allowsSelection = YES;
        [table reloadData];
    }
    [m_StoreViewCtrl setRecommendPackId:-1];
}

// @ 0x45258 — the fetch returned an empty catalogue; same split as the error
// path.
- (void)packListDownloadNothing:(StorePackListController *)controller {
    UITableView *table = (UITableView *)[self.view viewWithTag:10000];
    if ([table isHidden]) {
        [self showError:@"サーバーエラーが発生しました。\n後ほど再接続して下さい。"];
    } else {
        m_IsLoadingMoreList = NO;
        table.allowsSelection = YES;
        [table reloadData];
    }
    [m_StoreViewCtrl setRecommendPackId:-1];
}

#pragma mark - Error surface + restore bar button

// @ 0x44864 — surface a load failure in the pack table's empty area: hide the
// table (tag 10000) + its spinner (tag 0x2711) and show the empty-state label
// (tag 0x2712).
- (void)showError:(NSString *)message {
    [[self.view viewWithTag:10000] setHidden:YES];
    [[self.view viewWithTag:0x2711] setHidden:YES];
    UILabel *label = (UILabel *)[self.view viewWithTag:0x2712];
    [label setText:message];
    [label setHidden:NO];
}

// @ 0x44904 — "復元" bar button: confirm before kicking off a StoreKit restore.
- (void)pushBarBtnRestore:(id)sender {
    if (m_IsStoreClosing) {
        return;
    }
    _isAlertViewShowing = YES;
    neEngine::playSystemSe(1); // decide SE
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"購入情報の復元"
                                       message:@"購入済パックの情報を復元しますか？"
                                      delegate:self
                             cancelButtonTitle:@"Cancel"
                             otherButtonTitles:@"OK"];
    alert.tag = 0x1f;
    [alert show];
}

#pragma mark - Detail navigation

// @ 0x45648 — a promotion banner tile was tapped. Phone pushes a detail screen;
// iPad slides the in-place detail card up over a dim cover.
- (void)storePromotionViewTaped:(StorePromotionView *)view PackID:(int)packID {
    if (packID < 0) {
        return;
    }
    if (self.navigationController.topViewController != self) {
        return;
    }
    neEngine::playSystemSe(1); // decide SE
    if (!m_IsPad) {
        [self showDetailViewForPhone:packID];
        return;
    }
    if (m_RestoreButton) {
        [m_RestoreButton setEnabled:NO];
    }
    [(id)view stopAnimation];
    if (![[self.view viewWithTag:10000] allowsSelection]) {
        return;
    }
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [m_CoverViewPad setAlpha:0.0f];
    [m_PackDetailViewPad setAlpha:0.0f];
    [m_CoverViewPad setHidden:NO];
    [m_PackDetailViewPad setHidden:NO];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear]; // 3
    [UIView setAnimationDuration:0.3];                     // DAT_00045890
    [UIView setAnimationDelegate:self];
    [UIView
        setAnimationDidStopSelector:@selector(openDetailAnimStopFromPromotion:finished:context:)];
    [m_CoverViewPad setAlpha:1.0f];
    [m_PackDetailViewPad setAlpha:1.0f];
    [UIView commitAnimations];
}

// @ 0x45510 — iPad: the "open detail" slide finished for a normal cell tap.
// Resolve the tapped index against whichever list is populated (recommend
// first) and hand the pack info to the embedded detail card.
- (void)openDetailAnimStop:(NSString *)animationID
                  finished:(NSNumber *)finished
                   context:(void *)ctx {
    NSInteger index = [(__bridge StorePackView *)ctx index]; // ctx = the tapped packView (set
                                                             // @0x45... beginAnimations context)
    StorePackListController *list = m_PackListCtrl;
    if (m_RecommendPackListCtrl && [[m_RecommendPackListCtrl packIDList] count] != 0) {
        list = m_RecommendPackListCtrl;
    }
    int packID = [[[list packIDList] objectAtIndex:index] intValue];
    [m_PackDetailViewPad setPackInfo:[list getPackInfo:packID]];
    [m_PackDetailViewPad loadInfo];
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    m_IsAnimationing = NO;
}

// @ 0x45898 — iPad: the promotion-tap slide finished; load the promoted pack's
// detail.
- (void)openDetailAnimStopFromPromotion:(NSString *)animationID
                               finished:(NSNumber *)finished
                                context:(void *)ctx {
    int packID = [(id)m_PromotionView getPackID];
    [m_PackDetailViewPad setPackInfo:[m_PackListCtrl getPackInfo:packID]];
    [m_PackDetailViewPad loadInfo];
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
}

// @ 0x45a80 — iPad: the detail-close slide finished; tear the card down and
// restart the promotion animation.
- (void)closeDetailAnimStop:(NSString *)animationID
                   finished:(NSNumber *)finished
                    context:(void *)ctx {
    [m_CoverViewPad setHidden:YES];
    [m_PackDetailViewPad setHidden:YES];
    [m_PackDetailViewPad removePackInfo];
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    if (m_PromotionView) {
        [(id)m_PromotionView startAnimation];
    }
    if (m_RestoreButton) {
        [m_RestoreButton setEnabled:YES];
    }
}

// @ 0x45318 — iPad: a StorePackView tile was tapped. Gate on no animation
// already running and the catalogue table still allowing selection, freeze the
// promotion banner / restore button, then slide the dim cover + embedded detail
// card in. The tapped tile is carried as the animation context so
// -openDetailAnimStop:… can resolve its row index on completion.
- (void)packViewSelected:(id)packView {
    if (m_IsAnimationing) {
        return;
    }
    m_IsAnimationing = YES;
    if (![[self.view viewWithTag:10000] allowsSelection]) {
        return;
    }
    if (m_PromotionView) {
        [m_PromotionView stopAnimation];
    }
    if (m_RestoreButton) {
        [m_RestoreButton setEnabled:NO];
    }
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [m_CoverViewPad setAlpha:0.0f];
    [m_PackDetailViewPad setAlpha:0.0f];
    [m_CoverViewPad setHidden:NO];
    [m_PackDetailViewPad setHidden:NO];
    [UIView beginAnimations:nil context:(__bridge void *)packView];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear]; // 3
    [UIView setAnimationDuration:0.3];                     // DAT_00045508
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(openDetailAnimStop:finished:context:)];
    [m_CoverViewPad setAlpha:1.0f];
    [m_PackDetailViewPad setAlpha:1.0f];
    [UIView commitAnimations];
}

// @ 0x45940 — iPad: the dim cover was tapped. Cancel any in-flight detail load
// / sample, then slide the cover + detail card back out; -closeDetailAnimStop:…
// tears the card down once the fade completes.
- (void)handleTapCoverView:(id)sender {
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [m_PackDetailViewPad cancelLoading];
    [m_PackDetailViewPad stopSample];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear]; // 3
    [UIView setAnimationDuration:0.3];                     // DAT_00045a78
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(closeDetailAnimStop:finished:context:)];
    [m_CoverViewPad setAlpha:0.0f];
    [m_PackDetailViewPad setAlpha:0.0f];
    [UIView commitAnimations];
}

// @ 0x4934c — phone: push a StoreDetailViewController for the tapped pack.
// No-op unless this controller is on top of its nav stack. Resolves the pack
// info against whichever list is populated (recommend first), skins the nav
// bar, then pushes the detail screen.
- (void)showDetailViewForPhone:(int)packID {
    if (self.navigationController.topViewController != self) {
        return;
    }
    StoreDetailViewController *vc = [[StoreDetailViewController alloc] init];
    [vc setDelegate:self];
    StorePackListController *list = m_PackListCtrl;
    if (m_RecommendPackListCtrl && [[m_RecommendPackListCtrl packIDList] count] != 0) {
        list = m_RecommendPackListCtrl;
    }
    [vc setPackInfo:[list getPackInfo:packID]];
    UIImage *navbar = [UIImage imageNamed:@"p_store_detail_navbar"];
    [self.navigationController.navigationBar setBackgroundImage:navbar
                                                  forBarMetrics:UIBarMetricsDefault];
    [self.navigationController pushViewController:vc animated:YES];
}

// @ 0x46270 — detail card asked to buy: gate on StoreKit availability + a valid
// product, show the "処理中..." modal and begin the purchase.
- (void)detailViewStartPurchase:(StorePackInfo *)packInfo {
    if ([PurchaseManager isPurchasable] && [packInfo product]) {
        m_PurchasingPackInfo = packInfo;
        id dialog = [m_StoreViewCtrl modalDialog];
        [dialog layout:1];
        [[dialog labelMessage] setText:@"処理中..."];
        [m_StoreViewCtrl showModalDialog:self];
        [[PurchaseManager sharedManager] setMusicDataDelegate:self];
        [[PurchaseManager sharedManager] beginPurchase:[packInfo product]];
        return;
    }
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"Error"
                                       message:@"アプリケーション内購入が許可されていません。"
                                      delegate:nil
                             cancelButtonTitle:@"OK"
                             otherButtonTitles:nil];
    [alert show];
}

// @ 0x46420 — detail card asked to close: phone pops the nav stack, iPad slides
// the card.
- (void)detailViewClose {
    if (m_IsPad) {
        [self handleTapCoverView:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

// @ 0x46470 — the download/purchase modal's cancel button: abort the download,
// hide the modal and let the visible detail re-check its button caption.
- (void)storeDialogCancel:(id)sender {
    if (m_DownloadManager) {
        [m_DownloadManager cancel];
        m_DownloadManager = nil;
    }
    [m_StoreViewCtrl hideModalDialog];
    if (!m_IsPad) {
        UIViewController *top = self.navigationController.topViewController;
        if (![top isKindOfClass:[StoreDetailViewController class]]) {
            return;
        }
        [(id)top selfCheckButtonText];
    } else {
        [m_PackDetailViewPad selfCheckButtonText];
    }
}

#pragma mark - NSURLConnection stubs

// @ 0x46584 — NSURLConnection delegate stub (empty in the binary).
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
}

// @ 0x46588 — NSURLConnection delegate stub (empty in the binary).
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
}

#pragma mark - Purchase / download / restore

// @ 0x4658c — fold a pack's music + AC-music infos into the purchased library,
// optionally persisting.
- (void)updateMusicInfo:(StorePackInfo *)packInfo Save:(BOOL)save {
    if (packInfo == nil) {
        return;
    }
    NSArray *musicInfos = [packInfo musicInfos];
    if (musicInfos && [musicInfos count] != 0) {
        for (StoreMusicInfo *info in musicInfos) {
            [[MusicManager getInstance] addPurchasedMusic:info];
        }
    }
    NSArray *acMusicInfos = [packInfo acvMusicInfos];
    if (acMusicInfos && [acMusicInfos count] != 0) {
        for (StoreAcMusicInfo *info in acMusicInfos) {
            [[MusicManager getInstance] addPurchasedAcMusic:info];
        }
    }
    if (save) {
        [[MusicManager getInstance] savePurchasedMusics];
    }
}

// @ 0x45b48 — kick off downloads for a pack's still-missing musics. Grants the
// pack's character ticket, shows the download modal, builds a StoreDownloadTask
// per missing file (both normal + AC music) and starts a StoreDownloadManager —
// or, if nothing is missing, just flips the button caption to "installed".
- (void)startDownloadPackMusics:(StorePackInfo *)packInfo {
    if (packInfo == nil) {
        return;
    }
    NSString *productID = [StoreUtil productIDForPackID:[packInfo packID]];
    if (![CharaTicketData isExistData:productID
               inManagedObjectContext:[[AppDelegate appDelegate] managedObjectContext]]) {
        [UserSettingData addCharaTicket:5];
        [CharaTicketData addRecordWithProductId:productID
                         inManagedObjectContext:[[AppDelegate appDelegate] managedObjectContext]];
    }

    NSArray *musicInfos = [packInfo musicInfos];
    NSArray *acMusicInfos = [packInfo acvMusicInfos];
    if ((musicInfos == nil || [musicInfos count] == 0) &&
        (acMusicInfos == nil || [acMusicInfos count] == 0)) {
        return;
    }

    [m_StoreViewCtrl showModalDialog:self];
    if (!m_IsPad) {
        UIViewController *top = self.navigationController.topViewController;
        if ([top isKindOfClass:[StoreDetailViewController class]]) {
            [(id)top setButtonTextInstalling];
        }
    } else {
        [m_PackDetailViewPad setButtonTextInstalling];
    }

    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:[musicInfos count]];
    for (StoreMusicInfo *info in musicInfos) {
        NSString *path = [[MusicManager getInstance] getPathFromPurchased:[info musicID]];
        if (!RhFileExists(path)) {
            StoreDownloadTask *task =
                [[StoreDownloadTask alloc] initWithURL:[info itemURL]
                                                  path:path
                                             AddObject:[NSString stringWithString:[info name]]];
            [tasks addObject:task];
        }
    }
    for (StoreAcMusicInfo *info in acMusicInfos) {
        NSString *path = [[MusicManager getInstance] getAcPathFromPurchased:[info acMusicId]];
        if (!RhFileExists(path)) {
            StoreDownloadTask *task =
                [[StoreDownloadTask alloc] initWithURL:[info itemURL]
                                                  path:path
                                             AddObject:[NSString stringWithString:[info title]]];
            [tasks addObject:task];
        }
    }

    if ([tasks count] != 0) {
        m_DownloadManager = [[StoreDownloadManager alloc] initWithTasks:tasks delegate:self];
        id dialog = [m_StoreViewCtrl modalDialog];
        [dialog layout:0];
        [[dialog labelMessage] setText:@""];
        [[dialog progressView] setProgress:0];
        [m_DownloadManager start];
        return;
    }

    if (!m_IsPad) {
        UIViewController *top = self.navigationController.topViewController;
        if ([top isKindOfClass:[StoreDetailViewController class]]) {
            [(id)top setButtonTextInstalled];
        }
    } else {
        [m_PackDetailViewPad setButtonTextInstalled];
    }
    [m_StoreViewCtrl hideModalDialog];
}

// @ 0x46a7c — re-download: re-register the pack's musics (persisting) then
// download.
- (void)reDownloadPackMusics:(StorePackInfo *)packInfo {
    [self updateMusicInfo:packInfo Save:YES];
    [self startDownloadPackMusics:packInfo];
}

// @ 0x46798 — refresh the on-screen state for a just-purchased pack. Phone: if
// the detail screen is up flip its purchase state, else reload the pack's row
// in the main list (section 1); iPad: reload the pack's row (section 0, two
// packs per row).
- (void)updatePurchasedTableCell:(StorePackInfo *)packInfo {
    if (!m_IsPad) {
        UIViewController *top = self.navigationController.topViewController;
        if ([top isKindOfClass:[StoreDetailViewController class]]) {
            [(StoreDetailViewController *)top setPurchaseState:YES];
            return;
        }
        if ([top isKindOfClass:[StoreMainViewController class]]) {
            NSArray *ids = [m_PackListCtrl packIDList];
            for (NSUInteger i = 0; i < [ids count]; i++) {
                if ([[ids objectAtIndex:i] intValue] == [packInfo packID]) {
                    UITableView *table = (UITableView *)[self.view viewWithTag:10000];
                    NSIndexPath *ip = [NSIndexPath indexPathForRow:i inSection:1];
                    [table reloadRowsAtIndexPaths:[NSArray arrayWithObject:ip]
                                 withRowAnimation:UITableViewRowAnimationNone];
                    return;
                }
            }
        }
    } else {
        NSArray *ids = [m_PackListCtrl packIDList];
        for (NSUInteger i = 0; i < [ids count]; i++) {
            if ([[ids objectAtIndex:i] intValue] == [packInfo packID]) {
                UITableView *table = (UITableView *)[self.view viewWithTag:10000];
                NSIndexPath *ip = [NSIndexPath indexPathForRow:(i / 2) inSection:0];
                [table reloadRowsAtIndexPaths:[NSArray arrayWithObject:ip]
                             withRowAnimation:UITableViewRowAnimationNone];
                return;
            }
        }
    }
}

// @ 0x46ab0 — a purchase completed for a product id. If it matches the pending
// pack, persist the musics, register the product, refresh the row, start the
// downloads, and roll the month's spend total forward for the parental spending
// guard.
- (void)purchaseSucceeded:(NSString *)productID {
    if ([StoreUtil packIDForProductID:productID] != [m_PurchasingPackInfo packID]) {
        return;
    }
    [self updateMusicInfo:m_PurchasingPackInfo Save:YES];
    [[PurchaseManager sharedManager] addProductID:productID Save:YES];
    [[PurchaseManager sharedManager] setMusicDataDelegate:nil];
    [self updatePurchasedTableCell:m_PurchasingPackInfo];
    [self startDownloadPackMusics:m_PurchasingPackInfo];

    SKProduct *product = [m_PurchasingPackInfo product];
    if (product == nil) {
        return;
    }
    NSDate *lastUpdate = [UserSettingData lastUpdateSumPurchase];
    NSDate *now = [NSDate date];
    int prevSum = 0;
    if (lastUpdate != nil) {
        NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSUInteger units = NSYearCalendarUnit | NSMonthCalendarUnit; // 0xc
        NSDateComponents *lastC = [cal components:units fromDate:lastUpdate];
        NSDateComponents *nowC = [cal components:units fromDate:now];
        if ([lastC year] == [nowC year] && [lastC month] == [nowC month]) {
            prevSum = [UserSettingData sumPurchase];
        }
    }
    int price = [[product price] intValue];
    [UserSettingData saveLastUpdateSumPurchase:now];
    [UserSettingData saveSumPurchase:(price + prevSum)];
}

// @ 0x46d1c — a purchase failed/cancelled: drop the delegate, hide the modal
// and report.
- (void)purchaseFailed:(NSString *)productID error:(NSError *)error {
    [[PurchaseManager sharedManager] setMusicDataDelegate:nil];
    m_PurchasingPackInfo = nil;
    [m_StoreViewCtrl hideModalDialog];
    NSString *message = [[NSString alloc]
        initWithFormat:@"購入はキャンセルされました。\n\n%@", [error localizedDescription]];
    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"Error"
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
    [alert show];
}

// @ 0x46e58 — remember a restored pack's info and tick its product off the
// pending list.
- (void)addRestorePackInfo:(StorePackInfo *)packInfo {
    [m_RestorePackInfo addObject:packInfo];
    NSString *productID = [StoreUtil productIDForPackID:[packInfo packID]];
    if ([m_RestoreProductID containsObject:productID]) {
        [m_RestoreProductID removeObject:productID];
    }
}

// @ 0x46ef4 — walk the pending restored product ids: for each, resolve its pack
// info (or spin up a StorePackInfoDownloader to fetch a missing one). Returns
// YES while a detail fetch is still in flight (the download callback re-enters
// here), NO when all are ready.
- (BOOL)nextRestorePackInfo {
    NSArray *productIDs = [NSArray arrayWithArray:m_RestoreProductID];
    NSLog(@"IDs=%@", productIDs);
    for (NSString *productID in productIDs) {
        NSLog(@"ID=%@", productID);
        StorePackInfo *info = [m_PackListCtrl getPackInfo:[StoreUtil packIDForProductID:productID]];
        if (info == nil) {
            info = [m_PackListCtrl addPackInfoFromID:[StoreUtil packIDForProductID:productID]];
        }
        if ([info musicInfos] == nil) {
            if (m_StorePackInfoDownloader == nil) {
                m_StorePackInfoDownloader =
                    [[StorePackInfoDownloader alloc] initWithStorePackInfo:info];
                [m_StorePackInfoDownloader setDelegate:self];
                [m_StorePackInfoDownloader downloadDetail:NO];
            }
            return YES;
        }
        [self addRestorePackInfo:info];
    }
    return NO;
}

// @ 0x47134 — all restored packs are gathered: persist them, migrate the
// purchase-checked products, refresh their rows, and — if any file is still
// missing — offer to download them all (alert tag 0x1e); otherwise finish
// silently.
- (void)askDownloadAllMusics {
    for (StorePackInfo *info in m_RestorePackInfo) {
        [self updateMusicInfo:info Save:NO];
    }
    [[MusicManager getInstance] savePurchasedMusics];
    [[PurchaseManager sharedManager] addProductFromPurchaseCheckedProducts];
    [[PurchaseManager sharedManager] clearPurchaseCheckedProducts];
    [m_RestoreProductID removeAllObjects];
    m_RestoreProductID = nil;

    for (StorePackInfo *info in m_RestorePackInfo) {
        [self updatePurchasedTableCell:info];
    }

    int missing = 0;
    for (StorePackInfo *info in m_RestorePackInfo) {
        for (StoreMusicInfo *music in [info musicInfos]) {
            NSString *path = [[MusicManager getInstance] getPathFromPurchased:[music musicID]];
            if (!RhFileExists(path)) {
                missing++;
            }
        }
    }
    if (missing > 0) {
        CommonAlertView *alert =
            [[CommonAlertView alloc] initWithTitle:@"パックの再インストール"
                                           message:@"復元されたパックをすべてインストールしますか？"
                                          delegate:self
                                 cancelButtonTitle:@"Cancel"
                                 otherButtonTitles:@"OK"];
        alert.tag = 0x1e;
        [alert show];
        return;
    }
    [m_RestorePackInfo removeAllObjects];
    m_RestorePackInfo = nil;
    [m_StoreViewCtrl hideModalDialog];
}

// @ 0x4753c — download every missing music across the restored packs (grants
// tickets), then start the download manager (or hide the modal when nothing is
// missing).
- (void)restoreDownloadAllMusics {
    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:0];
    for (StorePackInfo *info in m_RestorePackInfo) {
        NSString *productID = [StoreUtil productIDForPackID:[info packID]];
        if (![CharaTicketData isExistData:productID
                   inManagedObjectContext:[[AppDelegate appDelegate] managedObjectContext]]) {
            [UserSettingData addCharaTicket:5];
            [CharaTicketData
                addRecordWithProductId:productID
                inManagedObjectContext:[[AppDelegate appDelegate] managedObjectContext]];
        }
        for (StoreMusicInfo *music in [info musicInfos]) {
            NSString *path = [[MusicManager getInstance] getPathFromPurchased:[music musicID]];
            if (!RhFileExists(path)) {
                StoreDownloadTask *task = [[StoreDownloadTask alloc]
                    initWithURL:[music itemURL]
                           path:path
                      AddObject:[NSString stringWithString:[music name]]];
                [tasks addObject:task];
            }
        }
    }
    [m_RestorePackInfo removeAllObjects];
    m_RestorePackInfo = nil;

    if ([tasks count] == 0) {
        [m_StoreViewCtrl hideModalDialog];
    } else {
        m_DownloadManager = [[StoreDownloadManager alloc] initWithTasks:tasks delegate:self];
        id dialog = [m_StoreViewCtrl modalDialog];
        [dialog layout:0];
        [[dialog labelMessage] setText:@""];
        [[dialog progressView] setProgress:0];
        [m_DownloadManager start];
    }
}

// @ 0x47c14 — StoreKit restore succeeded: reset the restore accumulators, seed
// the pending product-id list from the purchase-checked products, and start
// walking them.
- (void)restoreSucceeded {
    if (m_RestorePackInfo) {
        [m_RestorePackInfo removeAllObjects];
        m_RestorePackInfo = nil;
    }
    m_RestorePackInfo = [[NSMutableArray alloc] initWithCapacity:0];
    if (m_RestoreProductID) {
        [m_RestoreProductID removeAllObjects];
        m_RestoreProductID = nil;
    }
    m_RestoreProductID = [[NSMutableArray alloc]
        initWithArray:[[PurchaseManager sharedManager] purchaseCheckedProducts]];
    if (![self nextRestorePackInfo]) {
        [self askDownloadAllMusics];
    }
}

// @ 0x47d50 — StoreKit restore failed: hide the modal and report.
- (void)restoreFailed:(NSError *)error {
    [m_StoreViewCtrl hideModalDialog];
    NSString *message = [[NSString alloc]
        initWithFormat:@"購入はキャンセルされました。\n\n%@", [error localizedDescription]];
    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"Error"
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
    [alert show];
}

// @ 0x47e40 — StoreKit reported nothing to restore: just hide the modal.
- (void)restoreNothing {
    [m_StoreViewCtrl hideModalDialog];
}

#pragma mark - Downloader delegates

// @ 0x47e60 — a missing pack's detail finished downloading during a restore:
// fold it in and continue walking (or move on to the download-all prompt).
- (void)storePackInfoDownloaderFinished:(StorePackInfoDownloader *)downloader {
    [self addRestorePackInfo:downloader.packInfo]; // @0x57734 packInfo getter (no
                                                   // getPackInfo selector)
    if (m_StorePackInfoDownloader) {
        [m_StorePackInfoDownloader setDelegate:nil];
        m_StorePackInfoDownloader = nil;
    }
    if (![self nextRestorePackInfo]) {
        [self askDownloadAllMusics];
    }
}

// @ 0x47ef4 — a restore-time detail fetch errored: drop the downloader.
- (void)storePackInfoDownloaderError:(StorePackInfoDownloader *)downloader {
    if (m_StorePackInfoDownloader == nil) {
        return;
    }
    [m_StorePackInfoDownloader setDelegate:nil];
    m_StorePackInfoDownloader = nil;
}

// @ 0x47f38 — the download manager began the next file: show its name in the
// modal.
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager {
    id name = [[[manager tasks] objectAtIndex:[manager currentIndex]] addObject];
    id label = [[m_StoreViewCtrl modalDialog] labelMessage];
    [label setText:[NSString stringWithFormat:@"『%@』をダウンロード中...", name]];
}

// @ 0x47ffc — all files downloaded: drop the manager, mark the detail button
// installed and hide the modal.
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    m_DownloadManager = nil;
    m_PurchasingPackInfo = nil;
    if (!m_IsPad) {
        UIViewController *top = self.navigationController.topViewController;
        if ([top isKindOfClass:[StoreDetailViewController class]]) {
            [(id)top setButtonTextInstalled];
        }
    } else {
        [m_PackDetailViewPad setButtonTextInstalled];
    }
    [m_StoreViewCtrl hideModalDialog];
}

// @ 0x48108 — a download failed: drop the manager, hide the modal, report, and
// let the detail re-check its caption.
- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    m_DownloadManager = nil;
    [m_StoreViewCtrl hideModalDialog];
    NSString *message = @"ダウンロードに失敗しました。\nネットワーク接続をご確認下さい。";
    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"Error"
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
    [alert show];
    if (!m_IsPad) {
        UIViewController *top = self.navigationController.topViewController;
        if (![top isKindOfClass:[StoreDetailViewController class]]) {
            return;
        }
        [(id)top selfCheckButtonText];
    } else {
        [m_PackDetailViewPad selfCheckButtonText];
    }
}

// @ 0x482c0 — a download progressed: push the overall progress into the modal's
// bar.
- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    UIProgressView *progressView = [[m_StoreViewCtrl modalDialog] progressView];
    [progressView setProgress:[m_DownloadManager overallProgress]];
}

// @ 0x495e4 — a jacket finished loading: drop it into the on-screen cell
// (phone: one StorePackCell per row; iPad: the left/right pack view of a
// StoreTableCell).
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    UITableView *table = (UITableView *)[self.view viewWithTag:10000];
    if (!m_IsPad) {
        UITableViewCell *cell = [table cellForRowAtIndexPath:indexPath];
        UIImage *image = [downloader getImage];
        if (cell == nil || image == nil) {
            return;
        }
        [[(StorePackCell *)cell artworkView] setImage:image];
    } else {
        NSIndexPath *ip = [NSIndexPath indexPathForRow:(indexPath.row / 2)
                                             inSection:indexPath.section];
        UITableViewCell *cell = [table cellForRowAtIndexPath:ip];
        UIImage *image = [downloader getImage];
        if (cell == nil || image == nil) {
            return;
        }
        id packView = (indexPath.row & 1) ? [(StoreTableCell *)cell rightPackView] :
                                            [(StoreTableCell *)cell leftPackView];
        [packView setArtwork:image];
    }
}

// @ 0x49750 — a jacket failed to load (no-op in the binary).
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
}

// @ 0x49b6c — cancel + drop every in-flight jacket ImageDownloader.
- (void)stopDownloadArtworks {
    if ([m_ArtworkDownloaders count] != 0) {
        for (ImageDownloader *downloader in [m_ArtworkDownloaders allValues]) {
            [downloader setDelegate:nil];
            [downloader cancelDownload];
        }
        [m_ArtworkDownloaders removeAllObjects];
    }
}

#pragma mark - Alert delegate

// @ 0x47a04 — CommonAlertView button handler. Tag 0x1f = the restore-confirm
// alert (begin the StoreKit restore on "OK"); tag 0x1e = the download-all
// prompt (start the downloads on "OK", else abandon the restore).
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    NSInteger tag = alertView.tag;
    if (tag == 0x1f) {
        if (index == 1) {
            if (![PurchaseManager isPurchasable]) {
                CommonAlertView *alert = [[CommonAlertView alloc]
                        initWithTitle:@"Error"
                              message:@"アプリケーション内購入が許可されていません。"
                             delegate:nil
                    cancelButtonTitle:@"OK"
                    otherButtonTitles:nil];
                [alert show];
            } else {
                id dialog = [m_StoreViewCtrl modalDialog];
                [dialog layout:1];
                [[dialog labelMessage] setText:@"処理中..."];
                [m_StoreViewCtrl showModalDialog:self];
                [[PurchaseManager sharedManager] setMusicDataDelegate:self];
                [[PurchaseManager sharedManager] beginRestore];
            }
        }
        _isAlertViewShowing = NO;
    } else if (tag == 0x1e) {
        if (index == 1) {
            [self restoreDownloadAllMusics];
        } else {
            [m_RestorePackInfo removeAllObjects];
            m_RestorePackInfo = nil;
            [m_StoreViewCtrl hideModalDialog];
        }
    }
}

#pragma mark - UITableView data source / delegate

// @ 0x4832c — number of pack rows: the pack-id count, halved (rounding up) on
// iPad where two packs share a row.
- (NSInteger)numPackRows {
    NSInteger count = [[m_PackListCtrl packIDList] count];
    if (m_IsPad) {
        count = (count + 1) >> 1;
    }
    return count;
}

// @ 0x48fc0 — phone has a promotion section + a pack section; iPad has just the
// packs.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return m_IsPad ? 1 : 2;
}

// @ 0x48fd8 — phone promo section is one row; the pack section is numPackRows
// (+1 for the "show more" footer while the list continues).
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rows;
    if (!m_IsPad && section == 0) {
        rows = 1;
    } else {
        rows = [self numPackRows];
        if ([m_PackListCtrl packlistContinued]) {
            rows += 1;
        }
    }
    return rows;
}

// @ 0x49038 — row heights: phone promo scales to the table width (730:240);
// pack rows are 104 (phone) / 140 (iPad), the "show more" footer 84 (phone) /
// 60 (iPad).
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!m_IsPad) {
        if (indexPath.section == 0) {
            CGFloat width = tableView ? tableView.bounds.size.width : 0.0f;
            return width * 240.0f / 730.0f;
        }
        return (indexPath.row < [self numPackRows]) ? 104.0f : 84.0f;
    }
    return (indexPath.row < [self numPackRows]) ? 140.0f : 60.0f;
}

// @ 0x4837c — build a cell: phone section 0 = the promotion banner; the pack
// section is one StorePackCell per pack (phone) or a StoreTableCell holding two
// StorePackViews (iPad); the trailing row is the "show more" footer. Jackets
// load lazily through an ImageDownloader keyed by the row's index path.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *ids = [m_PackListCtrl packIDList];
    UIImage *placeholder = [UIImage imageNamed:@"store_jacket_128.png"];
    UITableViewCell *cell = nil;

    if (!m_IsPad && indexPath.section == 0) {
        // Promotion banner cell.
        StorePromotionTableCell *promoCell = (StorePromotionTableCell *)[tableView
            dequeueReusableCellWithIdentifier:@"StorePromotionCell"];
        if (promoCell == nil) {
            promoCell = [[StorePromotionTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:@"StorePromotionCell"];
        }
        [promoCell.contentView addSubview:m_PromotionView];
        [promoCell.contentView addSubview:m_PromotionViewDummy];
        cell = promoCell;
    } else if (indexPath.row < [self numPackRows]) {
        if (!m_IsPad) {
            // One pack per row (phone).
            StorePackCell *packCell =
                (StorePackCell *)[tableView dequeueReusableCellWithIdentifier:@"StorePacklistCell"];
            if (packCell == nil) {
                packCell = [[StorePackCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                reuseIdentifier:@"StorePacklistCell"];
            }
            int packID = [[ids objectAtIndex:indexPath.row] intValue];
            StorePackInfo *info = [m_PackListCtrl getPackInfo:packID];
            [packCell loadPackInfo:info];
            UIImage *art = [self artworkForInfo:info atIndexPath:indexPath];
            [packCell.artworkView setImage:(art ? art : placeholder)];
            cell = packCell;
        } else {
            // Two packs per row (iPad).
            NSString *rid =
                (indexPath.row & 1) ? @"StorePacklistCellOdd" : @"StorePacklistCellEven";
            StoreTableCell *tableCell =
                (StoreTableCell *)[tableView dequeueReusableCellWithIdentifier:rid];
            if (tableCell == nil) {
                tableCell = [[StoreTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                  reuseIdentifier:rid];
                [[tableCell leftPackView] setDelegate:self];
                [[tableCell rightPackView] setDelegate:self];
                UIImage *bg = (indexPath.row & 1) ? m_PackBgImage1 : m_PackBgImage0;
                [[tableCell leftPackView] setBgImage:bg];
                [[tableCell rightPackView] setBgImage:bg];
            }

            NSInteger leftIndex = indexPath.row * 2;
            int leftPackID = [[ids objectAtIndex:leftIndex] intValue];
            StorePackInfo *leftInfo = [m_PackListCtrl getPackInfo:leftPackID];
            [[tableCell leftPackView] loadPackInfo:leftInfo
                                             index:static_cast<unsigned int>(leftIndex)];
            NSIndexPath *leftIP = [NSIndexPath indexPathForRow:leftIndex
                                                     inSection:indexPath.section];
            UIImage *leftArt = [self artworkForInfo:leftInfo atIndexPath:leftIP];
            [[tableCell leftPackView] setArtwork:(leftArt ? leftArt : placeholder)];

            NSInteger rightIndex = indexPath.row * 2 + 1;
            if (rightIndex < (NSInteger)[ids count]) {
                [[tableCell rightPackView] setHidden:NO];
                int rightPackID = [[ids objectAtIndex:rightIndex] intValue];
                StorePackInfo *rightInfo = [m_PackListCtrl getPackInfo:rightPackID];
                [[tableCell rightPackView] loadPackInfo:rightInfo
                                                  index:static_cast<unsigned int>(rightIndex)];
                NSIndexPath *rightIP = [NSIndexPath indexPathForRow:rightIndex
                                                          inSection:indexPath.section];
                UIImage *rightArt = [self artworkForInfo:rightInfo atIndexPath:rightIP];
                [[tableCell rightPackView] setArtwork:(rightArt ? rightArt : placeholder)];
            } else {
                [[tableCell rightPackView] setHidden:YES];
            }
            cell = tableCell;
        }
    } else {
        // "Show more" footer row.
        UITableViewCell *moreCell =
            [tableView dequeueReusableCellWithIdentifier:@"StorePacklistMoreCell"];
        if (moreCell == nil) {
            moreCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:@"StorePacklistMoreCell"];
            moreCell.textLabel.font = [UIFont fontWithName:AppFontName()
                                                      size:(m_IsPad ? 18.0f : 15.0f)];
            moreCell.textLabel.textAlignment = NSTextAlignmentCenter; // 1
        }
        if (!m_IsLoadingMoreList) {
            moreCell.accessoryView = nil;
            moreCell.textLabel.textColor = [UIColor colorWithWhite:0.8f alpha:1.0f];
            moreCell.textLabel.shadowColor = [UIColor colorWithWhite:0.4f alpha:1.0f];
            moreCell.textLabel.text = @"▼ SHOW MORE ▼";
        } else {
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
                initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
            spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray; // 1
            moreCell.accessoryView = spinner;
            [spinner startAnimating];
            moreCell.textLabel.textColor = [UIColor colorWithWhite:0.4f alpha:1.0f];
            moreCell.textLabel.shadowColor = nil;
            moreCell.textLabel.text = @"読み込み中...";
        }
        cell = moreCell;
    }

    // Common tail (LAB_00048f5a): everything wants exclusive touch.
    if (m_PromotionView) {
        [m_PromotionView setExclusiveTouch:YES];
    }
    [cell setExclusiveTouch:YES];
    [cell.contentView setExclusiveTouch:YES];
    return cell;
}

// Lazy jacket loader shared by the three cellForRowAtIndexPath: paths (inlined
// in the binary): returns the cached artwork, or nil while an ImageDownloader
// (keyed by the index path) fetches it.
- (UIImage *)artworkForInfo:(StorePackInfo *)info atIndexPath:(NSIndexPath *)indexPath {
    ImageDownloader *downloader = [m_ArtworkDownloaders objectForKey:indexPath];
    if (downloader != nil) {
        return [downloader getImage];
    }
    if ([info artworkURL] == nil) {
        return nil;
    }
    downloader = [[ImageDownloader alloc] init];
    [downloader setImageURL:[info artworkURL]];
    [downloader setIndexPathInTableView:indexPath];
    [downloader setDelegate:self];
    [m_ArtworkDownloaders setObject:downloader forKey:indexPath];
    [downloader startDownload];
    return nil;
}

// @ 0x4912c — colour each cell as it appears: phone pack rows take the
// alternating pack backdrop, everything else a flat grey (packs 0.5 iPad,
// footer 0.6).
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat white;
    if (!m_IsPad) {
        if (indexPath.section == 0) {
            return;
        }
        if (indexPath.row < [self numPackRows]) {
            UIImage *bg = (indexPath.row & 1) ? m_PackBgImage1 : m_PackBgImage0;
            [(id)cell setBgImage:bg];
            return;
        }
        white = 0.6f; // 0x3f19999a
    } else {
        white = (indexPath.row < [self numPackRows]) ? 0.5f : 0.6f;
    }
    cell.backgroundColor = [UIColor colorWithWhite:white alpha:1.0f];
}

// @ 0x49258 — a phone pack row was tapped: push its detail (ignored on iPad /
// when not the visible controller / on the "show more" footer).
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.navigationController.topViewController == self && !m_IsPad &&
        indexPath.row < [self numPackRows]) {
        int packID = [[[m_PackListCtrl packIDList] objectAtIndex:indexPath.row] intValue];
        [self showDetailViewForPhone:packID];
        neEngine::playSystemSe(1); // decide SE
    }
}

#pragma mark - UIScrollView delegate

// @ 0x49754 — infinite scroll (fire "show more" near the bottom) plus the
// parallax that keeps the store_fun banner (tag 0x186a1) pinned to the content.
// The banner clamp is runtime-derived (contentOffset + bounds height), so no
// literal constants to recover.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!m_IsLoadingMoreList && [m_PackListCtrl packlistContinued]) {
        CGFloat bottom = scrollView.contentOffset.y + scrollView.bounds.size.height;
        if (scrollView.contentSize.height < bottom && [m_StoreViewCtrl recommendPackId] == -1) {
            [self selectShowMore];
        }
    }

    UITableView *table = (UITableView *)[self.view viewWithTag:10000];
    UIView *banner = [table viewWithTag:0x186a1];
    if (banner == nil) {
        return;
    }
    CGFloat slack = m_IsPad ? 300.0f : 100.0f;
    CGRect frame = banner.frame;
    CGFloat visibleBottom = scrollView.contentOffset.y + scrollView.bounds.size.height;
    CGFloat y;
    if (table.contentSize.height < table.bounds.size.height) {
        y = slack + visibleBottom - (CGFloat)m_OffsetForOS;
        if (slack + frame.size.height < y) {
            y = visibleBottom - frame.size.height - (CGFloat)m_OffsetForOS;
        }
    } else {
        y = slack + table.contentSize.height;
        if (slack + frame.size.height < visibleBottom) {
            y = visibleBottom - frame.size.height;
        }
    }
    frame.origin.y = y;
    banner.frame = frame;
}

// @ 0x49b64 — no-op in the binary.
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
}

// @ 0x49b68 — no-op in the binary.
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
}

#pragma mark - View lifecycle

// @ 0x49c84 — coming back on screen (phone): refresh + deselect the previously
// selected pack row so its purchased state updates.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UITableView *table = (UITableView *)[self.view viewWithTag:10000];
    if (!m_IsPad && ![table isHidden]) {
        NSIndexPath *selected = [table indexPathForSelectedRow];
        if (selected != nil) {
            [table reloadRowsAtIndexPaths:[NSArray arrayWithObject:selected]
                         withRowAnimation:UITableViewRowAnimationNone]; // 5
            [table deselectRowAtIndexPath:selected animated:animated];
        }
    }
}

// @ 0x49d64 — first appearance kicks off the initial fetch (hiding the empty
// label + table); otherwise re-run the success path to lay everything out.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[m_PackListCtrl packIDList] count] == 0 && ![m_PackListCtrl isFetching]) {
        [[self.view viewWithTag:0x2712] setHidden:YES];
        [[self.view viewWithTag:10000] setHidden:YES];
        [m_PackListCtrl startFetchingPack:[m_StoreViewCtrl recommendPackId]];
    } else {
        [self packListDownloadSuccess:m_PackListCtrl];
    }
}

// @ 0x49e88 — leaving the screen: stop the iPad detail card, cancel any
// in-flight page / detail fetch and re-enable the table.
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (m_IsPad) {
        [m_PackDetailViewPad cancelLoading];
        [m_PackDetailViewPad stopSample];
    }
    if ([m_PackListCtrl isFetching]) {
        m_IsLoadingMoreList = NO;
        UITableView *table = (UITableView *)[self.view viewWithTag:10000];
        [table setAllowsSelection:YES];
        [table reloadData];
    }
    if (m_StorePackInfoDownloader) {
        [m_StorePackInfoDownloader setDelegate:nil];
        [m_StorePackInfoDownloader cancel];
        m_StorePackInfoDownloader = nil;
    }
    [m_PackListCtrl cancelFetching];
}

// @ 0x49fe4 — viewDidDisappear: super-only, kept for the annotation.
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

// @ 0x4a010 — allow every orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return YES;
}

// @ 0x4a014 — no-op in the binary.
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                duration:(NSTimeInterval)duration {
}

// didReceiveMemoryWarning @ 0x4a018 — super-only override, omitted.

// @ 0x4a044 — dealloc: KEPT under ARC because it actively tears down live work
// — cancels the restore detail downloader, detaches the table, stops the jacket
// loads, cancels the download manager and detaches/cancels the promotion view.
// ARC releases the ivars, so the object-only release lines and [super dealloc]
// are omitted.
- (void)dealloc {
    if (m_StorePackInfoDownloader) {
        [m_StorePackInfoDownloader setDelegate:nil];
        [m_StorePackInfoDownloader cancel];
        m_StorePackInfoDownloader = nil;
    }
    UITableView *table = (UITableView *)[self.view viewWithTag:10000];
    [table setDelegate:nil];
    [table setDataSource:nil];
    [self stopDownloadArtworks];
    m_ArtworkDownloaders = nil;
    [m_DownloadManager cancel];
    m_DownloadManager = nil;
    m_RestoreProductID = nil;
    m_RestorePackInfo = nil;
    m_PackListCtrl = nil;
    m_RecommendPackListCtrl = nil;
    m_PackBgImage0 = nil;
    m_PackBgImage1 = nil;
    [m_PromotionView setDelegate:nil];
    [m_PromotionView cancel];
    m_PromotionView = nil;
    m_PromotionViewDummy = nil;
    [m_PackDetailViewPad setDelegate:nil];
}

@end
