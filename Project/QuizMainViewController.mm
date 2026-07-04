//
//  QuizMainViewController.mm
//  pop'n rhythmin
//
//  See QuizMainViewController.h. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin. Objective-C++ for the C++ neSceneManager / neEngine singletons. ARC.
//
//  Honesty notes:
//   - Networking: -startGetQuizHttp GETs +[StoreUtil getQuizURL]; -startReplyQuizHttp
//     POSTs body "uuid=<urlEncoded uuId>&id=<quizId>&is_correct=<0|1>" (Content-Type
//     "application/json", exact CFString) to +[StoreUtil replyQuizURL]. Both run through
//     Downloader with self as delegate; the shared -downloaderFinished: dispatches to
//     -getQuizFinished / -replyQuizFinished by matching the finished Downloader.
//   - -getQuizFinished parses {QuizId, Question, RightAns, AnsList:[{Text}]}. A question
//     newer than UserSettingData.lastAnswerQuizId is shown (with <br>/<BR> -> newline);
//     an already-answered one jumps straight to -drawResult. ErrorCode 1 also draws the
//     result; ErrorCode 0/99 (and a nil/short payload) raise the network-failure alert.
//   - -replyQuizFinished persists the returned TotalCorrect/TotalIncorrect/Consecutive
//     via UserSettingData, stamps the picked row with pq_answer_ok / pq_answer_ng, shows
//     the matching board (○/✕) + speech-bubble and plays se24_quiz_o (correct) or
//     se25_quiz_x (wrong). Every 5th correct answer grants a character ticket and arms
//     the present popup (_presentSt = 1).
//   - -touchesBegan:withEvent: (after the result board is up) reveals the present window
//     on the first tap (_presentSt 1 -> 2, plays se08_bonus_fai) and fades it out on the
//     next (_presentSt 2 -> 0). The network-failure message is the exact UTF-16LE decode
//     "通信に失敗しました。\n電波状態の良い場所でやり直して下さい。".
//   - The three quiz SEs are loaded into _sdRscId in -initWithStyle: and released in
//     -dealloc (kept, since dealloc also cancels the in-flight Downloaders).
//   - APPROXIMATION: the table-header ("blackboard") container and its child image/label
//     frames are rebuilt from the binary's vectorised CGRect math; the literal offsets
//     (17 / 55 / 117 / 197 / 222 …) are exact, but a few centring / container-size
//     computations are reconstructed rather than byte-verified.
//

#import "QuizMainViewController.h"

#import "QuizCell.h"          // one row per answer choice
#import "TouchableTableView.h" // pass-through table used for the header/board taps
#import "CommonAlertView.h"   // network-failure alert
#import "Downloader.h"        // Downloader + DownloaderDelegate
#import "StoreUtil.h"         // +getQuizURL / +replyQuizURL / urlEncodeString()
#import "AppDelegate.h"       // +appDelegate.uuId
#import "UserSettingData.h"   // quiz totals + charaTicket
#import "AudioManager.h"      // quiz SE load/play/release
#import "AppFont.h"           // AppFontName()
#import "neEngineBridge.h"    // neSceneManager::isPadDisplay/rootViewController, neEngine::playSystemSe

// Number of decimal digits of `value` (min 1, so 0 -> 1). Ghidra: countDigits @ 0x2d884.
static int QuizCountDigits(int value) {
    int digits = 1;
    while (value > 9) {
        digits++;
        value /= 10;
    }
    return digits;
}

@interface QuizMainViewController () <DownloaderDelegate>
- (void)touchedBackButton:(id)sender;
- (void)getQuizFinished;
- (void)replyQuizFinished;
- (void)startGetQuizHttp;
- (void)startReplyQuizHttp;
- (void)drawResult;
@end

