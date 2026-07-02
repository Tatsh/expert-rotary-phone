//
//  FriendListCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "FriendListCell.h"

#import "neEngineBridge.h"

@implementation FriendListCell {
    BOOL _isOS7;
    int _imgYouX, _imgFrameX, _imgFrame10X, _imgFrame01X, _imgOrderX, _imgCharaX;
    int _imgPlayerNameX, _imgScoreBaseX, _imgScoreX;
}

// @ 0xb3234 — three layouts: iPad, or phone by iOS version.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    _isOS7 = UIDevice.currentDevice.systemVersion.floatValue >= 7.0f;
    if (!neSceneManager::isPadDisplay()) {
        if (!_isOS7) {
            _imgYouX = 0xe8; _imgFrameX = 0xd; _imgFrame10X = 0xe; _imgFrame01X = 0x1d;
            _imgOrderX = 0x2b; _imgCharaX = 0x2b; _imgPlayerNameX = 0x5b; _imgScoreBaseX = 0x58;
            _imgScoreX = 10;
        } else {
            _imgYouX = 0xfb; _imgFrameX = 0x14; _imgFrame10X = 0x15; _imgFrame01X = 0x24;
            _imgOrderX = 0x32; _imgCharaX = 0x32; _imgPlayerNameX = 0x62; _imgScoreBaseX = 0x5f;
            _imgScoreX = 0x11;
        }
    } else {
        _imgYouX = 0xfa; _imgFrameX = 0x17; _imgFrame10X = 0x18; _imgFrame01X = 0x27;
        _imgOrderX = 0x3f; _imgCharaX = 0x3f; _imgPlayerNameX = 0x6f; _imgScoreBaseX = 0x6c;
        _imgScoreX = 0x1e;
    }
    return self;
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
