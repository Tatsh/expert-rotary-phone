//
//  InputConversionPassViewController.mm
//  pop'n rhythmin
//
//  See InputConversionPassViewController.h. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin. Objective-C++ for the neEngine / neSceneManager singletons
//  (system SE, pad-vs-phone layout, root-VC overlay + end callback). ARC.
//
//  Honesty notes:
//   - -init builds a lot of sub-view frames from a heavily NEON-spilled vector
//     sequence. The image names, text-field configuration, view hierarchy, the
//     tap-to-dismiss cover view (pad) and the button/indicator styling are byte-exact;
//     the per-device centre offsets (phone id/pass board y = 10 / 120, decide y = 260;
//     pad y-nudges -80 / +50 / +145 around the screen centre) are exact float decodes,
//     but the exact origin of each board is reconstructed structurally (horizontally
//     centred on the screen, fields centred on their board image) and flagged inline.
//   - Faithful oddity: -init never adds _indicator as a subview (it is fully configured
//     then left detached); -startConversionHttpWithId:pass: still sends it -startAnimating.
//     Preserved exactly (cf. ConversionView, whose spinner is likewise container-driven).
//   - All CommonAlertView strings are exact UTF-16 CFString decodes; the ASCII CFStrings
//     ("friman_bg", "conv_board*", "inputname_*", "%d", the POST body template
//     "uuid=%@&player_id=%@&convert_code=%@", "application/json", "yyyy-MM-dd HH:mm:ss",
//     and every JSON dictionary key) are exact.
//   - The success/error CommonAlertViews are alloc/init/show/release in the binary (they
//     retain themselves by adding to the root scene view in -show); ARC keeps the alloc,
//     drops the manual release. On success the success alert's delegate is self, so its
//     OK tap drives -startCloseAnimation; -downloaderFinished: does NOT clear _downloader
//     on success (only the ErrorCode branch does) — preserved faithfully.
//   - dealloc @ 0x92064 only releases _downloader (no -cancel, no observer removal); under
//     ARC that release is automatic, so dealloc is ARC-omitted.
//   - -endCloseAnimation manually -releases _idField / _passField / _indicator in the
//     binary; under ARC those ivars are owned by the (about-to-be-released) controller,
//     so the manual releases are stripped (no added behaviour to preserve).
//   - scoreToRank() and neSugorokuTouchSoundBit() are file-local statics in the binary
//     (each its own FUN_*, inlined per translation unit — cf. PlayScene.mm /
//     FriendScoreTableCell.mm / UserSettingData.mm); mirrored here as file-local statics.
//

#import "InputConversionPassViewController.h"

#import "ScoreData.h"
#import "ScoreData+Store.h"       // +getScoreData:inManagedObjectContext: / +hashScore:
#import "TreasureData.h"          // +init:
#import "TreasureData+Store.h"    // +addRecordWithMainMapId:subMapId:inManagedObjectContext:
#import "CharaTicketData.h"       // +addRecordWithProductId:inManagedObjectContext:
#import "MusicManager.h"          // +getInstance -> open*Music

#import "AppDelegate.h"           // +appDelegate -> uuId / managedObjectContext
#import "DownloadMain.h"          // Downloader-based download manager (shared helper)
#import "StoreUtil.h"             // +convertURL
#import "UserSettingData.h"       // player-save accessors + initForConvert
#import "MainViewController.h"    // -InConversionPassEndCallBack (root callback)

#import <QuartzCore/QuartzCore.h> // CALayer cornerRadius on the indicator
#import "neEngineBridge.h"        // neEngine::playSystemSe, neSceneManager::rootViewController / isPadDisplay

// Score -> rank index (0 best .. 6 worst). Ghidra: FUN_00028a40 (scoreToRank).
static int scoreToRank(int score) {
    if (score >= 100000) return 0;
    if (score >= 98000)  return 1;
    if (score >= 95000)  return 2;
    if (score >= 90000)  return 3;
    if (score >= 80000)  return 4;
    if (score >= 70000)  return 5;
    return 6;
}

