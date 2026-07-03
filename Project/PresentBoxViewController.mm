//
//  PresentBoxViewController.mm
//  pop'n rhythmin
//
//  See PresentBoxViewController.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Objective-C++ for the C++ neSceneManager / neEngine singletons. ARC.
//
//  Honesty notes:
//   - Present rows are NSValue-wrapped PresentData ({presentId,itemId,itemNum,info};
//     see DownloadMain.h). -downloadMainFinished: is the shared DownloadMain callback
//     (performSelector-style NSNumber result): <0 = network error, ==1 = a present
//     claim finished, ==0 = the present list finished. On a claim it credits the
//     player's Crypt109 charaTicket (itemId 1) or treasurePoint (itemId 0) for every
//     matching row (all rows when getPresentId == -1, i.e. "acquire all"), and on the
//     acquire-all path shows a "一括受け取り" gift alert before re-fetching the list.
//   - The alert strings are exact CFString decodes (UTF-16LE): network-failure message
//     "通信に失敗しました。\n電波状態の良い場所でやり直して下さい。" (OK); the acquire-all
//     gift alert "一括受け取り" / "プレゼントを受け取りました。" (OK); the per-row claim
//     confirm uses the item text as title ("キャラチケ %d枚" / "トレジャーポイント %dP"),
//     the row's Info blurb as message, "キャンセル" (index 0) and "受け取る" (index 1).
//   - Open/close animations: on phone a 0.3s alpha fade (didStop -> end*Animation); on
//     pad a two-phase ~1/6 s frame slide via animateWithDuration.  Open: park at
//     rootView.height, slide to y=420 (setNavViewFrameA @ 0x24f40), then settle to
//     y=470 (setNavViewFrameB @ 0x25078), then endOpenAnimation.  Close: slide from
//     470 → 420 (setNavViewFrameC @ 0x25320), then park below screen
//     (setNavViewFrameFromSubview @ 0x25460), then endCloseAnimation.  The binary's
//     two first-phase animation blocks are byte-identical (both target y=420); the
//     +[UIView commitAnimations] call is unconditional after both phone and pad
//     branches (a stray no-op on the pad/block path) — reproduced for fidelity.
//   - -endCloseAnimation removes the nav host and pokes the menu's -PresentBoxEndCallBack
//     (the root VC is a MainViewController, which owns that selector @ 0xe0d4).
//   - The dummy overlay carries the download spinner; -isAnimationing is an atomic read
//     (the binary issues a data-memory-barrier before loading the flag).
//

#import "PresentBoxViewController.h"

#import "PresentBoxCell.h"    // one row per present
#import "CommonAlertView.h"   // network-failure alert
#import "CustomAlertView.h"   // per-row claim confirm + acquire-all gift alert
#import "DownloadMain.h"      // present list/claim + PresentData struct + DownloadMainDelegate
#import "UserSettingData.h"   // charaTicket / treasurePoint credit
#import "MainViewController.h" // -PresentBoxEndCallBack (root VC)
#import "neEngineBridge.h"    // neSceneManager::isPadDisplay/rootViewController, neEngine::playSystemSe

// ---------------------------------------------------------------------------
// Block invoke helpers emitted by the compiler after startOpenAnimation
// (0x24c98) and startCloseAnimation (0x25160).  Placement: file-static.
// ---------------------------------------------------------------------------

// Ghidra: setNavViewFrameA @ 0x24f40
// Slides the navigation controller view to y = 420.0.
// Animations block, first phase of the iPad open animation.
static void setNavViewFrameA(PresentBoxViewController *self) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    f.origin.y = 420.0f;
    self.navigationController.view.frame = f;
}

// Ghidra: setNavViewFrameB @ 0x25078
// Settles the navigation controller view to y = 470.0.
// Animations block of the settle phase (second step of open).
static void setNavViewFrameB(PresentBoxViewController *self) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    f.origin.y = 470.0f;
    self.navigationController.view.frame = f;
}

// Ghidra: setNavViewFrameC @ 0x25320
// Slides the navigation controller view back to y = 420.0.
// Animations block, first phase of the iPad close animation.
static void setNavViewFrameC(PresentBoxViewController *self) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    f.origin.y = 420.0f;
    self.navigationController.view.frame = f;
}

