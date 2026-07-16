//
//  FriendRequestCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "FriendRequestCell.h"

#import "AppDelegate.h"    // +appAppSupportDirectory (downloaded chara icons)
#import "AppFont.h"        // AppFontName()
#import "DownloadMain.h"   // +getInstance / -startCancelFriendHttp:
#import "neEngineBridge.h" // neEngine::playSystemSe (cancel SE)

@implementation FriendRequestCell {
    BOOL _isOS7;
    int _imgCharaX;
    int _imgPlayerNameX;
    int _imgDateX;
    int _btnCancelX;

    NSString *_friendPlayerId; // requester id, kept for the cancel request

    // Built lazily in setFriendData: and torn down on reuse. Every one is owned
    // by its superview, so none is released in dealloc.
    UIImageView *_charaBgImgView;
    UIImageView *_charaImgView;
    UILabel *_playerNameLbl;
    UILabel *_requestDateLbl;
    UIButton *_cancelButton;
}

// @ 0xb9740 — record the layout x offsets for the chara icon / player name /
// date / cancel button, which shift by ~2 px on iOS 7 vs 6.
// @complete
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    if (!_isOS7) {
        _imgCharaX = 0x17;
        _imgPlayerNameX = 0x46;
        _imgDateX = 0x46;
        _btnCancelX = 0xc6;
    } else {
        _imgCharaX = 0x19;
        _imgPlayerNameX = 0x48;
        _imgDateX = 0x48;
        _btnCancelX = 0xd0;
    }
    return self;
}

// @ 0xb987c — build the row from a FriendRequestDataStruct. Rebuilt on every
// reuse. Everything is added to the content view; the background art is
// installed as the cell's backgroundView.
// Verified against the disassembly: the charaId `sxth; cmp #0x1d; bgt` split
// (bundle for <= 0x1d, app-support otherwise), the negative-charaId clamp
// (`cmp #0; it lt; mov.lt #0`), the rgb(93,88,84) label colours
// (0x3ebababb/0x3eb0b0b1/0x3ea8a8a9), the name font 0x41600000 (14.0) / date
// font 0x41700000 (15.0), and setMinimumScaleFactor:0x41700000 (15.0).
// @complete
- (void)setFriendData:(NSValue *)friendData {
    FriendRequestDataStruct data;
    [friendData getValue:&data];
    _friendPlayerId = data.playerId;

    // Reuse teardown.
    if (_charaBgImgView) {
        [_charaBgImgView removeFromSuperview];
        _charaBgImgView = nil;
    }
    if (_charaImgView) {
        [_charaImgView removeFromSuperview];
        _charaImgView = nil;
    }
    if (_playerNameLbl) {
        [_playerNameLbl removeFromSuperview];
        _playerNameLbl = nil;
    }
    if (_requestDateLbl) {
        [_requestDateLbl removeFromSuperview];
        _requestDateLbl = nil;
    }
    if (_cancelButton) {
        [_cancelButton removeFromSuperview];
        _cancelButton = nil;
    }

    // Row background (installed as the cell's backgroundView).
    UIImageView *bgImgView = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *bgImg = [UIImage imageNamed:@"frisco_base_others"];
    [bgImgView setImage:bgImg];
    [bgImgView setFrame:CGRectMake(0, 0, bgImg.size.width, bgImg.size.height)];
    [self setBackgroundView:bgImgView];
    self.backgroundColor = [UIColor clearColor];

    // Chara icon backing plate.
    _charaBgImgView =
        [[UIImageView alloc] initWithFrame:CGRectMake((CGFloat)_imgCharaX, 7.0f, 43.0f, 43.0f)];
    [_charaBgImgView setImage:[UIImage imageNamed:@"frisco_icon_cmn"]];
    [self.contentView addSubview:_charaBgImgView];

    // Chara icon (built-in charas from the bundle, downloaded ones from the
    // app-support dir).
    _charaImgView =
        [[UIImageView alloc] initWithFrame:CGRectMake((CGFloat)_imgCharaX, 7.0f, 43.0f, 43.0f)];
    short charaId = data.charaId;
    if (charaId < 0) {
        charaId = 0;
    }
    NSString *iconFile = [NSString stringWithFormat:@"sgc_icon_%03d.png", (int)charaId];
    UIImage *icon =
        (charaId < 0x1e) ?
            [UIImage imageNamed:iconFile] :
            [UIImage imageWithContentsOfFile:[[AppDelegate appAppSupportDirectory]
                                                 stringByAppendingPathComponent:iconFile]];
    [_charaImgView setImage:icon];
    [self.contentView addSubview:_charaImgView];

    // Requester name.
    _playerNameLbl =
        [[UILabel alloc] initWithFrame:CGRectMake((CGFloat)_imgPlayerNameX, 5.0f, 200.0f, 20.0f)];
    _playerNameLbl.backgroundColor = [UIColor clearColor];
    _playerNameLbl.textColor = [UIColor colorWithRed:0.36458503f
                                               green:0.34506654f
                                                blue:0.32941106f
                                               alpha:1.0f]; // rgb(93,88,84)
    _playerNameLbl.highlightedTextColor = [UIColor whiteColor];
    _playerNameLbl.font = [UIFont fontWithName:AppFontName() size:14.0f];
    _playerNameLbl.textAlignment = NSTextAlignmentLeft;
    _playerNameLbl.adjustsFontSizeToFitWidth = YES;
    [_playerNameLbl setMinimumScaleFactor:15.0f]; // verbatim (see FriendScoreTableCell note)
    _playerNameLbl.text = data.name;
    [self.contentView addSubview:_playerNameLbl];

    // Request date (no font-shrink on this label, unlike the name).
    _requestDateLbl =
        [[UILabel alloc] initWithFrame:CGRectMake((CGFloat)_imgDateX, 34.0f, 200.0f, 20.0f)];
    _requestDateLbl.backgroundColor = [UIColor clearColor];
    _requestDateLbl.textColor = [UIColor colorWithRed:0.36458503f
                                                green:0.34506654f
                                                 blue:0.32941106f
                                                alpha:1.0f];
    _requestDateLbl.highlightedTextColor = [UIColor whiteColor];
    _requestDateLbl.font = [UIFont fontWithName:AppFontName() size:15.0f];
    _requestDateLbl.textAlignment = NSTextAlignmentLeft;
    _requestDateLbl.text = data.date;
    [self.contentView addSubview:_requestDateLbl];

    // Cancel button.
    _cancelButton = [[UIButton alloc] init];
    UIImage *cancelImg = [UIImage imageNamed:@"fripre_btn_cancel"];
    [_cancelButton setBackgroundImage:cancelImg forState:UIControlStateNormal];
    [_cancelButton
        setFrame:CGRectMake(
                     (CGFloat)_btnCancelX, 24.0f, cancelImg.size.width, cancelImg.size.height)];
    [_cancelButton addTarget:self
                      action:@selector(onTouchedCancelButton)
            forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:_cancelButton];
}

// @ 0xba048 — cancel this outgoing friend request.
// @complete
- (void)onTouchedCancelButton {
    // Ghidra: NESceneManager_shared(); SysSePlayIntoSlot(&g_pNeSceneManager, 2) —
    // cancel SE.
    neEngine::playSystemSe(2);
    [[DownloadMain getInstance] startCancelFriendHttp:_friendPlayerId];
}

// dealloc @ 0xb9850 — ARC-omitted (chains to super only; every subview is owned
// by its superview, so nothing is released here).

@end
