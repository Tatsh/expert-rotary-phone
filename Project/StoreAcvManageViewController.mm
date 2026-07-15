//
//  StoreAcvManageViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreAcvManageViewController.h"
#import "StoreViewController.h"

#import "AppFont.h"           // AppFontName() == @"DFSoGei-W5-WIN-RKSJ-H" (getFontNameDFSoGei)
#import "MusicManager.h"      // [MusicManager getInstance] purchased-AC-music accessors
#import "RhUtil.h"            // RhFileExists()
#import "StoreAcMusicInfo.h"  // initWithDictionary: (parse the fetched AC-song info)
#import "StoreDownloadTask.h" // one file download descriptor
#import "StoreUtil.h"         // acvMusicInfoURL:

#import "neEngineBridge.h" // neSceneManager::shared / isPadDisplay

@implementation StoreAcvManageViewController

// @ 0x8c630 — identical to StoreManageViewController but for the arcade viewer.
- (instancetype)initWithParent:(StoreViewController *)parent {
    if ((self = [super init])) {
        m_StoreViewCtrl = parent;
        m_WorkingIndex = -1;

        // Tab item: "アーケードビューアー" ("Arcade Viewer") — Ghidra CFString @
        // 0x138a88.
        self.tabBarItem.title = @"アーケードビューアー";
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
        self.tabBarItem.image = [[UIImage imageNamed:@"store_icon_manage2"]
            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        self.tabBarItem.selectedImage = [[UIImage imageNamed:@"store_icon_manage2"]
            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
#else
        [self.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"store_icon_manage2"]
                      withFinishedUnselectedImage:[UIImage imageNamed:@"store_icon_manage2"]];
#endif

        m_ImgDelete = [UIImage imageNamed:@"manage_delete"];
        m_ImgDownload = [UIImage imageNamed:@"manage_download"];

        neSceneManager::shared();
        m_IsPad = neSceneManager::isPadDisplay();
        if (m_IsPad) {
            self.view.backgroundColor =
                [UIColor colorWithPatternImage:[UIImage imageNamed:@"friman_bg"]];
        }
    }
    return self;
}

// @ 0x8c7f0 — build the view tree: an iPad-only engraved header label, the
// manage table view (styled per device), then scan the purchased-music list for
// songs not yet present in the purchased-arcade list and, if any, kick off the
// integrity check. (setAutoresizingSize is a UIView category helper in the app;
// inlined here as the equivalent flexible mask.)
- (void)loadView {
    [super loadView];

    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    CGRect frame = self.view ? self.view.bounds : CGRectZero;

    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        UILabel *title = [[UILabel alloc] init];
        title.backgroundColor = [UIColor clearColor];
        title.textColor = [UIColor colorWithRed:0.188f
                                          green:0.188f
                                           blue:0.188f
                                          alpha:1.0f]; // 0x3e40c0c1
        title.highlightedTextColor = [UIColor whiteColor];
        title.font = [UIFont fontWithName:AppFontName() size:18.0f]; // 0x41900000
        title.textAlignment = NSTextAlignmentCenter;                 // 1
        title.shadowColor = [UIColor lightGrayColor];
        title.shadowOffset = CGSizeMake(1.0f, 1.0f);
        title.frame = CGRectMake(-8.0f, 0.0f, 280.0f, 50.0f); // -8/0/0x438c0000/0x42480000
        title.text = @"アーケードビューアー楽曲";
        [self.view addSubview:title];
        // Inset the table below the header (Ghidra: bounds + {20, 50, -40, -115}).
        frame = CGRectMake(frame.origin.x + 20.0f,
                           frame.origin.y + 50.0f,
                           frame.size.width - 40.0f,
                           frame.size.height - 115.0f);
    }

    m_TableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStylePlain];
    m_TableView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    m_TableView.rowHeight = m_IsPad ? 60.0f : 50.0f; // 0x8cf24 / 0x8cf20
    m_TableView.delegate = self;
    m_TableView.dataSource = self;
    m_TableView.allowsSelection = NO;
    m_TableView.clipsToBounds = YES;
    m_TableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        m_TableView.backgroundColor = [UIColor colorWithWhite:0.1843f alpha:1.0f]; // 0x3e3cbcbd
    } else {
        m_TableView.layer.cornerRadius = 8.0f; // 0x41000000
        m_TableView.layer.borderColor =
            [UIColor colorWithWhite:0.5608f alpha:1.0f].CGColor;                // 0x3f0f8f90
        m_TableView.layer.borderWidth = 1.5f;                                   // 0x3fc00000
        m_TableView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.8f]; // 0x3f4ccccd
        m_TableView.backgroundView = nil;
    }
    [self.view addSubview:m_TableView];

    m_CheckMusicIds = [NSMutableArray array];

    // Collect the ids of owned (non-arcade) songs that are NOT present in the
    // purchased arcade list — those need their arcade-viewer info fetched (see
    // -startCheck).
    NSMutableArray *purchased = [[MusicManager getInstance] getPurchasedMusicDictionaris];
    NSMutableArray *acPurchased = [[MusicManager getInstance] getPurchasedAcMusicDictionaris];
    for (NSDictionary *item in purchased) {
        unsigned int musicId = [[item objectForKey:@"ID"] unsignedIntValue];
        BOOL found = NO;
        for (NSDictionary *acItem in acPurchased) {
            if ([[acItem objectForKey:@"ID"] unsignedIntValue] == musicId) {
                found = YES;
                break;
            }
        }
        if (!found) {
            [m_CheckMusicIds addObject:[NSNumber numberWithUnsignedInt:musicId]];
        }
    }

    if (m_CheckMusicIds.count != 0) {
        [self startCheck];
    }
}

