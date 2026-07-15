//
//  CheckerCategoryViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The
//  music-checker genre-category list and its arcade-score HTTP sync.
//  Objective-C++ (.mm) because it drives the C++ "ne" engine singletons via
//  neEngineBridge (scene-manager pad flag, the system-SE hooks and the
//  e-AMUSEMENT login context).
//

#import "CheckerCategoryViewController.h"

#import "AppDelegate.h"                // +appDelegate.managedObjectContext
#import "ArcadeScoreData+Store.h"      // fetch / insert query methods
#import "ArcadeScoreData.h"            // Core Data arcade-score records
#import "CheckerCategoryCell.h"        // in-project row cell (setData:category:)
#import "CheckerMusicViewController.h" // pushed on row select
#import "CommonAlertView.h"            // sync result / error alerts
#import "Downloader.h"                 // the score-sync HTTP request
#import "InputOTPViewCtrl.h"           // OTP-input screen (initWithCategoryView:)
#import "StoreUtil.h"                  // +getArcadeScoreURL
#import "UserSettingData.h"            // +konamiId
#import "neEngineBridge.h"

// Alert messages (Ghidra CFStrings cf_Ok01YWeW0_0W0_00 @ 0x134a78 and
// cf_s_W00000k0j0c0f0D00 @ 0x13afe8).
static NSString *const kMsgCommFailed = @"通信に失敗しました。\n電波の良い場所でやり直して下さい。";
static NSString *const kMsgNoPlayData =
    @"現在アクティブになっている\ne-AMUSEMENT PASS で、\npop'n music "
    @"のプレーデータは\n見つかりませんでした。";

@interface CheckerCategoryViewController () <DownloaderDelegate>
- (void)touchedBackButton:(id)sender;
- (void)touchedGetDataButton:(id)sender;
- (NSString *)convertReplaceChara:(NSString *)string;
- (NSNumber *)convertCategoryId:(NSNumber *)categoryId;
@end

@implementation CheckerCategoryViewController {
    UIViewController *_dummyView;      // dimmed cover hosting the sync spinner
    NSArray *_scoreDataArray[25];      // [0..23] per-category records, [24] the
                                       // latest-10 bucket
    Downloader *_dlGetArcadeScoreData; // in-flight score-sync request (nil when idle)
}

// @ 0xcfb88 — build the transparent grouped table, the header "get data" button
// + spinner cover, and load the locally-cached arcade scores into the 25
// buckets.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self == nil) {
        return nil;
    }

    neAppEventCenter::shared();
    id refId = neAppEventCenter::linkRefId();
    CGRect viewFrame = self.view.frame;

    neSceneManager::shared();
    BOOL isPad = neSceneManager::isPadDisplay();
    self.tableView.rowHeight = isPad ? 66.0f : 46.0f;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor clearColor];

    // Load the locally-cached records: 24 per-category buckets + a "latest 10"
    // bucket.
    NSManagedObjectContext *moc = [AppDelegate appDelegate].managedObjectContext;
    _scoreDataArray[24] = [ArcadeScoreData getLatestDataLimit:10
                                                        refId:refId
                                       inManagedObjectContext:moc];
    for (short i = 0; i < 24; i++) {
        _scoreDataArray[i] = [ArcadeScoreData getDataFromCategory:i
                                                            refId:refId
                                           inManagedObjectContext:moc];
    }

    // Header: the category banner + a "get data" button, hosted in a container
    // padded below (banner height + 12, plus 20 more on iPad).
    UIImage *headerImg = [UIImage imageNamed:@"ppc_cate_header"];
    UIImageView *headerImgView = [[UIImageView alloc] initWithImage:headerImg];
    [headerImgView setFrame:CGRectMake(0.0f, 12.0f, headerImg.size.width, headerImg.size.height)];

    UIButton *getButton = [[UIButton alloc] init];
    UIImage *getImg = [UIImage imageNamed:@"ppc_cate_btn_getdata"];
    [getButton setFrame:CGRectMake(170.0f,
                                   headerImgView.frame.origin.y + 10.0f,
                                   getImg.size.width,
                                   getImg.size.height)];
    [getButton setBackgroundImage:getImg forState:UIControlStateNormal];
    [getButton addTarget:self
                  action:@selector(touchedGetDataButton:)
        forControlEvents:UIControlEventTouchUpInside];

    UIView *headerView = [[UIView alloc] init];
    CGFloat headerViewHeight = headerImg.size.height + headerImgView.frame.origin.y;
    if (isPad) {
        headerViewHeight += 20.0f;
    }
    headerView.frame = CGRectMake(0.0f, 0.0f, headerImg.size.width, headerViewHeight);
    [headerView addSubview:headerImgView];
    [headerView addSubview:getButton];
    self.tableView.tableHeaderView = headerView;

    // Backdrop: the "friman" paper on phone; a clear background on iPad.
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        UIImage *bg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *bgView = [[UIImageView alloc] initWithImage:bg];
        [bgView setFrame:CGRectMake(0.0f, 0.0f, bg.size.width, bg.size.height)];
        self.tableView.backgroundView = bgView;
    } else {
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.backgroundView = nil;
    }

    // Dimmed cover view (hosts the spinner shown during a sync).
    _dummyView = [[UIViewController alloc] init];
    _dummyView.view.frame = viewFrame;
    _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0.0f];
    _dummyView.view.hidden = YES;
    [self.view addSubview:_dummyView.view];

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    if (!isPad) {
        spinner.center =
            CGPointMake(viewFrame.size.width * 0.5f, viewFrame.size.height * 0.5f - 10.0f);
    } else {
        spinner.center = CGPointMake(160.0f, 358.0f);
    }
    spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    [spinner startAnimating];
    [_dummyView.view addSubview:spinner];

    // Custom back button in the left nav slot (phone only).
    if (!isPad) {
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backButton = [[UIButton alloc]
            initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
        [backButton setBackgroundImage:backImg forState:UIControlStateNormal];
        [backButton addTarget:self
                       action:@selector(touchedBackButton:)
             forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backButton];
    }
    return self;
}

