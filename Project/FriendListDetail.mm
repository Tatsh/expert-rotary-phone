//
//  FriendListDetail.mm
//  pop'n rhythmin
//
//  See FriendListDetail.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithFrame:friendData: @ 0xb4280, addCntNum:sheet:y:view: @ 0xb5230, dealloc @ 0xb53fc,
//  startOpenAnimation @ 0xb5480, endOpenAnimation @ 0xb5558, startCloseAnimation @ 0xb5570,
//  endCloseAnimation @ 0xb5640, downloaderFinished: @ 0xb5678, downloaderProceed: @ 0xb57cc,
//  downloaderError: @ 0xb57d0, commonAlertView:clickedButtonAtIndex: @ 0xb5898,
//  touchesBegan:withEvent: @ 0xb5a34, touchesEnded:withEvent: @ 0xb5b70,
//  startRemoveFriendHttp @ 0xb5be8, isEnabled @ 0xb5c98). Objective-C++ for the neSceneManager
//  device check and neEngine SE.
//
//  Layout note: the ~4KB init lays every element out against a global scale (1.0 phone @0xb5224 /
//  2.0 pad @0xb5228) via NEON vector multiplies. The device-branched offset globals at 0xb4a90..
//  are recovered exactly (read_memory): DAT_000b4a90=-48.0, b4a94=-50.0, b4a98=72.0, b4a9c=176.0,
//  b4aa0=-80.0 (pad), b4aa4=80.0 (pad). The subview tree, images, text bindings, colours, fonts,
//  tags, the phone/pad chara branch and the score grid (columns per difficulty at x {139,190,242},
//  digit art frilis_num_{n,h,e}{0-9}) are reproduced exactly. The delBtn/nameLabel frames are
//  device-branched NEON expressions over those offsets and runtime image .size; their exact
//  origin algebra is only partially attributable and is kept structural (flagged inline).
//

#import "FriendListDetail.h"

#import "neEngineBridge.h"           // neSceneManager::isPadDisplay, neEngine::playSystemSe
#import "DownloadMain.h"             // FriendListData, DownloadMain
#import "AppDelegate.h"              // appDelegate.uuId / appAppSupportDirectory
#import "AppFont.h"                  // AppFontName()
#import "StoreUtil.h"                // +removeFriendURL
#import "FriendListDetailChara.h"    // tap-portrait skill card
#import "Game/Data/Save/UserSettingData.h"   // +playerId (self row)

// Per-difficulty (Normal/Hyper/Extra) digit glyphs; addCntNum composes a 3-digit count from them.
static NSString *const kNumImg[3][10] = {
    { @"frilis_num_n0", @"frilis_num_n1", @"frilis_num_n2", @"frilis_num_n3", @"frilis_num_n4",
      @"frilis_num_n5", @"frilis_num_n6", @"frilis_num_n7", @"frilis_num_n8", @"frilis_num_n9" },
    { @"frilis_num_h0", @"frilis_num_h1", @"frilis_num_h2", @"frilis_num_h3", @"frilis_num_h4",
      @"frilis_num_h5", @"frilis_num_h6", @"frilis_num_h7", @"frilis_num_h8", @"frilis_num_h9" },
    { @"frilis_num_e0", @"frilis_num_e1", @"frilis_num_e2", @"frilis_num_e3", @"frilis_num_e4",
      @"frilis_num_e5", @"frilis_num_e6", @"frilis_num_e7", @"frilis_num_e8", @"frilis_num_e9" },
};
// Column origin per difficulty (DAT_0012fa00).
static const int kColX[3] = { 139, 190, 242 };

@implementation FriendListDetail {
    UIView *_dummyView;         // loading overlay (+ activity indicator), @0x34
    NSValue *_friendData;       // the friend's FriendListData (retained), @0x38
    BOOL _isAnimationing;       // open/close guard, @0x3c
    BOOL _isEnabled;            // presented flag, @0x3d
    Downloader *_dlRemoveFriend;// in-flight unfriend POST, @0x40
    CGFloat _scaleForPad;       // 1.0 phone / 2.0 pad, @0x44
}