// Sugoroku (treasure-map) main-map id -> touch-sound bit index (0 for out-of-range).
// Ghidra: neSugorokuTouchSoundBit (matches UserSettingData.mm's file-local copy).
static int neSugorokuTouchSoundBit(int mainMapId) {
    static const int kBits[9] = { 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    unsigned id = (unsigned)mainMapId & 0xffff;
    return id < 9 ? kBits[id] : 0;
}

// Own privates (selectors wired up by init / used across the download flow).
@interface InputConversionPassViewController ()
- (void)onBackBtn;
- (void)endOpenAnimation;
- (void)startCloseAnimation;
- (void)endCloseAnimation;
- (void)touchedDecideButton:(id)sender;
- (void)handleTapCoverView;
- (void)startConversionHttpWithId:(NSString *)playerId pass:(NSString *)pass;
- (BOOL)checkUsableCharacterForId:(NSString *)str;
- (BOOL)checkUsableCharacterForPass:(NSString *)str;
@end

@implementation InputConversionPassViewController

// @ 0x911d0 — build the input panel: (pad) a tap-to-dismiss dimmed cover, the board
// backdrop, the id / pass boards each holding a centred text field, the decide button,
// and the (detached) activity indicator.
- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    const CGRect frame = self.view ? self.view.frame : CGRectZero;
    const bool isPad = neSceneManager::isPadDisplay();

    // --- Pad: dimmed, tap-to-dismiss cover over the whole screen ---
    if (isPad) {
        _coverView = [[UIView alloc] initWithFrame:frame];
        _coverView.opaque = NO;
        _coverView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
        _coverView.userInteractionEnabled = YES;
        _coverView.exclusiveTouch = YES;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapCoverView)];
        [_coverView addGestureRecognizer:tap];
        [self.view addSubview:_coverView];
    }

    // --- Backdrop: phone uses the full-window art; pad uses a centred board + dim ---
    if (!isPad) {
        UIImageView *bg = [[UIImageView alloc] initWithFrame:frame];
        bg.image = [UIImage imageNamed:@"friman_bg"];
        [self.view addSubview:bg];
    } else {
        UIImage *boardImg = [UIImage imageNamed:@"conv_board"];
        UIImageView *board =
            [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, boardImg.size.width, boardImg.size.height)];
        board.image = boardImg;
        board.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f);
        self.view.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
        [self.view addSubview:board];
    }

    // --- Player-id board (holds _idField) ---
    UIImage *nameImg = [UIImage imageNamed:@"conv_board_name"];
    UIImageView *nameView = [[UIImageView alloc] initWithImage:nameImg];
    nameView.userInteractionEnabled = YES;
    if (!isPad) {
        nameView.frame = CGRectMake(0, 10.0f, nameImg.size.width, nameImg.size.height);
        nameView.center = CGPointMake(frame.size.width * 0.5f, nameView.center.y);  // x = runtime-structural (vmul.f32 with 0.5)
    } else {
        nameView.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f - 80.0f);
    }
    [self.view addSubview:nameView];

    _idField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 206.0f, 38.0f)];
    _idField.enabled = YES;
    _idField.returnKeyType = UIReturnKeyDone;                                  // 9
    _idField.delegate = self;
    _idField.keyboardType = UIKeyboardTypeASCIICapable;                        // 1
    _idField.autocapitalizationType = UITextAutocapitalizationTypeNone;        // 0
    _idField.autocorrectionType = UITextAutocorrectionTypeNo;                  // 1
    _idField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter; // 0
    [_idField setBackground:[UIImage imageNamed:@"inputname_area_name"]];
    _idField.textAlignment = NSTextAlignmentCenter;                            // 1
    _idField.center = CGPointMake(nameImg.size.width * 0.5f, 75.0f);
    [nameView addSubview:_idField];

    // --- Convert-pass board (holds _passField) ---
    UIImage *passImg = [UIImage imageNamed:@"conv_board_pass"];
    UIImageView *passView = [[UIImageView alloc] initWithImage:passImg];
    passView.userInteractionEnabled = YES;
    if (!isPad) {
        passView.frame = CGRectMake(0, 120.0f, passImg.size.width, passImg.size.height);
        passView.center = CGPointMake(frame.size.width * 0.5f, passView.center.y);  // x = runtime-structural (vmul.f32 with 0.5)
    } else {
        passView.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f + 50.0f);
    }
    [self.view addSubview:passView];

    _passField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 206.0f, 38.0f)];
    _passField.enabled = YES;
    _passField.returnKeyType = UIReturnKeyDone;                                // 9
    _passField.delegate = self;
    _passField.keyboardType = UIKeyboardTypeASCIICapable;                      // 1
    _passField.autocapitalizationType = UITextAutocapitalizationTypeNone;      // 0
    _passField.autocorrectionType = UITextAutocorrectionTypeNo;                // 1
    _passField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter; // 0
    [_passField setBackground:[UIImage imageNamed:@"conv_inputarea_pass"]];
    _passField.textAlignment = NSTextAlignmentCenter;                          // 1
    _passField.center = CGPointMake(passImg.size.width * 0.5f, 75.0f);
    [passView addSubview:_passField];

    // --- Decide (submit) button ---
    UIButton *decideBtn = [[UIButton alloc] init];
    UIImage *decideImg = [UIImage imageNamed:@"inputname_btn_deside"];
    [decideBtn setBackgroundImage:decideImg forState:UIControlStateNormal];
    decideBtn.frame = CGRectMake(0, 0, decideImg.size.width, decideImg.size.height);
    if (!isPad) {
        decideBtn.center = CGPointMake(frame.size.width * 0.5f, 260.0f);
    } else {
        decideBtn.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f + 145.0f);
    }
    [decideBtn addTarget:self action:@selector(touchedDecideButton:)
        forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:decideBtn];

    // --- Activity indicator (configured but, faithfully, left detached; see notes) ---
    _indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];     // 1
    _indicator.frame = CGRectMake(0, 0, 32.0f, 32.0f);
    _indicator.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f);
    _indicator.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;  // 0x21
    _indicator.hidesWhenStopped = YES;
    _indicator.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
    _indicator.layer.cornerRadius = 4.0f;

    return self;
}