// @ 0xd04bc — cancel the in-flight sync so no late callback fires into a dead
// controller; the bucket arrays and the cover view are released under ARC.
- (void)dealloc {
    if (_dlGetArcadeScoreData != nil) {
        [_dlGetArcadeScoreData cancel];
        _dlGetArcadeScoreData = nil;
    }
}

// @ 0xd0564 — unhide the cover view after loading (matches the binary).
- (void)viewDidLoad {
    [super viewDidLoad];
    _dummyView.view.hidden = NO;
}

// @ 0xd05c4 — re-center the spinner cover on the controller view (no super call
// in the binary).
- (void)viewWillAppear:(BOOL)animated {
    _dummyView.view.center =
        CGPointMake(self.view.frame.size.width * 0.5f, self.view.frame.size.height * 0.5f);
}

// @ 0xd0688 — super only.
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Score sync

// @ 0xd06b4 — POST konami-id / password / otp to the arcade-score endpoint
// (guards against a second concurrent request) and show the spinner cover.
- (void)startGetArcadeScoreHttpWithOtp:(NSString *)otp {
    if (_dlGetArcadeScoreData != nil) {
        return;
    }
    NSString *konamiId = [UserSettingData konamiId];
    neAppEventCenter::shared();
    NSString *body = [NSString stringWithFormat:@"konami_id=%@&password=%@&otp=%@",
                                                konamiId,
                                                neAppEventCenter::inputPassword(),
                                                (otp != nil ? otp : @"")];
    _dlGetArcadeScoreData =
        [[Downloader alloc] initWithURL:[StoreUtil getArcadeScoreURL]
                               delegate:self
                                   Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                            ContextType:@"application/json"];
    [_dlGetArcadeScoreData startDownloading];
    _dummyView.view.hidden = NO;
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

// @ 0xd0810
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xd0814 — one row per non-empty bucket (of the 25).
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rows = 0;
    for (int i = 0; i < 25; i++) {
        if (_scoreDataArray[i].count != 0) {
            rows++;
        }
    }
    return rows;
}