// @ 0xb5230 — draw a right-aligned 3-digit count using the difficulty's digit art.
- (void)addCntNum:(int)value sheet:(int)sheet y:(int)y view:(UIView *)view {
    const CGFloat s = _scaleForPad;
    const int baseX = kColX[sheet];
    int v = value;
    int dx = 0;                       // ones, tens, hundreds — 15pt apart, right to left
    for (int i = 0; i < 3; i++) {
        UIImage *img = [UIImage imageNamed:kNumImg[sheet][v % 10]];
        UIImageView *iv = [[UIImageView alloc]
            initWithFrame:CGRectMake((baseX + dx) * s, y * s,
                                     img.size.width * s, img.size.height * s)];
        [iv setImage:img];
        [view addSubview:iv];
        v /= 10;
        dx -= 15;
    }
}

// @ 0xb4280
- (instancetype)initWithFrame:(CGRect)frame friendData:(NSValue *)friendData {
    self = [super initWithFrame:frame];
    _friendData = friendData;    // stored before the nil-check, matching the binary
    if (self == nil) {
        return self;
    }

    FriendListData data;
    [friendData getValue:&data];
    const BOOL isFriend = (data.playerId != nil);   // self row has a nil playerId

    // Translucent black backdrop (alpha 0.3 = 0x3e99999a).
    self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3f];

    const BOOL isPad = neSceneManager::isPadDisplay();
    _scaleForPad = isPad ? 2.0f : 1.0f;   // DAT_000b5224 / DAT_000b5228
    const CGFloat s = _scaleForPad;

    // Window, centred in the frame; parents every element below (tag 100).
    UIImage *windowImg = [UIImage imageNamed:@"frilis_window"];
    UIImageView *window = [[UIImageView alloc]
        initWithFrame:CGRectMake((frame.size.width  - windowImg.size.width)  * 0.5f,
                                 (frame.size.height - windowImg.size.height) * 0.5f,
                                 windowImg.size.width, windowImg.size.height)];
    [window setImage:windowImg];
    [window setUserInteractionEnabled:YES];
    [window setTag:100];
    [self addSubview:window];

    // Loading overlay (hidden until an unfriend request is in flight) + spinner.
    _dummyView = [[UIView alloc] initWithFrame:frame];
    _dummyView.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
    [_dummyView setHidden:YES];
    [self addSubview:_dummyView];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, 24, 24)];
    [spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    spinner.center = CGPointMake(frame.size.width * 0.5f, frame.size.height * 0.5f - 10.0f);
    spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    [spinner startAnimating];
    [_dummyView addSubview:spinner];

    // Close button (top-right of the window).
    UIImage *closeImg = [UIImage imageNamed:@"frilis_btn_close"];
    UIButton *closeBtn = [[UIButton alloc] init];
    [closeBtn setFrame:CGRectMake(347.0f * s, 8.0f * s, closeImg.size.width, closeImg.size.height)];
    [closeBtn setImage:closeImg forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(startCloseAnimation)
       forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:closeBtn];

    // Unfriend button — friends only (you cannot unfriend yourself).
    if (isFriend) {
        UIImage *delImg = [UIImage imageNamed:@"frilis_btn_delate"];
        UIButton *delBtn = [[UIButton alloc] init];
        delBtn.backgroundColor = [UIColor clearColor];
        // Frame @ 0xb482c: y offset = DAT_000b4a90=-48.0 (phone) / DAT_000b4a94=-50.0 (pad),
        // added to a scaled window/delImg-width expression; kept structural (partial NEON attrib).
        [delBtn setFrame:CGRectMake((windowImg.size.width - delImg.size.width) - 12.0f * s,
                                    (isPad ? 60.0f : 44.0f) * s,
                                    delImg.size.width, delImg.size.height)];
        [delBtn setImage:delImg forState:UIControlStateNormal];
        [delBtn addTarget:self action:@selector(startRemoveFriendHttp)
         forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:delBtn];
    }

    short charaId = data.charaId;
    if (charaId < 0) {
        charaId = 0;
    }

    // Portrait (tappable, tag 0x65 -> FriendListDetailChara). Phone: icon plate + sgc_icon;
    // iPad: the large sugo_chara art loaded from Application Support.
    UIImageView *charaView;
    if (!isPad) {
        UIImageView *plate = [[UIImageView alloc]
            initWithFrame:CGRectMake(18, 36, 55, 55)];
        [plate setImage:[UIImage imageNamed:@"frilis_btn_chara"]];
        [window addSubview:plate];

        charaView = [[UIImageView alloc] initWithFrame:CGRectMake(25, 38, 43, 43)];
        NSString *iconFile = [NSString stringWithFormat:@"sgc_icon_%03d.png", (int)charaId];
        UIImage *icon = (charaId > 0x1d)
            ? [UIImage imageWithContentsOfFile:
                  [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:iconFile]]
            : [UIImage imageNamed:iconFile];
        [charaView setImage:icon];
    } else {
        charaView = [[UIImageView alloc] initWithFrame:CGRectMake(66, 72, 125, 120)];
        NSString *sugoFile = [NSString stringWithFormat:@"sugo_chara_%03d.png", (int)charaId];
        NSURL *sugoURL = [NSURL fileURLWithPath:
            [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:sugoFile]];
        [charaView setImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:sugoURL]]];
        charaView.backgroundColor = [UIColor clearColor];
    }
    [charaView setUserInteractionEnabled:YES];
    [charaView setTag:0x65];
    [window addSubview:charaView];

    // Name.
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.backgroundColor = [UIColor clearColor];
    nameLabel.textColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0f];
    nameLabel.text = data.name;
    nameLabel.font = [UIFont fontWithName:AppFontName() size:20.0f * s];
    [nameLabel setMinimumScaleFactor:0.5f];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    // Frame @ 0xb4e34: device-branched over exact constants 24.0/30.0 and offset globals
    // DAT_000b4a98=72.0, b4a9c=176.0, b4aa0=-80.0 (pad), b4aa4=80.0 (pad); kept structural.
    [nameLabel setFrame:CGRectMake(78.0f * s, 14.0f * s, 96.0f * s, 26.0f * s)];
    nameLabel.adjustsFontSizeToFitWidth = YES;
    [window addSubview:nameLabel];

    // Player id (own id for the self row). Black on phone, white on iPad.
    UILabel *playerIdLabel = [[UILabel alloc] init];
    playerIdLabel.backgroundColor = [UIColor clearColor];
    playerIdLabel.textColor = isPad ? [UIColor whiteColor]
                                    : [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0f];
    playerIdLabel.text = isFriend ? data.playerId : [UserSettingData playerId];
    playerIdLabel.font = [UIFont fontWithName:AppFontName() size:(isPad ? 15.0f * s : 15.0f)];
    playerIdLabel.adjustsFontSizeToFitWidth = YES;
    playerIdLabel.textAlignment = NSTextAlignmentCenter;
    [playerIdLabel sizeToFit];
    // Centre placement (parent-relative in the binary); best-effort origin.
    playerIdLabel.center = CGPointMake(windowImg.size.width * 0.5f, 60.0f * s);
    [window addSubview:playerIdLabel];

    // Friendship value (friends only).
    UILabel *friendshipLabel = [[UILabel alloc] init];
    friendshipLabel.backgroundColor = [UIColor clearColor];
    friendshipLabel.textColor = isPad ? [UIColor whiteColor]
                                      : [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0f];
    friendshipLabel.text = isFriend ? [NSString stringWithFormat:@"%d", data.friendShip] : @"";
    friendshipLabel.font = [UIFont fontWithName:AppFontName() size:(isPad ? 15.0f * s : 15.0f)];
    friendshipLabel.textAlignment = NSTextAlignmentCenter;
    [friendshipLabel sizeToFit];
    friendshipLabel.center = CGPointMake(windowImg.size.width * 0.5f, 80.0f * s);
    [window addSubview:friendshipLabel];

    // Clear-count grid: 3 difficulty columns; rank tiers 0-3, then perfect, then full-combo rows.
    for (int row = 0; row < 4; row++) {
        for (int sheet = 0; sheet < 3; sheet++) {
            [self addCntNum:data.rank[sheet][row] sheet:sheet y:(0x95 + row * 0x23) view:window];
        }
    }
    for (int sheet = 0; sheet < 3; sheet++) {
        [self addCntNum:data.perfect[sheet] sheet:sheet y:0x121 view:window];
    }
    for (int sheet = 0; sheet < 3; sheet++) {
        [self addCntNum:data.fullComboOnly[sheet] sheet:sheet y:0x143 view:window];
    }

    return self;
}