@implementation QuizMainViewController {
    UIViewController *_dummyView;             // dimmed overlay hosting the download spinner
    UILabel *_questionLbl;                    // question text on the blackboard header
    UIImageView *_rightView;                  // "○" board (shown on a correct answer)
    UIImageView *_wrongView;                  // "✕" board (shown on a wrong answer)
    UIImageView *_blackBoardView;             // question blackboard
    UIImageView *_blackBoardResultView;       // result blackboard (totals)
    UIImageView *_hanamaruView;               // ○/✕ stamp over the picked row
    UIImageView *_defSsmView;                 // default speech bubble
    UIImageView *_rightSsmView;               // correct speech bubble
    UIImageView *_wrongSsmView;               // wrong speech bubble
    UIView *_presentBaseView;                 // dimmed present-reward popup host
    Downloader *_dlQuiz;                      // in-flight get-quiz request
    Downloader *_dlAnswer;                    // in-flight reply-quiz request
    NSString *_question;                      // current question text
    NSArray *_quizAnswerArray;                // answer choice strings
    int _quizId;                              // current quiz id
    int _rightAnswer;                         // index of the correct answer
    int _totalCorrect;                        // running correct total
    int _totalIncorrect;                      // running incorrect total
    int _consecutive;                         // running correct streak
    int _finaleAnswer;                        // the answer the result screen renders (-1 = none)
    int _selectAnswer;                        // the row the player picked (-1 = none)
    UITableViewCell *_selectCell;             // the picked cell (for stamp placement)
    BOOL _isAnswerable;                       // YES while a row tap is accepted
    int _presentSt;                           // present popup state (0 none, 1 armed, 2 shown)
    int _sdRscId[3];                          // quiz SE source ids (correct / wrong / bonus)
}

