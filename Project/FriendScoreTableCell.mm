//
//  FriendScoreTableCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "FriendScoreTableCell.h"

#import "AppDelegate.h"                    // +appAppSupportDirectory (downloaded chara icons)
#import "AppFont.h"                        // AppFontName()
#import "Game/Data/Save/UserSettingData.h" // +playerName (self row)
#import "neEngineBridge.h"                 // neSceneManager::isPadDisplay

// One friend-score row, as wrapped in the NSValue passed to -setScoreData:.
// Obj-C type-encoding "{ScoreDataStruct=@@iBBcsB}" (verified in
// FriendScoreMainView's -tableView:cellForRowAtIndexPath:).
typedef struct {
    NSString *__unsafe_unretained playerId; // @  nil => empty slot; non-nil with
                                            // a nil name => the local player
    NSString *__unsafe_unretained name;     // @  nil on the self row (filled from UserSettingData)
    int score;                              // i  -1 => no score recorded
    BOOL isPerfect;                         // B
    BOOL isFullCombo;                       // B
    char rank;                              // c  0-based finishing place
    short charaId;                          // s
    BOOL isNotice;                          // B  event/notice row
} ScoreDataStruct;

// Rank "place" badges (1st..9th) for rows 0..8; two-digit rows compose digit
// glyphs.
static NSString *const kRankPlaceImg[9] = {
    @"frisco_ranknum_1st",
    @"frisco_ranknum_2nd",
    @"frisco_ranknum_3rd",
    @"frisco_ranknum_4th",
    @"frisco_ranknum_5th",
    @"frisco_ranknum_6th",
    @"frisco_ranknum_7th",
    @"frisco_ranknum_8th",
    @"frisco_ranknum_9th",
};
static NSString *const kRankDigitImg[10] = {
    @"frisco_ranknum_0",
    @"frisco_ranknum_1",
    @"frisco_ranknum_2",
    @"frisco_ranknum_3",
    @"frisco_ranknum_4",
    @"frisco_ranknum_5",
    @"frisco_ranknum_6",
    @"frisco_ranknum_7",
    @"frisco_ranknum_8",
    @"frisco_ranknum_9",
};
// Chara-icon backing plate: gold/silver/bronze for the top three, common for
// the rest.
static NSString *const kCharaIconBg[3] = {
    @"frisco_icon_1st",
    @"frisco_icon_2nd",
    @"frisco_icon_3rd",
};
// Score plaque, keyed by place (1st/2nd/3rd/common).
static NSString *const kScoreImg[4] = {
    @"frisco_sco_1st",
    @"frisco_sco_2nd",
    @"frisco_sco_3rd",
    @"frisco_sco_cmn",
};
// Score-rank badge, keyed by scoreToRank() (0 = perfect-S .. 6 = D).
static NSString *const kScoreRankImg[7] = {
    @"frisco_rank_perfect_s",
    @"frisco_rank_aaa",
    @"frisco_rank_aa",
    @"frisco_rank_a",
    @"frisco_rank_b",
    @"frisco_rank_c",
    @"frisco_rank_d",
};

// Score -> rank index (0 best .. 6 worst). The binary shares one routine
// (Ghidra FUN_00028a40, also reconstructed file-local in PlayScene.mm).
static int scoreToRank(int score) {
    if (score >= 100000) {
        return 0;
    }
    if (score >= 98000) {
        return 1;
    }
    if (score >= 95000) {
        return 2;
    }
    if (score >= 90000) {
        return 3;
    }
    if (score >= 80000) {
        return 4;
    }
    if (score >= 70000) {
        return 5;
    }
    return 6;
}

@implementation FriendScoreTableCell {
    BOOL _isOS7;
    int _imgYouX, _imgFrameX, _imgFrame10X, _imgFrame01X, _imgOrderX, _imgCharaX;
    int _imgPlayerNameX, _imgScoreBaseX, _imgScoreX, _imgRankX, _imgFullComboX;

    // Built lazily in setScoreData: and torn down on reuse. Every one is owned by
    // its superview, so none is released in dealloc.
    UIImageView *_bgImgView;
    UIImageView *_youImgView;
    UIImageView *_rankImgView01; // ones digit / single place badge
    UIImageView *_rankImgView10; // tens digit (rows >= 9 only)
    UIImageView *_charaBgImgView;
    UIImageView *_charaImgView;
    UILabel *_playerNameLbl;
    UIImageView *_scoreBaseImgView;
    UILabel *_scoreLbl;
    UIImageView *_scoreRankImgView;     // S/AAA/AA/A/B/C/D grade badge
    UIImageView *_fullcomboMarkImgView; // perfect / full-combo mark
}

