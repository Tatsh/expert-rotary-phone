//
//  CheckerDetail.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  .mm because init/back reach the C++ engine bridge
//  (neSceneManager::isPadDisplay(), neEngine::playSystemSe()).
//
//  The screen plots three scores per arcade sheet on a vertical "0..100%"
//  graph:
//    * top  — the venue top score  (icon/plate/digit set
//    "..._top"/"scobase_?top")
//    * ave  — the venue mean score ("..._ave"/"scobase_?ave")
//    * you  — the player's best    ("..._you"/"scobase_?you")
//  Sheets are indexed 0..3 = EX / Hyper / Normal / Easy (matching the image
//  name suffixes e / h / n / easy). A score of -1 means "no record" and that
//  sheet's column is skipped. Score values run 0..100000 (percent x 1000).
//

#import "CheckerDetail.h"

#import "AppDelegate.h"     // +appDelegate / displayType
#import "AppFont.h"         // AppFontName() == getFontNameDFSoGei()
#import "ArcadeScoreData.h" // in-project song record (top/mean/my scores, names)
#import "neEngineBridge.h"

// Score-line images behind each sheet column (0/off = dim, 1/on = lit). The
// _960 variants are the tall (960px) phone layout; the plain set is the
// iPad/short one.
static NSString *const kBaselineOff[4] = {
    @"ppc_ps_baseline_e0", @"ppc_ps_baseline_h0", @"ppc_ps_baseline_n0", @"ppc_ps_baseline_easy0"};
static NSString *const kBaselineOn[4] = {
    @"ppc_ps_baseline_e1", @"ppc_ps_baseline_h1", @"ppc_ps_baseline_n1", @"ppc_ps_baseline_easy1"};
static NSString *const kBaselineOff960[4] = {@"ppc_ps_baseline_e0_960",
                                             @"ppc_ps_baseline_h0_960",
                                             @"ppc_ps_baseline_n0_960",
                                             @"ppc_ps_baseline_easy0_960"};
static NSString *const kBaselineOn960[4] = {@"ppc_ps_baseline_e1_960",
                                            @"ppc_ps_baseline_h1_960",
                                            @"ppc_ps_baseline_n1_960",
                                            @"ppc_ps_baseline_easy1_960"};

// Plotted marker icons (off = dim when the sheet is not selected, on = lit).
static NSString *const kTopIconOff[4] = {
    @"ppc_ps_i_e_topoff", @"ppc_ps_i_h_topoff", @"ppc_ps_i_n_topoff", @"ppc_ps_i_easy_topoff"};
static NSString *const kTopIconOn[4] = {
    @"ppc_ps_i_e_top", @"ppc_ps_i_h_top", @"ppc_ps_i_n_top", @"ppc_ps_i_easy_top"};
static NSString *const kAveIconOff[4] = {
    @"ppc_ps_i_e_aveoff", @"ppc_ps_i_h_aveoff", @"ppc_ps_i_n_aveoff", @"ppc_ps_i_easy_aveoff"};
static NSString *const kAveIconOn[4] = {
    @"ppc_ps_i_e_ave", @"ppc_ps_i_h_ave", @"ppc_ps_i_n_ave", @"ppc_ps_i_easy_ave"};
static NSString *const kYouIconOff[4] = {
    @"ppc_ps_i_e_youoff", @"ppc_ps_i_h_youoff", @"ppc_ps_i_n_youoff", @"ppc_ps_i_easy_youoff"};
static NSString *const kYouIconOn[4] = {
    @"ppc_ps_i_e_you", @"ppc_ps_i_h_you", @"ppc_ps_i_n_you", @"ppc_ps_i_easy_you"};

// Score-plate (number background) images per sheet.
static NSString *const kScoBaseTop[4] = {@"ppc_ps_scobase_etop",
                                         @"ppc_ps_scobase_htop",
                                         @"ppc_ps_scobase_ntop",
                                         @"ppc_ps_scobase_easytop"};