// @ 0x8cf28 — dequeue/build a manage row: a bottom-detail cell with an engraved
// title/genre (drawn by a pair of shadow labels over the blanked built-in
// labels) and a right-aligned delete / download action button. The button image
// (and, on iPad, its title) reflects whether the arcade file is already on
// disk.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [m_TableView dequeueReusableCellWithIdentifier:@"StoreAcvManageCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"StoreAcvManageCell"]; // style 3

        // Built-in title label: narrower than the cell (leaves room for the
        // button).
        cell.textLabel.frame = CGRectMake(cell.textLabel.frame.origin.x,
                                          cell.textLabel.frame.origin.y,
                                          cell.frame.size.width - 200.0f,
                                          cell.textLabel.frame.size.height);
        cell.textLabel.font = [UIFont fontWithName:AppFontName() size:(m_IsPad ? 20.0f : 17.0f)];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth; // 2
        cell.detailTextLabel.font = [UIFont fontWithName:AppFontName()
                                                    size:(m_IsPad ? 16.0f : 14.0f)];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.196f alpha:1.0f]; // 0x3e48c8c9

        // Action button (tag 0xe01f): right-aligned, vertically centred, own touch.
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect]; // 1
        button.titleLabel.font = [UIFont fontWithName:AppFontName() size:(m_IsPad ? 16.0f : 14.0f)];
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        button.tag = 0xe01f;
        button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                  UIViewAutoresizingFlexibleTopMargin |
                                  UIViewAutoresizingFlexibleBottomMargin; // 0x29
        [button addTarget:self
                      action:@selector(pushCellButton:)
            forControlEvents:UIControlEventTouchUpInside]; // 0x40
        [cell addSubview:button];
        button.exclusiveTouch = YES;

        // Title shadow label (tag 0xe020) — engraved gray text with a white
        // highlight.
        UILabel *titleShadow = [[UILabel alloc] init];
        titleShadow.backgroundColor = [UIColor clearColor];
        titleShadow.textColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
        titleShadow.highlightedTextColor = [UIColor whiteColor];
        titleShadow.tag = 0xe020;
        neSceneManager::shared();
        if (!neSceneManager::isPadDisplay()) {
            titleShadow.font = [UIFont fontWithName:AppFontName() size:15.0f];
            titleShadow.frame = CGRectMake(10.0f, 9.0f, 240.0f, 15.0f);
        } else {
            titleShadow.font = [UIFont fontWithName:AppFontName() size:17.0f];
            titleShadow.frame = CGRectMake(15.0f, 12.0f, 550.0f, 17.0f);
        }
        [cell addSubview:titleShadow];

        // Genre shadow label (tag 0xe021).
        UILabel *genreShadow = [[UILabel alloc] init];
        genreShadow.backgroundColor = [UIColor clearColor];
        genreShadow.textColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
        genreShadow.highlightedTextColor = [UIColor whiteColor];
        genreShadow.tag = 0xe021;
        neSceneManager::shared();
        if (!neSceneManager::isPadDisplay()) {
            genreShadow.font = [UIFont fontWithName:AppFontName() size:12.0f];
            genreShadow.frame = CGRectMake(10.0f, 31.0f, 240.0f, 12.0f);
        } else {
            genreShadow.font = [UIFont fontWithName:AppFontName() size:14.0f];
            genreShadow.frame = CGRectMake(15.0f, 35.0f, 550.0f, 14.0f);
        }
        [cell addSubview:genreShadow];
    }

    NSDictionary *item =
        [[[MusicManager getInstance] getPurchasedAcMusicDictionaris] objectAtIndex:indexPath.row];
    unsigned int acMusicId = [[item objectForKey:@"ID"] unsignedIntValue];
    NSString *path = [[MusicManager getInstance] getAcPathFromPurchased:acMusicId];
    BOOL exists = RhFileExists(path);

    UIButton *button = (UIButton *)[cell viewWithTag:0xe01f];
    if (exists) {
        [button setImage:m_ImgDelete forState:UIControlStateNormal];
        if (m_IsPad) {
            [button setTitle:@"削除" forState:UIControlStateNormal];
        }
    } else {
        [button setImage:m_ImgDownload forState:UIControlStateNormal];
        if (m_IsPad) {
            [button setTitle:@"ダウンロード" forState:UIControlStateNormal];
        }
    }
    [button sizeToFit];
    // Right-align and vertically centre the button (Ghidra: cell.width -
    // buttonWidth - 10, (cell.height - buttonHeight) * 0.5). buttonHeight = 40
    // iPad / 36 phone.
    CGFloat buttonWidth = button.frame.size.width;
    CGFloat buttonHeight = m_IsPad ? 40.0f : 36.0f; // 0x42200000 / 0x42100000
    button.frame = CGRectMake(cell.frame.size.width - buttonWidth - 10.0f, // 0xc1200000
                              (cell.frame.size.height - buttonHeight) * 0.5f,
                              buttonWidth,
                              buttonHeight);

    // Populate the built-in labels, mirror their text into the shadow labels,
    // then blank the built-ins so only the engraved shadow labels are visible.
    cell.textLabel.text = [item objectForKey:@"Title"];
    cell.detailTextLabel.text = [item objectForKey:@"Genre"];
    [(UILabel *)[cell viewWithTag:0xe020] setText:cell.textLabel.text];
    cell.textLabel.text = @"";
    [(UILabel *)[cell viewWithTag:0xe021] setText:cell.detailTextLabel.text];
    cell.detailTextLabel.text = @"";

    return cell;
}

