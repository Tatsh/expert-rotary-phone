//
//  AcViewerMusicCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "AcViewerMusicCell.h"

#import "neEngineBridge.h"

@implementation AcViewerMusicCell {
    BOOL _isPad;
    int _offsetForPad1;   // extra x offset on iPad (50)
    int _offsetForPad2;
}

// @ 0x40430 — build the four difficulty buttons in a row at y = 51. The first button
// starts at x = 22 (pre-iOS 7) or 32, plus 50 more on iPad; each subsequent button
// sits just right of the previous. Tags 100..103 identify the chosen difficulty.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    _isPad = neSceneManager::isPadDisplay();
    _offsetForPad1 = 0;
    _offsetForPad2 = 0;
    if (_isPad) {
        _offsetForPad1 = 50;
        _offsetForPad2 = 0;
    }

    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        CGFloat firstX = (UIDevice.currentDevice.systemVersion.floatValue < 7.0f ? 22 : 32)
                       + _offsetForPad2;

        NSArray *images = @[ @"acv_viewer_diff_ea", @"acv_viewer_diff_n",
                             @"acv_viewer_diff_h", @"acv_viewer_diff_ex" ];
        UIButton *prev = nil;
        for (NSUInteger i = 0; i < 4; i++) {
            UIButton *btn = [[UIButton alloc] init];
            UIImage *img = [UIImage imageNamed:images[i]];
            CGFloat x = (prev == nil) ? firstX : CGRectGetMaxX(prev.frame);
            [btn setBackgroundImage:img forState:UIControlStateNormal];
            btn.frame = CGRectMake(x, 51, img.size.width, img.size.height);
            btn.tag = 100 + (NSInteger)i;
            switch (i) {
                case 0: self.easyBtn = btn; break;
                case 1: self.normalBtn = btn; break;
                case 2: self.hyperBtn = btn; break;
                case 3: self.exBtn = btn; break;
            }
            prev = btn;
        }
    }
    return self;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
