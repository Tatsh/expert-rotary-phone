//
//  StoreManageViewController.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreManageViewController.h"
#import "StoreViewController.h"

#import "AppFont.h"                 // AppFontName() == getFontNameDFSoGei() -> @"DFSoGei-W5-WIN-RKSJ-H"
#import "MusicManager.h"            // purchased-music library singleton
#import "RhUtil.h"                  // RhFileExists()
#import "StoreDownloadTask.h"       // one queued download (URL + local path)
#import "StoreMusicInfo.h"          // parsed music metadata (initWithDictionary:)
#import "StoreUtil.h"               // web-API URL builder
#import "neEngineBridge.h"          // neSceneManager::isPadDisplay

// musicInfoURL: is not yet declared in StoreUtil.h. TODO(dep): promote this to
// StoreUtil.h once that class's reconstruction reaches it (Ghidra: StoreUtil::musicInfoURL_,
// selector s_musicInfoURL_ @ 0x15ac04).
@interface StoreUtil (StoreManageViewController)
+ (NSURL *)musicInfoURL:(unsigned int)musicId;
@end

@implementation StoreManageViewController

// @ 0x4bc40 — tab item + action icons; iPad gets a patterned background.
- (instancetype)initWithParent:(StoreViewController *)parent {
    if ((self = [super init])) {
        m_StoreViewCtrl = parent;
        m_WorkingIndex = -1;

        // Tab item: "リズミン" ("Rhythmin") — Ghidra CFString @ 0x136968.
        self.tabBarItem.title = @"リズミン";
        [self.tabBarItem
            setFinishedSelectedImage:[UIImage imageNamed:@"store_icon_manage"]
             withFinishedUnselectedImage:[UIImage imageNamed:@"store_icon_manage"]];

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

// @ 0x4be00 — build the manage table (iPad gets a rounded, translucent card and a
// "リズミン楽曲" header label; iPhone gets a flat dark table).
- (void)loadView {
    [super loadView];
    self.view.autoresizesSubviews = YES;
    [self.view setAutoresizingSize];  // UIView category: flexible width + height

    CGRect frame = self.view.bounds;

    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        UILabel *header = [[UILabel alloc] init];
        header.backgroundColor = [UIColor clearColor];
        header.textColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
        header.highlightedTextColor = [UIColor whiteColor];
        header.font = [UIFont fontWithName:AppFontName() size:18.0f];
        header.textAlignment = NSTextAlignmentCenter;
        header.shadowColor = [UIColor lightGrayColor];
        header.shadowOffset = CGSizeMake(1.0f, 1.0f);
        header.frame = CGRectMake(-60.0f, 0.0f, 280.0f, 50.0f);
        header.text = @"リズミン楽曲";  // "Rhythmin songs"
        [self.view addSubview:header];

        // Inset the table below/around the header.
        frame.origin.x += 20.0f;
        frame.origin.y += 50.0f;
        frame.size.width += -40.0f;
        frame.size.height += -115.0f;
    }

    m_TableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStylePlain];
    [m_TableView setAutoresizingSize];
    m_TableView.rowHeight = m_IsPad ? 70.0f : 50.0f;
    m_TableView.delegate = self;
    m_TableView.dataSource = self;
    m_TableView.allowsSelection = NO;
    m_TableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    neSceneManager::shared();
    if (neSceneManager::isPadDisplay()) {
        m_TableView.layer.cornerRadius = 8.0f;
        m_TableView.layer.borderColor = [UIColor colorWithWhite:0.561f alpha:1.0f].CGColor;
        m_TableView.layer.borderWidth = 1.5f;
        m_TableView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.8f];
        m_TableView.backgroundView = nil;
    } else {
        m_TableView.backgroundColor = [UIColor colorWithWhite:0.184f alpha:1.0f];
    }
    [self.view addSubview:m_TableView];
}

