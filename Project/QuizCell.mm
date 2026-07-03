//
//  QuizCell.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  .mm because -setData:... reaches the C++ engine bridge (neSceneManager::isPadDisplay()).
//

#import "QuizCell.h"

#import "AppFont.h"   // AppFontName() == getFontNameDFSoGei() -> @"DFSoGei-W5-WIN-RKSJ-H"
#import "neEngineBridge.h"

@implementation QuizCell {
    int _answerId;
    UIImageView *_answerIdView;
}

// @ 0xd9bac — plain non-selectable cell.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

// dealloc @ 0xd9bf4 — ARC-omitted (super-only; frees no C memory).

// @ 0xd9c20 — rebuild the row: answer-base background + answer label + number badge.
- (void)setData:(NSString *)text answerId:(int)answerId rightId:(int)rightId selectId:(int)selectId {
    _answerId = answerId;

    // Reuse cleanup for the number badge.
    if (_answerIdView) {
        [_answerIdView removeFromSuperview];
        _answerIdView = nil;
    }

    // Answer-base image + opacity depend on whether/what the player answered.
    NSString *baseName;
    CGFloat baseAlpha;
    if (selectId < 0) {
        // Not answered yet.
        baseName = @"pq_ansbase_default";
        baseAlpha = 1.0f;
    } else if (selectId == answerId) {
        // This is the chosen row: highlight correct (ok) or incorrect (ng).
        baseName = (selectId == rightId) ? @"pq_ansbase_ok" : @"pq_ansbase_ng";
        baseAlpha = 1.0f;
    } else {
        // Answered, but a different row: dim it.
        baseName = @"pq_ansbase_cover";
        baseAlpha = 0.5f;
    }
    UIImage *baseImage = [UIImage imageNamed:baseName];

    UIImageView *bgView = [[UIImageView alloc] initWithFrame:self.bounds];
    [bgView setImage:baseImage];
    [bgView setFrame:CGRectMake(0.0f, 0.0f, baseImage.size.width, baseImage.size.height)];
    [bgView setAlpha:baseAlpha];
    self.backgroundView = bgView;
    self.backgroundColor = [UIColor clearColor];

    // Answer text label (DFSoGei 17, centered). The correct answer is tinted red
    // (223/255) once the player has chosen the wrong one; otherwise a dark tint (50/255).
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    CGFloat red = ((rightId == selectId) || (selectId < 0) || (rightId != answerId))
                      ? (50.0f / 255.0f)
                      : (223.0f / 255.0f);
    label.textColor = [UIColor colorWithRed:red green:(46.0f / 255.0f) blue:(43.0f / 255.0f) alpha:1.0f];
    label.highlightedTextColor = [UIColor whiteColor];
    label.font = [UIFont fontWithName:AppFontName() size:17.0f];
    label.textAlignment = NSTextAlignmentCenter;

    CGFloat width = 240.0f;
    if (neSceneManager::isPadDisplay()) {
        CGFloat sysVer = [[UIDevice currentDevice].systemVersion floatValue];
        if (sysVer >= 7.0f) {
            width = 252.0f;
        }
    }
    [label setFrame:CGRectMake(50.0f, 22.0f, width, 20.0f)];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5f;
    label.text = text;
    [self.contentView addSubview:label];

    // Answer-number badge: the "top" glyph (1-based) for unanswered / chosen rows,
    // otherwise the neutral "non" glyph.
    NSString *idName;
    if (selectId < 0 || selectId == answerId) {
        idName = [NSString stringWithFormat:@"pq_ansbase_top_%d", answerId + 1];
    } else {
        idName = [NSString stringWithFormat:@"pq_ansbase_non"];
    }
    UIImage *idImage = [UIImage imageNamed:idName];
    _answerIdView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f,
                                                                  idImage.size.width,
                                                                  idImage.size.height)];
    [_answerIdView setImage:idImage];
    [self.contentView addSubview:_answerIdView];
}

@end
