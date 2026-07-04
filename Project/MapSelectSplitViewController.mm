//
//  MapSelectSplitViewController.mm
//  pop'n rhythmin
//
//  See MapSelectSplitViewController.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin:
//    init                                         @ 0x754d8
//    dealloc                                      @ 0x764dc
//    viewDidLoad                                  @ 0x765dc  (super-only, omitted below)
//    didReceiveMemoryWarning                      @ 0x76608  (super-only, omitted below)
//    viewWillAppear:                              @ 0x76634
//    setSelectIndexPath:                          @ 0x766b8
//    startOpenAnimation                           @ 0x766e0
//    endOpenAnimation                             @ 0x7680c
//    startCloseAnimation                          @ 0x769c8
//    endCloseAnimation                            @ 0x76ad0
//    touchWithTreasureData:mapHeadArray:mainMapId:@ 0x76b40
//    scrollViewDidScroll:                         @ 0x77768
//    scrollViewWillBeginDragging:                 @ 0x77f00
//    scrollViewDidEndDecelerating:                @ 0x77f28
//    scrollViewDidEndDragging:willDecelerate:     @ 0x77f38
//    restartAutoScroll                            @ 0x77f50
//    restartAutoScrollAfterDelay                  @ 0x77f70
//    autoScroll                                   @ 0x77fa4
//    downloadMainFinished:                        @ 0x7819c
//    updateEventInfo                              @ 0x781ac
//    pageControlDidChanged:                       @ 0x786fc
//    backButtonFunc                               @ 0x78794
//    isAnimationing                               @ 0x787d8
//  File-static block-invoke helpers (MapSelect layout/scroll geometry):
//    mapSelectResetArrowFrame                     @ 0x76fc8
//    mapSelectAdvanceArrowFrame                   @ 0x7706c
//    mapSelectLayoutRightDummyViews               @ 0x77208
//    mapSelectSetRightDummyWidth                  @ 0x775b4
//    mapSelectAdvanceArrowFrameAlt                @ 0x77a98
//    mapSelectSetRightDummyWidthAlt               @ 0x77de8
//    mapSelectSyncScrollToPage                    @ 0x780d0
//  Objective-C++ for the C++ neSceneManager singleton / neEngine SE bridge. ARC.
//
//  Honesty notes:
//   - Every subview frame is a literal IEEE-754 constant recovered from the binary; the two
//     container sizes are derived from their backing image frame (width - 20, height - 130 for
//     the left map clip; width - 20, height - 190 for the right area clip), matching the
//     FloatVectorAdd deltas at DAT_00075c98 (-130) / DAT_00075c9c (-190).
//   - Image resource names are best-effort decodes of the binary's C-string symbols
//     (cf_map_select_bg -> "map_select_bg", etc.).
//   - The 7 file-static helpers are block invoke functions Ghidra surfaced as top-level
//     symbols; in the reconstructed ObjC++ they are expressed as static functions called
//     from inside UIView transition animation/completion blocks. The binary stores captured
//     float widths as int32_t in block structs (via vcvt.s32.f32 / vcvt.f32.s32); the
//     ObjC++ captures them directly as CGFloat. The arrow "advance" helpers shift
//     origin.x right by the arrow's own width (displacing it off panel); "reset" restores
//     origin.x to _arrowFrm.origin.x (bringing it back). The "Alt" variants are separate
//     compiled instances of the same logic at the scrollViewDidScroll: call sites.
//   - -scrollViewDidScroll: origin.x guard corrected from origin.y (prior placeholder
//     error) to origin.x, matching the binary's comparison of the first float of each
//     CGRect stret result against _arrowFrm.origin.x (DAT comparisons in the decompile).
//   - -dealloc is KEPT: it detaches this controller from DownloadMain's event-info delegate and
//     tears down the how-to overlay. There is no retained NSTimer (the auto-scroll carousel uses
//     -performSelector:withObject:afterDelay:), so nothing to invalidate. The child-controller /
//     index-path -release calls are ARC-omitted.
//   - The header map-name lookup unwraps _mapSelectViewCtrl.mapDataArray NSValues; that record's
//     layout (MainMapData) is declared in MapSelectViewController.h.
//

#import "MapSelectSplitViewController.h"

#import "MapSelectViewController.h"     // left map list: -setMapSelectDelegate:, -treasureDataArray,
                                        // -mapHeadArray, -mapDataArray + the MainMapData record.
