//
//  SortSelectViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The music-list
//  sort-select screen. Objective-C++ (.mm) because it drives the C++ "ne" engine
//  singletons via neEngineBridge (scene manager, root view controller, system SEs) and the
//  C++ MusicSelTask re-sort routine.
//

#import "SortSelectViewController.h"

#import "SortCell.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"

// The app's root navigation host (bridged UIViewController on the C++ scene manager).
static UIViewController *RootVC() {
    return neSceneManager::rootViewController();
}

// TODO(dep): the C++ music-select re-sort routine (Ghidra musicSelUpdate FUN_0003835c) lives
// in the not-yet-reconstructed MusicSelTask unit. Declared extern "C" (the symbol is
// unmangled in the binary), mirroring MainTask.mm's musicSel* engine-hook declarations.
extern "C" void musicSelUpdate(MusicSelTask *task);

namespace {
// The NSValue payload each SortCell reads: sort index + checked flag. Encodes as the
// binary's "{SortData=sc}".
struct SortData {
    short sortType;
    char isChecked;
};

// The task caches the music sort it last applied at +0x8fc (musicSelUpdate writes it there).
// Read raw at its byte offset — MusicSelTask is an incomplete type on the ObjC side.
inline unsigned MusicSelAppliedSort(MusicSelTask *task) {
    return *reinterpret_cast<unsigned *>(reinterpret_cast<char *>(task) + 0x8fc);
}
}  // namespace

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

@implementation SortSelectViewController {
    BOOL _isAnimationing;            // an open/close animation is in flight
    NSArray *_sortDataArray;         // the six boxed SortData rows
    UIViewController *_dummyView;    // dimmed "loading" overlay shown during a re-sort
}

@synthesize musicSelTask = _pMusicSelTask;

// @ 0xc5988 — build the sort table: transparent + separator-less, a clear spacer header, the
// "friman" (phone) / clear (iPad) backdrop, and a hidden dimmed loading overlay with a large
// spinner. The rows are seeded with the current sort checked.
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
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, viewFrame.size.width, 20.0f)];
    header.backgroundColor = [UIColor clearColor];
    self.tableView.tableHeaderView = header;

    // iPad: pull the list up under the nav bar (-20 pre-iOS7, -10 on iOS7+).
    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        float osVersion = UIDevice.currentDevice.systemVersion.floatValue;
        self.tableView.contentInset = UIEdgeInsetsMake(osVersion < 7.0f ? -20.0f : -10.0f, 0.0f, 0.0f, 0.0f);
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

    // Dimmed "loading" overlay (hidden until a re-sort is in flight) + large spinner.
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

// @ 0xc6018 — keep the C++ task pointer, (re)build the table via initWithStyle:, wrap self in
// a UINavigationController (with a back button on phone) and return that nav controller.
- (UINavigationController *)initAtNavigationController:(MusicSelTask *)musicSelTask {
    _pMusicSelTask = musicSelTask;
    UINavigationController *navigationController =
        [[UINavigationController alloc] initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(backButtonFunc) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    }
    return navigationController;
}

// dealloc @ 0xc61cc — object-only (releases _sortDataArray / _dummyView, then super); omitted
// under ARC.
// viewDidLoad @ 0xc6230 — super-only override, omitted.
// didReceiveMemoryWarning @ 0xc625c — super-only override, omitted.

#pragma mark - Open / close animation (shared modal-VC lifecycle)

// @ 0xc6288 — fade the view + nav view in (phone) or slide the nav view up into place (iPad).
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
        // iPad: pre-position the nav view below the root scene, then slide it up to y = 420.
        // NB: the completion runs a folded shared settle animation whose exact frame math is
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

// @ 0xc673c
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xc6750 — if the saved sort differs from the one the task last applied, re-sort the
// task's list (and hide the loading overlay), then fade (phone) / slide (iPad) the panel out.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    if ((unsigned)[UserSettingData musicSort] != MusicSelAppliedSort(_pMusicSelTask)) {
        musicSelUpdate(_pMusicSelTask);
        _dummyView.view.hidden = YES;
    }
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.0];  // recovered as 0.0 (the loading overlay covers the swap)
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

// @ 0xc6c0c — remove the nav view and notify the root host that the sort screen closed.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [RootVC() performSelector:@selector(SortSelectEndCallBack)];
    _isAnimationing = NO;
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

// @ 0xc6c78
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xc6c7c — one row per sort option.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (_sortDataArray != nil) ? (NSInteger)_sortDataArray.count : 0;
}

// @ 0xc6ca4 — one SortCell per option (reused by "Cell%ld_%ld"), bound to its boxed SortData.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld_%ld",
                            (long)indexPath.section, (long)indexPath.row];
    SortCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[SortCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    [cell setSortData:[_sortDataArray objectAtIndex:indexPath.row]];
    return cell;
}

// @ 0xc6db0 — no section headers.
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xc6db4 — a sort was picked: play the decide SE and save it. If it actually changes the
// task's applied sort, refresh the checked rows, show the loading overlay and (after 0.1 s)
// fade the panel closed. Re-picking the active sort does nothing.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(1);
    SortData selected;
    [(NSValue *)[_sortDataArray objectAtIndex:indexPath.row] getValue:&selected];
    [UserSettingData saveMusicSort:selected.sortType];
    if ((unsigned)[UserSettingData musicSort] != MusicSelAppliedSort(_pMusicSelTask)) {
        _sortDataArray = BuildSortDataArray(selected.sortType);
        [self.tableView reloadData];
        _dummyView.view.hidden = NO;
        [self performSelector:@selector(startCloseAnimation) withObject:nil afterDelay:0.1];
    }
}

#pragma mark - Actions

// @ 0xc6fe4 — the back button: play the cancel SE and fade the panel closed (unless already
// animating).
- (void)backButtonFunc {
    if (_isAnimationing) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
