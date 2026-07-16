//
//  StoreTableCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreTableCell.h"

#import "StorePackView.h"

@implementation StoreTableCell

// @ 0x527b4 — white cell + content view, holding two StorePackView halves (the
// VC frames + fills them per row).
// @complete
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        self.contentView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        // Both halves are built with a (0, 0, 365, 140) frame (0x43b68000 =
        // 365.0, 0x430c0000 = 140.0 at 0x528b4 / 0x528ea); the VC reframes them
        // per row.
        _leftPackView = [[StorePackView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 365.0f, 140.0f)];
        _rightPackView =
            [[StorePackView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 365.0f, 140.0f)];
        [self.contentView addSubview:_leftPackView];
        [self.contentView addSubview:_rightPackView];
    }
    return self;
}

// @ 0x5293c — detach each pack view's delegate before releasing it, so a queued
// callback can't reach a half-torn-down cell. (leftPackView/rightPackView are
// the synthesized retaining-property getters @ 0x529e4 / 0x529f4.)
// @complete
- (void)dealloc {
    [_leftPackView setDelegate:nil];
    if (_leftPackView != nil) {
        _leftPackView = nil;
    }
    [_rightPackView setDelegate:nil];
    if (_rightPackView != nil) {
        _rightPackView = nil;
    }
}

@end
