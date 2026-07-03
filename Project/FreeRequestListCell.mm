//
//  FreeRequestListCell.mm
//  pop'n rhythmin
//
//  See FreeRequestListCell.h. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Objective-C++ for the neSceneManager::isPadDisplay() device check.
//

#import "FreeRequestListCell.h"

#import "neEngineBridge.h"   // neSceneManager::isPadDisplay
#import "AppDelegate.h"      // +appAppSupportDirectory (downloaded chara icons)

@implementation FreeRequestListCell {
    // Built lazily in setFriendData:rank: and torn down on reuse; each is owned by its
    // superview, so none is released in dealloc.
    UIImageView *_bgImgView;
    UIImageView *_charaBgImgView;
    UIImageView *_charaImgView;
    UIImageView *_scoreBaseImgView;
    UILabel *_playerNameLbl;
    UILabel *_scoreLbl;

    BOOL isOS7;
    int imgCharaX;
    int imgPlayerNameX;
    int imgScoreBaseX;
    int imgScoreX;
}

// @ 0xe49c4 — record the layout x offsets for the chara icon / player name / score plate /
// score, which shift between iOS 6/7 and phone/pad.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    CGFloat ver = UIDevice.currentDevice.systemVersion.floatValue;
    isOS7 = ver >= 7.0f;
    if (ver < 7.0f) {
        if (!neSceneManager::isPadDisplay()) {
            imgCharaX = 0x12; imgPlayerNameX = 0x5a; imgScoreBaseX = 0x53; imgScoreX = 0;
        } else {
            imgCharaX = 0x17; imgPlayerNameX = 0x5f; imgScoreBaseX = 0x58; imgScoreX = 5;
        }
    } else {
        imgCharaX = 0x17; imgPlayerNameX = 0x6b; imgScoreBaseX = 100; imgScoreX = 0x11;
    }
    return self;
}

// @ 0xe4b60 — rebuild the row from a FreeRequestDataStruct. Rebuilt on every reuse. Every subview
// is added to the background plate (_bgImgView); on phone the plate is installed as the cell's
// backgroundView, on pad it is added to the content view (shifted -10px on iOS 6).
- (void)setFriendData:(NSValue *)friendData rank:(int)rank {
    FreeRequestDataStruct data;
    [friendData getValue:&data];

    // Reuse teardown.
    if (_bgImgView)        { [_bgImgView removeFromSuperview];        _bgImgView = nil; }
    if (_charaBgImgView)   { [_charaBgImgView removeFromSuperview];   _charaBgImgView = nil; }
    if (_charaImgView)     { [_charaImgView removeFromSuperview];     _charaImgView = nil; }
    if (_playerNameLbl)    { [_playerNameLbl removeFromSuperview];    _playerNameLbl = nil; }
    if (_scoreBaseImgView) { [_scoreBaseImgView removeFromSuperview]; _scoreBaseImgView = nil; }
    if (_scoreLbl)         { [_scoreLbl removeFromSuperview];         _scoreLbl = nil; }

    // Row background plate.
    _bgImgView = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *bgImg = [UIImage imageNamed:@"frisco_base_others"];
    [_bgImgView setImage:bgImg];
    if (!neSceneManager::isPadDisplay()) {
        [_bgImgView setFrame:CGRectMake(0, 0, bgImg.size.width, bgImg.size.height)];
        [self setBackgroundView:_bgImgView];
    } else {
        CGFloat x = (UIDevice.currentDevice.systemVersion.floatValue >= 7.0f) ? 0.0f : -10.0f;
        [_bgImgView setFrame:CGRectMake(x, 0, bgImg.size.width, bgImg.size.height)];
        [self.contentView addSubview:_bgImgView];
    }
    self.backgroundColor = [UIColor clearColor];

    // Chara icon backing plate.
    _charaBgImgView = [[UIImageView alloc]
        initWithFrame:CGRectMake((CGFloat)imgCharaX, 5.0f, 43.0f, 43.0f)];
    [_charaBgImgView setImage:[UIImage imageNamed:@"frisco_icon_cmn"]];
    [_bgImgView addSubview:_charaBgImgView];

    // Chara icon (built-in charas from the bundle, downloaded ones from the app-support dir).
    _charaImgView = [[UIImageView alloc]
        initWithFrame:CGRectMake((CGFloat)imgCharaX, 5.0f, 43.0f, 43.0f)];
    short charaId = data.charaId;
    if (charaId < 0) {
        charaId = 0;
    }
    NSString *iconFile = [NSString stringWithFormat:@"sgc_icon_%03d.png", (int)charaId];
    UIImage *icon = (charaId < 0x1e)
        ? [UIImage imageNamed:iconFile]
        : [UIImage imageWithContentsOfFile:
              [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:iconFile]];
    [_charaImgView setImage:icon];
    [_bgImgView addSubview:_charaImgView];

    // Player name (BullyBold 14, dark gray rgb 93/88/84).
    _playerNameLbl = [[UILabel alloc]
        initWithFrame:CGRectMake((CGFloat)imgPlayerNameX, 5.0f, 180.0f, 20.0f)];
    _playerNameLbl.backgroundColor = [UIColor clearColor];
    _playerNameLbl.textColor = [UIColor colorWithRed:0.36470f green:0.34510f
                                                blue:0.32941f alpha:1.0f];
    _playerNameLbl.highlightedTextColor = [UIColor whiteColor];
    _playerNameLbl.font = [UIFont fontWithName:@"BullyBold" size:14.0f];
    _playerNameLbl.textAlignment = NSTextAlignmentLeft;
    _playerNameLbl.adjustsFontSizeToFitWidth = YES;
    [_playerNameLbl setMinimumScaleFactor:14.0f];   // verbatim from the binary
    _playerNameLbl.text = data.name;
    [_bgImgView addSubview:_playerNameLbl];

    // Score plate.
    _scoreBaseImgView = [[UIImageView alloc]
        initWithFrame:CGRectMake((CGFloat)imgScoreBaseX, 24.0f, 190.0f, 20.0f)];
    [_scoreBaseImgView setImage:[UIImage imageNamed:@"frilis_scototal_cmn"]];
    [_bgImgView addSubview:_scoreBaseImgView];

    // Score value (BullyBold 18, right-aligned).
    _scoreLbl = [[UILabel alloc]
        initWithFrame:CGRectMake((CGFloat)imgScoreX, 25.0f, 262.0f, 20.0f)];
    _scoreLbl.backgroundColor = [UIColor clearColor];
    _scoreLbl.textColor = [UIColor colorWithRed:0.36470f green:0.34510f
                                           blue:0.32941f alpha:1.0f];
    _scoreLbl.highlightedTextColor = [UIColor whiteColor];
    _scoreLbl.font = [UIFont fontWithName:@"BullyBold" size:18.0f];
    _scoreLbl.textAlignment = NSTextAlignmentRight;
    _scoreLbl.text = [NSString stringWithFormat:@"%d", data.score];
    [_bgImgView addSubview:_scoreLbl];
}

// dealloc @ 0xe4b34 — ARC-omitted (chains to super only; every subview is owned by its
// superview, so nothing is released here).

@end
