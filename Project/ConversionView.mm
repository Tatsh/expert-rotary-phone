//
//  ConversionView.mm
//  pop'n rhythmin
//
//  See ConversionView.h. Reconstructed from Ghidra project rb420, program PopnRhythmin:
//    init                                    @ 0x1be48
//    dealloc                                 @ 0x1be84  (chains to super only -> ARC-omitted)
//    viewDidLoad                             @ 0x1beb0
//    didReceiveMemoryWarning                 @ 0x1ca9c  (super-only)
//    viewDidUnload                           @ 0x1cac8  (super-only)
//    viewWillAppear:                         @ 0x1caf4  (super-only)
//    viewDidAppear:                          @ 0x1cb20  (super-only)
//    viewWillDisappear:                      @ 0x1cb4c  (super-only)
//    viewDidDisappear:                       @ 0x1cb78  (super-only)
//    shouldAutorotateToInterfaceOrientation: @ 0x1cba4
//    backButtonFunc                          @ 0x1cbb0
//    okButtonFunc                            @ 0x1cc4c
//    commonAlertView:clickedButtonAtIndex:   @ 0x1cd00
//    startConversionHttp                     @ 0x1cf0c
//    downloaderFinished:                     @ 0x1da60
//    downloaderError:                        @ 0x1dc84
//    startCloseAnimation                     @ 0x1dd50
//    endCloseAnimation                       @ 0x1de20
//    delegate                                @ 0x1de7c
//    setDelegate:                            @ 0x1de8c
//  Objective-C++ for the C++ neEngine / neSceneManager singletons. ARC.
//
//  Honesty notes:
//   - The caution / how-to bodies are NOT embedded: -viewDidLoad loads them from
//     the bundle via -[NSBundle pathForResource:@"caution"/@"howto" ofType:@"txt"]
//     + -[NSData dataWithContentsOfFile:] + UTF-8 -[NSString initWithData:encoding:].
//     The two section captions and every alert string are exact UTF-16 CFString
//     decodes; the ASCII CFStrings ("friman_bg", "conv_bt_yes", "navi_btn_back",
//     "settings_navbar", "yyyy-MM-dd HH:mm:ss", "param=%@", "json=%@", "%06d",
//     "application/json", and the JSON dictionary keys) are exact.
//   - -viewDidLoad's sub-view frames come from a heavily NEON-spilled vector
//     sequence; the two text-view y offsets (+50, +150) and the label frames are
//     exact float decodes, but the per-device label origin nudge and the OK-button
//     centring are best-effort (flagged inline).
//   - -init stores self into the delegate ivar (a plain pointer store); the
//     container immediately overrides it via -setDelegate:. Kept faithfully.
//   - The success/error CommonAlertViews are alloc/init/show/release in the binary
//     (they retain themselves by adding to the root scene view in -show); ARC keeps
//     the alloc, drops the manual release.
//   - -dealloc only chains to [super dealloc]; it does NOT cancel an in-flight
//     _downloader, so it is ARC-omitted (no added behaviour to preserve).
//   - _indicator is never assigned in the reconstructed methods (only -stopAnimating
//     is sent to it, a no-op while nil); its spinner is presumably driven by the
//     container. Declared for faithfulness.
//   - -commonAlertView:...: the "mail" action sends -GotoMailWithText: to the
//     MainViewController *class* object (exact from the decomp: the classref is
//     loaded into the receiver and never replaced); cast through id so the
//     instance-declared selector compiles. Flagged as a faithful oddity.
//

#import "ConversionView.h"
#import "ScoreData.h"
#import "TreasureData.h"
#import "CharaTicketData.h"
#import "MusicManager.h"

#import "AppDelegate.h"        // +appDelegate -> uuId / managedObjectContext
#import "AppFont.h"            // AppFontName() == getFontNameDFSoGei(), AppMaruFontName() == getFontNameDFMaruGothic()
#import "CommonAlertView.h"
#import "Downloader.h"
#import "MainViewController.h" // -GotoMailWithText: / isGotoTitle / -AcceptPolicyEndCallBack (root)
#import "StoreUtil.h"          // +getConvertCodeURL
#import "UserSettingData.h"    // player save accessors

#import "neEngineBridge.h"     // neEngine::playSystemSe, neSceneManager::shared/rootViewController/isPadDisplay

@implementation ConversionView {
    BOOL isAnimationing;                  // +? close-fade guard
    UIActivityIndicatorView *_indicator;  // spinner (driven by the container; see notes)
    Downloader *_downloader;              // in-flight convert-code POST (nil when idle)
    NSString *_convertCodeStr;            // "%06d" formatted issued pass
}