static NSString *const kScoBaseAve[4] = {@"ppc_ps_scobase_eave",
                                         @"ppc_ps_scobase_have",
                                         @"ppc_ps_scobase_nave",
                                         @"ppc_ps_scobase_easyave"};
static NSString *const kScoBaseYou[4] = {@"ppc_ps_scobase_eyou",
                                         @"ppc_ps_scobase_hyou",
                                         @"ppc_ps_scobase_nyou",
                                         @"ppc_ps_scobase_easyyou"};

// Column tag bases: sheet-select buttons are 200+sheet, name-mode plates
// 204+sheet.
static const NSInteger kSheetButtonTag[4] = {200, 201, 202, 203};
static const NSInteger kNamePlateTag[4] = {204, 205, 206, 207};

// Ghidra: setNavControllerViewFrameTall @ 0xd9750
// Block invoke — restores the navigation controller view to the "tall" split
// pane layout used when popping back to CheckerMusicViewController:
// CGRectMake(385, 182, 320, 716).
// Owner: CheckerDetail.touchedBackButton: (animations block @ ~0xd9678).
static void setNavControllerViewFrameTall(CheckerDetail *self) {
    self.navigationController.view.frame = CGRectMake(385.0f, 182.0f, 320.0f, 716.0f);
}

@interface CheckerDetail ()
- (void)touchedBackButton:(id)sender;
- (void)touchedSheetButton:(id)sender;
@end

@implementation CheckerDetail {
    ArcadeScoreData *_arcadeScoreData;
    int _selectedSheet; // 0..3, or -1 until the first scored sheet is found
    BOOL _isNameMode;   // top plate shows holder name (YES) vs score (NO)

    UIImageView *_scoreLineOff[4];
    UIImageView *_scoreLineOn[4];
    UIImageView *_topIconOff[4];
    UIImageView *_topIconOn[4];
    UIImageView *_meanIconOff[4];
    UIImageView *_meanIconOn[4];
    UIImageView *_myIconOff[4];
    UIImageView *_myIconOn[4];
    UIImageView *_topScoreBase[4]; // top-score plate (holds the top-score digits)
    UIImageView *_topNameBase[4];  // overlays _topScoreBase, holds the holder-name label
    UIImageView *_meanBase[4];     // venue-mean plate
    UIImageView *_myBase[4];       // personal-best plate
}

// @ 0xd7418 — redraw `image` through a device-gray bitmap context to grayscale
// it.
- (UIImage *)convertGrayScaleImage:(UIImage *)image {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context;
    if (image == nil) {
        context = CGBitmapContextCreate(NULL, 0, 0, 8, 0, colorSpace, (CGBitmapInfo)0);
    } else {
        context = CGBitmapContextCreate(NULL,
                                        (size_t)image.size.width,
                                        (size_t)image.size.height,
                                        8,
                                        0,
                                        colorSpace,
                                        (CGBitmapInfo)0);
    }
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(
        context, CGRectMake(0.0f, 0.0f, image.size.width, image.size.height), image.CGImage);
    CGImageRef grayCGImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *result = [UIImage imageWithCGImage:grayCGImage];
    CFRelease(grayCGImage);
    return result;
}