// @ 0x4c308 — one manage row: the built-in text/detail labels are positioned then
// blanked, and drop-shadow duplicates (tags 0xE020/0xE021) carry the visible song
// name + artist; the action button (tag 0xE01F) shows delete or download.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [m_TableView dequeueReusableCellWithIdentifier:@"StoreManageCell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"StoreManageCell"];

        // Built-in text label: black DFSoGei, flexible width, trimmed to leave room for the button.
        CGRect tf = cell.textLabel.frame;
        cell.textLabel.frame = CGRectMake(tf.origin.x, tf.origin.y,
                                          cell.frame.size.width - 200.0f, tf.size.height);
        cell.textLabel.font = [UIFont fontWithName:AppFontName() size:(m_IsPad ? 20.0f : 17.0f)];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        cell.detailTextLabel.font = [UIFont fontWithName:AppFontName() size:(m_IsPad ? 16.0f : 14.0f)];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.196f alpha:1.0f];

        // Action button (tag 0xE01F) -> pushCellButton:.
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        button.titleLabel.font = [UIFont fontWithName:AppFontName() size:(m_IsPad ? 16.0f : 14.0f)];
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        button.tag = 0xE01F;
        button.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                                   UIViewAutoresizingFlexibleTopMargin |
                                   UIViewAutoresizingFlexibleBottomMargin);  // 0x29
        [button addTarget:self action:@selector(pushCellButton:)
         forControlEvents:UIControlEventTouchUpInside];
        [cell addSubview:button];
        button.exclusiveTouch = YES;

        // Drop-shadow duplicate of the song name (tag 0xE020).
        UILabel *nameLabel = [[UILabel alloc] init];
        nameLabel.backgroundColor = [UIColor clearColor];
        nameLabel.textColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
        nameLabel.highlightedTextColor = [UIColor whiteColor];
        nameLabel.tag = 0xE020;
        neSceneManager::shared();
        if (neSceneManager::isPadDisplay()) {
            nameLabel.font = [UIFont fontWithName:AppFontName() size:17.0f];
            nameLabel.frame = CGRectMake(15.0f, 12.0f, 550.0f, 17.0f);
        } else {
            nameLabel.font = [UIFont fontWithName:AppFontName() size:15.0f];
            nameLabel.frame = CGRectMake(10.0f, 9.0f, 240.0f, 15.0f);
        }
        [cell addSubview:nameLabel];

        // Drop-shadow duplicate of the artist (tag 0xE021).
        UILabel *artistLabel = [[UILabel alloc] init];
        artistLabel.backgroundColor = [UIColor clearColor];
        artistLabel.textColor = [UIColor colorWithRed:0.188f green:0.188f blue:0.188f alpha:1.0f];
        artistLabel.highlightedTextColor = [UIColor whiteColor];
        artistLabel.tag = 0xE021;
        neSceneManager::shared();
        if (neSceneManager::isPadDisplay()) {
            artistLabel.font = [UIFont fontWithName:AppFontName() size:14.0f];
            artistLabel.frame = CGRectMake(15.0f, 35.0f, 550.0f, 14.0f);
        } else {
            artistLabel.font = [UIFont fontWithName:AppFontName() size:12.0f];
            artistLabel.frame = CGRectMake(10.0f, 31.0f, 240.0f, 12.0f);
        }
        [cell addSubview:artistLabel];
    }

    NSDictionary *item = [[[MusicManager getInstance] getPurchasedMusicDictionaris]
                             objectAtIndex:indexPath.row];
    unsigned int musicId = [[item objectForKey:@"ID"] unsignedIntValue];
    BOOL downloaded = RhFileExists([MusicManager getPathFromPurchased:musicId]);

    UIButton *button = (UIButton *)[cell viewWithTag:0xE01F];
    if (downloaded) {
        [button setImage:m_ImgDelete forState:UIControlStateNormal];
        if (m_IsPad) {
            [button setTitle:@"削除" forState:UIControlStateNormal];  // "Delete"
        }
    } else {
        [button setImage:m_ImgDownload forState:UIControlStateNormal];
        if (m_IsPad) {
            [button setTitle:@"ダウンロード" forState:UIControlStateNormal];  // "Download"
        }
    }
    [button sizeToFit];

    // Right-align the button in the cell, vertically centred (36pt tall, 40pt on iPad).
    CGFloat buttonWidth = button.frame.size.width;
    CGFloat buttonHeight = m_IsPad ? 40.0f : 36.0f;
    button.frame = CGRectMake(cell.frame.size.width - buttonWidth - 10.0f,
                              (cell.frame.size.height - buttonHeight) * 0.5f,
                              buttonWidth, buttonHeight);

    // Fill the built-in labels, copy their text into the shadow labels, then blank them.
    cell.textLabel.text = [item objectForKey:@"Name"];
    cell.detailTextLabel.text = [item objectForKey:@"Artist"];
    [(UILabel *)[cell viewWithTag:0xE020] setText:cell.textLabel.text];
    cell.textLabel.text = @"";
    [(UILabel *)[cell viewWithTag:0xE021] setText:cell.detailTextLabel.text];
    cell.detailTextLabel.text = @"";

    return cell;
}

