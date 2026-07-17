//
//  SubMapSelectViewController.mm
//  pop'n rhythmin
//
//  See SubMapSelectViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin:
//    initWithTreasureData:mapHeadArray:mainMapId: @ 0xc1ea0
//    dealloc                                      @ 0xc2910
//    viewDidLoad                                  @ 0xc2aa0
//    handleGesture:                               @ 0xc2b80
//    didReceiveMemoryWarning                      @ 0xc2bec
//    numberOfSectionsInTableView:                 @ 0xc2c18
//    tableView:numberOfRowsInSection:             @ 0xc2c1c
//    tableView:cellForRowAtIndexPath:             @ 0xc2c44
//    tableView:titleForHeaderInSection:           @ 0xc2d50
//    tableView:didSelectRowAtIndexPath:           @ 0xc2d54
//    startCloseAnimation                          @ 0xc3088
//    endCloseAnimation                            @ 0xc31a8
//    downloadMainFinished:                        @ 0xc3204
//    backButtonFunc                               @ 0xc3280
//    delegate / setDelegate:                      @ 0xc3334 / 0xc3344
//  Objective-C++ for the C++ neSceneManager singleton and the C++ Random
//  generator. ARC.
//
//  Honesty notes:
//   - The row list is built by cross-referencing mapHeadArray (NSValue-wrapped
//   map-head
//     records) against treasureData (TreasureData save records): for every
//     map-head whose mapId/10 == mainMapId that also has a matching
//     TreasureData (mainMapId == mapId/10 && subMapId == mapId%10), one
//     NSValue-wrapped SubMapData ("{SubMapData=ss@@}") is emitted. The area
//     *name* is a Shift-JIS string carried in the map-head record; the binary
//     decodes it twice into two identical NSStrings (SubMapListCell reads the
//     second). The exact byte offset of the name inside the map-head payload is
//     obscured by the decompiler's inlined buffer copy, so it is read here as
//     the record's trailing NUL-terminated Shift-JIS string.
//   - Under ARC the two SubMapData NSString fields are __unsafe_unretained
//   (mirroring
//     FriendListData in DownloadMain.h); the original manually retained them
//     and released them in -dealloc, which is ARC-omitted here.
//   - -dealloc is kept because it detaches this controller from DownloadMain's
//   visitor delegate.
//   - Selecting an area snapshots a pending TreasureTmpData (subMapId := mapId,
//   a random
//     +0x48 field via the xorshift Random seeded with time()), zeroes the
//     consumed-treasure point, then asks DownloadMain for the area's visiting
//     friend (type 0).
//   - The dim spinner overlay (_dummyView) is created hidden, revealed in
//   -viewDidLoad and on
//     selection, and hidden again when the visitor request finishes — matching
//     the binary's setHidden: polarity exactly (init YES, viewDidLoad NO,
//     didSelect NO, finished YES).
//

#import "SubMapSelectViewController.h"

#import "AppDelegate.h"        // +appDelegate.displayType
#import "DownloadMain.h"       // visitor request + DownloadMainDelegate
#import "MainViewController.h" // MapSelectEndCallBack on the root VC
#import "Random.h"             // xorshift128 (Ghidra rngStateInit/rngSeed/GetRandRangeInt)
#import "SubMapListCell.h"     // one row per area
#import "TreasureData.h"       // sugoroku save records
#import "TreasureTmpData.h"    // pending-treasure struct
#import "UserSettingData.h"    // treasure snapshot
#import "neEngineBridge.h" // neSceneManager::isPadDisplay / rootViewController, neEngine::playSystemSe

#import <objc/message.h>
#import <string.h>
#import <time.h>

// NSValue payload for one visible area row. Obj-C type-encoding
// "{SubMapData=ss@@}".
typedef struct SubMapData {
    short mainMapId;
    short subMapId;
    NSString *__unsafe_unretained name;  // area name (Shift-JIS decoded)
    NSString *__unsafe_unretained name2; // identical copy the binary also allocates
} SubMapData;

@interface SubMapSelectViewController () <DownloadMainDelegate>
- (void)handleGesture:(UIPanGestureRecognizer *)recognizer;
- (void)startCloseAnimation;
- (void)backButtonFunc;
@end

@implementation SubMapSelectViewController {
    UIViewController *_dummyView;     // dim spinner overlay (visitor request in flight)
    NSArray *_subMapArray;            // NSValue-wrapped SubMapData rows
    BOOL _isDecide;                   // an area was chosen (guards re-entry)
    id __unsafe_unretained _delegate; // optional overlay owner (pad); assign/non-retaining (binary)
}

@synthesize delegate = _delegate;

