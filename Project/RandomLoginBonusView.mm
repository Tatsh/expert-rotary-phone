//
//  RandomLoginBonusView.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  ARC. (.mm: uses the C++ neEngine bridge for the root scene view / idiom /
//  SE, plus the AudioManager SE engine.)
//

#import "RandomLoginBonusView.h"
#import "AudioManager.h" // +sharedManager, -loadSe:isLoop:callName:group:, -playSe:resourceId:, -stopSe:, -releaseSe:resourceId:
#import "UserSettingData.h" // +treasurePoint / +saveTreasurePoint:
#import "neEngineBridge.h" // neSceneManager::rootViewController(), neSceneManager::isPadDisplay(), neEngine::playSystemSe(int)

@interface RandomLoginBonusView () {
    int _bonus;                   // rolled treasure-point bonus (0..9999)
    UIImageView *_numImgView1000; // thousands reel
    UIImageView *_numImgView0100; // hundreds reel
    UIImageView *_numImgView0010; // tens reel
    UIImageView *_numImgView0001; // ones reel
    int _seRscId[3];              // loaded SE resource ids: 0 roll(loop), 1 fail, 2 close
    int _seInstId[3];             // playing SE instance ids
    BOOL _isAnimationing;         // guard while an open/close/lock animation runs
    int _state;                   // 0 = reels spinning, 1 = locked / awaiting dismiss
}
- (void)getBonus;
- (void)touchEvent:(id)sender;
- (void)startCloseAnimation;
- (void)endCloseAnimation;
- (void)showAlertView;
- (UIImageView *)makeDigitReelForValue:(int)digit
                       animationImages:(NSArray *)images
                                hidden:(BOOL)hiddenLeadingZero;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
@end

@implementation RandomLoginBonusView

// @ 0x0012e318 — the weighted-random {value, weight} roulette table (7 rows).
// Recovered verbatim from the const-data blob (Ghidra &UNK_0012e318 values /
// &DAT_0012e31c weights, interleaved 8 bytes per row). The weights sum to 1000,
// which matches the arc4random() % 1000 + 1 roll below.
//
// @complete (table bytes verified @ 0x12e318: value at +0, weight at +4).
constexpr struct {
    int value;
    int weight;
} kBonusTable[7] = {
    {100, 150}, // @ 0x0012e318
    {200, 150}, // @ 0x0012e320
    {300, 300}, // @ 0x0012e328
    {400, 300}, // @ 0x0012e330
    {500, 78},  // @ 0x0012e338
    {1000, 20}, // @ 0x0012e340
    {9999, 2},  // @ 0x0012e348
};

// @ 0x18a38 — weighted-random roll into _bonus.
//
// arc4random() % 1000 + 1 is walked down the 7-row {value, weight} table
// (weights sum to 1000); the first row whose running weight covers the roll
// supplies the value.
//
// @complete
- (void)getBonus {
    _bonus = 0;
    int roll = (int)(arc4random() % 1000) + 1;
    for (int i = 0; i < 7; i++) {
        if (roll <= kBonusTable[i].weight) {
            _bonus = kBonusTable[i].value;
            return;
        }
        roll -= kBonusTable[i].weight;
    }
}

// @ 0x18a90 — nib path funnels into -init.
//
// @complete
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self init];
}

// @ 0x18aa0 — frame path funnels into -init.
//
// @complete
- (instancetype)initWithFrame:(CGRect)frame {
    return [self init];
}