// @ 0xd085c — bind the N-th non-empty bucket (scanned high (24) to low) to the
// row, passing its bucket index as the category.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier =
        [NSString stringWithFormat:@"Cell%ld_%ld", (long)indexPath.section, (long)indexPath.row];
    CheckerCategoryCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[CheckerCategoryCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:identifier];
    }

    int found = 0;
    int idx = 0;
    for (int i = 24; i >= 0; i--) {
        if (_scoreDataArray[i].count != 0) {
            if (indexPath.row == found) {
                idx = i;
                break;
            }
            found++;
        }
    }
    [cell setData:_scoreDataArray[idx] category:(short)idx];
    return cell;
}

// @ 0xd0988
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xd098c — push the CheckerMusicViewController for the selected bucket.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.navigationController.topViewController != self || indexPath.section != 0) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(1); // decide SE

    int found = 0;
    int idx = 0;
    for (int i = 24; i >= 0; i--) {
        if (_scoreDataArray[i].count != 0) {
            if (indexPath.row == found) {
                idx = i;
                break;
            }
            found++;
        }
    }
    CheckerMusicViewController *music =
        [[CheckerMusicViewController alloc] initWithScoreData:_scoreDataArray[idx]
                                                     category:(short)idx];
    neSceneManager::shared();
    [self.navigationController pushViewController:music animated:!neSceneManager::isPadDisplay()];
}

#pragma mark - DownloaderDelegate