#import "SubMapSelectViewController.h"  // right area panel
#import "HowToViewCtrlPad.h"            // first-run treasure how-to overlay
#import "MainViewController.h"          // MapSelectEndCallBack on the app root VC
#import "DownloadMain.h"                // event-info delegate + live event id list
#import "UserSettingData.h"             // treasureSelectedMapId / isTreasureSelected / charaId
#import "AppDelegate.h"                 // +appAppSupportDirectory (downloaded chara art)
#import "AppFont.h"                     // AppFontName() == getFontNameDFSoGei()
#import "neEngineBridge.h"              // neSceneManager::rootViewController, neEngine::playSystemSe

@interface MapSelectSplitViewController () <DownloadMainDelegate> {
    @public   // de-inlined static helpers reach these via self-> (binary by-offset access)
    BOOL              _isAnimationing;
    UIImageView      *_markView;               // friend-request badge (toggled in viewWillAppear:)
    NSIndexPath      *_selectIndexPath;        // pending area row the arrow points at
    MapSelectViewController    *_mapSelectViewCtrl;   // left: main-map list
    SubMapSelectViewController *_subMapSelectViewCtrl;// right: area list
    UIImageView      *_arrowImageView;         // slides to the selected row
    CGRect            _arrowFrm;               // arrow home frame (x,y,w,h)
    UIImageView      *_rightImageView;         // right "area select" backing image
    UIView           *_rightDummyView;         // right area clip (hosts _subMapSelectViewCtrl)
    UIImageView      *_rightHeaderImageView;   // per-map icon on the header banner
    UILabel          *_rightHeaderLabel;       // map name on the header banner
    UIView           *_rightHeaderDummyView;   // header banner clip
    UIImageView      *_rightEmptyImageView;    // "no area" placeholder (hidden until empty)
    UIImageView      *_eventImageView;         // bottom event banner backing image
    UIView           *_eventDummyView;         // bottom event banner clip
    UIScrollView     *_scrollView;             // event-banner carousel
    UIPageControl    *_pageCtrl;               // carousel page dots (kept hidden)
    BOOL              _eventViewing;           // carousel is currently built/visible
    BOOL              _autoScroll;             // carousel auto-advance armed
    HowToViewCtrlPad *_howtoViewCtrlPad;       // first-run treasure how-to overlay
}
- (void)endOpenAnimation;
- (void)endCloseAnimation;
- (void)backButtonFunc;
- (void)restartAutoScroll;
- (void)restartAutoScrollAfterDelay;
- (void)autoScroll;
- (void)updateEventInfo;
- (void)pageControlDidChanged:(UIPageControl *)pageControl;
@end

// ---------------------------------------------------------------------------
// File-static geometry helpers — block invoke functions lifted by Ghidra as
// top-level symbols; all operate exclusively on MapSelectSplitViewController
// ivars so they live here as static (no seam needed).
// ---------------------------------------------------------------------------

// Ghidra: mapSelectResetArrowFrame @ 0x76fc8
// Block invoke body: restore _arrowImageView.frame.origin.x to _arrowFrm.origin.x
// while leaving origin.y/size unchanged.
// Used in -touchWithTreasureData:… as the animations block when the arrow is already
// displaced (origin.x != _arrowFrm.origin.x) AND the target row falls inside the
// guard band [130, 520] — 0.5 s cross-dissolve slides the arrow back to home x.
static void mapSelectResetArrowFrame(MapSelectSplitViewController *self) {
    CGRect f = self->_arrowImageView ? self->_arrowImageView.frame : CGRectZero;
    f.origin.x = self->_arrowFrm.origin.x;
    self->_arrowImageView.frame = f;
}

// Ghidra: mapSelectAdvanceArrowFrame @ 0x7706c
// Block invoke body: shift _arrowImageView.frame.origin.x right by frame.size.width,
// displacing the arrow off the left panel.
// Used in -touchWithTreasureData:… as the animations block when the arrow is at rest
// (origin.x == _arrowFrm.origin.x) AND the target row falls OUTSIDE the guard band —
// quick 0.1 s cross-dissolve.
static void mapSelectAdvanceArrowFrame(MapSelectSplitViewController *self) {
    CGRect f = self->_arrowImageView ? self->_arrowImageView.frame : CGRectZero;
    f.origin.x += f.size.width;
    self->_arrowImageView.frame = f;
}

