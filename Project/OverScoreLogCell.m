//
//  OverScoreLogCell.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "OverScoreLogCell.h"

#import "AppFont.h"   // AppFontName() == getFontNameDFSoGei() -> @"DFSoGei-W5-WIN-RKSJ-H"

// The log-data element (from OverScoreLogViewController's _overScoreLogDataArray) fills the
// struct below via -getValue:. TODO(dep): the concrete element class is not yet reconstructed;
// declaring the selector here lets the cell copy the row's values out of it.
@interface NSObject (OverScoreLogDataValue)
- (void)getValue:(void *)outValue;
@end

// Plain C struct the data element writes into (Ghidra ivar m_overScoreLogData, filled at
// param_1 + m_overScoreLogData). Only the fields this cell reads are named; pointers are
// __unsafe_unretained because the element owns the objects, the cell only borrows them.
typedef struct OverScoreLogData {
    int32_t reserved0;                        // +0x00 — not read by this cell
    __unsafe_unretained NSString *musicName;  // +0x04
    int32_t sheetType;                        // +0x08 — 0 normal, 1 helper, 2 ex
    __unsafe_unretained NSString *friendName; // +0x0c
    __unsafe_unretained NSString *updateDate; // +0x10
    int32_t myScore;                          // +0x14
    int32_t friendScore;                      // +0x18
} OverScoreLogData;

@implementation OverScoreLogCell {
    OverScoreLogData m_overScoreLogData;
    UILabel *m_lblMusicName;
    UILabel *m_lblFriendName;
    UILabel *m_lblUpdateDate;
    UILabel *m_lblMyScore;
    UILabel *m_lblFriendScore;
    UIImageView *m_imgViewSheet;
}

// @ 0x69760 — plain non-selectable cell; its content is bound by the VC on reuse.
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

// dealloc @ 0x697a8 — ARC-omitted (super-only; frees no C memory).
// setSelected:animated: @ 0x697d4 — super-only override, omitted.
// .cxx_construct @ 0x6a29c — compiler-emitted C++ ivar constructor; not hand-written.

