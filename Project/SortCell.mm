//
//  SortCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "SortCell.h"

#import "neEngineBridge.h"

// The NSValue payload getValue: fills for a sort-option row.
typedef struct {
    short sortType;
    unsigned char isChecked;
} SortRowValue;

// @ 0xc5418 — plain non-selectable cell; content bound by the VC on reuse.
@implementation SortCell {
    NSValue *_sortVal;              // the bound row value
    UIImageView *_bgImgView;        // base plate
    UIImageView *_titleImageView;   // sort-key title art
    UIImageView *_checkImageView;   // check-mark
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

// dealloc @ 0xc5460 — ARC-omitted (releases ivars only; synthesized by ARC).

// @ 0xc548c — rebuild the row from an NSValue-wrapped sort-option record.
- (void)setSortData:(NSValue *)sortValue {
    // Sort-key title images, indexed by sortType (0..5).
    static NSString *const kSortTitle[6] = {
        @"m_sort_text_title", @"m_sort_text_art", @"m_sort_text_lvn",
        @"m_sort_text_lvh", @"m_sort_text_lvex", @"m_sort_text_nodata"
    };

    SortRowValue v;
    [sortValue getValue:&v];
    _sortVal = sortValue;

    if (_bgImgView) {
        [_bgImgView removeFromSuperview];
        _bgImgView = nil;
    }
    if (_titleImageView) {
        [_titleImageView removeFromSuperview];
        _titleImageView = nil;
    }
    if (_checkImageView) {
        [_checkImageView removeFromSuperview];
        _checkImageView = nil;
    }

    BOOL isPad = neSceneManager::isPadDisplay();

    // Base plate.
    _bgImgView = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *base = [UIImage imageNamed:@"m_sort_base"];
    [_bgImgView setImage:base];
    if (!isPad) {
        // Phone: stretch to the cell's width, keep the art's height.
        [_bgImgView setFrame:CGRectMake(0.0f, 0.0f, self.frame.size.width, base.size.height)];
    } else {
        // Pad: native size, then re-center horizontally at x = 170.
        [_bgImgView setFrame:CGRectMake(0.0f, 0.0f, base.size.width, base.size.height)];
        [_bgImgView setCenter:CGPointMake(170.0f, _bgImgView.center.y)];
    }
    if (!isPad) {
        self.backgroundView = _bgImgView;
    } else {
        [self addSubview:_bgImgView];
    }
    self.backgroundColor = [UIColor clearColor];

    // Sort-key title art.
    UIImage *titleImage = [UIImage imageNamed:kSortTitle[v.sortType]];
    _titleImageView = [[UIImageView alloc] initWithFrame:CGRectMake(27.0f, 18.0f,
                                                                    titleImage.size.width,
                                                                    titleImage.size.height)];
    [_titleImageView setImage:titleImage];
    if (!isPad) {
        [self.contentView addSubview:_titleImageView];
    } else {
        [_bgImgView addSubview:_titleImageView];
    }

    // Check-mark.
    UIImage *checkImage = [UIImage imageNamed:(v.isChecked ? @"m_sort_check_01" : @"m_sort_check_00")];
    _checkImageView = [[UIImageView alloc] initWithFrame:CGRectMake(253.0f, 15.0f,
                                                                    checkImage.size.width,
                                                                    checkImage.size.height)];
    [_checkImageView setImage:checkImage];
    if (!isPad) {
        [self.contentView addSubview:_checkImageView];
    } else {
        [_bgImgView addSubview:_checkImageView];
    }
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