// @ 0xc1ea0 — build the area list for `mainMapId`.
// @complete
- (instancetype)initWithTreasureData:(NSArray *)treasureData
                        mapHeadArray:(NSArray *)mapHeadArray
                           mainMapId:(short)mainMapId {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        CGRect viewFrame = self.view ? self.view.frame : CGRectZero;

        _delegate = self;

        BOOL isPad = neSceneManager::isPadDisplay();
        self.tableView.rowHeight = isPad ? 112.0f : 104.0f; // DAT 0xc.../grouped
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.separatorColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
        self.tableView.backgroundColor = [UIColor clearColor];
        if (isPad) {
            self.tableView.scrollEnabled = NO;
        }

        // Cross-reference map heads with the treasure save table.
        NSMutableArray *rows = [NSMutableArray array];
        for (NSValue *headValue in mapHeadArray) {
            short head[40];
            [headValue getValue:head];
            short mapId = head[0];
            if (mapId / 10 != mainMapId) {
                continue;
            }
            for (TreasureData *td in treasureData) {
                if ([[td mainMapId] shortValue] != mapId / 10) {
                    continue;
                }
                if ([[td subMapId] shortValue] != mapId % 10) {
                    continue;
                }
                // Area name: trailing Shift-JIS bytes of the map-head record (see
                // honesty note).
                const char *sjis = (const char *)(head + 1);
                NSData *nameData = [NSData dataWithBytes:sjis length:strlen(sjis)];
                NSString *name = [[NSString alloc] initWithData:nameData
                                                       encoding:NSShiftJISStringEncoding];
                NSString *name2 = [[NSString alloc] initWithData:nameData
                                                        encoding:NSShiftJISStringEncoding];
                SubMapData d;
                d.mainMapId = mapId / 10;
                d.subMapId = mapId % 10;
                d.name = name;
                d.name2 = name2;
                [rows addObject:[NSValue value:&d withObjCType:@encode(SubMapData)]];
                break;
            }
        }
        _subMapArray = [[NSArray alloc] initWithArray:rows];

        // Clear table header (taller on iOS 7+).
        CGFloat headerH = (UIDevice.currentDevice.systemVersion.floatValue >= 7.0f) ? 20.0f : 10.0f;
        UIView *headerView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewFrame.size.width, headerH)];
        headerView.backgroundColor = [UIColor clearColor];
        self.tableView.tableHeaderView = headerView;

        // Phone: a scaled map backdrop behind the table.
        if (!isPad) {
            NSString *bgName = ([[AppDelegate appDelegate] displayType] == 2) ? @"map_select_bg" :
                                                                                @"map_select_bg960";
            UIImage *bgImg = [UIImage imageNamed:bgName];
            UIImageView *bgView = [[UIImageView alloc] initWithImage:bgImg];
            bgView.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
            self.tableView.backgroundView = bgView;
            self.tableView.backgroundColor = [UIColor clearColor];
        }

        // Dim spinner overlay (hidden until viewDidLoad / a selection).
        _dummyView = [[UIViewController alloc] init];
        _dummyView.view.frame = viewFrame;
        _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
        _dummyView.view.hidden = YES;
        [self.view addSubview:_dummyView.view];

        UIActivityIndicatorView *spinner =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        if (!isPad) {
            spinner.center =
                CGPointMake(viewFrame.size.width * 0.5f, (int)(viewFrame.size.height * 0.5f) - 10);
        } else {
            spinner.center = CGPointMake(214.0f, (int)(viewFrame.size.height * 0.5f) - 10);
        }
        spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
        [spinner startAnimating];
        [_dummyView.view addSubview:spinner];

        // Phone: custom back button in the nav item.
        if (!neSceneManager::isPadDisplay()) {
            UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
            UIButton *backBtn = [[UIButton alloc]
                initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
            [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
            [backBtn addTarget:self
                          action:@selector(backButtonFunc)
                forControlEvents:UIControlEventTouchUpInside];
            self.navigationItem.leftBarButtonItem =
                [[UIBarButtonItem alloc] initWithCustomView:backBtn];
        }
    }
    return self;
}

// @ 0xc2aa0 — add the left-swipe recogniser (phone) and reveal the overlay
// host.
// @complete
- (void)viewDidLoad {
    [super viewDidLoad];
    if (!neSceneManager::isPadDisplay()) {
        UIPanGestureRecognizer *pan =
            [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
        [self.view addGestureRecognizer:pan];
    }
    _dummyView.view.hidden = NO;
}

// @ 0xc2b80 — a rightward pan (translation.x > 80) pops the screen.
// @complete
- (void)handleGesture:(UIPanGestureRecognizer *)recognizer {
    if (recognizer != nil && [recognizer translationInView:self.view].x > 80.0f) { // DAT_000c2be8
        [self backButtonFunc];
    }
}

// didReceiveMemoryWarning @ 0xc2bec — super-only override, ARC/omit. @complete

#pragma mark - Table

// @ 0xc2c18
// @complete
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xc2c1c
// @complete
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _subMapArray ? [_subMapArray count] : 0;
}