// @ 0x8d8b4 — one section listing every purchased arcade-viewer song.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[MusicManager getInstance] getPurchasedAcMusicDictionaris] count];
}

// @ 0x8d8f8 — per-device row background: phone alternates two grays, iPad uses
// a stretchable pack-background image over a clear cell.
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        CGFloat white = (indexPath.row & 1) ? 0.8f // 0x3f4ccccd
                                              :
                                              0.7568f; // 0x3f41c1c2
        cell.backgroundColor = [UIColor colorWithWhite:white alpha:1.0f];
    } else {
        cell.backgroundColor = [UIColor clearColor];
        NSString *bg = (indexPath.row & 1) ? @"store_pack_bg_0" : @"store_pack_bg_1";
        cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:bg]];
    }
}

// @ 0x8da44 — single section.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x8da48 — the per-row action button was tapped: walk up to the owning cell,
// resolve the row's arcade song, and either (file missing) re-download it via
// the store modal dialog, or (file present) confirm deletion. Ignored while
// another action or a check pass is running.
- (void)pushCellButton:(id)sender {
    if (m_WorkingIndex != -1 || m_CheckMusicIds.count != 0) {
        return;
    }

    id view = sender;
    while (![view isKindOfClass:[UITableViewCell class]]) {
        view = [view superview];
    }
    NSIndexPath *indexPath = [m_TableView indexPathForCell:(UITableViewCell *)view];
    if (indexPath == nil) {
        return;
    }
    m_WorkingIndex = static_cast<int>(indexPath.row);

    NSDictionary *item =
        [[[MusicManager getInstance] getPurchasedAcMusicDictionaris] objectAtIndex:m_WorkingIndex];
    unsigned int acMusicId = [[item objectForKey:@"ID"] unsignedIntValue];
    NSString *path = [[MusicManager getInstance] getAcPathFromPurchased:acMusicId];

    if (!RhFileExists(path)) {
        // File missing: re-download it, showing the store's shared modal progress
        // dialog.
        id dialog = m_StoreViewCtrl.modalDialog;
        [dialog performSelector:@selector(layout:) withObject:nil];
        UILabel *message = [dialog performSelector:@selector(labelMessage)];
        message.text = [NSString stringWithFormat:@"%@", [item objectForKey:@"Title"]];
        [(UIProgressView *)[dialog performSelector:@selector(progressView)] setProgress:0.0f];
        if (![m_StoreViewCtrl showModalDialog:self]) {
            m_WorkingIndex = -1;
            return;
        }
        NSURL *url = [StoreUtil acvMusicInfoURL:acMusicId];
        m_InfoDownloader = [[Downloader alloc] initWithURL:url delegate:self];
        [m_InfoDownloader startDownloading];
    } else {
        // File present: confirm deletion.
        if (m_DeleteAlertView != nil) {
            [m_DeleteAlertView setDelegate:nil];
            m_DeleteAlertView = nil;
        }
        m_DeleteAlertView = [[CommonAlertView alloc]
                initWithTitle:@"削除"
                      message:[NSString stringWithFormat:@"%@", [item objectForKey:@"Title"]]
                     delegate:self
            cancelButtonTitle:@"いいえ"
            otherButtonTitles:@"はい"];
        [m_DeleteAlertView show];
    }
}