// @ 0xd0ad8 — parse the JSON response: on error show the matching alert; on
// success merge every record into the local Core Data store, rebuild the
// buckets and reload.
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [_dlGetArcadeScoreData getDataInJSON];
    NSString *message;

    id errorCode = [json objectForKey:@"ErrorCode"];
    if (errorCode != nil) {
        message = ([errorCode intValue] == 3) ? kMsgNoPlayData : kMsgCommFailed;
    } else {
        NSArray *list = [json objectForKey:@"List"];
        if (list == nil || list.count == 0) {
            message = kMsgCommFailed;
        } else {
            // Parallel columns, filled per record (row kept only when MusicNo is
            // set).
            NSMutableArray *musicNo = [NSMutableArray array];
            NSMutableArray *title = [NSMutableArray array];
            NSMutableArray *genre = [NSMutableArray array];
            NSMutableArray *category = [NSMutableArray array];
            NSMutableArray *topNameEs = [NSMutableArray array];
            NSMutableArray *topEs = [NSMutableArray array];
            NSMutableArray *meanEs = [NSMutableArray array];
            NSMutableArray *myEs = [NSMutableArray array];
            NSMutableArray *topNameN = [NSMutableArray array];
            NSMutableArray *topN = [NSMutableArray array];
            NSMutableArray *meanN = [NSMutableArray array];
            NSMutableArray *myN = [NSMutableArray array];
            NSMutableArray *topNameH = [NSMutableArray array];
            NSMutableArray *topH = [NSMutableArray array];
            NSMutableArray *meanH = [NSMutableArray array];
            NSMutableArray *myH = [NSMutableArray array];
            NSMutableArray *topNameEx = [NSMutableArray array];
            NSMutableArray *topEx = [NSMutableArray array];
            NSMutableArray *meanEx = [NSMutableArray array];
            NSMutableArray *myEx = [NSMutableArray array];

            for (NSDictionary *rec in list) {
                id no = [rec objectForKey:@"MusicNo"];
                id recTitle = [self convertReplaceChara:[rec objectForKey:@"Title"]];
                id recGenre = [self convertReplaceChara:[rec objectForKey:@"Genre"]];
                id recCategory = [self convertCategoryId:[rec objectForKey:@"Category"]];
                id recTopNameEs = [self convertReplaceChara:[rec objectForKey:@"TopNameEs"]];
                id recTopEs = [rec objectForKey:@"TopEs"];
                id recMeanEs = [rec objectForKey:@"MeanEs"];
                id recMyEs = [rec objectForKey:@"MyEs"];
                id recTopNameN = [self convertReplaceChara:[rec objectForKey:@"TopNameN"]];
                id recTopN = [rec objectForKey:@"TopN"];
                id recMeanN = [rec objectForKey:@"MeanN"];
                id recMyN = [rec objectForKey:@"MyN"];
                id recTopNameH = [self convertReplaceChara:[rec objectForKey:@"TopNameH"]];
                id recTopH = [rec objectForKey:@"TopH"];
                id recMeanH = [rec objectForKey:@"MeanH"];
                id recMyH = [rec objectForKey:@"MyH"];
                id recTopNameEx = [self convertReplaceChara:[rec objectForKey:@"TopNameEx"]];
                id recTopEx = [rec objectForKey:@"TopEx"];
                id recMeanEx = [rec objectForKey:@"MeanEx"];
                id recMyEx = [rec objectForKey:@"MyEx"];
                if (no != nil) {
                    [musicNo addObject:no];
                    [title addObject:recTitle];
                    [genre addObject:recGenre];
                    [category addObject:recCategory];
                    [topNameEs addObject:recTopNameEs];
                    [topEs addObject:recTopEs];
                    [meanEs addObject:recMeanEs];
                    [myEs addObject:recMyEs];
                    [topNameN addObject:recTopNameN];
                    [topN addObject:recTopN];
                    [meanN addObject:recMeanN];
                    [myN addObject:recMyN];
                    [topNameH addObject:recTopNameH];
                    [topH addObject:recTopH];
                    [meanH addObject:recMeanH];
                    [myH addObject:recMyH];
                    [topNameEx addObject:recTopNameEx];
                    [topEx addObject:recTopEx];
                    [meanEx addObject:recMeanEx];
                    [myEx addObject:recMyEx];
                }
            }

            neAppEventCenter::shared();
            id refId = neAppEventCenter::linkRefId();
            NSManagedObjectContext *moc = [AppDelegate appDelegate].managedObjectContext;
            for (NSUInteger i = 0; i < musicNo.count; i++) {
                short mid = [musicNo[i] shortValue];
                ArcadeScoreData *rec = [ArcadeScoreData getDataFromMusicId:mid
                                                                     refId:refId
                                                    inManagedObjectContext:moc];
                if (rec == nil) {
                    rec = [ArcadeScoreData addRecordWithMusicId:mid
                                                          refId:refId
                                         inManagedObjectContext:moc];
                }
                [rec setTitle:title[i]];
                [rec setGenre:genre[i]];
                [rec setCategory:[NSNumber numberWithShort:[category[i] shortValue]]];
                [rec setUpdateDate:[NSDate date]];
                [rec setTopNameEs:topNameEs[i]];
                [rec setTopNameN:topNameN[i]];
                [rec setTopNameH:topNameH[i]];
                [rec setTopNameEx:topNameEx[i]];
                [rec setTopScoreEs:[NSNumber numberWithInt:[topEs[i] intValue]]];
                [rec setTopScoreN:[NSNumber numberWithInt:[topN[i] intValue]]];
                [rec setTopScoreH:[NSNumber numberWithInt:[topH[i] intValue]]];
                [rec setTopScoreEx:[NSNumber numberWithInt:[topEx[i] intValue]]];
                [rec setMeanScoreEs:[NSNumber numberWithInt:[meanEs[i] intValue]]];
                [rec setMeanScoreN:[NSNumber numberWithInt:[meanN[i] intValue]]];
                [rec setMeanScoreH:[NSNumber numberWithInt:[meanH[i] intValue]]];
                [rec setMeanScoreEx:[NSNumber numberWithInt:[meanEx[i] intValue]]];
                [rec setMyScoreEs:[NSNumber numberWithInt:[myEs[i] intValue]]];
                [rec setMyScoreN:[NSNumber numberWithInt:[myN[i] intValue]]];
                [rec setMyScoreH:[NSNumber numberWithInt:[myH[i] intValue]]];
                [rec setMyScoreEx:[NSNumber numberWithInt:[myEx[i] intValue]]];

                NSError *error = nil;
                if (![moc save:&error]) {
                    // The binary walks the detailed validation errors but does nothing
                    // with them; kept for fidelity.
                    for (id detail in [error.userInfo objectForKey:NSDetailedErrorsKey]) {
                        (void)detail;
                    }
                }
            }

            // Rebuild the buckets from the freshly-merged store and reload.
            _scoreDataArray[24] = [ArcadeScoreData getLatestDataLimit:10
                                                                refId:refId
                                               inManagedObjectContext:moc];
            for (short i = 0; i < 24; i++) {
                _scoreDataArray[i] = [ArcadeScoreData getDataFromCategory:i
                                                                    refId:refId
                                                   inManagedObjectContext:moc];
            }
            [self.tableView reloadData];
            message = nil;
        }
    }

    _dlGetArcadeScoreData = nil;
    if (message != nil) {
        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:nil
                                                                message:message
                                                               delegate:nil
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"OK"];
        [alert show];
    }
    _dummyView.view.hidden = YES;
}