// @ 0xc2c44
// @complete
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    SubMapListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[SubMapListCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:identifier];
    }
    [cell setMapData:[_subMapArray objectAtIndex:indexPath.row]];
    return cell;
}

// @ 0xc2d50
// @complete
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xc2d54 — choose an area: snapshot the pending treasure, then request its
// visitor. (mapId = mainMapId*10 + subMapId; rng.setSeed(time(NULL));
// bonusRoll = getRandRangeInt(100); coalesced 5-byte clear at tmp+0x4c — verified.)
// @complete
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0 || _isDecide) {
        return;
    }

    // On pad, swallow the tap while the overlay owner is animating.
    if (neSceneManager::isPadDisplay() && _delegate != nil && _delegate != self) {
        BOOL (*sendIsAnimationing)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
        if (sendIsAnimationing(_delegate, @selector(isAnimationing))) {
            return;
        }
    }

    neEngine::playSystemSe(1); // decide SE
    _dummyView.view.hidden = NO;
    _isDecide = YES;

    SubMapData selected;
    [[_subMapArray objectAtIndex:indexPath.row] getValue:&selected];
    short mapId = selected.mainMapId * 10 + selected.subMapId;

    Random rng;
    rng.setSeed((uint32_t)time(NULL));

    TreasureTmpData tmp = [UserSettingData treasureTmp];
    tmp.subMapId = mapId; // combined map id (main*10 + sub)
    tmp.field06 = -1;
    tmp.goalCharaId = 0;
    tmp.musicPiece = 0;
    tmp.wallPaperPiece = 0;
    memset(tmp.friendPlayerId, 0, sizeof(tmp.friendPlayerId));
    memset(tmp.goalName, 0, sizeof(tmp.goalName));
    tmp.bonusRoll = (uint8_t)rng.getRandRangeInt(100);
    // Clear the fast-record score and the friend-meet flag (+0x4c..+0x50; the
    // binary does this as one coalesced 5-byte zero store).
    tmp.fastRecord = 0;
    tmp.friendMeetFlag = 0;
    [UserSettingData saveTreasureTmp:tmp];
    [UserSettingData saveConsumedTreasurePoint:0];

    DownloadMain *dm = [DownloadMain getInstance];
    [dm setDelegateGetVisitor:self];
    [dm startGetVisitorHttp:(short)tmp.subMapId type:0];
}

#pragma mark - Close animation

// @ 0xc3088 — animate the nav host out (unless a pad overlay owner will handle
// it). (The binary's pad+delegate branch falls through to a bare commitAnimations
// no-op, equivalent to skipping the block as reconstructed.)
// @complete
- (void)startCloseAnimation {
    if (!neSceneManager::isPadDisplay() || _delegate == nil) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3]; // DAT_000c31a0
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0;
        self.navigationController.view.alpha = 0;
        [UIView commitAnimations];
    }
}

// @ 0xc31a8 — remove the nav host and notify the root map controller.
// @complete
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [(MainViewController *)neSceneManager::rootViewController() MapSelectEndCallBack];
}

#pragma mark - DownloadMain delegate

// @ 0xc3204 — visitor request finished: hide the spinner, detach, and close.
// @complete
- (void)downloadMainFinished:(NSNumber *)success {
    _dummyView.view.hidden = YES;
    [[DownloadMain getInstance] setDelegateGetVisitor:nil];
    [self startCloseAnimation];
}

#pragma mark - Navigation

// @ 0xc3280 — back button / swipe: restore the map-select nav bar art and pop.
// @complete
- (void)backButtonFunc {
    if (_isDecide) {
        return;
    }
    _isDecide = YES;
    neEngine::playSystemSe(2); // cancel SE
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"map_select_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0xc2910 — detach from DownloadMain's visitor delegate before teardown. Kept
// under ARC because it clears a DownloadMain delegate; the _subMapArray string
// releases and the _dummyView release are ARC-managed (the SubMapData strings
// are __unsafe_unretained — see honesty note; the binary manually releases them
// at 0xc29fe/0xc2a0a, deliberately ARC-omitted here).
// @complete
- (void)dealloc {
    DownloadMain *dm = [DownloadMain getInstance];
    if ([dm delegateGetVisitor] == self) {
        [dm setDelegateGetVisitor:nil];
    }
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