// Ghidra: setNavViewFrameFromSubview @ 0x25460
// Parks the navigation controller view off-screen below the root view.
// Animations block, second phase of the iPad close animation.  Captures self
// and a reference UIViewController; sets nav-view origin.y to refController's
// view height.
static void setNavViewFrameFromSubview(PresentBoxViewController *self,
                                       UIViewController *refController) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    UIView *ref = refController.view;
    f.origin.y = ref ? ref.frame.size.height : 0.0f;
    self.navigationController.view.frame = f;
}

@interface PresentBoxViewController () <DownloadMainDelegate>
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)backButtonFunc;
- (void)allGetFunc;
- (NSIndexPath *)indexPathForControlEvent:(UIEvent *)event;
- (void)touchedGetButton:(id)sender event:(UIEvent *)event;
- (void)downloadMainFinished:(NSNumber *)result;
@end

@implementation PresentBoxViewController {
    UIViewController *_dummyView;         // dimmed overlay hosting the download spinner
    UIImageView *_emptyImageView;         // "no presents" banner (centred over the table)
    UIButton *_btnGetAll;                 // "acquire all" button
    BOOL _isAnimationing;                 // open/close animation in flight
    NSMutableArray *_presentDataArray;    // parsed rows (NSValue-wrapped PresentData)
    CustomAlertView *_customAlert;        // live per-row claim confirm
    NSValue *_presentDataValue;           // the row awaiting confirm (bound in touchedGetButton:)
}

// @ 0x24098 — build the table (empty spacer header, phone backdrop), the dimmed dummy
// overlay + spinner, the phone back button, the empty-state banner and the acquire-all
// button; inset the content by the acquire button's height.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        CGRect viewFrame = self.view ? self.view.frame : CGRectZero;
        BOOL isPad = neSceneManager::isPadDisplay();

        self.tableView.rowHeight = isPad ? 59.0f : 54.0f;   // DAT_00024934 / DAT_00024930
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.separatorColor = [UIColor clearColor];

        // Empty 20pt-tall clear spacer header.
        UIView *headerView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewFrame.size.width, 20.0f)];
        headerView.backgroundColor = [UIColor clearColor];
        self.tableView.tableHeaderView = headerView;

        // Phone: a "friman_bg" backdrop; pad: no backdrop, clear background.
        if (!isPad) {
            UIImage *bgImg = [UIImage imageNamed:@"friman_bg"];
            UIImageView *bgImgView = [[UIImageView alloc] initWithImage:bgImg];
            bgImgView.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
            self.tableView.backgroundView = bgImgView;
        } else {
            self.tableView.backgroundColor = [UIColor clearColor];
            self.tableView.backgroundView = nil;
        }

        // Dimmed dummy overlay carrying the download spinner (hidden until viewDidLoad).
        _dummyView = [[UIViewController alloc] init];
        _dummyView.view.frame = viewFrame;
        _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
        _dummyView.view.hidden = YES;
        [self.view addSubview:_dummyView.view];

        UIActivityIndicatorView *spinner =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        spinner.center = CGPointMake(viewFrame.size.width * 0.5f,
                                     (int)(viewFrame.size.height * 0.5f) - 10);
        spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
        [spinner startAnimating];
        [_dummyView.view addSubview:spinner];

        // Phone-only custom back button.
        if (!neSceneManager::isPadDisplay()) {
            UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
            UIButton *backBtn = [[UIButton alloc]
                initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
            [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
            [backBtn addTarget:self action:@selector(backButtonFunc)
              forControlEvents:UIControlEventTouchUpInside];
            self.navigationItem.leftBarButtonItem =
                [[UIBarButtonItem alloc] initWithCustomView:backBtn];
        }

        // Empty-state banner ("pbox_no_pbox"), hidden until the list is known empty.
        UIImage *emptyImg = [UIImage imageNamed:@"pbox_no_pbox"];
        _emptyImageView = [[UIImageView alloc] initWithImage:emptyImg];
        _emptyImageView.frame = CGRectMake(0, 0, emptyImg.size.width, emptyImg.size.height);
        _emptyImageView.hidden = YES;
        [self.view addSubview:_emptyImageView];

        // Acquire-all button ("pbox_bt_acquis"): y = -10 pre-iOS 7, else -15; on pad its
        // x-centre is pinned to 170.
        _btnGetAll = [[UIButton alloc] init];
        UIImage *btnImg = [UIImage imageNamed:@"pbox_bt_acquis"];
        CGFloat sysVer = UIDevice.currentDevice.systemVersion.floatValue;
        [_btnGetAll setBackgroundImage:btnImg forState:UIControlStateNormal];
        _btnGetAll.frame = CGRectMake(0, (sysVer < 7.0f) ? -10.0f : -15.0f,
                                      btnImg.size.width, btnImg.size.height);
        if (neSceneManager::isPadDisplay()) {
            _btnGetAll.center = CGPointMake(170.0f, _btnGetAll.center.y);
        }
        _btnGetAll.hidden = YES;
        [_btnGetAll addTarget:self action:@selector(allGetFunc)
             forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_btnGetAll];

        // Inset the table so its first row clears the (overlapping) acquire button.
        self.tableView.contentInset = UIEdgeInsetsMake(btnImg.size.height, 0, 0, 0);
    }
    return self;
}

