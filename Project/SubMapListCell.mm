//
//  SubMapListCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "SubMapListCell.h"

#import "AppDelegate.h"
#import "AppFont.h"
#import "TreasureData+Store.h"
#import "TreasureData.h"
#import "TreasureMap.h"
#import "neEngineBridge.h"

// The NSValue payload getValue: fills for a sub-map (area) row.
typedef struct {
    short mainMapId;
    short subMapId;
    int reserved;
    NSString *__unsafe_unretained name;
} SubMapListRowValue;

// Small right-of-icon count label ("%d" of collected pieces), shared style.
static UILabel *SubMapCountLabel(NSString *text, CGRect frame) {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.backgroundColor = [UIColor clearColor];
    lbl.textColor = [UIColor colorWithRed:69.0f / 255.0f
                                    green:64.0f / 255.0f
                                     blue:59.0f / 255.0f
                                    alpha:1.0f];
    lbl.highlightedTextColor = [UIColor whiteColor];
    lbl.font = [UIFont fontWithName:AppFontName() size:16.0f];
    lbl.textAlignment = NSTextAlignmentLeft;
    lbl.text = text;
    lbl.frame = frame;
    return lbl;
}

@implementation SubMapListCell {
    NSValue *_mapVal; // the bound row value
}

// @ 0xc0f8c — plain non-selectable cell; its content is bound by the VC on
// reuse.
// @complete
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

// dealloc @ 0xc0fd4 — ARC-omitted (releases ivars only; synthesized by ARC).

