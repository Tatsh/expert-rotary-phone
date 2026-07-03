//
//  FriendReplyCell.mm
//  pop'n rhythmin
//
//  See FriendReplyCell.h. Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0xa9150, setReplyData: @ 0xa92ac, onTouchedOkButton @ 0xa9cf0,
//  onTouchedNgButton @ 0xa9d58). Objective-C++ for the neEngine SE + device check.
//

#import "FriendReplyCell.h"

#import "neEngineBridge.h"     // neEngine::playSystemSe, neSceneManager::isPadDisplay
#import "AppDelegate.h"        // +appAppSupportDirectory
#import "AppFont.h"            // AppFontName()

@implementation FriendReplyCell {
    BOOL _isOS7;
    int _imgCharaX, _imgPlayerNameX, _dateX, _btnYesX, _btnNoX;

    NSValue *_replyData;          // current row (assign; owned by the controller's array)
    UIImageView *_bgImgView;
    UIImageView *_charaBgView;
    UIImageView *_charaView;
    UILabel *_playerNameLabel;
    UILabel *_requestDateLabel;
    UIButton *_okButton;          // accept
    UIButton *_ngButton;          // reject
}
@synthesize delegate = _delegate;

// @ 0xa9150 — record the chara / name / date / yes / no subview x offsets (they shift on iOS 7).
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    if (!_isOS7) {
        _imgCharaX = 0x17; _imgPlayerNameX = 0x46; _dateX = 0x46; _btnYesX = 0xd0; _btnNoX = 0x85;
    } else {
        _imgCharaX = 0x19; _imgPlayerNameX = 0x48; _dateX = 0x48; _btnYesX = 0xe1; _btnNoX = 0x96;
    }
    return self;
}