// @ 0x18ab0 — designated setup: dimmer + panel + four spinning digit reels.
//
// @complete
// Verified: SE load order (se26_roll loop / se08_bonus_fai / se09_bonus_cl, all
// group 1); dimmer white alpha 0.5; login_board_02; -getBonus after the board;
// iPad reel X = 183/288/398/503 at y = 523 (0x4337c000/0x43900000/0x43c70000/
// 0x43fb8000/0x4402c000); phone base X delta 24.0 (0x41c00000), X step 54.0
// (0x42580000), Y delta 133.0 (0x43050000); reel animationDuration 0.5;
// full-screen touchEvent: catcher; self.hidden = YES.
- (instancetype)init {
    UIView *rootView = neSceneManager::rootViewController().view;
    CGRect frame = rootView ? rootView.frame : CGRectZero;

    self = [super initWithFrame:frame];
    if (self) {
        _state = 0;

        // Load the three SEs (roll loop / fail / close) into the "1" group.
        NSBundle *bundle = [NSBundle mainBundle];
        AudioManager *audio = [AudioManager sharedManager];

        NSString *rollPath = [bundle pathForResource:@"se26_roll" ofType:@"m4a"];
        _seRscId[0] = static_cast<int>([audio loadSe:rollPath isLoop:YES callName:nil group:1]);

        NSString *failPath = [bundle pathForResource:@"se08_bonus_fai" ofType:@"m4a"];
        _seRscId[1] = static_cast<int>([audio loadSe:failPath isLoop:NO callName:nil group:1]);

        NSString *closePath = [bundle pathForResource:@"se09_bonus_cl" ofType:@"m4a"];
        _seRscId[2] = static_cast<int>([audio loadSe:closePath isLoop:NO callName:nil group:1]);

        // Modal dimmer.
        self.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];

        // Centred "login_board_02" panel.
        UIImage *boardImg = [UIImage imageNamed:@"login_board_02"];
        UIImageView *board = [[UIImageView alloc] initWithImage:boardImg];
        board.frame = CGRectMake(0.0f, 0.0f, boardImg.size.width, boardImg.size.height);
        board.center = CGPointMake(self.frame.size.width * 0.5f, self.frame.size.height * 0.5f);
        board.userInteractionEnabled = YES;
        [self addSubview:board];

        // Decide the bonus, then build the four digit reels.
        [self getBonus];

        // The reels roll through num_logb_0..9 in a per-column shuffled order.
        NSArray *up = @[
            [UIImage imageNamed:@"num_logb_0"],
            [UIImage imageNamed:@"num_logb_1"],
            [UIImage imageNamed:@"num_logb_2"],
            [UIImage imageNamed:@"num_logb_3"],
            [UIImage imageNamed:@"num_logb_4"],
            [UIImage imageNamed:@"num_logb_5"],
            [UIImage imageNamed:@"num_logb_6"],
            [UIImage imageNamed:@"num_logb_7"],
            [UIImage imageNamed:@"num_logb_8"],
            [UIImage imageNamed:@"num_logb_9"]
        ];
        NSArray *down = @[
            [UIImage imageNamed:@"num_logb_9"],
            [UIImage imageNamed:@"num_logb_8"],
            [UIImage imageNamed:@"num_logb_7"],
            [UIImage imageNamed:@"num_logb_6"],
            [UIImage imageNamed:@"num_logb_5"],
            [UIImage imageNamed:@"num_logb_4"],
            [UIImage imageNamed:@"num_logb_3"],
            [UIImage imageNamed:@"num_logb_2"],
            [UIImage imageNamed:@"num_logb_1"],
            [UIImage imageNamed:@"num_logb_0"]
        ];
        NSArray *mid1 = @[
            [UIImage imageNamed:@"num_logb_4"],
            [UIImage imageNamed:@"num_logb_5"],
            [UIImage imageNamed:@"num_logb_6"],
            [UIImage imageNamed:@"num_logb_7"],
            [UIImage imageNamed:@"num_logb_8"],
            [UIImage imageNamed:@"num_logb_9"],
            [UIImage imageNamed:@"num_logb_0"],
            [UIImage imageNamed:@"num_logb_1"],
            [UIImage imageNamed:@"num_logb_2"],
            [UIImage imageNamed:@"num_logb_3"]
        ];
        NSArray *mid2 = @[
            [UIImage imageNamed:@"num_logb_3"],
            [UIImage imageNamed:@"num_logb_2"],
            [UIImage imageNamed:@"num_logb_1"],
            [UIImage imageNamed:@"num_logb_0"],
            [UIImage imageNamed:@"num_logb_9"],
            [UIImage imageNamed:@"num_logb_8"],
            [UIImage imageNamed:@"num_logb_7"],
            [UIImage imageNamed:@"num_logb_6"],
            [UIImage imageNamed:@"num_logb_5"],
            [UIImage imageNamed:@"num_logb_4"]
        ];

        // Thousands reel is blank for bonuses < 1000 (no leading digit).
        _numImgView1000 = [self makeDigitReelForValue:(_bonus / 1000)
                                      animationImages:up
                                               hidden:(_bonus < 1000)];
        _numImgView0100 = [self makeDigitReelForValue:((_bonus % 1000) / 100)
                                      animationImages:down
                                               hidden:NO];
        _numImgView0010 = [self makeDigitReelForValue:((_bonus % 100) / 10)
                                      animationImages:mid1
                                               hidden:NO];
        _numImgView0001 = [self makeDigitReelForValue:(_bonus % 10) animationImages:mid2 hidden:NO];

        // Layout. Ghidra positions the reels relative to the board on phone and at
        // fixed coordinates on iPad; y is 523 on iPad.
        //
        // Phone-idiom per-reel deltas recovered from the const-data floats:
        //   DAT_0001952c / DAT_0001987c = 133.0f (0x43050000) — reel Y offset from
        //   board. DAT_00019530 / DAT_00019880 =  54.0f (0x42580000) — reel-to-reel
        //   X step.
        // The base X delta from board.origin.x is 24.0f (0x41c00000). Each reel's Y
        // is taken from the board (not the previous reel); each reel's X is the
        // previous reel's origin.x + 54.0.
        static constexpr CGFloat kReelBaseXDelta = 24.0f; // 0x41c00000
        static constexpr CGFloat kReelXStep = 54.0f;   // 0x42580000 (DAT_00019530 / DAT_00019880)
        static constexpr CGFloat kReelYDelta = 133.0f; // 0x43050000 (DAT_0001952c / DAT_0001987c)

        BOOL isPad = neSceneManager::isPadDisplay();
        UIImage *digitImg = up.firstObject;
        CGSize dSize = digitImg.size;
        if (isPad) {
            _numImgView1000.frame = CGRectMake(183.0f, 523.0f, dSize.width, dSize.height);
            _numImgView0100.frame = CGRectMake(288.0f, 523.0f, dSize.width, dSize.height);
            _numImgView0010.frame = CGRectMake(398.0f, 523.0f, dSize.width, dSize.height);
            _numImgView0001.frame = CGRectMake(503.0f, 523.0f, dSize.width, dSize.height);
        } else {
            // Phone: reels sit on the board, stepping right by a fixed 54pt each.
            CGRect b = board.frame;
            CGFloat y = b.origin.y + kReelYDelta;
            CGFloat x0 = b.origin.x + kReelBaseXDelta;
            _numImgView1000.frame = CGRectMake(x0, y, dSize.width, dSize.height);
            _numImgView0100.frame = CGRectMake(x0 + kReelXStep, y, dSize.width, dSize.height);
            _numImgView0010.frame =
                CGRectMake(x0 + kReelXStep * 2.0f, y, dSize.width, dSize.height);
            _numImgView0001.frame =
                CGRectMake(x0 + kReelXStep * 3.0f, y, dSize.width, dSize.height);
        }

        [self addSubview:_numImgView1000];
        [self addSubview:_numImgView0100];
        [self addSubview:_numImgView0010];
        [self addSubview:_numImgView0001];
        [_numImgView1000 startAnimating];
        [_numImgView0100 startAnimating];
        [_numImgView0010 startAnimating];
        [_numImgView0001 startAnimating];

        // Full-screen transparent tap catcher.
        UIButton *btn = [[UIButton alloc] initWithFrame:self.frame];
        btn.userInteractionEnabled = YES;
        btn.backgroundColor = [UIColor clearColor];
        [btn addTarget:self
                      action:@selector(touchEvent:)
            forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];

        self.hidden = YES;
    }
    return self;
}

