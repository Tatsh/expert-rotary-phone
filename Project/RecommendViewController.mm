//
//  RecommendViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The "friend recommend" list.
//  Objective-C++ (.mm) because it drives the C++ "ne" engine singletons via neEngineBridge (scene
//  manager, root view controller, system SEs) and the C++ MusicSelTask re-sort routine.
//

#import "RecommendViewController.h"

#import "DownloadMain.h"
#import "RecommendListCell.h"
#import "StoreViewController.h"
#import "MainTask.h"          // MusicSelTask == MainTask: the real rebuildList() re-sort method
#import "neEngineBridge.h"

// The app's root navigation host (bridged UIViewController on the C++ scene manager).
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

// @ 0xbc2cc — the recommend list's sort comparator (binary symbol "compareByLocalizedName", used
// via -sortedArrayUsingFunction:context:). It boxes/reads both RecommendData records and orders by
// the record's date string (offset +0xc) with -localizedCaseInsensitiveCompare:, receiver = the
// second element, so the list ends up newest-first. Best-effort.
static NSInteger RecommendCompareByDate(id obj1, id obj2, void *context) {
    RecommendData a;
    RecommendData b;
    [(NSValue *)obj1 getValue:&a];
    [(NSValue *)obj2 getValue:&b];
    return [b.updateDate localizedCaseInsensitiveCompare:a.updateDate];
}

// ---------------------------------------------------------------------------
// settingNav* — block invoke functions emitted by the compiler immediately
// after startOpenAnimation (0xbc5e0) and startCloseAnimation (0xbcaa8).
// Each captures self (block-struct +0x14); settingNavSetFrameFromView also
// captures a reference UIViewController (+0x18) whose view height it reads.
// Placement: file-static (single owner — RecommendViewController).
// ---------------------------------------------------------------------------

// Ghidra: settingNavSetFrameA @ 0xbc888
// Slides the navigation controller view to y = 420.0.
// Animations block for the first phase of startOpenAnimation (iPad path).
static void settingNavSetFrameA(RecommendViewController *self) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    f.origin.y = 420.0f;
    self.navigationController.view.frame = f;
}

// Ghidra: settingNavSetFrameB @ 0xbc9c0
// Settles the navigation controller view to y = 470.0.
// Animations block inside settingNavAnimateShow (settle phase).
static void settingNavSetFrameB(RecommendViewController *self) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    f.origin.y = 470.0f;
    self.navigationController.view.frame = f;
}

// Ghidra: settingNavAnimateShow @ 0xbc920
// Completion block of the first open-animation step.  Runs a 0.25 s settle
// animation (UIViewAnimationOptionAllowUserInteraction = 2) that slides the
// nav view from y = 420 down to y = 470, then calls -endOpenAnimation.
// The two inner block invokes are settingNavSetFrameB (animations, @ 0xbc9c0)
// and an unnamed completion that calls [self endOpenAnimation] (@ ~0xbca58).
static void settingNavAnimateShow(RecommendViewController *self) {
    [UIView animateWithDuration:0.25
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         settingNavSetFrameB(self);   // Ghidra: settingNavSetFrameB @ 0xbc9c0
                     }
                     completion:^(BOOL finished) {
                         [self endOpenAnimation];      // completion block @ ~0xbca58
                     }];
}

// Ghidra: settingNavSetFrameC @ 0xbccb8
// Slides the navigation controller view back to y = 420.0.
// Animations block for the first phase of startCloseAnimation (iPad path).
static void settingNavSetFrameC(RecommendViewController *self) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    f.origin.y = 420.0f;
    self.navigationController.view.frame = f;
}

// Ghidra: settingNavSetFrameFromView @ 0xbcdf8
// Parks the navigation controller view off-screen below the root view.
// Animations block for the second phase of startCloseAnimation.  Captures
// self and a reference controller; sets nav-view origin.y to refController's
// view height (moves the panel just out of sight below the root scene).
static void settingNavSetFrameFromView(RecommendViewController *self,
                                       UIViewController *refController) {
    UIView *navView = self.navigationController.view;
    CGRect f = navView ? navView.frame : CGRectZero;
    UIView *ref = refController.view;
    f.origin.y = ref ? ref.frame.size.height : 0.0f;
    self.navigationController.view.frame = f;
}

@interface RecommendViewController ()
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)touchedBackButton:(id)sender;
@end

