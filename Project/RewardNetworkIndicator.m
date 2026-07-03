//
//  RewardNetworkIndicator.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RewardNetworkIndicator.h"

@implementation RewardNetworkIndicator

// @ 0xf3c0c — a half-opaque black overlay with an 80x80 large white spinner.
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.indicator =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 80.0f, 80.0f)];
        self.indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        self.backgroundColor = [UIColor blackColor];
        self.alpha = 0.5f;
        [self addSubview:self.indicator];
    }
    return self;
}

// @ 0xf3d58 — keep the spinner centered in the overlay.
- (void)layoutSubviews {
    [super layoutSubviews];
    self.indicator.center = CGPointMake(CGRectGetWidth(self.bounds) * 0.5f,
                                        CGRectGetHeight(self.bounds) * 0.5f);
}

// @ 0xf3e14
- (void)show {
    self.hidden = NO;
    [self.indicator startAnimating];
}

// @ 0xf3e64
- (void)close {
    self.hidden = YES;
    [self.indicator stopAnimating];
}

// setIndicator: @ 0xf3ec4 / indicator @ 0xf3eb4 — synthesized accessors for the
//   _indicator ivar.
// .cxx_destruct @ 0xf3eec — compiler-emitted ARC teardown for _indicator; not
//   hand-written.

@end
