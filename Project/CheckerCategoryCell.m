//
//  CheckerCategoryCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "CheckerCategoryCell.h"

#import "neEngineBridge.h"

@implementation CheckerCategoryCell {
    BOOL _isOS7;
    BOOL _isPad;
    int _offsetXForPad;
    int _imgMusicCntX;
}

// @ 0xcf49c — the music-count label x offset varies by device + OS.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _offsetXForPad = 0;
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    _isPad = neSceneManager::isPadDisplay();
    if (!_isPad) {
        _imgMusicCntX = _isOS7 ? 0xf5 : 0xf0;
    } else if (!_isOS7) {
        _offsetXForPad = 6;   _imgMusicCntX = 0xec;
    } else {
        _offsetXForPad = 0xe; _imgMusicCntX = 0xf4;
    }
    return self;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