// @ 0xda198 — build the blackboard header (question board + result board + ○/✕ boards +
// speech bubbles + question label), the phone backdrop / back button, the dimmed spinner
// overlay, kick off the first quiz fetch, and load the three quiz SEs.
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    _finaleAnswer = -1;
    _selectAnswer = -1;
    if (self) {
        BOOL isPad = neSceneManager::isPadDisplay();
        int displayType = [[AppDelegate appDelegate] displayType];

        // Swap in a TouchableTableView (forwards touches to the controller) and disable scroll.
        TouchableTableView *table =
            [[TouchableTableView alloc] initWithFrame:self.tableView.frame];
        self.tableView = table;
        self.tableView.scrollEnabled = NO;

        CGRect viewFrame = self.view ? self.view.frame : CGRectZero;
        self.tableView.rowHeight = 56.0f;   // 0x42600000
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.separatorColor = [UIColor clearColor];

        // Extra vertical nudge: -10, or 0 when displayType == 2; +10 again on pad.
        int yNudge = (displayType == 2) ? 0 : -10;
        if (isPad) {
            yNudge += 10;
        }

        // Question blackboard ("pq_question").
        UIImage *boardImg = [UIImage imageNamed:@"pq_question"];
        _blackBoardView = [[UIImageView alloc] initWithImage:boardImg];
        if (!isPad) {
            _blackBoardView.frame = CGRectMake((viewFrame.size.width - boardImg.size.width) * 0.5f,
                                               17.0f, boardImg.size.width, boardImg.size.height);
        } else {
            _blackBoardView.frame =
                CGRectMake(16.0f, 17.0f, boardImg.size.width, boardImg.size.height);
        }

        // Result blackboard ("pq_question_result"), hidden until the answer is graded.
        UIImage *resultImg = [UIImage imageNamed:@"pq_question_result"];
        _blackBoardResultView = [[UIImageView alloc] initWithImage:resultImg];
        if (!isPad) {
            _blackBoardResultView.frame =
                CGRectMake((viewFrame.size.width - resultImg.size.width) * 0.5f, 17.0f,
                           resultImg.size.width, resultImg.size.height);
        } else {
            _blackBoardResultView.frame =
                CGRectMake(16.0f, 17.0f, resultImg.size.width, resultImg.size.height);
        }
        _blackBoardResultView.hidden = YES;

        // Header container carrying the boards, ○/✕ marks, bubbles and the question label.
        // (Full-width; height accommodates the child frames — see APPROXIMATION note.)
        UIView *headerView =
            [[UIView alloc] initWithFrame:CGRectMake(0, (CGFloat)yNudge, viewFrame.size.width, 200.0f)];

        // Correct ("pq_question_ok") / wrong ("pq_question_ng") boards, hidden by default.
        UIImage *okImg = [UIImage imageNamed:@"pq_question_ok"];
        _rightView = [[UIImageView alloc] initWithImage:okImg];
        if (!isPad) {
            _rightView.frame = CGRectMake((headerView.frame.size.width - okImg.size.width) * 0.5f,
                                          55.0f, okImg.size.width, okImg.size.height);
        } else {
            _rightView.frame = CGRectMake(26.0f, 55.0f, okImg.size.width, okImg.size.height);
        }
        _rightView.hidden = YES;

        UIImage *ngImg = [UIImage imageNamed:@"pq_question_ng"];
        _wrongView = [[UIImageView alloc] initWithImage:ngImg];
        if (!isPad) {
            _wrongView.frame = CGRectMake((headerView.frame.size.width - ngImg.size.width) * 0.5f,
                                          55.0f, ngImg.size.width, ngImg.size.height);
        } else {
            _wrongView.frame = CGRectMake(26.0f, 55.0f, ngImg.size.width, ngImg.size.height);
        }
        _wrongView.hidden = YES;

        // Speech bubbles (default / correct / wrong), stacked at the same spot.
        UIImage *ssmDefImg = [UIImage imageNamed:@"pq_ssm_default"];
        UIImage *ssmOkImg  = [UIImage imageNamed:@"pq_ssm_ok"];
        UIImage *ssmNgImg  = [UIImage imageNamed:@"pq_ssm_ng"];
        _defSsmView   = [[UIImageView alloc] initWithImage:ssmDefImg];
        _rightSsmView = [[UIImageView alloc] initWithImage:ssmOkImg];
        _wrongSsmView = [[UIImageView alloc] initWithImage:ssmNgImg];
        CGRect ssmFrame =
            CGRectMake(222.0f, 117.0f, ssmDefImg.size.width, ssmDefImg.size.height);
        _defSsmView.frame = ssmFrame;
        _rightSsmView.frame = ssmFrame;
        _wrongSsmView.frame = ssmFrame;
        _rightSsmView.hidden = YES;
        _wrongSsmView.hidden = YES;

        // Question label (chalk text, up to 4 auto-shrinking centred lines).
        _questionLbl = [[UILabel alloc] init];
        _questionLbl.backgroundColor = [UIColor clearColor];
        // Ghidra colorWithRed:green:blue:alpha: (0x3f78f8f9, 0x3f78f8f9, 0x423eeaeb, 1.0);
        // the blue channel decodes out of [0,1] (clamps to 1) — reconstructed as chalk grey.
        _questionLbl.textColor = [UIColor colorWithRed:0.9725f green:0.9725f blue:0.9725f alpha:1.0f];
        _questionLbl.highlightedTextColor = [UIColor whiteColor];
        _questionLbl.font = [UIFont fontWithName:AppFontName() size:17.0f];
        _questionLbl.textAlignment = NSTextAlignmentCenter;
        _questionLbl.adjustsFontSizeToFitWidth = YES;
        _questionLbl.minimumScaleFactor = 10.0f;   // matches the binary literal (0x41200000)
        _questionLbl.numberOfLines = 4;
        _questionLbl.text = @"";
        _questionLbl.frame = CGRectMake(26.0f, 30.0f, 285.0f, 150.0f);

        [headerView addSubview:_blackBoardView];
        [headerView addSubview:_blackBoardResultView];
        [headerView addSubview:_questionLbl];
        [headerView addSubview:_rightView];
        [headerView addSubview:_wrongView];
        [headerView addSubview:_defSsmView];
        [headerView addSubview:_rightSsmView];
        [headerView addSubview:_wrongSsmView];
        self.tableView.tableHeaderView = headerView;

        // Phone backdrop ("friman_bg"); pad: no backdrop, clear background.
        if (!neSceneManager::isPadDisplay()) {
            UIImage *bgImg = [UIImage imageNamed:@"friman_bg"];
            UIImageView *bgImgView = [[UIImageView alloc] initWithImage:bgImg];
            bgImgView.frame = CGRectMake(0, 0, bgImg.size.width, bgImg.size.height);
            self.tableView.backgroundView = bgImgView;
        } else {
            self.tableView.backgroundView = nil;
            self.tableView.backgroundColor = [UIColor clearColor];
        }

        // Dimmed dummy overlay carrying the download spinner.
        _dummyView = [[UIViewController alloc] init];
        _dummyView.view.frame = viewFrame;
        _dummyView.view.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0];
        _dummyView.view.hidden = YES;
        [self.view addSubview:_dummyView.view];

        UIActivityIndicatorView *spinner =
            [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
        spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        if (!isPad) {
            spinner.center = CGPointMake(viewFrame.size.width * 0.5f,
                                         (int)(viewFrame.size.height * 0.5f) - 10);
        } else {
            spinner.center = CGPointMake(160.0f, 265.0f);   // 0x43200000 / 0x43848000
        }
        spinner.transform = CGAffineTransformMakeScale(2.0f, 2.0f);
        [spinner startAnimating];
        [_dummyView.view addSubview:spinner];

        // Phone-only custom back button.
        if (!isPad) {
            UIImage *backImg = [UIImage imageNamed:@"navi_btn_back"];
            UIButton *backBtn = [[UIButton alloc]
                initWithFrame:CGRectMake(0, 0, backImg.size.width, backImg.size.height)];
            [backBtn setBackgroundImage:backImg forState:UIControlStateNormal];
            [backBtn addTarget:self action:@selector(touchedBackButton:)
              forControlEvents:UIControlEventTouchUpInside];
            self.navigationItem.leftBarButtonItem =
                [[UIBarButtonItem alloc] initWithCustomView:backBtn];
        }

        [self startGetQuizHttp];
    }

    // Load the three quiz SEs (correct / wrong / bonus) regardless of the init result.
    AudioManager *audio = [AudioManager sharedManager];
    static NSString *const kSeNames[3] = { @"se24_quiz_o", @"se25_quiz_x", @"se08_bonus_fai" };
    for (int i = 0; i < 3; i++) {
        NSString *path = [[NSBundle mainBundle] pathForResource:kSeNames[i] ofType:@"m4a"];
        _sdRscId[i] = (int)[audio loadSe:path isLoop:NO callName:nil group:1];
    }
    return self;
}

