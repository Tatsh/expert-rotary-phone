//
//  FreeRequestDetail.mm
//  pop'n rhythmin
//
//  See FreeRequestDetail.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin:
//    initWithFrame:friendData:            @ 0xe3170
//    addCntNum:sheet:y:view:              @ 0xe40ac
//    dealloc                              @ 0xe4278  (Ghidra spells it
//    "deallc") startOpenAnimation                   @ 0xe42f8 endOpenAnimation
//    @ 0xe43d0 startCloseAnimation                  @ 0xe43e8 endCloseAnimation
//    @ 0xe44a8 downloaderFinished:                  @ 0xe44e0
//    downloaderProceed:                   @ 0xe46a0
//    downloaderError:                     @ 0xe46a4
//    commonAlertView:clickedButtonAtIndex:@ 0xe476c
//    startRequestFriendHttp               @ 0xe477c
//    touchedCancel                        @ 0xe490c
//    touchesEnded:withEvent:              @ 0xe493c
//    isAnimationing                       @ 0xe4994
//    isEnabled                            @ 0xe49ac
//  Objective-C++ for the C++ neSceneManager / neEngine singletons. ARC.
//
//  Honesty notes:
//   - Asset names, tags, fonts, colors, texts, animation durations (0.3s,
//   DAT_000e43c8 /
//     DAT_000e44a0), the dim alpha (0.3), the per-difficulty count-sheet
//     layout, the Downloader wiring, and the alert strings are exact (CFString
//     / DAT decodes). The card's *sub-view frames* are reconstructed from
//     heavily float-vector'd decompiler output and are best-effort: the
//     DAT_000e39xx constants they use are decoded
//     (151/368/36/72/176/60/80/212/-80/81 pt) but the exact origin/size
//     arithmetic per label — including the pad-only re-centering passes — could
//     not be recovered cleanly, so a few label frames below are approximate.
//     Structure and behaviour are faithful.
//   - _scaleForPad is 1.0 on phone / 2.0 on pad (DAT_000e40a0 / DAT_000e40a4);
//   button and
//     digit-image frames are multiplied by it.
//   - friendData wraps a FriendListData (DownloadMain.h): playerId / name /
//   charaId and the
//     rank[3][7] + perfect[3] + fullComboOnly[3] tallies drive the count sheet.
//     Its NSString fields are __unsafe_unretained; this overlay only reads them
//     (the owning list holds the array), so no retain/release is issued (ARC).
//   - -downloaderFinished: mirrors the binary's ErrorCode switch exactly; the
//   code->message
//     mapping was verified from the tbb jump table (codes 0/1/2/7 -> the
//     generic retry message, 3/4/5/6/8/9 -> specific messages, a nil JSON body
//     -> the success message). Re-read this pass @ 0xe4586: entries 0/1/2/7
//     share one target; 3/4/5/6/8/9 are distinct.
//   - The friend request POSTs "uuid=%@&player_id=%@&message=%@" (message
//   empty) to
//     +[StoreUtil requestFriendURL], Content-Type "application/json", body
//     UTF-8.
//   - Label 3 (Ghidra cf__, a short JP static string) could not be decoded;
//   @"さん" is a
//     best-effort placeholder flagged NOTE(unverified) below.
//

#import "FreeRequestDetail.h"

#import "AppDelegate.h"    // +appDelegate.uuId, +appAppSupportDirectory
#import "AppFont.h"        // AppFontName() == Ghidra getFontNameDFSoGei()
#import "DownloadMain.h"   // FriendListData struct + @encode
#import "StoreUtil.h"      // +requestFriendURL
#import "neEngineBridge.h" // neSceneManager::isPadDisplay, neEngine::playSystemSe

@interface FreeRequestDetail ()
- (void)addCntNum:(int)count sheet:(int)sheet y:(int)y view:(UIView *)view;
- (void)startCloseAnimation;
- (void)startRequestFriendHttp;
- (void)touchedCancel;
@end

@implementation FreeRequestDetail {
    UIView *_dummyView;      // dimmed spinner overlay shown while a request runs
    NSValue *_friendData;    // NSValue-wrapped FriendListData for this row
    BOOL _isAnimationing;    // open/close animation in flight
    BOOL _isEnabled;         // overlay on screen + interactive
    Downloader *_downloader; // in-flight friend-request POST
    float _scaleForPad;      // 1.0 phone / 2.0 pad
}