// @ 0x24938 — wrap a freshly (re)initialised controller in a portrait nav host.
- (UINavigationController *)initAtNavigationController {
    UINavigationController *nav = [UINavigationController alloc];
    PresentBoxViewController *vc = [self initWithStyle:UITableViewStyleGrouped];   // style 1
    return [nav initWithRootViewController:vc];
}

// @ 0x24988 — detach from the DownloadMain present delegates (kept under ARC because it
// detaches DownloadMain callbacks so no late message fires into a dead controller). The
// _customAlert delegate is also cleared; object-ivar releases are ARC-managed.
- (void)dealloc {
    if (_customAlert != nil) {
        _customAlert.delegate = nil;
    }
    [_emptyImageView removeFromSuperview];
    [_btnGetAll removeFromSuperview];

    DownloadMain *dm = [DownloadMain getInstance];
    if (dm.delegateGetPresentList == self) {
        dm.delegateGetPresentList = nil;
    }
    if (dm.delegateGetPresent == self) {
        dm.delegateGetPresent = nil;
    }
}

// @ 0x24abc — reveal the spinner, register as the present list/claim delegate and kick
// off the list fetch. On pad, size for the popover host.
- (void)viewDidLoad {
    [super viewDidLoad];
    if (neSceneManager::isPadDisplay()) {
        [self setContentSizeForViewInPopover:CGSizeMake(320.0f, 524.0f)];
    }
    _dummyView.view.hidden = NO;

    DownloadMain *dm = [DownloadMain getInstance];
    dm.delegateGetPresentList = self;
    [dm startGetPresentListHttp];
    dm.delegateGetPresent = self;
}

// @ 0x24ba4 — recentre the empty-state banner in the view (the binary does NOT chain to
// super here).
- (void)viewWillAppear:(BOOL)animated {
    CGRect f = self.view.frame;
    _emptyImageView.center =
        CGPointMake(f.size.width * 0.5f, f.size.height * 0.5f - 5.0f);
}

// didReceiveMemoryWarning @ 0x24c6c — super-only override, ARC/omit.

#pragma mark - Open / close animation

// @ 0x24c98
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;

    if (!neSceneManager::isPadDisplay()) {
        self.view.alpha = 0.0f;
        self.navigationController.view.alpha = 0.0f;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];                       // DAT_00024f38
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
        self.view.alpha = 1.0f;
        self.navigationController.view.alpha = 1.0f;
    } else {
        UIViewController *rootVC = neSceneManager::rootViewController();
        // Park the nav host just below the root view, then slide it up to y = 420.
        CGRect start = self.navigationController.view.frame;
        start.origin.y = rootVC.view.frame.size.height;
        self.navigationController.view.frame = start;
        // Phase 1 (~1/6 s): slide from off-screen to y = 420 (setNavViewFrameA @ 0x24f40).
        // Phase 2 (~1/6 s): settle to y = 470 (setNavViewFrameB @ 0x25078), then
        //   call -endOpenAnimation.
        [UIView animateWithDuration:0.16666667 delay:0 options:0     // DAT_00024f30
                         animations:^{
                             setNavViewFrameA(self);   // Ghidra: setNavViewFrameA @ 0x24f40
                         }
                         completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.16666667 delay:0 options:0
                                              animations:^{
                                                  setNavViewFrameB(self); // Ghidra: setNavViewFrameB @ 0x25078
                                              }
                                              completion:^(BOOL f2) {
                                                  [self endOpenAnimation];
                                              }];
                         }];
    }
    [UIView commitAnimations];   // paired on phone; a stray no-op on the pad/block path
}