// Ghidra: mapSelectLayoutRightDummyViews @ 0x77208
// Block invoke body: collapse _rightDummyView and _rightHeaderDummyView to width 10.0
// (0x41200000); origin and height are preserved from the views' current frames.
// Used as the animations block of the right-panel cross-dissolve in both
// -touchWithTreasureData:… and -scrollViewDidScroll:.
static void mapSelectLayoutRightDummyViews(MapSelectSplitViewController *self) {
    if (self->_rightDummyView) {
        CGRect f = self->_rightDummyView.frame;
        f.size.width = 10.0f;
        self->_rightDummyView.frame = f;
    }
    if (self->_rightHeaderDummyView) {
        CGRect f = self->_rightHeaderDummyView.frame;
        f.size.width = 10.0f;
        self->_rightHeaderDummyView.frame = f;
    }
}

// Ghidra: mapSelectSetRightDummyWidth @ 0x775b4
// Block invoke body: restore _rightDummyView and _rightHeaderDummyView widths from
// values captured before the collapsing animation (stored as int32_t via
// vcvt.s32.f32 in the binary's block captures; recovered by vcvt.f32.s32).
// In the ObjC++ reconstruction the widths are captured directly as CGFloat.
// Used as the (nested) completion block in -touchWithTreasureData:…'s right-panel
// cross-dissolve (LAB_000772f8_1 → nested block invoke).
static void mapSelectSetRightDummyWidth(MapSelectSplitViewController *self,
                                        CGFloat rightDummyWidth,
                                        CGFloat rightHeaderDummyWidth) {
    if (self->_rightDummyView) {
        CGRect f = self->_rightDummyView.frame;
        f.size.width = rightDummyWidth;
        self->_rightDummyView.frame = f;
    }
    if (self->_rightHeaderDummyView) {
        CGRect f = self->_rightHeaderDummyView.frame;
        f.size.width = rightHeaderDummyWidth;
        self->_rightHeaderDummyView.frame = f;
    }
}

// Ghidra: mapSelectAdvanceArrowFrameAlt @ 0x77a98
// Block invoke body: identical logic to mapSelectAdvanceArrowFrame; a separate
// compiled block literal at the -scrollViewDidScroll: call site.
// Used when the map list is scrolled and the arrow is at home x — the arrow is
// displaced off-panel (0.1 s cross-dissolve, duration DAT_00077a90).
static void mapSelectAdvanceArrowFrameAlt(MapSelectSplitViewController *self) {
    CGRect f = self->_arrowImageView ? self->_arrowImageView.frame : CGRectZero;
    f.origin.x += f.size.width;
    self->_arrowImageView.frame = f;
}

// Ghidra: mapSelectSetRightDummyWidthAlt @ 0x77de8
// Block invoke body: identical logic to mapSelectSetRightDummyWidth; separate compiled
// instance for -scrollViewDidScroll:'s right-panel cross-dissolve completion block
// (LAB_00077c8c_1 captures self + int32_t widths at +0x18/+0x1c).
static void mapSelectSetRightDummyWidthAlt(MapSelectSplitViewController *self,
                                           CGFloat rightDummyWidth,
                                           CGFloat rightHeaderDummyWidth) {
    if (self->_rightDummyView) {
        CGRect f = self->_rightDummyView.frame;
        f.size.width = rightDummyWidth;
        self->_rightDummyView.frame = f;
    }
    if (self->_rightHeaderDummyView) {
        CGRect f = self->_rightHeaderDummyView.frame;
        f.size.width = rightHeaderDummyWidth;
        self->_rightHeaderDummyView.frame = f;
    }
}

// Ghidra: mapSelectSyncScrollToPage @ 0x780d0
// Block invoke body: set _scrollView.contentOffset.x = frame.size.width *
// _pageCtrl.currentPage, preserving the current contentOffset.y.
// Used as the animations block in -autoScroll's cross-dissolve page transition.
static void mapSelectSyncScrollToPage(MapSelectSplitViewController *self) {
    CGFloat pageWidth = self->_scrollView ? self->_scrollView.frame.size.width : 0.0f;
    NSInteger page    = [self->_pageCtrl currentPage];
    CGPoint   offset  = self->_scrollView ? self->_scrollView.contentOffset : CGPointZero;
    offset.x = pageWidth * (CGFloat)page;
    [self->_scrollView setContentOffset:offset];
}