// @ 0xe3170 — build the confirm card from the tapped row's FriendListData.
//
// Verified against the disassembly: backgroundColor black alpha 0.3
// (0x3e99999a); _scaleForPad 2.0 (pad) / 1.0 (phone); "frilis_window" tag 400
// (0x190); request/cancel buttons only when fd.playerId is non-nil, at
// (151, 368) and (36, 368) scaled, wired to -startRequestFriendHttp /
// -touchedCancel; charaId clamped to >= 0 and the > 29 bundled/downloaded split
// (phone "sgc_icon_%03d.png", pad "sugo_chara_%03d.png"); the count sheet runs
// grade 0..3 x diff 0..2 at y = 0x95 + grade*0x23, then Perfect at y = 0x121 and
// FullCombo at y = 0x143. The per-label sub-view frame arithmetic is now derived
// from the disassembly: the name label frame is (72, 30, 176, 24) * scale, and
// the id / caption labels measure their text then lay out horizontally centred on
// 212 with the top at y = 60 (id) / y = 81 (caption), scaling the whole frame;
// the CGRect argument order (x = r2, y = r3, width = sp[0], height = sp[4]) was
// cross-checked against the immediate-encoded chara / button frames in the same
// method.
- (instancetype)initWithFrame:(CGRect)frame friendData:(NSValue *)friendData {
    if ((self = [super initWithFrame:frame])) {
        _friendData = friendData;

        FriendListData fd;
        [friendData getValue:&fd];

        self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3f]; // 0x3e99999a

        BOOL isPad = neSceneManager::isPadDisplay();
        _scaleForPad = isPad ? 2.0f : 1.0f; // DAT_000e40a4 / DAT_000e40a0

        // "frilis_window" card, centred, tag 400 (its own touches are ignored — see
        // touchesEnded:withEvent:).
        UIImage *windowImg = [UIImage imageNamed:@"frilis_window"];
        UIImageView *window = [[UIImageView alloc]
            initWithFrame:CGRectMake((frame.size.width - windowImg.size.width) * 0.5f,
                                     (frame.size.height - windowImg.size.height) * 0.5f + 8.0f,
                                     windowImg.size.width * 0.5f,
                                     windowImg.size.height * 0.5f)];
        window.userInteractionEnabled = YES;
        [window setImage:windowImg];
        window.tag = 400;
        [self addSubview:window];

        // Dimmed dummy overlay carrying the request spinner (hidden until a request
        // runs).
        _dummyView = [[UIView alloc] initWithFrame:frame];
        _dummyView.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
        _dummyView.hidden = YES;
        [self addSubview:_dummyView];

        UIActivityIndicatorView *spinner =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        spinner.center =
            CGPointMake(frame.size.width * 0.5f, static_cast<int>(frame.size.height * 0.5f) - 10);
        spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
        [spinner startAnimating];
        [_dummyView addSubview:spinner];

        // Request + cancel buttons (only when the row carries a player id).
        if (fd.playerId != nil) {
            UIButton *requestBtn = [[UIButton alloc] init];
            UIImage *reqImg = [UIImage imageNamed:@"fpl_btn_presenting"];
            [requestBtn setFrame:CGRectMake(151.0f * _scaleForPad,
                                            368.0f * _scaleForPad,
                                            reqImg.size.width,
                                            reqImg.size.height)]; // DAT 0xe3948/0xe394c
            [requestBtn setImage:reqImg forState:UIControlStateNormal];
            [requestBtn addTarget:self
                           action:@selector(startRequestFriendHttp)
                 forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:requestBtn];

            UIButton *cancelBtn = [[UIButton alloc] init];
            UIImage *canImg = [UIImage imageNamed:@"fpl_btn_cancel"];
            [cancelBtn setFrame:CGRectMake(36.0f * _scaleForPad,
                                           368.0f * _scaleForPad,
                                           canImg.size.width,
                                           canImg.size.height)]; // DAT 0xe3950/0xe394c
            [cancelBtn setImage:canImg forState:UIControlStateNormal];
            [cancelBtn addTarget:self
                          action:@selector(touchedCancel)
                forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:cancelBtn];
        }

        // Friend character art (clamp charaId to >= 0). Ids <= 29 are bundled;
        // larger ids are downloaded characters read from the Application Support
        // directory.
        short charaId = fd.charaId < 0 ? 0 : fd.charaId;
        if (!isPad) {
            UIImageView *charaBg =
                [[UIImageView alloc] initWithFrame:CGRectMake(18.0f, 36.0f, 55.0f, 55.0f)];
            [charaBg setImage:[UIImage imageNamed:@"frilis_btn_chara"]];
            [window addSubview:charaBg];

            NSString *charaName =
                [NSString stringWithFormat:@"sgc_icon_%03d.png", static_cast<int>(charaId)];
            UIImage *charaImg;
            if (charaId > 29) {
#ifdef ENABLE_PATCHES
                NSString *path = [AppDelegate appAssetsPath:charaName];
#else
                NSString *path =
                    [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:charaName];
#endif
                charaImg = [UIImage imageWithContentsOfFile:path];
            } else {
                charaImg = [UIImage imageWithContentsOfFile:charaName];
            }
            UIImageView *chara =
                [[UIImageView alloc] initWithFrame:CGRectMake(25.0f, 38.0f, 43.0f, 43.0f)];
            [chara setImage:charaImg];
            [window addSubview:chara];
        } else {
            NSString *charaName =
                [NSString stringWithFormat:@"sugo_chara_%03d.png", static_cast<int>(charaId)];
#ifdef ENABLE_PATCHES
            NSString *charaPath = [AppDelegate appAssetsPath:charaName];
#else
            NSString *charaPath =
                [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:charaName];
#endif
            NSURL *url = [NSURL fileURLWithPath:charaPath];
            UIImageView *chara =
                [[UIImageView alloc] initWithFrame:CGRectMake(66.0f, 72.0f, 125.0f, 120.0f)];
            [chara setImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:url]]];
            chara.backgroundColor = [UIColor clearColor];
            [window addSubview:chara];
        }

        UIColor *textColor =
            isPad ? [UIColor whiteColor] : [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0f];

        // Name label (DFSoGei, 20pt * scale).
        UILabel *nameLbl = [[UILabel alloc] init];
        nameLbl.backgroundColor = [UIColor clearColor];
        nameLbl.textColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0f];
        nameLbl.text = fd.name;
        nameLbl.font = [UIFont fontWithName:AppFontName() size:20.0f * _scaleForPad];
        nameLbl.minimumScaleFactor = 0.5f;
        nameLbl.textAlignment = NSTextAlignmentCenter;
        // Frame (72, 30, 176, 24) * scale. Verified against the setFrame register
        // layout (x = r2 = 72.0 (DAT_000e3954), y = r3 = 30.0 (0x41f00000),
        // width = sp[0] = 176.0 (DAT_000e3958), height = sp[4] = 24.0
        // (0x41c00000)); the CGRect arg order was cross-checked against the
        // immediate-encoded chara frames in the same method.
        nameLbl.frame = CGRectMake(72.0f * _scaleForPad,
                                   30.0f * _scaleForPad,
                                   176.0f * _scaleForPad,
                                   24.0f * _scaleForPad);
        nameLbl.adjustsFontSizeToFitWidth = YES;
        [window addSubview:nameLbl];

        // Player-id label (15pt * scale). The binary measures the text (via
        // -sizeWithFont:constrainedToSize:(640, 1136)) and lays it out
        // horizontally centred on 212 with its top at y = 60, then scales the
        // whole frame: frame = ((212 - w/2), 60, w, h) * scale (x from
        // DAT_000e3964 = 212.0, y from DAT_000e3968 = 60.0). On iPad the label is
        // then re-centred (its frame centre nudged down by 5.0, DAT 0x40a00000)
        // and the font re-set to 15pt * scale.
        UILabel *idLbl = [[UILabel alloc] init];
        idLbl.backgroundColor = [UIColor clearColor];
        idLbl.textColor = textColor;
        idLbl.text = fd.playerId;
        idLbl.font = [UIFont fontWithName:AppFontName() size:15.0f * _scaleForPad];
        idLbl.adjustsFontSizeToFitWidth = YES;
        idLbl.textAlignment = NSTextAlignmentCenter;
        [idLbl sizeToFit];
        CGSize idSize = idLbl.bounds.size;
        idLbl.frame = CGRectMake((212.0f - idSize.width * 0.5f) * _scaleForPad,
                                 60.0f * _scaleForPad,
                                 idSize.width * _scaleForPad,
                                 idSize.height * _scaleForPad);
        if (isPad) {
            idLbl.center = CGPointMake(idLbl.center.x, idLbl.center.y + 5.0f);
        }
        [window addSubview:idLbl];

        // Caption label (Ghidra cf__ — a short JP static string). Same layout as
        // the id label but with its top at y = 81 (DAT_000e40a8 = 81.0) instead
        // of 60, sharing the horizontal centre 212.
        UILabel *captionLbl = [[UILabel alloc] init];
        captionLbl.backgroundColor = [UIColor clearColor];
        captionLbl.textColor = textColor;
        captionLbl.text = @"さん"; // NOTE(unverified): Ghidra cf__ not decoded
        captionLbl.font = [UIFont fontWithName:AppFontName() size:15.0f * _scaleForPad];
        captionLbl.textAlignment = NSTextAlignmentCenter;
        [captionLbl sizeToFit];
        CGSize capSize = captionLbl.bounds.size;
        captionLbl.frame = CGRectMake((212.0f - capSize.width * 0.5f) * _scaleForPad,
                                      81.0f * _scaleForPad,
                                      capSize.width * _scaleForPad,
                                      capSize.height * _scaleForPad);
        if (isPad) {
            captionLbl.center = CGPointMake(captionLbl.center.x, captionLbl.center.y + 5.0f);
        }
        [window addSubview:captionLbl];

        // Per-difficulty count sheet on the card: 4 clear-medal grades (S/AAA/AA/A)
        // x 3 difficulties (N/H/Ex), then a Perfect row and a FullCombo row.
        for (int grade = 0; grade < 4; grade++) {
            for (int diff = 0; diff < 3; diff++) {
                [self addCntNum:fd.rank[diff][grade]
                          sheet:diff
                              y:(0x95 + grade * 0x23)
                           view:window];
            }
        }
        for (int diff = 0; diff < 3; diff++) {
            [self addCntNum:fd.perfect[diff] sheet:diff y:0x121 view:window];
        }
        for (int diff = 0; diff < 3; diff++) {
            [self addCntNum:fd.fullComboOnly[diff] sheet:diff y:0x143 view:window];
        }
    }
    return self;
}

