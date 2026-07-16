//
//  SortSelectViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The
//  music-list sort-select screen. Objective-C++ (.mm) because it drives the C++
//  "ne" engine singletons via neEngineBridge (scene manager, root view
//  controller, system SEs) and the C++ MainTask re-sort routine.
//

#import "SortSelectViewController.h"

#import "MainTask.h"
#import "SortCell.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"

// The app's root navigation host (bridged UIViewController on the C++ scene
// manager).
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

namespace {
// The NSValue payload each SortCell reads: sort index + checked flag. Encodes
// as the binary's "{SortData=sc}".
struct SortData {
    short sortType;
    char isChecked;
};
} // namespace

// Six SortData rows (0..5), the one matching `currentSort` checked.
static NSArray *BuildSortDataArray(short currentSort) {
    NSMutableArray *rows = [NSMutableArray array];
    for (short i = 0; i < 6; i++) {
        SortData sd;
        sd.sortType = i;
        sd.isChecked = (currentSort == i);
        [rows addObject:[NSValue value:&sd withObjCType:@encode(SortData)]];
    }
    return [NSArray arrayWithArray:rows];
}

@interface SortSelectViewController ()
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)backButtonFunc;
@end

// ─── File-static nav-frame helpers ───────────────────────────────────────────
// Forward-declare so startOpenAnimation / startCloseAnimation can call them;
// bodies are defined after @end. Single caller class → no shared header.
static void friendNavSetFrameA(SortSelectViewController *);
static void friendNavSetFrameB(SortSelectViewController *);
static void friendNavSetFrameC(SortSelectViewController *);
static void friendNavSetFrameFromView(SortSelectViewController *, UIViewController *);

@implementation SortSelectViewController {
    BOOL _isAnimationing;         // an open/close animation is in flight
    NSArray *_sortDataArray;      // the six boxed SortData rows
    UIViewController *_dummyView; // dimmed "loading" overlay shown during a re-sort
}

@synthesize musicSelTask = _pMusicSelTask;

// @ 0xc5988 — build the sort table: transparent + separator-less, a clear
// spacer header, the "friman" (phone) / clear (iPad) backdrop, and a hidden
// dimmed loading overlay with a large spinner. The rows are seeded with the
// current sort checked.
//
// @complete
// Verified: rowHeight 59.0 (0x426c0000); clear separator; 6 boxed SortData rows
// ({SortData=sc}); 20-pt clear header; iPad inset -20/-10; friman_bg backdrop
// on phone; dimmed overlay UIViewController with a WhiteLarge spinner centred at
// (w/2, h/2 - 50) scaled 2x.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if (!(self = [super initWithStyle:style])) {
        return nil;
    }
    CGRect viewFrame = self.view.frame;
    self.tableView.rowHeight = 59.0f;
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    _sortDataArray = BuildSortDataArray([UserSettingData musicSort]);

    // Clear 20-pt spacer header.
    UIView *header =
        [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, viewFrame.size.width, 20.0f)];
    header.backgroundColor = [UIColor clearColor];
    self.tableView.tableHeaderView = header;

    // iPad: pull the list up under the nav bar (-20 pre-iOS7, -10 on iOS7+).
    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        float osVersion = UIDevice.currentDevice.systemVersion.floatValue;
        self.tableView.contentInset =
            UIEdgeInsetsMake(osVersion < 7.0f ? -20.0f : -10.0f, 0.0f, 0.0f, 0.0f);
    }

    // Backdrop: "friman" image (phone) / clear (iPad).
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

    // Dimmed "loading" overlay (hidden until a re-sort is in flight) + large
    // spinner.
    _dummyView = [[UIViewController alloc] init];
    _dummyView.view.frame = self.view.frame;
    _dummyView.view.hidden = YES;
    _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0.0f];
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

// @ 0xc6018 — keep the C++ task pointer, (re)build the table via
// initWithStyle:, wrap self in a UINavigationController (with a back button on
// phone) and return that nav controller.
//
// @complete
- (UINavigationController *)initAtNavigationController:(MainTask *)musicSelTask
    __attribute__((objc_method_family(none))) {
    _pMusicSelTask = musicSelTask;
    UINavigationController *navigationController = [[UINavigationController alloc]
        initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self
                      action:@selector(backButtonFunc)
            forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    }
    return navigationController;
}