// ---------------------------------------------------------------------------

@implementation MapSelectSplitViewController

// .cxx_construct @ 0x787f0 — compiler-emitted C++ ivar constructor; not hand-written.

// @ 0x754d8 — build the whole split hub (backdrop, left map list, arrow, right area panel,
// header banner, event carousel, back button) then arm the auto-scroll carousel.
- (instancetype)init {
    if ((self = [super init])) {
        [[DownloadMain getInstance] setDelegateGetEventInfo:self];

        short mainMapId = [UserSettingData treasureSelectedMapId];

        // Full-screen backdrop.
        UIImageView *bg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"map_select_bg"]];
        bg.frame = CGRectMake(0.0f, 0.0f, bg.image.size.width, bg.image.size.height);
        [self.view addSubview:bg];

        // Player character art (bundled for stock ids < 30, otherwise the downloaded copy under
        // the app-support directory).
        short charaId = [UserSettingData charaId];
        NSString *charaName = [NSString stringWithFormat:@"open_chara_%03d.png", (int)charaId];
        NSString *charaPath;
        if (charaId < 30) {
            charaPath = [[NSBundle mainBundle] pathForResource:charaName ofType:nil];
        } else {
            charaPath = [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:charaName];
        }
        UIImage *charaImage =
            [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL fileURLWithPath:charaPath]]];
        UIImageView *charaView = [[UIImageView alloc] initWithImage:charaImage];
        charaView.frame = CGRectMake(341.0f, 608.0f, charaView.frame.size.width, charaView.frame.size.height);
        charaView.backgroundColor = [UIColor clearColor];
        [self.view addSubview:charaView];

        // Left "map select" backing image (interactive; hosts the clipped map list).
        UIImageView *mapSelectBg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"map_select_mapselect_bg"]];
        mapSelectBg.frame = CGRectMake(48.0f, 69.0f, mapSelectBg.image.size.width, mapSelectBg.image.size.height);
        mapSelectBg.userInteractionEnabled = YES;
        [self.view addSubview:mapSelectBg];

        UIView *mapClip = [[UIView alloc] init];
        mapClip.frame = CGRectMake(8.0f, 65.0f,
                                   mapSelectBg.frame.size.width - 20.0f,
                                   mapSelectBg.frame.size.height - 130.0f);  // DAT_00075c98
        mapClip.clipsToBounds = YES;
        [mapSelectBg addSubview:mapClip];

        _mapSelectViewCtrl = [[MapSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [_mapSelectViewCtrl setMapSelectDelegate:self];
        _mapSelectViewCtrl.view.frame = CGRectMake(0.0f, 0.0f, mapClip.frame.size.width, mapClip.frame.size.height);
        [mapClip addSubview:_mapSelectViewCtrl.view];

        // Arrow that slides to the selected row; _arrowFrm is its home frame.
        _arrowImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"map_select_arrow"]];
        _arrowFrm = CGRectMake(372.0f, 166.0f, _arrowImageView.image.size.width, _arrowImageView.image.size.height);
        _arrowImageView.frame = _arrowFrm;
        [self.view addSubview:_arrowImageView];

        // Right "area select" backing image + clipped area panel.
        _rightImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"map_select_areaselect_bg"]];
        _rightImageView.frame = CGRectMake(390.0f, 69.0f, _rightImageView.image.size.width, _rightImageView.image.size.height);
        _rightImageView.userInteractionEnabled = YES;
        _rightImageView.clipsToBounds = YES;
        [self.view addSubview:_rightImageView];

        _rightDummyView = [[UIView alloc] init];
        _rightDummyView.clipsToBounds = YES;
        _rightDummyView.frame = CGRectMake(8.0f, 128.0f,
                                           _rightImageView.frame.size.width - 20.0f,
                                           _rightImageView.frame.size.height - 190.0f);  // DAT_00075c9c
        [_rightImageView addSubview:_rightDummyView];

        _subMapSelectViewCtrl =
            [[SubMapSelectViewController alloc] initWithTreasureData:[_mapSelectViewCtrl treasureDataArray]
                                                       mapHeadArray:[_mapSelectViewCtrl mapHeadArray]
                                                          mainMapId:mainMapId];
        [_subMapSelectViewCtrl setDelegate:self];
        [_rightDummyView addSubview:_subMapSelectViewCtrl.view];

        // Header banner (map icon + name) clipped over the right panel.
        _rightHeaderDummyView = [[UIView alloc] init];
        _rightHeaderDummyView.frame = CGRectMake(8.0f, 84.0f, _rightImageView.frame.size.width - 20.0f, 60.0f);
        _rightHeaderDummyView.clipsToBounds = YES;
        [_rightImageView addSubview:_rightHeaderDummyView];

        UIImageView *banner = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"map_select_banner"]];
        [_rightHeaderDummyView addSubview:banner];

        UIImage *mapIcon = [UIImage imageNamed:[NSString stringWithFormat:@"map_icon_%02d", (int)mainMapId]];
        _rightHeaderImageView = [[UIImageView alloc] initWithFrame:CGRectMake(23.0f, 7.0f, mapIcon.size.width, mapIcon.size.height)];
        _rightHeaderImageView.image = mapIcon;
        [banner addSubview:_rightHeaderImageView];

        // Find this map's display name in the map-data table for the header label.
        NSString *headerName = nil;
        for (NSValue *entry in [_mapSelectViewCtrl mapDataArray]) {
            MainMapData record;
            [entry getValue:&record];
            if (record.mainMapId == mainMapId) {
                headerName = record.name;
                break;
            }
        }

        _rightHeaderLabel = [[UILabel alloc] init];
        _rightHeaderLabel.backgroundColor = [UIColor clearColor];
        _rightHeaderLabel.textColor = [UIColor colorWithRed:0.2706f green:0.2510f blue:0.2313f alpha:1.0f];
        _rightHeaderLabel.highlightedTextColor = [UIColor whiteColor];
        _rightHeaderLabel.font = [UIFont fontWithName:AppFontName() size:17.0f];
        _rightHeaderLabel.textAlignment = NSTextAlignmentLeft;
        _rightHeaderLabel.adjustsFontSizeToFitWidth = YES;
        _rightHeaderLabel.minimumScaleFactor = 0.5f;
        _rightHeaderLabel.text = headerName;
        _rightHeaderLabel.frame = CGRectMake(90.0f, 19.0f, 200.0f, 20.0f);
        [banner addSubview:_rightHeaderLabel];

        // "No area" placeholder, centred in the right panel (hidden unless the map has no areas).
        _rightEmptyImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"area_select_no_area"]];
        _rightEmptyImageView.hidden = YES;
        _rightEmptyImageView.center = CGPointMake(_rightDummyView.frame.size.width * 0.5f,
                                                  _rightDummyView.frame.size.height * 0.5f - 30.0f);
        [_rightDummyView addSubview:_rightEmptyImageView];

        // Bottom event banner (backing image + clip); the carousel is filled by -updateEventInfo.
        _eventImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"map_select_event_bg"]];
        _eventImageView.frame = CGRectMake(2.0f, 733.0f, _eventImageView.image.size.width, _eventImageView.image.size.height);
        _eventImageView.userInteractionEnabled = YES;
        [self.view addSubview:_eventImageView];

        _eventDummyView = [[UIView alloc] initWithFrame:CGRectMake(19.0f, 70.0f, 320.0f, 104.0f)];
        [_eventImageView addSubview:_eventDummyView];
        [self updateEventInfo];

        // Custom back button.
        UIImage *backImage = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backButton = [[UIButton alloc] initWithFrame:CGRectMake(10.0f, 10.0f, backImage.size.width, backImage.size.height)];
        [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
        [backButton addTarget:self action:@selector(backButtonFunc) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:backButton];

        _selectIndexPath = nil;
        _autoScroll = YES;
        [self autoScroll];
    }
    return self;
}