// @ 0xe40ac — draw `count` as up to 3 right-aligned digit images
// (frilis_num_<n|h|e><digit>) for difficulty row `sheet` (0=N,1=H,2=Ex) at
// vertical position `y`, into `view`. All frames are scaled by _scaleForPad.
//
// kBaseX = {139, 190, 242} verified @ 0x12fbe0. The binary indexes a static
// [sheet][digit] table of pre-built "frilis_num_XY" image-name constants where
// this reconstruction rebuilds the same names via -stringWithFormat:; the X
// step (base - i*15) * scale, the Y * scale, the image size * scale, and the
// three right-aligned digits (count /= 10) all match.
- (void)addCntNum:(int)count sheet:(int)sheet y:(int)y view:(UIView *)view {
    static NSString *const kSet[3] = {@"n", @"h", @"e"};
    static constexpr int kBaseX[3] = {139, 190, 242}; // DAT_0012fbe0
    for (int i = 0; i < 3; i++) {
        int digit = count % 10;
        UIImage *img =
            [UIImage imageNamed:[NSString stringWithFormat:@"frilis_num_%@%d", kSet[sheet], digit]];
        UIImageView *iv =
            [[UIImageView alloc] initWithFrame:CGRectMake((kBaseX[sheet] - i * 15) * _scaleForPad,
                                                          y * _scaleForPad,
                                                          img.size.width * _scaleForPad,
                                                          img.size.height * _scaleForPad)];
        [iv setImage:img];
        [view addSubview:iv];
        count /= 10;
    }
}