// @ 0x4cc94 — one row per purchased song.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[MusicManager getInstance] getPurchasedMusicDictionaris] count];
}

// @ 0x4ccd8 — zebra striping on iPhone; a per-row pack background image on iPad.
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
                                        forRowAtIndexPath:(NSIndexPath *)indexPath {
    neSceneManager::shared();
    if (!neSceneManager::isPadDisplay()) {
        CGFloat white = (indexPath.row & 1) ? 0.8f : 0.757f;
        cell.backgroundColor = [UIColor colorWithWhite:white alpha:1.0f];
    } else {
        cell.backgroundColor = [UIColor clearColor];
        NSString *imageName = (indexPath.row & 1) ? @"store_pack_bg_0" : @"store_pack_bg_1";
        UIImageView *bg = [[UIImageView alloc]
            initWithImage:[UIImage imageNamed:imageName]];
        cell.backgroundView = bg;
    }
}

// @ 0x4ce24 — single section.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// @ 0x4ce28 — per-row action: download a missing song or confirm deleting a present one.
- (void)pushCellButton:(id)sender {
    if (m_WorkingIndex != -1) {
        return;  // already busy with another row
    }

    // The button lives inside the cell's view tree; walk up to its UITableViewCell.
    UIView *view = (UIView *)sender;
    while (![view isKindOfClass:[UITableViewCell class]]) {
        view = view.superview;
    }
    NSIndexPath *indexPath = [m_TableView indexPathForCell:(UITableViewCell *)view];
    if (indexPath == nil) {
        return;
    }
    m_WorkingIndex = indexPath.row;

    NSDictionary *item = [[[MusicManager getInstance] getPurchasedMusicDictionaris]
                             objectAtIndex:m_WorkingIndex];
    unsigned int musicId = [[item objectForKey:@"ID"] unsignedIntValue];

    // Ghidra checks getPathFromPurchased:/RhFileExists twice; both use the same id, so it
    // reduces to a single "is the audio file present?" test.
    if (!RhFileExists([MusicManager getPathFromPurchased:musicId])) {
        // Missing -> refresh its info then re-download. Show the shared progress dialog.
        id dialog = [m_StoreViewCtrl modalDialog];
        [dialog layout:0];
        [[dialog labelMessage] setText:
            [NSString stringWithFormat:@"「%@」をダウンロード中...", [item objectForKey:@"Name"]]];
        [[dialog progressView] setProgress:0];
        if (![m_StoreViewCtrl showModalDialog:self]) {
            m_WorkingIndex = -1;
            return;
        }
        NSURL *url = [StoreUtil musicInfoURL:musicId];
        m_InfoDownloader = [[Downloader alloc] initWithURL:url delegate:self];
        [m_InfoDownloader startDownloading];
    } else {
        // Present -> confirm deletion.
        if (m_DeleteAlertView != nil) {
            m_DeleteAlertView.delegate = nil;
        }
        m_DeleteAlertView = [[CommonAlertView alloc]
            initWithTitle:@"削除"  // "Delete"
                  message:[NSString stringWithFormat:@"「%@」を削除しますか？", [item objectForKey:@"Name"]]
                 delegate:self
        cancelButtonTitle:@"いいえ"    // "No"
        otherButtonTitles:@"はい"];    // "Yes"
        [m_DeleteAlertView show];
    }
}