// @ 0xdb2a4 — cancel any in-flight requests and release the loaded SEs (kept under ARC
// because it cancels the Downloaders and releases the SEs).
- (void)dealloc {
    AudioManager *audio = [AudioManager sharedManager];
    if (_dlQuiz != nil) {
        [_dlQuiz cancel];
        _dlQuiz = nil;
    }
    if (_dlAnswer != nil) {
        [_dlAnswer cancel];
        _dlAnswer = nil;
    }
    for (int i = 0; i < 3; i++) {
        [audio releaseSe:nil resourceId:_sdRscId[i]];
    }
}

// @ 0xdb3d4 — reveal the spinner overlay (the fetch was started in -initWithStyle:).
- (void)viewDidLoad {
    [super viewDidLoad];
    _dummyView.view.hidden = NO;
}

// didReceiveMemoryWarning @ 0xdb438 — super-only override, ARC/omit.

#pragma mark - Table

// @ 0xdb464
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0xdb468 — one row per non-empty answer string.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count = 0;
    for (NSString *answer in _quizAnswerArray) {
        if (answer.length != 0) {
            count++;
        }
    }
    return count;
}

// @ 0xdb538 — one QuizCell per answer choice.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"Cell%ld-%ld",
                            (long)indexPath.section, (long)indexPath.row];
    QuizCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[QuizCell alloc] initWithStyle:UITableViewCellStyleDefault
                               reuseIdentifier:identifier];
    }
    [cell setData:_quizAnswerArray[indexPath.row]
         answerId:(int)indexPath.row
          rightId:_rightAnswer
         selectId:_finaleAnswer];
    return cell;
}

// @ 0xdb674
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

// @ 0xdb678 — accept a row tap once, then POST the reply.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!_isAnswerable) {
        return;
    }
    _selectAnswer = (int)indexPath.row;
    _isAnswerable = NO;
    _selectCell = [tableView cellForRowAtIndexPath:indexPath];
    _dummyView.view.hidden = NO;
    [self startReplyQuizHttp];
}

#pragma mark - Downloader delegate

// @ 0xdb730 — dispatch to the matching handler, then hide the spinner.
- (void)downloaderFinished:(Downloader *)downloader {
    if (_dlQuiz == downloader) {
        [self getQuizFinished];
    } else if (_dlAnswer == downloader) {
        [self replyQuizFinished];
    }
    _dummyView.view.hidden = YES;
}