// dealloc @ 0xc61cc — object-only (releases _sortDataArray / _dummyView, then
// super); omitted under ARC. viewDidLoad @ 0xc6230 — super-only override,
// omitted. didReceiveMemoryWarning @ 0xc625c — super-only override, omitted.

#pragma mark - Open / close animation (shared modal-VC lifecycle)

// @ 0xc6288 — fade the view + nav view in (phone) or slide the nav view up into
// place (iPad).
//
// @complete (phone duration 0.3 verified @ 0xc6528; iPad slides 1/6 s each).
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
        // iPad: pre-position the nav view below the root scene (y =
        // rootVC.view.height), then slide it up to y = 420 (friendNavSetFrameA @
        // 0xc6530), then settle at y = 470 (friendNavSetFrameB @ 0xc6668).
        UIViewController *root = RootVC();
        CGRect navFrame = self.navigationController.view.frame;
        CGRect rootFrame = root.view.frame;
        self.navigationController.view.frame = CGRectMake(
            navFrame.origin.x, rootFrame.size.height, navFrame.size.width, navFrame.size.height);
        [UIView animateWithDuration:(1.0 / 6.0)
            delay:0.0
            options:UIViewAnimationOptionLayoutSubviews
            animations:^{
              friendNavSetFrameA(self);
            }
            completion:^(BOOL f1) {
              [UIView animateWithDuration:(1.0 / 6.0)
                  delay:0.0
                  options:UIViewAnimationOptionLayoutSubviews
                  animations:^{
                    friendNavSetFrameB(self);
                  }
                  completion:^(BOOL f2) {
                    [self endOpenAnimation];
                  }];
            }];
    }
    [UIView commitAnimations];
}

// @ 0xc673c
//
// @complete
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xc6750 — if the saved sort differs from the one the task last applied,
// re-sort the task's list (and hide the loading overlay), then fade (phone) /
// slide (iPad) the panel out.
//
// @complete
// Verified: the re-sort test compares musicSort against MainTask+0x8fc
// (appliedSort()); on a change it calls rebuildList() (FUN_0003835c) and hides
// the overlay; phone fade uses duration 0.0; iPad slides 1/6 s each.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    if ((unsigned)[UserSettingData musicSort] != (unsigned)_pMusicSelTask->appliedSort()) {
        _pMusicSelTask->rebuildList();
        _dummyView.view.hidden = YES;
    }
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.0]; // recovered as 0.0 (the loading overlay
                                           // covers the swap)
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0.0f;
        self.navigationController.view.alpha = 0.0f;
    } else {
        // iPad: pull back to y = 420 (friendNavSetFrameC @ 0xc6970), then exit to
        // y = rootVC.view.height (friendNavSetFrameFromView @ 0xc6ab0 — two
        // captures: self at +0x14, rootVC at +0x18 in the binary block struct).
        UIViewController *root = RootVC();
        [UIView animateWithDuration:(1.0 / 6.0)
            delay:0.0
            options:UIViewAnimationOptionLayoutSubviews
            animations:^{
              friendNavSetFrameC(self);
            }
            completion:^(BOOL f1) {
              [UIView animateWithDuration:(1.0 / 6.0)
                  delay:0.0
                  options:UIViewAnimationOptionLayoutSubviews
                  animations:^{
                    friendNavSetFrameFromView(self, root);
                  }
                  completion:^(BOOL f2) {
                    [self endCloseAnimation];
                  }];
            }];
    }
    [UIView commitAnimations];
}

// @ 0xc6c0c — remove the nav view and notify the root host that the sort screen
// closed.
//
// @complete
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(SortSelectEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

// @ 0xc6c78
//
// @complete
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xc6c7c — one row per sort option.
//
// @complete
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (_sortDataArray != nil) ? (NSInteger)_sortDataArray.count : 0;
}

// @ 0xc6ca4 — one SortCell per option (reused by "Cell%ld-%ld"), bound to its
// boxed SortData.
//
// @complete
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // The reuse identifier uses a hyphen separator (CFString @ 0x134e38 ->
    // "Cell%ld-%ld"), not an underscore.
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    SortCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[SortCell alloc] initWithStyle:UITableViewCellStyleDefault
                               reuseIdentifier:identifier];
    }
    [cell setSortData:[_sortDataArray objectAtIndex:indexPath.row]];
    return cell;
}