@synthesize delegate = _delegate;

// @ 0x1be48
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        // Faithful: the binary stores self into the delegate ivar as a default; the
        // container overrides it via -setDelegate: right after -init.
        _delegate = (id<ViewCmnProtocol>)self;
    }
    return self;
}

// dealloc @ 0x1be84 — ARC-omitted (chains to [super dealloc] only; does not cancel
// the in-flight downloader).

// @ 0x1beb0 — build the backdrop, the two captioned text sections (caution / how-to),
// the OK ("issue pass") button, and the nav-bar back button.
- (void)viewDidLoad {
    [super viewDidLoad];

    const BOOL isPad = neSceneManager::isPadDisplay();

    CGRect vf = self.view ? self.view.frame : CGRectZero;

    // Backdrop: phone uses the framed window art; pad clears the background.
    if (!isPad) {
        UIImage *bg = [UIImage imageNamed:@"friman_bg"];
        UIImageView *bgView = [[UIImageView alloc] initWithImage:bg];
        [self.view addSubview:bgView];
    } else {
        self.view.backgroundColor = [UIColor clearColor];
    }

    UIColor *labelColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
    UIColor *bodyColor  = [UIColor colorWithRed:0.3f green:0.3f blue:0.3f alpha:1.0f];

    // --- Section 1 caption: 注意 ("Caution") ---
    UILabel *cautionLabel = [[UILabel alloc] init];
    cautionLabel.backgroundColor = [UIColor clearColor];
    cautionLabel.textColor = labelColor;
    cautionLabel.highlightedTextColor = [UIColor whiteColor];
    cautionLabel.font = [UIFont fontWithName:AppFontName() size:15.0f];
    cautionLabel.textAlignment = NSTextAlignmentCenter;
    cautionLabel.adjustsFontSizeToFitWidth = YES;
    cautionLabel.minimumScaleFactor = 10.0f;
    cautionLabel.frame = CGRectMake(0.0f, 10.0f, 272.0f, 50.0f);
    if (!isPad) {
        // Phone origin nudge (+24,+24) from the NEON pair — best-effort.
        CGRect f = cautionLabel.frame;
        f.origin.x += 24.0f;
        f.origin.y += 24.0f;
        cautionLabel.frame = f;
    }
    cautionLabel.text = @"注意";
    [self.view addSubview:cautionLabel];

    // --- Section 1 body: bundled caution.txt (UTF-8), read-only ---
    UITextView *cautionText =
        [[UITextView alloc] initWithFrame:CGRectMake(vf.origin.x, vf.origin.y + 50.0f,
                                                     vf.size.width, vf.size.height)];
    NSString *cautionPath = [[NSBundle mainBundle] pathForResource:@"caution" ofType:@"txt"];
    NSString *cautionBody = [[NSString alloc]
        initWithData:[NSData dataWithContentsOfFile:cautionPath] encoding:NSUTF8StringEncoding];
    cautionText.backgroundColor = [UIColor clearColor];
    cautionText.editable = NO;
    cautionText.text = cautionBody;
    cautionText.textColor = bodyColor;
    cautionText.font = [UIFont fontWithName:AppMaruFontName() size:12.0f];
    cautionText.userInteractionEnabled = YES;
    if (isPad) {
        cautionText.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    [self.view addSubview:cautionText];

    // --- Section 2 caption: 機種変更方法 ("Device-change method") ---
    UILabel *howtoLabel = [[UILabel alloc] init];
    howtoLabel.backgroundColor = [UIColor clearColor];
    howtoLabel.textColor = labelColor;
    howtoLabel.highlightedTextColor = [UIColor whiteColor];
    howtoLabel.font = [UIFont fontWithName:AppFontName() size:15.0f];
    howtoLabel.textAlignment = NSTextAlignmentCenter;
    howtoLabel.adjustsFontSizeToFitWidth = YES;
    howtoLabel.minimumScaleFactor = 10.0f;
    howtoLabel.frame = CGRectMake(0.0f, 160.0f, 272.0f, 50.0f);
    howtoLabel.text = @"機種変更方法";
    if (!isPad) {
        CGRect f = howtoLabel.frame;   // phone origin nudge (+24,+24) — best-effort
        f.origin.x += 24.0f;
        f.origin.y += 24.0f;
        howtoLabel.frame = f;
    }
    [self.view addSubview:howtoLabel];

    // --- Section 2 body: bundled howto.txt (UTF-8), read-only ---
    UITextView *howtoText =
        [[UITextView alloc] initWithFrame:CGRectMake(vf.origin.x, vf.origin.y + 200.0f,
                                                     vf.size.width, vf.size.height)];
    NSString *howtoPath = [[NSBundle mainBundle] pathForResource:@"howto" ofType:@"txt"];
    NSString *howtoBody = [[NSString alloc]
        initWithData:[NSData dataWithContentsOfFile:howtoPath] encoding:NSUTF8StringEncoding];
    howtoText.backgroundColor = [UIColor clearColor];
    howtoText.editable = NO;
    howtoText.text = howtoBody;
    howtoText.textColor = bodyColor;
    howtoText.font = [UIFont fontWithName:AppMaruFontName() size:12.0f];
    howtoText.userInteractionEnabled = YES;
    if (isPad) {
        howtoText.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    [self.view addSubview:howtoText];

    // --- "Issue pass" button (added inside the how-to text view) ---
    UIImage *okImg = [UIImage imageNamed:@"conv_bt_yes"];
    UIButton *okButton = [[UIButton alloc] init];
    okButton.frame = CGRectMake(0.0f, 0.0f, okImg.size.width, okImg.size.height);
    [okButton setBackgroundImage:okImg forState:UIControlStateNormal];
    [okButton addTarget:self action:@selector(okButtonFunc)
       forControlEvents:UIControlEventTouchUpInside];

    const float sysVer = [UIDevice currentDevice].systemVersion.floatValue;
    if (isPad) {
        // Pad: fixed centre (y differs slightly pre/post iOS 7). Best-effort geometry.
        okButton.center = CGPointMake(136.0f, (sysVer >= 7.0f) ? 180.0f : 190.0f);
    } else if (sysVer >= 7.0f) {
        // Phone iOS 7+: centred on the how-to content, near y = 200. Best-effort.
        okButton.center = CGPointMake(howtoText.contentSize.width * 0.5f, 200.0f);
    } else {
        // Phone iOS 6: centred within the how-to content size. Best-effort.
        okButton.center = CGPointMake(howtoText.contentSize.width * 0.5f,
                                      howtoText.contentSize.height * 0.5f + 50.0f);
    }
    [howtoText addSubview:okButton];

    // --- Nav-bar back button (phone) / hide the system back button (pad) ---
    if (!isPad) {
        UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
        UIButton *backBtn = [[UIButton alloc]
            initWithFrame:CGRectMake(-10.0f, 0.0f, backImg.size.width, backImg.size.height)];
        [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
        [backBtn addTarget:self action:@selector(backButtonFunc)
          forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    } else {
        [self.navigationItem setHidesBackButton:YES];
    }
}

// didReceiveMemoryWarning @ 0x1ca9c — super-only override, omitted.
// viewDidUnload @ 0x1cac8 — super-only override, omitted.
// viewWillAppear: @ 0x1caf4 — super-only override, omitted.
// viewDidAppear: @ 0x1cb20 — super-only override, omitted.
// viewWillDisappear: @ 0x1cb4c — super-only override, omitted.
// viewDidDisappear: @ 0x1cb78 — super-only override, omitted.

// @ 0x1cba4 — portrait only.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

// @ 0x1cbb0 — back button: cancel SE, restore the settings nav-bar art, pop.
- (void)backButtonFunc {
    neEngine::playSystemSe(2);   // cancel/back SE

    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0x1cc4c — OK ("issue pass") tapped: decide SE, confirm dialog (tag 0).
- (void)okButtonFunc {
    neEngine::playSystemSe(1);   // decide/confirm SE

    CommonAlertView *alert = [[CommonAlertView alloc]
              initWithTitle:@"機種変更"
                    message:@"注意事項に同意の上、機種変更パスの発行を行いますか？\n（パス発行後は本端末のプレイデータは初期化されます）"
                   delegate:self
          cancelButtonTitle:@"キャンセル"
          otherButtonTitles:@"パス発行"];
    [alert setTag:0];
    [alert show];
}

// @ 0x1cd00 — dialog callback for both the confirm dialog (tag 0) and the
// issued-pass dialog (tag 1).
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (alertView.tag == 0) {
        // Confirm dialog: index 0 = cancel (ignore), index 1 = issue the pass.
        if (index == 0) {
            return;
        }
        [self startConversionHttp];
        return;
    }

    if (alertView.tag != 1) {
        return;
    }

    // Issued-pass dialog.
    if (index == 0) {
        // "Send mail": compose a body with the player id + issued pass and hand it
        // to MainViewController (sent to the class object — faithful, see notes).
        NSString *body = [NSString stringWithFormat:
            @"プレーヤーID:%@\n機種変更パス:%@\n\n機種変更先で必要となりますので、必ずメモをとってください。",
            [UserSettingData playerId], [UserSettingData convertCode]];
        body = [body stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [(id)[MainViewController class] GotoMailWithText:body];
    } else if (index == 1) {
        // "Initialize and go to title": wipe the local save for a fresh device and
        // re-open the collabo / invite / login-bonus / treasure music.
        [UserSettingData initForConvert];
        [[MusicManager getInstance] openCollaboMusic];
        [[MusicManager getInstance] openInviteMusic];
        [[MusicManager getInstance] openLoginBonusMusic];
        [[MusicManager getInstance] openTreasureMusic];
        [TreasureData init:[[AppDelegate appDelegate] managedObjectContext]];
    }

    // Both actions flag the title transition and close the settings overlay.
    neSceneManager::shared();
    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    root.isGotoTitle = YES;
    [self.delegate startCloseAnimation];
}

// @ 0x1cf0c — build and POST the full local save to the convert-code endpoint.
// No-op while a request is already in flight.
- (void)startConversionHttp {
    if (_downloader != nil) {
        return;
    }

    NSMutableDictionary *params = [NSMutableDictionary dictionary];

    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

    NSDate *lastUpdate = [UserSettingData lastUpdateSumPurchase];
    int spPresentFlag = 0;
    if ([UserSettingData isBemaniCollaboOpened]) {
        spPresentFlag |= 1;
    }
    if ([UserSettingData isFollowBonusGet]) {
        spPresentFlag |= 2;
    }

    if (lastUpdate != nil) {
        [params setObject:[fmt stringFromDate:lastUpdate] forKey:@"last_update_sum_purchase"];
    }
    [params setObject:[[AppDelegate appDelegate] uuId] forKey:@"uuid"];
    [params setObject:[NSNumber numberWithInt:[UserSettingData sumPurchase]] forKey:@"sum_purchase"];
    [params setObject:[NSNumber numberWithInt:[UserSettingData charaTicket]] forKey:@"chara_ticket_cnt"];
    [params setObject:[NSNumber numberWithInt:[UserSettingData treasurePoint]] forKey:@"treasure_point"];
    [params setObject:[NSNumber numberWithInt:spPresentFlag] forKey:@"sp_present_flag"];
    [params setObject:[NSNumber numberWithInt:[UserSettingData getOpenedLoginBonusId]] forKey:@"opened_login_bonus_id"];
    [params setObject:[NSNumber numberWithInt:[UserSettingData getLoginBonusCnt]] forKey:@"local_login_bonus_cnt"];

    // Owned characters: [{ idx, data }, ...]
    NSMutableArray *gotChara = [NSMutableArray array];
    NSArray *charaArray = [UserSettingData gotCharaArray];
    for (NSUInteger i = 0; i < charaArray.count; i++) {
        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        [entry setObject:[NSNumber numberWithInt:(int)i] forKey:@"idx"];
        [entry setObject:[charaArray objectAtIndex:i] forKey:@"data"];
        [gotChara addObject:entry];
    }
    [params setObject:gotChara forKey:@"got_chara"];

    // Per-music scores.
    NSMutableArray *musicArray = [NSMutableArray array];
    NSArray *scores = [ScoreData getAllScoreData:[[AppDelegate appDelegate] managedObjectContext]];
    for (NSUInteger i = 0; i < scores.count; i++) {
        ScoreData *s = [scores objectAtIndex:i];
        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        [entry setObject:s.musicId forKey:@"id"];
        [entry setObject:s.playCntN forKey:@"play_cnt_n"];
        [entry setObject:s.playCntH forKey:@"play_cnt_h"];
        [entry setObject:s.playCntEx forKey:@"play_cnt_ex"];
        [entry setObject:s.fullComboN forKey:@"full_combo_n"];
        [entry setObject:s.fullComboH forKey:@"full_combo_h"];
        [entry setObject:s.fullComboEx forKey:@"full_combo_ex"];
        [entry setObject:s.perfectN forKey:@"perfect_n"];
        [entry setObject:s.perfectH forKey:@"perfect_h"];
        [entry setObject:s.perfectEx forKey:@"perfect_ex"];
        [entry setObject:s.scoreN forKey:@"score_n"];
        [entry setObject:s.scoreH forKey:@"score_h"];
        [entry setObject:s.scoreEx forKey:@"score_ex"];
        [musicArray addObject:entry];
    }
    [params setObject:musicArray forKey:@"music"];

    // Treasure (map) progress.
    NSMutableArray *treasureArray = [NSMutableArray array];
    NSArray *treasures = [TreasureData getAllTreasureData:[[AppDelegate appDelegate] managedObjectContext]];
    for (NSUInteger i = 0; i < treasures.count; i++) {
        TreasureData *t = [treasures objectAtIndex:i];
        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        [entry setObject:t.mainMapId forKey:@"main_map_id"];
        [entry setObject:t.subMapId forKey:@"sub_map_id"];
        [entry setObject:t.musicPiece forKey:@"music_piece"];
        [entry setObject:t.wallPaperPiece forKey:@"wall_paper_piece"];
        [entry setObject:t.clearCnt forKey:@"clear_cnt"];
        [entry setObject:t.friendMeetCnt forKey:@"friend_meet_cnt"];
        [entry setObject:t.fastRecord forKey:@"fast_record"];
        [entry setObject:t.goalCharaTicket forKey:@"chara_ticket"];
        [entry setObject:t.goalTouchSound forKey:@"touch_sound"];
        [treasureArray addObject:entry];
    }
    [params setObject:treasureArray forKey:@"treasure"];

    // Purchased chara tickets.
    NSMutableArray *ticketArray = [NSMutableArray array];
    NSArray *tickets = [CharaTicketData getAllData:[[AppDelegate appDelegate] managedObjectContext]];
    for (NSUInteger i = 0; i < tickets.count; i++) {
        CharaTicketData *c = [tickets objectAtIndex:i];
        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        [entry setObject:c.productId forKey:@"product_id"];
        [ticketArray addObject:entry];
    }
    [params setObject:ticketArray forKey:@"chara_ticket"];

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params
                                                      options:NSJSONWritingPrettyPrinted
                                                        error:&jsonError];
    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *body = [NSString stringWithFormat:@"param=%@", jsonStr];

    if (jsonError == nil) {
        NSLog(@"json=%@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
        _downloader = [[Downloader alloc]
                          initWithURL:[StoreUtil getConvertCodeURL]
                             delegate:self
                                 Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                          ContextType:@"application/json"];
        [_downloader startDownloading];
    } else {
        NSLog(@"%@", jsonError);
    }
}

// @ 0x1da60 — POST succeeded: parse the JSON, show the issued pass (or an error).
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    id errorCode = [json objectForKey:@"ErrorCode"];
    [_indicator stopAnimating];

    CommonAlertView *alert;
    if (errorCode == nil) {
        int code = [[json objectForKey:@"ConvertCode"] intValue];
        NSString *codeStr = [NSString stringWithFormat:@"%06d", code];
        _convertCodeStr = codeStr;
        [UserSettingData saveConvertCode:codeStr];

        NSString *message = [NSString stringWithFormat:
            @"プレーヤーID:%@\n機種変更パス:%@\n\n機種変更先で必要となりますので、必ずメモをとってください。",
            [UserSettingData playerId], _convertCodeStr];
        alert = [[CommonAlertView alloc] initWithTitle:@"機種変更"
                                               message:message
                                              delegate:self
                                     cancelButtonTitle:@"メール送信"
                                     otherButtonTitles:@"初期化してタイトルへ"];
        [alert setTag:1];
    } else {
        alert = [[CommonAlertView alloc] initWithTitle:@"機種変更"
                                               message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
                                              delegate:nil
                                     cancelButtonTitle:nil
                                     otherButtonTitles:@"OK"];
    }
    [alert show];

    _downloader = nil;
}

// @ 0x1dc84 — POST failed: drop the request and show the network-error alert.
- (void)downloaderError:(Downloader *)downloader {
    _downloader = nil;
    [_indicator stopAnimating];

    CommonAlertView *alert = [[CommonAlertView alloc]
              initWithTitle:@"機種変更"
                    message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
                   delegate:nil
          cancelButtonTitle:nil
          otherButtonTitles:@"OK"];
    [alert show];
}

// @ 0x1dd50 — fade the panel out over 0.3s; endCloseAnimation fires when it stops.
- (void)startCloseAnimation {
    if (isAnimationing) {
        return;
    }
    isAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0.0f;
    [UIView commitAnimations];
}

// @ 0x1de20 — close fade finished: tear down and notify the root view controller.
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    neSceneManager::shared();
    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    [root AcceptPolicyEndCallBack];
    isAnimationing = NO;
}

@end
