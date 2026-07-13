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
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        self.contentView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        _leftPackView = [[StorePackView alloc] initWithFrame:CGRectZero];
        _rightPackView = [[StorePackView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_leftPackView];
        [self.contentView addSubview:_rightPackView];
    }
    return self;
}

// @ 0x5293c — detach each pack view's delegate before releasing it, so a queued
// callback can't reach a half-torn-down cell. (leftPackView/rightPackView are
// the synthesized retaining-property getters @ 0x529e4 / 0x529f4.)
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
