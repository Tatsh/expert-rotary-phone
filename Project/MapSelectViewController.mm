//
//  MapSelectViewController.mm
//  pop'n rhythmin
//
//  See MapSelectViewController.h. Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    initWithStyle:                       @ 0xbec60
//    initAtNavigationController           @ 0xbf498
//    dealloc                              @ 0xbf7a8
//    viewDidLoad                          @ 0xbf980
//    didReceiveMemoryWarning              @ 0xbf9e0
//    viewDidAppear:                       @ 0xbfa0c
//    startOpenAnimation                   @ 0xbfa38
//    endOpenAnimation                     @ 0xbfb70
//    startCloseAnimation                  @ 0xbfb88
//    endCloseAnimation                    @ 0xbfc90
//    numberOfSectionsInTableView:         @ 0xbfcec
//    tableView:numberOfRowsInSection:     @ 0xbfcf0
//    tableView:cellForRowAtIndexPath:     @ 0xbfd18
//    tableView:titleForHeaderInSection:   @ 0xbfe40
//    tableView:didSelectRowAtIndexPath:   @ 0xbfe44
//    scrollViewDidScroll:                 @ 0xc0098
//    downloadMainFinished:                @ 0xc00bc
//    backButtonFunc                       @ 0xc00fc
//    updateEventInfo                      @ 0xc0190
//    mapSelectDelegate / setMapSelectDelegate: @ 0xc0768 / 0xc0778
//    treasureDataArray / mapHeadArray / mapDataArray @ 0xc0788 / 0xc079c / 0xc07b0
//  Objective-C++ for the C++ neSceneManager singleton. ARC.
//
//  Honesty notes:
//   - The visible rows are built by cross-referencing every bundled map-head record (from the
//     free helper loadAllTreasureMapHeaders, Ghidra @ 0xcdee0) against the TreasureData save
//     table: each main-map head (mapId % 10 == 0) that has a matching TreasureData record emits
//     one NSValue-wrapped MainMapData ("{MainMapData=s@}") of { mainMapId, name }. The map name
//     is a Shift-JIS string embedded in the head record; the binary copies it out of an inlined
//     buffer whose exact field offset the decompiler obscured, so it is read here as the record's
//     NUL-terminated Shift-JIS string at the recovered offset (0x14), mirroring the SubMap screen.
//   - Under ARC the MainMapData NSString field is __unsafe_unretained (mirroring FriendListData in
//     DownloadMain.h); the original manually released each name (and the three arrays) in -dealloc,
//     which is ARC-omitted. -dealloc is kept because it detaches this controller from DownloadMain's
//     event-info delegate.
//   - TODO(dep): loadAllTreasureMapHeaders() (Ghidra @ 0xcdee0, the sugoroku map-header loader)
//     and isIndexInRange12() (Ghidra @ 0xe2c3c, an event-id 0..11 bounds check) are free helpers
//     whose owning module (the sugoroku map layer) is not yet reconstructed; they are forward-
//     declared below until it is recovered.
//   - The dim spinner overlay (_dummyView) is created hidden and revealed in -viewDidLoad, matching
//     the binary's setHidden: polarity.
//   - Faithful quirk: -startCloseAnimation's guard tests _isAnimationing == 0 and then re-stores 0
//     (never 1), so it does not actually latch — reproduced verbatim from Ghidra @ 0xbfb88.
//

#import "MapSelectViewController.h"

#import "MapListCell.h"                  // one row per main map
#import "DownloadMain.h"                 // event-info push + DownloadMainDelegate
#import "MainViewController.h"           // MapSelectEndCallBack on the root VC
#import "SubMapSelectViewController.h"   // pushed area list (phone)
#import "HowToViewCtrl.h"                // first-run how-to overlay
#import "AppDelegate.h"                  // +appDelegate.displayType / managedObjectContext
#import "TreasureData.h"                 // sugoroku save records
#import "TreasureTmpData.h"              // pending-treasure struct (cleared on back)
#import "UserSettingData.h"              // first-run flag + selected-map persistence
#import "neEngineBridge.h"               // neSceneManager::isPadDisplay / rootViewController, neEngine::playSystemSe