// @ 0xae06c — record the full row layout x offsets (iOS 6 vs 7).
// @complete
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    if (!_isOS7) {
        _imgYouX = 0xe8;
        _imgFrameX = 0xd;
        _imgFrame10X = 0xe;
        _imgFrame01X = 0x1d;
        _imgOrderX = 0x2b;
        _imgCharaX = 0x2b;
        _imgPlayerNameX = 0x5b;
        _imgScoreBaseX = 0x58;
        _imgScoreX = 10;
        _imgRankX = 0xde;
        _imgFullComboX = 0xe4;
    } else {
        _imgYouX = 0xfb;
        _imgFrameX = 0x14;
        _imgFrame10X = 0x15;
        _imgFrame01X = 0x24;
        _imgOrderX = 0x32;
        _imgCharaX = 0x32;
        _imgPlayerNameX = 0x62;
        _imgScoreBaseX = 0x5f;
        _imgScoreX = 0x11;
        _imgRankX = 0xea;
        _imgFullComboX = 0xf0;
    }
    return self;
}

// @ 0xae288 — render one friend-score row from an NSValue-wrapped
// ScoreDataStruct. Rebuilt on every reuse, so it first strips the subviews it
// built last time. Phone uses the iOS6/7 x-offset ivars above; iPad uses its
// own fixed metrics (only the pre-iOS7 -10pt shift, folded into `padX0`,
// carries over). The self row (nil name) shows the "you" marker.
// @complete
- (void)setScoreData:(NSValue *)scoreData {
    ScoreDataStruct data;
    [scoreData getValue:&data];

    const BOOL isPad = neSceneManager::isPadDisplay();
    const CGFloat padX0 = _isOS7 ? 0.0f : -10.0f;

    // Reuse teardown.
    if (_bgImgView) {
        [_bgImgView removeFromSuperview];
        _bgImgView = nil;
    }
    if (_youImgView) {
        [_youImgView removeFromSuperview];
        _youImgView = nil;
    }
    if (_rankImgView01) {
        [_rankImgView01 removeFromSuperview];
        _rankImgView01 = nil;
    }
    if (_rankImgView10) {
        [_rankImgView10 removeFromSuperview];
        _rankImgView10 = nil;
    }
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
    if (_scoreBaseImgView) {
        [_scoreBaseImgView removeFromSuperview];
        _scoreBaseImgView = nil;
    }
    if (_scoreLbl) {
        [_scoreLbl removeFromSuperview];
        _scoreLbl = nil;
    }
    if (_scoreRankImgView) {
        [_scoreRankImgView removeFromSuperview];
        _scoreRankImgView = nil;
    }
    if (_fullcomboMarkImgView) {
        [_fullcomboMarkImgView removeFromSuperview];
        _fullcomboMarkImgView = nil;
    }

    // Row background image. On phone it is installed as the cell's
    // backgroundView; on iPad it is added to the content view (shifted right by
    // 45pt) and also parents every other element on the row.
    _bgImgView = [[UIImageView alloc] initWithFrame:self.bounds];
    [self setBackgroundView:nil];

    NSString *baseName;
    if (!neSceneManager::isPadDisplay()) {
        if (data.playerId == nil || data.name != nil) {
            baseName = data.isNotice ? @"frisco_base_notice" : @"frisco_base_others";
        } else {
            baseName = @"frisco_base_player";
        }
    } else {
        if (data.playerId == nil || data.name != nil) {
            if (!data.isNotice) {
                if (data.score == -1) {
                    baseName = @"frisco_base_player_04";
                } else if (data.rank == 2) {
                    baseName = @"frisco_base_player_03";
                } else if (data.rank == 1) {
                    baseName = @"frisco_base_player_02";
                } else if (data.rank == 0) {
                    baseName = @"frisco_base_player_01";
                } else {
                    baseName = @"frisco_base_player_04";
                }
            } else {
                baseName = @"frisco_base_player_06";
            }
        } else {
            baseName = @"frisco_base_player_05";
        }
    }
    UIImage *bgImg = [UIImage imageNamed:baseName];
    [_bgImgView setImage:bgImg];
    if (!isPad) {
        [_bgImgView setFrame:CGRectMake(0, 0, bgImg.size.width, bgImg.size.height)];
        [self setBackgroundView:_bgImgView];
    } else {
        [_bgImgView setFrame:CGRectMake(padX0 + 45.0f, 0, bgImg.size.width, bgImg.size.height)];
        [self.contentView addSubview:_bgImgView];
    }
    self.backgroundColor = [UIColor clearColor];

    // "You" marker — phone only, on the local player's own row (playerId set,
    // name nil).
    if (!isPad && data.playerId != nil && data.name == nil) {
        UIImage *youImg = [UIImage imageNamed:@"frisco_you"];
        _youImgView = [[UIImageView alloc] initWithFrame:self.bounds];
        [_youImgView setImage:youImg];
        [_youImgView
            setFrame:CGRectMake((CGFloat)_imgYouX, 0, youImg.size.width, youImg.size.height)];
        [_bgImgView addSubview:_youImgView];
    }

    // Rank badge (only when a score exists). Rows 0..8 use a single "place"
    // glyph; rows 9+ compose the one-based place number from two digit glyphs.
    if (data.score != -1) {
        int place = (int)data.rank;
        if (place < 9) {
            int idx = (data.rank > 8) ? 8 : place;
            UIImage *img = [UIImage imageNamed:kRankPlaceImg[idx]];
            _rankImgView01 = [[UIImageView alloc] init];
            [_rankImgView01 setImage:img];
            CGFloat x = isPad ? (padX0 + 7.0f) : (CGFloat)_imgFrameX;
            CGFloat y = isPad ? 40.0f : 14.0f;
            [_rankImgView01 setFrame:CGRectMake(x, y, img.size.width, img.size.height)];
            [self.contentView addSubview:_rankImgView01];
        } else {
            int oneBased = place + 1;
            UIImage *ones = [UIImage imageNamed:kRankDigitImg[oneBased % 10]];
            _rankImgView01 = [[UIImageView alloc] init];
            [_rankImgView01 setImage:ones];
            CGFloat x1 = isPad ? (padX0 + 22.0f) : (CGFloat)_imgFrame01X;
            CGFloat y1 = isPad ? 40.0f : 14.0f;
            [_rankImgView01 setFrame:CGRectMake(x1, y1, ones.size.width, ones.size.height)];
            [self.contentView addSubview:_rankImgView01];

            UIImage *tens = [UIImage imageNamed:kRankDigitImg[(oneBased / 10) % 10]];
            _rankImgView10 = [[UIImageView alloc] init];
            [_rankImgView10 setImage:tens];
            CGFloat x2 = isPad ? (padX0 + 7.0f) : (CGFloat)_imgFrameX;
            CGFloat y2 = isPad ? 40.0f : 14.0f;
            [_rankImgView10 setFrame:CGRectMake(x2, y2, tens.size.width, tens.size.height)];
            [self.contentView addSubview:_rankImgView10];
        }
    }

    // Chara icon backing plate + icon (only when a player occupies the row).
    if (data.playerId != nil) {
        CGFloat cx = isPad ? 6.0f : (CGFloat)_imgOrderX;
        CGFloat cy = isPad ? 17.0f : 5.0f;
        CGRect charaFrame = CGRectMake(cx, cy, 43.0f, 43.0f);

        _charaBgImgView = [[UIImageView alloc] initWithFrame:charaFrame];
        [_charaBgImgView
            setImage:[UIImage imageNamed:(data.rank < 3 ? kCharaIconBg[(int)data.rank] :
                                                          @"frisco_icon_cmn")]];
        [_bgImgView addSubview:_charaBgImgView];

        _charaImgView = [[UIImageView alloc] initWithFrame:charaFrame];
        short charaId = data.charaId;
        if (charaId < 0) {
            charaId = 0;
        }
        NSString *charaFile = [NSString stringWithFormat:@"sgc_icon_%03d.png", (int)charaId];
        UIImage *charaImg;
        if (charaId > 0x1d) {
            NSString *path =
                [[AppDelegate appAppSupportDirectory] stringByAppendingPathComponent:charaFile];
            charaImg = [UIImage imageWithContentsOfFile:path];
        } else {
            charaImg = [UIImage imageNamed:charaFile];
        }
        [_charaImgView setImage:charaImg];
        [_bgImgView addSubview:_charaImgView];
    }

    // Event/notice icon overlay.
    if (data.isNotice) {
        UIImage *noticeIcon = [UIImage imageNamed:@"frisco_base_notice_icon"];
        UIImageView *noticeView = [[UIImageView alloc] initWithImage:noticeIcon];
        CGFloat nx = isPad ? 36.0f : 0.0f;
        CGFloat ny = isPad ? 2.0f : 0.0f;
        [noticeView setFrame:CGRectMake(nx, ny, noticeIcon.size.width, noticeIcon.size.height)];
        [_bgImgView addSubview:noticeView];
    }

    // Player name, score plaque and score value (only when a player occupies the
    // row).
    if (data.playerId != nil) {
        CGFloat nameX = isPad ? 8.0f : (CGFloat)_imgPlayerNameX;
        CGFloat nameY = isPad ? 60.0f : 5.0f;
        _playerNameLbl = [[UILabel alloc] initWithFrame:CGRectMake(nameX, nameY, 130.0f, 20.0f)];
        _playerNameLbl.backgroundColor = [UIColor clearColor];
        // Exact constants from the binary (0x3ebababb / 0x3eb0b0b1 / 0x3ea8a8a9) ~=
        // rgb(93,88,84).
        _playerNameLbl.textColor = [UIColor colorWithRed:0.364705890417099f
                                                   green:0.3450980484485626f
                                                    blue:0.3294117748737335f
                                                   alpha:1.0f];
        _playerNameLbl.highlightedTextColor = [UIColor whiteColor];
        _playerNameLbl.font = [UIFont fontWithName:AppFontName() size:15.0f]; // 0x41700000
        _playerNameLbl.textAlignment = NSTextAlignmentLeft;
        _playerNameLbl.adjustsFontSizeToFitWidth = YES;
        // As in the sibling FriendListCell, the binary passes the literal 14.0 to
        // -setMinimumScaleFactor:; reproduced verbatim to match the binary.
        [_playerNameLbl setMinimumScaleFactor:14.0f];
        // The self row carries no name; fall back to the saved player name (or
        // "YOU").
        if (data.name == nil) {
            NSString *pn = [UserSettingData playerName];
            _playerNameLbl.text = pn ?: @"YOU";
        } else {
            _playerNameLbl.text = data.name;
        }
        [_bgImgView addSubview:_playerNameLbl];

        // Score plaque (art keyed by place).
        int placeIdx = (data.rank < 3) ? (int)data.rank : 3;
        CGFloat baseX = isPad ? 6.0f : (CGFloat)_imgScoreBaseX;
        CGFloat baseY = isPad ? 80.0f : 24.0f;
        _scoreBaseImgView =
            [[UIImageView alloc] initWithFrame:CGRectMake(baseX, baseY, 135.0f, 20.0f)];
        [_scoreBaseImgView setImage:[UIImage imageNamed:kScoreImg[placeIdx]]];
        [_bgImgView addSubview:_scoreBaseImgView];

        // Score value (right-aligned over the plaque).
        CGFloat scoreX = isPad ? 6.0f : (CGFloat)_imgScoreX;
        CGFloat scoreY = isPad ? 80.0f : 25.0f;
        CGFloat scoreW = isPad ? 130.0f : 206.0f;
        _scoreLbl = [[UILabel alloc] initWithFrame:CGRectMake(scoreX, scoreY, scoreW, 20.0f)];
        _scoreLbl.backgroundColor = [UIColor clearColor];
        _scoreLbl.textColor = [UIColor colorWithRed:0.364705890417099f
                                              green:0.3450980484485626f
                                               blue:0.3294117748737335f
                                              alpha:1.0f];
        _scoreLbl.highlightedTextColor = [UIColor whiteColor];
        _scoreLbl.font = [UIFont fontWithName:AppFontName() size:18.0f];
        _scoreLbl.textAlignment = NSTextAlignmentRight;
        _scoreLbl.text = (data.score < 0) ? @"" : [NSString stringWithFormat:@"%d", data.score];
        [_bgImgView addSubview:_scoreLbl];
    }

    // Score-rank badge + perfect/full-combo mark (only when a score exists).
    if (data.score < 0) {
        return;
    }
    int rank = scoreToRank(data.score);

    CGFloat rrX = isPad ? 135.0f : (CGFloat)_imgRankX;
    CGFloat rrY = isPad ? 15.0f : 5.0f;
    _scoreRankImgView = [[UIImageView alloc] initWithFrame:CGRectMake(rrX, rrY, 63.0f, 40.0f)];
    [_scoreRankImgView setImage:[UIImage imageNamed:kScoreRankImg[rank]]];
    [_bgImgView addSubview:_scoreRankImgView];

    UIImage *markImg;
    if (rank == 0) {
        markImg = [UIImage imageNamed:@"frisco_font_perfect_s"];
    } else if (data.isPerfect) {
        markImg = [UIImage imageNamed:@"frisco_font_perfect"];
    } else if (data.isFullCombo) {
        markImg = [UIImage imageNamed:@"frisco_font_fullcombo"];
    } else {
        return;
    }
    if (markImg == nil) {
        return;
    }
    _fullcomboMarkImgView = [[UIImageView alloc] init];
    [_fullcomboMarkImgView setImage:markImg];
    CGFloat mx, my;
    if (!isPad) {
        mx = (CGFloat)_imgFullComboX;
        my = 39.0f;
    } else {
        // Pinned just inside the score-rank badge on iPad.
        CGRect rf = _scoreRankImgView.frame;
        mx = rf.origin.x + 6.5f;
        my = rf.origin.y + rf.size.height;
    }
    [_fullcomboMarkImgView setFrame:CGRectMake(mx, my, markImg.size.width, markImg.size.height)];
    [_bgImgView addSubview:_fullcomboMarkImgView];
}

// dealloc @ 0xae25c — ARC-omitted (chains to super only; every subview is owned
// by its superview, so nothing is released here).

@end