// Build one rolling digit reel; blank (empty image view) when
// hiddenLeadingZero.
- (UIImageView *)makeDigitReelForValue:(int)digit
                       animationImages:(NSArray *)images
                                hidden:(BOOL)hiddenLeadingZero {
    UIImage *face = [UIImage imageNamed:[NSString stringWithFormat:@"num_logb_%d", digit]];
    UIImageView *reel =
        hiddenLeadingZero ? [[UIImageView alloc] init] : [[UIImageView alloc] initWithImage:face];
    reel.animationImages = images;
    reel.animationDuration = 0.5;
    return reel;
}

// @ 0x19884 — stop and release the SE, then up-chain.
//
// @complete
// Verified: -stopSe:_seInstId[0], -stopSe:_seInstId[1], -releaseSe:nil
// resourceId:_seRscId[0], -releaseSe:nil resourceId:_seRscId[1], [super dealloc].
- (void)dealloc {
    AudioManager *audio = [AudioManager sharedManager];
    [audio stopSe:_seInstId[0]];
    [audio stopSe:_seInstId[1]];
    // resourceId args were partially lost in decompilation; releasing the loaded
    // SE resources (roll / fail). _seRscId[2] (close) is also loaded.
    [[AudioManager sharedManager] releaseSe:nil resourceId:_seRscId[0]];
    [[AudioManager sharedManager] releaseSe:nil resourceId:_seRscId[1]];
    // (ARC synthesises [super dealloc]; kept explicit in Ghidra @ 0x19884.)
}

