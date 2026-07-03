# PopnRhythmin — Exhaustive Missing Inventory

Machine-generated from Ghidra **rb420 / PopnRhythmin** by walking `__objc_classlist` and diffing
each class's `method_list` IMPs (thumb bit cleared) against the reconstructed `@ 0x…` address
annotations in `Project/`. A method is *reconstructed* iff its address appears in source.

## Totals — app Objective-C classes

| Metric | Count |
| --- | ---: |
| Classes audited | 148 |
| Complete | 10 |
| Partial (file exists, methods missing) | 64 |
| Fully missing (no source file) | 68 |
| **Missing methods** | **1557** |
| Ivars in fully-missing classes | ~378 |

## Scope decisions

| Component | Owner | Action |
| --- | --- | --- |
| TouchJSON — `CJSONDataSerializer` `CJSONDeserializer` `CJSONScanner` `CJSONSerializer` `CDataScanner` `CSerializedJSONData` | ours (no upstream source) | **reconstruct** (not in counts below yet) |
| ZipArchive — `UnZipArchive` | 3rd-party ([ziparchive](https://code.google.com/archive/p/ziparchive/)) | **exclude**, use upstream |
| `RewardNetwork*` / `Recommend*` (~24 classes) | Konami ad SDK | **stub now**, reconstruct much later |
| `BFCodec` (Blowfish) | unconfirmed | flagged |

## Fully missing classes — 68

| Class | Methods | Ivars | `instanceSize` |
| --- | ---: | ---: | ---: |
| `SearchView` | 31 | 17 | 251 |
| `InputConversionPassViewController` | 27 | 6 | 188 |
| `InputKIDViewCtrl` | 26 | 11 | 208 |
| `MapSelectSplitViewController` | 24 | 20 | 248 |
| `MapSelectViewController` | 24 | 10 | 204 |
| `FriendScoreMainView` | 23 | 12 | 212 |
| `InputNameViewCtrl` | 22 | 4 | 177 |
| `SoundSettingView` | 22 | 8 | 196 |
| `AcViewerOptionViewController` | 21 | 5 | 180 |
| `ConversionView` | 20 | 5 | 180 |
| `PresentBoxViewController` | 20 | 7 | 192 |
| `HowToViewCtrlPad` | 19 | 7 | 192 |
| `QuizMainViewController` | 19 | 26 | 276 |
| `AcViewerCategoryViewController` | 18 | 3 | 268 |
| `CheckerCategoryViewController` | 18 | 3 | 272 |
| `CustomAlertView` | 18 | 6 | 80 |
| `InputOTPViewCtrl` | 18 | 5 | 184 |
| `OverScoreLogViewController` | 18 | 6 | 188 |
| `PopnLinkTopViewController` | 17 | 6 | 184 |
| `SortSelectViewController` | 17 | 4 | 176 |
| `DefaultDataDownloadView` | 16 | 11 | 204 |
| `FreeRequestDetail` | 16 | 6 | 72 |
| `InviteTopViewControllerPad` | 16 | 5 | 180 |
| `SubMapSelectViewController` | 16 | 4 | 180 |
| `AcViewerMusicViewController` | 15 | 5 | 184 |
| `CustomWebView` | 15 | 10 | 116 |
| `FriendRequestTable` | 15 | 4 | 180 |
| `SettingTableSplitViewController` | 15 | 7 | 308 |
| `FreeRequestListViewController` | 14 | 4 | 180 |
| `FriendMngTopSplitViewController` | 14 | 13 | 284 |
| `FriendRequestViewController` | 14 | 4 | 180 |
| `PopnLinkTopSplitViewController` | 14 | 12 | 280 |
| `SettingTopViewController` | 14 | 2 | 168 |
| `InputKidViewController` | 12 | 3 | 176 |
| `TouchRangeViewCtrl` | 12 | 6 | 192 |
| `CommunicatingView` | 11 | 5 | 178 |
| `GameEffectView` | 11 | 0 | 162 |
| `PolicyView` | 11 | 1 | 168 |
| `RandomLoginBonusView` | 11 | 9 | 104 |
| `StoreDialogView` | 11 | 5 | 72 |
| `AcViewerHiSpeedViewController` | 10 | 0 | 162 |
| `AcceptPolicyViewController` | 10 | 5 | 180 |
| `CheckerMusicViewController` | 10 | 1 | 168 |
| `HttpConn` | 10 | 6 | 28 |
| `PopkunSizeViewCtrl` | 10 | 12 | 224 |
| `AcViewerHidSudViewController` | 9 | 0 | 162 |
| `AcViewerPopKunViewController` | 9 | 0 | 162 |
| `AcViewerRanMirViewController` | 9 | 0 | 162 |
| `CustomSplitViewController` | 9 | 3 | 176 |
| `DevDataDownloader` | 9 | 6 | 25 |
| `LoginBonusView` | 9 | 3 | 61 |
| `InviteTopViewController` | 8 | 1 | 163 |
| `MapAnnotation` | 8 | 4 | 32 |
| `CheckerDetail` | 7 | 15 | 368 |
| `DownloadImageView` | 7 | 3 | 68 |
| `DownloadProgresView` | 7 | 4 | 80 |
| `TouchRangeView` | 7 | 3 | 61 |
| `MyInviteCodeViewController` | 4 | 0 | 162 |
| `PurchaseStore` | 4 | 1 | 5 |
| `AcViewerCategoryCell` | 3 | 0 | 52 |
| `CheckerMusicCell` | 3 | 10 | 92 |
| `DelayImageView` | 3 | 1 | 56 |
| `FreeRequestListCell` | 3 | 11 | 96 |
| `QuizCell` | 3 | 2 | 60 |
| `TouchableTableView` | 3 | 0 | 56 |
| `TouchableScrollView` | 2 | 0 | 56 |
| `neWindow` | 1 | 0 | 144 |
| `ViewUtility` | 0 | 0 | 4 |

## Partial classes — 64

| Class | Reconstructed | Total | Missing |
| --- | ---: | ---: | ---: |
| `DownloadMain` | 25 | 119 | 94 |
| `StoreMainViewController` | 10 | 64 | 54 |
| `MainViewController` | 48 | 96 | 48 |
| `AudioManager` | 41 | 69 | 28 |
| `MusicData` | 9 | 34 | 25 |
| `AcMusicData` | 7 | 31 | 24 |
| `MusicManager` | 14 | 37 | 23 |
| `StoreAcvManageViewController` | 1 | 24 | 23 |
| `StoreManageViewController` | 1 | 23 | 22 |
| `AppDelegate` | 24 | 43 | 19 |
| `StorePackDetailViewPad` | 15 | 32 | 17 |
| `SettingTableViewController` | 4 | 20 | 16 |
| `ImageDownloader` | 7 | 20 | 13 |
| `StoreViewController` | 8 | 21 | 13 |
| `HowToViewCtrl` | 2 | 14 | 12 |
| `StoreDetailMusicCell` | 3 | 15 | 12 |
| `CharaInfo` | 2 | 13 | 11 |
| `CommonAlertView` | 4 | 15 | 11 |
| `StoreDownloadManager` | 1 | 12 | 11 |
| `StoreMusicInfo` | 2 | 13 | 11 |
| `AcViewerSplitViewController` | 7 | 16 | 9 |
| `FriendMngTopViewController` | 5 | 14 | 9 |
| `StoreDetailViewController` | 39 | 48 | 9 |
| `neGLView` | 6 | 15 | 9 |
| `PurchaseManager` | 22 | 30 | 8 |
| `Downloader` | 9 | 16 | 7 |
| `PurchaseTransactionCache` | 1 | 8 | 7 |
| `StorePackMusicView` | 7 | 14 | 7 |
| `AcViewerDetailCell` | 1 | 7 | 6 |
| `AcViewerMusicCell` | 1 | 7 | 6 |
| `LimitedCharaInfo` | 1 | 7 | 6 |
| `PreferredCharaInfo` | 1 | 7 | 6 |
| `StoreAcMusicInfo` | 2 | 8 | 6 |
| `StorePackCell` | 1 | 7 | 6 |
| `StorePackInfo` | 18 | 24 | 6 |
| `StorePackInfoDownloader` | 8 | 14 | 6 |
| `StorePackListController` | 13 | 19 | 6 |
| `StorePackView` | 5 | 11 | 6 |
| `BirthDayViewController` | 8 | 13 | 5 |
| `MusicPatch` | 4 | 9 | 5 |
| `PresentBoxCell` | 1 | 6 | 5 |
| `CustomButton` | 2 | 6 | 4 |
| `OverScoreLogCell` | 1 | 5 | 4 |
| `StorePromotionView` | 15 | 19 | 4 |
| `TwitterUtil` | 2 | 6 | 4 |
| `FriendReplyCell` | 4 | 7 | 3 |
| `FriendRequestCell` | 1 | 4 | 3 |
| `StoreDetailHeaderView` | 4 | 7 | 3 |
| `StoreDownloadTask` | 2 | 5 | 3 |
| `StoreImageView` | 4 | 7 | 3 |
| `StoreTableCell` | 1 | 4 | 3 |
| `AcViewerOptionCell` | 1 | 3 | 2 |
| `CheckerCategoryCell` | 1 | 3 | 2 |
| `CustomTextView` | 2 | 4 | 2 |
| `FriendScoreTableCell` | 1 | 3 | 2 |
| `MapListCell` | 1 | 3 | 2 |
| `SortCell` | 1 | 3 | 2 |
| `StoreDetailCopyrightCell` | 1 | 3 | 2 |
| `StorePromotionTableCell` | 1 | 3 | 2 |
| `SubMapListCell` | 1 | 3 | 2 |
| `SystemHardware` | 3 | 5 | 2 |
| `YearAndMonthPicker` | 7 | 9 | 2 |
| `FriendListCell` | 2 | 3 | 1 |
| `SettingOtherTableViewController` | 23 | 24 | 1 |

## Complete classes — 10

`ArcadeScoreData`, `FriendListDetail`, `FriendListDetailChara`, `FriendListViewController`, `FriendReplyViewController`, `HowToView`, `SettingCustomerTableViewController`, `SettingGameTableViewController`, `SettingHowtoTableViewController`, `TreasureData`

## Stub files (carry `TODO(dep)` / stub markers)

- `AppDelegate.mm`
- `FriendListViewController.mm`
- `FriendMngTopViewController.mm`
- `FriendReplyViewController.mm`
- `Game/Note/PlayJudge.mm`
- `SettingCustomerTableViewController.mm`
- `SettingGameTableViewController.mm`
- `SettingHowtoTableViewController.mm`
- `SettingOtherTableViewController.mm`
- `StoreDetailViewController.mm`
- `StoreImageView.m`
- `System/src/Task/PlayScene.mm`

## C / C++ non-method functions

The class walk covers Objective-C methods only. Non-method C/C++ functions were all named in the
Ghidra pass (0 `FUN_` remain). The reconstructed engine (`NoteMng`, `AcNoteMng`, `AepManager`,
the task classes, `TreasureMap`, `Random`) covers most; the main non-method gap is the **Sugoroku
board** — `SugorokuMainTask` (`Game/Task/SugorokuMainTask.mm`) and `SugorokuMap` (`Init` /
`GetWarpSquare` / `GetButtobiSquare`). Statically-linked library funcs (minizip / Blowfish / AES /
MD5 / libc++) are intentionally **not** reconstructed.

---

# Per-class detail

Order: fully missing → partial (most-missing first) → complete. Addresses are function entry points.

### `SearchView`  — ❌ missing

- Methods: **0 / 31** reconstructed (31 missing) · Ivars: 17 · `instanceSize`=251
- Missing methods: `initAtNavigationController` 0x85538, `dealloc` 0x85888, `viewDidLoad` 0x85a58, `didReceiveMemoryWarning` 0x861f8, `viewWillDisappear:` 0x86224, `showError:` 0x863a0, `gotoCurrentPosition` 0x864b8, `startSearchMaster` 0x8650c, `startGameCenter:` 0x865ec, `addIndicator` 0x867a4, `subIndicator` 0x867dc, `downloadMarkImage` 0x86810, `onCurrentPosButton` 0x86990, `mapViewWillStartLoadingMap:` 0x86a48, `mapViewDidFinishLoadingMap:` 0x86a4c, `mapViewDidFailLoadingMap:withError:` 0x86a50, `mapView:regionWillChangeAnimated:` 0x86a54, `mapView:regionDidChangeAnimated:` 0x86a58, `mapView:viewForAnnotation:` 0x870b0, `mapView:annotationView:calloutAccessoryControlTapped:` 0x87318, `commonAlertView:clickedButtonAtIndex:` 0x87520, `downloaderFinished:` 0x875a0, `downloaderError:` 0x8830c, `imageDownloader:didLoad:` 0x88398, `imageDownloaderDidFail:didLoad:` 0x88740, `backButtonFunc` 0x8879c, `startOpenAnimation` 0x88838, `endOpenAnimation` 0x88964, `startCloseAnimation` 0x88978, `endCloseAnimation` 0x88a98, `.cxx_construct` 0x88b04
- Ivars: `m_Map:@"MKMapView"@164`, `m_Indicator:@"UIActivityIndicatorView"@168`, `m_IndicatorCount:i@172`, `m_MessageLabel:@"UILabel"@176`, `m_ErrorLabel:@"UILabel"@180`, `m_MasterDownloader:@"Downloader"@184`, `m_ListDownloader:@"Downloader"@188`, `m_ImageDownloader:@"ImageDownloader"@192`, `m_Info:@"NSMutableDictionary"@196`, `m_Models:@"NSMutableArray"@200`, `m_ModelNameForArrayIndex:@"NSMutableDictionary"@204`, `m_LastRegion:{?="center"{?="latitude"d"longitude"d}"span"{?="latitudeDelta"d"longitudeDelta"d}}@208`, `m_DictSpot:@"NSMutableDictionary"@240`, `m_GoogleMapURL:@"NSString"@244`, `m_LoadedMaster:c@248`, `m_LoadedImages:c@249`, `m_IsAnimationing:c@250`

### `InputConversionPassViewController`  — ❌ missing

- Methods: **0 / 27** reconstructed (27 missing) · Ivars: 6 · `instanceSize`=188
- Missing methods: `init` 0x911d0, `initAtNavigationController` 0x91e84, `dealloc` 0x92064, `onBackBtn` 0x920b4, `startOpenAnimation` 0x920e8, `endOpenAnimation` 0x92220, `startCloseAnimation` 0x92238, `endCloseAnimation` 0x92368, `didReceiveMemoryWarning` 0x9240c, `viewDidLoad` 0x92438, `viewDidUnload` 0x92464, `viewWillAppear:` 0x92490, `viewDidAppear:` 0x924bc, `viewWillDisappear:` 0x924e8, `viewDidDisappear:` 0x92514, `shouldAutorotateToInterfaceOrientation:` 0x92540, `textFieldShouldBeginEditing:` 0x9254c, `textFieldShouldReturn:` 0x92550, `touchedDecideButton:` 0x925a4, `textField:shouldChangeCharactersInRange:replacementString:` 0x92664, `downloaderFinished:` 0x926e0, `downloaderError:` 0x93938, `startConversionHttpWithId:pass:` 0x93a00, `checkUsableCharacterForId:` 0x93c38, `checkUsableCharacterForPass:` 0x93cf0, `commonAlertView:clickedButtonAtIndex:` 0x93d80, `handleTapCoverView` 0x93d90
- Ivars: `_idField:@"UITextField"@164`, `_passField:@"UITextField"@168`, `_indicator:@"UIActivityIndicatorView"@172`, `_downloader:@"Downloader"@176`, `m_IsAnimationing:c@180`, `_coverView:@"UIView"@184`

### `InputKIDViewCtrl`  — ❌ missing

- Methods: **0 / 26** reconstructed (26 missing) · Ivars: 11 · `instanceSize`=208
- Missing methods: `init` 0xd5888, `didReceiveMemoryWarning` 0xd66e8, `dealloc` 0xd6714, `viewDidLoad` 0xd67ec, `viewDidUnload` 0xd6818, `viewWillAppear:` 0xd6844, `viewDidAppear:` 0xd6870, `viewWillDisappear:` 0xd689c, `viewDidDisappear:` 0xd68c8, `shouldAutorotateToInterfaceOrientation:` 0xd68f4, `textFieldShouldBeginEditing:` 0xd6900, `textFieldDidEndEditing:` 0xd6904, `textFieldShouldReturn:` 0xd6948, `touchedDecideButton:` 0xd69b0, `touchedBackButton:` 0xd6af8, `endDirectCloseAnimation` 0xd6c90, `textField:shouldChangeCharactersInRange:replacementString:` 0xd6cec, `downloaderFinished:` 0xd6d90, `downloaderError:` 0xd6fa8, `startLinkKidHttp` 0xd7088, `commonAlertView:clickedButtonAtIndex:` 0xd7284, `keyboardWasShown:` 0xd72e4, `keyboardWillBeHidden:` 0xd7328, `touchesBegan:withEvent:` 0xd7358, `delegate` 0xd73f4, `setDelegate:` 0xd7404
- Ivars: `_scrollView:@"TouchableScrollView"@164`, `_kidField:@"UITextField"@168`, `_passField:@"UITextField"@172`, `_otpField:@"UITextField"@176`, `_dummyView:@"UIViewController"@180`, `_downloader:@"Downloader"@184`, `oldKonamiId:@"NSString"@188`, `oldPassword:@"NSString"@192`, `_scrollOffset:f@196`, `_isAninationing:c@200`, `_delegate:@"<PopnLinkTopSplitViewControllerDelegate>"@204`

### `MapSelectSplitViewController`  — ❌ missing

- Methods: **0 / 24** reconstructed (24 missing) · Ivars: 20 · `instanceSize`=248
- Missing methods: `init` 0x754d8, `dealloc` 0x764dc, `viewDidLoad` 0x765dc, `didReceiveMemoryWarning` 0x76608, `viewWillAppear:` 0x76634, `setSelectIndexPath:` 0x766b8, `startOpenAnimation` 0x766e0, `endOpenAnimation` 0x7680c, `startCloseAnimation` 0x769c8, `endCloseAnimation` 0x76ad0, `touchWithTreasureData:mapHeadArray:mainMapId:` 0x76b40, `scrollViewDidScroll:` 0x77768, `scrollViewWillBeginDragging:` 0x77f00, `scrollViewDidEndDecelerating:` 0x77f28, `scrollViewDidEndDragging:willDecelerate:` 0x77f38, `restartAutoScroll` 0x77f50, `restartAutoScrollAfterDelay` 0x77f70, `autoScroll` 0x77fa4, `downloadMainFinished:` 0x7819c, `updateEventInfo` 0x781ac, `pageControlDidChanged:` 0x786fc, `backButtonFunc` 0x78794, `.cxx_construct` 0x787f0, `isAnimationing` 0x787d8
- Ivars: `_isAnimationing:c@162`, `_markView:@"UIImageView"@164`, `_selectIndexPath:@"NSIndexPath"@168`, `_mapSelectViewCtrl:@"MapSelectViewController"@172`, `_subMapSelectViewCtrl:@"SubMapSelectViewController"@176`, `_arrowImageView:@"UIImageView"@180`, `_arrowFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@184`, `_rightImageView:@"UIImageView"@200`, `_rightDummyView:@"UIView"@204`, `_rightHeaderImageView:@"UIImageView"@208`, `_rightHeaderLabel:@"UILabel"@212`, `_rightHeaderDummyView:@"UIView"@216`, `_rightEmptyImageView:@"UIImageView"@220`, `_eventImageView:@"UIImageView"@224`, `_eventDummyView:@"UIView"@228`, `_scrollView:@"UIScrollView"@232`, `_pageCtrl:@"UIPageControl"@236`, `_eventViewing:c@240`, `_autoScroll:c@241`, `_howtoViewCtrlPad:@"HowToViewCtrlPad"@244`

### `MapSelectViewController`  — ❌ missing

- Methods: **0 / 24** reconstructed (24 missing) · Ivars: 10 · `instanceSize`=204
- Missing methods: `initWithStyle:` 0xbec60, `initAtNavigationController` 0xbf498, `dealloc` 0xbf7a8, `viewDidLoad` 0xbf980, `didReceiveMemoryWarning` 0xbf9e0, `viewDidAppear:` 0xbfa0c, `startOpenAnimation` 0xbfa38, `endOpenAnimation` 0xbfb70, `startCloseAnimation` 0xbfb88, `endCloseAnimation` 0xbfc90, `numberOfSectionsInTableView:` 0xbfcec, `tableView:numberOfRowsInSection:` 0xbfcf0, `tableView:cellForRowAtIndexPath:` 0xbfd18, `tableView:titleForHeaderInSection:` 0xbfe40, `tableView:didSelectRowAtIndexPath:` 0xbfe44, `scrollViewDidScroll:` 0xc0098, `downloadMainFinished:` 0xc00bc, `backButtonFunc` 0xc00fc, `updateEventInfo` 0xc0190, `mapSelectDelegate` 0xc0768, `setMapSelectDelegate:` 0xc0778, `treasureDataArray` 0xc0788, `mapHeadArray` 0xc079c, `mapDataArray` 0xc07b0
- Ivars: `_dummyHeadView:@"UIView"@164`, `_eventHeadView:@"UIView"@168`, `_dummyView:@"UIViewController"@172`, `_treasureDataArray:@"NSArray"@176`, `_mapHeadArray:@"NSArray"@180`, `_mapDataArray:@"NSArray"@184`, `_isAnimationing:c@188`, `_eventIds:@"NSMutableArray"@192`, `_mapSelectDelegate:@"<MapSelectViewControllerDelegate>"@196`, `_selectedIndexRow:i@200`

### `FriendScoreMainView`  — ❌ missing

- Methods: **0 / 23** reconstructed (23 missing) · Ivars: 12 · `instanceSize`=212
- Missing methods: `initAtNavigationControllerWithMusicId:` 0xa9df0, `dealloc` 0xabdd8, `viewDidLoad` 0xabef8, `didReceiveMemoryWarning` 0xabf9c, `startOpenAnimation` 0xabfc8, `endOpenAnimation` 0xac120, `startCloseAnimation` 0xac138, `endCloseAnimation` 0xac270, `numberOfSectionsInTableView:` 0xac384, `tableView:numberOfRowsInSection:` 0xac388, `tableView:cellForRowAtIndexPath:` 0xac45c, `tableView:didSelectRowAtIndexPath:` 0xac74c, `downloaderFinished:` 0xac7f0, `downloaderProceed:` 0xadc10, `downloaderError:` 0xadc14, `downloadMainFinished:` 0xadcec, `tabBarController:didSelectViewController:` 0xaddc0, `onBackButtonTouched` 0xaddf4, `releaseFriendScore` 0xade6c, `startGetFriendScoreHttp` 0xadee4, `isAnimationing` 0xae028, `musicId` 0xae040, `setMusicId:` 0xae054
- Ivars: `_tabCtrl:@"UITabBarController"@164`, `_tblViewCtrlN:@"UITableViewController"@168`, `_tblViewCtrlH:@"UITableViewController"@172`, `_tblViewCtrlEx:@"UITableViewController"@176`, `_dummyView:@"UIViewController"@180`, `_selectedView:@"UIViewController"@184`, `_dlGetFriendScore:@"Downloader"@188`, `_frScoreNArray:@"NSArray"@192`, `_frScoreHArray:@"NSArray"@196`, `_frScoreExArray:@"NSArray"@200`, `_isAnimationing:c@204`, `_musicId:I@208`

### `InputNameViewCtrl`  — ❌ missing

- Methods: **0 / 22** reconstructed (22 missing) · Ivars: 4 · `instanceSize`=177
- Missing methods: `init` 0x8f438, `initAtNavigationController` 0x90668, `startOpenAnimation` 0x90740, `endOpenAnimation` 0x90878, `startCloseAnimation` 0x90890, `endCloseAnimation` 0x90998, `didReceiveMemoryWarning` 0x90a28, `viewDidLoad` 0x90a54, `viewDidUnload` 0x90a80, `viewWillAppear:` 0x90aac, `viewDidAppear:` 0x90ad8, `viewWillDisappear:` 0x90b04, `viewDidDisappear:` 0x90b30, `shouldAutorotateToInterfaceOrientation:` 0x90b5c, `textFieldShouldBeginEditing:` 0x90b68, `textFieldShouldReturn:` 0x90b6c, `touchedDecideButton:` 0x90b94, `textField:shouldChangeCharactersInRange:replacementString:` 0x90c10, `downloaderFinished:` 0x90c4c, `downloaderError:` 0x90e48, `startPlayerNewHttp:` 0x90f14, `checkUsableCharacter:` 0x91108
- Ivars: `_nameField:@"UITextField"@164`, `_indicator:@"UIActivityIndicatorView"@168`, `_downloader:@"Downloader"@172`, `m_IsAnimationing:c@176`

### `SoundSettingView`  — ❌ missing

- Methods: **0 / 22** reconstructed (22 missing) · Ivars: 8 · `instanceSize`=196
- Missing methods: `initWithStyle:` 0x811c8, `dealloc` 0x8131c, `viewDidLoad` 0x81564, `didReceiveMemoryWarning` 0x8191c, `viewDidUnload` 0x81948, `viewWillAppear:` 0x81974, `viewDidAppear:` 0x819a0, `viewWillDisappear:` 0x819cc, `viewDidDisappear:` 0x819f8, `shouldAutorotateToInterfaceOrientation:` 0x81a24, `numberOfSectionsInTableView:` 0x81a30, `tableView:numberOfRowsInSection:` 0x81a60, `tableView:cellForRowAtIndexPath:` 0x81a8c, `tableView:titleForHeaderInSection:` 0x82780, `tableView:viewForHeaderInSection:` 0x82784, `tableView:heightForHeaderInSection:` 0x8292c, `tableView:didSelectRowAtIndexPath:` 0x82934, `bgmSliderValChanged:` 0x82af4, `seSliderValChanged:` 0x82bbc, `touchSoundSliderValChanged:` 0x82cc4, `isHaveTouchSound:` 0x82d9c, `backButtonFunc` 0x82dc0
- Ivars: `_bgmSlider:@"UISlider"@164`, `_seSlider:@"UISlider"@168`, `_touchSoundSlider:@"UISlider"@172`, `_touchSoundRscId:i@176`, `_seRscId:i@180`, `_selectedTouchSoundNo:i@184`, `_touchSoundHaveFlg:i@188`, `_touchSoundArray:@"NSMutableArray"@192`

### `AcViewerOptionViewController`  — ❌ missing

- Methods: **0 / 21** reconstructed (21 missing) · Ivars: 5 · `instanceSize`=180
- Missing methods: `init` 0xdeff0, `initForAcMain:` 0xdfc0c, `viewDidLoad` 0xdfe30, `viewWillAppear:` 0xdfee0, `handleGesture:` 0xdff0c, `numberOfSectionsInTableView:` 0xdff78, `tableView:numberOfRowsInSection:` 0xdff7c, `tableView:cellForRowAtIndexPath:` 0xdff88, `tableView:titleForHeaderInSection:` 0xe00c0, `tableView:accessoryTypeForRowWithIndexPath:` 0xe00c4, `tableView:didSelectRowAtIndexPath:` 0xe00c8, `touchedPlayButton:` 0xe0374, `touchedResumeButton:` 0xe0490, `touchedBackButton:` 0xe053c, `sendLog` 0xe0664, `startOpenAnimationForAcMain` 0xe0820, `startCloseAnimation` 0xe0960, `endCloseAnimation` 0xe0a78, `endCloseAnimationForAcMain` 0xe0ad4, `delegate` 0xe0b20, `setDelegate:` 0xe0b30
- Ivars: `_naviCtrl:@"UINavigationController"@164`, `_forAcMain:c@168`, `_isAnimationing:c@169`, `_pAcMain:^{AcMainTask=^^?^{C_TASK}^{C_TASK}i^{C_TASK}^{C_TASK}^{C_TASK}^{C_TASK}*B{WorkStruct=[1^{AepTexture}][10^{AepTexture}][1^{AepLyrCtrl}][1^{AepLyrCtrl}][1i][1i][1i][1i][10i][9i][7i][1i][1i]i{CGPoint=ff}{CGPoint=ff}{CGPoint=ff}BIssiifiiiiiiiiiiiiiiiiii[9i]iii@172`, `_delegate:@"<AcViewerViewControllerDelegate>"@176`

### `ConversionView`  — ❌ missing

- Methods: **0 / 20** reconstructed (20 missing) · Ivars: 5 · `instanceSize`=180
- Missing methods: `init` 0x1be48, `dealloc` 0x1be84, `viewDidLoad` 0x1beb0, `didReceiveMemoryWarning` 0x1ca9c, `viewDidUnload` 0x1cac8, `viewWillAppear:` 0x1caf4, `viewDidAppear:` 0x1cb20, `viewWillDisappear:` 0x1cb4c, `viewDidDisappear:` 0x1cb78, `shouldAutorotateToInterfaceOrientation:` 0x1cba4, `backButtonFunc` 0x1cbb0, `okButtonFunc` 0x1cc4c, `commonAlertView:clickedButtonAtIndex:` 0x1cd00, `startConversionHttp` 0x1cf0c, `downloaderFinished:` 0x1da60, `downloaderError:` 0x1dc84, `startCloseAnimation` 0x1dd50, `endCloseAnimation` 0x1de20, `delegate` 0x1de7c, `setDelegate:` 0x1de8c
- Ivars: `isAnimationing:c@162`, `_indicator:@"UIActivityIndicatorView"@164`, `_downloader:@"Downloader"@168`, `_delegate:@"<ViewCmnProtocol>"@172`, `_convertCodeStr:@"NSString"@176`

### `PresentBoxViewController`  — ❌ missing

- Methods: **0 / 20** reconstructed (20 missing) · Ivars: 7 · `instanceSize`=192
- Missing methods: `initWithStyle:` 0x24098, `initAtNavigationController` 0x24938, `dealloc` 0x24988, `viewDidLoad` 0x24abc, `viewWillAppear:` 0x24ba4, `didReceiveMemoryWarning` 0x24c6c, `startOpenAnimation` 0x24c98, `endOpenAnimation` 0x2514c, `startCloseAnimation` 0x25160, `endCloseAnimation` 0x255bc, `numberOfSectionsInTableView:` 0x25628, `tableView:numberOfRowsInSection:` 0x2562c, `tableView:cellForRowAtIndexPath:` 0x25668, `downloadMainFinished:` 0x257a8, `backButtonFunc` 0x25cdc, `allGetFunc` 0x25d48, `indexPathForControlEvent:` 0x25db4, `touchedGetButton:event:` 0x25e34, `customAlertView:clickedButtonAtIndex:` 0x260a4, `isAnimationing` 0x26144
- Ivars: `_dummyView:@"UIViewController"@164`, `_emptyImageView:@"UIImageView"@168`, `_btnGetAll:@"UIButton"@172`, `_isAnimationing:c@176`, `_presentDataArray:@"NSMutableArray"@180`, `_customAlert:@"CustomAlertView"@184`, `_presentDataValue:@"NSValue"@188`

### `HowToViewCtrlPad`  — ❌ missing

- Methods: **0 / 19** reconstructed (19 missing) · Ivars: 7 · `instanceSize`=192
- Missing methods: `initWithFileNameArray:` 0x16718, `dealloc` 0x1676c, `viewDidLoad` 0x16808, `viewWillAppear:` 0x16adc, `viewDidAppear:` 0x16b40, `didReceiveMemoryWarning` 0x1718c, `viewWillDisappear:` 0x171b8, `pageControlDidChanged:` 0x171e4, `scrollViewDidScroll:` 0x1727c, `startOpenAnimation` 0x17378, `endOpenAnimation` 0x174a4, `startCloseAnimation` 0x174b8, `endCloseAnimation` 0x175d8, `setPageImages` 0x17634, `handleTapCoverView:` 0x178f8, `backGroundImage` 0x1791c, `setBackGroundImage:` 0x17930, `pageCtrl` 0x17940, `setPageCtrl:` 0x17954
- Ivars: `_fileNameArray:@"NSArray"@164`, `_scrollView:@"UIScrollView"@168`, `_pageCtrl:@"UIPageControl"@172`, `_backGroundImage:@"UIImage"@176`, `_isAnimationing:c@180`, `m_CoverView:@"UIView"@184`, `_pageImgs:@"UIView"@188`

### `QuizMainViewController`  — ❌ missing

- Methods: **0 / 19** reconstructed (19 missing) · Ivars: 26 · `instanceSize`=276
- Missing methods: `initWithStyle:` 0xda198, `dealloc` 0xdb2a4, `viewDidLoad` 0xdb3d4, `didReceiveMemoryWarning` 0xdb438, `numberOfSectionsInTableView:` 0xdb464, `tableView:numberOfRowsInSection:` 0xdb468, `tableView:cellForRowAtIndexPath:` 0xdb538, `tableView:titleForHeaderInSection:` 0xdb674, `tableView:didSelectRowAtIndexPath:` 0xdb678, `downloaderFinished:` 0xdb730, `downloaderProceed:` 0xdb7ac, `downloaderError:` 0xdb7b0, `touchedBackButton:` 0xdb8cc, `getQuizFinished` 0xdb968, `replyQuizFinished` 0xdbda4, `startGetQuizHttp` 0xdc2b8, `startReplyQuizHttp` 0xdc36c, `drawResult` 0xdc4ec, `touchesBegan:withEvent:` 0xdca68
- Ivars: `_dummyView:@"UIViewController"@164`, `_questionLbl:@"UILabel"@168`, `_rightView:@"UIImageView"@172`, `_wrongView:@"UIImageView"@176`, `_blackBoardView:@"UIImageView"@180`, `_blackBoardResultView:@"UIImageView"@184`, `_hanamaruView:@"UIImageView"@188`, `_presentBaseView:@"UIView"@192`, `_defSsmView:@"UIImageView"@196`, `_rightSsmView:@"UIImageView"@200`, `_wrongSsmView:@"UIImageView"@204`, `_dlQuiz:@"Downloader"@208`, `_dlAnswer:@"Downloader"@212`, `_question:@"NSString"@216`, `_quizAnswerArray:@"NSArray"@220`, `_quizId:i@224`, `_rightAnswer:i@228`, `_totalCorrect:i@232`, `_totalIncorrect:i@236`, `_consecutive:i@240`, `_finaleAnswer:i@244`, `_selectAnswer:i@248`, `_selectCell:@"UITableViewCell"@252`, `_isAnswerable:c@256`, `_presentSt:i@260`, `_sdRscId:[3i]@264`

### `AcViewerCategoryViewController`  — ❌ missing

- Methods: **0 / 18** reconstructed (18 missing) · Ivars: 3 · `instanceSize`=268
- Missing methods: `getAcMusicData:` 0x687f0, `initWithStyle:` 0x68804, `initAtNavigationController` 0x68d40, `dealloc` 0x68ec8, `viewDidLoad` 0x68f30, `didReceiveMemoryWarning` 0x6903c, `startOpenAnimation` 0x69068, `endOpenAnimation` 0x691a0, `startCloseAnimation` 0x691b8, `endCloseAnimation` 0x692c0, `numberOfSectionsInTableView:` 0x6932c, `tableView:numberOfRowsInSection:` 0x69330, `tableView:cellForRowAtIndexPath:` 0x69378, `tableView:titleForHeaderInSection:` 0x694c4, `tableView:didSelectRowAtIndexPath:` 0x694c8, `touchedBackButton:` 0x696c4, `delegate` 0x69740, `setDelegate:` 0x69750
- Ivars: `_acMusicDataArray:[24@"NSArray"]@164`, `_isAnimationing:c@260`, `_delegate:@"<AcViewerViewControllerDelegate>"@264`

### `CheckerCategoryViewController`  — ❌ missing

- Methods: **0 / 18** reconstructed (18 missing) · Ivars: 3 · `instanceSize`=272
- Missing methods: `initWithStyle:` 0xcfb88, `dealloc` 0xd04bc, `viewDidLoad` 0xd0564, `viewWillAppear:` 0xd05c4, `didReceiveMemoryWarning` 0xd0688, `startGetArcadeScoreHttpWithOtp:` 0xd06b4, `numberOfSectionsInTableView:` 0xd0810, `tableView:numberOfRowsInSection:` 0xd0814, `tableView:cellForRowAtIndexPath:` 0xd085c, `tableView:titleForHeaderInSection:` 0xd0988, `tableView:didSelectRowAtIndexPath:` 0xd098c, `downloaderFinished:` 0xd0ad8, `downloaderProceed:` 0xd1884, `downloaderError:` 0xd1888, `touchedBackButton:` 0xd1960, `touchedGetDataButton:` 0xd1a18, `convertReplaceChara:` 0xd1b40, `convertCategoryId:` 0xd1cac
- Ivars: `_dummyView:@"UIViewController"@164`, `_scoreDataArray:[25@"NSArray"]@168`, `_dlGetArcadeScoreData:@"Downloader"@268`

### `CustomAlertView`  — ❌ missing

- Methods: **0 / 18** reconstructed (18 missing) · Ivars: 6 · `instanceSize`=80
- Missing methods: `dealloc` 0x26880, `setTitleColor:` 0x268ac, `setTextColor:` 0x268cc, `setTitleFontSize:` 0x268ec, `setTextFontSize:` 0x26940, `setOpenAnimeType:` 0x26994, `setCloseAnimeType:` 0x269ac, `initWithType:title:message:cancelButtonTitle:otherButtonTitle:` 0x269c4, `initWithView:type:title:message:cancelButtonTitle:otherButtonTitle:` 0x26a60, `initWithView:center:type:title:message:cancelButtonTitle:otherButtonTitle:` 0x26abc, `show` 0x274fc, `removeView` 0x277b8, `endCloseAnimation` 0x27ad0, `clickedYesButton:` 0x27ae0, `clickedNoButton:` 0x27b34, `customAlertView:clickedButtonAtIndex:` 0x27b88, `delegate` 0x27b8c, `setDelegate:` 0x27b9c
- Ivars: `mDelegate:@"<CustomAlertViewDelegate>"@56`, `mBgImageView:@"UIView"@60`, `_title:@"UILabel"@64`, `_text:@"CustomTextView"@68`, `m_OpenAnimeType:i@72`, `m_CloseAnimeType:i@76`

### `InputOTPViewCtrl`  — ❌ missing

- Methods: **0 / 18** reconstructed (18 missing) · Ivars: 5 · `instanceSize`=184
- Missing methods: `initWithCategoryView:` 0x78d18, `didReceiveMemoryWarning` 0x79518, `dealloc` 0x79544, `viewDidLoad` 0x79590, `viewDidUnload` 0x795bc, `viewWillAppear:` 0x795e8, `viewDidAppear:` 0x79614, `viewWillDisappear:` 0x79640, `viewDidDisappear:` 0x7966c, `shouldAutorotateToInterfaceOrientation:` 0x79698, `textFieldShouldBeginEditing:` 0x796a4, `textFieldShouldReturn:` 0x796a8, `touchedDecideButton:` 0x796d4, `touchedBackButton:` 0x797c4, `endDirectCloseAnimation` 0x79860, `textField:shouldChangeCharactersInRange:replacementString:` 0x798bc, `keyboardWasShown:` 0x798f8, `keyboardWillBeHidden:` 0x798fc
- Ivars: `_categoryView:@"CheckerCategoryViewController"@164`, `_scrollView:@"TouchableScrollView"@168`, `_otpField:@"UITextField"@172`, `_dummyView:@"UIViewController"@176`, `_scrollOffset:f@180`

### `OverScoreLogViewController`  — ❌ missing

- Methods: **0 / 18** reconstructed (18 missing) · Ivars: 6 · `instanceSize`=188
- Missing methods: `initWithStyle:` 0x29928, `initAtNavigationController:` 0x29e24, `dealloc` 0x29fd8, `viewDidLoad` 0x2a08c, `didReceiveMemoryWarning` 0x2a180, `startOpenAnimation` 0x2a1b0, `endOpenAnimation` 0x2a664, `startCloseAnimation` 0x2a678, `endCloseAnimation` 0x2aad4, `numberOfSectionsInTableView:` 0x2ab80, `tableView:heightForRowAtIndexPath:` 0x2ab84, `tableView:numberOfRowsInSection:` 0x2abe0, `tableView:cellForRowAtIndexPath:` 0x2ac1c, `tableView:didSelectRowAtIndexPath:` 0x2ad28, `downloadMainFinished:` 0x2adac, `backButtonFunc` 0x2aefc, `musicSelTask` 0x2af2c, `setMusicSelTask:` 0x2af40
- Ivars: `_dummyView:@"UIViewController"@164`, `_isAnimationing:c@168`, `_overScoreLogDataArray:@"NSMutableArray"@172`, `_musicSelTask:^{MusicSelTask=^^?^{C_TASK}^{C_TASK}i^{C_TASK}^{C_TASK}^{C_TASK}^{C_TASK}*B{WorkStruct=^{AepManager}@@[4^{AepLyrCtrl}][2^{AepLyrCtrl}][2^{AepTexture}]^{AepTexture}^{AepTexture}[10^{AepTexture}][10^{AepTexture}][10^{AepTexture}][3[10^{AepTexture}]][3i][3i][3i][3i][24i][3i][7i][7i][3i][22i][6i][3i][3[3i]][3i][27{JacketStruct=ii@^{AepTexture}{MusicInfoStruct=@[3i][3i][3s][3B][3B]}}][3c][5i][5i]iiiiiii[3i][3B][3B]BBBBBBBBBBBBi[10I][10i]fiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiifiiiiBiii@i@i^{C_TASK}}i}@176`, `m_musicId:i@180`, `m_sheet:i@184`

### `PopnLinkTopViewController`  — ❌ missing

- Methods: **0 / 17** reconstructed (17 missing) · Ivars: 6 · `instanceSize`=184
- Missing methods: `updateButtonEnable` 0xcca48, `init` 0xccacc, `initAtNavigationController` 0xcd2e0, `viewDidLoad` 0xcd4b8, `viewWillAppear:` 0xcd4e4, `didReceiveMemoryWarning` 0xcd57c, `startOpenAnimation` 0xcd5a8, `endOpenAnimation` 0xcd8f4, `startCloseAnimation` 0xcd908, `endCloseAnimation` 0xcda68, `onInKidButtonTouched:` 0xcdad4, `onScoreCheckerButtonTouched:` 0xcdc18, `onQuizButtonTouched:` 0xcdd5c, `delegate` 0xcdea0, `setDelegate:` 0xcdeb0, `scrollView` 0xcdec0, `setScrollView:` 0xcded0
- Ivars: `_isAnimationing:c@162`, `_btnId:@"UIButton"@164`, `_btnChecker:@"UIButton"@168`, `_btnQuiz:@"UIButton"@172`, `_delegate:@@176`, `_scrollView:@"UIScrollView"@180`

### `SortSelectViewController`  — ❌ missing

- Methods: **0 / 17** reconstructed (17 missing) · Ivars: 4 · `instanceSize`=176
- Missing methods: `initWithStyle:` 0xc5988, `initAtNavigationController:` 0xc6018, `dealloc` 0xc61cc, `viewDidLoad` 0xc6230, `didReceiveMemoryWarning` 0xc625c, `startOpenAnimation` 0xc6288, `endOpenAnimation` 0xc673c, `startCloseAnimation` 0xc6750, `endCloseAnimation` 0xc6c0c, `numberOfSectionsInTableView:` 0xc6c78, `tableView:numberOfRowsInSection:` 0xc6c7c, `tableView:cellForRowAtIndexPath:` 0xc6ca4, `tableView:titleForHeaderInSection:` 0xc6db0, `tableView:didSelectRowAtIndexPath:` 0xc6db4, `backButtonFunc` 0xc6fe4, `musicSelTask` 0xc7028, `setMusicSelTask:` 0xc703c
- Ivars: `_isAnimationing:c@162`, `_pMusicSelTask:^v@164`, `_sortDataArray:@"NSArray"@168`, `_dummyView:@"UIViewController"@172`

### `DefaultDataDownloadView`  — ❌ missing

- Methods: **0 / 16** reconstructed (16 missing) · Ivars: 11 · `instanceSize`=204
- Missing methods: `initWithFileDataArray:` 0xdd158, `viewDidLoad` 0xdd3d4, `didReceiveMemoryWarning` 0xdd400, `dealloc` 0xdd42c, `downloadWithIdx:` 0xdd4c0, `downloaderFinished:` 0xdd6fc, `downloaderProceed:` 0xdd9cc, `downloaderError:` 0xddaf4, `startOpenAnimation` 0xddbe8, `endOpenAnimation` 0xddcd8, `startCloseAnimation` 0xddf38, `endCloseAnimation` 0xde028, `isDigit:` 0xde084, `setJustDownloadedSize` 0xde114, `isFailed` 0xde1a0, `setIsFailed:` 0xde1b8
- Ivars: `_downloadView:@"DownloadProgresView"@164`, `_dlFileListDataArray:@"NSArray"@168`, `_downloader:@"Downloader"@172`, `_downloadingIdx:i@176`, `_filePath:@"NSString"@180`, `_fileSize:i@184`, `_totalFileSize:i@188`, `_downloadedFileSize:i@192`, `_isFailed:c@196`, `_isAnimationing:c@197`, `_tryCnt:i@200`

### `FreeRequestDetail`  — ❌ missing

- Methods: **0 / 16** reconstructed (16 missing) · Ivars: 6 · `instanceSize`=72
- Missing methods: `initWithFrame:friendData:` 0xe3170, `addCntNum:sheet:y:view:` 0xe40ac, `deallc` 0xe4278, `startOpenAnimation` 0xe42f8, `endOpenAnimation` 0xe43d0, `startCloseAnimation` 0xe43e8, `endCloseAnimation` 0xe44a8, `downloaderFinished:` 0xe44e0, `downloaderProceed:` 0xe46a0, `downloaderError:` 0xe46a4, `commonAlertView:clickedButtonAtIndex:` 0xe476c, `startRequestFriendHttp` 0xe477c, `touchedCancel` 0xe490c, `touchesEnded:withEvent:` 0xe493c, `isAnimationing` 0xe4994, `isEnabled` 0xe49ac
- Ivars: `_dummyView:@"UIView"@52`, `_friendData:@"NSValue"@56`, `_isAnimationing:c@60`, `_isEnabled:c@61`, `_downloader:@"Downloader"@64`, `_scaleForPad:f@68`

### `InviteTopViewControllerPad`  — ❌ missing

- Methods: **0 / 16** reconstructed (16 missing) · Ivars: 5 · `instanceSize`=180
- Missing methods: `initAtNavigationController` 0x5c638, `dealloc` 0x5d0fc, `touchedDecideButton:` 0x5d128, `startOpenAnimation` 0x5d350, `endOpenAnimation` 0x5d488, `startCloseAnimation` 0x5d4a0, `endCloseAnimation` 0x5d5c0, `textFieldShouldBeginEditing:` 0x5d61c, `textFieldDidEndEditing:` 0x5d654, `textFieldShouldReturn:` 0x5d698, `textField:shouldChangeCharactersInRange:replacementString:` 0x5d6c0, `downloaderFinished:` 0x5d728, `downloaderError:` 0x5d944, `commonAlertView:clickedButtonAtIndex:` 0x5da10, `startInviteHttp:` 0x5da14, `onTweetButton` 0x5db50
- Ivars: `isAnimationing:c@162`, `_codeField:@"UITextField"@164`, `_indicator:@"UIActivityIndicatorView"@168`, `_downloader:@"Downloader"@172`, `_scrollView:@"UIScrollView"@176`

### `SubMapSelectViewController`  — ❌ missing

- Methods: **0 / 16** reconstructed (16 missing) · Ivars: 4 · `instanceSize`=180
- Missing methods: `initWithTreasureData:mapHeadArray:mainMapId:` 0xc1ea0, `dealloc` 0xc2910, `viewDidLoad` 0xc2aa0, `handleGesture:` 0xc2b80, `didReceiveMemoryWarning` 0xc2bec, `numberOfSectionsInTableView:` 0xc2c18, `tableView:numberOfRowsInSection:` 0xc2c1c, `tableView:cellForRowAtIndexPath:` 0xc2c44, `tableView:titleForHeaderInSection:` 0xc2d50, `tableView:didSelectRowAtIndexPath:` 0xc2d54, `startCloseAnimation` 0xc3088, `endCloseAnimation` 0xc31a8, `downloadMainFinished:` 0xc3204, `backButtonFunc` 0xc3280, `delegate` 0xc3334, `setDelegate:` 0xc3344
- Ivars: `_dummyView:@"UIViewController"@164`, `_subMapArray:@"NSArray"@168`, `_isDecide:c@172`, `_delegate:@@176`

### `AcViewerMusicViewController`  — ❌ missing

- Methods: **0 / 15** reconstructed (15 missing) · Ivars: 5 · `instanceSize`=184
- Missing methods: `initWithData:` 0xcba44, `dealloc` 0xcc218, `viewDidLoad` 0xcc2ec, `handleGesture:` 0xcc31c, `didReceiveMemoryWarning` 0xcc388, `numberOfSectionsInTableView:` 0xcc3b4, `tableView:numberOfRowsInSection:` 0xcc3b8, `tableView:cellForRowAtIndexPath:` 0xcc3e0, `tableView:titleForHeaderInSection:` 0xcc588, `touchedBackButton:` 0xcc58c, `touchedChangeButton:` 0xcc664, `indexPathForControlEvent:` 0xcc7ac, `touchedSheetButton:event:` 0xcc82c, `delegate` 0xcca24, `setDelegate:` 0xcca34
- Ivars: `_acMusicDataArray:@"NSArray"@164`, `_genreButton:@"UIImage"@168`, `_titleButton:@"UIImage"@172`, `_changeButton:@"UIButton"@176`, `_delegate:@"<AcViewerViewControllerDelegate>"@180`

### `CustomWebView`  — ❌ missing

- Methods: **0 / 15** reconstructed (15 missing) · Ivars: 10 · `instanceSize`=116
- Missing methods: `setErrorMsg:text:` 0x5df50, `dealloc` 0x5df80, `initWithFrame:` 0x5dfe8, `initWithURL:` 0x5dfec, `pushCloseBtn` 0x5e6b8, `close` 0x5e6e8, `webViewDidStartLoad:` 0x5e808, `webViewDidFinishLoad:` 0x5e874, `webView:didFailLoadWithError:` 0x5eb04, `webView:shouldStartLoadWithRequest:navigationType:` 0x5ebb4, `observeValueForKeyPath:ofObject:change:context:` 0x5ec5c, `SetCloseCallback:param:` 0x5ed7c, `showErrorAlert` 0x5ed9c, `touchedFollowButton` 0x5ee38, `.cxx_construct` 0x5ef8c
- Ivars: `m_AlertViewCallback:^?@52`, `m_AlertViewCallbackParam:^v@56`, `_webView:@"UIWebView"@60`, `_closeBtnSmall:@"UIButton"@64`, `_closeBtnBig:@"UIButton"@68`, `_indicator:@"UIActivityIndicatorView"@72`, `_errorTitle:@"NSString"@76`, `_errorText:@"NSString"@80`, `webViewFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@84`, `smallBtnFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@100`

### `FriendRequestTable`  — ❌ missing

- Methods: **0 / 15** reconstructed (15 missing) · Ivars: 4 · `instanceSize`=180
- Missing methods: `initWithStyle:` 0xb7148, `dealloc` 0xb794c, `viewDidLoad` 0xb79e8, `didReceiveMemoryWarning` 0xb7a28, `reDownloadGetFriendRequest` 0xb7a54, `numberOfSectionsInTableView:` 0xb7b98, `tableView:numberOfRowsInSection:` 0xb7b9c, `tableView:cellForRowAtIndexPath:` 0xb7bc4, `tableView:titleForHeaderInSection:` 0xb7cd0, `tableView:didSelectRowAtIndexPath:` 0xb7cd4, `releaseSendDataArray` 0xb7cd8, `backButtonFunc` 0xb7d9c, `downloaderFinished:` 0xb7e38, `downloaderProceed:` 0xb84dc, `downloaderError:` 0xb84e0
- Ivars: `_dummyView:@"UIViewController"@164`, `_lonelyImageView:@"UIImageView"@168`, `dlGetFriendRequest:@"Downloader"@172`, `_sendDataArray:@"NSMutableArray"@176`

### `SettingTableSplitViewController`  — ❌ missing

- Methods: **0 / 15** reconstructed (15 missing) · Ivars: 7 · `instanceSize`=308
- Missing methods: `init` 0xb5cb0, `dealloc` 0xb6614, `viewDidLoad` 0xb6684, `didReceiveMemoryWarning` 0xb66b0, `startOpenAnimation` 0xb66dc, `endOpenAnimation` 0xb6808, `startCloseAnimation` 0xb6820, `endCloseAnimation` 0xb6928, `onGameButtonTouched:` 0xb6984, `onHowtoButtonTouched:` 0xb6998, `onCustomerButtonTouched:` 0xb69ac, `onOtherButtonTouched:` 0xb69c0, `startViewAnimation:` 0xb69d4, `handleTapCoverView` 0xb7100, `.cxx_construct` 0xb7144
- Ivars: `_isAnimationing:c@162`, `_leftViewCtrl:@"SettingTopViewController"@164`, `_rightViewCtrl:@"UINavigationController"@168`, `_arrowImageView:@"UIImageView"@172`, `_selectedIndex:i@176`, `_viewFrm:[4{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}]@180`, `_arrowFrm:[4{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}]@244`

### `FreeRequestListViewController`  — ❌ missing

- Methods: **0 / 14** reconstructed (14 missing) · Ivars: 4 · `instanceSize`=180
- Missing methods: `initWithStyle:` 0xe5430, `dealloc` 0xe5bb4, `viewDidLoad` 0xe5c5c, `didReceiveMemoryWarning` 0xe5ccc, `numberOfSectionsInTableView:` 0xe5cf8, `tableView:numberOfRowsInSection:` 0xe5cfc, `tableView:cellForRowAtIndexPath:` 0xe5d24, `tableView:titleForHeaderInSection:` 0xe5e3c, `tableView:didSelectRowAtIndexPath:` 0xe5e40, `releaseFriendList` 0xe60cc, `downloaderFinished:` 0xe61e0, `downloaderError:` 0xe6c80, `startGetRecommendFriendHttp` 0xe6d60, `backButtonFunc` 0xe6ea4
- Ivars: `_dummyView:@"UIViewController"@164`, `_frinedDataArray:@"NSArray"@168`, `_downloader:@"Downloader"@172`, `_freeRequestDetail:@"FreeRequestDetail"@176`

### `FriendMngTopSplitViewController`  — ❌ missing

- Methods: **0 / 14** reconstructed (14 missing) · Ivars: 13 · `instanceSize`=284
- Missing methods: `init` 0xc3358, `dealloc` 0xc3bbc, `viewDidLoad` 0xc3c2c, `didReceiveMemoryWarning` 0xc3c58, `viewWillAppear:` 0xc3c84, `startOpenAnimation` 0xc3d08, `endOpenAnimation` 0xc3e34, `startCloseAnimation` 0xc3f68, `endCloseAnimation` 0xc4070, `onListButtonTouched:` 0xc40d0, `onRequestButtonTouched:` 0xc4760, `onReplyButtonTouched:` 0xc4df0, `handleTapCoverView` 0xc53d0, `.cxx_construct` 0xc5414
- Ivars: `_isAnimationing:c@162`, `_markView:@"UIImageView"@164`, `_leftViewCtrl:@"FriendMngTopViewController"@168`, `_rightViewCtrl:@"UINavigationController"@172`, `_arrowImageView:@"UIImageView"@176`, `_selectedIndex:i@180`, `_listFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@184`, `_requestFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@200`, `_replyFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@216`, `_listArrowFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@232`, `_requestArrowFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@248`, `_replyArrowFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@264`, `_howToView:@"HowToViewCtrlPad"@280`

### `FriendRequestViewController`  — ❌ missing

- Methods: **0 / 14** reconstructed (14 missing) · Ivars: 4 · `instanceSize`=180
- Missing methods: `init` 0xb1c08, `dealloc` 0xb27bc, `viewDidLoad` 0xb28ac, `didReceiveMemoryWarning` 0xb2908, `textFieldShouldBeginEditing:` 0xb2934, `textFieldShouldReturn:` 0xb2938, `textField:shouldChangeCharactersInRange:replacementString:` 0xb2960, `touchedRequestButton:` 0xb29c8, `touchedFreeRequestButton:` 0xb2bb0, `downloaderFinished:` 0xb2ccc, `downloaderError:` 0xb2ecc, `downloadMainFinished:` 0xb2f98, `startFriendRequestHttp:` 0xb303c, `backButtonFunc` 0xb317c
- Ivars: `_playerIdField:@"UITextField"@164`, `_indicator:@"UIActivityIndicatorView"@168`, `_requestTable:@"FriendRequestTable"@172`, `_downloader:@"Downloader"@176`

### `PopnLinkTopSplitViewController`  — ❌ missing

- Methods: **0 / 14** reconstructed (14 missing) · Ivars: 12 · `instanceSize`=280
- Missing methods: `init` 0xe0b40, `dealloc` 0xe1430, `viewDidLoad` 0xe14e0, `didReceiveMemoryWarning` 0xe150c, `startOpenAnimation` 0xe1538, `endOpenAnimation` 0xe1840, `startCloseAnimation` 0xe1858, `endCloseAnimation` 0xe1960, `onInKidButtonTouched:` 0xe19c0, `onScoreCheckerButtonTouched:` 0xe1fa8, `onQuizButtonTouched:` 0xe25b0, `reloadLeftView` 0xe2bb8, `handleTapCoverView` 0xe2bf4, `.cxx_construct` 0xe2c38
- Ivars: `_isAnimationing:c@162`, `_leftViewCtrl:@"PopnLinkTopViewController"@164`, `_rightViewCtrl:@"UINavigationController"@168`, `_konamiIdArrowImageView:@"UIImageView"@172`, `_selectedIndex:i@176`, `_konamiIdFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@180`, `_checkerFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@196`, `_quizFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@212`, `_konamiIdArrowFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@228`, `_checkerArrowFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@244`, `_quizArrowFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@260`, `_howToView:@"HowToViewCtrlPad"@276`

### `SettingTopViewController`  — ❌ missing

- Methods: **0 / 14** reconstructed (14 missing) · Ivars: 2 · `instanceSize`=168
- Missing methods: `init` 0x13fe8, `initAtNavigationController` 0x14464, `viewDidLoad` 0x1463c, `didReceiveMemoryWarning` 0x14668, `startOpenAnimation` 0x14694, `endOpenAnimation` 0x147c0, `startCloseAnimation` 0x147d8, `endCloseAnimation` 0x148f8, `onGameButtonTouched:` 0x14964, `onHowtoButtonTouched:` 0x14a90, `onCustomerButtonTouched:` 0x14ae0, `onOtherButtonTouched:` 0x14b30, `settingTopDelegate` 0x14b80, `setSettingTopDelegate:` 0x14b90
- Ivars: `_isAnimationing:c@162`, `_settingTopDelegate:@"<SettingTopViewControllerDalegate>"@164`

### `InputKidViewController`  — ❌ missing

- Methods: **0 / 12** reconstructed (12 missing) · Ivars: 3 · `instanceSize`=176
- Missing methods: `init` 0xe7cec, `viewDidLoad` 0xe84ec, `didReceiveMemoryWarning` 0xe8518, `textFieldShouldBeginEditing:` 0xe8544, `textFieldShouldReturn:` 0xe8548, `textField:shouldChangeCharactersInRange:replacementString:` 0xe8570, `touchedDecideButton:` 0xe85d8, `touchedBackButton` 0xe87fc, `downloaderFinished:` 0xe8840, `downloaderError:` 0xe8a5c, `commonAlertView:clickedButtonAtIndex:` 0xe8b28, `startInviteHttp:` 0xe8b5c
- Ivars: `_codeField:@"UITextField"@164`, `_indicator:@"UIActivityIndicatorView"@168`, `_downloader:@"Downloader"@172`

### `TouchRangeViewCtrl`  — ❌ missing

- Methods: **0 / 12** reconstructed (12 missing) · Ivars: 6 · `instanceSize`=192
- Missing methods: `viewDidLoad` 0x8a360, `didReceiveMemoryWarning` 0x8a9d0, `viewWillDisappear:` 0x8a9fc, `sliderValChanged:` 0x8aa9c, `touchedResetButton:` 0x8aad0, `isEnablePoint:` 0x8ab04, `touchesBegan:withEvent:` 0x8abd0, `touchesMoved:withEvent:` 0x8ad0c, `touchesEnded:withEvent:` 0x8af28, `touchesCancelled:withEvent:` 0x8b15c, `backButtonFunc` 0x8b16c, `.cxx_construct` 0x8b208
- Ivars: `_infoView:@"UIImageView"@164`, `_radiusSlider:@"UISlider"@168`, `_resetButton:@"UIButton"@172`, `_toucheRangeView:@"TouchRangeView"@176`, `_touchedPoint:{CGPoint="x"f"y"f}@180`, `_radius:f@188`

### `CommunicatingView`  — ❌ missing

- Methods: **0 / 11** reconstructed (11 missing) · Ivars: 5 · `instanceSize`=178
- Missing methods: `init` 0xde740, `viewDidLoad` 0xdec30, `didReceiveMemoryWarning` 0xdec5c, `dealloc` 0xdec88, `failed` 0xdecb4, `startOpenAnimation` 0xded10, `endOpenAnimation` 0xdee00, `startCloseAnimation` 0xdee48, `endCloseAnimation` 0xdef48, `touchesBegan:withEvent:` 0xdef94, `isAnimationing` 0xdefd8
- Ivars: `communicatingView:@"UIImageView"@164`, `communicateFailedView:@"UIImageView"@168`, `indicatorView:@"UIActivityIndicatorView"@172`, `_isAnimationing:c@176`, `_isCloseReserve:c@177`

### `GameEffectView`  — ❌ missing

- Methods: **0 / 11** reconstructed (11 missing) · Ivars: 0 · `instanceSize`=162
- Missing methods: `initWithStyle:` 0x72d4c, `dealloc` 0x72eb0, `viewDidLoad` 0x72edc, `didReceiveMemoryWarning` 0x730f4, `numberOfSectionsInTableView:` 0x73120, `tableView:numberOfRowsInSection:` 0x73124, `tableView:cellForRowAtIndexPath:` 0x73128, `tableView:didSelectRowAtIndexPath:` 0x73518, `tableView:viewForHeaderInSection:` 0x735dc, `tableView:heightForHeaderInSection:` 0x737b0, `backButtonFunc` 0x737d8

### `PolicyView`  — ❌ missing

- Methods: **0 / 11** reconstructed (11 missing) · Ivars: 1 · `instanceSize`=168
- Missing methods: `init` 0x52a04, `viewDidLoad` 0x52a8c, `didReceiveMemoryWarning` 0x52eec, `viewDidUnload` 0x52f18, `viewWillAppear:` 0x52f44, `viewDidAppear:` 0x52fac, `viewWillDisappear:` 0x52fd8, `viewDidDisappear:` 0x53004, `shouldAutorotateToInterfaceOrientation:` 0x53030, `backButtonFunc` 0x5303c, `layoutManager:lineSpacingAfterGlyphAtIndex:withProposedLineFragmentRect:` 0x53134
- Ivars: `_textView:@"UITextView"@164`

### `RandomLoginBonusView`  — ❌ missing

- Methods: **0 / 11** reconstructed (11 missing) · Ivars: 9 · `instanceSize`=104
- Missing methods: `getBonus` 0x18a38, `initWithCoder:` 0x18a90, `initWithFrame:` 0x18aa0, `init` 0x18ab0, `dealloc` 0x19884, `show` 0x19960, `touchEvent:` 0x19b9c, `startCloseAnimation` 0x1a448, `endCloseAnimation` 0x1a508, `showAlertView` 0x1a558, `customAlertView:clickedButtonAtIndex:` 0x1a650
- Ivars: `_bonus:i@52`, `_numImgView1000:@"UIImageView"@56`, `_numImgView0100:@"UIImageView"@60`, `_numImgView0010:@"UIImageView"@64`, `_numImgView0001:@"UIImageView"@68`, `_seRscId:[3i]@72`, `_seInstId:[3i]@84`, `_isAnimationing:c@96`, `_state:i@100`

### `StoreDialogView`  — ❌ missing

- Methods: **0 / 11** reconstructed (11 missing) · Ivars: 5 · `instanceSize`=72
- Missing methods: `initWithFrame:` 0x416dc, `initWithFrame:abortable:` 0x41708, `dealloc` 0x41dc0, `layout:` 0x41e4c, `btnAbort:` 0x41f38, `delegate` 0x41f8c, `setDelegate:` 0x41f9c, `indicatorView` 0x41fac, `labelMessage` 0x41fbc, `progressView` 0x41fcc, `buttonAbort` 0x41fdc
- Ivars: `m_IndicatorView:@"UIActivityIndicatorView"@52`, `m_LabelMessage:@"UILabel"@56`, `m_ProgressView:@"UIProgressView"@60`, `m_ButtonAbort:@"UIButton"@64`, `delegate:@@68`

### `AcViewerHiSpeedViewController`  — ❌ missing

- Methods: **0 / 10** reconstructed (10 missing) · Ivars: 0 · `instanceSize`=162
- Missing methods: `init` 0x2cbb0, `viewDidLoad` 0x2d484, `handleGesture:` 0x2d4b4, `numberOfSectionsInTableView:` 0x2d520, `tableView:numberOfRowsInSection:` 0x2d524, `tableView:cellForRowAtIndexPath:` 0x2d530, `tableView:titleForHeaderInSection:` 0x2d660, `tableView:accessoryTypeForRowWithIndexPath:` 0x2d664, `tableView:didSelectRowAtIndexPath:` 0x2d668, `touchedBackButton:` 0x2d738

### `AcceptPolicyViewController`  — ❌ missing

- Methods: **0 / 10** reconstructed (10 missing) · Ivars: 5 · `instanceSize`=180
- Missing methods: `init` 0xaf848, `dealloc` 0xb02bc, `onYesBtn:` 0xb032c, `onNoBtn:` 0xb037c, `onDetailBtn:` 0xb03ac, `onBackBtn:` 0xb04e4, `startOpenAnimation` 0xb0540, `endOpenAnimation` 0xb0630, `startCloseAnimation` 0xb0648, `endCloseAnimation` 0xb0718
- Ivars: `isAnimationing:c@162`, `_topView:@"UIView"@164`, `_detailView:@"UIImageView"@168`, `_policyView:@"UINavigationController"@172`, `_naviCtrl:@"UINavigationController"@176`

### `CheckerMusicViewController`  — ❌ missing

- Methods: **0 / 10** reconstructed (10 missing) · Ivars: 1 · `instanceSize`=168
- Missing methods: `initWithScoreData:category:` 0xd27b8, `dealloc` 0xd2e20, `viewDidLoad` 0xd2e98, `didReceiveMemoryWarning` 0xd2ec4, `numberOfSectionsInTableView:` 0xd2ef0, `tableView:numberOfRowsInSection:` 0xd2ef4, `tableView:cellForRowAtIndexPath:` 0xd2f1c, `tableView:titleForHeaderInSection:` 0xd3028, `tableView:didSelectRowAtIndexPath:` 0xd3030, `touchedBackButton:` 0xd3254
- Ivars: `_scoreDataArray:@"NSArray"@164`

### `HttpConn`  — ❌ missing

- Methods: **0 / 10** reconstructed (10 missing) · Ivars: 6 · `instanceSize`=28
- Missing methods: `init` 0x6a550, `get:` 0x6a58c, `post:paramString:` 0x6a6c4, `connection:didReceiveResponse:` 0x6a8c0, `connection:didReceiveData:` 0x6a978, `connection:didFailWithError:` 0x6a9c8, `connectionDidFinishLoading:` 0x6aa38, `receivedString` 0x6ab60, `status` 0x6ab74, `setStatus:` 0x6ab88
- Ivars: `receivedData:@"NSMutableData"@4`, `receivedString:@"NSString"@8`, `encoding:I@12`, `conn:@"NSURLConnection"@16`, `statusCode:i@20`, `status:i@24`

### `PopkunSizeViewCtrl`  — ❌ missing

- Methods: **0 / 10** reconstructed (10 missing) · Ivars: 12 · `instanceSize`=224
- Missing methods: `viewDidLoad` 0x8b44c, `didReceiveMemoryWarning` 0x8c1a4, `viewWillDisappear:` 0x8c1d0, `dealloc` 0x8c1fc, `sliderValChanged:` 0x8c228, `sliderValDecide:` 0x8c270, `touchedResetButton:` 0x8c29c, `backButtonFunc` 0x8c30c, `resizePopkun` 0x8c3a8, `.cxx_construct` 0x8c620
- Ivars: `_infoView:@"UIImageView"@164`, `_popkun:@"UIImageView"@168`, `_sizeSlider:@"UISlider"@172`, `_resetButton:@"UIButton"@176`, `_sizeLbl:@"UILabel"@180`, `_size:f@184`, `_orgFrame:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@188`, `offsetYForPad1:i@204`, `offsetYForPad2:i@208`, `offsetYForPad3:i@212`, `offsetYForPad4:i@216`, `_hoge:@"CustomAlertView"@220`

### `AcViewerHidSudViewController`  — ❌ missing

- Methods: **0 / 9** reconstructed (9 missing) · Ivars: 0 · `instanceSize`=162
- Missing methods: `init` 0x1adf4, `viewDidLoad` 0x1b6c8, `numberOfSectionsInTableView:` 0x1b6f8, `tableView:numberOfRowsInSection:` 0x1b6fc, `tableView:cellForRowAtIndexPath:` 0x1b708, `tableView:titleForHeaderInSection:` 0x1b838, `tableView:accessoryTypeForRowWithIndexPath:` 0x1b83c, `tableView:didSelectRowAtIndexPath:` 0x1b840, `touchedBackButton:` 0x1b910

### `AcViewerPopKunViewController`  — ❌ missing

- Methods: **0 / 9** reconstructed (9 missing) · Ivars: 0 · `instanceSize`=162
- Missing methods: `init` 0x7d01c, `viewDidLoad` 0x7d8f0, `numberOfSectionsInTableView:` 0x7d920, `tableView:numberOfRowsInSection:` 0x7d924, `tableView:cellForRowAtIndexPath:` 0x7d930, `tableView:titleForHeaderInSection:` 0x7da60, `tableView:accessoryTypeForRowWithIndexPath:` 0x7da64, `tableView:didSelectRowAtIndexPath:` 0x7da68, `touchedBackButton:` 0x7db38

### `AcViewerRanMirViewController`  — ❌ missing

- Methods: **0 / 9** reconstructed (9 missing) · Ivars: 0 · `instanceSize`=162
- Missing methods: `init` 0xa6c20, `viewDidLoad` 0xa74f4, `numberOfSectionsInTableView:` 0xa7520, `tableView:numberOfRowsInSection:` 0xa7524, `tableView:cellForRowAtIndexPath:` 0xa7530, `tableView:titleForHeaderInSection:` 0xa7660, `tableView:accessoryTypeForRowWithIndexPath:` 0xa7664, `tableView:didSelectRowAtIndexPath:` 0xa7668, `touchedBackButton:` 0xa7738

### `CustomSplitViewController`  — ❌ missing

- Methods: **0 / 9** reconstructed (9 missing) · Ivars: 3 · `instanceSize`=176
- Missing methods: `initWithFrame:leftViewWidth:leftViewController:rightView:` 0x5dbc0, `initWithLeftViewWidth:leftViewController:rightView:` 0x5dde0, `dealloc` 0x5de28, `viewDidLoad` 0x5dea0, `didReceiveMemoryWarning` 0x5decc, `leftViewCtrl` 0x5def8, `setLeftViewCtrl:` 0x5df0c, `rightViewCtrl` 0x5df24, `setRightViewCtrl:` 0x5df38
- Ivars: `m_leftViewCtrl:@"UIViewController"@164`, `m_rightViewCtrl:@"UIViewController"@168`, `m_leftViewWidth:i@172`

### `DevDataDownloader`  — ❌ missing

- Methods: **0 / 9** reconstructed (9 missing) · Ivars: 6 · `instanceSize`=25
- Missing methods: `dealloc` 0x8e8ec, `startDownload:file:` 0x8e984, `downloaderFinished:` 0x8eb1c, `downloaderProceed:` 0x8ed78, `downloaderError:` 0x8ed7c, `delegate` 0x8ee00, `setDelegate:` 0x8ee10, `isOld` 0x8ee20, `setIsOld:` 0x8ee38
- Ivars: `m_Downloader:@"Downloader"@4`, `m_Title:@"NSString"@8`, `m_FileName:@"NSString"@12`, `m_IsOld:c@16`, `m_Delegate:@"<DevDataDownloaderDelegate>"@20`, `isAcv:c@24`

### `LoginBonusView`  — ❌ missing

- Methods: **0 / 9** reconstructed (9 missing) · Ivars: 3 · `instanceSize`=61
- Missing methods: `initWithCoder:` 0x7bfc8, `initWithFrame:` 0x7bfd8, `init` 0x7bfe8, `dealloc` 0x7c540, `getReward` 0x7c594, `show` 0x7c728, `touchEvent:` 0x7c8e0, `showAlertView` 0x7cc68, `customAlertView:clickedButtonAtIndex:` 0x7ce50
- Ivars: `m_BgImgView:@"UIImageView"@52`, `m_OldLoginCnt:i@56`, `m_IsTouch:c@60`

### `InviteTopViewController`  — ❌ missing

- Methods: **0 / 8** reconstructed (8 missing) · Ivars: 1 · `instanceSize`=163
- Missing methods: `initAtNavigationController` 0xe6f88, `touchedInviteButton:` 0xe7860, `touchedInputButton:` 0xe7914, `touchedBackButton` 0xe79c8, `startOpenAnimation` 0xe7a38, `endOpenAnimation` 0xe7b70, `startCloseAnimation` 0xe7b88, `endCloseAnimation` 0xe7c90
- Ivars: `isAnimationing:c@162`

### `MapAnnotation`  — ❌ missing

- Methods: **0 / 8** reconstructed (8 missing) · Ivars: 4 · `instanceSize`=32
- Missing methods: `initWithCoordinate:Title:SubTitle:Model:` 0x850e4, `dealloc` 0x851c8, `setCoordinate:` 0x85264, `modelName` 0x85288, `.cxx_construct` 0x852d8, `coordinate` 0x85298, `title` 0x852b0, `subtitle` 0x852c4
- Ivars: `m_Coordinate:{?="latitude"d"longitude"d}@4`, `m_Title:@"NSString"@20`, `m_SubTitle:@"NSString"@24`, `m_ModelName:@"NSString"@28`

### `CheckerDetail`  — ❌ missing

- Methods: **0 / 7** reconstructed (7 missing) · Ivars: 15 · `instanceSize`=368
- Missing methods: `convertGrayScaleImage:` 0xd7418, `initWithScoreData:` 0xd752c, `deallc` 0xd9620, `viewDidLoad` 0xd964c, `touchedBackButton:` 0xd9678, `touchedSheetButton:` 0xd97c4, `touchesBegan:withEvent:` 0xd9aac
- Ivars: `_arcadeScoreData:@"ArcadeScoreData"@164`, `_selectedSheet:i@168`, `_isNameMode:B@172`, `_scoreLineOff:[4@"UIImageView"]@176`, `_scoreLineOn:[4@"UIImageView"]@192`, `_topIconOff:[4@"UIImageView"]@208`, `_topIconOn:[4@"UIImageView"]@224`, `_meanIconOff:[4@"UIImageView"]@240`, `_meanIconOn:[4@"UIImageView"]@256`, `_myIconOff:[4@"UIImageView"]@272`, `_myIconOn:[4@"UIImageView"]@288`, `_topScoreBase:[4@"UIImageView"]@304`, `_topNameBase:[4@"UIImageView"]@320`, `_meanBase:[4@"UIImageView"]@336`, `_myBase:[4@"UIImageView"]@352`

### `DownloadImageView`  — ❌ missing

- Methods: **0 / 7** reconstructed (7 missing) · Ivars: 3 · `instanceSize`=68
- Missing methods: `initWithURLString:` 0x62be8, `initWithURLString:withImage:` 0x62c5c, `dealloc` 0x62cd0, `SetupView` 0x62d30, `startDownload` 0x62e24, `imageDownloader:didLoad:` 0x62ef0, `imageDownloaderDidFail:didLoad:` 0x62f60
- Ivars: `m_ImageURL:@"NSString"@56`, `m_ImageDownLoader:@"ImageDownloader"@60`, `m_IndicatorView:@"UIActivityIndicatorView"@64`

### `DownloadProgresView`  — ❌ missing

- Methods: **0 / 7** reconstructed (7 missing) · Ivars: 4 · `instanceSize`=80
- Missing methods: `initWithFrame:` 0xde1d0, `dealloc` 0xde630, `layout:` 0xde65c, `.cxx_construct` 0xde738, `indicatorView` 0xde708, `labelMessage` 0xde718, `progressView` 0xde728
- Ivars: `_indicatorView:@"UIActivityIndicatorView"@52`, `_labelMessage:@"UILabel"@56`, `_progressView:@"UIProgressView"@60`, `_dialogFrame:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@64`

### `TouchRangeView`  — ❌ missing

- Methods: **0 / 7** reconstructed (7 missing) · Ivars: 3 · `instanceSize`=61
- Missing methods: `initWithFilename:touched:` 0x8b20c, `dealloc` 0x8b2c0, `drawRect:` 0x8b324, `getImageWidth` 0x8b364, `getImageHeight` 0x8b3a4, `isTouched` 0x8b3e4, `setIsTouched:` 0x8b3fc
- Ivars: `_untouchedPopkun:@"UIImage"@52`, `_touchedPopkun:@"UIImage"@56`, `_isTouched:c@60`

### `MyInviteCodeViewController`  — ❌ missing

- Methods: **0 / 4** reconstructed (4 missing) · Ivars: 0 · `instanceSize`=162
- Missing methods: `init` 0xe8c98, `viewDidLoad` 0xe9194, `didReceiveMemoryWarning` 0xe91c0, `touchedBackButton` 0xe91ec

### `PurchaseStore`  — ❌ missing

- Methods: **0 / 4** reconstructed (4 missing) · Ivars: 1 · `instanceSize`=5
- Missing methods: `purchaseSucceeded:` 0x838d4, `purchaseFailed:error:` 0x83928, `nowPurchasing` 0x8393c, `setNowPurchasing:` 0x83954
- Ivars: `nowPurchasing:B@4`

### `AcViewerCategoryCell`  — ❌ missing

- Methods: **0 / 3** reconstructed (3 missing) · Ivars: 0 · `instanceSize`=52
- Missing methods: `initWithStyle:reuseIdentifier:` 0x1a804, `dealloc` 0x1a84c, `setData:` 0x1a878

### `CheckerMusicCell`  — ❌ missing

- Methods: **0 / 3** reconstructed (3 missing) · Ivars: 10 · `instanceSize`=92
- Missing methods: `initWithStyle:reuseIdentifier:` 0xd1d28, `dealloc` 0xd1ea0, `setData:` 0xd1ecc
- Ivars: `_scoreData:@"ArcadeScoreData"@52`, `_bgImg:@"UIImageView"@56`, `_dateLbl:@"UILabel"@60`, `_titleLbl:@"UILabel"@64`, `_genreLbl:@"UILabel"@68`, `isOS7:B@72`, `bgX:i@76`, `dateX:i@80`, `titleX:i@84`, `genreX:i@88`

### `DelayImageView`  — ❌ missing

- Methods: **0 / 3** reconstructed (3 missing) · Ivars: 1 · `instanceSize`=56
- Missing methods: `threadFunc` 0x88c8, `image` 0x8980, `setImage:` 0x8990
- Ivars: `image:@"UIImage"@52`

### `FreeRequestListCell`  — ❌ missing

- Methods: **0 / 3** reconstructed (3 missing) · Ivars: 11 · `instanceSize`=96
- Missing methods: `initWithStyle:reuseIdentifier:` 0xe49c4, `dealloc` 0xe4b34, `setFriendData:rank:` 0xe4b60
- Ivars: `_bgImgView:@"UIImageView"@52`, `_charaBgImgView:@"UIImageView"@56`, `_charaImgView:@"UIImageView"@60`, `_playerNameLbl:@"UILabel"@64`, `_scoreBaseImgView:@"UIImageView"@68`, `_scoreLbl:@"UILabel"@72`, `isOS7:B@76`, `imgCharaX:i@80`, `imgPlayerNameX:i@84`, `imgScoreBaseX:i@88`, `imgScoreX:i@92`

### `QuizCell`  — ❌ missing

- Methods: **0 / 3** reconstructed (3 missing) · Ivars: 2 · `instanceSize`=60
- Missing methods: `initWithStyle:reuseIdentifier:` 0xd9bac, `dealloc` 0xd9bf4, `setData:answerId:rightId:selectId:` 0xd9c20
- Ivars: `_answerId:i@52`, `_answerIdView:@"UIImageView"@56`

### `TouchableTableView`  — ❌ missing

- Methods: **0 / 3** reconstructed (3 missing) · Ivars: 0 · `instanceSize`=56
- Missing methods: `initWithFrame:` 0xe96ec, `dealloc` 0xe9724, `touchesBegan:withEvent:` 0xe9750

### `TouchableScrollView`  — ❌ missing

- Methods: **0 / 2** reconstructed (2 missing) · Ivars: 0 · `instanceSize`=56
- Missing methods: `initWithFrame:` 0xe30dc, `touchesBegan:withEvent:` 0xe3114

### `neWindow`  — ❌ missing

- Methods: **0 / 1** reconstructed (1 missing) · Ivars: 0 · `instanceSize`=144
- Missing methods: `initWithFrame:` 0x28a00

### `ViewUtility`  — ❌ missing

- Methods: **0 / 0** reconstructed (0 missing) · Ivars: 0 · `instanceSize`=4

### `DownloadMain`  — 🟡 partial

- Methods: **25 / 119** reconstructed (94 missing) · Ivars: 63 · `instanceSize`=252
- Missing methods: `dealloc` 0x93ec0, `startPlayerGetHttp` 0x93f14, `isPlayerGetDownLoading` 0x94060, `getPlayerGetProgressSec` 0x94078, `playerGetFinished` 0x940c4, `startNewsHttp` 0x94488, `isNewsDownLoading` 0x9458c, `releaseInformationData` 0x945a4, `newsGetFinished` 0x946b8, `startSaveScoreHttp:sheet:score:medal:charaId:` 0x952d4, `saveScoreFinished` 0x95434, `isGetBlockListDownLoading` 0x96710, `isDelBlockListDownLoading` 0x96ae4, `delBlockListFinished` 0x96afc, `startGetRecommendListHttp` 0x96b54, `isGetRecommendListDownLoading` 0x96c68, `releaseRecommendData` 0x96c80, `compareToUpdateDate:` 0x96db0, `getRecommendListFinished` 0x96df0, `startGetVisitorHttp:type:` 0x972e4, `isGetVisitorDownLoading` 0x97410, `getVisitorFinished` 0x97428, `isSaveTreasureDownLoading` 0x97894, `releaseFileListData` 0x979f0, `startGetPresentListHttp` 0x97d60, `isGetPresentListDownLoading` 0x97e74, `releasePresentList` 0x97e8c, `getPresentListFinished` 0x97f90, `startGetPresentHttp:` 0x9829c, `isGetPresentDownLoading` 0x983c0, `getPresentFinished` 0x983d8, `startGetOverScoreLogHttp` 0x984b4, `isGetOverScoreLogDownLoading` 0x985c8, `releaseOverScoreLogArray` 0x985e0, `getOverScoreLogFinished` 0x98700, `startGetEventInfoHttp` 0x98a6c, `isGetEventInfoDownLoading` 0x98b7c, `getEventInfoFinished` 0x98b94, `downloaderFinished:` 0x98f78, `downloaderProceed:` 0x9918c, `downloaderError:` 0x99190, `cppDelegateNews` 0x995ac, `setCppDelegateNews:` 0x995c0, `cppDelegateRecommendList` 0x995d8, `setCppDelegateRecommendList:` 0x995ec, `setDelegateGetFriendList:` 0x99618, `setDelegateCancelFriend:` 0x99644, `delegateGetVisitor` 0x9965c, `setDelegateGetVisitor:` 0x99670, `delegateGetPresentList` 0x99688, `setDelegateGetPresentList:` 0x9969c, `delegateGetPresent` 0x996b4, `setDelegateGetPresent:` 0x996c8, `delegateGetEventInfo` 0x996e0, `setDelegateGetEventInfo:` 0x996f4, `informationDataArray` 0x9970c, `arcadePt` 0x99720, `errorGetPlayer` 0x99760, `loginBonusId` 0x99774, `loginCnt` 0x99788, `isLoginCntUpdate` 0x9979c, `setIsLoginCntUpdate:` 0x997b4, `newsTextArray` 0x997cc, `newsUrlArray` 0x997e0, `lastGetNewsTime` 0x997f4, `serverYear` 0x99808, `serverMonth` 0x9981c, `serverDay` 0x99830, `serverHour` 0x99844, `serverMinute` 0x99858, `serverSecond` 0x9986c, `isNewMusicPackReleased` 0x99880, `setIsNewMusicPackReleased:` 0x99898, `frSendPlayerIdArray` 0x998b0, `frSendNameArray` 0x998c4, `frReceivePlayerIdArray` 0x998d8, `frReceiveNameArray` 0x998ec, `frReceiveMessageArray` 0x99900, `presentDataArray` 0x99928, `getPresentId` 0x9993c, `setGetPresentId:` 0x99950, `overScoreLogArray` 0x99968, `blNameArray` 0x99990, `isGetVisitorSuccess` 0x999a4, `setIsGetVisitorSuccess:` 0x999bc, `recommendDataArray` 0x999d4, `treasureEventIdArray` 0x999fc, `gameEventIdArray` 0x99a10, `isTreasureEventInfoUpdated` 0x99a24, `setIsTreasureEventInfoUpdated:` 0x99a3c, `isGameEventInfoUpdated` 0x99a54, `setIsGameEventInfoUpdated:` 0x99a6c, `delegateGetOverScoreLog` 0x99a84, `setDelegateGetOverScoreLog:` 0x99a98
- Ivars: `dlGetPlayer:@"Downloader"@4`, `_arcadePt:i@8`, `_friendRequestedCnt:i@12`, `_errorGetPlayer:i@16`, `_loginBonusId:i@20`, `_loginCnt:i@24`, `_isLoginCntUpdate:c@28`, `dlNews:@"Downloader"@32`, `_cppDelegateNews:^{ModeSelTask=^^?^{C_TASK}^{C_TASK}i^{C_TASK}^{C_TASK}^{C_TASK}^{C_TASK}*B{WorkStruct=[3^{AepLyrCtrl}][1i][5i][1^{AepTexture}][6i][6i]^{C_TASK}iiiiiiiiiiiiBBBBB@@@@iiiiiiBiii{RECT_GCU=iiii}iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii}iB}@36`, `_lastNewsGetTime:@"NSDate"@40`, `_storeUpdateTime:@"NSString"@44`, `_newsTextArray:@"NSArray"@48`, `_newsUrlArray:@"NSArray"@52`, `_informationDataArray:@"NSArray"@56`, `_serverYear:i@60`, `_serverMonth:i@64`, `_serverDay:i@68`, `_serverHour:i@72`, `_serverMinute:i@76`, `_serverSecond:i@80`, `_isNewMusicPackReleased:c@84`, `dlSaveScore:@"Downloader"@88`, `_saveMusic:I@92`, `_saveSheet:s@96`, `dlCancelFriend:@"Downloader"@100`, `_delegateCancelFriend:@"<DownloadMainDelegate>"@104`, `dlGetFriendList:@"Downloader"@108`, `_delegateGetFriendList:@"<DownloadMainDelegate>"@112`, `_friendListArray:@"NSArray"@116`, `dlAddBlockList:@"Downloader"@120`, `dlGetBlockList:@"Downloader"@124`, `_blPlayerIdArray:@"NSArray"@128`, `_blNameArray:@"NSArray"@132`, `dlDelBlockList:@"Downloader"@136`, `dlGetRecommendList:@"Downloader"@140`, `_cppDelegateRecommendList:^{MusicSelTask=^^?^{C_TASK}^{C_TASK}i^{C_TASK}^{C_TASK}^{C_TASK}^{C_TASK}*B{WorkStruct=^{AepManager}@@[4^{AepLyrCtrl}][2^{AepLyrCtrl}][2^{AepTexture}]^{AepTexture}^{AepTexture}[10^{AepTexture}][10^{AepTexture}][10^{AepTexture}][3[10^{AepTexture}]][3i][3i][3i][3i][24i][3i][7i][7i][3i][22i][6i][3i][3[3i]][3i][27{JacketStruct=ii@^{AepTexture}{MusicInfoStruct=@[3i][3i][3s][3B][3B]}}][3c][5i][5i]iiiiiii[3i][3B][3B]BBBBBBBBBBBBi[10I][10i]fiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiifiiiiBiii@i@i^{C_TASK}}i}@144`, `_recommendDataArray:@"NSArray"@148`, `dlGetVisitor:@"Downloader"@152`, `_delegateGetVisitor:@"<DownloadMainDelegate>"@156`, `_isGetVisitorSuccess:c@160`, `dlGetPresentList:@"Downloader"@164`, `_delegateGetPresentList:@"<DownloadMainDelegate>"@168`, `_presentDataArray:@"NSArray"@172`, `dlGetPresent:@"Downloader"@176`, `_delegateGetPresent:@"<DownloadMainDelegate>"@180`, `_getPresentId:i@184`, `dlGetOverScoreLog:@"Downloader"@188`, `_delegateGetOverScoreLog:@"<DownloadMainDelegate>"@192`, `_overScoreLogArray:@"NSArray"@196`, `dlSaveTreasure:@"Downloader"@200`, `dlGetDlFileList:@"Downloader"@204`, `_dlFileListDataArray:@"NSArray"@208`, `dlGetEventInfo:@"Downloader"@212`, `_delegateGetEventInfo:@"<DownloadMainDelegate>"@216`, `_treasureEventIdArray:@"NSArray"@220`, `_gameEventIdArray:@"NSArray"@224`, `_isTreasureEventInfoUpdated:c@228`, `_isGameEventInfoUpdated:c@229`, `_frSendPlayerIdArray:@"NSArray"@232`, `_frSendNameArray:@"NSArray"@236`, `_frReceivePlayerIdArray:@"NSArray"@240`, `_frReceiveNameArray:@"NSArray"@244`, `_frReceiveMessageArray:@"NSArray"@248`

### `StoreMainViewController`  — 🟡 partial

- Methods: **10 / 64** reconstructed (54 missing) · Ivars: 25 · `instanceSize`=252
- Missing methods: `showError:` 0x44864, `pushBarBtnRestore:` 0x44904, `packListDownloadError:errorMessage:` 0x45108, `packListDownloadNothing:` 0x45258, `openDetailAnimStop:finished:context:` 0x45510, `storePromotionViewTaped:PackID:` 0x45648, `openDetailAnimStopFromPromotion:finished:context:` 0x45898, `closeDetailAnimStop:finished:context:` 0x45a80, `startDownloadPackMusics:` 0x45b48, `detailViewStartPurchase:` 0x46270, `detailViewClose` 0x46420, `storeDialogCancel:` 0x46470, `connectionDidFinishLoading:` 0x46584, `connection:didFailWithError:` 0x46588, `updateMusicInfo:Save:` 0x4658c, `updatePurchasedTableCell:` 0x46798, `reDownloadPackMusics:` 0x46a7c, `purchaseSucceeded:` 0x46ab0, `purchaseFailed:error:` 0x46d1c, `addRestorePackInfo:` 0x46e58, `nextRestorePackInfo` 0x46ef4, `askDownloadAllMusics` 0x47134, `restoreDownloadAllMusics` 0x4753c, `commonAlertView:clickedButtonAtIndex:` 0x47a04, `restoreSucceeded` 0x47c14, `restoreFailed:` 0x47d50, `restoreNothing` 0x47e40, `storePackInfoDownloaderFinished:` 0x47e60, `storePackInfoDownloaderError:` 0x47ef4, `downloadManagerStartTask:` 0x47f38, `downloadManagerCompleted:` 0x47ffc, `downloadManagerFailed:` 0x48108, `downloadManagerProceed:` 0x482c0, `numPackRows` 0x4832c, `tableView:cellForRowAtIndexPath:` 0x4837c, `numberOfSectionsInTableView:` 0x48fc0, `tableView:numberOfRowsInSection:` 0x48fd8, `tableView:heightForRowAtIndexPath:` 0x49038, `tableView:willDisplayCell:forRowAtIndexPath:` 0x4912c, `tableView:didSelectRowAtIndexPath:` 0x49258, `imageDownloader:didLoad:` 0x495e4, `imageDownloaderDidFail:didLoad:` 0x49750, `scrollViewDidScroll:` 0x49754, `scrollViewWillBeginDragging:` 0x49b64, `scrollViewDidEndDragging:willDecelerate:` 0x49b68, `stopDownloadArtworks` 0x49b6c, `viewWillAppear:` 0x49c84, `viewDidAppear:` 0x49d64, `viewWillDisappear:` 0x49e88, `viewDidDisappear:` 0x49fe4, `shouldAutorotateToInterfaceOrientation:` 0x4a010, `willRotateToInterfaceOrientation:duration:` 0x4a014, `didReceiveMemoryWarning` 0x4a018, `dealloc` 0x4a044
- Ivars: `m_StoreViewCtrl:@"StoreViewController"@164`, `m_PackListCtrl:@"StorePackListController"@168`, `m_ArtworkDownloaders:@"NSMutableDictionary"@172`, `m_DownloadManager:@"StoreDownloadManager"@176`, `m_PurchasingPackInfo:@"StorePackInfo"@180`, `m_PromotionView:@"StorePromotionView"@184`, `m_PromotionViewDummy:@"UIImageView"@188`, `m_PackTableLabel:@"UILabel"@192`, `m_ShowMoreButton:@"UIButton"@196`, `m_ShowMoreIndicator:@"UIActivityIndicatorView"@200`, `m_CoverViewPad:@"UIView"@204`, `m_PackDetailViewPad:@"StorePackDetailViewPad"@208`, `m_RestoreProductID:@"NSMutableArray"@212`, `m_RestorePackInfo:@"NSMutableArray"@216`, `m_RestoreButton:@"UIButton"@220`, `m_StorePackInfoDownloader:@"StorePackInfoDownloader"@224`, `m_PackBgImage0:@"UIImage"@228`, `m_PackBgImage1:@"UIImage"@232`, `m_IsPad:c@236`, `m_IsLoadingMoreList:c@237`, `m_IsAnimationing:c@238`, `m_OffsetForOS:i@240`, `m_IsStoreClosing:c@244`, `_isAlertViewShowing:c@245`, `m_RecommendPackListCtrl:@"StorePackListController"@248`

### `MainViewController`  — 🟡 partial

- Methods: **48 / 96** reconstructed (48 missing) · Ivars: 51 · `instanceSize`=356
- Missing methods: `dealloc` 0xb440, `didReceiveMemoryWarning` 0xb4c4, `viewDidUnload` 0xb4f0, `loadView` 0xb51c, `viewDidLoad` 0xb970, `viewWillAppear:` 0xb9b0, `viewDidAppear:` 0xb9dc, `viewWillDisappear:` 0xba08, `viewDidDisappear:` 0xba34, `shouldAutorotateToInterfaceOrientation:` 0xba60, `LayoutedGLView:` 0xba6c, `screenshot` 0xbb98, `StopLoop` 0xbed0, `GetGlView` 0xc150, `IsFriendManageEnable` 0xcf70, `IsPopnLinkEnable` 0xd21c, `IsStoreEnable` 0xd548, `InsertCommunicating` 0xd6a8, `IsCommunicatingAnimationing` 0xd764, `IsCommunicatingEnable` 0xd790, `CommunicatingFailed` 0xd7a8, `CommunicatingEndCallBack` 0xd7c8, `IsInviteCodeEnable` 0xd918, `IsArcadeSearchEnable` 0xda28, `IsPresentBoxEnable` 0xe158, `SaveToCameraRoll:` 0xe704, `onCompleteCapture:didFinishSavingWithError:contextInfo:` 0xe7c0, `SetAlertViewCallback:param:` 0xe810, `commonAlertView:clickedButtonAtIndex:` 0xe914, `customAlertView:clickedButtonAtIndex:` 0xeac8, `appListDidAppear` 0xeaec, `appListDidDisappear` 0xeaf0, `appListFailLoadWithError:` 0xeb1c, `handleTapCoverView:` 0xeba8, `InsertBlackBoard` 0xeca4, `FadeInBlackBoard` 0xede8, `FadeOutBlackBoard` 0xefdc, `.cxx_construct` 0xf1e8, `settingViewing` 0xf0d0, `cameraRollSaving` 0xf0e8, `isDefaultDlFailed` 0xf100, `rewardListViweing` 0xf118, `setRewardListViweing:` 0xf130, `isGotoTitle` 0xf178, `setIsGotoTitle:` 0xf190, `acMusicSelViewing` 0xf1a8, `setAcMusicSelViewing:` 0xf1c0, `cameraRollError` 0xf1d8
- Ivars: `_glView:@"neGLView"@164`, `_settingViewing:B@168`, `_cameraRollSaving:B@169`, `_isDefaultDlFailed:B@170`, `_rewardListViweing:B@171`, `_isGotoTitle:B@172`, `_acMusicSelViewing:B@173`, `_settingNaviCtrl:@"UINavigationController"@176`, `_friendMngNaviCtrl:@"UINavigationController"@180`, `_popnLinkNaviCtrl:@"UINavigationController"@184`, `_friendScoreNaviCtrl:@"UINavigationController"@188`, `_recommendNaviCtrl:@"UINavigationController"@192`, `_mapSelectNaviCtrl:@"UINavigationController"@196`, `_sortSelectNaviCtrl:@"UINavigationController"@200`, `_inputNameNaviCtrl:@"UINavigationController"@204`, `_inputConvPassNaviCtrl:@"UINavigationController"@208`, `_inviteNaviCtrl:@"UINavigationController"@212`, `_searchNaviCtrl:@"UINavigationController"@216`, `_acViewerNaviCtrl:@"UINavigationController"@220`, `_presentBoxNaviCtrl:@"UINavigationController"@224`, `_overScoreLogNaviCtrl:@"UINavigationController"@228`, `_storeViewController:@"StoreViewController"@232`, `_defaultDlViewController:@"DefaultDataDownloadView"@236`, `_acceptPolicyCtrl:@"AcceptPolicyViewController"@240`, `_communicatingView:@"CommunicatingView"@244`, `_cameraRollError:@"NSError"@248`, `m_LoopInterval:i@252`, `m_DisplayLink:@"CADisplayLink"@256`, `m_TaskTime:{C_TIME="m_Time"{timeval="tv_sec"i"tv_usec"i}}@260`, `m_RenderTime:{C_TIME="m_Time"{timeval="tv_sec"i"tv_usec"i}}@268`, `m_IsPause:B@276`, `m_IsLoop:B@277`, `m_AepManager:^{AepManager=[256c][256c][25[262144c]][25{HASH_TABLE=[2047S][2047*]}][25{HASH_TABLE=[2047S][2047*]}][25{HASH_TABLE=[2047S][2047*]}][25[512s]][25i]{AepOrderingTable=^^?{SIZE=ll}[2048{OT_STRUCT=^{OT_STRUCT}ssi(?={?={FRAME_DATA=SSSS}iiffiiiisSii{RECT_GCU=iiii}}{?=^{AepTexture}iiiiiiffiiiisSii{RECT_GCU=iiii}}{?=iiiiii}{?=iiiiiiii}{?=iiiiii}{?=iiiiiiiiii}{?=[256c]iiiiii{RECT_GCU=iiii}})}]ii[50^{OT_STRUCT}][50^{OT_STRUCT}]^^{AepTexture}f}[25^{AepTexture}][512c][25c][25[1024{FRAME_DATA=SSSS}]][25i][25^{LAYER_DATA}][25^?][25^v]{RECT_GCU=iiii}{S_FADE=iiii}i}@280`, `m_AlertViewCallback:^?@284`, `m_AlertViewCallbackParam:^v@288`, `m_capturedImg:@"UIImage"@292`, `m_flgCapture:c@296`, `_coverView:@"UIButton"@300`, `_presentBoxViewCtrl:@"PresentBoxViewController"@304`, `_sortSelectViewCtrl:@"SortSelectViewController"@308`, `_recommendViewCtrl:@"RecommendViewController"@312`, `_overScoreLogViewCtrl:@"OverScoreLogViewController"@316`, `_settingViewCtrl:@"SettingTableSplitViewController"@320`, `_mapSelectViewCtrl:@"MapSelectSplitViewController"@324`, `_friendMngViewCtrl:@"FriendMngTopSplitViewController"@328`, `_popnLinkViewCtrl:@"PopnLinkTopSplitViewController"@332`, `_inputNameViewCtrl:@"InputNameViewCtrl"@336`, `_inputConvPassViewCtrl:@"InputConversionPassViewController"@340`, `_acViewerViewCtrl:@"AcViewerSplitViewController"@344`, `_inviteViewCtrl:@"InviteTopViewControllerPad"@348`, `_blackBoardView:@"UIView"@352`

### `AudioManager`  — 🟡 partial

- Methods: **41 / 69** reconstructed (28 missing) · Ivars: 23 · `instanceSize`=380
- Missing methods: `init` 0x1df8c, `cleanupSe` 0x1e238, `loadBgmDataWithBytes:length:isLoop:` 0x1e63c, `loadBgmDataWithBytesNoCopy:length:isLoop:` 0x1e67c, `loadBgmDataWithBytesNoCopy:length:freeWhenDone:isLoop:` 0x1e6bc, `loadVoiceData:isLoop:` 0x1e7f0, `releaseSe:resourceId:` 0x1eba8, `releaseSeAll` 0x1eda8, `releaseVoice` 0x1efdc, `prepareSetGroup:resourceId:groupId:` 0x1f164, `playSeSetGroup:resourceId:groupId:` 0x1f380, `onPauseSe:` 0x1f434, `offPauseSe:` 0x1f498, `isPlayingSe:` 0x1f4fc, `onPauseSeAll` 0x1f568, `offPauseSeAll` 0x1f5cc, `stopAll` 0x1f694, `orderInstanceList:` 0x1f7ec, `setJustBgmVolume:` 0x1fc6c, `bgmDeviceCurrentTime` 0x1ff84, `onFadeInTimer:` 0x2002c, `onFadeOutTimer:` 0x200ec, `isPlayingVoice` 0x2042c, `audioPlayerDidFinishPlaying:successfully:` 0x20460, `audioPlayerBeginInterruption:` 0x204ac, `audioPlayerEndInterruption:` 0x204d4, `dealloc` 0x206d8, `.cxx_construct` 0x207a0
- Ivars: `sePlayer:^{CAPlayer=^{CAComponent}@^^{CASource}i}@4`, `seAVPlayer:^{AVPlayer=^{AVComponent}@^^{AVSource}i}@8`, `seList:[8{_SE_MANAGE_ID_="instanceId"I"busId"i"group"i}]@12`, `seNameList:@"NSMutableArray"@108`, `seRidList:@"NSMutableArray"@112`, `isStart:B@116`, `isSuspend:B@117`, `isInterruption:[2B]@118`, `bgmPlayer:@"AVAudioPlayer"@120`, `isPlaying:[2B]@124`, `unitVolume:f@128`, `voicePlayer:@"AVAudioPlayer"@132`, `isOnPause:B@136`, `fadeTimer:@"NSTimer"@140`, `bgmPlayTime:d@144`, `voicePlayTime:d@152`, `isOnPauseVoice:B@160`, `pushBgm:@"AVAudioPlayer"@164`, `seManageId:[2[8{_SE_MANAGE_ID_="instanceId"I"busId"i"group"i}]]@168`, `seVolume:[2i]@360`, `seType:@"NSMutableDictionary"@368`, `bgmSettingVolume:f@372`, `loadedBgmPath:@"NSString"@376`

### `MusicData`  — 🟡 partial

- Methods: **9 / 34** reconstructed (25 missing) · Ivars: 16 · `instanceSize`=68
- Missing methods: `dealloc` 0xc779c, `artwork2xData` 0xc7964, `musicNameImage2xData` 0xc7980, `artistNameImage2xData` 0xc799c, `compare:` 0xc79b8, `compareMusicID:` 0xc7a28, `compareMusicNameCustom:` 0xc7a60, `compareArtistNameCustom:` 0xc7ad4, `compareMusicNameHira:` 0xc7b3c, `compareArtistNameHira:` 0xc7bb0, `compareDifficultyNormal:` 0xc7c18, `compareDifficultyHyper:` 0xc7c50, `compareDifficultyEx:` 0xc7c88, `lvNormal` 0xc7cd4, `lvHyper` 0xc7ce8, `bpm_MIN` 0xc7d10, `bpm_MAX` 0xc7d24, `musicName` 0xc7d38, `musicNameHira` 0xc7d4c, `artistName` 0xc7d60, `artistNameHira` 0xc7d74, `musicSortName` 0xc7d88, `artistSortName` 0xc7d9c, `musicNameInitial` 0xc7db0, `artistNameInitial` 0xc7dc4
- Ivars: `m_FilePath:@"NSString"@4`, `m_DecodeType:i@8`, `m_MusicID:i@12`, `m_lvNormal:i@16`, `m_lvHyper:i@20`, `m_lvEx:i@24`, `m_BPM_MIN:i@28`, `m_BPM_MAX:i@32`, `m_MusicName:@"NSString"@36`, `m_MusicHira:@"NSString"@40`, `m_ArtistName:@"NSString"@44`, `m_ArtistHira:@"NSString"@48`, `m_MusicSortName:@"NSString"@52`, `m_ArtistSortName:@"NSString"@56`, `m_MusicNameInitial:@"NSString"@60`, `m_ArtistNameInitial:@"NSString"@64`

### `AcMusicData`  — 🟡 partial

- Methods: **7 / 31** reconstructed (24 missing) · Ivars: 17 · `instanceSize`=72
- Missing methods: `dealloc` 0x6629c, `getBackTrack:` 0x66394, `compare:` 0x66488, `compareAcMusicId:` 0x664f8, `compareMusicNameCustom:` 0x66530, `compareGenreNameCustom:` 0x665a4, `compareLvEasy:` 0x6660c, `compareLvNormal:` 0x66644, `compareLvHyper:` 0x6667c, `compareLvEx:` 0x666b4, `lvEasy` 0x66700, `lvNormal` 0x66714, `lvHyper` 0x66728, `bpmEasy` 0x66750, `bpmNormal` 0x66764, `bpmHyper` 0x66778, `bpmEx` 0x6678c, `category` 0x667a0, `musicName` 0x667b4, `musicNameKana` 0x667c8, `genreName` 0x667dc, `genreNameKana` 0x667f0, `musicNameInitial` 0x66804, `genreNameInitial` 0x66818
- Ivars: `m_filePath:@"NSString"@4`, `m_acMusicId:i@8`, `m_lvEasy:i@12`, `m_lvNormal:i@16`, `m_lvHyper:i@20`, `m_lvEx:i@24`, `m_bpmEasy:@"NSString"@28`, `m_bpmNormal:@"NSString"@32`, `m_bpmHyper:@"NSString"@36`, `m_bpmEx:@"NSString"@40`, `m_category:i@44`, `m_musicName:@"NSString"@48`, `m_musicNameKana:@"NSString"@52`, `m_genreName:@"NSString"@56`, `m_genreNameKana:@"NSString"@60`, `m_musicNameInitial:@"NSString"@64`, `m_genreNameInitial:@"NSString"@68`

### `MusicManager`  — 🟡 partial

- Methods: **14 / 37** reconstructed (23 missing) · Ivars: 13 · `instanceSize`=56
- Missing methods: `init` 0xc81dc, `dealloc` 0xc827c, `createDefaultMusics` 0xc8384, `createOpenTreasureMusics` 0xc8440, `createOpenInviteMusics` 0xc8554, `createOpenCollaboMusics` 0xc8604, `createOpenLoginBonusMusics` 0xc86b4, `createAcDefaultMusics` 0xc8764, `savePurchasedMusics` 0xc8bec, `getPurchasedMusicDictionaris` 0xc8f28, `getPurchasedAcMusicDictionaris` 0xc8f38, `addPurchasedMusic:` 0xc8f48, `addPurchasedAcMusic:` 0xc93f0, `deleteMusic:` 0xc9898, `deleteAcMusic:` 0xc9914, `isRecommendedPack:` 0xc9990, `openTreasureMusic` 0xcafc0, `openInviteMusic` 0xcaff0, `openCollaboMusic` 0xcb020, `openLoginBonusMusic` 0xcb050, `getMusicIDs` 0xcb24c, `getAcMusicIDs` 0xcb474, `getMusicPatchArray` 0xcb948
- Ivars: `m_DefaultMusicIDs:@"NSArray"@4`, `m_OpenTreasureMusicIDs:@"NSMutableArray"@8`, `m_OpenInviteMusicIDs:@"NSMutableArray"@12`, `m_OpenCollaboMusicIDs:@"NSMutableArray"@16`, `m_OpenLoginBonusMusicIDs:@"NSMutableArray"@20`, `m_PurchasedMusicDictionaris:@"NSMutableArray"@24`, `m_PurchasedAcMusicDictionaris:@"NSMutableArray"@28`, `m_AcDefaultMusicIDs:@"NSArray"@32`, `m_MusicDataArray:@"NSMutableArray"@36`, `m_MusicDataArrayDirty:c@40`, `m_AcMusicDataArray:@"NSMutableArray"@44`, `m_AcMusicDataArrayDirty:c@48`, `m_MusicLvPatchArray:@"NSArray"@52`

### `StoreAcvManageViewController`  — 🟡 partial

- Methods: **1 / 24** reconstructed (23 missing) · Ivars: 10 · `instanceSize`=204
- Missing methods: `loadView` 0x8c7f0, `tableView:cellForRowAtIndexPath:` 0x8cf28, `tableView:numberOfRowsInSection:` 0x8d8b4, `tableView:willDisplayCell:forRowAtIndexPath:` 0x8d8f8, `numberOfSectionsInTableView:` 0x8da44, `pushCellButton:` 0x8da48, `startDownloadMusic` 0x8de20, `startCheck` 0x8df94, `downloaderFinished:` 0x8e03c, `downloaderError:` 0x8e1a4, `storeDialogCancel:` 0x8e250, `commonAlertView:clickedButtonAtIndex:` 0x8e2f8, `downloadManagerCompleted:` 0x8e3e4, `downloadManagerFailed:` 0x8e45c, `downloadManagerProceed:` 0x8e574, `shouldAutorotateToInterfaceOrientation:` 0x8e5e0, `didReceiveMemoryWarning` 0x8e5e4, `viewDidUnload` 0x8e610, `viewWillAppear:` 0x8e664, `viewDidAppear:` 0x8e690, `viewWillDisappear:` 0x8e6f0, `viewDidDisappear:` 0x8e71c, `dealloc` 0x8e748
- Ivars: `tableView:@"UITableView"@164`, `storeViewCtrl:@"StoreViewController"@168`, `working_index:I@172`, `m_InfoDownloader:@"Downloader"@176`, `dlManager:@"StoreDownloadManager"@180`, `deleteAlertView:@"CommonAlertView"@184`, `imgDelete:@"UIImage"@188`, `imgDownload:@"UIImage"@192`, `isPad:c@196`, `checkMusicIds:@"NSMutableArray"@200`

### `StoreManageViewController`  — 🟡 partial

- Methods: **1 / 23** reconstructed (22 missing) · Ivars: 9 · `instanceSize`=197
- Missing methods: `loadView` 0x4be00, `tableView:cellForRowAtIndexPath:` 0x4c308, `tableView:numberOfRowsInSection:` 0x4cc94, `tableView:willDisplayCell:forRowAtIndexPath:` 0x4ccd8, `numberOfSectionsInTableView:` 0x4ce24, `pushCellButton:` 0x4ce28, `startDownloadMusic` 0x4d1ec, `downloaderFinished:` 0x4d360, `downloaderError:` 0x4d460, `storeDialogCancel:` 0x4d4b8, `commonAlertView:clickedButtonAtIndex:` 0x4d560, `downloadManagerCompleted:` 0x4d64c, `downloadManagerFailed:` 0x4d6c4, `downloadManagerProceed:` 0x4d7dc, `shouldAutorotateToInterfaceOrientation:` 0x4d848, `didReceiveMemoryWarning` 0x4d84c, `viewDidUnload` 0x4d878, `viewWillAppear:` 0x4d8cc, `viewDidAppear:` 0x4d8f8, `viewWillDisappear:` 0x4d958, `viewDidDisappear:` 0x4d984, `dealloc` 0x4d9b0
- Ivars: `tableView:@"UITableView"@164`, `storeViewCtrl:@"StoreViewController"@168`, `working_index:I@172`, `m_InfoDownloader:@"Downloader"@176`, `dlManager:@"StoreDownloadManager"@180`, `deleteAlertView:@"CommonAlertView"@184`, `imgDelete:@"UIImage"@188`, `imgDownload:@"UIImage"@192`, `isPad:c@196`

### `AppDelegate`  — 🟡 partial

- Methods: **24 / 43** reconstructed (19 missing) · Ivars: 17 · `instanceSize`=72
- Missing methods: `dealloc` 0x8c74, `deleteUuid` 0x9c20, `setUsersettingVer:` 0x9d58, `getUsersettingVer` 0xa044, `deleteUsersettingVer` 0xa270, `userAgent` 0xa3a8, `appVersionNum` 0xa458, `finishRequest:` 0xab44, `purchaseSucceeded:` 0xab9c, `purchaseFailed:error:` 0xac24, `getProduct:` 0xacac, `loginGameCenter` 0xb00c, `displayType` 0xb0a8, `products` 0xb0bc, `mainTask` 0xb0d0, `setMainTask:` 0xb0e4, `acMainTask` 0xb0fc, `setAcMainTask:` 0xb110, `rewardAppId` 0xb128
- Ivars: `_window:@"neWindow"@4`, `_viewController:@"MainViewController"@8`, `_strageAlert:@"CommonAlertView"@12`, `_userAgent:@"NSString"@16`, `_hardwareType:i@20`, `_hardwareName:@"NSString"@24`, `_displayType:i@28`, `_managedObjectContext:@"NSManagedObjectContext"@32`, `_managedObjectContextSub:@"NSManagedObjectContext"@36`, `_managedObjectModel:@"NSManagedObjectModel"@40`, `_persistentStoreCoordinator:@"NSPersistentStoreCoordinator"@44`, `_products:@"NSArray"@48`, `_mainTask:^v@52`, `_acMainTask:^v@56`, `_isNecessaryToResume:B@60`, `_rewardAppId:@"NSString"@64`, `_getEventInfoTimer:@"NSTimer"@68`

### `StorePackDetailViewPad`  — 🟡 partial

- Methods: **15 / 32** reconstructed (17 missing) · Ivars: 20 · `instanceSize`=144
- Missing methods: `selfCheckButtonText` 0x4ef54, `setButtonTextBuy` 0x4f024, `setButtonTextInstall` 0x4f0b8, `setButtonTextInstalling` 0x4f144, `setButtonTextInstalled` 0x4f1d0, `showPackInfo` 0x4f318, `loadInfo` 0x4f680, `finishBgm:` 0x50100, `downloaderError:` 0x505d8, `downloaderProceed:` 0x507a4, `storePackInfoDownloaderFinished:` 0x507a8, `storePackInfoDownloaderError:` 0x50840, `commonAlertView:clickedButtonAtIndex:` 0x5093c, `dealloc` 0x50990, `packInfo` 0x50b48, `delegate` 0x50b68, `setDelegate:` 0x50b78
- Ivars: `packInfo:@"StorePackInfo"@52`, `packView:@"UIView"@56`, `musicView:[4@"StorePackMusicView"]@60`, `packArtworkView:@"StoreImageView"@76`, `labelPackName:@"UILabel"@80`, `labelComment:@"UILabel"@84`, `copyrightView:@"UITextView"@88`, `buttonPurchase:@"UIButton"@92`, `indicator:@"UIActivityIndicatorView"@96`, `labelLoading:@"UILabel"@100`, `m_StorePackInfoDownloader:@"StorePackInfoDownloader"@104`, `m_SampleDownloader:@"Downloader"@108`, `samplePlaying:i@112`, `isInfoLoaded:c@116`, `m_ArtistSiteButton:@"UIButton"@120`, `delegate:@@124`, `recommendDownloader:@"Downloader"@128`, `dummyView:@"UIViewController"@132`, `recommendPackIdArr:@"NSArray"@136`, `m_BirthDayView:@"BirthDayViewController"@140`

### `SettingTableViewController`  — 🟡 partial

- Methods: **4 / 20** reconstructed (16 missing) · Ivars: 7 · `instanceSize`=186
- Missing methods: `initAtNavigationController` 0x7ed98, `dealloc` 0x7ef98, `endCloseAnimation` 0x7f250, `viewDidAppear:` 0x7f2f0, `viewDidLoad` 0x7f31c, `didReceiveMemoryWarning` 0x7f348, `numberOfSectionsInTableView:` 0x7f374, `tableView:numberOfRowsInSection:` 0x7f378, `tableView:cellForRowAtIndexPath:` 0x7f390, `tableView:titleForHeaderInSection:` 0x7f708, `tableView:accessoryTypeForRowWithIndexPath:` 0x7f764, `tableView:didSelectRowAtIndexPath:` 0x7f818, `commonAlertView:clickedButtonAtIndex:` 0x80128, `settingClose` 0x801dc, `onEffectOnChanged:` 0x801ec, `onSimpleModeChanged:` 0x8029c
- Ivars: `_effectSwitch:@"UIButton"@164`, `_simpleModeSwitch:@"UISwitch"@168`, `_treasureRetireAlertView:@"CommonAlertView"@172`, `_isAnimationing:c@176`, `howtoViewCtrlPad:@"HowToViewCtrlPad"@180`, `isPad:c@184`, `_isEffectOn:c@185`

### `ImageDownloader`  — 🟡 partial

- Methods: **7 / 20** reconstructed (13 missing) · Ivars: 6 · `instanceSize`=28
- Missing methods: `connection:didReceiveResponse:` 0x5a79c, `dealloc` 0x5aaa4, `setImageURL:` 0x5ab64, `indexPathInTableView` 0x5ab74, `setIndexPathInTableView:` 0x5ab84, `delegate` 0x5ab94, `setDelegate:` 0x5aba4, `activeDownload` 0x5abb4, `setActiveDownload:` 0x5abc4, `imageConnection` 0x5abd4, `setImageConnection:` 0x5abe4, `downloadedImage` 0x5abf4, `setDownloadedImage:` 0x5ac04
- Ivars: `m_ImageURL:@"NSString"@4`, `m_IndexPathInTableView:@"NSIndexPath"@8`, `delegate:@"<ImageDownloaderDelegate>"@12`, `m_ActiveDownload:@"NSMutableData"@16`, `m_ImageConnection:@"NSURLConnection"@20`, `m_DownloadedImage:@"UIImage"@24`

### `StoreViewController`  — 🟡 partial

- Methods: **8 / 21** reconstructed (13 missing) · Ivars: 8 · `instanceSize`=192
- Missing methods: `dealloc` 0x53708, `loadView` 0x537d8, `showModalDialog:` 0x53b10, `openDialogAnimStop:finished:context:` 0x53c88, `hideModalDialog` 0x53cd8, `closeDialogAnimStop:finished:context:` 0x53df0, `shouldAutorotateToInterfaceOrientation:` 0x53e58, `didReceiveMemoryWarning` 0x54338, `viewWillAppear:` 0x54364, `viewDidAppear:` 0x54390, `viewWillDisappear:` 0x543bc, `viewDidDisappear:` 0x543e8, `modalDialog` 0x54414
- Ivars: `m_CoverView:@"UIView"@164`, `m_ModalDialog:@"StoreDialogView"@168`, `m_MainNavCtrl:@"UINavigationController"@172`, `m_ManageNavCtrl:@"UINavigationController"@176`, `m_AcvManageNavCtrl:@"UINavigationController"@180`, `m_Animation:c@184`, `m_IsModalDialogAnimation:c@185`, `_recommendPackId:i@188`

### `HowToViewCtrl`  — 🟡 partial

- Methods: **2 / 14** reconstructed (12 missing) · Ivars: 7 · `instanceSize`=189
- Missing methods: `didReceiveMemoryWarning` 0x834e0, `viewWillDisappear:` 0x8350c, `dealloc` 0x83538, `pageControlDidChanged:` 0x835d8, `scrollViewDidScroll:` 0x83670, `backButtonFunc` 0x837bc, `fromNaviBarImage` 0x8385c, `setFromNaviBarImage:` 0x83870, `backGroundImage` 0x83880, `setBackGroundImage:` 0x83894, `isCloseButtonEnable` 0x838a4, `setIsCloseButtonEnable:` 0x838bc
- Ivars: `_fileNameArray:@"NSArray"@164`, `_scrollView:@"UIScrollView"@168`, `_pageCtrl:@"UIPageControl"@172`, `_closeBtn:@"UIButton"@176`, `_fromNaviBarImage:@"UIImage"@180`, `_backGroundImage:@"UIImage"@184`, `_isCloseButtonEnable:c@188`

### `StoreDetailMusicCell`  — 🟡 partial

- Methods: **3 / 15** reconstructed (12 missing) · Ivars: 11 · `instanceSize`=96
- Missing methods: `handleLink:` 0x74fb0, `setBgImage:` 0x74ffc, `sampleDownloading` 0x750dc, `samplePlaying` 0x7513c, `dealloc` 0x7519c, `artworkView` 0x752b4, `labelName` 0x752c4, `labelArtist` 0x752d4, `labelLevels` 0x752e4, `linkURL` 0x752f4, `setLinkURL:` 0x75304, `arcadeViewer` 0x75314
- Ivars: `bgView:@"UIImageView"@52`, `artworkView:@"UIImageView"@56`, `labelName:@"UILabel"@60`, `labelArtist:@"UILabel"@64`, `labelLevels:@"UILabel"@68`, `sampleView:@"UIView"@72`, `indicator:@"UIActivityIndicatorView"@76`, `playingView:@"UIImageView"@80`, `buttonLink:@"UIButton"@84`, `linkURL:@"NSURL"@88`, `arcadeViewer:@"UIImageView"@92`

### `CharaInfo`  — 🟡 partial

- Methods: **2 / 13** reconstructed (11 missing) · Ivars: 6 · `instanceSize`=28
- Missing methods: `dealloc` 0x640b8, `setCharaId:` 0x64144, `charaName` 0x6415c, `setCharaName:` 0x6416c, `info` 0x6417c, `setInfo:` 0x6418c, `setSkillId:` 0x641b0, `skillName` 0x641c8, `setSkillName:` 0x641d8, `rarity` 0x641e8, `setRarity:` 0x641fc
- Ivars: `_charaId:i@4`, `_charaName:@"NSString"@8`, `_info:@"NSString"@12`, `_skillId:i@16`, `_skillName:@"NSString"@20`, `_rarity:i@24`

### `CommonAlertView`  — 🟡 partial

- Methods: **4 / 15** reconstructed (11 missing) · Ivars: 7 · `instanceSize`=80
- Missing methods: `initWithFrame:` 0x4a308, `dealloc` 0x4b474, `onYesButton` 0x4b970, `onNoButton` 0x4b9a4, `commonAlertView:clickedButtonAtIndex:` 0x4b9d8, `title` 0x4bbc0, `setTitle:` 0x4bbd4, `message` 0x4bbe4, `setMessage:` 0x4bbf8, `delegate` 0x4bc08, `setDelegate:` 0x4bc1c
- Ivars: `_isAnimationing:c@52`, `_titleView:@"UILabel"@56`, `_messageView:@"CustomTextView"@60`, `_dummyView:@"UIView"@64`, `_delegate:@"<CommonAlertViewDelegate>"@68`, `_title:@"NSString"@72`, `_message:@"NSString"@76`

### `StoreDownloadManager`  — 🟡 partial

- Methods: **1 / 12** reconstructed (11 missing) · Ivars: 5 · `instanceSize`=21
- Missing methods: `initWithTasks:delegate:` 0x41fec, `currentProgress` 0x42090, `overallProgress` 0x420b0, `numTasks` 0x42120, `start` 0x42140, `cancel` 0x422a0, `downloaderProceed:` 0x42568, `downloaderError:` 0x425bc, `dealloc` 0x42664, `currentIndex` 0x426e0, `tasks` 0x426f0
- Ivars: `m_Tasks:@"NSArray"@4`, `m_FileDownloader:@"Downloader"@8`, `m_Delegate:@"<StoreDownloadManagerDelegate>"@12`, `m_CurrentIndex:I@16`, `m_IsStarted:c@20`

### `StoreMusicInfo`  — 🟡 partial

- Methods: **2 / 13** reconstructed (11 missing) · Ivars: 10 · `instanceSize`=44
- Missing methods: `dealloc` 0x566b8, `musicID` 0x5676c, `name` 0x5677c, `artist` 0x5678c, `itemURL` 0x5679c, `artworkURL` 0x567ac, `sampleURL` 0x567bc, `itunesURL` 0x567cc, `lvBasic` 0x567dc, `lvMedium` 0x567ec, `lvHard` 0x567fc
- Ivars: `musicID:i@4`, `name:@"NSString"@8`, `artist:@"NSString"@12`, `itemURL:@"NSString"@16`, `artworkURL:@"NSString"@20`, `sampleURL:@"NSString"@24`, `itunesURL:@"NSString"@28`, `lvBasic:i@32`, `lvMedium:i@36`, `lvHard:i@40`

### `AcViewerSplitViewController`  — 🟡 partial

- Methods: **7 / 16** reconstructed (9 missing) · Ivars: 12 · `instanceSize`=256
- Missing methods: `dealloc` 0x32234, `viewDidLoad` 0x326d4, `didReceiveMemoryWarning` 0x32700, `startHiddenAnimation:` 0x32a80, `hiddenFunc` 0x32c18, `endHiddenAnimation` 0x32c7c, `onBackButtonTouched:` 0x32d44, `handleTapCoverView` 0x3350c, `.cxx_construct` 0x33510
- Ivars: `_isAnimationing:c@162`, `_leftViewCtrl:@"UIViewController"@164`, `_rightViewCtrl:@"UINavigationController"@168`, `_arrowImageView:@"UIImageView"@172`, `_rightViewFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@176`, `_categoryArrowFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@192`, `_musicNameArrowFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@208`, `_genreArrowFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@224`, `_btnCategory:@"UIButton"@240`, `_btnMusicName:@"UIButton"@244`, `_btnGenre:@"UIButton"@248`, `_selectedButton:@"UIButton"@252`

### `FriendMngTopViewController`  — 🟡 partial

- Methods: **5 / 14** reconstructed (9 missing) · Ivars: 3 · `instanceSize`=172
- Missing methods: `dealloc` 0xa6488, `viewDidLoad` 0xa64b4, `didReceiveMemoryWarning` 0xa64e0, `viewWillAppear:` 0xa650c, `endOpenAnimation` 0xa66bc, `startCloseAnimation` 0xa66d0, `endCloseAnimation` 0xa6810, `delegate` 0xa6c00, `setDelegate:` 0xa6c10
- Ivars: `_isAnimationing:c@162`, `_markView:@"UIImageView"@164`, `m_Delegate:@@168`

### `StoreDetailViewController`  — 🟡 partial

- Methods: **39 / 48** reconstructed (9 missing) · Ivars: 17 · `instanceSize`=232
- Missing methods: `didReceiveMemoryWarning` 0x72898, `viewDidUnload` 0x728c4, `viewWillAppear:` 0x72ad0, `viewDidAppear:` 0x72afc, `viewWillDisappear:` 0x72b60, `viewDidDisappear:` 0x72c88, `backButtonFunc` 0x72cb4, `packInfo` 0x72d0c, `delegate` 0x72d2c
- Ivars: `packInfo:@"StorePackInfo"@164`, `m_HeaderView:@"StoreDetailHeaderView"@168`, `m_BirthDayView:@"BirthDayViewController"@172`, `m_PackTableView:@"UITableView"@176`, `m_AccessingIndicator:@"UIActivityIndicatorView"@180`, `m_AccessingLabel:@"UILabel"@184`, `m_StorePackInfoDownloader:@"StorePackInfoDownloader"@188`, `sampleDownloader:@"Downloader"@192`, `packBgImage0:@"UIImage"@196`, `packBgImage1:@"UIImage"@200`, `artworkDownloaders:@"NSMutableDictionary"@204`, `recommendPackIdArr:@"NSArray"@208`, `rowSamplePlayed:i@212`, `isDownloadingSample:c@216`, `delegate:@@220`, `recommendDownloader:@"Downloader"@224`, `dummyView:@"UIViewController"@228`

### `neGLView`  — 🟡 partial

- Methods: **6 / 15** reconstructed (9 missing) · Ivars: 8 · `instanceSize`=84
- Missing methods: `initWithFrame:` 0x28100, `dealloc` 0x28334, `GetFrontBufferWidth` 0x28524, `GetFrontBufferHeight` 0x28534, `touchesBegan:withEvent:` 0x285e8, `touchesMoved:withEvent:` 0x28718, `touchesCancelled:withEvent:` 0x289c4, `delegate` 0x289d4, `setDelegate:` 0x289e8
- Ivars: `m_GLContext:@"EAGLContext"@52`, `m_FrontBufferWidth:i@56`, `m_FrontBufferHeight:i@60`, `m_DefaultFramebuffer:I@64`, `m_ColorRenderbuffer:I@68`, `m_RenderBufferID:I@72`, `m_GLInterface:^{neIGLES=^^?}@76`, `delegate:@"<GLViewDelegate>"@80`

### `PurchaseManager`  — 🟡 partial

- Methods: **22 / 30** reconstructed (8 missing) · Ivars: 10 · `instanceSize`=40
- Missing methods: `dealloc` 0x545b8, `end` 0x546f8, `startProductRequest:` 0x55170, `downloaderProceed:` 0x55eb8, `delegate` 0x56128, `setDelegate:` 0x56138, `musicDataDelegate` 0x56148, `setMusicDataDelegate:` 0x56158
- Ivars: `m_PurchasedProducts:@"NSMutableArray"@4`, `m_PurchaseCheckTransactions:@"NSMutableArray"@8`, `m_PurchaseCheckedProducts:@"NSMutableArray"@12`, `m_Transactioing:c@16`, `m_IsRestored:c@17`, `m_RestoredTransactions:@"NSMutableArray"@20`, `m_IsMusicData:c@24`, `m_Downloader:@"Downloader"@28`, `m_Delegate:@"<PurchaseManagerDelegate>"@32`, `m_MusicDataDelegate:@"<PurchaseManagerMusicDelegate>"@36`

### `Downloader`  — 🟡 partial

- Methods: **9 / 16** reconstructed (7 missing) · Ivars: 7 · `instanceSize`=36
- Missing methods: `connection:didReceiveResponse:` 0x62514, `currentSize` 0x62888, `currentProgress` 0x628a8, `getProgressSec` 0x629bc, `dealloc` 0x629f8, `addData` 0x62afc, `setAddData:` 0x62b10
- Ivars: `m_Request:@"NSMutableURLRequest"@4`, `m_Connection:@"NSURLConnection"@8`, `m_DownloadSize:q@12`, `m_DownloadedData:@"NSMutableData"@20`, `m_Delegate:@"<DownloaderDelegate>"@24`, `m_AdditionalData:@"NSObject"@28`, `m_StartTime:@"NSDate"@32`

### `PurchaseTransactionCache`  — 🟡 partial

- Methods: **1 / 8** reconstructed (7 missing) · Ivars: 5 · `instanceSize`=24
- Missing methods: `dealloc` 0x56254, `productID` 0x56338, `receiptData` 0x56348, `transactionID` 0x56358, `transactionDate` 0x56368, `digestString` 0x56378, `setDigestString:` 0x56388
- Ivars: `m_ProductID:@"NSString"@4`, `m_ReceiptData:@"NSData"@8`, `m_TransactionID:@"NSString"@12`, `m_TransactionDate:@"NSDate"@16`, `m_DigestString:@"NSString"@20`

### `StorePackMusicView`  — 🟡 partial

- Methods: **7 / 14** reconstructed (7 missing) · Ivars: 9 · `instanceSize`=88
- Missing methods: `setIsExistAcv:` 0x5171c, `dealloc` 0x5191c, `artworkView` 0x519e4, `labelName` 0x519f4, `labelArtist` 0x51a04, `labelLevels` 0x51a14, `buttonLink` 0x51a34
- Ivars: `artworkView:@"StoreImageView"@52`, `labelName:@"UILabel"@56`, `labelArtist:@"UILabel"@60`, `labelLevels:@"UILabel"@64`, `indicatorSample:@"UIActivityIndicatorView"@68`, `buttonSample:@"UIButton"@72`, `buttonLink:@"UIButton"@76`, `m_BG:@"UIImageView"@80`, `arcadeViewer:@"UIImageView"@84`

### `AcViewerDetailCell`  — 🟡 partial

- Methods: **1 / 7** reconstructed (6 missing) · Ivars: 5 · `instanceSize`=72
- Missing methods: `dealloc` 0x5b668, `setData:` 0x5b694, `optionName` 0x5bbb8, `setOptionName:` 0x5bbc8, `optionKind` 0x5bbd8, `setOptionKind:` 0x5bbec
- Ivars: `_optionLbl:@"UILabel"@52`, `_checkImageView:@"UIImageView"@56`, `_optionName:@"NSString"@60`, `_optionKind:i@64`, `_index:i@68`

### `AcViewerMusicCell`  — 🟡 partial

- Methods: **1 / 7** reconstructed (6 missing) · Ivars: 13 · `instanceSize`=104
- Missing methods: `dealloc` 0x40954, `setData:` 0x409e0, `easyBtn` 0x4168c, `normalBtn` 0x416a0, `hyperBtn` 0x416b4, `exBtn` 0x416c8
- Ivars: `_bgImgView:@"UIImageView"@52`, `_titleLbl:@"UILabel"@56`, `_lvEsLbl:@"UILabel"@60`, `_lvNLbl:@"UILabel"@64`, `_lvHLbl:@"UILabel"@68`, `_lvExLbl:@"UILabel"@72`, `_easyBtn:@"UIButton"@76`, `_normalBtn:@"UIButton"@80`, `_hyperBtn:@"UIButton"@84`, `_exBtn:@"UIButton"@88`, `isPad:c@92`, `offsetForPad1:i@96`, `offsetForPad2:i@100`

### `LimitedCharaInfo`  — 🟡 partial

- Methods: **1 / 7** reconstructed (6 missing) · Ivars: 3 · `instanceSize`=13
- Missing methods: `dealloc` 0x642e8, `musicIds` 0x6434c, `setMusicIds:` 0x6435c, `setCharaIds:` 0x6437c, `getFlg` 0x6438c, `setGetFlg:` 0x643a4
- Ivars: `_musicIds:@"NSArray"@4`, `_charaIds:@"NSArray"@8`, `_getFlg:c@12`

### `PreferredCharaInfo`  — 🟡 partial

- Methods: **1 / 7** reconstructed (6 missing) · Ivars: 3 · `instanceSize`=13
- Missing methods: `dealloc` 0x64214, `musicIds` 0x64278, `setMusicIds:` 0x64288, `setCharaIds:` 0x642a8, `getFlg` 0x642b8, `setGetFlg:` 0x642d0
- Ivars: `_musicIds:@"NSArray"@4`, `_charaIds:@"NSArray"@8`, `_getFlg:c@12`

### `StoreAcMusicInfo`  — 🟡 partial

- Methods: **2 / 8** reconstructed (6 missing) · Ivars: 5 · `instanceSize`=24
- Missing methods: `dealloc` 0x85458, `acMusicId` 0x854e4, `title` 0x854f4, `genre` 0x85504, `itemURL` 0x85514, `sampleURL` 0x85524
- Ivars: `acMusicId:i@4`, `title:@"NSString"@8`, `genre:@"NSString"@12`, `itemURL:@"NSString"@16`, `sampleURL:@"NSString"@20`

### `StorePackCell`  — 🟡 partial

- Methods: **1 / 7** reconstructed (6 missing) · Ivars: 8 · `instanceSize`=84
- Missing methods: `isPurchased` 0x6f5a8, `setIsPurchased:` 0x6f5d8, `loadPackInfo:` 0x6f604, `setBgImage:` 0x6f7b4, `dealloc` 0x6f7d4, `artworkView` 0x6f8b0
- Ivars: `bgView:@"UIImageView"@52`, `artworkView:@"UIImageView"@56`, `labelName:@"UILabel"@60`, `labelPrice:@"UILabel"@64`, `labelPurchased:@"UILabel"@68`, `newMarker:@"UIImageView"@72`, `charaTicket:@"UIImageView"@76`, `arcadeViewer:@"UIImageView"@80`

### `StorePackInfo`  — 🟡 partial

- Methods: **18 / 24** reconstructed (6 missing) · Ivars: 13 · `instanceSize`=56
- Missing methods: `dealloc` 0x570f4, `downloadDetailInfo` 0x571e4, `musicInfos` 0x573f0, `acvMusicInfos` 0x57400, `artistURL` 0x57410, `bunnerURL` 0x57420
- Ivars: `m_Product:@"SKProduct"@4`, `m_PackID:i@8`, `m_IsNew:c@12`, `m_ArtworkURL:@"NSString"@16`, `m_PackName:@"NSString"@20`, `m_Comment:@"NSString"@24`, `m_ShortComment:@"NSString"@28`, `m_Copyright:@"NSString"@32`, `m_ArtistURL:@"NSString"@36`, `m_ArtistBunnerURL:@"NSString"@40`, `m_MusicInfos:@"NSArray"@44`, `m_AcvMusicInfos:@"NSArray"@48`, `m_AcvNum:i@52`

### `StorePackInfoDownloader`  — 🟡 partial

- Methods: **8 / 14** reconstructed (6 missing) · Ivars: 3 · `instanceSize`=16
- Missing methods: `downloaderProceed:` 0x57690, `packInfo` 0x57744, `delegate` 0x57764, `setDelegate:` 0x57774, `downloader` 0x57784, `setDownloader:` 0x57794
- Ivars: `m_PackInfo:@"StorePackInfo"@4`, `m_Downloader:@"Downloader"@8`, `m_Delegate:@"<StorePackInfoDownloaderDelegate>"@12`

### `StorePackListController`  — 🟡 partial

- Methods: **13 / 19** reconstructed (6 missing) · Ivars: 10 · `instanceSize`=41
- Missing methods: `packInfos` 0x57a24, `downloaderProceed:` 0x58540, `request:didFailWithError:` 0x58698, `dealloc` 0x58714, `delegate` 0x58800, `setDelegate:` 0x58810
- Ivars: `m_ArrayPackInfo:@"NSMutableArray"@4`, `m_ListPackID:@"NSMutableArray"@8`, `m_PromotionList:@"NSArray"@12`, `m_PacklistDownloader:@"Downloader"@16`, `tmp_pack_list:@"NSDictionary"@20`, `m_ProductsRequest:@"SKProductsRequest"@24`, `m_SelfRetain:@"StorePackListController"@28`, `m_Delegate:@"<StorePackListDelegate>"@32`, `m_FetchedPackNum:I@36`, `m_PacklistContinued:c@40`

### `StorePackView`  — 🟡 partial

- Methods: **5 / 11** reconstructed (6 missing) · Ivars: 11 · `instanceSize`=96
- Missing methods: `dealloc` 0x52448, `setBgImage:` 0x52488, `setIsPurchased:` 0x52560, `delegate` 0x52784, `setDelegate:` 0x52794, `index` 0x527a4
- Ivars: `m_BackGroundImageView:@"UIImageView"@52`, `m_ArtworkImageView:@"UIImageView"@56`, `m_ArcadeViewerImageView:@"UIImageView"@60`, `m_TicketImageView:@"UIImageView"@64`, `m_NameLabel:@"UILabel"@68`, `m_CommentLabel:@"UILabel"@72`, `m_PriceLabel:@"UILabel"@76`, `m_PurchasedButton:@"UIButton"@80`, `m_NewMarker:@"UIImageView"@84`, `m_Index:I@88`, `m_Delegate:@"<StorePackViewDelegate>"@92`

### `BirthDayViewController`  — 🟡 partial

- Methods: **8 / 13** reconstructed (5 missing) · Ivars: 8 · `instanceSize`=196
- Missing methods: `dealloc` 0x847e8, `viewDidLoad` 0x8506c, `didReceiveMemoryWarning` 0x85098, `delegate` 0x850c4, `setDelegate:` 0x850d4
- Ivars: `_infoView:@"UIView"@164`, `_selectDate:@"YearAndMonthPicker"@168`, `_subView:@"UIView"@172`, `_delegate:@@176`, `m_IsAnimationing:c@180`, `_borderView:@"UIView"@184`, `_subBorderView:@"UIView"@188`, `_dummyView:@"UIView"@192`

### `MusicPatch`  — 🟡 partial

- Methods: **4 / 9** reconstructed (5 missing) · Ivars: 4 · `instanceSize`=20
- Missing methods: `dealloc` 0x787f4, `musicId` 0x78820, `setLvN:` 0x78860, `setLvH:` 0x7888c, `setLvEx:` 0x788b8
- Ivars: `_musicId:i@4`, `_lvN:i@8`, `_lvH:i@12`, `_lvEx:i@16`

### `PresentBoxCell`  — 🟡 partial

- Methods: **1 / 6** reconstructed (5 missing) · Ivars: 5 · `instanceSize`=84
- Missing methods: `dealloc` 0x6e438, `setSelected:animated:` 0x6e464, `setPresentData:` 0x6e494, `.cxx_construct` 0x6ed48, `getBtn` 0x6ed34
- Ivars: `_getBtn:@"UIButton"@52`, `_imageViewIcon:@"UIImageView"@56`, `_lbl:@"UILabel"@60`, `_lblInfo:@"UILabel"@64`, `_presentData:{PresentData="presentId"i"itemId"i"itemNum"i"info"@"NSString"}@68`

### `CustomButton`  — 🟡 partial

- Methods: **2 / 6** reconstructed (4 missing) · Ivars: 1 · `instanceSize`=92
- Missing methods: `initWithFrame:` 0xdcf5c, `dealloc` 0xdcf94, `.cxx_construct` 0xdd154, `setTappableInsets:` 0xdd11c
- Ivars: `_tappableInsets:{UIEdgeInsets="top"f"left"f"bottom"f"right"f}@76`

### `OverScoreLogCell`  — 🟡 partial

- Methods: **1 / 5** reconstructed (4 missing) · Ivars: 7 · `instanceSize`=104
- Missing methods: `dealloc` 0x697a8, `setSelected:animated:` 0x697d4, `setOverScoreLogData:` 0x69804, `.cxx_construct` 0x6a29c
- Ivars: `m_lblMusicName:@"UILabel"@52`, `m_imgViewSheet:@"UIImageView"@56`, `m_lblFriendName:@"UILabel"@60`, `m_lblUpdateDate:@"UILabel"@64`, `m_lblMyScore:@"UILabel"@68`, `m_lblFriendScore:@"UILabel"@72`, `m_overScoreLogData:{OverScoreLogData="musicId"i"musicName"@"NSString""sheet"i"friendName"@"NSString""updateDate"@"NSString""myScore"i"friendScore"i}@76`

### `StorePromotionView`  — 🟡 partial

- Methods: **15 / 19** reconstructed (4 missing) · Ivars: 8 · `instanceSize`=84
- Missing methods: `layoutSubviews` 0x79c00, `imageDownloaderDidFail:didLoad:` 0x7a2a4, `delegate` 0x7a724, `setDelegate:` 0x7a734
- Ivars: `m_Indicator:@"UIActivityIndicatorView"@52`, `m_Timer:@"NSTimer"@56`, `m_FrontImageView:@"UIImageView"@60`, `m_NextImageView:@"UIImageView"@64`, `m_PromotionDataArray:@"NSMutableArray"@68`, `m_Index:i@72`, `m_ImageDownloader:@"NSMutableArray"@76`, `m_Delegate:@"<StorePromotionViewDelegate>"@80`

### `TwitterUtil`  — 🟡 partial

- Methods: **2 / 6** reconstructed (4 missing) · Ivars: 2 · `instanceSize`=172
- Missing methods: `dealloc` 0x788d0, `init` 0x78934, `setText:` 0x789a8, `setImage:` 0x78a08
- Ivars: `m_Text:@"NSString"@164`, `m_Img:@"UIImage"@168`

### `FriendReplyCell`  — 🟡 partial

- Methods: **4 / 7** reconstructed (3 missing) · Ivars: 15 · `instanceSize`=112
- Missing methods: `dealloc` 0xa9280, `delegate` 0xa9dc0, `setDelegate:` 0xa9dd4
- Ivars: `_delegate:@"FriendReplyViewController"@52`, `_replyData:@"NSValue"@56`, `_bgImgView:@"UIImageView"@60`, `_charaBgView:@"UIImageView"@64`, `_charaView:@"UIImageView"@68`, `_playerNameLabel:@"UILabel"@72`, `_requestDateLabel:@"UILabel"@76`, `_okButton:@"UIButton"@80`, `_ngButton:@"UIButton"@84`, `isOS7:B@88`, `imgCharaX:i@92`, `imgPlayerNameX:i@96`, `dateX:i@100`, `btnYesX:i@104`, `btnNoX:i@108`

### `FriendRequestCell`  — 🟡 partial

- Methods: **1 / 4** reconstructed (3 missing) · Ivars: 11 · `instanceSize`=96
- Missing methods: `dealloc` 0xb9850, `setFriendData:` 0xb987c, `onTouchedCancelButton` 0xba048
- Ivars: `_charaBgImgView:@"UIImageView"@52`, `_charaImgView:@"UIImageView"@56`, `_playerNameLbl:@"UILabel"@60`, `_requestDateLbl:@"UILabel"@64`, `_cancelButton:@"UIButton"@68`, `_friendPlayerId:@"NSString"@72`, `isOS7:B@76`, `imgCharaX:i@80`, `imgPlayerNameX:i@84`, `imgDateX:i@88`, `btnCancelX:i@92`

### `StoreDetailHeaderView`  — 🟡 partial

- Methods: **4 / 7** reconstructed (3 missing) · Ivars: 7 · `instanceSize`=80
- Missing methods: `dealloc` 0x7447c, `labelName` 0x74544, `labelComment` 0x74554
- Ivars: `m_BgView:@"UIImageView"@52`, `m_ArtworkView:@"UIImageView"@56`, `m_ReflectionArtworkView:@"UIImageView"@60`, `m_LabelName:@"UILabel"@64`, `m_LabelComment:@"UILabel"@68`, `m_ButtonPurchase:@"UIButton"@72`, `m_NewMarker:@"UIImageView"@76`

### `StoreDownloadTask`  — 🟡 partial

- Methods: **2 / 5** reconstructed (3 missing) · Ivars: 3 · `instanceSize`=16
- Missing methods: `initWithURL:path:AddObject:` 0x42700, `dealloc` 0x427dc, `addObject` 0x42874
- Ivars: `m_FileURL:@"NSString"@4`, `m_FilePath:@"NSString"@8`, `m_AddObject:@@12`

### `StoreImageView`  — 🟡 partial

- Methods: **4 / 7** reconstructed (3 missing) · Ivars: 2 · `instanceSize`=64
- Missing methods: `unloadImage:` 0x42928, `dealloc` 0x42aa8, `imageURL` 0x42b20
- Ivars: `m_ImageURL:@"NSString"@56`, `m_ImageDownloader:@"ImageDownloader"@60`

### `StoreTableCell`  — 🟡 partial

- Methods: **1 / 4** reconstructed (3 missing) · Ivars: 2 · `instanceSize`=60
- Missing methods: `dealloc` 0x5293c, `leftPackView` 0x529e4, `rightPackView` 0x529f4
- Ivars: `m_LeftPackView:@"StorePackView"@52`, `m_RightPackView:@"StorePackView"@56`

### `AcViewerOptionCell`  — 🟡 partial

- Methods: **1 / 3** reconstructed (2 missing) · Ivars: 2 · `instanceSize`=60
- Missing methods: `dealloc` 0x654c8, `setData:` 0x654f4
- Ivars: `_optionKindLbl:@"UILabel"@52`, `_optionDetailLbl:@"UILabel"@56`

### `CheckerCategoryCell`  — 🟡 partial

- Methods: **1 / 3** reconstructed (2 missing) · Ivars: 7 · `instanceSize`=84
- Missing methods: `dealloc` 0xcf5c8, `setData:category:` 0xcf5f4
- Ivars: `_musicCntBaseView:@"UIImageView"@52`, `_musicCntNumView:[3@"UIImageView"]@56`, `_bgView:@"UIImageView"@68`, `isOS7:c@72`, `isPad:c@73`, `offsetXForPad:i@76`, `imgMusicCntX:i@80`

### `CustomTextView`  — 🟡 partial

- Methods: **2 / 4** reconstructed (2 missing) · Ivars: 0 · `instanceSize`=56
- Missing methods: `initWithFrame:` 0x27fd0, `dealloc` 0x28008

### `FriendScoreTableCell`  — 🟡 partial

- Methods: **1 / 3** reconstructed (2 missing) · Ivars: 23 · `instanceSize`=144
- Missing methods: `dealloc` 0xae25c, `setScoreData:` 0xae288
- Ivars: `_bgImgView:@"UIImageView"@52`, `_youImgView:@"UIImageView"@56`, `_rankImgView01:@"UIImageView"@60`, `_rankImgView10:@"UIImageView"@64`, `_charaBgImgView:@"UIImageView"@68`, `_charaImgView:@"UIImageView"@72`, `_playerNameLbl:@"UILabel"@76`, `_scoreBaseImgView:@"UIImageView"@80`, `_scoreLbl:@"UILabel"@84`, `_scoreRankImgView:@"UIImageView"@88`, `_fullcomboMarkImgView:@"UIImageView"@92`, `isOS7:B@96`, `imgYouX:i@100`, `imgFrameX:i@104`, `imgFrame10X:i@108`, `imgFrame01X:i@112`, `imgOrderX:i@116`, `imgCharaX:i@120`, `imgPlayerNameX:i@124`, `imgScoreBaseX:i@128`, `imgScoreX:i@132`, `imgRankX:i@136`, `imgFullComboX:i@140`

### `MapListCell`  — 🟡 partial

- Methods: **1 / 3** reconstructed (2 missing) · Ivars: 2 · `instanceSize`=60
- Missing methods: `dealloc` 0xbe2b8, `setMapData:isSelect:` 0xbe2e4
- Ivars: `_mapVal:@"NSValue"@52`, `_bgImgView:@"UIImageView"@56`

### `SortCell`  — 🟡 partial

- Methods: **1 / 3** reconstructed (2 missing) · Ivars: 4 · `instanceSize`=68
- Missing methods: `dealloc` 0xc5460, `setSortData:` 0xc548c
- Ivars: `_sortVal:@"NSValue"@52`, `_titleImageView:@"UIImageView"@56`, `_checkImageView:@"UIImageView"@60`, `_bgImgView:@"UIImageView"@64`

### `StoreDetailCopyrightCell`  — 🟡 partial

- Methods: **1 / 3** reconstructed (2 missing) · Ivars: 1 · `instanceSize`=56
- Missing methods: `dealloc` 0x7547c, `labelCopyright` 0x754c8
- Ivars: `labelCopyright:@"UILabel"@52`

### `StorePromotionTableCell`  — 🟡 partial

- Methods: **1 / 3** reconstructed (2 missing) · Ivars: 0 · `instanceSize`=52
- Missing methods: `setSelected:animated:` 0x738f4, `layoutSubviews` 0x73924

### `SubMapListCell`  — 🟡 partial

- Methods: **1 / 3** reconstructed (2 missing) · Ivars: 1 · `instanceSize`=56
- Missing methods: `dealloc` 0xc0fd4, `setMapData:` 0xc1000
- Ivars: `_mapVal:@"NSValue"@52`

### `SystemHardware`  — 🟡 partial

- Methods: **3 / 5** reconstructed (2 missing) · Ivars: 2 · `instanceSize`=12
- Missing methods: `init` 0x12718, `dealloc` 0x12758
- Ivars: `m_HardwareType:i@4`, `m_HardwareName:@"NSString"@8`

### `YearAndMonthPicker`  — 🟡 partial

- Methods: **7 / 9** reconstructed (2 missing) · Ivars: 3 · `instanceSize`=64
- Missing methods: `dealloc` 0x8efe4, `month` 0x8f424
- Ivars: `_year:i@52`, `_month:i@56`, `monthArr:@"NSMutableArray"@60`

### `FriendListCell`  — 🟡 partial

- Methods: **2 / 3** reconstructed (1 missing) · Ivars: 19 · `instanceSize`=128
- Missing methods: `dealloc` 0xb3494
- Ivars: `_bgImgView:@"UIImageView"@52`, `_youImgView:@"UIImageView"@56`, `_rankImgView01:@"UIImageView"@60`, `_rankImgView10:@"UIImageView"@64`, `_charaBgImgView:@"UIImageView"@68`, `_charaImgView:@"UIImageView"@72`, `_playerNameLbl:@"UILabel"@76`, `_scoreBaseImgView:@"UIImageView"@80`, `_scoreLbl:@"UILabel"@84`, `isOS7:B@88`, `imgYouX:i@92`, `imgFrameX:i@96`, `imgFrame10X:i@100`, `imgFrame01X:i@104`, `imgOrderX:i@108`, `imgCharaX:i@112`, `imgPlayerNameX:i@116`, `imgScoreBaseX:i@120`, `imgScoreX:i@124`

### `SettingOtherTableViewController`  — 🟡 partial

- Methods: **23 / 24** reconstructed (1 missing) · Ivars: 8 · `instanceSize`=208
- Missing methods: `.cxx_construct` 0xd5880
- Ivars: `_treasureRetireAlertView:@"CommonAlertView"@164`, `_isAnimationing:c@168`, `_viewCmnDelegate:@"<ViewCmnProtocol>"@172`, `_selectedIndexPath:@"NSIndexPath"@176`, `_convDetailView:@"UIViewController"@180`, `_convDummyFrm:{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}@184`, `_arrowTopView:@"UIImageView"@200`, `_arrowUnderView:@"UIImageView"@204`

### `ArcadeScoreData`  — ✅ complete

- Methods: **1 / 1** reconstructed (0 missing) · Ivars: 0 · `instanceSize`=48

### `CharaTicketData`  — ✅ complete

- Methods: **0 / 0** reconstructed (0 missing) · Ivars: 0 · `instanceSize`=48

### `FriendListDetail`  — ✅ complete

- Methods: **15 / 15** reconstructed (0 missing) · Ivars: 6 · `instanceSize`=72
- Ivars: `_dummyView:@"UIView"@52`, `_friendData:@"NSValue"@56`, `_isAnimationing:c@60`, `_isEnabled:c@61`, `_dlRemoveFriend:@"Downloader"@64`, `_scaleForPad:f@68`

### `FriendListDetailChara`  — ✅ complete

- Methods: **6 / 6** reconstructed (0 missing) · Ivars: 2 · `instanceSize`=61
- Ivars: `_friendData:@"NSValue"@56`, `_isAnimationing:c@60`

### `FriendListViewController`  — ✅ complete

- Methods: **12 / 12** reconstructed (0 missing) · Ivars: 6 · `instanceSize`=188
- Ivars: `_dummyView:@"UIViewController"@164`, `_sortButton:@"UIButton"@168`, `_lonelyImageView:@"UIImageView"@172`, `_detailView:@"FriendListDetail"@176`, `_isBestScoreSort:c@180`, `_frinedDataArray:@"NSArray"@184`

### `FriendReplyViewController`  — ✅ complete

- Methods: **17 / 17** reconstructed (0 missing) · Ivars: 8 · `instanceSize`=196
- Ivars: `_dummyView:@"UIViewController"@164`, `_lonelyImageView:@"UIImageView"@168`, `_headView:@"UIView"@172`, `_lonelyHeadView:@"UIView"@176`, `dlGetFriendRequest:@"Downloader"@180`, `_receiveDataArray:@"NSMutableArray"@184`, `dlReplyFriend:@"Downloader"@188`, `_replyPlayerId:@"NSString"@192`

### `HowToView`  — ✅ complete

- Methods: **3 / 3** reconstructed (0 missing) · Ivars: 2 · `instanceSize`=60
- Ivars: `_imageList:@"NSArray"@52`, `_bgImage:@"UIImage"@56`

### `OverScoreData`  — ✅ complete

- Methods: **0 / 0** reconstructed (0 missing) · Ivars: 0 · `instanceSize`=48

### `ScoreData`  — ✅ complete

- Methods: **0 / 0** reconstructed (0 missing) · Ivars: 0 · `instanceSize`=48

### `SettingCustomerTableViewController`  — ✅ complete

- Methods: **14 / 14** reconstructed (0 missing) · Ivars: 2 · `instanceSize`=168
- Ivars: `_isAnimationing:c@162`, `_policyView:@"UINavigationController"@164`

### `SettingGameTableViewController`  — ✅ complete

- Methods: **17 / 17** reconstructed (0 missing) · Ivars: 4 · `instanceSize`=288
- Ivars: `_isAnimationing:c@162`, `_selectedIndexPath:@"NSIndexPath"@164`, `_detailView:[6@"UIViewController"]@168`, `_dummyFrm:[6{CGRect="origin"{CGPoint="x"f"y"f}"size"{CGSize="width"f"height"f}}]@192`

### `SettingHowtoTableViewController`  — ✅ complete

- Methods: **14 / 14** reconstructed (0 missing) · Ivars: 2 · `instanceSize`=168
- Ivars: `_isAnimationing:c@162`, `howtoViewCtrlPad:@"HowToViewCtrlPad"@164`

### `StoreUtil`  — ✅ complete

- Methods: **0 / 0** reconstructed (0 missing) · Ivars: 0 · `instanceSize`=4

### `TreasureData`  — ✅ complete

- Methods: **1 / 1** reconstructed (0 missing) · Ivars: 0 · `instanceSize`=48

### `UserSettingData`  — ✅ complete

- Methods: **0 / 0** reconstructed (0 missing) · Ivars: 0 · `instanceSize`=4

### `neTextureForiOS`  — ✅ complete

- Methods: **0 / 0** reconstructed (0 missing) · Ivars: 0 · `instanceSize`=4