// @ 0xc6db0 — no section headers.
//
// @complete
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xc6db4 — a sort was picked: play the decide SE and save it. If it actually
// changes the task's applied sort, refresh the checked rows, show the loading
// overlay and (after 0.1 s) fade the panel closed. Re-picking the active sort
// does nothing.
//
// @complete (saveMusicSort takes the signed-short sortType; afterDelay 0.1).
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(1);
    SortData selected;
    [(NSValue *)[_sortDataArray objectAtIndex:indexPath.row] getValue:&selected];
    [UserSettingData saveMusicSort:selected.sortType];
    if ((unsigned)[UserSettingData musicSort] != (unsigned)_pMusicSelTask->appliedSort()) {
        _sortDataArray = BuildSortDataArray(selected.sortType);
        [self.tableView reloadData];
        _dummyView.view.hidden = NO;
        [self performSelector:@selector(startCloseAnimation) withObject:nil afterDelay:0.1];
    }
}

#pragma mark - Actions

// @ 0xc6fe4 — the back button: play the cancel SE and fade the panel closed
// (unless already animating).
//
// @complete
- (void)backButtonFunc {
    if (_isAnimationing) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

@end

// ─── File-static nav-frame helpers ───────────────────────────────────────────
// In the binary these are the block-invoke functions emitted by the compiler
// for the ObjC block literals in startOpenAnimation (iPad) and
// startCloseAnimation (iPad). All four are called only from this class →
// file-static, no shared header.
//
// Open animation sequence (iPad):
//   pre-position: nav.view.origin.y = rootVC.view.frame.size.height (off-screen
//   below) → friendNavSetFrameA  (y = 420, fast slide-in) → friendNavSetFrameB
//   (y = 470, settle)
//
// Close animation sequence (iPad):
//   → friendNavSetFrameC  (y = 420, pull up from resting 470)
//   → friendNavSetFrameFromView  (y = rootVC.view.frame.size.height, exit
//   off-screen)

// Ghidra: friendNavSetFrameA @ 0xc6530
// Animations-block invoke of the first open-animation step. Reads the current
// nav view frame, overrides origin.y = 420.0f, sets it back.
//
// @complete (self at +0x14; origin.y = 0x43d20000 = 420.0).
static void friendNavSetFrameA(SortSelectViewController *self) {
    UIView *v = self.navigationController.view;
    CGRect f = (v != nil) ? v.frame : CGRectZero;
    f.origin.y = 420.0f;
    [self.navigationController.view setFrame:f];
}

// Ghidra: friendNavSetFrameB @ 0xc6668
// Animations-block invoke of the settle step (completion of A). Overrides
// origin.y = 470.0f — the final resting position of the panel on screen.
//
// @complete (self at +0x14; origin.y = 0x43eb0000 = 470.0).
static void friendNavSetFrameB(SortSelectViewController *self) {
    UIView *v = self.navigationController.view;
    CGRect f = (v != nil) ? v.frame : CGRectZero;
    f.origin.y = 470.0f;
    [self.navigationController.view setFrame:f];
}

// Ghidra: friendNavSetFrameC @ 0xc6970
// Animations-block invoke of the first close-animation step. Body is identical
// to friendNavSetFrameA (both encode 0x43d20000 = 420.0f); separate Thumb
// addresses because the compiler emits one block-invoke function per lambda
// site.
//
// @complete (self at +0x14; origin.y = 0x43d20000 = 420.0).
static void friendNavSetFrameC(SortSelectViewController *self) {
    UIView *v = self.navigationController.view;
    CGRect f = (v != nil) ? v.frame : CGRectZero;
    f.origin.y = 420.0f;
    [self.navigationController.view setFrame:f];
}

// Ghidra: friendNavSetFrameFromView @ 0xc6ab0
// Animations-block invoke of the exit step (completion of C). Two captures in
// the binary block struct: self at +0x14, rootVC at +0x18. Reads the nav view
// frame (or CGRectZero if nil), then replaces origin.y with rootVC.view's
// height to push the panel off-screen below.
//
// @complete (self at +0x14, rootVC at +0x18; origin.y = rootVC.view height).
static void friendNavSetFrameFromView(SortSelectViewController *self, UIViewController *rootVC) {
    UIView *navView = self.navigationController.view;
    CGRect f = (navView != nil) ? navView.frame : CGRectZero;
    f.origin.y = (rootVC.view != nil) ? rootVC.view.frame.size.height : 0.0f;
    [self.navigationController.view setFrame:f];
}

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