#import <string.h>

// TODO(dep): free helpers owned by the not-yet-reconstructed sugoroku map layer.
//   loadAllTreasureMapHeaders — Ghidra @ 0xcdee0: loads every bundled "map_%02d_%d.map" header
//     (0x50-byte MapFileHead) and returns an NSArray of NSValue-wrapped records.
//   isIndexInRange12 — Ghidra @ 0xe2c3c: returns (index < 12), used to drop out-of-range event ids.
NSArray *loadAllTreasureMapHeaders(void);
bool isIndexInRange12(unsigned int index);

// MainMapData (the NSValue payload of -mapDataArray) is declared in MapSelectViewController.h.

@interface MapSelectViewController () <DownloadMainDelegate>
- (void)backButtonFunc;
- (void)startCloseAnimation;
- (void)endCloseAnimation;
- (void)endOpenAnimation;
- (void)updateEventInfo;
@end

@implementation MapSelectViewController {
    UIView            *_dummyHeadView;   // clear table-header spacer (no active event)
    UIView            *_eventHeadView;   // event banner table-header (active event)
    UIViewController  *_dummyView;       // dim spinner overlay
    BOOL               _isAnimationing;
    NSMutableArray    *_eventIds;        // active treasure-event ids (NSNumber, 0..11)
    int                _selectedIndexRow; // pad: highlighted row
}

@synthesize mapSelectDelegate = _mapSelectDelegate;
@synthesize treasureDataArray = _treasureDataArray;
@synthesize mapHeadArray = _mapHeadArray;
@synthesize mapDataArray = _mapDataArray;

// @ 0xbec60 — build the main-map row list and the overlay spinner.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self == nil) {
        return nil;
    }
    CGRect viewFrame = self.view ? self.view.frame : CGRectZero;
    _mapSelectDelegate = nil;
    _selectedIndexRow = 0;

    BOOL isPad = neSceneManager::isPadDisplay();
    self.tableView.rowHeight = isPad ? 67.0f : 57.0f;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];

    // Snapshot the save table + every bundled map head.
    _treasureDataArray = [TreasureData getAllTreasureData:[[AppDelegate appDelegate] managedObjectContext]];
    _mapHeadArray = loadAllTreasureMapHeaders();

    // One row per main map (mapId % 10 == 0) that has a save record.
    NSMutableArray *rows = [NSMutableArray array];
    for (NSValue *headValue in _mapHeadArray) {
        int16_t head[40];
        [headValue getValue:head];
        short mapId = head[0];
        if (mapId % 10 != 0) {
            continue;
        }
        for (TreasureData *td in _treasureDataArray) {
            if ([[td mainMapId] shortValue] != mapId / 10) {
                continue;
            }
            // Map name: NUL-terminated Shift-JIS string embedded at record offset 0x14
            // (see honesty note).
            const char *sjis = (const char *)head + 0x14;
            NSData *nameData = [NSData dataWithBytes:sjis length:strlen(sjis)];
            NSString *name = [[NSString alloc] initWithData:nameData
                                                   encoding:NSShiftJISStringEncoding];
            MainMapData d;
            d.mainMapId = mapId / 10;
            d.name = name;
            [rows addObject:[NSValue value:&d withObjCType:@encode(MainMapData)]];
            break;
        }
    }
    _mapDataArray = [[NSArray alloc] initWithArray:rows];

    // Phone listens for the event-info push so the banner can refresh live.
    if (!neSceneManager::isPadDisplay()) {
        [[DownloadMain getInstance] setDelegateGetEventInfo:self];
    }
    [self updateEventInfo];

    // Backdrop: phone paints a full map image behind the table; pad stays clear.
    if (!neSceneManager::isPadDisplay()) {
        NSString *bgName = ([[AppDelegate appDelegate] displayType] == 2) ? @"map_select_bg"
                                                                          : @"map_select_bg960";
        UIImage *bgImg = [UIImage imageNamed:bgName];
        UIImageView *bgView = [[UIImageView alloc] initWithImage:bgImg];
        bgView.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
        self.tableView.backgroundView = bgView;
    } else {
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
    }

    // Dim spinner overlay (hidden until viewDidLoad).
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

    return self;
}