// @ 0x2514c
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0x25160
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;

    if (!neSceneManager::isPadDisplay()) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];                        // DAT_00025318
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0.0f;
        self.navigationController.view.alpha = 0.0f;
    } else {
        // Phase 1 (~1/6 s): slide from y = 470 back to y = 420 (setNavViewFrameC @ 0x25320).
        // NOTE: the binary's open- and close-animation first blocks are byte-identical
        // (both target y = 420); the symmetry here is intentional — reproduced for fidelity.
        // Phase 2 (~1/6 s): park below screen (setNavViewFrameFromSubview @ 0x25460), then
        //   call -endCloseAnimation.
        UIViewController *rootVC = neSceneManager::rootViewController();
        [UIView animateWithDuration:0.16666667 delay:0 options:0     // DAT_00025310
                         animations:^{
                             setNavViewFrameC(self);   // Ghidra: setNavViewFrameC @ 0x25320
                         }
                         completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.16666667 delay:0 options:0
                                              animations:^{
                                                  // Ghidra: setNavViewFrameFromSubview @ 0x25460
                                                  setNavViewFrameFromSubview(self, rootVC);
                                              }
                                              completion:^(BOOL f2) {
                                                  [self endCloseAnimation];
                                              }];
                         }];
    }
    [UIView commitAnimations];   // paired on phone; a stray no-op on the pad/block path
}

// @ 0x255bc — tear the nav host down and notify the menu the present box has closed.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    [root PresentBoxEndCallBack];
    _isAnimationing = NO;
}

#pragma mark - Table

// @ 0x25628
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x2562c
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _presentDataArray ? [_presentDataArray count] : 0;
}

// @ 0x25668 — one PresentBoxCell per row; wire its acquire button to -touchedGetButton:event:.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld-%ld",
                            (long)indexPath.section, (long)indexPath.row];
    PresentBoxCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[PresentBoxCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:identifier];
    }
    [cell setPresentData:[_presentDataArray objectAtIndex:indexPath.row]];
    [cell.getBtn addTarget:self action:@selector(touchedGetButton:event:)
          forControlEvents:UIControlEventTouchUpInside];
    return cell;
}

#pragma mark - DownloadMain delegate

// @ 0x257a8 — shared present callback. result.intValue: <0 network error, ==1 a claim
// finished, ==0 the present list finished.
- (void)downloadMainFinished:(NSNumber *)result {
    _dummyView.view.hidden = YES;
    DownloadMain *dm = [DownloadMain getInstance];

    if (result.intValue < 0) {
        _emptyImageView.hidden = NO;
        _btnGetAll.hidden = YES;
        [self.tableView setContentInset:UIEdgeInsetsZero];
        self.tableView.scrollEnabled = NO;
        CommonAlertView *alert = [[CommonAlertView alloc]
            initWithTitle:nil
                  message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
                 delegate:nil
        cancelButtonTitle:nil
        otherButtonTitles:@"OK"];
        [alert show];
        return;
    }

    if (result.intValue == 1) {
        // A present claim finished: credit every matching row (all rows for "acquire all").
        NSUInteger n = _presentDataArray.count;
        for (NSUInteger i = 0; i < n; i++) {
            PresentData data;
            [[_presentDataArray objectAtIndex:i] getValue:&data];
            if (dm.getPresentId == -1 || dm.getPresentId == data.presentId) {
                if (data.itemId == 1) {
                    [UserSettingData saveCharaTicket:
                        (short)([UserSettingData charaTicket] + data.itemNum)];
                } else if (data.itemId == 0) {
                    [UserSettingData saveTreasurePoint:
                        (short)([UserSettingData treasurePoint] + data.itemNum)];
                }
                if (data.presentId == dm.getPresentId) {
                    break;
                }
            }
        }

        if (dm.getPresentId == -1) {
            CGPoint center = neSceneManager::isPadDisplay() ? CGPointMake(170.0f, 240.0f)
                                                            : CGPointZero;
            CustomAlertView *gift = [[CustomAlertView alloc]
                initWithView:self.tableView
                      center:center
                        type:CustomAlertViewTypeGift
                       title:@"一括受け取り"
                     message:@"プレゼントを受け取りました。"
           cancelButtonTitle:nil
             otherButtonTitle:@"OK"];
            [gift setOpenAnimeType:CustomAlertViewAnimeTypeScale];
            [gift show];
        }

        [dm startGetPresentListHttp];
        [self.tableView reloadData];
    }

    if (result.intValue != 0) {
        return;   // the ==1 claim path stops here; only ==0 refreshes the list
    }

    // Present list finished: snapshot the parsed rows and update the empty / scroll state.
    _presentDataArray = [[dm presentDataArray] mutableCopy];
    NSUInteger count = _presentDataArray.count;
    if (count == 0) {
        _emptyImageView.hidden = NO;
        _btnGetAll.hidden = YES;
        [self.tableView setContentInset:UIEdgeInsetsZero];
    } else {
        _btnGetAll.hidden = NO;
    }
    self.tableView.scrollEnabled = (count != 0);
    [self.tableView reloadData];
}