// @ 0x19960 — install over the root scene view, credit the bonus, pop open.
//
// @complete
// Verified: addSubview:self, bringSubviewToFront:self, credit
// (treasurePoint + _bonus only when treasurePoint >= 0, stored as short),
// scale 2.0, hidden = NO, animateWithDuration:0.3 options
// AllowUserInteraction (2); reset block @ 0x19ad8 captures self at +0x14.
- (void)show {
    UIViewController *root = neSceneManager::rootViewController();
    UIView *rootView = root.view;
    [rootView addSubview:self];
    [rootView bringSubviewToFront:self];

    // Credit the rolled bonus immediately.
    short have = [UserSettingData treasurePoint];
    [UserSettingData saveTreasurePoint:(short)((short)_bonus + have)];

    self.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
    self.hidden = NO;
    [UIView animateWithDuration:0.3
        delay:0.0
        options:UIViewAnimationOptionAllowUserInteraction
        animations:^{
          // Ghidra: loginBonusResetTransform @ 0x19ad8 (block-invoke thunk;
          // captured var at +0x14 = self; calls [self setTransform:
          // identity(1.0f)]).
          self.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
        }
        completion:^(BOOL finished) {
          // Ghidra completion @ 0x19b1c — start the looping roll SE for the
          // reels.
          self->_seInstId[0] =
              static_cast<int>([[AudioManager sharedManager] playSe:nil
                                                         resourceId:self->_seRscId[0]]);
        }];
}