// @ 0x91e84 — phone entry point: wrap self in a nav controller with a custom back
// button and the convert nav-bar art, and return that host.
- (UINavigationController *)initAtNavigationController __attribute__((objc_method_family(none))) {
    InputConversionPassViewController *content = [self init];
    if (content == nil) {
        return nil;
    }

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:content];

    UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
    UIButton *backBtn =
        [[UIButton alloc] initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
    [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
    [backBtn addTarget:content action:@selector(onBackBtn)
      forControlEvents:UIControlEventTouchUpInside];
    content.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:backBtn];

    [content.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"conv_navbar"]
             forBarMetrics:UIBarMetricsDefault];

    return nav;
}

// dealloc @ 0x92064 — releases _downloader only (no -cancel / no observers); ARC-omitted.

// @ 0x920b4 — nav-bar back button: play the cancel SE and run the close fade.
- (void)onBackBtn {
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

// @ 0x920e8 — fade the panel (and its embedded nav view) in over 0.3 s.
- (void)startOpenAnimation {
    if (m_IsAnimationing) {
        return;
    }
    m_IsAnimationing = YES;
    self.view.alpha = 0.0f;
    self.navigationController.view.alpha = 0.0f;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    self.navigationController.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0x92220
- (void)endOpenAnimation {
    m_IsAnimationing = NO;
}

// @ 0x92238 — fade the panel out over 0.3 s (suspending root input for the transition).
- (void)startCloseAnimation {
    if (m_IsAnimationing) {
        return;
    }
    m_IsAnimationing = YES;
    neSceneManager::rootViewController().view.userInteractionEnabled = NO;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0.0f;
    self.navigationController.view.alpha = 0.0f;
    [UIView commitAnimations];
}

// @ 0x92368 — close fade finished: tear down and notify the root view controller.
// (The binary also -releases _idField / _passField / _indicator here; ARC-stripped.)
- (void)endCloseAnimation {
    [self.view removeFromSuperview];
    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    [root InConversionPassEndCallBack];
    m_IsAnimationing = NO;
}

// didReceiveMemoryWarning @ 0x9240c — super-only override, omitted.
// viewDidLoad @ 0x92438 — super-only override, omitted.
// viewDidUnload @ 0x92464 — super-only override, omitted.
// viewWillAppear: @ 0x92490 — super-only override, omitted.
// viewDidAppear: @ 0x924bc — super-only override, omitted.
// viewWillDisappear: @ 0x924e8 — super-only override, omitted.
// viewDidDisappear: @ 0x92514 — super-only override, omitted.

// @ 0x92540 — portrait only.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

// @ 0x9254c
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    return YES;
}

// @ 0x92550 — Done/return dismisses the keyboard on whichever field is active.
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (_idField == textField) {
        [textField resignFirstResponder];
    }
    if (_passField == textField) {
        [textField resignFirstResponder];
    }
    return YES;
}