// @ 0x69804 — pull this row's values out of the data element, tear down any recycled
// subviews, then rebuild the banner background + five labels + sheet-icon image view. All
// frames/fonts recovered from the binary; the iOS 6 vs 7+ layout split keys off
// -[UIDevice systemVersion].floatValue exactly as the original does.
- (void)setOverScoreLogData:(id)overScoreLogData {
    CGFloat sysVer = [[UIDevice currentDevice].systemVersion floatValue];
    BOOL legacy = sysVer < 7.0;   // pre-iOS 7 layout

    [overScoreLogData getValue:&m_overScoreLogData];

    // Reuse cleanup: drop any subviews left over from a previous binding.
    if (m_lblMusicName)   { [m_lblMusicName removeFromSuperview];   m_lblMusicName = nil; }
    if (m_lblFriendName)  { [m_lblFriendName removeFromSuperview];  m_lblFriendName = nil; }
    if (m_lblUpdateDate)  { [m_lblUpdateDate removeFromSuperview];  m_lblUpdateDate = nil; }
    if (m_lblMyScore)     { [m_lblMyScore removeFromSuperview];     m_lblMyScore = nil; }
    if (m_lblFriendScore) { [m_lblFriendScore removeFromSuperview]; m_lblFriendScore = nil; }
    if (m_imgViewSheet)   { [m_imgViewSheet removeFromSuperview];   m_imgViewSheet = nil; }

    // Banner background image sized to its own artwork.
    UIImageView *bg = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *bannerImg = [UIImage imageNamed:@"osl_friend_banner"];
    [bg setImage:bannerImg];
    [bg setFrame:CGRectMake(0.0f, 0.0f, bannerImg.size.width, bannerImg.size.height)];
    self.backgroundView = bg;
    self.backgroundColor = [UIColor clearColor];

    // Music name (DFSoGei 16, black on white-highlight).
    m_lblMusicName = [[UILabel alloc] initWithFrame:CGRectMake(28.0f, 23.0f,
                                                               legacy ? 160.0f : 172.0f, 18.0f)];
    m_lblMusicName.backgroundColor = [UIColor clearColor];
    m_lblMusicName.textColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
    m_lblMusicName.highlightedTextColor = [UIColor whiteColor];
    m_lblMusicName.font = [UIFont fontWithName:AppFontName() size:16.0f];
    m_lblMusicName.text = m_overScoreLogData.musicName;
    [self.contentView addSubview:m_lblMusicName];

    // Sheet/difficulty icon (only 0/1/2 are handled by the binary).
    NSString *sheetImageName = nil;
    if (m_overScoreLogData.sheetType == 2)      sheetImageName = @"acv_custom_ex";
    else if (m_overScoreLogData.sheetType == 1) sheetImageName = @"acv_custom_heper"; // sic (binary spelling)
    else if (m_overScoreLogData.sheetType == 0) sheetImageName = @"acv_custom_normal";
    UIImage *sheetImg = sheetImageName ? [UIImage imageNamed:sheetImageName] : nil;

    m_imgViewSheet = [[UIImageView alloc] initWithFrame:self.bounds];
    [m_imgViewSheet setImage:sheetImg];
    [m_imgViewSheet setFrame:CGRectMake(legacy ? 190.0f : 207.0f, 24.0f,
                                        sheetImg.size.width, sheetImg.size.height)];
    [self.contentView addSubview:m_imgViewSheet];

    // Friend name (BullyBold 11, dark gray RGB 89/81/79).
    m_lblFriendName = [[UILabel alloc] initWithFrame:CGRectMake(legacy ? 81.0f : 83.0f,
                                                               legacy ? 5.0f : 6.0f, 87.0f,
                                                               legacy ? 12.0f : 10.0f)];
    m_lblFriendName.backgroundColor = [UIColor clearColor];
    m_lblFriendName.textColor = [UIColor colorWithRed:0.34902f green:0.31765f blue:0.30980f alpha:1.0f];
    m_lblFriendName.highlightedTextColor = [UIColor whiteColor];
    m_lblFriendName.font = [UIFont fontWithName:@"BullyBold" size:11.0f]; // getFontNameBullyBold() @ 0x5ef90
    m_lblFriendName.text = m_overScoreLogData.friendName;
    [self.contentView addSubview:m_lblFriendName];

    // My score (BullyBold 16, black, right-aligned).
    m_lblMyScore = [[UILabel alloc] initWithFrame:CGRectMake(legacy ? 198.0f : 207.0f,
                                                            legacy ? 60.0f : 61.0f,
                                                            legacy ? 75.0f : 85.0f, 18.0f)];
    m_lblMyScore.backgroundColor = [UIColor clearColor];
    m_lblMyScore.textColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
    m_lblMyScore.highlightedTextColor = [UIColor whiteColor];
    m_lblMyScore.font = [UIFont fontWithName:@"BullyBold" size:16.0f];
    m_lblMyScore.textAlignment = NSTextAlignmentRight;
    m_lblMyScore.text = [NSString stringWithFormat:@"%d", m_overScoreLogData.myScore];
    [self.contentView addSubview:m_lblMyScore];

    // Friend score (BullyBold 16, black, right-aligned).
    m_lblFriendScore = [[UILabel alloc] initWithFrame:CGRectMake(28.0f, legacy ? 60.0f : 61.0f,
                                                                legacy ? 75.0f : 85.0f, 18.0f)];
    m_lblFriendScore.backgroundColor = [UIColor clearColor];
    m_lblFriendScore.textColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
    m_lblFriendScore.highlightedTextColor = [UIColor whiteColor];
    m_lblFriendScore.font = [UIFont fontWithName:@"BullyBold" size:16.0f];
    m_lblFriendScore.textAlignment = NSTextAlignmentRight;
    m_lblFriendScore.text = [NSString stringWithFormat:@"%d", m_overScoreLogData.friendScore];
    [self.contentView addSubview:m_lblFriendScore];

    // Update date (BullyBold 9, dark gray) — "更新日：%@".
    m_lblUpdateDate = [[UILabel alloc] initWithFrame:CGRectMake(legacy ? 195.0f : 210.0f,
                                                               legacy ? 5.0f : 6.0f, 90.0f,
                                                               legacy ? 12.0f : 10.0f)];
    m_lblUpdateDate.backgroundColor = [UIColor clearColor];
    m_lblUpdateDate.textColor = [UIColor colorWithRed:0.34902f green:0.31765f blue:0.30980f alpha:1.0f];
    m_lblUpdateDate.highlightedTextColor = [UIColor whiteColor];
    m_lblUpdateDate.font = [UIFont fontWithName:@"BullyBold" size:9.0f];
    m_lblUpdateDate.text = [NSString stringWithFormat:@"更新日：%@", m_overScoreLogData.updateDate];
    [self.contentView addSubview:m_lblUpdateDate];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