// @ 0xbf498 — wrap self in a nav controller; first run pushes a how-to overlay.
- (UINavigationController *)initAtNavigationController {
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:[self initWithStyle:UITableViewStyleGrouped]];

    if (neSceneManager::isPadDisplay()) {
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"map_select_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
    }

    // First-ever visit: show the two-page treasure how-to over the list.
    if (![UserSettingData isTreasureSelected]) {
        HowToViewCtrl *howto = [[HowToViewCtrl alloc]
            initWithFileNameArray:@[ @"firstplay_tre01", @"firstplay_tre02" ]];
        howto.isCloseButtonEnable = YES;
        howto.backGroundImage = [UIImage imageNamed:@"friman_bg"];
        [self.navigationController pushViewController:howto animated:NO];
        [UserSettingData saveIsTreasureSelected:YES];
    }

    // Custom back button.
    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(backButtonFunc)
      forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];

    return nav;
}

// @ 0xbf7a8 — detach from DownloadMain's event-info delegate before teardown. Kept under ARC
// for that side effect; the map-name string releases and the array/overlay releases are
// ARC-managed (the MainMapData strings are __unsafe_unretained — see honesty note).
- (void)dealloc {
    if (!neSceneManager::isPadDisplay()) {
        [[DownloadMain getInstance] setDelegateGetEventInfo:nil];
    }
}

// @ 0xbf980 — reveal the overlay host.
- (void)viewDidLoad {
    [super viewDidLoad];
    _dummyView.view.hidden = NO;
}

// didReceiveMemoryWarning @ 0xbf9e0 — super-only override, ARC/omit.
// viewDidAppear:          @ 0xbfa0c — super-only override, ARC/omit.

#pragma mark - Open / close animation

// @ 0xbfa38 — cross-fade the nav host in.
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.view.alpha = 0;
    self.navigationController.view.alpha = 0;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];   // DAT_000bfb68
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    self.navigationController.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0xbfb70
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xbfb88 — cross-fade the nav host out. (See honesty note: the guard stores 0, not 1.)
- (void)startCloseAnimation {
    if (!_isAnimationing) {
        _isAnimationing = NO;
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3];   // DAT_000bfc88
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
        self.view.alpha = 0;
        self.navigationController.view.alpha = 0;
        [UIView commitAnimations];
    }
}

// @ 0xbfc90 — remove the host and notify the root map controller.
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    [(MainViewController *)neSceneManager::rootViewController() MapSelectEndCallBack];
    _isAnimationing = NO;
}

#pragma mark - Table

// @ 0xbfcec
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xbfcf0
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _mapDataArray ? (NSInteger)_mapDataArray.count : 0;
}

// @ 0xbfd18 — one MapListCell per main map. On pad the highlighted row draws its selected art.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld-%ld",
                            (long)indexPath.section, (long)indexPath.row];
    MapListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[MapListCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:identifier];
    }
    // Pad highlights the selected row (the binary reads indexPath.row only on pad, comparing
    // it against the stored selection); phone never selects here.
    BOOL isSelect = neSceneManager::isPadDisplay() && (indexPath.row == _selectedIndexRow);
    [cell setMapData:[_mapDataArray objectAtIndex:indexPath.row] isSelect:isSelect];
    return cell;
}

