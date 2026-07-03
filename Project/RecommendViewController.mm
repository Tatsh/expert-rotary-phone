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
#import "neEngineBridge.h"

// The app's root navigation host (bridged UIViewController on the C++ scene manager).
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

// TODO(dep): the C++ music-select re-sort routine (Ghidra musicSelUpdate FUN_0003835c) lives in
// the not-yet-reconstructed MusicSelTask unit. Declared extern "C" (the symbol is unmangled in the
// binary), mirroring SortSelectViewController.mm / MainTask.mm's musicSel* engine-hook declarations.
extern "C" void musicSelUpdate(MusicSelTask *task);

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
    spinner.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f - 50.0f);
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
        // iPad: pre-position the nav view below the root scene, then slide it up. The completion
        // runs a folded shared settle animation (settingNavAnimateShow) whose exact frame math is
        // not recovered; modelled here as the lifecycle end (endOpenAnimation). Best-effort.
        UIViewController *root = RootVC();
        CGRect navFrame = self.navigationController.view.frame;
        CGRect rootFrame = root.view.frame;
        self.navigationController.view.frame =
            CGRectMake(navFrame.origin.x, rootFrame.size.height, navFrame.size.width, navFrame.size.height);
        [UIView animateWithDuration:(1.0 / 6.0)
                              delay:0.0
                            options:UIViewAnimationOptionLayoutSubviews
                         animations:^{
                             CGRect f = self.navigationController.view.frame;
                             self.navigationController.view.frame =
                                 CGRectMake(f.origin.x, 420.0f, f.size.width, f.size.height);
                         }
                         completion:^(BOOL finished) {
                             [self endOpenAnimation];
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
        musicSelUpdate(_pMusicSelTask);
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
        // iPad: slide out; the folded completion is modelled as endCloseAnimation. Best-effort.
        UIViewController *root = RootVC();
        (void)root;
        [UIView animateWithDuration:(1.0 / 6.0)
                              delay:0.0
                            options:UIViewAnimationOptionLayoutSubviews
                         animations:^{
                             CGRect f = self.navigationController.view.frame;
                             self.navigationController.view.frame =
                                 CGRectMake(f.origin.x, 420.0f, f.size.width, f.size.height);
                         }
                         completion:^(BOOL finished) {
                             [self endCloseAnimation];
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