// @ 0xdb7ac — progress: unused.
- (void)downloaderProceed:(Downloader *)downloader {
}

// @ 0xdb7b0 — drop the failed request, hide the spinner, show the failure alert.
- (void)downloaderError:(Downloader *)downloader {
    if (_dlQuiz == downloader) {
        _dlQuiz = nil;
    } else if (_dlAnswer == downloader) {
        _selectAnswer = -1;
        _isAnswerable = YES;
        _dlAnswer = nil;
    }
    _dummyView.view.hidden = YES;

    CommonAlertView *alert = [[CommonAlertView alloc]
        initWithTitle:nil
              message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
             delegate:nil
    cancelButtonTitle:nil
    otherButtonTitles:@"OK"];
    [alert show];
}

#pragma mark - Networking

// @ 0xdc2b8 — GET the daily quiz (once), revealing the spinner overlay.
- (void)startGetQuizHttp {
    if (_dlQuiz != nil) {
        return;
    }
    _dummyView.view.hidden = NO;
    _dlQuiz = [[Downloader alloc] initWithURL:[StoreUtil getQuizURL] delegate:self];
    [_dlQuiz startDownloading];
}

// @ 0xdc36c — POST the player's answer (once), revealing the spinner overlay.
- (void)startReplyQuizHttp {
    if (_dlAnswer != nil) {
        return;
    }
    _dummyView.view.hidden = NO;
    NSString *body = [NSString stringWithFormat:@"uuid=%@&id=%d&is_correct=%d",
                      urlEncodeString([[AppDelegate appDelegate] uuId]),
                      _quizId,
                      (_selectAnswer == _rightAnswer) ? 1 : 0];
    _dlAnswer = [[Downloader alloc]
        initWithURL:[StoreUtil replyQuizURL]
           delegate:self
               Post:[body dataUsingEncoding:NSUTF8StringEncoding]
        ContextType:@"application/json"];
    [_dlAnswer startDownloading];
}

#pragma mark - Response handling