// @ 0xb5480 — fade in over 0.3s (DAT_000b5550).
- (void)startOpenAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    _isEnabled = YES;
    [self setAlpha:0];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    [self setAlpha:1.0f];
    [UIView commitAnimations];
}

// @ 0xb5558
- (void)endOpenAnimation {
    _isAnimationing = NO;
}

// @ 0xb5570 — decide cancel SE, fade out over 0.3s (DAT_000b5638). The binary clears the guard.
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = NO;
    neEngine::playSystemSe(2);
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    [self setAlpha:0];
    [UIView commitAnimations];
}

// @ 0xb5640
- (void)endCloseAnimation {
    [self removeFromSuperview];
    _isAnimationing = NO;
    _isEnabled = NO;
}

// @ 0xb5a34 — tapping the portrait (tag 0x65) opens the chara/skill card (tag 0x66) with the
// decide SE.
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([[[touches anyObject] view] tag] == 0x65) {
        neEngine::playSystemSe(1);
        UIView *portrait = [self viewWithTag:100];
        FriendListDetailChara *card = [[FriendListDetailChara alloc]
            initWithFrame:portrait.frame friendData:_friendData];
        [card setTag:0x66];
        [portrait addSubview:card];
        [card startOpenAnimation];
    }
}

// @ 0xb5b70 — a tap that ends outside the portrait/card region closes the card (or the detail).
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    NSInteger tag = [[[touches anyObject] view] tag];
    if (tag - 100 < 3) {   // 100/101/102 — inside the window/portrait/card: swallow
        return;
    }
    UIView *card = [[self viewWithTag:100] viewWithTag:0x66];
    [(card ?: self) startCloseAnimation];
}