// @ 0xc1000 — rebuild the area row from an NSValue-wrapped sub-map record.
// @complete
- (void)setMapData:(NSValue *)mapValue {
    SubMapListRowValue v;
    [mapValue getValue:&v];
    _mapVal = mapValue;

    NSManagedObjectContext *moc = [[AppDelegate appDelegate] managedObjectContext];
    TreasureData *td = [TreasureData getTreasureData:v.mainMapId
                                            subMapId:v.subMapId
                              inManagedObjectContext:moc];

    float osVersion = UIDevice.currentDevice.systemVersion.floatValue;
    BOOL isPad = neSceneManager::isPadDisplay();

    // Two left-margin columns: `col` (icons/labels tied to the difficulty side)
    // and `col2` (item side, which drops by 5pt on pre-iOS 7 phones).
    int col = isPad ? 20 : 10;
    int col2 = isPad ? 20 : (osVersion < 7.0f ? 5 : 10);

    // Area banner.
    UIImageView *banner = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *bannerImg = [UIImage imageNamed:@"area_select_banner"];
    [banner setImage:bannerImg];
    [banner setFrame:CGRectMake(0.0f, 0.0f, bannerImg.size.width, bannerImg.size.height)];
    // The binary installs the banner as the cell's backgroundView unconditionally
    // (0xc129a setBackgroundView:, no device guard); on iPad it doubles as the
    // parent for the row's decorations (see `host` below).
    self.backgroundView = banner;
    self.backgroundColor = [UIColor clearColor];

    // On phone, decorations live in the content view; on pad they hang off the
    // banner.
    UIView *host = isPad ? (UIView *)banner : self.contentView;

    // Area name.
    UILabel *nameLbl = [[UILabel alloc] init];
    nameLbl.backgroundColor = [UIColor clearColor];
    nameLbl.textColor = [UIColor colorWithRed:69.0f / 255.0f
                                        green:64.0f / 255.0f
                                         blue:59.0f / 255.0f
                                        alpha:1.0f];
    nameLbl.highlightedTextColor = [UIColor whiteColor];
    nameLbl.font = [UIFont fontWithName:AppFontName() size:17.0f];
    nameLbl.textAlignment = NSTextAlignmentLeft;
    nameLbl.adjustsFontSizeToFitWidth = YES;
    nameLbl.minimumScaleFactor = 0.5f;
    nameLbl.text = v.name;
    nameLbl.frame = CGRectMake(col + 27, 20.0f, 260.0f, 20.0f);
    [host addSubview:nameLbl];

    // Collected "kakera" (fragment) count = set low-3-bits of musicPiece +
    // wallPaperPiece.
    int musicPiece = [[td musicPiece] intValue];
    int wallPaperPiece = [[td wallPaperPiece] intValue];
    int pieceCount = 0;
    for (int bit = 0; bit < 3; bit++) {
        if (musicPiece & (1 << bit)) {
            pieceCount++;
        }
    }
    for (int bit = 0; bit < 3; bit++) {
        if (wallPaperPiece & (1 << bit)) {
            pieceCount++;
        }
    }

    UIImage *kakeraImg = [UIImage imageNamed:@"area_icon_kakera"];
    UIImageView *kakeraView = [[UIImageView alloc]
        initWithFrame:CGRectMake(col2 + 105, 77.0f, kakeraImg.size.width, kakeraImg.size.height)];
    [kakeraView setImage:kakeraImg];
    [host addSubview:kakeraView];
    [host addSubview:SubMapCountLabel([NSString stringWithFormat:@"%d", pieceCount],
                                      CGRectMake(col2 + 130, 80.0f, 100.0f, 20.0f))];

    // Collected chara-ticket count.
    int ticketCount = [[td goalCharaTicket] intValue];
    UIImage *ticketImg = [UIImage imageNamed:@"area_icon_ticket"];
    UIImageView *ticketView = [[UIImageView alloc]
        initWithFrame:CGRectMake(col2 + 184, 77.0f, ticketImg.size.width, ticketImg.size.height)];
    [ticketView setImage:ticketImg];
    [host addSubview:ticketView];
    [host addSubview:SubMapCountLabel([NSString stringWithFormat:@"%d", ticketCount],
                                      CGRectMake(col2 + 207, 80.0f, 100.0f, 20.0f))];

    // Goal areas (subMapId == 2) show the "daon" touch-sound reward icon.
    if (v.subMapId == 2) {
        int touchSound = [[td goalTouchSound] intValue];
        NSString *daonName = (touchSound == 0) ? @"area_icon_daon_dff" : @"area_icon_daon_on";
        UIImage *daonImg = [UIImage imageNamed:daonName];
        UIImageView *daonView = [[UIImageView alloc]
            initWithFrame:CGRectMake(col2 + 260, 80.0f, daonImg.size.width, daonImg.size.height)];
        [daonView setImage:daonImg];
        [host addSubview:daonView];
    }

    // Section header art.
    UIImage *diffImg = [UIImage imageNamed:@"area_diff_text"];
    UIImageView *diffView = [[UIImageView alloc]
        initWithFrame:CGRectMake(col + 25, 50.0f, diffImg.size.width, diffImg.size.height)];
    [diffView setImage:diffImg];
    [host addSubview:diffView];

    UIImage *itemImg = [UIImage imageNamed:@"area_item_text"];
    UIImageView *itemView = [[UIImageView alloc]
        initWithFrame:CGRectMake(col2 + 25, 83.0f, itemImg.size.width, itemImg.size.height)];
    [itemView setImage:itemImg];
    [host addSubview:itemView];

    // Earned goal stars.
    int starCount = getTreasureMapTableEntry(v.mainMapId, v.subMapId);
    UIImage *starImg = [UIImage imageNamed:@"area_icon_star_dff"];
    for (int i = 0; i < starCount; i++) {
        CGFloat starX = roundf((float)col + i * starImg.size.width + 102.0f);
        UIImageView *starView = [[UIImageView alloc]
            initWithFrame:CGRectMake(starX, 50.0f, starImg.size.width, starImg.size.height)];
        [starView setImage:starImg];
        [host addSubview:starView];
    }

    // "Cleared" badge.
    if ([[td clearCnt] intValue] > 0) {
        UIImage *clearImg = [UIImage imageNamed:@"map_select_cleartxt_bg"];
        UIImageView *clearView = [[UIImageView alloc]
            initWithFrame:CGRectMake(253.0f, 3.0f, clearImg.size.width, clearImg.size.height)];
        [clearView setImage:clearImg];
        if (!neSceneManager::isPadDisplay()) {
            if (UIDevice.currentDevice.systemVersion.floatValue < 7.0f) {
                // Pre-iOS 7 phone: nudge the badge up-left for the older banner art.
                clearView.frame = CGRectOffset(clearView.frame, -20.0f, -20.0f);
            }
            [self.contentView addSubview:clearView];
        } else {
            [banner addSubview:clearView];
        }
    }
}

@end