#pragma mark - Actions

// @ 0x25cdc — back button: close the box (blocked unless we are the top VC and no claim
// confirm is up).
- (void)backButtonFunc {
    if (self.navigationController.topViewController != self) {
        return;
    }
    if (_customAlert != nil) {
        return;
    }
    neEngine::playSystemSe(2);   // cancel/back SE
    [self startCloseAnimation];
}

// @ 0x25d48 — "acquire all": claim every present (id -1), unless a claim is already running.
- (void)allGetFunc {
    neEngine::playSystemSe(1);   // decide/confirm SE
    DownloadMain *dm = [DownloadMain getInstance];
    if ([dm isGetPresentDownLoading]) {
        return;
    }
    [dm startGetPresentHttp:-1];
}

// @ 0x25db4 — map the control event's touch back to the table row it fired from.
- (NSIndexPath *)indexPathForControlEvent:(UIEvent *)event {
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint point = [touch locationInView:self.tableView];
    return [self.tableView indexPathForRowAtPoint:point];
}

// @ 0x25e34 — a row's acquire button: raise the per-row claim confirm alert.
- (void)touchedGetButton:(id)sender event:(UIEvent *)event {
    if (!neSceneManager::isPadDisplay()) {
        if (self.navigationController.topViewController != self) {
            return;
        }
        if (_customAlert != nil) {
            return;
        }
    }
    neEngine::playSystemSe(1);   // decide/confirm SE

    NSIndexPath *indexPath = [self indexPathForControlEvent:event];
    _presentDataValue = [_presentDataArray objectAtIndex:indexPath.row];

    PresentData data;
    [_presentDataValue getValue:&data];
    NSString *title = nil;
    if (data.itemId == 1) {
        title = [NSString stringWithFormat:@"キャラチケ %d枚", data.itemNum];
    } else if (data.itemId == 0) {
        title = [NSString stringWithFormat:@"トレジャーポイント %dP", data.itemNum];
    }

    UIViewController *rootVC = neSceneManager::rootViewController();
    CGPoint center = neSceneManager::isPadDisplay() ? CGPointMake(170.0f, 190.0f)
                                                    : CGPointZero;
    _customAlert = [[CustomAlertView alloc]
        initWithView:self.view
              center:center
                type:CustomAlertViewTypeGift
               title:title
             message:data.info
   cancelButtonTitle:@"キャンセル"
     otherButtonTitle:@"受け取る"];
    _customAlert.delegate = self;
    [rootVC.view bringSubviewToFront:self.view];
    [_customAlert setOpenAnimeType:CustomAlertViewAnimeTypeScale];
    [_customAlert show];
}

#pragma mark - CustomAlertView delegate

// @ 0x260a4 — confirm result: index 1 claims the bound present (unless one is already
// downloading); always drop the alert.
- (void)customAlertView:(CustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (index == 1) {
        DownloadMain *dm = [DownloadMain getInstance];
        if (![dm isGetPresentDownLoading]) {
            PresentData data;
            [_presentDataValue getValue:&data];
            [dm startGetPresentHttp:data.presentId];
        }
    }
    _customAlert.delegate = nil;
    _customAlert = nil;
}

// @ 0x26144 — atomic read of the animation-in-flight flag.
- (BOOL)isAnimationing {
    return _isAnimationing;
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