// @ 0x764dc — detach from DownloadMain's event-info delegate and tear down the how-to overlay.
- (void)dealloc {
    [[DownloadMain getInstance] setDelegateGetEventInfo:nil];
    // _mapSelectViewCtrl / _subMapSelectViewCtrl / _selectIndexPath -release calls are ARC-managed.
    if (_howtoViewCtrlPad != nil) {
        [_howtoViewCtrlPad.view removeFromSuperview];
    }
}

// viewDidLoad @ 0x765dc and didReceiveMemoryWarning @ 0x76608 are super-only overrides — omitted.

// @ 0x76634 — refresh the friend-request badge on every appearance.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    int requested = [[DownloadMain getInstance] friendRequestedCnt];
    _markView.hidden = (requested < 1);
}

// @ 0x766b8
- (void)setSelectIndexPath:(NSIndexPath *)selectIndexPath {
    _selectIndexPath = selectIndexPath;
}

// @ 0x766e0 — cross-fade the hub (and the navigation host) in.
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    self.view.alpha = 0.0f;
    self.navigationController.view.alpha = 0.0f;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    self.navigationController.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0x7680c — on open finish, present the first-run treasure how-to once.
- (void)endOpenAnimation {
    _isAnimationing = NO;
    if (![UserSettingData isTreasureSelected]) {
        if (_howtoViewCtrlPad != nil) {
            _howtoViewCtrlPad = nil;   // -release
        }
        NSArray *files = [NSArray arrayWithObjects:@"firstplay_tre01", @"firstplay_tre02", nil];
        _howtoViewCtrlPad = [[HowToViewCtrlPad alloc] initWithFileNameArray:files];

        UIPageControl *pc = _howtoViewCtrlPad.pageCtrl;
        CGRect pcFrame = pc ? pc.frame : CGRectZero;
        pcFrame.origin.y += -50.0f;   // DAT_000769c0
        [_howtoViewCtrlPad.pageCtrl setFrame:pcFrame];

        [neSceneManager::rootViewController().view addSubview:_howtoViewCtrlPad.view];
        [UserSettingData saveIsTreasureSelected:YES];
    }
}