@implementation RecommendViewController {
    UIViewController *_dummyView;         // dimmed spinner overlay (shown during a store re-sort)
    StoreViewController *_storeView;      // the store opened on a tapped recommendation
    NSArray *_recommendDataArray;         // boxed RecommendData rows (date-sorted)
    BOOL _isAnimationing;                 // an open/close animation is in flight
    BOOL _isBack;                         // the back transition has begun (latches taps out)
}

@synthesize musicSelTask = _pMusicSelTask;
@synthesize animationing = _isAnimationing;

// @ 0xbbd68 — build the transparent, separator-less table (a clear 20-pt spacer header, the
// "friman" backdrop on phone / clear on iPad, and a hidden dimmed loading overlay with a large
// spinner) and load + date-sort the recommend list.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if (!(self = [super initWithStyle:style])) {
        return nil;
    }
    CGRect viewFrame = self.view.frame;
    self.tableView.rowHeight = 59.0f;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];

    _recommendDataArray =
        [[[DownloadMain getInstance] recommendDataArray] sortedArrayUsingFunction:RecommendCompareByDate
                                                                          context:NULL];

    // Clear 20-pt spacer header.
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, viewFrame.size.width, 20.0f)];
    header.backgroundColor = [UIColor clearColor];
    self.tableView.tableHeaderView = header;

    // iPad: pull the list up under the nav bar (-20 pre-iOS7, -10 on iOS7+).
    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        float osVersion = UIDevice.currentDevice.systemVersion.floatValue;
        self.tableView.contentInset = UIEdgeInsetsMake(osVersion < 7.0f ? -20.0f : -10.0f, 0.0f, 0.0f, 0.0f);
    }

    // Backdrop: "friman_bg" image (phone) / clear (iPad).
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        UIImage *frimanImg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *frimanView = [[UIImageView alloc] initWithImage:frimanImg];
        frimanView.frame = CGRectMake(0.0f, 0.0f, frimanImg.size.width, frimanImg.size.height);
        self.tableView.backgroundView = frimanView;
    } else {
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
    }

    // Dimmed "loading" overlay (transparent white) + large spinner, hidden until a store re-sort.
    _dummyView = [[UIViewController alloc] init];
    _dummyView.view.frame = self.view.frame;
    _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0.0f];
    _dummyView.view.hidden = YES;
    [self.tableView addSubview:_dummyView.view];

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    CGRect frame = self.view.frame;
    spinner.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f - 10.0f);
    spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    [spinner startAnimating];
    [_dummyView.view addSubview:spinner];
    return self;
}

// @ 0xbc30c — keep the C++ task pointer, (re)build the table via initWithStyle:, wrap self in a
// UINavigationController (with a back button on phone) and return that nav controller.
- (UINavigationController *)initAtNavigationController:(MusicSelTask *)musicSelTask {
    _pMusicSelTask = musicSelTask;
    UINavigationController *navigationController =
        [[UINavigationController alloc] initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(touchedBackButton:) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    }
    return navigationController;
}

// dealloc @ 0xbc4c0 — object-only (releases _dummyView / _storeView, then super); omitted under ARC.

// @ 0xbc524 — reveal the (transparent) overlay after load.
- (void)viewDidLoad {
    [super viewDidLoad];
    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        [self setContentSizeForViewInPopover:CGSizeMake(320.0f, 524.0f)];
    }
    _dummyView.view.hidden = NO;
}

// didReceiveMemoryWarning @ 0xbc5b4 — super-only override, omitted.

#pragma mark - Open / close animation (shared modal-VC lifecycle)

// @ 0xbc5e0 — fade the view + nav view in (phone) or slide the nav view up into place (iPad).
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        self.view.alpha = 0.0f;
        self.navigationController.view.alpha = 0.0f;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
        self.view.alpha = 1.0f;
        self.navigationController.view.alpha = 1.0f;
    } else {
        // iPad: park the nav view just below the root scene, then two-phase slide it into place.
        // Phase 1 (~1/6 s): slide up to y = 420 (settingNavSetFrameA @ 0xbc888).
        // Phase 2 (0.25 s, UIViewAnimationOptionAllowUserInteraction): settle to y = 470
        //   (settingNavAnimateShow @ 0xbc920 → settingNavSetFrameB @ 0xbc9c0), then
        //   call -endOpenAnimation (completion block @ ~0xbca58).
        UIViewController *root = RootVC();
        CGRect f = self.navigationController.view.frame;
        f.origin.y = root.view.frame.size.height;   // park below screen
        self.navigationController.view.frame = f;
        [UIView animateWithDuration:(1.0 / 6.0)
                              delay:0.0
                            options:UIViewAnimationOptionLayoutSubviews
                         animations:^{
                             settingNavSetFrameA(self);    // Ghidra: settingNavSetFrameA @ 0xbc888
                         }
                         completion:^(BOOL finished) {
                             settingNavAnimateShow(self);  // Ghidra: settingNavAnimateShow @ 0xbc920
                         }];
    }
    [UIView commitAnimations];
}