#pragma mark - Open / close animation

// @ 0xe42f8 — fade in (alpha 0 -> 1 over 0.3s); marks enabled + animating.
//
// (both _isAnimationing and _isEnabled set; duration 0.3 @ 0xe43c8).
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    _isEnabled = YES;
    self.alpha = 0;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3]; // DAT_000e43c8
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0xe43d0 — open animation finished.
//
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xe43e8 — fade out (alpha -> 0 over 0.3s), then remove on stop.
//
// (the binary clears _isAnimationing to 0 here; duration 0.3 @
// 0xe44a0).
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = NO;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3]; // DAT_000e44a0
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.alpha = 0;
    [UIView commitAnimations];
}

// @ 0xe44a8 — close animation finished: drop off screen and disable.
//
- (void)endCloseAnimation {
    [self removeFromSuperview];
    _isAnimationing = NO;
    _isEnabled = NO;
}

#pragma mark - Downloader delegate

// @ 0xe44e0 — friend-request response: nil JSON body -> success; else map the
// "ErrorCode" number to a result message. Always drops the downloader + hides
// the spinner, then alerts.
//
- (void)downloaderFinished:(Downloader *)downloader {
    NSString *message;
    NSDictionary *json = [downloader getDataInJSON];
    if (json == nil) {
        message = @"フレンド申請に成功しました。";
    } else {
        message = nil;
        id errorCode = [json objectForKey:@"ErrorCode"];
        if ([errorCode isKindOfClass:[NSNumber class]]) {
            switch ([errorCode intValue]) {
            case FriendResultCommError0:
            case FriendResultCommError1:
            case FriendResultCommError2:
            case FriendResultCommError7:
                message = @"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。";
                break;
            case FriendResultInvalidPlayerId:
                message = @"無効なプレーヤーIDです。";
                break;
            case FriendResultSelfListFull:
                message = @"これ以上、フレンドを登録することはできません。";
                break;
            case FriendResultPeerListFull:
                message = @"相手の人は、これ以上、フレンドを登録することはできません。";
                break;
            case FriendResultBlocked:
                message = @"ブロックリスト対象です。";
                break;
            case FriendResultAlreadyRequested:
                message = @"既に申請済み\nまたは、申請を受けています。";
                break;
            case FriendResultAlreadyRegistered:
                message = @"既に登録済みです。";
                break;
            default:
                message = nil;
                break;
            }
        }
    }

    _downloader = nil;
    _dummyView.hidden = YES;

    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"フレンド申請"
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"OK"];
    [alert show];
}

