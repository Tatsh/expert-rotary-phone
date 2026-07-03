//
//  FriendListCell.mm
//  pop'n rhythmin
//
//  A friend-list ranking row; subview x-offsets have three layouts (phone iOS 6,
//  phone iOS 7, iPad). Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0xb3234, setFriendData:rank:isBestScoreSort: @ 0xb34c0).
//  Objective-C++ for the neSceneManager::isPadDisplay() device check.
//

#import "FriendListCell.h"

#import "neEngineBridge.h"      // neSceneManager::isPadDisplay
#import "DownloadMain.h"        // FriendListData
#import "AppDelegate.h"         // +appAppSupportDirectory (downloaded chara icons)
#import "AppFont.h"             // AppFontName()

// Rank "place" badges (1st..9th) used for rows 0..8; two-digit rows compose these digits.
static NSString *const kRankPlaceImg[9] = {
    @"frisco_ranknum_1st", @"frisco_ranknum_2nd", @"frisco_ranknum_3rd",
    @"frisco_ranknum_4th", @"frisco_ranknum_5th", @"frisco_ranknum_6th",
    @"frisco_ranknum_7th", @"frisco_ranknum_8th", @"frisco_ranknum_9th",
};
static NSString *const kRankDigitImg[10] = {
    @"frisco_ranknum_0", @"frisco_ranknum_1", @"frisco_ranknum_2", @"frisco_ranknum_3",
    @"frisco_ranknum_4", @"frisco_ranknum_5", @"frisco_ranknum_6", @"frisco_ranknum_7",
    @"frisco_ranknum_8", @"frisco_ranknum_9",
};
// Chara-icon backing plate: gold/silver/bronze for the top three, common for the rest.
static NSString *const kCharaIconBg[3] = {
    @"frisco_icon_1st", @"frisco_icon_2nd", @"frisco_icon_3rd",
};
// Score plaque, keyed by place (1st/2nd/3rd/common), separate art for total vs. best-score sort.
static NSString *const kScoreTotalImg[4] = {
    @"frilis_scototal_1st", @"frilis_scototal_2nd", @"frilis_scototal_3rd", @"frilis_scototal_cmn",
};
static NSString *const kScoreBestImg[4] = {
    @"frilis_scobest_1st", @"frilis_scobest_2nd", @"frilis_scobest_3rd", @"frilis_scobest_cmn",
};

@implementation FriendListCell {
    BOOL _isOS7;
    int _imgYouX, _imgFrameX, _imgFrame10X, _imgFrame01X, _imgOrderX, _imgCharaX;
    int _imgPlayerNameX, _imgScoreBaseX, _imgScoreX;

    // Built lazily in setFriendData:rank:isBestScoreSort: and torn down on reuse. Each is added
    // to a superview (which owns it) and nilled on reuse; ARC needs no explicit dealloc.
    UIImageView *_bgImgView;
    UIImageView *_youImgView;
    UIImageView *_rankImgView01;   // ones digit / single place badge
    UIImageView *_rankImgView10;   // tens digit (rows >= 9 only)
    UIImageView *_charaBgImgView;
    UIImageView *_charaImgView;
    UILabel *_playerNameLbl;
    UIImageView *_scoreBaseImgView;
    UILabel *_scoreLbl;
}

// @ 0xb3234 — three layouts: iPad, or phone by iOS version.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    if (!neSceneManager::isPadDisplay()) {
        if (!_isOS7) {
            _imgYouX = 0xe8; _imgFrameX = 0xd; _imgFrame10X = 0xe; _imgFrame01X = 0x1d;
            _imgOrderX = 0x2b; _imgCharaX = 0x2b; _imgPlayerNameX = 0x5b; _imgScoreBaseX = 0x58;
            _imgScoreX = 10;
        } else {
            _imgYouX = 0xfb; _imgFrameX = 0x14; _imgFrame10X = 0x15; _imgFrame01X = 0x24;
            _imgOrderX = 0x32; _imgCharaX = 0x32; _imgPlayerNameX = 0x62; _imgScoreBaseX = 0x5f;
            _imgScoreX = 0x11;
        }
    } else {
        _imgYouX = 0xfa; _imgFrameX = 0x17; _imgFrame10X = 0x18; _imgFrame01X = 0x27;
        _imgOrderX = 0x3f; _imgCharaX = 0x3f; _imgPlayerNameX = 0x6f; _imgScoreBaseX = 0x6c;
        _imgScoreX = 0x1e;
    }
    return self;
}