// @ 0xbfe40
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xbfe44 — choose a main map: push the area list (phone) or forward to the overlay (pad).
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0) {
        return;
    }
    if (!neSceneManager::isPadDisplay() &&
        self.navigationController.topViewController != self) {
        return;
    }

    neEngine::playSystemSe(1);   // decide SE

    MainMapData selected;
    [[_mapDataArray objectAtIndex:indexPath.row] getValue:&selected];
    short mainMapId = selected.mainMapId;

    if (_mapSelectDelegate == nil) {
        // Phone: push the sub-map (area) list.
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"area_selec_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
        SubMapSelectViewController *sub = [[SubMapSelectViewController alloc]
            initWithTreasureData:_treasureDataArray
                    mapHeadArray:_mapHeadArray
                       mainMapId:mainMapId];
        [self.navigationController pushViewController:sub animated:YES];
    } else {
        // Pad: forward the selection to the split-view overlay owner.
        [_mapSelectDelegate setSelectIndexPath:indexPath];
        [_mapSelectDelegate touchWithTreasureData:_treasureDataArray
                                     mapHeadArray:_mapHeadArray
                                        mainMapId:mainMapId];
    }

    if (neSceneManager::isPadDisplay()) {
        _selectedIndexRow = (int)indexPath.row;
        [tableView reloadData];
    }
    [UserSettingData saveTreasureSelectedMapId:mainMapId];
}

// @ 0xc0098 — mirror the scroll into the pad overlay.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_mapSelectDelegate == nil) {
        return;
    }
    [_mapSelectDelegate scrollViewDidScroll:scrollView];
}

#pragma mark - DownloadMain delegate

// @ 0xc00bc — event-info refreshed: rebuild the banner header and reload.
- (void)downloadMainFinished:(NSNumber *)success {
    [self updateEventInfo];
    [self.tableView reloadData];
}

#pragma mark - Navigation

// @ 0xc00fc — back button: clear any pending treasure selection, then close.
- (void)backButtonFunc {
    TreasureTmpData tmp = [UserSettingData treasureTmp];
    tmp.subMapId = -1;
    [UserSettingData saveTreasureTmp:tmp];
    neEngine::playSystemSe(2);   // cancel SE
    [self startCloseAnimation];
}

#pragma mark - Event banner

// @ 0xc0190 — rebuild the active-event id list and the table-header banner.
- (void)updateEventInfo {
    _eventIds = [NSMutableArray array];
    for (NSNumber *eventId in [[DownloadMain getInstance] treasureEventIdArray]) {
        if (isIndexInRange12((unsigned int)[eventId intValue])) {
            [_eventIds addObject:eventId];
        }
    }

    CGRect viewFrame = self.view ? self.view.frame : CGRectZero;
    BOOL isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;

    // Clear spacer header (used when no event is active).
    if (_dummyHeadView == nil) {
        CGFloat spacerH = isOS7 ? 20.0f : 10.0f;
        _dummyHeadView = [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, viewFrame.size.width, spacerH)];
        _dummyHeadView.backgroundColor = [UIColor clearColor];
    }

    // Event banner header (first active event only). Exact origins approximated from the
    // decompiler's inlined image-size math (see honesty note).
    if (_eventIds.count > 0) {
        NSNumber *first = [_eventIds objectAtIndex:0];
        NSString *imgName = [NSString stringWithFormat:@"event_0_%03d", [first intValue]];
        UIImage *img = [UIImage imageNamed:imgName];
        UIImageView *banner = [[UIImageView alloc] initWithImage:img];

        BOOL isPad = neSceneManager::isPadDisplay();
        CGFloat inset  = isPad ? 30.0f : 10.0f;
        CGFloat headerH = (isPad ? 20.0f : 0.0f) + img.size.height + inset;
        if (_eventHeadView == nil) {
            _eventHeadView = [[UIView alloc] init];
            _eventHeadView.backgroundColor = [UIColor clearColor];
        }
        _eventHeadView.frame = CGRectMake(0, 0, viewFrame.size.width, headerH);
        banner.frame = CGRectMake(inset, isPad ? 20.0f : 0.0f, img.size.width, img.size.height);
        [_eventHeadView addSubview:banner];
    }

    if (!neSceneManager::isPadDisplay() && _eventIds.count > 0) {
        self.tableView.tableHeaderView = _eventHeadView;
    } else {
        self.tableView.tableHeaderView = _dummyHeadView;
    }
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