// @ 0x769c8 — cross-fade the hub (and the navigation host) out.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = NO;   // matches the binary (guarded on ==0, then re-stores 0)
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];   // DAT_00076ac8
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0.0f;
    self.navigationController.view.alpha = 0.0f;
    [UIView commitAnimations];
}

// @ 0x76ad0 — on close finish, drop the navigation host and hand control back to the app root.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    [(MainViewController *)neSceneManager::rootViewController() MapSelectEndCallBack];
    _isAnimationing = NO;
}

// @ 0x76b40 — slide the arrow to the selected row and cross-fade the right panel to the new area.
- (void)touchWithTreasureData:(NSArray *)treasureData
                 mapHeadArray:(NSArray *)mapHeadArray
                    mainMapId:(int)mainMapId {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    _mapSelectViewCtrl.tableView.scrollEnabled = NO;

    // Target arrow Y = home Y + selectedRow * rowHeight - the map list's scroll offset.
    CGFloat rowHeight = _mapSelectViewCtrl.tableView.rowHeight;
    CGFloat targetY = _arrowFrm.origin.y + (CGFloat)_selectIndexPath.row * rowHeight;
    targetY -= _mapSelectViewCtrl.tableView.contentOffset.y;

    if (_arrowImageView.frame.origin.x == _arrowFrm.origin.x) {
        // Arrow at rest: cross-dissolve it to the new Y.  Inside the guard band [130, 520]
        // the slide is a slow 0.5 s dissolve to the target row; outside it, a quick 0.1 s
        // snap that displaces the arrow off the panel (mapSelectAdvanceArrowFrame @ 0x7706c).
        if (targetY < 130.0f || 520.0f < targetY) {   // DAT_00076fc0 / DAT_00076fc4
            [UIView transitionWithView:_arrowImageView
                              duration:0.1   // DAT_00076fb8
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                mapSelectAdvanceArrowFrame(self); // Ghidra: @ 0x7706c
                            }
                            completion:nil];
        } else {
            [UIView transitionWithView:_arrowImageView
                              duration:0.5
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                CGRect f = self->_arrowImageView.frame;
                                f.origin.y = targetY;
                                self->_arrowImageView.frame = f;
                            }
                            completion:nil];
        }
    } else {
        // Arrow already displaced: place it directly at the target Y, then (if the target
        // is inside the guard band) dissolve the x back to home (mapSelectResetArrowFrame
        // @ 0x76fc8).
        CGRect f = _arrowImageView.frame;
        f.origin.y = targetY;
        _arrowImageView.frame = f;
        if (130.0f <= targetY && targetY <= 520.0f) {
            [UIView transitionWithView:_arrowImageView
                              duration:0.5
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                mapSelectResetArrowFrame(self); // Ghidra: @ 0x76fc8
                            }
                            completion:nil];
        }
    }

    // Cross-fade the right area panel.
    // animations (mapSelectLayoutRightDummyViews @ 0x77208): collapse both clips to width 10.
    // completion (LAB_000772f8_1): swap in the new SubMapSelectViewController, clear the
    //   animating guard, then restore the original clip widths via mapSelectSetRightDummyWidth
    //   (@ 0x775b4, a nested block invoke created inside the completion with the pre-animation
    //   widths captured as int32_t via vcvt.s32.f32 in the binary).
    CGFloat origDummyW  = _rightDummyView         ? _rightDummyView.frame.size.width         : 0.0f;
    CGFloat origHeaderW = _rightHeaderDummyView   ? _rightHeaderDummyView.frame.size.width   : 0.0f;
    [UIView transitionWithView:_rightDummyView
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        mapSelectLayoutRightDummyViews(self); // Ghidra: @ 0x77208
                    }
                    completion:^(BOOL finished) {
                        // Ghidra: LAB_000772f8_1 — swap SubMapSelectViewController,
                        // release animating guard, restore panel widths.
                        [self->_subMapSelectViewCtrl.view removeFromSuperview];
                        self->_subMapSelectViewCtrl =
                            [[SubMapSelectViewController alloc] initWithTreasureData:treasureData
                                                                       mapHeadArray:mapHeadArray
                                                                          mainMapId:(short)mainMapId];
                        [self->_subMapSelectViewCtrl setDelegate:self];
                        [self->_rightDummyView addSubview:self->_subMapSelectViewCtrl.view];
                        self->_isAnimationing = NO;
                        mapSelectSetRightDummyWidth(self, origDummyW, origHeaderW); // Ghidra: @ 0x775b4
                    }];
}