// @ 0xb34c0 — render one ranking row from an NSValue-wrapped FriendListData. `rank` is the
// 0-based row (0 == 1st place); `isBestScoreSort` selects which score/plaque to show. The self
// row (the local player) has a nil playerId and gets the "you" marker. Called on every reuse, so
// it first strips any subviews it built last time.
- (void)setFriendData:(NSValue *)friendData rank:(int)rank isBestScoreSort:(BOOL)isBestScoreSort {
    FriendListData data;
    [friendData getValue:&data];

    const BOOL isPad = neSceneManager::isPadDisplay();

    // Reuse teardown.
    if (_bgImgView)        { [_bgImgView removeFromSuperview];        _bgImgView = nil; }
    if (_youImgView)       { [_youImgView removeFromSuperview];       _youImgView = nil; }
    if (_rankImgView01)    { [_rankImgView01 removeFromSuperview];    _rankImgView01 = nil; }
    if (_rankImgView10)    { [_rankImgView10 removeFromSuperview];    _rankImgView10 = nil; }
    if (_charaBgImgView)   { [_charaBgImgView removeFromSuperview];   _charaBgImgView = nil; }
    if (_charaImgView)     { [_charaImgView removeFromSuperview];     _charaImgView = nil; }
    if (_playerNameLbl)    { [_playerNameLbl removeFromSuperview];    _playerNameLbl = nil; }
    if (_scoreBaseImgView) { [_scoreBaseImgView removeFromSuperview]; _scoreBaseImgView = nil; }
    if (_scoreLbl)         { [_scoreLbl removeFromSuperview];         _scoreLbl = nil; }

    // Row background: on phone it is the cell's backgroundView; on iPad it is a plain subview of
    // the content view (shifted left 10pt on the pre-iOS7 metrics) and also acts as the parent for
    // every other element (so the whole row moves as a unit).
    _bgImgView = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *bgImg = [UIImage imageNamed:@"frisco_base_others"];
    [_bgImgView setImage:bgImg];
    if (!isPad) {
        [_bgImgView setFrame:CGRectMake(0, 0, bgImg.size.width, bgImg.size.height)];
        [self setBackgroundView:_bgImgView];
    } else {
        CGFloat bgX = (!_isOS7) ? -10.0f : 0.0f;
        [_bgImgView setFrame:CGRectMake(bgX, 0, bgImg.size.width, bgImg.size.height)];
        [self.contentView addSubview:_bgImgView];
    }
    self.backgroundColor = [UIColor clearColor];

    // Everything else parents to the content view on phone, or the background image on iPad.
    UIView *parent = isPad ? _bgImgView : self.contentView;

    // "You" marker — only the local player's row (nil playerId).
    if (data.playerId == nil) {
        UIImage *youImg = [UIImage imageNamed:@"frisco_you"];
        _youImgView = [[UIImageView alloc] initWithFrame:self.bounds];
        [_youImgView setImage:youImg];
        [_youImgView setFrame:CGRectMake((CGFloat)_imgYouX, 0, youImg.size.width, youImg.size.height)];
        [parent addSubview:_youImgView];
    }

    // Rank badge: rows 0..8 use a single "place" badge; rows 9+ compose two digit glyphs from the
    // one-based place number (row 9 -> "10").
    if (rank < 9) {
        int idx = (rank > 8) ? 8 : rank;
        UIImage *img = [UIImage imageNamed:kRankPlaceImg[idx]];
        _rankImgView01 = [[UIImageView alloc] init];
        [_rankImgView01 setImage:img];
        [_rankImgView01 setFrame:CGRectMake((CGFloat)_imgFrameX, 12.0f, img.size.width, img.size.height)];
        [parent addSubview:_rankImgView01];
    } else {
        int place = rank + 1;
        UIImage *ones = [UIImage imageNamed:kRankDigitImg[place % 10]];
        _rankImgView01 = [[UIImageView alloc] init];
        [_rankImgView01 setImage:ones];
        [_rankImgView01 setFrame:CGRectMake((CGFloat)_imgFrame01X, 12.0f, ones.size.width, ones.size.height)];
        [parent addSubview:_rankImgView01];

        UIImage *tens = [UIImage imageNamed:kRankDigitImg[(place / 10) % 10]];
        _rankImgView10 = [[UIImageView alloc] init];
        [_rankImgView10 setImage:tens];
        [_rankImgView10 setFrame:CGRectMake((CGFloat)_imgFrame10X, 12.0f, tens.size.width, tens.size.height)];
        [parent addSubview:_rankImgView10];
    }

    // Chara icon backing plate (gold/silver/bronze for top 3, common otherwise).
    _charaBgImgView = [[UIImageView alloc]
        initWithFrame:CGRectMake((CGFloat)_imgOrderX, 5.0f, 43.0f, 43.0f)];
    [_charaBgImgView setImage:[UIImage imageNamed:(rank < 3 ? kCharaIconBg[rank] : @"frisco_icon_cmn")]];
    [parent addSubview:_charaBgImgView];

    // Chara icon. Built-in charas (id <= 29) ship in the bundle; downloaded charas load from the
    // Application Support directory.
    _charaImgView = [[UIImageView alloc]
        initWithFrame:CGRectMake((CGFloat)_imgCharaX, 5.0f, 43.0f, 43.0f)];
    short charaId = data.charaId;
    if (charaId < 0) {
        charaId = 0;
    }
    NSString *charaFile = [NSString stringWithFormat:@"sgc_icon_%03d.png", (int)charaId];
    UIImage *charaImg;
    if (charaId > 0x1d) {
        NSString *path = [[AppDelegate appAppSupportDirectory]
            stringByAppendingPathComponent:charaFile];
        charaImg = [UIImage imageWithContentsOfFile:path];
    } else {
        charaImg = [UIImage imageNamed:charaFile];
    }
    [_charaImgView setImage:charaImg];
    [parent addSubview:_charaImgView];

    // Player name.
    _playerNameLbl = [[UILabel alloc]
        initWithFrame:CGRectMake((CGFloat)_imgPlayerNameX, 5.0f, 130.0f, 20.0f)];
    _playerNameLbl.backgroundColor = [UIColor clearColor];
    // Exact constants from the binary (0x3ebababb / 0x3eb0b0b1 / 0x3ea8a8a9) ~= rgb(93,88,84).
    _playerNameLbl.textColor = [UIColor colorWithRed:0.36458503f
                                               green:0.34506654f
                                                blue:0.32941106f
                                               alpha:1.0f];
    _playerNameLbl.highlightedTextColor = [UIColor whiteColor];
    _playerNameLbl.font = [UIFont fontWithName:AppFontName() size:14.0f];
    _playerNameLbl.textAlignment = NSTextAlignmentLeft;
    _playerNameLbl.adjustsFontSizeToFitWidth = YES;
    // Binary sends -setMinimumScaleFactor: the literal 14.0 (0x41600000). That is out of the
    // documented 0..1 range for scale factor and reads like the value the deprecated
    // -setMinimumFontSize: expected; reproduced verbatim to match the binary.
    [_playerNameLbl setMinimumScaleFactor:14.0f];
    _playerNameLbl.text = data.name;
    [parent addSubview:_playerNameLbl];

    // Score plaque (art keyed by place, and by which score is being ranked on).
    _scoreBaseImgView = [[UIImageView alloc]
        initWithFrame:CGRectMake((CGFloat)_imgScoreBaseX, 24.0f, 190.0f, 20.0f)];
    int placeIdx = (rank > 2) ? 3 : rank;
    int score;
    if (!isBestScoreSort) {
        [_scoreBaseImgView setImage:[UIImage imageNamed:kScoreTotalImg[placeIdx]]];
        score = data.totalScore;
    } else {
        [_scoreBaseImgView setImage:[UIImage imageNamed:kScoreBestImg[placeIdx]]];
        score = data.bestScore;
    }
    [parent addSubview:_scoreBaseImgView];

    // Score value (right-aligned over the plaque).
    _scoreLbl = [[UILabel alloc]
        initWithFrame:CGRectMake((CGFloat)_imgScoreX, 25.0f, 262.0f, 20.0f)];
    _scoreLbl.backgroundColor = [UIColor clearColor];
    _scoreLbl.textColor = [UIColor colorWithRed:0.36458503f
                                          green:0.34506654f
                                           blue:0.32941106f
                                          alpha:1.0f];
    _scoreLbl.highlightedTextColor = [UIColor whiteColor];
    _scoreLbl.font = [UIFont fontWithName:AppFontName() size:18.0f];
    _scoreLbl.textAlignment = NSTextAlignmentRight;
    _scoreLbl.text = [NSString stringWithFormat:@"%d", score];
    [parent addSubview:_scoreLbl];
}

// dealloc @ 0xb3494 — ARC-omitted (chains to super only; every subview is owned by its
// superview, so nothing needs releasing here).

@end