// @ 0xdb968 — the get-quiz response arrived.
- (void)getQuizFinished {
    NSDictionary *json = [_dlQuiz getDataInJSON];
    BOOL showError = YES;

    id errorCode = [json objectForKey:@"ErrorCode"];
    if (errorCode == nil) {
        id quizId = [json objectForKey:@"QuizId"];
        NSString *question = [json objectForKey:@"Question"];
        id rightAns = [json objectForKey:@"RightAns"];
        NSArray *ansList = [json objectForKey:@"AnsList"];
        if (ansList != nil) {
            NSMutableArray *answers = [NSMutableArray array];
            for (NSDictionary *entry in ansList) {
                NSString *text = [entry objectForKey:@"Text"];
                if (text != nil) {
                    [answers addObject:text];
                }
            }
            if (question != nil && rightAns != nil) {
                _quizId = [quizId intValue];
                if ([UserSettingData lastAnswerQuizId] < _quizId) {
                    // A newer, still-unanswered quiz: show it.
                    _question = nil;
                    _quizAnswerArray = nil;
                    _question = [[question stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"]
                                          stringByReplacingOccurrencesOfString:@"<BR>" withString:@"\n"];
                    _rightAnswer = [rightAns intValue];
                    _quizAnswerArray = [[NSArray alloc] initWithArray:answers];
                    _questionLbl.text = _question;
                    _isAnswerable = YES;
                    [self.tableView reloadData];
                } else {
                    // Already answered this one: go straight to the result board.
                    [self drawResult];
                }
                showError = NO;
            }
        }
    } else {
        int code = [errorCode intValue];
        if (code != 99) {
            if (code == 1) {
                [self drawResult];
                showError = NO;
            } else if (code != 0) {
                showError = NO;   // an unhandled non-error code: no action
            }
            // code == 0 falls through to showError = YES
        }
    }

    _dlQuiz = nil;

    if (showError) {
        CommonAlertView *alert = [[CommonAlertView alloc]
            initWithTitle:nil
                  message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
                 delegate:nil
            cancelButtonTitle:nil
            otherButtonTitles:@"OK"];
        [alert show];
    }
}

// @ 0xdbda4 — the reply-quiz response arrived: persist the totals, then grade the pick.
- (void)replyQuizFinished {
    AudioManager *audio = [AudioManager sharedManager];
    NSDictionary *json = [_dlAnswer getDataInJSON];
    BOOL showError = YES;

    if ([json objectForKey:@"ErrorCode"] == nil) {
        id totalCorrect = [json objectForKey:@"TotalCorrect"];
        id totalIncorrect = [json objectForKey:@"TotalIncorrect"];
        id consecutive = [json objectForKey:@"Consecutive"];
        if (totalCorrect != nil && totalIncorrect != nil && consecutive != nil) {
            _totalCorrect = [totalCorrect intValue];
            _totalIncorrect = [totalIncorrect intValue];
            _consecutive = [consecutive intValue];
            [UserSettingData saveTotalCorrectQuiz:_totalCorrect];
            [UserSettingData saveTotalInCorrectQuiz:_totalIncorrect];
            [UserSettingData saveConsecutiveQuiz:_consecutive];
            showError = NO;
        }
    }

    _dlAnswer = nil;

    if (showError) {
        _selectAnswer = -1;
        _isAnswerable = YES;
        CommonAlertView *alert = [[CommonAlertView alloc]
            initWithTitle:nil
                  message:@"通信に失敗しました。\n電波状態の良い場所でやり直して下さい。"
                 delegate:nil
            cancelButtonTitle:nil
            otherButtonTitles:@"OK"];
        [alert show];
    } else {
        [UserSettingData saveLastAnswerQuizId:_quizId];
        _finaleAnswer = _selectAnswer;

        UIImage *stamp;
        if (_selectAnswer == _rightAnswer) {
            stamp = [UIImage imageNamed:@"pq_answer_ok"];
            if (_totalCorrect > 0 && _totalCorrect % 5 == 0) {
                [UserSettingData saveCharaTicket:(short)([UserSettingData charaTicket] + 1)];
                _presentSt = 1;
            }
        } else {
            stamp = [UIImage imageNamed:@"pq_answer_ng"];
        }

        // ○/✕ stamp over the picked row.
        CGFloat stampY = _selectCell ? (_selectCell.frame.origin.y - 10.0f) : -10.0f;
        _hanamaruView = [[UIImageView alloc]
            initWithFrame:CGRectMake(197.0f, stampY, stamp.size.width, stamp.size.height)];
        [_hanamaruView setImage:stamp];
        [self.tableView addSubview:_hanamaruView];

        _defSsmView.hidden = YES;
        if (_selectAnswer == _rightAnswer) {
            _rightView.hidden = NO;
            _rightSsmView.hidden = NO;
        } else {
            _wrongView.hidden = NO;
            _wrongSsmView.hidden = NO;
        }
        [audio playSe:nil resourceId:(_selectAnswer == _rightAnswer ? _sdRscId[0] : _sdRscId[1])];
    }

    [self.tableView reloadData];
}

// @ 0xdc4ec — swap the question board for the result board and lay out the running
// correct total (pq_total%d over pq_totalbase) and the streak (b_invite_num%d over
// pq_ans_base).
- (void)drawResult {
    _totalCorrect = [UserSettingData totalCorrectQuiz];
    _totalIncorrect = [UserSettingData totalInCorrectQuiz];
    _consecutive = [UserSettingData consecutiveCorrectQuiz];

    _blackBoardView.hidden = YES;
    _blackBoardResultView.hidden = NO;
    _hanamaruView.hidden = YES;
    _rightView.hidden = YES;
    _wrongView.hidden = YES;
    _questionLbl.hidden = YES;
    _quizAnswerArray = nil;

    // Total-correct digits over "pq_totalbase".
    UIImage *totalBaseImg = [UIImage imageNamed:@"pq_totalbase"];
    UIImageView *totalBase = [[UIImageView alloc]
        initWithFrame:CGRectMake(33.0f, 222.0f, totalBaseImg.size.width, totalBaseImg.size.height)];
    [totalBase setImage:totalBaseImg];
    [self.tableView addSubview:totalBase];

    int value = _totalCorrect;
    int digits = QuizCountDigits(value);
    if (digits > 0) {
        int x = digits * 10 + 0x6b;
        do {
            UIImage *digitImg = [UIImage imageNamed:[NSString stringWithFormat:@"pq_total%d", value % 10]];
            UIImageView *digitView = [[UIImageView alloc] initWithImage:digitImg];
            digitView.frame = CGRectMake((CGFloat)x, 58.0f, digitImg.size.width, digitImg.size.height);
            [totalBase addSubview:digitView];
            x -= 0x14;
            value /= 10;
        } while (--digits != 0);
    }

    // Streak digits over "pq_ans_base".
    UIImage *ansBaseImg = [UIImage imageNamed:@"pq_ans_base"];
    UIImageView *ansBase = [[UIImageView alloc]
        initWithFrame:CGRectMake(22.0f, 338.0f, ansBaseImg.size.width, ansBaseImg.size.height)];
    [ansBase setImage:ansBaseImg];
    if (neSceneManager::isPadDisplay()) {
        CGRect f = ansBase.frame;
        f.origin.x += 20.0f;
        ansBase.frame = f;
    }
    [self.tableView addSubview:ansBase];

    value = _consecutive;
    digits = QuizCountDigits(value);
    if (digits > 0) {
        int x = digits * 12 + 0xbe;
        do {
            UIImage *digitImg = [UIImage imageNamed:[NSString stringWithFormat:@"b_invite_num%d", value % 10]];
            UIImageView *digitView = [[UIImageView alloc] initWithImage:digitImg];
            digitView.frame = CGRectMake((CGFloat)x, 33.0f, 24.0f, 24.0f);
            [ansBase addSubview:digitView];
            x -= 0x18;
            value /= 10;
        } while (--digits != 0);
    }

    [self.tableView reloadData];
}

// @ 0xdca68 — a tap on the graded board: draw the result (first time), then toggle the
// present-reward popup in (state 1) / out (state 2).
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_finaleAnswer < 0) {
        return;
    }

    if (_blackBoardResultView.isHidden) {
        neEngine::playSystemSe(1);
        [self drawResult];
        [self.tableView reloadData];
    }

    if (_presentSt == 2) {
        // Fade the present window out.
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3f];   // DAT_000dce48 == (double)0.3f
        _presentBaseView.alpha = 0.0f;
        [UIView commitAnimations];
        _presentSt = 0;
    } else if (_presentSt == 1) {
        AudioManager *audio = [AudioManager sharedManager];
        [audio playSe:nil resourceId:_sdRscId[2]];   // bonus SE

        _presentBaseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320.0f, 568.0f)];
        _presentBaseView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5f];

        UIImage *winImg = [UIImage imageNamed:@"pq_window_present"];
        UIImageView *winView = [[UIImageView alloc] initWithImage:winImg];
        winView.frame = CGRectMake((320.0f - winImg.size.width) * 0.5f, 100.0f,
                                   winImg.size.width, winImg.size.height);

        // Total-correct digits (2x assets, drawn at half size) across the window.
        int value = _totalCorrect;
        int digits = QuizCountDigits(value);
        if (digits > 0) {
            int x = digits * 9 + 0x96;
            do {
                UIImage *digitImg =
                    [UIImage imageNamed:[NSString stringWithFormat:@"pq_present_num%d_2x", value % 10]];
                UIImageView *digitView = [[UIImageView alloc] initWithImage:digitImg];
                digitView.frame = CGRectMake((CGFloat)x, 95.0f,
                                             digitImg.size.width * 0.5f, digitImg.size.height * 0.5f);
                [winView addSubview:digitView];
                x -= 0x12;
                value /= 10;
            } while (--digits != 0);
        }

        [_presentBaseView addSubview:winView];
        [self.view addSubview:_presentBaseView];
        _presentBaseView.alpha = 0.0f;

        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.5];
        _presentBaseView.alpha = 1.0f;
        [UIView commitAnimations];
        _presentSt = 2;
    }
}

#pragma mark - Actions

// @ 0xdb8cc — back button: restore the menu navbar art and pop.
- (void)touchedBackButton:(id)sender {
    neEngine::playSystemSe(2);   // cancel/back SE
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"pl_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