#pragma mark - UIScrollViewDelegate

// @ 0x77768 — drive the event carousel's page control, or (for the map list) snap the arrow home.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_scrollView != scrollView) {
        // The left map list moved: if the arrow is at home x and nothing is animating,
        // displace it off the panel and collapse/restore the right clips.
        // Guard: compare origin.x (first float of the frame struct) against _arrowFrm.origin.x.
        if (_arrowImageView.frame.origin.x != _arrowFrm.origin.x) {
            return;
        }
        if (_isAnimationing) {
            return;
        }
        neEngine::playSystemSe(2);
        // Shift the arrow off-panel (mapSelectAdvanceArrowFrameAlt @ 0x77a98); on
        // completion re-enable the left map-list table's scrolling and clear the
        // animating guard (Ghidra block LAB_00077b3c_1: [_mapSelectViewCtrl.tableView
        // setScrollEnabled:1]; _isAnimationing = 0 — the mirror of startOpenAnimation).
        [UIView transitionWithView:_arrowImageView
                          duration:0.1   // DAT_00077a90
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            mapSelectAdvanceArrowFrameAlt(self); // Ghidra: @ 0x77a98
                        }
                        completion:^(BOOL finished) {
                            self->_mapSelectViewCtrl.tableView.scrollEnabled = YES;
                            self->_isAnimationing = NO;
                        }];
        // Collapse right clips, then restore widths (mapSelectSetRightDummyWidthAlt @ 0x77de8,
        // LAB_00077c8c_1).  animations body at LAB_00077b9c_1 is the same collapse logic as
        // mapSelectLayoutRightDummyViews (separate compiled instance in the binary).
        CGFloat origDummyW  = _rightDummyView       ? _rightDummyView.frame.size.width       : 0.0f;
        CGFloat origHeaderW = _rightHeaderDummyView ? _rightHeaderDummyView.frame.size.width : 0.0f;
        [UIView transitionWithView:_rightDummyView
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            mapSelectLayoutRightDummyViews(self); // Ghidra: @ 0x77208 (same logic as LAB_00077b9c_1)
                        }
                        completion:^(BOOL finished) {
                            mapSelectSetRightDummyWidthAlt(self, origDummyW, origHeaderW); // Ghidra: @ 0x77de8
                        }];
        return;
    }

    // Event carousel: update the page control from the horizontal offset.
    NSInteger previousPage = _pageCtrl.currentPage;
    CGFloat width = _scrollView.frame.size.width;
    CGFloat page = width != 0.0f ? (_scrollView.contentOffset.x / width) + 0.5f : 0.5f;
    _pageCtrl.currentPage = (NSInteger)page;
    if (previousPage != _pageCtrl.currentPage) {
        neEngine::playSystemSe(4);
        [self pageControlDidChanged:_pageCtrl];
    }
}

