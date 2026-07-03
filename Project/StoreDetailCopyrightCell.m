//
//  StoreDetailCopyrightCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreDetailCopyrightCell.h"

@implementation StoreDetailCopyrightCell

// @ 0x75324 — a word-wrapping grey label at (5, 5, 310, 0), sized by the VC, on a
// clear background.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _labelCopyright = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, 310, 0)];
        _labelCopyright.backgroundColor = [UIColor clearColor];
        _labelCopyright.textColor = [UIColor colorWithWhite:0.3f alpha:1.0f];
        _labelCopyright.numberOfLines = 0;
        _labelCopyright.lineBreakMode = NSLineBreakByWordWrapping;
        [self.contentView addSubview:_labelCopyright];
    }
    return self;
}

// labelCopyright @ 0x754c8 — synthesized getter (returns the labelCopyright ivar).
// dealloc @ 0x7547c — ARC-omitted (releases the labelCopyright ivar only).

@end