// @ 0x925a4 — decide tapped: if both fields are non-empty, dismiss the keyboards, POST
// the convert request, and play the decide SE.
- (void)touchedDecideButton:(id)sender {
    NSString *playerId = _idField.text;
    NSString *pass = _passField.text;
    if (playerId.length != 0 && pass.length != 0) {
        [_idField resignFirstResponder];
        [_passField resignFirstResponder];
        [self startConversionHttpWithId:playerId pass:pass];
        neEngine::playSystemSe(1);
    }
}

// @ 0x92664 — length-limit the two fields (id: max 7 chars, pass: max 6 chars).
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    if ((_idField == textField && string.length + range.location + range.length < 8) ||
        (_passField == textField && string.length + range.location + range.length < 7)) {
        return YES;
    }
    return NO;
}

// @ 0x926e0 — POST succeeded: on no ErrorCode, restore the entire server-side save into
// UserSettingData + the Core Data stores and show the "done" alert; otherwise show the
// id/pass-mismatch alert and drop the request.
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [_downloader getDataInJSON];
    id errorCode = [json objectForKey:@"ErrorCode"];
    [_indicator stopAnimating];

    if (errorCode == nil) {
        NSString *playerName = [json objectForKey:@"PlayerName"];
        NSString *playerId = [json objectForKey:@"PlayerId"];
        int charaId = [[json objectForKey:@"CharaId"] intValue];
        int isInvited = [[json objectForKey:@"IsInvited"] intValue];
        int inviteCnt = [[json objectForKey:@"InviteCnt"] intValue];
        int sumPurchase = [[json objectForKey:@"SumPurchase"] intValue];
        int charaTicketCnt = [[json objectForKey:@"CharaTicketCnt"] intValue];
        int treasurePoint = [[json objectForKey:@"TreasurePoint"] intValue];
        int spPresentFlag = [[json objectForKey:@"SpPresentFlag"] intValue];
        int openedLoginBonusId = [[json objectForKey:@"OpenedLoginBonusId"] intValue];
        int localLoginBonusCnt = [[json objectForKey:@"LocalLoginBonusCnt"] intValue];
        int lastAnswerQuizId = [[json objectForKey:@"LastAnswerQuizId"] intValue];
        int totalCorrectQuiz = [[json objectForKey:@"TotalCorrectQuiz"] intValue];
        int totalInCorrectQuiz = [[json objectForKey:@"TotalInCorrectQuiz"] intValue];
        int consecutiveCorrectQuiz = [[json objectForKey:@"ConsecutiveCorrectQuiz"] intValue];
        id lastUpdateSumPurchase = [json objectForKey:@"LastUpdateSumPurchase"];

        // Owned characters: each {Idx, Data} entry expands Data's set bits into ids
        // (Idx*32 + bit).
        NSMutableArray *gotCharaList = [NSMutableArray array];
        NSArray *gotChara = [json objectForKey:@"GotChara"];
        for (id entry in gotChara) {
            int idx = [[entry objectForKey:@"Idx"] intValue];
            int data = [[entry objectForKey:@"Data"] intValue];
            for (int bit = 0; bit < 32; bit++) {
                if (data & (1 << bit)) {
                    [gotCharaList addObject:[NSNumber numberWithInt:idx * 32 + bit]];
                }
            }
        }

        NSArray *music = [json objectForKey:@"Music"];
        NSMutableArray *playCnt = [[json objectForKey:@"PlayCnt"] mutableCopy];
        NSArray *treasure = [json objectForKey:@"Treasure"];

        // Aggregate the "have touch sound" bitmask from the treasure rows.
        int touchSoundFlg = 0;
        for (id t in treasure) {
            int mainMapId = [[t objectForKey:@"MainMapId"] intValue];
            int touchSound = [[t objectForKey:@"TouchSound"] intValue];
            if (touchSound != 0) {
                touchSoundFlg |= 1 << neSugorokuTouchSoundBit((short)mainMapId);
            }
        }

        NSArray *packCharaTicket = [json objectForKey:@"PackCharaTicket"];

        // Invite-present tier from the invite count.
        int invitePresent;
        if (inviteCnt < 3)      invitePresent = 0;
        else if (inviteCnt < 5) invitePresent = 3;
        else if (inviteCnt < 7) invitePresent = 5;
        else                    invitePresent = 7;

        // Reset the local save, then write the restored player state.
        [UserSettingData initForConvert];
        [UserSettingData savePlayerName:playerName];
        [UserSettingData savePlayerId:playerId];
        [UserSettingData saveHaveTouchSoundFlg:touchSoundFlg];
        [UserSettingData saveSumPurchase:sumPurchase];
        [UserSettingData saveIsInputInviteCode:(BOOL)isInvited];
        [UserSettingData saveInvitePresent:invitePresent];
        [UserSettingData saveInviteCnt:inviteCnt];
        [UserSettingData saveCharaId:(short)charaId];
        [UserSettingData saveCharaIdServer:(short)charaId];
        [UserSettingData saveCharaTicket:(short)charaTicketCnt];
        [UserSettingData saveTreasurePoint:(short)treasurePoint];
        [UserSettingData saveLastAnswerQuizId:lastAnswerQuizId];
        [UserSettingData saveTotalCorrectQuiz:totalCorrectQuiz];
        [UserSettingData saveTotalInCorrectQuiz:totalInCorrectQuiz];
        [UserSettingData saveConsecutiveQuiz:consecutiveCorrectQuiz];
        [UserSettingData saveOpenedLoginBonusId:openedLoginBonusId];
        [UserSettingData saveLoginBonusCnt:localLoginBonusCnt];

        if (lastUpdateSumPurchase != nil) {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            [fmt setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            [UserSettingData saveLastUpdateSumPurchase:[fmt dateFromString:lastUpdateSumPurchase]];
        }

        for (NSNumber *n in gotCharaList) {
            [UserSettingData saveGotCharaArray:[n shortValue]];
        }

        if (spPresentFlag & 1) {
            [UserSettingData saveIsBemaniCollaboOpened:YES];
            [[MusicManager getInstance] openCollaboMusic];
        }
        if (spPresentFlag & 2) {
            [UserSettingData saveIsFollowBonusGet:YES];
        }

        NSManagedObjectContext *context = [[AppDelegate appDelegate] managedObjectContext];

        // Per-music scores: match each Music entry to its PlayCnt row (by Id) and write
        // the ScoreData record (full-combo / perfect flags, rank+score per difficulty,
        // hashed checksum, last-play date, play counts).
        for (id m in music) {
            int mid = [[m objectForKey:@"Id"] intValue];
            int scoreN = [[m objectForKey:@"ScoreN"] intValue];
            int scoreH = [[m objectForKey:@"ScoreH"] intValue];
            int scoreEx = [[m objectForKey:@"ScoreEx"] intValue];
            int flag = [[m objectForKey:@"Flag"] intValue];

            for (id pc in playCnt) {
                if ([[pc objectForKey:@"Id"] intValue] == mid) {
                    int cntN = [[pc objectForKey:@"CntN"] intValue];
                    int cntH = [[pc objectForKey:@"CntH"] intValue];
                    int cntEx = [[pc objectForKey:@"CntEx"] intValue];

                    ScoreData *sd = [ScoreData getScoreData:mid inManagedObjectContext:context];
                    if (flag & 0x01) sd.fullComboN = [NSNumber numberWithBool:YES];
                    if (flag & 0x02) sd.fullComboH = [NSNumber numberWithBool:YES];
                    if (flag & 0x04) sd.fullComboEx = [NSNumber numberWithBool:YES];
                    if (flag & 0x08) sd.perfectN = [NSNumber numberWithBool:YES];
                    if (flag & 0x10) sd.perfectH = [NSNumber numberWithBool:YES];
                    if (flag & 0x20) sd.perfectEx = [NSNumber numberWithBool:YES];
                    if (scoreN >= 0) {
                        sd.rankN = [NSNumber numberWithInt:scoreToRank(scoreN)];
                        sd.scoreN = [NSNumber numberWithInt:scoreN];
                    }
                    if (scoreH >= 0) {
                        sd.rankH = [NSNumber numberWithInt:scoreToRank(scoreH)];
                        sd.scoreH = [NSNumber numberWithInt:scoreH];
                    }
                    if (scoreEx >= 0) {
                        sd.rankEx = [NSNumber numberWithInt:scoreToRank(scoreEx)];
                        sd.scoreEx = [NSNumber numberWithInt:scoreEx];
                    }
                    sd.chksco = [ScoreData hashScore:sd];
                    sd.lastPlayDate = [NSDate date];
                    sd.playCntN = [NSNumber numberWithInt:cntN];
                    sd.playCntH = [NSNumber numberWithInt:cntH];
                    sd.playCntEx = [NSNumber numberWithInt:cntEx];
                    [playCnt removeObject:pc];
                    break;
                }
            }
            [context save:nil];
        }

        // Treasure (map) progress: one TreasureData row per Treasure entry.
        for (id t in treasure) {
            int mainMapId = [[t objectForKey:@"MainMapId"] intValue];
            int subMapId = [[t objectForKey:@"SubMapId"] intValue];
            int musicPiece = [[t objectForKey:@"MusicPiece"] intValue];
            int wallPiece = [[t objectForKey:@"WallPiece"] intValue];
            int clearCnt = [[t objectForKey:@"ClearCnt"] intValue];
            int friendMeetCnt = [[t objectForKey:@"FriendMeetCnt"] intValue];
            int fastRecord = [[t objectForKey:@"FastRecord"] intValue];
            int charaTicket = [[t objectForKey:@"CharaTicket"] intValue];
            int touchSound = [[t objectForKey:@"TouchSound"] intValue];

            TreasureData *td = [TreasureData addRecordWithMainMapId:(short)mainMapId
                                                          subMapId:(short)subMapId
                                            inManagedObjectContext:context];
            td.musicPiece = [NSNumber numberWithInt:musicPiece];
            td.wallPaperPiece = [NSNumber numberWithInt:wallPiece];
            td.goalCharaTicket = [NSNumber numberWithInt:charaTicket];
            td.goalTouchSound = [NSNumber numberWithInt:touchSound];
            td.clearCnt = [NSNumber numberWithInt:clearCnt];
            td.fastRecord = [NSNumber numberWithInt:fastRecord];
            td.friendMeetCnt = [NSNumber numberWithInt:friendMeetCnt];
            [context save:nil];
        }

        // Purchased chara tickets.
        for (id p in packCharaTicket) {
            [CharaTicketData addRecordWithProductId:[p objectForKey:@"ProductId"]
                             inManagedObjectContext:context];
            [context save:nil];
        }

        // Re-open the event / login-bonus / treasure music and rebuild treasure roots.
        [[MusicManager getInstance] openInviteMusic];
        [[MusicManager getInstance] openLoginBonusMusic];
        [[MusicManager getInstance] openTreasureMusic];
        [TreasureData init:[[AppDelegate appDelegate] managedObjectContext]];

        CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"機種変更"
                                                               message:@"処理が完了しました。"
                                                              delegate:self
                                                     cancelButtonTitle:nil
                                                     otherButtonTitles:@"OK"];
        [alert show];
        // _downloader is intentionally left set on success (see notes).
    } else {
        CommonAlertView *alert = [[CommonAlertView alloc]
                  initWithTitle:@"機種変更"
                        message:@"通信に失敗しました。\nプレーヤーIDと機種変更パスを確認してください。"
                       delegate:nil
              cancelButtonTitle:nil
              otherButtonTitles:@"OK"];
        [alert show];
        _downloader = nil;
    }
}