// @ 0xb5be8 — confirm before unfriending (needs a friendData and no request already running).
- (void)startRemoveFriendHttp {
    if (_dlRemoveFriend == nil && _friendData != nil) {
        CommonAlertView *alert = [[CommonAlertView alloc]
            initWithTitle:@"フレンドを解除します"
                  message:nil
                 delegate:self
        cancelButtonTitle:@"Cancel"
        otherButtonTitles:@"OK"];
        [alert show];
    }
}

// @ 0xb5898 — alert responses: tag-100 (result) reloads the list + closes; the confirm alert's
// "OK" (index 1) fires the unfriend POST.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if ([alertView tag] == 100) {
        [[DownloadMain getInstance] startGetFriendListHttp];
        [self startCloseAnimation];
        return;
    }
    if (index != 1) {
        return;
    }
    [_dummyView setHidden:NO];
    FriendListData data;
    [_friendData getValue:&data];
    NSString *body = [NSString stringWithFormat:@"uuid=%@&player_id=%@",
                      AppDelegate.appDelegate.uuId, data.playerId];
    _dlRemoveFriend = [[Downloader alloc]
        initWithURL:[StoreUtil removeFriendURL]
           delegate:self
               Post:[body dataUsingEncoding:NSUTF8StringEncoding]
        ContextType:@"application/x-www-form-urlencoded"];
    [_dlRemoveFriend startDownloading];
}

// @ 0xb5678 — unfriend POST finished: show the result (tag 100), success vs. failure by whether
// the JSON body came back.
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [_dlRemoveFriend getDataInJSON];
    NSString *message;
    id delegate;
    if (json == nil) {
        message = @"通信に失敗しました。";   // best-effort: cf_00000dW0_0W0_00 (comms failure)
        delegate = self;
    } else {
        // The binary also checks the "ErrorCode" key here; the success copy is shown regardless.
        (void)[[json objectForKey:@"ErrorCode"] isKindOfClass:[NSNumber class]];
        message = @"解除しました。";          // best-effort: cf_Ok01YWeW0_0W0_00 (unfriended)
        delegate = nil;
    }
    _dlRemoveFriend = nil;
    [_dummyView setHidden:YES];

    CommonAlertView *alert = [[CommonAlertView alloc]
        initWithTitle:@"フレンド解除"
              message:message
             delegate:delegate
    cancelButtonTitle:nil
    otherButtonTitles:@"OK"];
    [alert setTag:100];
    [alert show];
}

// @ 0xb57cc — no-op.
- (void)downloaderProceed:(Downloader *)downloader {
}

// @ 0xb57d0 — unfriend POST failed at the transport level: generic comms-error alert.
- (void)downloaderError:(Downloader *)downloader {
    _dlRemoveFriend = nil;
    [_dummyView setHidden:YES];
    CommonAlertView *alert = [[CommonAlertView alloc]
        initWithTitle:nil
              message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
             delegate:nil
    cancelButtonTitle:nil
    otherButtonTitles:@"OK"];
    [alert show];
}

// @ 0xb5c98
- (BOOL)isEnabled {
    return _isEnabled;
}

// @ 0xb53fc
- (void)dealloc {
    if (_dlRemoveFriend != nil) {
        [_dlRemoveFriend cancel];
    }
}

@end