// @ 0x19b9c — board tap: first lock the reels (state 0), then close (state !=
// 0).
//
// Fully verified against the disassembly. Guard on _isAnimationing; when
// _state == 0, set _isAnimationing, -stopSe:_seInstId[0], _seInstId[1] =
// -playSe:_seRscId[1], then run four sequential -animateWithDuration:0.5 options
// AllowUserInteraction (2) passes, one per reel (thousands, hundreds, tens,
// ones). Each pass first sends -stopAnimating to its reel, then animates that
// reel up to 2x (the "Up" animation blocks @ 0x19ec4 / 0x1a00c / 0x1a154 /
// 0x1a29c, each -setTransform:scale(2, 2) with self captured at +0x14), and its
// completion (@ 0x19f18 / 0x1a060 / 0x1a1a8 / 0x1a2f0) schedules a nested
// -animateWithDuration:0.5 that springs the same reel back to identity 1x (the
// "Down" blocks @ 0x19fa0 / 0x1a0e8 / 0x1a230 / 0x1a3a0). The first three Down
// animations pass completion:nil; only the fourth reel's Down completion
// (LAB_0001a3f4) does anything — it sets _state = 1 and _isAnimationing = NO and
// returns. The binary does not send -showAlertView from this cascade (verified:
// LAB_0001a3f4 is two ivar stores then bx lr, no msgSend). When _state != 0 the
// tap instead plays system SE 1 and calls -startCloseAnimation.
// @complete
- (void)touchEvent:(id)sender {
    if (_isAnimationing) {
        return;
    }

    if (_state == 0) {
        _isAnimationing = YES;

        // Swap the looping roll SE for the reveal SE.
        [[AudioManager sharedManager] stopSe:_seInstId[0]];
        _seInstId[1] = static_cast<int>([[AudioManager sharedManager] playSe:nil
                                                                  resourceId:_seRscId[1]]);

        // Lock each reel with a staggered scale bounce. Ghidra runs four
        // animateWithDuration:0.5 passes (loginBonusScaleDigit* blocks); the final
        // reel's completion transitions to the "locked" state and shows the alert.
        [_numImgView1000 stopAnimating];
        [UIView animateWithDuration:0.5
            delay:0.0
            options:UIViewAnimationOptionAllowUserInteraction
            animations:^{
              // Ghidra: loginBonusScaleDigit1000Up @ 0x19ec4 (block-invoke thunk;
              // captured +0x14 = self; scales _numImgView1000 to 2.0×).
              self->_numImgView1000.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
            }
            completion:^(BOOL finished) {
              [UIView animateWithDuration:0.5
                                    delay:0.0
                                  options:UIViewAnimationOptionAllowUserInteraction
                               animations:^{
                                 // Ghidra: loginBonusScaleDigit1000Down @ 0x19fa0
                                 // (block-invoke thunk; captured +0x14 = self;
                                 // springs _numImgView1000 back to identity 1.0×).
                                 self->_numImgView1000.transform = CGAffineTransformIdentity;
                               }
                               completion:nil];
            }];

        [_numImgView0100 stopAnimating];
        [UIView animateWithDuration:0.5
            delay:0.0
            options:UIViewAnimationOptionAllowUserInteraction
            animations:^{
              // Up block for 0100-place reel (unnamed in Ghidra; scale 2.0×
              // inferred from loginBonusScaleDigit1000Up pattern, confirmed at
              // binary offset ~0x1a00c).
              self->_numImgView0100.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
            }
            completion:^(BOOL finished) {
              [UIView animateWithDuration:0.5
                                    delay:0.0
                                  options:UIViewAnimationOptionAllowUserInteraction
                               animations:^{
                                 // Ghidra: loginBonusScaleDigit0100 @ 0x1a0e8
                                 // (block-invoke thunk; captured +0x14 = self;
                                 // springs _numImgView0100 back to identity 1.0×).
                                 self->_numImgView0100.transform = CGAffineTransformIdentity;
                               }
                               completion:nil];
            }];

        [_numImgView0010 stopAnimating];
        [UIView animateWithDuration:0.5
            delay:0.0
            options:UIViewAnimationOptionAllowUserInteraction
            animations:^{
              // Up block for 0010-place reel (unnamed in Ghidra; scale 2.0×
              // inferred from loginBonusScaleDigit1000Up pattern, confirmed at
              // binary offset ~0x1a154).
              self->_numImgView0010.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
            }
            completion:^(BOOL finished) {
              [UIView animateWithDuration:0.5
                                    delay:0.0
                                  options:UIViewAnimationOptionAllowUserInteraction
                               animations:^{
                                 // Ghidra: loginBonusScaleDigit0010 @ 0x1a230
                                 // (block-invoke thunk; captured +0x14 = self;
                                 // springs _numImgView0010 back to identity 1.0×).
                                 self->_numImgView0010.transform = CGAffineTransformIdentity;
                               }
                               completion:nil];
            }];

        [_numImgView0001 stopAnimating];
        [UIView animateWithDuration:0.5
            delay:0.0
            options:UIViewAnimationOptionAllowUserInteraction
            animations:^{
              // Up block for 0001-place reel (unnamed in Ghidra; scale 2.0×
              // inferred from loginBonusScaleDigit1000Up pattern, confirmed at
              // binary offset ~0x1a29c).
              self->_numImgView0001.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
            }
            completion:^(BOOL finished) {
              [UIView animateWithDuration:0.5
                  delay:0.0
                  options:UIViewAnimationOptionAllowUserInteraction
                  animations:^{
                    // Ghidra: loginBonusScaleDigit0001 @ 0x1a3a0 (block-invoke
                    // thunk; captured +0x14 = self; springs _numImgView0001 back to
                    // identity 1.0×).
                    self->_numImgView0001.transform = CGAffineTransformIdentity;
                  }
                  completion:^(BOOL fin) {
                    // Ghidra terminal completion LAB_0001a3f4 — reels locked.
                    // Two ivar stores only (no msgSend in the binary): mark the
                    // reels locked and clear the animation guard.
                    self->_state = 1;
                    self->_isAnimationing = NO;
                  }];
            }];
    } else {
        neEngine::playSystemSe(1);
        [self startCloseAnimation];
    }
}