// @ 0xe46a0 — per-chunk progress: no-op.
//
// (bx lr).
- (void)downloaderProceed:(Downloader *)downloader {
}

// @ 0xe46a4 — request failed: drop the downloader, hide the spinner, show the
// network alert.
//
- (void)downloaderError:(Downloader *)downloader {
    _downloader = nil;
    _dummyView.hidden = YES;

    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:nil
                                       message:@"通信に失敗しました。\n電波状態の"
                                               @"良い場所でやり直して下さい。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
}

#pragma mark - CommonAlertView delegate

// @ 0xe476c — dismissing a result alert closes the overlay.
//
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    [self startCloseAnimation];
}

#pragma mark - Networking

// @ 0xe477c — POST the friend request (once) for this row's player id,
// revealing the spinner.
//
// Verified: guarded on _downloader == nil && fd.playerId != nil; plays SE 1 on
// send / SE 2 otherwise; POST body "uuid=%@&player_id=%@&message=%@" (message
// empty), UTF-8, Content-Type "application/json" to +[StoreUtil
// requestFriendURL]; reveals _dummyView.
- (void)startRequestFriendHttp {
    FriendListData fd;
    [_friendData getValue:&fd];

    if (_downloader == nil && fd.playerId != nil) {
        neEngine::playSystemSe(1); // decide/confirm SE

        NSString *body = [NSString stringWithFormat:@"uuid=%@&player_id=%@&message=%@",
                                                    [[AppDelegate appDelegate] uuId],
                                                    fd.playerId,
                                                    @""];
        _downloader = [[Downloader alloc] initWithURL:[StoreUtil requestFriendURL]
                                             delegate:self
                                                 Post:[body dataUsingEncoding:NSUTF8StringEncoding]
                                          ContextType:@"application/json"];
        [_downloader startDownloading];
        _dummyView.hidden = NO;
    } else {
        neEngine::playSystemSe(2); // cancel/back SE (already requesting)
    }
}

// @ 0xe490c — cancel button: play the back SE and close.
//
- (void)touchedCancel {
    neEngine::playSystemSe(2);
    [self startCloseAnimation];
}

// @ 0xe493c — a touch that ends outside the card (tag != 400) dismisses the
// overlay.
//
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([[touches anyObject] view].tag == 400) {
        return;
    }
    [self touchedCancel];
}

#pragma mark - State

// @ 0xe4994
//
// (atomic BOOL getter; dmb barrier).
- (BOOL)isAnimationing {
    return _isAnimationing;
}

// @ 0xe49ac
//
// (atomic BOOL getter; dmb barrier).
- (BOOL)isEnabled {
    return _isEnabled;
}

// @ 0xe4278 (Ghidra "deallc") — cancel the in-flight request so no late
// callback fires into a dead overlay. Kept under ARC because it cancels a
// Downloader; the _dummyView / _downloader object releases are ARC-managed.
//
// (binary releases _dummyView, then cancels + releases _downloader,
// then [super dealloc]; the cancel is the load-bearing part kept under ARC).
- (void)dealloc {
    if (_downloader != nil) {
        [_downloader cancel];
    }
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