// @ 0x93938 — POST failed: drop the request and show the network-error alert.
- (void)downloaderError:(Downloader *)downloader {
    [_indicator stopAnimating];
    _downloader = nil;

    CommonAlertView *alert = [[CommonAlertView alloc]
              initWithTitle:@"プレーヤーネーム"
                    message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
                   delegate:nil
          cancelButtonTitle:nil
          otherButtonTitles:@"OK"];
    [alert show];
}

// @ 0x93a00 — build and POST {uuid, player_id, convert_code} to the convert endpoint.
// No-op while a request is already in flight; validates the two fields first.
- (void)startConversionHttpWithId:(NSString *)playerId pass:(NSString *)pass {
    if (_downloader != nil) {
        return;
    }

    BOOL idOk = [self checkUsableCharacterForId:playerId];
    BOOL passOk = [self checkUsableCharacterForPass:pass];

    if (!idOk || !passOk) {
        // Name whichever field holds the bad character (pass is checked first).
        NSString *title = passOk ? @"プレーヤーID" : @"機種変更パス";
        CommonAlertView *alert = [[CommonAlertView alloc]
                  initWithTitle:title
                        message:@"使用できない文字が含まれています。"
                       delegate:nil
              cancelButtonTitle:nil
              otherButtonTitles:@"OK"];
        [alert show];
        return;
    }

    NSString *code = [NSString stringWithFormat:@"%d", [pass intValue]];
    NSString *body = [NSString stringWithFormat:@"uuid=%@&player_id=%@&convert_code=%@",
                      [[AppDelegate appDelegate] uuId], playerId, code];

    _downloader = [[Downloader alloc]
                      initWithURL:[StoreUtil convertURL]
                         delegate:self
                             Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                      ContextType:@"application/json"];
    [_downloader startDownloading];
    [_indicator startAnimating];
}

// @ 0x93c38 — YES when every character of the id is alphanumeric (a-z A-Z 0-9).
- (BOOL)checkUsableCharacterForId:(NSString *)str {
    NSMutableCharacterSet *set = [[NSMutableCharacterSet alloc] init];
    [set addCharactersInString:@"abcdefghijklmnopqrstuvwxyz"];
    [set addCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    [set addCharactersInString:@"0123456789"];
    return [str stringByTrimmingCharactersInSet:set].length == 0;
}

// @ 0x93cf0 — YES when every character of the pass is a digit (0-9).
- (BOOL)checkUsableCharacterForPass:(NSString *)str {
    NSMutableCharacterSet *set = [[NSMutableCharacterSet alloc] init];
    [set addCharactersInString:@"0123456789"];
    return [str stringByTrimmingCharactersInSet:set].length == 0;
}

// @ 0x93d80 — any alert dismissal runs the close fade.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    [self startCloseAnimation];
}

// @ 0x93d90 — pad cover tap: play the cancel SE and run the close fade (unless a fade
// is already running).
- (void)handleTapCoverView {
    if (m_IsAnimationing) {
        return;
    }
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