// @ 0x1a448 — fade the overlay out; -endCloseAnimation runs when it stops.
//
// @complete
- (void)startCloseAnimation {
    if (_isAnimationing) {
        return;
    }
    _isAnimationing = YES;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.alpha = 0.0f;
    [UIView commitAnimations];
}

// @ 0x1a508 — remove self and notify the root scene it was dismissed.
//
// @complete
// The binary sends -customAlertView:clickedButtonAtIndex: unconditionally
// (no -respondsToSelector: guard is emitted @ 0x1a508); the root scene is
// always the outer delegate.
- (void)endCloseAnimation {
    [self removeFromSuperview];
    UIViewController *root = neSceneManager::rootViewController();
    // The root scene acts as the outer delegate (index 0 = dismissed).
    [(id)root customAlertView:nil clickedButtonAtIndex:0];
    _isAnimationing = NO;
}

// @ 0x1a558 — report the rolled bonus in a gift-styled CustomAlertView.
//
// @complete
// Title/message CFStrings verified: "ログインボーナス" @ 0x12b94c and
// "トレジャーポイントをGET！\n[%dP]" @ 0x12b95e; type 1 (Gift), otherButton
// "OK", -setOpenAnimeType:1 (Scale).
- (void)showAlertView {
    // UTF-16 CFStrings recovered from the binary:
    //   title   @ 0x00134c18 -> data 0x0012b94c : "ログインボーナス"
    //   message @ 0x00134c28 -> data 0x0012b95e :
    //   "トレジャーポイントをGET！\n[%dP]"
    NSString *title = [NSString stringWithFormat:@"ログインボーナス"];
    NSString *message = [NSString stringWithFormat:@"トレジャーポイントをGET！\n[%dP]", _bonus];

    CustomAlertView *alert = [[CustomAlertView alloc] initWithView:self
                                                              type:CustomAlertViewTypeGift
                                                             title:title
                                                           message:message
                                                 cancelButtonTitle:nil
                                                  otherButtonTitle:@"OK"];
    alert.delegate = self;
    [alert setOpenAnimeType:CustomAlertViewAnimeTypeScale];
    [alert show];
}

// @ 0x1a650 — CustomAlertViewDelegate: fade the dimmer away, then remove.
//
// @complete
// Verified: background white alpha 0, animateWithDuration:0.3 options
// AllowUserInteraction (2); collapse block @ 0x1a740 sends
// -setTransform:(0,0,0,0,0,0) on self (captured at +0x14); completion removes.
- (void)customAlertView:(CustomAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    self.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.0f];
    [UIView animateWithDuration:0.3
        delay:0.0
        options:UIViewAnimationOptionAllowUserInteraction
        animations:^{
          // Ghidra: loginBonusCollapseTransform @ 0x1a740 (block-invoke thunk;
          // captured +0x14 = self; collapses view to a zero-area point via
          // degenerate all-zero CGAffineTransform — confirmed from Ghidra
          // setTransform(0,0,0,0,0,0) call; previous reconstruction used
          // self.alpha which was wrong).
          self.transform = CGAffineTransformMake(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
        }
        completion:^(BOOL finished) {
          [self removeFromSuperview];
        }];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