// @ 0xd752c
- (instancetype)initWithScoreData:(ArcadeScoreData *)scoreData {
    self = [super init];
    _arcadeScoreData = scoreData;
    _selectedSheet = -1;
    if (!self) {
        return self;
    }

    int displayType = [[AppDelegate appDelegate] displayType];
    BOOL isPad = neSceneManager::isPadDisplay();

    // Layout nudges applied only on iPad (0 on phone), and differing by iOS
    // version.
    CGFloat headerYOffset = 0.0f;
    CGFloat contentYOffset = 0.0f;
    if (isPad) {
        if (UIDevice.currentDevice.systemVersion.floatValue >= 7.0f) {
            headerYOffset = 54.0f;
            contentYOffset = 94.0f;
        } else {
            headerYOffset = 10.0f;
            contentYOffset = 50.0f;
        }
    }

    // Per-sheet scores (index 0..3 = EX / Hyper / Normal / Easy). -1 = no record.
    int topScores[4], meanScores[4], myScores[4];
    topScores[0] = scoreData.topScoreEx.intValue;
    meanScores[0] = scoreData.meanScoreEx.intValue;
    myScores[0] = scoreData.myScoreEx.intValue;
    topScores[1] = scoreData.topScoreH.intValue;
    meanScores[1] = scoreData.meanScoreH.intValue;
    myScores[1] = scoreData.myScoreH.intValue;
    topScores[2] = scoreData.topScoreN.intValue;
    meanScores[2] = scoreData.meanScoreN.intValue;
    myScores[2] = scoreData.myScoreN.intValue;
    topScores[3] = scoreData.topScoreEs.intValue;
    meanScores[3] = scoreData.meanScoreEs.intValue;
    myScores[3] = scoreData.myScoreEs.intValue;

    // Background: phone gets a full paper image, iPad a clear view.
    if (!isPad) {
        CGRect bgFrame = self.view ? self.view.frame : CGRectZero;
        UIImageView *bg = [[UIImageView alloc] initWithFrame:bgFrame];
        [bg setImage:[UIImage imageNamed:@"friman_bg"]];
        [self.view addSubview:bg];
    } else {
        [self.view setBackgroundColor:[UIColor clearColor]];
    }

    // Header banner + song update-date / title / genre labels.
    UIImage *headerImg = [UIImage imageNamed:@"ppc_ps_header"];
    CGFloat headerY = headerYOffset + (displayType == 2 ? 18.0f : 8.0f);
    UIImageView *header = [[UIImageView alloc]
        initWithFrame:CGRectMake(5.0f, headerY, headerImg.size.width, headerImg.size.height)];
    [header setImage:headerImg];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy/MM/dd"];

    UILabel *dateLabel = [[UILabel alloc] init];
    dateLabel.backgroundColor = [UIColor clearColor];
    dateLabel.textColor = [UIColor colorWithRed:0.764706f green:0.2f blue:0.003922f alpha:1.0f];
    dateLabel.highlightedTextColor = [UIColor whiteColor];
    dateLabel.font = [UIFont fontWithName:AppFontName() size:13.0f];
    dateLabel.textAlignment = NSTextAlignmentLeft;
    dateLabel.adjustsFontSizeToFitWidth = YES;
    dateLabel.minimumScaleFactor = 10.0f;
    dateLabel.text = [dateFormatter stringFromDate:scoreData.updateDate];
    [dateLabel setFrame:CGRectMake(180.0f, 11.0f, 78.0f, 16.0f)];
    [header addSubview:dateLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [UIColor colorWithRed:0.341176f
                                           green:0.317647f
                                            blue:0.298039f
                                           alpha:1.0f];
    titleLabel.highlightedTextColor = [UIColor whiteColor];
    titleLabel.font = [UIFont fontWithName:AppFontName() size:13.0f];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 10.0f;
    titleLabel.text = scoreData.title;
    [titleLabel setFrame:CGRectMake(17.0f, 31.0f, 210.0f, 18.0f)];
    [header addSubview:titleLabel];

    UILabel *genreLabel = [[UILabel alloc] init];
    genreLabel.backgroundColor = [UIColor clearColor];
    genreLabel.textColor = [UIColor colorWithRed:0.960784f
                                           green:0.960784f
                                            blue:0.960784f
                                           alpha:1.0f];
    genreLabel.highlightedTextColor = [UIColor whiteColor];
    genreLabel.font = [UIFont fontWithName:AppFontName() size:13.0f];
    genreLabel.textAlignment = NSTextAlignmentCenter;
    genreLabel.adjustsFontSizeToFitWidth = YES;
    genreLabel.minimumScaleFactor = 10.0f;
    genreLabel.text = scoreData.genre;
    [genreLabel setFrame:CGRectMake(17.0f, 50.0f, 210.0f, 18.0f)];
    [header addSubview:genreLabel];

    [self.view addSubview:header];

    // The graph canvas: base grid image plus everything plotted onto it.
    NSString *const *scoreLineOffNames;
    NSString *const *scoreLineOnNames;
    UIImage *graphBaseImg;
    CGFloat topY;     // graph Y of a 0% score (the baseline the columns rise from)
    CGFloat baseImgY; // Y of the graph image inside the view
    if (displayType == 2) {
        graphBaseImg = [UIImage imageNamed:@"ppc_ps_base"];
        scoreLineOffNames = kBaselineOff;
        scoreLineOnNames = kBaselineOn;
        topY = 340.0f;
        baseImgY = 108.0f;
    } else {
        graphBaseImg = [UIImage imageNamed:@"ppc_ps_base_960"];
        scoreLineOffNames = kBaselineOff960;
        scoreLineOnNames = kBaselineOn960;
        topY = 290.0f;
        baseImgY = 88.0f;
    }
    CGFloat graphH = topY - 40.0f; // pixels spanning 0..100000 score
    UIImageView *graphBase =
        [[UIImageView alloc] initWithFrame:CGRectMake(10.0f,
                                                      contentYOffset + baseImgY,
                                                      graphBaseImg.size.width,
                                                      graphBaseImg.size.height)];
    [graphBase setImage:graphBaseImg];
    [graphBase setUserInteractionEnabled:YES];

    // Score-line strips per column; lit strip on the selected sheet, dim on the
    // rest.
    CGFloat lineX = 45.0f;
    for (int i = 0; i < 4; i++) {
        if (topScores[i] >= 0) {
            if (_selectedSheet == -1) {
                _selectedSheet = i;
            }
            UIImage *offImg = [UIImage imageNamed:scoreLineOffNames[i]];
            UIImage *onImg = [UIImage imageNamed:scoreLineOnNames[i]];
            _scoreLineOff[i] = [[UIImageView alloc]
                initWithFrame:CGRectMake(lineX, 6.0f, offImg.size.width, offImg.size.height)];
            [_scoreLineOff[i] setImage:offImg];
            _scoreLineOn[i] = [[UIImageView alloc]
                initWithFrame:CGRectMake(lineX, 6.0f, offImg.size.width, offImg.size.height)];
            [_scoreLineOn[i] setImage:onImg];
            BOOL notSelected = (i != _selectedSheet);
            [_scoreLineOff[i] setHidden:!notSelected];
            [_scoreLineOn[i] setHidden:notSelected];
            [graphBase addSubview:_scoreLineOff[i]];
            [graphBase addSubview:_scoreLineOn[i]];
        }
        lineX += 65.0f;
    }

    // Plotted marker icons: top / ave / you, each at its score height in the
    // column.
    CGFloat iconX = 52.0f;
    for (int i = 0; i < 4; i++) {
        if (topScores[i] >= 0) {
            CGFloat topIconY = topY - topScores[i] * graphH / 100000.0f;
            CGFloat aveIconY = topY - graphH * meanScores[i] / 100000.0f;
            CGFloat youIconY = topY - graphH * myScores[i] / 100000.0f;

            UIImage *topOffImg = [UIImage imageNamed:kTopIconOff[i]];
            UIImage *topOnImg = [UIImage imageNamed:kTopIconOn[i]];
            _topIconOff[i] = [[UIImageView alloc]
                initWithFrame:CGRectMake(
                                  iconX, topIconY, topOffImg.size.width, topOffImg.size.height)];
            [_topIconOff[i] setImage:topOffImg];
            _topIconOn[i] = [[UIImageView alloc]
                initWithFrame:CGRectMake(
                                  iconX, topIconY, topOffImg.size.width, topOffImg.size.height)];
            [_topIconOn[i] setImage:topOnImg];

            UIImage *aveOffImg = [UIImage imageNamed:kAveIconOff[i]];
            UIImage *aveOnImg = [UIImage imageNamed:kAveIconOn[i]];
            _meanIconOff[i] = [[UIImageView alloc]
                initWithFrame:CGRectMake(
                                  iconX, aveIconY, aveOffImg.size.width, aveOffImg.size.height)];
            [_meanIconOff[i] setImage:aveOffImg];
            _meanIconOn[i] = [[UIImageView alloc]
                initWithFrame:CGRectMake(
                                  iconX, aveIconY, aveOffImg.size.width, aveOffImg.size.height)];
            [_meanIconOn[i] setImage:aveOnImg];

            UIImage *youOffImg = [UIImage imageNamed:kYouIconOff[i]];
            UIImage *youOnImg = [UIImage imageNamed:kYouIconOn[i]];
            _myIconOff[i] = [[UIImageView alloc]
                initWithFrame:CGRectMake(
                                  iconX, youIconY, youOffImg.size.width, youOffImg.size.height)];
            [_myIconOff[i] setImage:youOffImg];
            _myIconOn[i] = [[UIImageView alloc]
                initWithFrame:CGRectMake(
                                  iconX, youIconY, youOffImg.size.width, youOffImg.size.height)];
            [_myIconOn[i] setImage:youOnImg];

            BOOL notSelected = (i != _selectedSheet);
            if (notSelected) {
                [_topIconOff[i] setHidden:NO];
                [_topIconOn[i] setHidden:YES];
                [_meanIconOff[i] setHidden:NO];
                [_meanIconOn[i] setHidden:YES];
                [_myIconOff[i] setHidden:NO];
                [_myIconOn[i] setHidden:YES];
            } else {
                [_topIconOff[i] setHidden:YES];
                [_topIconOn[i] setHidden:NO];
                [_meanIconOff[i] setHidden:YES];
                [_meanIconOn[i] setHidden:NO];
                [_myIconOff[i] setHidden:YES];
                [_myIconOn[i] setHidden:NO];
            }
            [graphBase addSubview:_topIconOff[i]];
            [graphBase addSubview:_topIconOn[i]];
            [graphBase addSubview:_meanIconOff[i]];
            [graphBase addSubview:_meanIconOn[i]];
            [graphBase addSubview:_myIconOff[i]];
            [graphBase addSubview:_myIconOn[i]];
        }
        iconX += 65.0f;
    }

    // Score plates (number backgrounds) per column. The three plates in a column
    // are driven by their score heights but nudged apart by a plate-height so
    // they never overlap, and clamped between Y=55 and the graph baseline. The
    // precise fixed-point clamp chain is transcribed from the binary (init @
    // 0xd752c) and reproduced here.
    CGFloat plateBaseline = topY + 40.0f;
    CGFloat plateColX = 0.0f;
    for (int i = 0; i < 4; i++) {
        if (topScores[i] >= 0) {
            CGFloat labelXAdj = (i == 3) ? -24.0f : 78.0f;
            CGFloat colX = labelXAdj + plateColX;

            UIImage *topPlateImg = [UIImage imageNamed:kScoBaseTop[i]];
            UIImage *avePlateImg = [UIImage imageNamed:kScoBaseAve[i]];
            UIImage *youPlateImg = [UIImage imageNamed:kScoBaseYou[i]];
            CGFloat plateH = topPlateImg.size.height;

            // Raw graphed Y for each plate, floored at 55.
            CGFloat topRawY = (topY - 6.0f) - graphH * topScores[i] / 100000.0f;
            CGFloat aveRawY = (topY - 6.0f) - graphH * meanScores[i] / 100000.0f;
            CGFloat youRawY = (topY - 6.0f) - graphH * myScores[i] / 100000.0f;
            if (topRawY < 55.0f) {
                topRawY = 55.0f;
            }
            if (aveRawY < 55.0f) {
                aveRawY = 55.0f;
            }
            if (youRawY < 55.0f) {
                youRawY = 55.0f;
            }

            // Top plate keeps 3 plate-heights of room below it for the other two.
            CGFloat topPlateY = MIN(topRawY, plateBaseline - plateH * 3.0f);
            // The higher-scoring of you/ave sits just under the top plate; the other
            // sits under it, each at least a plate-height apart and above the
            // baseline.
            CGFloat avePlateY, youPlateY;
            if (myScores[i] < meanScores[i]) {
                avePlateY = MIN(MAX(aveRawY, topPlateY + plateH), plateBaseline - plateH * 2.0f);
                youPlateY = MIN(MAX(youRawY, avePlateY + plateH), plateBaseline - plateH);
            } else {
                youPlateY = MIN(MAX(youRawY, topPlateY + plateH), plateBaseline - plateH * 2.0f);
                avePlateY = MIN(MAX(aveRawY, youPlateY + plateH), plateBaseline - plateH);
            }

            _topScoreBase[i] =
                [[UIImageView alloc] initWithFrame:CGRectMake(colX,
                                                              topPlateY,
                                                              topPlateImg.size.width,
                                                              topPlateImg.size.height)];
            [_topScoreBase[i] setImage:topPlateImg];
            [_topScoreBase[i] setUserInteractionEnabled:YES];
            [_topScoreBase[i] setTag:kNamePlateTag[i]];

            // Transparent overlay on the top plate that carries the holder-name
            // label.
            _topNameBase[i] =
                [[UIImageView alloc] initWithFrame:CGRectMake(colX,
                                                              topPlateY,
                                                              topPlateImg.size.width,
                                                              topPlateImg.size.height)];
            [_topNameBase[i] setImage:nil];
            [_topNameBase[i] setUserInteractionEnabled:YES];
            [_topNameBase[i] setTag:kNamePlateTag[i]];

            _meanBase[i] = [[UIImageView alloc] initWithFrame:CGRectMake(colX,
                                                                         avePlateY,
                                                                         avePlateImg.size.width,
                                                                         avePlateImg.size.height)];
            [_meanBase[i] setImage:avePlateImg];

            _myBase[i] = [[UIImageView alloc] initWithFrame:CGRectMake(colX,
                                                                       youPlateY,
                                                                       youPlateImg.size.width,
                                                                       youPlateImg.size.height)];
            [_myBase[i] setImage:youPlateImg];

            BOOL notSelected = (i != _selectedSheet);
            if (notSelected) {
                [_topScoreBase[i] setHidden:YES];
                [_topNameBase[i] setHidden:YES];
                [_meanBase[i] setHidden:YES];
                [_myBase[i] setHidden:YES];
            } else {
                [_topScoreBase[i] setHidden:NO];
                [_topNameBase[i] setHidden:YES];
                [_meanBase[i] setHidden:NO];
                [_myBase[i] setHidden:NO];
            }
            [graphBase addSubview:_topScoreBase[i]];
            [graphBase addSubview:_topNameBase[i]];
            [graphBase addSubview:_meanBase[i]];
            [graphBase addSubview:_myBase[i]];
        }
        plateColX += 65.0f;
    }

    // Invisible touch buttons over each scored column to switch the active sheet.
    CGFloat btnX = 45.0f;
    for (int i = 0; i < 4; i++) {
        if (topScores[i] >= 0) {
            UIButton *sheetButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [sheetButton setFrame:CGRectMake(btnX, 6.0f, 45.0f, 45.0f)];
            [sheetButton setTag:kSheetButtonTag[i]];
            [sheetButton setBackgroundColor:[UIColor colorWithWhite:1.0f alpha:0.0f]];
            [sheetButton setExclusiveTouch:YES];
            [sheetButton addTarget:self
                            action:@selector(touchedSheetButton:)
                  forControlEvents:UIControlEventTouchUpInside];
            [graphBase addSubview:sheetButton];
        }
        btnX += 65.0f;
    }

    [self.view addSubview:graphBase];

    // Draw the score digits (and, for the top plate, the holder-name label).
    for (int i = 0; i < 4; i++) {
        if (topScores[i] >= 0) {
            // Top score digits, right-to-left, onto _topScoreBase; the holder-name
            // label is (re)built onto _topNameBase alongside each digit, as in the
            // binary.
            int topValue = topScores[i];
            int topDigits = 1;
            for (int t = topValue; t > 9; t /= 10) {
                topDigits++;
            }
            {
                CGFloat digitX = 60.0f;
                int value = topValue;
                for (int d = 0; d < topDigits; d++) {
                    UIImage *digitImg = [UIImage
                        imageNamed:[NSString stringWithFormat:@"ppc_ps_num_top_%d", value % 10]];
                    UIImageView *digitView = [[UIImageView alloc] initWithImage:digitImg];
                    [digitView
                        setFrame:CGRectMake(
                                     digitX, 25.0f, digitImg.size.width, digitImg.size.height)];
                    [_topScoreBase[i] addSubview:digitView];

                    UILabel *nameLabel = [[UILabel alloc] init];
                    nameLabel.backgroundColor = [UIColor clearColor];
                    nameLabel.highlightedTextColor = [UIColor whiteColor];
                    nameLabel.font = [UIFont fontWithName:AppFontName() size:10.0f];
                    nameLabel.textAlignment = NSTextAlignmentCenter;
                    nameLabel.adjustsFontSizeToFitWidth = YES;
                    nameLabel.minimumScaleFactor = 10.0f;
                    [nameLabel setFrame:CGRectMake(11.0f, 23.0f, 60.0f, 16.0f)];
                    switch (i) {
                    case 0:
                        nameLabel.textColor = [UIColor colorWithRed:0.960784f
                                                              green:0.960784f
                                                               blue:0.960784f
                                                              alpha:1.0f];
                        nameLabel.text = scoreData.topNameEx;
                        break;
                    case 1:
                        nameLabel.textColor = [UIColor colorWithRed:0.341176f
                                                              green:0.317647f
                                                               blue:0.298039f
                                                              alpha:1.0f];
                        nameLabel.text = scoreData.topNameH;
                        break;
                    case 2:
                        nameLabel.textColor = [UIColor colorWithRed:0.341176f
                                                              green:0.317647f
                                                               blue:0.298039f
                                                              alpha:1.0f];
                        nameLabel.text = scoreData.topNameN;
                        break;
                    case 3:
                        nameLabel.textColor = [UIColor colorWithRed:0.960784f
                                                              green:0.960784f
                                                               blue:0.960784f
                                                              alpha:1.0f];
                        nameLabel.text = scoreData.topNameEs;
                        break;
                    }
                    [_topNameBase[i] addSubview:nameLabel];

                    digitX -= 10.0f;
                    value /= 10;
                }
            }

            // Venue-mean digits onto _meanBase.
            int aveValue = meanScores[i];
            int aveDigits = 1;
            for (int t = aveValue; t > 9; t /= 10) {
                aveDigits++;
            }
            {
                CGFloat digitX = 60.0f;
                int value = aveValue;
                for (int d = 0; d < aveDigits; d++) {
                    UIImage *digitImg = [UIImage
                        imageNamed:[NSString stringWithFormat:@"ppc_ps_num_ave_%d", value % 10]];
                    UIImageView *digitView = [[UIImageView alloc] initWithImage:digitImg];
                    [digitView
                        setFrame:CGRectMake(
                                     digitX, 25.0f, digitImg.size.width, digitImg.size.height)];
                    [_meanBase[i] addSubview:digitView];
                    digitX -= 10.0f;
                    value /= 10;
                }
            }

            // Personal-best digits onto _myBase.
            int youValue = myScores[i];
            int youDigits = 1;
            for (int t = youValue; t > 9; t /= 10) {
                youDigits++;
            }
            {
                CGFloat digitX = 60.0f;
                int value = youValue;
                for (int d = 0; d < youDigits; d++) {
                    UIImage *digitImg = [UIImage
                        imageNamed:[NSString stringWithFormat:@"ppc_ps_num_you_%d", value % 10]];
                    UIImageView *digitView = [[UIImageView alloc] initWithImage:digitImg];
                    [digitView
                        setFrame:CGRectMake(
                                     digitX, 25.0f, digitImg.size.width, digitImg.size.height)];
                    [_myBase[i] addSubview:digitView];
                    digitX -= 10.0f;
                    value /= 10;
                }
            }
        }
    }

    // Custom back button in the left nav slot.
    NSString *backName = isPad ? @"pl_checker_return" : @"navi_btn_back";
    UIImage *backImg = [UIImage imageNamed:backName];
    UIButton *backButton = [[UIButton alloc]
        initWithFrame:CGRectMake(0.0f, 0.0f, backImg.size.width, backImg.size.height)];
    [backButton setBackgroundImage:backImg forState:UIControlStateNormal];
    [backButton addTarget:self
                   action:@selector(touchedBackButton:)
         forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    if (neSceneManager::isPadDisplay()) {
        self.navigationItem.hidesBackButton = YES;
    }
    return self;
}

// dealloc @ 0xd9620 — super-only override, ARC/omit (releases ivars only).
// viewDidLoad @ 0xd964c — super-only override, ARC/omit (no added behavior).

// @ 0xd9678 — back to the song list; on iPad first shrink the split nav pane.
- (void)touchedBackButton:(id)sender {
    neEngine::playSystemSe(2); // cancel SE
    if (neSceneManager::isPadDisplay()) {
        [UIView animateWithDuration:0.4f
                              delay:0.0f
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                           setNavControllerViewFrameTall(
                               self); // Ghidra: setNavControllerViewFrameTall @ 0xd9750
                         }
                         completion:nil];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0xd97c4 — switch the active sheet (button tag 200..203), lighting its
// column and dimming the previously selected one.
- (void)touchedSheetButton:(id)sender {
    NSInteger tag = [sender tag];
    if ((NSUInteger)(tag - 200) >= 4) {
        return;
    }
    int sheet = (int)(tag - 200); // kSheetButtonTag maps identically to the sheet index
    if (_selectedSheet == sheet) {
        return;
    }
    neEngine::playSystemSe(2);

    for (int i = 0; i < 4; i++) {
        if (i == sheet) {
            // Light the newly selected column.
            [_scoreLineOff[i] setHidden:YES];
            [_topIconOff[i] setHidden:YES];
            [_meanIconOff[i] setHidden:YES];
            [_myIconOff[i] setHidden:YES];
            [_scoreLineOn[i] setHidden:NO];
            [_topIconOn[i] setHidden:NO];
            [_meanIconOn[i] setHidden:NO];
            [_myIconOn[i] setHidden:NO];
            // Score vs. name plate depends on the current name mode.
            if (_isNameMode) {
                [_topScoreBase[i] setHidden:YES];
                [_topNameBase[i] setHidden:NO];
            } else {
                [_topScoreBase[i] setHidden:NO];
                [_topNameBase[i] setHidden:YES];
            }
            [_meanBase[i] setHidden:NO];
            [_myBase[i] setHidden:NO];
        } else {
            // Dim every other column.
            [_scoreLineOff[i] setHidden:NO];
            [_topIconOff[i] setHidden:NO];
            [_meanIconOff[i] setHidden:NO];
            [_myIconOff[i] setHidden:NO];
            [_scoreLineOn[i] setHidden:YES];
            [_topIconOn[i] setHidden:YES];
            [_meanIconOn[i] setHidden:YES];
            [_myIconOn[i] setHidden:YES];
            [_topScoreBase[i] setHidden:YES];
            [_topNameBase[i] setHidden:YES];
            [_meanBase[i] setHidden:YES];
            [_myBase[i] setHidden:YES];
        }
    }
    _selectedSheet = sheet;
}

// @ 0xd9aac — tapping the selected column's score plate (tag 204..207) flips
// between showing the top score and the top holder's name.
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSInteger tag = [[[touches anyObject] view] tag];
    if ((NSUInteger)(tag - 204) >= 4) {
        return;
    }
    int sheet = (int)(tag - 204); // kNamePlateTag maps identically to the sheet index
    if (_selectedSheet != sheet) {
        return;
    }
    _isNameMode = !_isNameMode;
    neEngine::playSystemSe(2);
    if (_isNameMode) {
        [_topScoreBase[sheet] setHidden:YES];
        [_topNameBase[sheet] setHidden:NO];
    } else {
        [_topScoreBase[sheet] setHidden:NO];
        [_topNameBase[sheet] setHidden:YES];
    }
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
