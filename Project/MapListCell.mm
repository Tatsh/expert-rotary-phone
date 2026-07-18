//
//  MapListCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "MapListCell.h"

#import "AppDelegate.h"
#import "TreasureData+Store.h"
#import "TreasureData.h"
#import "neEngineBridge.h"

// The shared DynaFont gothic face, referenced literally by this cell in the
// binary (cf_DFSoGei_W5_WIN_RKSJ_H); identical to AppFontName().
static NSString *const kCellFont = @"DFSoGei-W5-WIN-RKSJ-H";

// The NSValue payload getValue: fills for a main-map row.
typedef struct {
    short mapId;
    short reserved;
    NSString *__unsafe_unretained name;
} MapListRowValue;

// @ 0xbe270 — plain non-selectable cell; content bound by the VC on reuse.
@implementation MapListCell {
    NSValue *_mapVal;        // the bound row value
    UIImageView *_bgImgView; // banner (background view on phone, subview host on pad)
}

// @complete
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

// dealloc @ 0xbe2b8 — ARC-omitted (releases ivars only; synthesized by ARC).

// @ 0xbe2e4 — rebuild the row from an NSValue-wrapped main-map record.
// @complete
- (void)setMapData:(NSValue *)mapValue isSelect:(BOOL)isSelect {
    MapListRowValue v;
    [mapValue getValue:&v];
    _mapVal = mapValue;

    float osVersion = UIDevice.currentDevice.systemVersion.floatValue;
    BOOL isPad = neSceneManager::isPadDisplay();

    if (_bgImgView) {
        [_bgImgView removeFromSuperview];
        _bgImgView = nil;
    }

    // Banner background.
    _bgImgView = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *banner =
        [UIImage imageNamed:(isSelect ? @"map_select_banner_on" : @"map_select_banner")];
    [_bgImgView setImage:banner];
    if (!isPad) {
        [_bgImgView setFrame:CGRectMake(0.0f, 0.0f, banner.size.width, banner.size.height)];
        self.backgroundView = _bgImgView;
    } else {
        CGFloat bannerX = isSelect ? 20.0f : 0.0f;
        [_bgImgView setFrame:CGRectMake(bannerX, 0.0f, banner.size.width, banner.size.height)];
        [self addSubview:_bgImgView];
    }
    self.backgroundColor = [UIColor clearColor];

    // Map icon.
    CGFloat iconX = isPad ? 23.0f : (osVersion >= 7.0f ? 23.0f : 20.0f);
    NSString *iconName = [NSString stringWithFormat:@"map_icon%02d", static_cast<int>(v.mapId)];
    UIImage *iconImage = [UIImage imageNamed:iconName];
    UIImageView *iconView = [[UIImageView alloc]
        initWithFrame:CGRectMake(iconX, 7.0f, iconImage.size.width, iconImage.size.height)];
    [iconView setImage:iconImage];
    if (!isPad) {
        [self.contentView addSubview:iconView];
    } else {
        [_bgImgView addSubview:iconView];
    }

    // Name label.
    UILabel *nameLbl = [[UILabel alloc] init];
    nameLbl.backgroundColor = [UIColor clearColor];
    nameLbl.textColor = [UIColor colorWithRed:69.0f / 255.0f
                                        green:64.0f / 255.0f
                                         blue:59.0f / 255.0f
                                        alpha:1.0f];
    nameLbl.highlightedTextColor = [UIColor whiteColor];
    nameLbl.font = [UIFont fontWithName:kCellFont size:17.0f];
    nameLbl.textAlignment = NSTextAlignmentLeft;
    nameLbl.adjustsFontSizeToFitWidth = YES;
    nameLbl.minimumScaleFactor = 0.5f;
    nameLbl.text = v.name;
    CGFloat nameX, nameW;
    if (!isPad) {
        nameX = (osVersion >= 7.0f) ? 91.0f : 83.0f;
        nameW = (osVersion >= 7.0f) ? 192.0f : 190.0f;
    } else {
        nameX = (osVersion >= 7.0f) ? 93.0f : 90.0f;
        nameW = (osVersion >= 7.0f) ? 190.0f : 195.0f;
    }
    nameLbl.frame = CGRectMake(nameX, 19.0f, nameW, 20.0f);
    if (!isPad) {
        [self.contentView addSubview:nameLbl];
    } else {
        [_bgImgView addSubview:nameLbl];
    }

    // "Cleared" badge — only when every sub-map (0..2) of this map has been
    // cleared.
    NSManagedObjectContext *moc = [[AppDelegate appDelegate] managedObjectContext];
    for (short sub = 0; sub < 3; sub++) {
        TreasureData *td = [TreasureData getTreasureData:v.mapId
                                                subMapId:sub
                                  inManagedObjectContext:moc];
        if ([[td clearCnt] intValue] < 1) {
            return;
        }
    }

    UIImage *clearImage = [UIImage imageNamed:@"map_select_cleartxt_bg"];
    UIImageView *clearView = [[UIImageView alloc]
        initWithFrame:CGRectMake(253.0f, 3.0f, clearImage.size.width, clearImage.size.height)];
    [clearView setImage:clearImage];
    if (!neSceneManager::isPadDisplay()) {
        if (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) {
            // Pre-iOS 7 phone: nudge the badge up-left to line up with the older
            // banner art.
            clearView.frame = CGRectOffset(clearView.frame, -20.0f, -20.0f);
        }
        [self.contentView addSubview:clearView];
    } else {
        [_bgImgView addSubview:clearView];
    }
}

@end