// @ 0xa92ac — build the row from a ReplyDataStruct. Rebuilt on every reuse.
- (void)setReplyData:(NSValue *)replyData {
    _replyData = replyData;
    ReplyDataStruct data;
    [replyData getValue:&data];

    const BOOL isPad = neSceneManager::isPadDisplay();
    // Pre-iOS7 iPad metrics nudge the whole row 10pt left.
    const int padOffset = (isPad && UIDevice.currentDevice.systemVersion.floatValue < 7.0f) ? -10 : 0;

    // Reuse teardown.
    if (_bgImgView)        { [_bgImgView removeFromSuperview];        _bgImgView = nil; }
    if (_charaBgView)      { [_charaBgView removeFromSuperview];      _charaBgView = nil; }
    if (_charaView)        { [_charaView removeFromSuperview];        _charaView = nil; }
    if (_playerNameLabel)  { [_playerNameLabel removeFromSuperview];  _playerNameLabel = nil; }
    if (_requestDateLabel) { [_requestDateLabel removeFromSuperview]; _requestDateLabel = nil; }
    if (_okButton)         { [_okButton removeFromSuperview];         _okButton = nil; }
    if (_ngButton)         { [_ngButton removeFromSuperview];         _ngButton = nil; }

    // Row background: cell backgroundView on phone; content-view subview on iPad.
    _bgImgView = [[[UIImageView alloc] initWithFrame:self.bounds] autorelease];
    UIImage *bgImg = [UIImage imageNamed:@"frirep_base"];
    [_bgImgView setImage:bgImg];
    [_bgImgView setFrame:CGRectMake(padOffset, 0, bgImg.size.width, bgImg.size.height)];
    if (!isPad) {
        [self setBackgroundView:_bgImgView];
    } else {
        [self.contentView addSubview:_bgImgView];
    }
    self.backgroundColor = [UIColor clearColor];

    // Chara icon plate + icon (built-in charas from the bundle, downloaded from disk).
    _charaBgView = [[[UIImageView alloc] init] autorelease];
    UIImage *plate = [UIImage imageNamed:@"frisco_icon_cmn"];
    [_charaBgView setImage:plate];
    [_charaBgView setFrame:CGRectMake((CGFloat)_imgCharaX, 7.0f, plate.size.width, plate.size.height)];
    [_bgImgView addSubview:_charaBgView];

    _charaView = [[[UIImageView alloc] init] autorelease];
    short charaId = data.charaId;
    if (charaId < 0) {
        charaId = 0;
    }
    NSString *iconFile = [NSString stringWithFormat:@"sgc_icon_%03d.png", (int)charaId];
    UIImage *icon = (charaId < 0x1e)
        ? [UIImage imageNamed:iconFile]
        : [UIImage imageWithContentsOfFile:
              [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:iconFile]];
    [_charaView setImage:icon];
    [_charaView setFrame:CGRectMake((CGFloat)_imgCharaX, 7.0f, 43.0f, 43.0f)];
    [_bgImgView addSubview:_charaView];

    // Requester name.
    _playerNameLabel = [[[UILabel alloc]
        initWithFrame:CGRectMake((CGFloat)_imgPlayerNameX, 5.0f, 200.0f, 20.0f)] autorelease];
    _playerNameLabel.backgroundColor = [UIColor clearColor];
    _playerNameLabel.textColor = [UIColor colorWithRed:0.36458503f green:0.34506654f
                                                  blue:0.32941106f alpha:1.0f];   // rgb(93,88,84)
    _playerNameLabel.highlightedTextColor = [UIColor whiteColor];
    _playerNameLabel.font = [UIFont fontWithName:AppFontName() size:15.0f];
    _playerNameLabel.textAlignment = NSTextAlignmentLeft;
    _playerNameLabel.adjustsFontSizeToFitWidth = YES;
    [_playerNameLabel setMinimumScaleFactor:16.0f];   // verbatim (see FriendListCell note)
    _playerNameLabel.text = data.name;
    [_bgImgView addSubview:_playerNameLabel];

    // Request date.
    _requestDateLabel = [[[UILabel alloc]
        initWithFrame:CGRectMake((CGFloat)_dateX, 25.0f, 200.0f, 20.0f)] autorelease];
    _requestDateLabel.backgroundColor = [UIColor clearColor];
    _requestDateLabel.textColor = [UIColor colorWithRed:0.36458503f green:0.34506654f
                                                   blue:0.32941106f alpha:1.0f];
    _requestDateLabel.highlightedTextColor = [UIColor whiteColor];
    _requestDateLabel.font = [UIFont fontWithName:AppFontName() size:14.0f];
    _requestDateLabel.textAlignment = NSTextAlignmentLeft;
    _requestDateLabel.adjustsFontSizeToFitWidth = YES;
    [_requestDateLabel setMinimumScaleFactor:14.0f];
    _requestDateLabel.text = data.date;
    [_bgImgView addSubview:_requestDateLabel];

    // NG (reject) button.
    _ngButton = [[[UIButton alloc] init] autorelease];
    UIImage *ngImg = [UIImage imageNamed:@"frirep_btn_no"];
    [_ngButton setBackgroundImage:ngImg forState:UIControlStateNormal];
    [_ngButton setFrame:CGRectMake((CGFloat)(_btnNoX + padOffset), 43.0f,
                                   ngImg.size.width, ngImg.size.height)];
    [_ngButton addTarget:self action:@selector(onTouchedNgButton)
        forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:_ngButton];

    // OK (accept) button.
    _okButton = [[[UIButton alloc] init] autorelease];
    UIImage *okImg = [UIImage imageNamed:@"frirep_btn_ok"];
    [_okButton setBackgroundImage:okImg forState:UIControlStateNormal];
    [_okButton setFrame:CGRectMake((CGFloat)(_btnYesX + padOffset), 43.0f,
                                   okImg.size.width, okImg.size.height)];
    [_okButton setUserInteractionEnabled:YES];
    [_okButton addTarget:self action:@selector(onTouchedOkButton)
        forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:_okButton];
}

// @ 0xa9cf0 — accept: reply == 1.
- (void)onTouchedOkButton {
    neEngine::playSystemSe(1);
    if (_delegate != nil) {
        ReplyDataStruct data;
        [_replyData getValue:&data];
        [_delegate startReplyFriendHttp:data.playerId reply:1];
    }
}

// @ 0xa9d58 — reject: reply == 0.
- (void)onTouchedNgButton {
    neEngine::playSystemSe(1);
    if (_delegate != nil) {
        ReplyDataStruct data;
        [_replyData getValue:&data];
        [_delegate startReplyFriendHttp:data.playerId reply:0];
    }
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
