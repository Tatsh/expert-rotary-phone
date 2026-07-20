//
//  AcViewerCategoryCell.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  .mm because -setData: reaches the C++ engine bridge
//  (neSceneManager::isPadDisplay()).
//

#import "AcViewerCategoryCell.h"

#import "AcMusicData.h" // the row objects are AcMusicData; -category selects the banner
#import "neEngineBridge.h"

// The array holds AcMusicData arcade song records; only the first element's
// `category` (a small int, 0..23) is read to select the banner image.

@implementation AcViewerCategoryCell

// @ 0x1a804 — plain non-selectable cell.
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

// dealloc @ 0x1a84c — ARC-omitted (super-only; frees no C memory).

// @ 0x1a878 — install the category banner. The banner is centered inside a
// full-width background view on iOS 7+ phones, used directly as the cell
// background on older phones, and added as a horizontally-centered subview on
// iPad.
- (void)setData:(NSArray *)dataList {
    // Banner images indexed by category (0 = etc, 1 = TV, 2..23 = p01..p22).
    static NSString *const kCateBase[24] = {
        @"ppc_cate_base_etc", @"ppc_cate_base_tv",  @"ppc_cate_base_p01", @"ppc_cate_base_p02",
        @"ppc_cate_base_p03", @"ppc_cate_base_p04", @"ppc_cate_base_p05", @"ppc_cate_base_p06",
        @"ppc_cate_base_p07", @"ppc_cate_base_p08", @"ppc_cate_base_p09", @"ppc_cate_base_p10",
        @"ppc_cate_base_p11", @"ppc_cate_base_p12", @"ppc_cate_base_p13", @"ppc_cate_base_p14",
        @"ppc_cate_base_p15", @"ppc_cate_base_p16", @"ppc_cate_base_p17", @"ppc_cate_base_p18",
        @"ppc_cate_base_p19", @"ppc_cate_base_p20", @"ppc_cate_base_p21", @"ppc_cate_base_p22"};

    BOOL isPad = neSceneManager::isPadDisplay();

    UIImageView *baseImg = [[UIImageView alloc] initWithFrame:self.bounds];
    NSString *baseName;
    if (dataList == nil) {
        baseName = @"ppc_cate_base_all";
    } else {
        AcMusicData *first = [dataList objectAtIndexedSubscript:0];
        baseName = kCateBase[[first category]];
    }
    UIImage *image = [UIImage imageNamed:baseName];
    [baseImg setImage:image];

    if (!isPad) {
        CGFloat sysVer = [[UIDevice currentDevice].systemVersion floatValue];
        if (sysVer >= 7.0f) {
            // iOS 7+ phone: center the banner inside a full-width background view.
            UIView *container = [[UIView alloc]
                initWithFrame:CGRectMake(0.0f, 0.0f, self.bounds.size.width, image.size.height)];
            CGFloat cw = container.frame.size.width;
            [baseImg setFrame:CGRectMake((cw - image.size.width) * 0.5f,
                                         0.0f,
                                         image.size.width,
                                         image.size.height)];
            [container addSubview:baseImg];
            self.backgroundView = container;
        } else {
            // Pre-iOS 7 phone: banner is the cell background directly.
            [baseImg setFrame:CGRectMake(0.0f, 0.0f, image.size.width, image.size.height)];
            self.backgroundView = baseImg;
        }
    } else {
        // iPad: horizontally-centered subview (center x = 160).
        [baseImg setFrame:CGRectMake(0.0f, 0.0f, image.size.width, image.size.height)];
        [baseImg setCenter:CGPointMake(160.0f, image.size.height * 0.5f)];
        [self addSubview:baseImg];
    }
    self.backgroundColor = [UIColor clearColor];
}

@end