// @ 0x8de20 — start the arcade file download for the working row via
// StoreDownloadManager.
- (void)startDownloadMusic {
    NSDictionary *item =
        [[[MusicManager getInstance] getPurchasedAcMusicDictionaris] objectAtIndex:m_WorkingIndex];
    unsigned int acMusicId = [[item objectForKey:@"ID"] unsignedIntValue];
    NSString *path = [[MusicManager getInstance] getAcPathFromPurchased:acMusicId];

    StoreDownloadTask *task = [[StoreDownloadTask alloc] initWithURL:[item objectForKey:@"ItemURL"]
                                                                path:path
                                                           AddObject:nil];
    m_DlManager = [[StoreDownloadManager alloc] initWithTasks:[NSArray arrayWithObject:task]
                                                     delegate:self];
    [m_DlManager start];
}

// @ 0x8df94 — fetch the arcade-viewer info for the first pending id (see
// -loadView).
- (void)startCheck {
    unsigned int acMusicId = [[m_CheckMusicIds objectAtIndex:0] unsignedIntValue];
    NSURL *url = [StoreUtil acvMusicInfoURL:acMusicId];
    m_InfoDownloader = [[Downloader alloc] initWithURL:url delegate:self];
    [m_InfoDownloader startDownloading];
}

// @ 0x8e03c — a Downloader finished. If it is the info downloader, register the
// fetched arcade song, then advance: process the next pending id, or (when the
// check list is drained) download the working row's file / reload the table.
- (void)downloaderFinished:(Downloader *)downloader {
    if (m_InfoDownloader != downloader) {
        return;
    }

    StoreAcMusicInfo *info =
        [[StoreAcMusicInfo alloc] initWithDictionary:[downloader getDataInJSON]];
    if (info != nil) {
        if ([[MusicManager getInstance] addPurchasedAcMusic:info]) {
            [[MusicManager getInstance] savePurchasedMusics];
        }
    }

    m_InfoDownloader = nil;

    if (m_CheckMusicIds.count == 0) {
        [self startDownloadMusic];
    } else {
        [m_CheckMusicIds removeObjectAtIndex:0];
        if (m_CheckMusicIds.count == 0) {
            [m_TableView reloadData];
        } else {
            [self startCheck];
        }
    }
}