// @ 0xbca94
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xbcaa8 — if a store was opened on a tapped recommendation, re-sort the task's list (and hide
// the overlay), then fade (phone) / slide (iPad) the panel out.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    if (_storeView != nil) {
        _pMusicSelTask->rebuildList();
        _dummyView.view.hidden = YES;
    }
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0.0f;
        self.navigationController.view.alpha = 0.0f;
    } else {
        // iPad: two-phase slide out.
        // Phase 1 (~1/6 s): slide from y = 470 back to y = 420 (settingNavSetFrameC @ 0xbccb8).
        // Phase 2 (~1/6 s): park below the root view (settingNavSetFrameFromView @ 0xbcdf8),
        //   then call -endCloseAnimation.
        UIViewController *root = RootVC();
        [UIView animateWithDuration:(1.0 / 6.0)
                              delay:0.0
                            options:UIViewAnimationOptionLayoutSubviews
                         animations:^{
                             settingNavSetFrameC(self);   // Ghidra: settingNavSetFrameC @ 0xbccb8
                         }
                         completion:^(BOOL finished) {
                             [UIView animateWithDuration:(1.0 / 6.0)
                                                   delay:0.0
                                                 options:UIViewAnimationOptionLayoutSubviews
                                              animations:^{
                                                  // Ghidra: settingNavSetFrameFromView @ 0xbcdf8
                                                  settingNavSetFrameFromView(self, root);
                                              }
                                              completion:^(BOOL finished2) {
                                                  [self endCloseAnimation];
                                              }];
                         }];
    }
    [UIView commitAnimations];
}

// @ 0xbcf54 — remove the nav view and notify the root host that the recommend screen closed.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(RecommendEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

// @ 0xbcfc0
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xbcfc4 — one row per recommended pack.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (_recommendDataArray != nil) ? (NSInteger)_recommendDataArray.count : 0;
}

// @ 0xbcfec — one RecommendListCell per pack (reused by "Cell%ld_%ld"), bound to its boxed record.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld_%ld",
                            (long)indexPath.section, (long)indexPath.row];
    RecommendListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[RecommendListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    [cell setRecommendData:[_recommendDataArray objectAtIndex:indexPath.row]];
    return cell;
}

// @ 0xbd0f8 — no section headers.
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xbd0fc — a recommendation was tapped: open the in-app store on that pack (unless the back
// transition has begun, or that store is already presented). Releases any previous store, builds
// StoreViewController for the pack id, adds it over the nav view (phone) / root view (iPad) and
// runs its show animation.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_isBack) {
        return;
    }
    if (_storeView != nil &&
        [self.navigationController.view.subviews containsObject:_storeView.view]) {
        return;
    }
    if (indexPath.section != 0) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(1);

    RecommendData data;
    [(NSValue *)[_recommendDataArray objectAtIndex:indexPath.row] getValue:&data];

    _storeView = [[StoreViewController alloc] initWithRecommendPackId:data.packId];

    UIView *host = nil;
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        host = self.navigationController.view;
    } else {
        neSceneManager::shared();
        host = RootVC().view;
    }
    [host addSubview:_storeView.view];
    [_storeView showAnimation];
}

#pragma mark - Actions

// @ 0xbd2c4 — the back button: unless already backing out or the store is presented, latch the
// back state, play the cancel SE, reveal the overlay and (after 0.1 s) fade the panel closed.
- (void)touchedBackButton:(id)sender {
    if (_isBack) {
        return;
    }
    if (_storeView != nil &&
        [self.navigationController.view.subviews containsObject:_storeView.view]) {
        return;
    }
    _isBack = YES;
    neSceneManager::shared();
    neEngine::playSystemSe(2);
    _dummyView.view.hidden = NO;
    [self performSelector:@selector(startCloseAnimation) withObject:nil afterDelay:0.1];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