// @ 0xd1884 — progress callback: unused.
- (void)downloaderProceed:(Downloader *)downloader {
}

// @ 0xd1888 — the sync failed: drop the request, hide the spinner and alert.
- (void)downloaderError:(Downloader *)downloader {
    _dlGetArcadeScoreData = nil;
    _dummyView.view.hidden = YES;
    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:nil
                                                            message:kMsgCommFailed
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"OK"];
    [alert show];
}

#pragma mark - Actions

// @ 0xd1960 — BACK: only as the nav top VC; play the cancel SE, restore the
// nav-bar art and pop.
- (void)touchedBackButton:(id)sender {
    if (self.navigationController.topViewController != self) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(2); // cancel SE
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"pl_navbar"]
                                                  forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0xd1a18 — GET DATA: only as the nav top VC; play the decide SE, then either
// sync straight away or (when an OTP is required) push the OTP-input screen
// first.
- (void)touchedGetDataButton:(id)sender {
    if (self.navigationController.topViewController != self) {
        return;
    }
    neSceneManager::shared();
    neEngine::playSystemSe(1); // decide SE
    neAppEventCenter::shared();
    if (!neAppEventCenter::requireOtpInput()) {
        [self startGetArcadeScoreHttpWithOtp:nil];
    } else {
        [self.navigationController.navigationBar
            setBackgroundImage:[UIImage imageNamed:@"input_kid_navbar"]
                 forBarMetrics:UIBarMetricsDefault];
        InputOTPViewCtrl *otpViewCtrl = [[InputOTPViewCtrl alloc] initWithCategoryView:self];
        [self.navigationController pushViewController:otpViewCtrl animated:YES];
    }
}

#pragma mark - Title / category normalization

// @ 0xd1b40 — normalize a server-supplied title/name: fix two CP932 mojibake
// glyphs and expand the HTML entities the arcade score API emits for accented
// characters.
- (NSString *)convertReplaceChara:(NSString *)string {
    NSString *s = string;
    s = [s stringByReplacingOccurrencesOfString:@"＜" withString:@"〜"]; // U+FF3C -> U+301C
    s = [s stringByReplacingOccurrencesOfString:@"→" withString:@"ー"];  // U+2192 -> U+30FC
    s = [s stringByReplacingOccurrencesOfString:@"&hearts;" withString:@"♡"];
    s = [s stringByReplacingOccurrencesOfString:@"&agrave;" withString:@"à"];
    s = [s stringByReplacingOccurrencesOfString:@"&auml;" withString:@"ä"];
    s = [s stringByReplacingOccurrencesOfString:@"&Auml;" withString:@"Ä"];
    s = [s stringByReplacingOccurrencesOfString:@"&copy;" withString:@"©"];
    s = [s stringByReplacingOccurrencesOfString:@"&eacute;" withString:@"é"];
    s = [s stringByReplacingOccurrencesOfString:@"&ecirc;" withString:@"ê"];
    s = [s stringByReplacingOccurrencesOfString:@"&euml;" withString:@"ë"];
    s = [s stringByReplacingOccurrencesOfString:@"&oacute;" withString:@"ó"];
    s = [s stringByReplacingOccurrencesOfString:@"&ouml;" withString:@"ö"];
    s = [s stringByReplacingOccurrencesOfString:@"&sup2;" withString:@"²"];
    return s;
}

// @ 0xd1cac — remap the server's category code to the app's category index:
// 50 -> 1 (TV), 60 -> 0 (etc), otherwise +2.
- (NSNumber *)convertCategoryId:(NSNumber *)categoryId {
    int value = [categoryId intValue];
    int result;
    if (value == 50) {
        result = 1;
    } else if (value == 60) {
        result = 0;
    } else {
        result = value + 2;
    }
    return [NSNumber numberWithInt:result];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