// @ 0x8e1a4 — the info download failed. Abandon the whole check batch (reload)
// if one was running; otherwise fall through to the file download for the
// working row.
- (void)downloaderError:(Downloader *)downloader {
    if (m_InfoDownloader != downloader) {
        return;
    }

    m_InfoDownloader = nil;

    if (m_CheckMusicIds.count != 0) {
        [m_CheckMusicIds removeAllObjects];
        [m_TableView reloadData];
        return;
    }

    [self startDownloadMusic];
    m_WorkingIndex = -1;
}

// @ 0x8e250 — the store modal dialog's abort button: cancel any in-flight
// info/file download, hide the dialog, and clear the working row.
- (void)storeDialogCancel:(id)sender {
    if (m_InfoDownloader != nil) {
        [m_InfoDownloader cancel];
        m_InfoDownloader = nil;
    }
    if (m_DlManager != nil) {
        [m_DlManager cancel];
        m_DlManager = nil;
    }
    [m_StoreViewCtrl hideModalDialog];
    m_WorkingIndex = -1;
}

// @ 0x8e2f8 — delete-confirm alert result: on "はい" (index 1) delete the
// working row's arcade file and reload; either way clear the working row.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (m_DeleteAlertView == alertView && index == 1) {
        NSDictionary *item = [[[MusicManager getInstance] getPurchasedAcMusicDictionaris]
            objectAtIndex:m_WorkingIndex];
        unsigned int acMusicId = [[item objectForKey:@"ID"] unsignedIntValue];
        [[MusicManager getInstance] deleteAcMusic:acMusicId];
        [m_TableView reloadData];
    }
    m_WorkingIndex = -1;
}

// @ 0x8e3e4 — file download finished: reload, hide the dialog, clear the
// working row.
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    m_DlManager = nil;
    [m_TableView reloadData];
    [m_StoreViewCtrl hideModalDialog];
    m_WorkingIndex = -1;
}

// @ 0x8e45c — file download failed: report it, hide the dialog, clear the
// working row.
- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    m_DlManager = nil;

    NSString *message = @"ダウンロードに失敗しました。";
    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"Error"
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
    [alert show];

    [m_StoreViewCtrl hideModalDialog];
    m_WorkingIndex = -1;
}

// @ 0x8e574 — file download progressed: push the overall progress into the
// dialog's bar.
- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    id dialog = m_StoreViewCtrl.modalDialog;
    [(UIProgressView *)[dialog performSelector:@selector(progressView)]
        setProgress:m_DlManager.overallProgress];
}

// @ 0x8e5e0 — all orientations supported.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

// didReceiveMemoryWarning @ 0x8e5e4 — super-only override, omitted.

// @ 0x8e610 — the view was torn down: release the table (the ARC-managed ivar
// is niled after super).
- (void)viewDidUnload {
    [super viewDidUnload];
    if (m_TableView != nil) {
        m_TableView = nil;
    }
}

// viewWillAppear: @ 0x8e664 — super-only override, omitted.

// @ 0x8e690 — refresh the list and flash the scroll indicators on appearance.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [m_TableView reloadData];
    [m_TableView flashScrollIndicators];
}

// viewWillDisappear: @ 0x8e6f0 — super-only override, omitted.

// viewDidDisappear: @ 0x8e71c — super-only override, omitted.

// @ 0x8e748 — tear-down: drop the alert delegate, detach the table's data
// source/delegate, cancel the active file download and the in-flight info
// download. KEPT under ARC because it cancels downloads and detaches delegates
// (not object-only). Object releases and [super dealloc] are ARC-omitted.
- (void)dealloc {
    [m_DeleteAlertView setDelegate:nil];
    m_TableView.dataSource = nil;
    m_TableView.delegate = nil;
    [m_DlManager cancel];
    [self.view removeFromSuperview];
    if (m_InfoDownloader != nil) {
        [m_InfoDownloader cancel];
        m_InfoDownloader = nil;
    }
}

@end