// @ 0x4d1ec — queue the audio-file download for the working row and start it.
- (void)startDownloadMusic {
    NSDictionary *item = [[[MusicManager getInstance] getPurchasedMusicDictionaris]
                             objectAtIndex:m_WorkingIndex];
    unsigned int musicId = [[item objectForKey:@"ID"] unsignedIntValue];
    NSString *path = [MusicManager getPathFromPurchased:musicId];

    StoreDownloadTask *task = [[StoreDownloadTask alloc]
        initWithURL:[item objectForKey:@"ItemURL"] path:path AddObject:nil];
    m_DlManager = [[StoreDownloadManager alloc]
        initWithTasks:[NSArray arrayWithObject:task] delegate:self];
    [m_DlManager start];
}

// @ 0x4d360 — the StoreMusicInfo JSON came back: merge/save it, then fetch the audio.
- (void)downloaderFinished:(Downloader *)downloader {
    if (m_InfoDownloader != downloader) {
        return;
    }
    StoreMusicInfo *info = [[StoreMusicInfo alloc]
        initWithDictionary:[downloader getDataInJSON]];
    if (info != nil) {
        if ([[MusicManager getInstance] addPurchasedMusic:info]) {
            [[MusicManager getInstance] savePurchasedMusics];
        }
    }
    m_InfoDownloader = nil;
    [self startDownloadMusic];
}

// @ 0x4d460 — the info fetch failed. (Ghidra still calls startDownloadMusic here — a
// best-effort attempt at the audio file — before clearing the working index.)
- (void)downloaderError:(Downloader *)downloader {
    if (m_InfoDownloader != downloader) {
        return;
    }
    m_InfoDownloader = nil;
    [self startDownloadMusic];
    m_WorkingIndex = -1;
}

// @ 0x4d4b8 — abort button of the shared progress dialog: cancel both downloaders.
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

// @ 0x4d560 — "Yes" (index 1) on the delete confirmation removes the song.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (alertView == m_DeleteAlertView && index == 1) {
        NSDictionary *item = [[[MusicManager getInstance] getPurchasedMusicDictionaris]
                                 objectAtIndex:m_WorkingIndex];
        unsigned int musicId = [[item objectForKey:@"ID"] unsignedIntValue];
        [[MusicManager getInstance] deleteMusic:musicId];
        [m_TableView reloadData];
    }
    m_WorkingIndex = -1;
}

// @ 0x4d64c — the audio download queue finished: refresh the list and close the dialog.
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    m_DlManager = nil;
    [m_TableView reloadData];
    [m_StoreViewCtrl hideModalDialog];
    m_WorkingIndex = -1;
}

// @ 0x4d6c4 — the audio download failed: show an error alert and close the dialog.
- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    m_DlManager = nil;

    CommonAlertView *alert = [[CommonAlertView alloc]
        initWithTitle:@"Error"
              message:@"ダウンロードに失敗しました。\nネットワーク接続をご確認下さい。"
             delegate:nil
    cancelButtonTitle:@"OK"
    otherButtonTitles:nil];
    [alert show];

    [m_StoreViewCtrl hideModalDialog];
    m_WorkingIndex = -1;
}

// @ 0x4d7dc — mirror the queue's overall progress into the dialog's progress bar.
- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    [[[m_StoreViewCtrl modalDialog] progressView] setProgress:m_DlManager.overallProgress];
}

// @ 0x4d848 — all orientations supported.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

// didReceiveMemoryWarning @ 0x4d84c — super-only override, omitted.

// @ 0x4d878 — drop the table view when the view is torn down (ARC clears the ivar).
- (void)viewDidUnload {
    [super viewDidUnload];
    m_TableView = nil;
}

// viewWillAppear: @ 0x4d8cc — super-only override, omitted.

// @ 0x4d8f8 — refresh the list and flash the scroll indicators on appear.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [m_TableView reloadData];
    [m_TableView flashScrollIndicators];
}

// viewWillDisappear: @ 0x4d958 — super-only override, omitted.
// viewDidDisappear: @ 0x4d984 — super-only override, omitted.

// @ 0x4d9b0 — KEPT under ARC: cancels the in-flight downloads and detaches delegates so
// no late callbacks fire (the ivar releases themselves are ARC-automatic).
- (void)dealloc {
    m_DeleteAlertView.delegate = nil;
    m_TableView.dataSource = nil;
    m_TableView.delegate = nil;
    [m_DlManager cancel];
    [m_InfoDownloader cancel];
    [self.view removeFromSuperview];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