// @ 0x77f00
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (_scrollView != scrollView) {
        return;
    }
    _autoScroll = NO;
}

// @ 0x77f28
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self restartAutoScrollAfterDelay];
}

// @ 0x77f38
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (decelerate) {
        return;
    }
    [self restartAutoScrollAfterDelay];
}

#pragma mark - Auto-scroll carousel

// @ 0x77f50
- (void)restartAutoScroll {
    _autoScroll = YES;
    [self autoScroll];
}

// @ 0x77f70
- (void)restartAutoScrollAfterDelay {
    [self performSelector:@selector(restartAutoScroll) withObject:nil afterDelay:3.0];
}

// @ 0x77fa4 — advance the event carousel by one page, then re-arm after 5s.
- (void)autoScroll {
    if (!_autoScroll) {
        return;
    }
    NSInteger current = _pageCtrl.currentPage;
    NSInteger pages = _pageCtrl.numberOfPages;
    NSInteger next = (current == pages - 1) ? 0 : current + 1;
    _pageCtrl.currentPage = next;
    // Cross-dissolve the carousel to the new page; the animations block syncs the scroll
    // offset to _pageCtrl.currentPage (already set to `next` above).
    // Ghidra: mapSelectSyncScrollToPage @ 0x780d0 as the animations block invoke.
    [UIView transitionWithView:_scrollView
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        mapSelectSyncScrollToPage(self); // Ghidra: @ 0x780d0
                    }
                    completion:nil];
    [self performSelector:@selector(autoScroll) withObject:nil afterDelay:5.0];
}

#pragma mark - Event info

// @ 0x7819c — DownloadMainDelegate: the event list finished downloading.
- (void)downloadMainFinished:(NSNumber *)success {
    [self updateEventInfo];
}

// @ 0x781ac — (re)build the bottom event-banner carousel from DownloadMain's live event ids.
- (void)updateEventInfo {
    // Keep only in-range event ids (< 12; app helper isIndexInRange12 @ 0xe2c3c).
    NSArray *eventIds = [[DownloadMain getInstance] treasureEventIdArray];
    NSMutableArray *events = [NSMutableArray array];
    for (NSNumber *eventId in eventIds) {
        if ((unsigned)[eventId intValue] < 12u) {
            [events addObject:eventId];
        }
    }

    if (events.count == 0) {
        _eventImageView.hidden = YES;
        _eventViewing = NO;
    } else if (!_eventViewing) {
        _eventImageView.hidden = NO;
        [_scrollView removeFromSuperview];
        [_pageCtrl removeFromSuperview];

        UIImage *eventStrip = [UIImage imageNamed:@"map_select_event"];
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, eventStrip.size.width, eventStrip.size.height)];
        _scrollView.contentSize = eventStrip.size;
        _scrollView.delegate = self;

        if (events.count != 0) {
            int firstId = [events[0] intValue];
            UIImage *eventImage = [UIImage imageNamed:[NSString stringWithFormat:@"event_0_%03d", firstId]];
            UIImageView *eventIconView = [[UIImageView alloc] initWithImage:eventImage];
            CGRect f = eventIconView.frame;
            f.origin.x = 0.0f;   // FloatVectorMult(size, 0) — first page at x = 0
            eventIconView.frame = f;
            [_scrollView addSubview:eventIconView];
        }

        [_eventDummyView addSubview:_scrollView];

        _pageCtrl = [[UIPageControl alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _eventDummyView.frame.size.width, 30.0f)];
        _pageCtrl.numberOfPages = events.count;
        _pageCtrl.currentPage = 0;
        _pageCtrl.hidden = YES;
        [_eventDummyView addSubview:_pageCtrl];

        _eventViewing = YES;
    }
}

// @ 0x786fc — scroll the carousel to the page the page control now shows.
- (void)pageControlDidChanged:(UIPageControl *)pageControl {
    CGFloat width = _scrollView.frame.size.width;
    CGFloat height = _scrollView.frame.size.height;
    CGFloat x = width * (CGFloat)pageControl.currentPage;
    [_scrollView scrollRectToVisible:CGRectMake(x, 0.0f, width, height) animated:YES];
}

#pragma mark - Back button

// @ 0x78794
- (void)backButtonFunc {
    if (_isAnimationing) {
        return;
    }
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

// @ 0x787d8
- (BOOL)isAnimationing {
    return _isAnimationing;
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
