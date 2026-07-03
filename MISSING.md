# PopnRhythmin — Exhaustive Missing Inventory

Machine-generated from Ghidra **rb420 / PopnRhythmin** (`__objc_classlist` walk) diffed against the
reconstructed `@ 0x…` annotations in `Project/`. Self-updating: rebuild `.audit/recon.txt`, then run
`python3 .audit/gen_missing.py`.

## Totals — app Objective-C classes

| Metric | Count |
| --- | ---: |
| Classes audited | 173 |
| Complete | 164 |
| Partial (file exists, methods missing) | 0 |
| Fully missing (no source file) | 9 |
| **Missing methods** | **227** |

## Scope decisions

| Component | Owner | Action |
| --- | --- | --- |
| TouchJSON (`CJSON*`, `CDataScanner`, `CSerializedJSONData`) | ours | reconstruct |
| `RewardNetwork*` / `Recommend*` | ours (Konami ad SDK) | reconstruct (may stub first) |
| `BFCodec` (Blowfish) | ours | reconstruct |
| `UnZipArchive` (ZipArchive) | 3rd-party ([ziparchive](https://code.google.com/archive/p/ziparchive/)) | **exclude** |

## Fully missing classes — 9

| Class | Methods | Ivars | `instanceSize` |
| --- | ---: | ---: | ---: |
| `SearchView` | 30 | 17 | `251` |
| `RecommendCore` | 29 | 7 | `32` |
| `InputConversionPassViewController` | 27 | 6 | `188` |
| `InputKIDViewCtrl` | 26 | 11 | `208` |
| `MapSelectViewController` | 24 | 10 | `204` |
| `FriendScoreMainView` | 23 | 12 | `212` |
| `MapSelectSplitViewController` | 23 | 20 | `248` |
| `RecommendWebView` | 23 | 7 | `76` |
| `InputNameViewCtrl` | 22 | 4 | `177` |

## Partial classes — 0

| Class | Done | Total | Missing (binary + unimpl) |
| --- | ---: | ---: | ---: |

## Complete classes — 164

- `AcMusicData`
- `AcViewerCategoryCell`
- `AcViewerCategoryViewController`
- `AcViewerDetailCell`
- `AcViewerHiSpeedViewController`
- `AcViewerHidSudViewController`
- `AcViewerMusicCell`
- `AcViewerMusicViewController`
- `AcViewerOptionCell`
- `AcViewerOptionViewController`
- `AcViewerPopKunViewController`
- `AcViewerRanMirViewController`
- `AcViewerSplitViewController`
- `AcceptPolicyViewController`
- `AppDelegate`
- `ArcadeScoreData`
- `AudioManager`
- `BFCodec`
- `BirthDayViewController`
- `CDataScanner`
- `CJSONDataSerializer`
- `CJSONDeserializer`
- `CJSONScanner`
- `CJSONSerializer`
- `CSerializedJSONData`
- `CharaInfo`
- `CharaTicketData`
- `CheckerCategoryCell`
- `CheckerCategoryViewController`
- `CheckerDetail`
- `CheckerMusicCell`
- `CheckerMusicViewController`
- `CommonAlertView`
- `CommunicatingView`
- `ConversionView`
- `CustomAlertView`
- `CustomButton`
- `CustomSplitViewController`
- `CustomTextView`
- `CustomWebView`
- `DefaultDataDownloadView`
- `DelayImageView`
- `DevDataDownloader`
- `DownloadImageView`
- `DownloadMain`
- `DownloadProgresView`
- `Downloader`
- `FreeRequestDetail`
- `FreeRequestListCell`
- `FreeRequestListViewController`
- `FriendListCell`
- `FriendListDetail`
- `FriendListDetailChara`
- `FriendListViewController`
- `FriendMngTopSplitViewController`
- `FriendMngTopViewController`
- `FriendReplyCell`
- `FriendReplyViewController`
- `FriendRequestCell`
- `FriendRequestTable`
- `FriendRequestViewController`
- `FriendScoreTableCell`
- `GameEffectView`
- `HowToView`
- `HowToViewCtrl`
- `HowToViewCtrlPad`
- `HttpConn`
- `ImageDownloader`
- `InputKidViewController`
- `InputOTPViewCtrl`
- `InviteTopViewController`
- `InviteTopViewControllerPad`
- `LimitedCharaInfo`
- `LoginBonusView`
- `MainViewController`
- `MapAnnotation`
- `MapListCell`
- `MusicData`
- `MusicManager`
- `MusicPatch`
- `MyInviteCodeViewController`
- `OverScoreData`
- `OverScoreLogCell`
- `OverScoreLogViewController`
- `PolicyView`
- `PopkunSizeViewCtrl`
- `PopnLinkTopSplitViewController`
- `PopnLinkTopViewController`
- `PreferredCharaInfo`
- `PresentBoxCell`
- `PresentBoxViewController`
- `PurchaseManager`
- `PurchaseStore`
- `PurchaseTransactionCache`
- `QuizCell`
- `QuizMainViewController`
- `RandomLoginBonusView`
- `RecommendAdId`
- `RecommendListCell`
- `RecommendNetwork`
- `RecommendViewController`
- `RecommendWebAPI`
- `RecommendWebViewController`
- `RewardNetwork`
- `RewardNetworkError`
- `RewardNetworkIndicator`
- `RewardNetworkMessage`
- `RewardNetworkPasteBoard`
- `RewardNetworkURLConnection`
- `RewardNetworkUdid`
- `RewardNetworkUtilities`
- `RewardNetworkWebAPI`
- `RewardNetworkWebViewController`
- `ScoreData`
- `SettingCustomerTableViewController`
- `SettingGameTableViewController`
- `SettingHowtoTableViewController`
- `SettingOtherTableViewController`
- `SettingTableSplitViewController`
- `SettingTableViewController`
- `SettingTopViewController`
- `SortCell`
- `SortSelectViewController`
- `SoundSettingView`
- `StoreAcMusicInfo`
- `StoreAcvManageViewController`
- `StoreDetailCopyrightCell`
- `StoreDetailHeaderView`
- `StoreDetailMusicCell`
- `StoreDetailViewController`
- `StoreDialogView`
- `StoreDownloadManager`
- `StoreDownloadTask`
- `StoreImageView`
- `StoreMainViewController`
- `StoreManageViewController`
- `StoreMusicInfo`
- `StorePackCell`
- `StorePackDetailViewPad`
- `StorePackInfo`
- `StorePackInfoDownloader`
- `StorePackListController`
- `StorePackMusicView`
- `StorePackView`
- `StorePromotionTableCell`
- `StorePromotionView`
- `StoreTableCell`
- `StoreUtil`
- `StoreViewController`
- `SubMapListCell`
- `SubMapSelectViewController`
- `SystemHardware`
- `TouchRangeView`
- `TouchRangeViewCtrl`
- `TouchableScrollView`
- `TouchableTableView`
- `TreasureData`
- `TwitterUtil`
- `UserSettingData`
- `ViewUtility`
- `YearAndMonthPicker`
- `neGLView`
- `neTextureForiOS`
- `neWindow`

---

# Per-class detail

### `SearchView` — ❌ missing

Methods **0/30** · unimpl 0 · ivars 17 · `instanceSize`=`251`

#### Missing methods (in binary, not reconstructed)

| Selector | Address |
| --- | --- |
| `initAtNavigationController` | `0x85538` |
| `dealloc` | `0x85888` |
| `viewDidLoad` | `0x85a58` |
| `didReceiveMemoryWarning` | `0x861f8` |
| `viewWillDisappear:` | `0x86224` |
| `showError:` | `0x863a0` |
| `gotoCurrentPosition` | `0x864b8` |
| `startSearchMaster` | `0x8650c` |
| `startGameCenter:` | `0x865ec` |
| `addIndicator` | `0x867a4` |
| `subIndicator` | `0x867dc` |
| `downloadMarkImage` | `0x86810` |
| `onCurrentPosButton` | `0x86990` |
| `mapViewWillStartLoadingMap:` | `0x86a48` |
| `mapViewDidFinishLoadingMap:` | `0x86a4c` |
| `mapViewDidFailLoadingMap:withError:` | `0x86a50` |
| `mapView:regionWillChangeAnimated:` | `0x86a54` |
| `mapView:regionDidChangeAnimated:` | `0x86a58` |
| `mapView:viewForAnnotation:` | `0x870b0` |
| `mapView:annotationView:calloutAccessoryControlTapped:` | `0x87318` |
| `commonAlertView:clickedButtonAtIndex:` | `0x87520` |
| `downloaderFinished:` | `0x875a0` |
| `downloaderError:` | `0x8830c` |
| `imageDownloader:didLoad:` | `0x88398` |
| `imageDownloaderDidFail:didLoad:` | `0x88740` |
| `backButtonFunc` | `0x8879c` |
| `startOpenAnimation` | `0x88838` |
| `endOpenAnimation` | `0x88964` |
| `startCloseAnimation` | `0x88978` |
| `endCloseAnimation` | `0x88a98` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Map` | `MKMapView *` | `0xa4` |
| `m_Indicator` | `UIActivityIndicatorView *` | `0xa8` |
| `m_IndicatorCount` | `int` | `0xac` |
| `m_MessageLabel` | `UILabel *` | `0xb0` |
| `m_ErrorLabel` | `UILabel *` | `0xb4` |
| `m_MasterDownloader` | `Downloader *` | `0xb8` |
| `m_ListDownloader` | `Downloader *` | `0xbc` |
| `m_ImageDownloader` | `ImageDownloader *` | `0xc0` |
| `m_Info` | `NSMutableDictionary *` | `0xc4` |
| `m_Models` | `NSMutableArray *` | `0xc8` |
| `m_ModelNameForArrayIndex` | `NSMutableDictionary *` | `0xcc` |
| `m_LastRegion` | `struct ?` | `0xd0` |
| `m_DictSpot` | `NSMutableDictionary *` | `0xf0` |
| `m_GoogleMapURL` | `NSString *` | `0xf4` |
| `m_LoadedMaster` | `BOOL` | `0xf8` |
| `m_LoadedImages` | `BOOL` | `0xf9` |
| `m_IsAnimationing` | `BOOL` | `0xfa` |

### `RecommendCore` — ❌ missing

Methods **0/29** · unimpl 0 · ivars 7 · `instanceSize`=`32`

#### Missing methods (in binary, not reconstructed)

| Selector | Address |
| --- | --- |
| `init` | `0xfc33c` |
| `getCountryCode` | `0xfc628` |
| `getCategoryId` | `0xfc638` |
| `isInitialized` | `0xfc648` |
| `isInstalledAppliWithScheme:` | `0xfc664` |
| `startWithCountryCode:categoryId:env:callback:` | `0xfc734` |
| `openAppliListWithCallback:` | `0xfcc0c` |
| `appliListWithCallBack:` | `0xfd1c8` |
| `closeAppliList` | `0xfd630` |
| `postApplicationInstallWithAdIdFrom:countryCode:categoryId:adType:callback:` | `0xfd688` |
| `setParentView:delegate:` | `0xfdb28` |
| `setNavigationBarHidden:` | `0xfdc1c` |
| `redirectWithRequest:` | `0xfdc2c` |
| `rotateAppliListWithInterfaceOrientation:duration:` | `0xfe4e4` |
| `appListDidAppear` | `0xfe56c` |
| `appListDidDisappear` | `0xfe570` |
| `appListFailLoadWithError:` | `0xfe610` |
| `callbackForOpenAppliList` | `0xfe660` |
| `setCallbackForOpenAppliList:` | `0xfe674` |
| `categoryId` | `0xfe698` |
| `setCategoryId:` | `0xfe6a8` |
| `lastErrorForOpenAppliList` | `0xfe6d0` |
| `setLastErrorForOpenAppliList:` | `0xfe6e0` |
| `webViewController` | `0xfe708` |
| `setWebViewController:` | `0xfe718` |
| `initializeFlg` | `0xfe740` |
| `setInitializeFlg:` | `0xfe750` |
| `countryCode` | `0xfe760` |
| `setCountryCode:` | `0xfe770` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `navigationBarHidden` | `BOOL` | `0x4` |
| `_callbackForOpenAppliList` | `@?` | `0x8` |
| `_categoryId` | `NSString *` | `0xc` |
| `_lastErrorForOpenAppliList` | `NSError *` | `0x10` |
| `_webViewController` | `RecommendWebViewController *` | `0x14` |
| `_initializeFlg` | `int` | `0x18` |
| `_countryCode` | `NSString *` | `0x1c` |

### `InputConversionPassViewController` — ❌ missing

Methods **0/27** · unimpl 0 · ivars 6 · `instanceSize`=`188`

#### Missing methods (in binary, not reconstructed)

| Selector | Address |
| --- | --- |
| `init` | `0x911d0` |
| `initAtNavigationController` | `0x91e84` |
| `dealloc` | `0x92064` |
| `onBackBtn` | `0x920b4` |
| `startOpenAnimation` | `0x920e8` |
| `endOpenAnimation` | `0x92220` |
| `startCloseAnimation` | `0x92238` |
| `endCloseAnimation` | `0x92368` |
| `didReceiveMemoryWarning` | `0x9240c` |
| `viewDidLoad` | `0x92438` |
| `viewDidUnload` | `0x92464` |
| `viewWillAppear:` | `0x92490` |
| `viewDidAppear:` | `0x924bc` |
| `viewWillDisappear:` | `0x924e8` |
| `viewDidDisappear:` | `0x92514` |
| `shouldAutorotateToInterfaceOrientation:` | `0x92540` |
| `textFieldShouldBeginEditing:` | `0x9254c` |
| `textFieldShouldReturn:` | `0x92550` |
| `touchedDecideButton:` | `0x925a4` |
| `textField:shouldChangeCharactersInRange:replacementString:` | `0x92664` |
| `downloaderFinished:` | `0x926e0` |
| `downloaderError:` | `0x93938` |
| `startConversionHttpWithId:pass:` | `0x93a00` |
| `checkUsableCharacterForId:` | `0x93c38` |
| `checkUsableCharacterForPass:` | `0x93cf0` |
| `commonAlertView:clickedButtonAtIndex:` | `0x93d80` |
| `handleTapCoverView` | `0x93d90` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_idField` | `UITextField *` | `0xa4` |
| `_passField` | `UITextField *` | `0xa8` |
| `_indicator` | `UIActivityIndicatorView *` | `0xac` |
| `_downloader` | `Downloader *` | `0xb0` |
| `m_IsAnimationing` | `BOOL` | `0xb4` |
| `_coverView` | `UIView *` | `0xb8` |

### `InputKIDViewCtrl` — ❌ missing

Methods **0/26** · unimpl 0 · ivars 11 · `instanceSize`=`208`

#### Missing methods (in binary, not reconstructed)

| Selector | Address |
| --- | --- |
| `init` | `0xd5888` |
| `didReceiveMemoryWarning` | `0xd66e8` |
| `dealloc` | `0xd6714` |
| `viewDidLoad` | `0xd67ec` |
| `viewDidUnload` | `0xd6818` |
| `viewWillAppear:` | `0xd6844` |
| `viewDidAppear:` | `0xd6870` |
| `viewWillDisappear:` | `0xd689c` |
| `viewDidDisappear:` | `0xd68c8` |
| `shouldAutorotateToInterfaceOrientation:` | `0xd68f4` |
| `textFieldShouldBeginEditing:` | `0xd6900` |
| `textFieldDidEndEditing:` | `0xd6904` |
| `textFieldShouldReturn:` | `0xd6948` |
| `touchedDecideButton:` | `0xd69b0` |
| `touchedBackButton:` | `0xd6af8` |
| `endDirectCloseAnimation` | `0xd6c90` |
| `textField:shouldChangeCharactersInRange:replacementString:` | `0xd6cec` |
| `downloaderFinished:` | `0xd6d90` |
| `downloaderError:` | `0xd6fa8` |
| `startLinkKidHttp` | `0xd7088` |
| `commonAlertView:clickedButtonAtIndex:` | `0xd7284` |
| `keyboardWasShown:` | `0xd72e4` |
| `keyboardWillBeHidden:` | `0xd7328` |
| `touchesBegan:withEvent:` | `0xd7358` |
| `delegate` | `0xd73f4` |
| `setDelegate:` | `0xd7404` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_scrollView` | `TouchableScrollView *` | `0xa4` |
| `_kidField` | `UITextField *` | `0xa8` |
| `_passField` | `UITextField *` | `0xac` |
| `_otpField` | `UITextField *` | `0xb0` |
| `_dummyView` | `UIViewController *` | `0xb4` |
| `_downloader` | `Downloader *` | `0xb8` |
| `oldKonamiId` | `NSString *` | `0xbc` |
| `oldPassword` | `NSString *` | `0xc0` |
| `_scrollOffset` | `float` | `0xc4` |
| `_isAninationing` | `BOOL` | `0xc8` |
| `_delegate` | `<PopnLinkTopSplitViewControllerDelegate> *` | `0xcc` |

### `MapSelectViewController` — ❌ missing

Methods **0/24** · unimpl 0 · ivars 10 · `instanceSize`=`204`

#### Missing methods (in binary, not reconstructed)

| Selector | Address |
| --- | --- |
| `initWithStyle:` | `0xbec60` |
| `initAtNavigationController` | `0xbf498` |
| `dealloc` | `0xbf7a8` |
| `viewDidLoad` | `0xbf980` |
| `didReceiveMemoryWarning` | `0xbf9e0` |
| `viewDidAppear:` | `0xbfa0c` |
| `startOpenAnimation` | `0xbfa38` |
| `endOpenAnimation` | `0xbfb70` |
| `startCloseAnimation` | `0xbfb88` |
| `endCloseAnimation` | `0xbfc90` |
| `numberOfSectionsInTableView:` | `0xbfcec` |
| `tableView:numberOfRowsInSection:` | `0xbfcf0` |
| `tableView:cellForRowAtIndexPath:` | `0xbfd18` |
| `tableView:titleForHeaderInSection:` | `0xbfe40` |
| `tableView:didSelectRowAtIndexPath:` | `0xbfe44` |
| `scrollViewDidScroll:` | `0xc0098` |
| `downloadMainFinished:` | `0xc00bc` |
| `backButtonFunc` | `0xc00fc` |
| `updateEventInfo` | `0xc0190` |
| `mapSelectDelegate` | `0xc0768` |
| `setMapSelectDelegate:` | `0xc0778` |
| `treasureDataArray` | `0xc0788` |
| `mapHeadArray` | `0xc079c` |
| `mapDataArray` | `0xc07b0` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyHeadView` | `UIView *` | `0xa4` |
| `_eventHeadView` | `UIView *` | `0xa8` |
| `_dummyView` | `UIViewController *` | `0xac` |
| `_treasureDataArray` | `NSArray *` | `0xb0` |
| `_mapHeadArray` | `NSArray *` | `0xb4` |
| `_mapDataArray` | `NSArray *` | `0xb8` |
| `_isAnimationing` | `BOOL` | `0xbc` |
| `_eventIds` | `NSMutableArray *` | `0xc0` |
| `_mapSelectDelegate` | `<MapSelectViewControllerDelegate> *` | `0xc4` |
| `_selectedIndexRow` | `int` | `0xc8` |

### `FriendScoreMainView` — ❌ missing

Methods **0/23** · unimpl 0 · ivars 12 · `instanceSize`=`212`

#### Missing methods (in binary, not reconstructed)

| Selector | Address |
| --- | --- |
| `initAtNavigationControllerWithMusicId:` | `0xa9df0` |
| `dealloc` | `0xabdd8` |
| `viewDidLoad` | `0xabef8` |
| `didReceiveMemoryWarning` | `0xabf9c` |
| `startOpenAnimation` | `0xabfc8` |
| `endOpenAnimation` | `0xac120` |
| `startCloseAnimation` | `0xac138` |
| `endCloseAnimation` | `0xac270` |
| `numberOfSectionsInTableView:` | `0xac384` |
| `tableView:numberOfRowsInSection:` | `0xac388` |
| `tableView:cellForRowAtIndexPath:` | `0xac45c` |
| `tableView:didSelectRowAtIndexPath:` | `0xac74c` |
| `downloaderFinished:` | `0xac7f0` |
| `downloaderProceed:` | `0xadc10` |
| `downloaderError:` | `0xadc14` |
| `downloadMainFinished:` | `0xadcec` |
| `tabBarController:didSelectViewController:` | `0xaddc0` |
| `onBackButtonTouched` | `0xaddf4` |
| `releaseFriendScore` | `0xade6c` |
| `startGetFriendScoreHttp` | `0xadee4` |
| `isAnimationing` | `0xae028` |
| `musicId` | `0xae040` |
| `setMusicId:` | `0xae054` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_tabCtrl` | `UITabBarController *` | `0xa4` |
| `_tblViewCtrlN` | `UITableViewController *` | `0xa8` |
| `_tblViewCtrlH` | `UITableViewController *` | `0xac` |
| `_tblViewCtrlEx` | `UITableViewController *` | `0xb0` |
| `_dummyView` | `UIViewController *` | `0xb4` |
| `_selectedView` | `UIViewController *` | `0xb8` |
| `_dlGetFriendScore` | `Downloader *` | `0xbc` |
| `_frScoreNArray` | `NSArray *` | `0xc0` |
| `_frScoreHArray` | `NSArray *` | `0xc4` |
| `_frScoreExArray` | `NSArray *` | `0xc8` |
| `_isAnimationing` | `BOOL` | `0xcc` |
| `_musicId` | `unsigned int` | `0xd0` |

### `MapSelectSplitViewController` — ❌ missing

Methods **0/23** · unimpl 0 · ivars 20 · `instanceSize`=`248`

#### Missing methods (in binary, not reconstructed)

| Selector | Address |
| --- | --- |
| `init` | `0x754d8` |
| `dealloc` | `0x764dc` |
| `viewDidLoad` | `0x765dc` |
| `didReceiveMemoryWarning` | `0x76608` |
| `viewWillAppear:` | `0x76634` |
| `setSelectIndexPath:` | `0x766b8` |
| `startOpenAnimation` | `0x766e0` |
| `endOpenAnimation` | `0x7680c` |
| `startCloseAnimation` | `0x769c8` |
| `endCloseAnimation` | `0x76ad0` |
| `touchWithTreasureData:mapHeadArray:mainMapId:` | `0x76b40` |
| `scrollViewDidScroll:` | `0x77768` |
| `scrollViewWillBeginDragging:` | `0x77f00` |
| `scrollViewDidEndDecelerating:` | `0x77f28` |
| `scrollViewDidEndDragging:willDecelerate:` | `0x77f38` |
| `restartAutoScroll` | `0x77f50` |
| `restartAutoScrollAfterDelay` | `0x77f70` |
| `autoScroll` | `0x77fa4` |
| `downloadMainFinished:` | `0x7819c` |
| `updateEventInfo` | `0x781ac` |
| `pageControlDidChanged:` | `0x786fc` |
| `backButtonFunc` | `0x78794` |
| `isAnimationing` | `0x787d8` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_markView` | `UIImageView *` | `0xa4` |
| `_selectIndexPath` | `NSIndexPath *` | `0xa8` |
| `_mapSelectViewCtrl` | `MapSelectViewController *` | `0xac` |
| `_subMapSelectViewCtrl` | `SubMapSelectViewController *` | `0xb0` |
| `_arrowImageView` | `UIImageView *` | `0xb4` |
| `_arrowFrm` | `struct CGRect` | `0xb8` |
| `_rightImageView` | `UIImageView *` | `0xc8` |
| `_rightDummyView` | `UIView *` | `0xcc` |
| `_rightHeaderImageView` | `UIImageView *` | `0xd0` |
| `_rightHeaderLabel` | `UILabel *` | `0xd4` |
| `_rightHeaderDummyView` | `UIView *` | `0xd8` |
| `_rightEmptyImageView` | `UIImageView *` | `0xdc` |
| `_eventImageView` | `UIImageView *` | `0xe0` |
| `_eventDummyView` | `UIView *` | `0xe4` |
| `_scrollView` | `UIScrollView *` | `0xe8` |
| `_pageCtrl` | `UIPageControl *` | `0xec` |
| `_eventViewing` | `BOOL` | `0xf0` |
| `_autoScroll` | `BOOL` | `0xf1` |
| `_howtoViewCtrlPad` | `HowToViewCtrlPad *` | `0xf4` |

### `RecommendWebView` — ❌ missing

Methods **0/23** · unimpl 0 · ivars 7 · `instanceSize`=`76`

#### Missing methods (in binary, not reconstructed)

| Selector | Address |
| --- | --- |
| `init` | `0xfe808` |
| `removeFromSuperview` | `0xfe8a4` |
| `loadRequestWithCallback:` | `0xfe970` |
| `closeList` | `0xff098` |
| `cancelRequest` | `0xff0a8` |
| `setIndicatorwithEnable:` | `0xff0e0` |
| `setViewType:` | `0xff0f0` |
| `setScrollEnabled:` | `0xff100` |
| `loadRecommendView` | `0xff268` |
| `unloadRecommendView` | `0xff30c` |
| `webViewDidStartLoad:` | `0xff340` |
| `loadRequestWithURL:parameters:delegate:` | `0xff354` |
| `viewDidDisappear:` | `0xff494` |
| `webViewDidFinishLoad:` | `0xff574` |
| `setHidden:` | `0xff6bc` |
| `webView:didFailLoadWithError:` | `0xff6fc` |
| `appliListClosed` | `0xff828` |
| `updateIndicator:` | `0xff86c` |
| `webView:shouldStartLoadWithRequest:navigationType:` | `0xff8a8` |
| `callbackForOpenAppliList` | `0xff904` |
| `setCallbackForOpenAppliList:` | `0xff918` |
| `lastErrorForOpenAppliList` | `0xff93c` |
| `setLastErrorForOpenAppliList:` | `0xff94c` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `parentView` | `UIView *` | `0x34` |
| `_indicator` | `RewardNetworkIndicator *` | `0x38` |
| `isIndicator` | `BOOL` | `0x3c` |
| `nowHidden` | `BOOL` | `0x3d` |
| `_viewType` | `int` | `0x40` |
| `_callbackForOpenAppliList` | `@?` | `0x44` |
| `_lastErrorForOpenAppliList` | `NSError *` | `0x48` |

### `InputNameViewCtrl` — ❌ missing

Methods **0/22** · unimpl 0 · ivars 4 · `instanceSize`=`177`

#### Missing methods (in binary, not reconstructed)

| Selector | Address |
| --- | --- |
| `init` | `0x8f438` |
| `initAtNavigationController` | `0x90668` |
| `startOpenAnimation` | `0x90740` |
| `endOpenAnimation` | `0x90878` |
| `startCloseAnimation` | `0x90890` |
| `endCloseAnimation` | `0x90998` |
| `didReceiveMemoryWarning` | `0x90a28` |
| `viewDidLoad` | `0x90a54` |
| `viewDidUnload` | `0x90a80` |
| `viewWillAppear:` | `0x90aac` |
| `viewDidAppear:` | `0x90ad8` |
| `viewWillDisappear:` | `0x90b04` |
| `viewDidDisappear:` | `0x90b30` |
| `shouldAutorotateToInterfaceOrientation:` | `0x90b5c` |
| `textFieldShouldBeginEditing:` | `0x90b68` |
| `textFieldShouldReturn:` | `0x90b6c` |
| `touchedDecideButton:` | `0x90b94` |
| `textField:shouldChangeCharactersInRange:replacementString:` | `0x90c10` |
| `downloaderFinished:` | `0x90c4c` |
| `downloaderError:` | `0x90e48` |
| `startPlayerNewHttp:` | `0x90f14` |
| `checkUsableCharacter:` | `0x91108` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_nameField` | `UITextField *` | `0xa4` |
| `_indicator` | `UIActivityIndicatorView *` | `0xa8` |
| `_downloader` | `Downloader *` | `0xac` |
| `m_IsAnimationing` | `BOOL` | `0xb0` |

### `AcMusicData` — ✅ complete

Methods **31/31** · unimpl 0 · ivars 17 · `instanceSize`=`72`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_filePath` | `NSString *` | `0x4` |
| `m_acMusicId` | `int` | `0x8` |
| `m_lvEasy` | `int` | `0xc` |
| `m_lvNormal` | `int` | `0x10` |
| `m_lvHyper` | `int` | `0x14` |
| `m_lvEx` | `int` | `0x18` |
| `m_bpmEasy` | `NSString *` | `0x1c` |
| `m_bpmNormal` | `NSString *` | `0x20` |
| `m_bpmHyper` | `NSString *` | `0x24` |
| `m_bpmEx` | `NSString *` | `0x28` |
| `m_category` | `int` | `0x2c` |
| `m_musicName` | `NSString *` | `0x30` |
| `m_musicNameKana` | `NSString *` | `0x34` |
| `m_genreName` | `NSString *` | `0x38` |
| `m_genreNameKana` | `NSString *` | `0x3c` |
| `m_musicNameInitial` | `NSString *` | `0x40` |
| `m_genreNameInitial` | `NSString *` | `0x44` |

### `AcViewerCategoryCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 0 · `instanceSize`=`52`

### `AcViewerCategoryViewController` — ✅ complete

Methods **18/18** · unimpl 0 · ivars 3 · `instanceSize`=`268`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_acMusicDataArray` | `NSArray *[24]` | `0xa4` |
| `_isAnimationing` | `BOOL` | `0x104` |
| `_delegate` | `<AcViewerViewControllerDelegate> *` | `0x108` |

### `AcViewerDetailCell` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 5 · `instanceSize`=`72`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_optionLbl` | `UILabel *` | `0x34` |
| `_checkImageView` | `UIImageView *` | `0x38` |
| `_optionName` | `NSString *` | `0x3c` |
| `_optionKind` | `int` | `0x40` |
| `_index` | `int` | `0x44` |

### `AcViewerHiSpeedViewController` — ✅ complete

Methods **10/10** · unimpl 0 · ivars 0 · `instanceSize`=`162`

### `AcViewerHidSudViewController` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 0 · `instanceSize`=`162`

### `AcViewerMusicCell` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 13 · `instanceSize`=`104`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_bgImgView` | `UIImageView *` | `0x34` |
| `_titleLbl` | `UILabel *` | `0x38` |
| `_lvEsLbl` | `UILabel *` | `0x3c` |
| `_lvNLbl` | `UILabel *` | `0x40` |
| `_lvHLbl` | `UILabel *` | `0x44` |
| `_lvExLbl` | `UILabel *` | `0x48` |
| `_easyBtn` | `UIButton *` | `0x4c` |
| `_normalBtn` | `UIButton *` | `0x50` |
| `_hyperBtn` | `UIButton *` | `0x54` |
| `_exBtn` | `UIButton *` | `0x58` |
| `isPad` | `BOOL` | `0x5c` |
| `offsetForPad1` | `int` | `0x60` |
| `offsetForPad2` | `int` | `0x64` |

### `AcViewerMusicViewController` — ✅ complete

Methods **15/15** · unimpl 0 · ivars 5 · `instanceSize`=`184`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_acMusicDataArray` | `NSArray *` | `0xa4` |
| `_genreButton` | `UIImage *` | `0xa8` |
| `_titleButton` | `UIImage *` | `0xac` |
| `_changeButton` | `UIButton *` | `0xb0` |
| `_delegate` | `<AcViewerViewControllerDelegate> *` | `0xb4` |

### `AcViewerOptionCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 2 · `instanceSize`=`60`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_optionKindLbl` | `UILabel *` | `0x34` |
| `_optionDetailLbl` | `UILabel *` | `0x38` |

### `AcViewerOptionViewController` — ✅ complete

Methods **21/21** · unimpl 0 · ivars 5 · `instanceSize`=`180`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_naviCtrl` | `UINavigationController *` | `0xa4` |
| `_forAcMain` | `BOOL` | `0xa8` |
| `_isAnimationing` | `BOOL` | `0xa9` |
| `_pAcMain` | `struct AcMainTask *` | `0xac` |
| `_delegate` | `<AcViewerViewControllerDelegate> *` | `0xb0` |

### `AcViewerPopKunViewController` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 0 · `instanceSize`=`162`

### `AcViewerRanMirViewController` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 0 · `instanceSize`=`162`

### `AcViewerSplitViewController` — ✅ complete

Methods **15/15** · unimpl 0 · ivars 12 · `instanceSize`=`256`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_leftViewCtrl` | `UIViewController *` | `0xa4` |
| `_rightViewCtrl` | `UINavigationController *` | `0xa8` |
| `_arrowImageView` | `UIImageView *` | `0xac` |
| `_rightViewFrm` | `struct CGRect` | `0xb0` |
| `_categoryArrowFrm` | `struct CGRect` | `0xc0` |
| `_musicNameArrowFrm` | `struct CGRect` | `0xd0` |
| `_genreArrowFrm` | `struct CGRect` | `0xe0` |
| `_btnCategory` | `UIButton *` | `0xf0` |
| `_btnMusicName` | `UIButton *` | `0xf4` |
| `_btnGenre` | `UIButton *` | `0xf8` |
| `_selectedButton` | `UIButton *` | `0xfc` |

### `AcceptPolicyViewController` — ✅ complete

Methods **10/10** · unimpl 0 · ivars 5 · `instanceSize`=`180`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `isAnimationing` | `BOOL` | `0xa2` |
| `_topView` | `UIView *` | `0xa4` |
| `_detailView` | `UIImageView *` | `0xa8` |
| `_policyView` | `UINavigationController *` | `0xac` |
| `_naviCtrl` | `UINavigationController *` | `0xb0` |

### `AppDelegate` — ✅ complete

Methods **43/43** · unimpl 0 · ivars 17 · `instanceSize`=`72`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_window` | `neWindow *` | `0x4` |
| `_viewController` | `MainViewController *` | `0x8` |
| `_strageAlert` | `CommonAlertView *` | `0xc` |
| `_userAgent` | `NSString *` | `0x10` |
| `_hardwareType` | `int` | `0x14` |
| `_hardwareName` | `NSString *` | `0x18` |
| `_displayType` | `int` | `0x1c` |
| `_managedObjectContext` | `NSManagedObjectContext *` | `0x20` |
| `_managedObjectContextSub` | `NSManagedObjectContext *` | `0x24` |
| `_managedObjectModel` | `NSManagedObjectModel *` | `0x28` |
| `_persistentStoreCoordinator` | `NSPersistentStoreCoordinator *` | `0x2c` |
| `_products` | `NSArray *` | `0x30` |
| `_mainTask` | `void *` | `0x34` |
| `_acMainTask` | `void *` | `0x38` |
| `_isNecessaryToResume` | `bool` | `0x3c` |
| `_rewardAppId` | `NSString *` | `0x40` |
| `_getEventInfoTimer` | `NSTimer *` | `0x44` |

### `ArcadeScoreData` — ✅ complete

Methods **1/1** · unimpl 0 · ivars 0 · `instanceSize`=`48`

### `AudioManager` — ✅ complete

Methods **68/68** · unimpl 0 · ivars 23 · `instanceSize`=`380`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `sePlayer` | `struct CAPlayer *` | `0x4` |
| `seAVPlayer` | `struct AVPlayer *` | `0x8` |
| `seList` | `struct _SE_MANAGE_ID_[8]` | `0xc` |
| `seNameList` | `NSMutableArray *` | `0x6c` |
| `seRidList` | `NSMutableArray *` | `0x70` |
| `isStart` | `bool` | `0x74` |
| `isSuspend` | `bool` | `0x75` |
| `isInterruption` | `bool[2]` | `0x76` |
| `bgmPlayer` | `AVAudioPlayer *` | `0x78` |
| `isPlaying` | `bool[2]` | `0x7c` |
| `unitVolume` | `float` | `0x80` |
| `voicePlayer` | `AVAudioPlayer *` | `0x84` |
| `isOnPause` | `bool` | `0x88` |
| `fadeTimer` | `NSTimer *` | `0x8c` |
| `bgmPlayTime` | `double` | `0x90` |
| `voicePlayTime` | `double` | `0x98` |
| `isOnPauseVoice` | `bool` | `0xa0` |
| `pushBgm` | `AVAudioPlayer *` | `0xa4` |
| `seManageId` | `struct _SE_MANAGE_ID_[8][2]` | `0xa8` |
| `seVolume` | `int[2]` | `0x168` |
| `seType` | `NSMutableDictionary *` | `0x170` |
| `bgmSettingVolume` | `float` | `0x174` |
| `loadedBgmPath` | `NSString *` | `0x178` |

### `BFCodec` — ✅ complete

Methods **6/6** · unimpl 0 · ivars 2 · `instanceSize`=`16`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_iv` | `unsigned char[8]` | `0x4` |
| `_blf` | `struct C_BLOWFISH *` | `0xc` |

### `BirthDayViewController` — ✅ complete

Methods **13/13** · unimpl 0 · ivars 8 · `instanceSize`=`196`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_infoView` | `UIView *` | `0xa4` |
| `_selectDate` | `YearAndMonthPicker *` | `0xa8` |
| `_subView` | `UIView *` | `0xac` |
| `_delegate` | `id` | `0xb0` |
| `m_IsAnimationing` | `BOOL` | `0xb4` |
| `_borderView` | `UIView *` | `0xb8` |
| `_subBorderView` | `UIView *` | `0xbc` |
| `_dummyView` | `UIView *` | `0xc0` |

### `CDataScanner` — ✅ complete

Methods **22/22** · unimpl 0 · ivars 6 · `instanceSize`=`28`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `data` | `NSData *` | `0x4` |
| `start` | `char *` | `0x8` |
| `end` | `char *` | `0xc` |
| `current` | `char *` | `0x10` |
| `length` | `unsigned int` | `0x14` |
| `doubleCharacters` | `NSCharacterSet *` | `0x18` |

### `CJSONDataSerializer` — ✅ complete

Methods **6/6** · unimpl 0 · ivars 0 · `instanceSize`=`4`

### `CJSONDeserializer` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 0 · `instanceSize`=`4`

### `CJSONScanner` — ✅ complete

Methods **10/10** · unimpl 0 · ivars 1 · `instanceSize`=`29`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `strictEscapeCodes` | `BOOL` | `0x1c` |

### `CJSONSerializer` — ✅ complete

Methods **5/5** · unimpl 0 · ivars 1 · `instanceSize`=`8`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `serializer` | `CJSONDataSerializer *` | `0x4` |

### `CSerializedJSONData` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 1 · `instanceSize`=`8`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `data` | `NSData *` | `0x4` |

### `CharaInfo` — ✅ complete

Methods **13/13** · unimpl 0 · ivars 6 · `instanceSize`=`28`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_charaId` | `int` | `0x4` |
| `_charaName` | `NSString *` | `0x8` |
| `_info` | `NSString *` | `0xc` |
| `_skillId` | `int` | `0x10` |
| `_skillName` | `NSString *` | `0x14` |
| `_rarity` | `int` | `0x18` |

### `CharaTicketData` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`48`

### `CheckerCategoryCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 7 · `instanceSize`=`84`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_musicCntBaseView` | `UIImageView *` | `0x34` |
| `_musicCntNumView` | `UIImageView *[3]` | `0x38` |
| `_bgView` | `UIImageView *` | `0x44` |
| `isOS7` | `BOOL` | `0x48` |
| `isPad` | `BOOL` | `0x49` |
| `offsetXForPad` | `int` | `0x4c` |
| `imgMusicCntX` | `int` | `0x50` |

### `CheckerCategoryViewController` — ✅ complete

Methods **18/18** · unimpl 0 · ivars 3 · `instanceSize`=`272`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_scoreDataArray` | `NSArray *[25]` | `0xa8` |
| `_dlGetArcadeScoreData` | `Downloader *` | `0x10c` |

### `CheckerDetail` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 15 · `instanceSize`=`368`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_arcadeScoreData` | `ArcadeScoreData *` | `0xa4` |
| `_selectedSheet` | `int` | `0xa8` |
| `_isNameMode` | `bool` | `0xac` |
| `_scoreLineOff` | `UIImageView *[4]` | `0xb0` |
| `_scoreLineOn` | `UIImageView *[4]` | `0xc0` |
| `_topIconOff` | `UIImageView *[4]` | `0xd0` |
| `_topIconOn` | `UIImageView *[4]` | `0xe0` |
| `_meanIconOff` | `UIImageView *[4]` | `0xf0` |
| `_meanIconOn` | `UIImageView *[4]` | `0x100` |
| `_myIconOff` | `UIImageView *[4]` | `0x110` |
| `_myIconOn` | `UIImageView *[4]` | `0x120` |
| `_topScoreBase` | `UIImageView *[4]` | `0x130` |
| `_topNameBase` | `UIImageView *[4]` | `0x140` |
| `_meanBase` | `UIImageView *[4]` | `0x150` |
| `_myBase` | `UIImageView *[4]` | `0x160` |

### `CheckerMusicCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 10 · `instanceSize`=`92`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_scoreData` | `ArcadeScoreData *` | `0x34` |
| `_bgImg` | `UIImageView *` | `0x38` |
| `_dateLbl` | `UILabel *` | `0x3c` |
| `_titleLbl` | `UILabel *` | `0x40` |
| `_genreLbl` | `UILabel *` | `0x44` |
| `isOS7` | `bool` | `0x48` |
| `bgX` | `int` | `0x4c` |
| `dateX` | `int` | `0x50` |
| `titleX` | `int` | `0x54` |
| `genreX` | `int` | `0x58` |

### `CheckerMusicViewController` — ✅ complete

Methods **10/10** · unimpl 0 · ivars 1 · `instanceSize`=`168`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_scoreDataArray` | `NSArray *` | `0xa4` |

### `CommonAlertView` — ✅ complete

Methods **15/15** · unimpl 0 · ivars 7 · `instanceSize`=`80`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0x34` |
| `_titleView` | `UILabel *` | `0x38` |
| `_messageView` | `CustomTextView *` | `0x3c` |
| `_dummyView` | `UIView *` | `0x40` |
| `_delegate` | `<CommonAlertViewDelegate> *` | `0x44` |
| `_title` | `NSString *` | `0x48` |
| `_message` | `NSString *` | `0x4c` |

### `CommunicatingView` — ✅ complete

Methods **11/11** · unimpl 0 · ivars 5 · `instanceSize`=`178`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `communicatingView` | `UIImageView *` | `0xa4` |
| `communicateFailedView` | `UIImageView *` | `0xa8` |
| `indicatorView` | `UIActivityIndicatorView *` | `0xac` |
| `_isAnimationing` | `BOOL` | `0xb0` |
| `_isCloseReserve` | `BOOL` | `0xb1` |

### `ConversionView` — ✅ complete

Methods **20/20** · unimpl 0 · ivars 5 · `instanceSize`=`180`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `isAnimationing` | `BOOL` | `0xa2` |
| `_indicator` | `UIActivityIndicatorView *` | `0xa4` |
| `_downloader` | `Downloader *` | `0xa8` |
| `_delegate` | `<ViewCmnProtocol> *` | `0xac` |
| `_convertCodeStr` | `NSString *` | `0xb0` |

### `CustomAlertView` — ✅ complete

Methods **18/18** · unimpl 0 · ivars 6 · `instanceSize`=`80`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `mDelegate` | `<CustomAlertViewDelegate> *` | `0x38` |
| `mBgImageView` | `UIView *` | `0x3c` |
| `_title` | `UILabel *` | `0x40` |
| `_text` | `CustomTextView *` | `0x44` |
| `m_OpenAnimeType` | `int` | `0x48` |
| `m_CloseAnimeType` | `int` | `0x4c` |

### `CustomButton` — ✅ complete

Methods **5/5** · unimpl 0 · ivars 1 · `instanceSize`=`92`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_tappableInsets` | `struct UIEdgeInsets` | `0x4c` |

### `CustomSplitViewController` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 3 · `instanceSize`=`176`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_leftViewCtrl` | `UIViewController *` | `0xa4` |
| `m_rightViewCtrl` | `UIViewController *` | `0xa8` |
| `m_leftViewWidth` | `int` | `0xac` |

### `CustomTextView` — ✅ complete

Methods **4/4** · unimpl 0 · ivars 0 · `instanceSize`=`56`

### `CustomWebView` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 10 · `instanceSize`=`116`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_AlertViewCallback` | `void /*unknown*/ *` | `0x34` |
| `m_AlertViewCallbackParam` | `void *` | `0x38` |
| `_webView` | `UIWebView *` | `0x3c` |
| `_closeBtnSmall` | `UIButton *` | `0x40` |
| `_closeBtnBig` | `UIButton *` | `0x44` |
| `_indicator` | `UIActivityIndicatorView *` | `0x48` |
| `_errorTitle` | `NSString *` | `0x4c` |
| `_errorText` | `NSString *` | `0x50` |
| `webViewFrm` | `struct CGRect` | `0x54` |
| `smallBtnFrm` | `struct CGRect` | `0x64` |

### `DefaultDataDownloadView` — ✅ complete

Methods **16/16** · unimpl 0 · ivars 11 · `instanceSize`=`204`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_downloadView` | `DownloadProgresView *` | `0xa4` |
| `_dlFileListDataArray` | `NSArray *` | `0xa8` |
| `_downloader` | `Downloader *` | `0xac` |
| `_downloadingIdx` | `int` | `0xb0` |
| `_filePath` | `NSString *` | `0xb4` |
| `_fileSize` | `int` | `0xb8` |
| `_totalFileSize` | `int` | `0xbc` |
| `_downloadedFileSize` | `int` | `0xc0` |
| `_isFailed` | `BOOL` | `0xc4` |
| `_isAnimationing` | `BOOL` | `0xc5` |
| `_tryCnt` | `int` | `0xc8` |

### `DelayImageView` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 1 · `instanceSize`=`56`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `image` | `UIImage *` | `0x34` |

### `DevDataDownloader` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 6 · `instanceSize`=`25`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Downloader` | `Downloader *` | `0x4` |
| `m_Title` | `NSString *` | `0x8` |
| `m_FileName` | `NSString *` | `0xc` |
| `m_IsOld` | `BOOL` | `0x10` |
| `m_Delegate` | `<DevDataDownloaderDelegate> *` | `0x14` |
| `isAcv` | `BOOL` | `0x18` |

### `DownloadImageView` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 3 · `instanceSize`=`68`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_ImageURL` | `NSString *` | `0x38` |
| `m_ImageDownLoader` | `ImageDownloader *` | `0x3c` |
| `m_IndicatorView` | `UIActivityIndicatorView *` | `0x40` |

### `DownloadMain` — ✅ complete

Methods **119/119** · unimpl 0 · ivars 63 · `instanceSize`=`252`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `dlGetPlayer` | `Downloader *` | `0x4` |
| `_arcadePt` | `int` | `0x8` |
| `_friendRequestedCnt` | `int` | `0xc` |
| `_errorGetPlayer` | `int` | `0x10` |
| `_loginBonusId` | `int` | `0x14` |
| `_loginCnt` | `int` | `0x18` |
| `_isLoginCntUpdate` | `BOOL` | `0x1c` |
| `dlNews` | `Downloader *` | `0x20` |
| `_cppDelegateNews` | `struct ModeSelTask *` | `0x24` |
| `_lastNewsGetTime` | `NSDate *` | `0x28` |
| `_storeUpdateTime` | `NSString *` | `0x2c` |
| `_newsTextArray` | `NSArray *` | `0x30` |
| `_newsUrlArray` | `NSArray *` | `0x34` |
| `_informationDataArray` | `NSArray *` | `0x38` |
| `_serverYear` | `int` | `0x3c` |
| `_serverMonth` | `int` | `0x40` |
| `_serverDay` | `int` | `0x44` |
| `_serverHour` | `int` | `0x48` |
| `_serverMinute` | `int` | `0x4c` |
| `_serverSecond` | `int` | `0x50` |
| `_isNewMusicPackReleased` | `BOOL` | `0x54` |
| `dlSaveScore` | `Downloader *` | `0x58` |
| `_saveMusic` | `unsigned int` | `0x5c` |
| `_saveSheet` | `short` | `0x60` |
| `dlCancelFriend` | `Downloader *` | `0x64` |
| `_delegateCancelFriend` | `<DownloadMainDelegate> *` | `0x68` |
| `dlGetFriendList` | `Downloader *` | `0x6c` |
| `_delegateGetFriendList` | `<DownloadMainDelegate> *` | `0x70` |
| `_friendListArray` | `NSArray *` | `0x74` |
| `dlAddBlockList` | `Downloader *` | `0x78` |
| `dlGetBlockList` | `Downloader *` | `0x7c` |
| `_blPlayerIdArray` | `NSArray *` | `0x80` |
| `_blNameArray` | `NSArray *` | `0x84` |
| `dlDelBlockList` | `Downloader *` | `0x88` |
| `dlGetRecommendList` | `Downloader *` | `0x8c` |
| `_cppDelegateRecommendList` | `struct MusicSelTask *` | `0x90` |
| `_recommendDataArray` | `NSArray *` | `0x94` |
| `dlGetVisitor` | `Downloader *` | `0x98` |
| `_delegateGetVisitor` | `<DownloadMainDelegate> *` | `0x9c` |
| `_isGetVisitorSuccess` | `BOOL` | `0xa0` |
| `dlGetPresentList` | `Downloader *` | `0xa4` |
| `_delegateGetPresentList` | `<DownloadMainDelegate> *` | `0xa8` |
| `_presentDataArray` | `NSArray *` | `0xac` |
| `dlGetPresent` | `Downloader *` | `0xb0` |
| `_delegateGetPresent` | `<DownloadMainDelegate> *` | `0xb4` |
| `_getPresentId` | `int` | `0xb8` |
| `dlGetOverScoreLog` | `Downloader *` | `0xbc` |
| `_delegateGetOverScoreLog` | `<DownloadMainDelegate> *` | `0xc0` |
| `_overScoreLogArray` | `NSArray *` | `0xc4` |
| `dlSaveTreasure` | `Downloader *` | `0xc8` |
| `dlGetDlFileList` | `Downloader *` | `0xcc` |
| `_dlFileListDataArray` | `NSArray *` | `0xd0` |
| `dlGetEventInfo` | `Downloader *` | `0xd4` |
| `_delegateGetEventInfo` | `<DownloadMainDelegate> *` | `0xd8` |
| `_treasureEventIdArray` | `NSArray *` | `0xdc` |
| `_gameEventIdArray` | `NSArray *` | `0xe0` |
| `_isTreasureEventInfoUpdated` | `BOOL` | `0xe4` |
| `_isGameEventInfoUpdated` | `BOOL` | `0xe5` |
| `_frSendPlayerIdArray` | `NSArray *` | `0xe8` |
| `_frSendNameArray` | `NSArray *` | `0xec` |
| `_frReceivePlayerIdArray` | `NSArray *` | `0xf0` |
| `_frReceiveNameArray` | `NSArray *` | `0xf4` |
| `_frReceiveMessageArray` | `NSArray *` | `0xf8` |

### `DownloadProgresView` — ✅ complete

Methods **6/6** · unimpl 0 · ivars 4 · `instanceSize`=`80`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_indicatorView` | `UIActivityIndicatorView *` | `0x34` |
| `_labelMessage` | `UILabel *` | `0x38` |
| `_progressView` | `UIProgressView *` | `0x3c` |
| `_dialogFrame` | `struct CGRect` | `0x40` |

### `Downloader` — ✅ complete

Methods **16/16** · unimpl 0 · ivars 7 · `instanceSize`=`36`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Request` | `NSMutableURLRequest *` | `0x4` |
| `m_Connection` | `NSURLConnection *` | `0x8` |
| `m_DownloadSize` | `long long` | `0xc` |
| `m_DownloadedData` | `NSMutableData *` | `0x14` |
| `m_Delegate` | `<DownloaderDelegate> *` | `0x18` |
| `m_AdditionalData` | `NSObject *` | `0x1c` |
| `m_StartTime` | `NSDate *` | `0x20` |

### `FreeRequestDetail` — ✅ complete

Methods **16/16** · unimpl 0 · ivars 6 · `instanceSize`=`72`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIView *` | `0x34` |
| `_friendData` | `NSValue *` | `0x38` |
| `_isAnimationing` | `BOOL` | `0x3c` |
| `_isEnabled` | `BOOL` | `0x3d` |
| `_downloader` | `Downloader *` | `0x40` |
| `_scaleForPad` | `float` | `0x44` |

### `FreeRequestListCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 11 · `instanceSize`=`96`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_bgImgView` | `UIImageView *` | `0x34` |
| `_charaBgImgView` | `UIImageView *` | `0x38` |
| `_charaImgView` | `UIImageView *` | `0x3c` |
| `_playerNameLbl` | `UILabel *` | `0x40` |
| `_scoreBaseImgView` | `UIImageView *` | `0x44` |
| `_scoreLbl` | `UILabel *` | `0x48` |
| `isOS7` | `bool` | `0x4c` |
| `imgCharaX` | `int` | `0x50` |
| `imgPlayerNameX` | `int` | `0x54` |
| `imgScoreBaseX` | `int` | `0x58` |
| `imgScoreX` | `int` | `0x5c` |

### `FreeRequestListViewController` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 4 · `instanceSize`=`180`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_frinedDataArray` | `NSArray *` | `0xa8` |
| `_downloader` | `Downloader *` | `0xac` |
| `_freeRequestDetail` | `FreeRequestDetail *` | `0xb0` |

### `FriendListCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 19 · `instanceSize`=`128`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_bgImgView` | `UIImageView *` | `0x34` |
| `_youImgView` | `UIImageView *` | `0x38` |
| `_rankImgView01` | `UIImageView *` | `0x3c` |
| `_rankImgView10` | `UIImageView *` | `0x40` |
| `_charaBgImgView` | `UIImageView *` | `0x44` |
| `_charaImgView` | `UIImageView *` | `0x48` |
| `_playerNameLbl` | `UILabel *` | `0x4c` |
| `_scoreBaseImgView` | `UIImageView *` | `0x50` |
| `_scoreLbl` | `UILabel *` | `0x54` |
| `isOS7` | `bool` | `0x58` |
| `imgYouX` | `int` | `0x5c` |
| `imgFrameX` | `int` | `0x60` |
| `imgFrame10X` | `int` | `0x64` |
| `imgFrame01X` | `int` | `0x68` |
| `imgOrderX` | `int` | `0x6c` |
| `imgCharaX` | `int` | `0x70` |
| `imgPlayerNameX` | `int` | `0x74` |
| `imgScoreBaseX` | `int` | `0x78` |
| `imgScoreX` | `int` | `0x7c` |

### `FriendListDetail` — ✅ complete

Methods **15/15** · unimpl 0 · ivars 6 · `instanceSize`=`72`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIView *` | `0x34` |
| `_friendData` | `NSValue *` | `0x38` |
| `_isAnimationing` | `BOOL` | `0x3c` |
| `_isEnabled` | `BOOL` | `0x3d` |
| `_dlRemoveFriend` | `Downloader *` | `0x40` |
| `_scaleForPad` | `float` | `0x44` |

### `FriendListDetailChara` — ✅ complete

Methods **6/6** · unimpl 0 · ivars 2 · `instanceSize`=`61`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_friendData` | `NSValue *` | `0x38` |
| `_isAnimationing` | `BOOL` | `0x3c` |

### `FriendListViewController` — ✅ complete

Methods **12/12** · unimpl 0 · ivars 6 · `instanceSize`=`188`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_sortButton` | `UIButton *` | `0xa8` |
| `_lonelyImageView` | `UIImageView *` | `0xac` |
| `_detailView` | `FriendListDetail *` | `0xb0` |
| `_isBestScoreSort` | `BOOL` | `0xb4` |
| `_frinedDataArray` | `NSArray *` | `0xb8` |

### `FriendMngTopSplitViewController` — ✅ complete

Methods **13/13** · unimpl 0 · ivars 13 · `instanceSize`=`284`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_markView` | `UIImageView *` | `0xa4` |
| `_leftViewCtrl` | `FriendMngTopViewController *` | `0xa8` |
| `_rightViewCtrl` | `UINavigationController *` | `0xac` |
| `_arrowImageView` | `UIImageView *` | `0xb0` |
| `_selectedIndex` | `int` | `0xb4` |
| `_listFrm` | `struct CGRect` | `0xb8` |
| `_requestFrm` | `struct CGRect` | `0xc8` |
| `_replyFrm` | `struct CGRect` | `0xd8` |
| `_listArrowFrm` | `struct CGRect` | `0xe8` |
| `_requestArrowFrm` | `struct CGRect` | `0xf8` |
| `_replyArrowFrm` | `struct CGRect` | `0x108` |
| `_howToView` | `HowToViewCtrlPad *` | `0x118` |

### `FriendMngTopViewController` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 3 · `instanceSize`=`172`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_markView` | `UIImageView *` | `0xa4` |
| `m_Delegate` | `id` | `0xa8` |

### `FriendReplyCell` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 15 · `instanceSize`=`112`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_delegate` | `FriendReplyViewController *` | `0x34` |
| `_replyData` | `NSValue *` | `0x38` |
| `_bgImgView` | `UIImageView *` | `0x3c` |
| `_charaBgView` | `UIImageView *` | `0x40` |
| `_charaView` | `UIImageView *` | `0x44` |
| `_playerNameLabel` | `UILabel *` | `0x48` |
| `_requestDateLabel` | `UILabel *` | `0x4c` |
| `_okButton` | `UIButton *` | `0x50` |
| `_ngButton` | `UIButton *` | `0x54` |
| `isOS7` | `bool` | `0x58` |
| `imgCharaX` | `int` | `0x5c` |
| `imgPlayerNameX` | `int` | `0x60` |
| `dateX` | `int` | `0x64` |
| `btnYesX` | `int` | `0x68` |
| `btnNoX` | `int` | `0x6c` |

### `FriendReplyViewController` — ✅ complete

Methods **17/17** · unimpl 0 · ivars 8 · `instanceSize`=`196`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_lonelyImageView` | `UIImageView *` | `0xa8` |
| `_headView` | `UIView *` | `0xac` |
| `_lonelyHeadView` | `UIView *` | `0xb0` |
| `dlGetFriendRequest` | `Downloader *` | `0xb4` |
| `_receiveDataArray` | `NSMutableArray *` | `0xb8` |
| `dlReplyFriend` | `Downloader *` | `0xbc` |
| `_replyPlayerId` | `NSString *` | `0xc0` |

### `FriendRequestCell` — ✅ complete

Methods **4/4** · unimpl 0 · ivars 11 · `instanceSize`=`96`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_charaBgImgView` | `UIImageView *` | `0x34` |
| `_charaImgView` | `UIImageView *` | `0x38` |
| `_playerNameLbl` | `UILabel *` | `0x3c` |
| `_requestDateLbl` | `UILabel *` | `0x40` |
| `_cancelButton` | `UIButton *` | `0x44` |
| `_friendPlayerId` | `NSString *` | `0x48` |
| `isOS7` | `bool` | `0x4c` |
| `imgCharaX` | `int` | `0x50` |
| `imgPlayerNameX` | `int` | `0x54` |
| `imgDateX` | `int` | `0x58` |
| `btnCancelX` | `int` | `0x5c` |

### `FriendRequestTable` — ✅ complete

Methods **15/15** · unimpl 0 · ivars 4 · `instanceSize`=`180`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_lonelyImageView` | `UIImageView *` | `0xa8` |
| `dlGetFriendRequest` | `Downloader *` | `0xac` |
| `_sendDataArray` | `NSMutableArray *` | `0xb0` |

### `FriendRequestViewController` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 4 · `instanceSize`=`180`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_playerIdField` | `UITextField *` | `0xa4` |
| `_indicator` | `UIActivityIndicatorView *` | `0xa8` |
| `_requestTable` | `FriendRequestTable *` | `0xac` |
| `_downloader` | `Downloader *` | `0xb0` |

### `FriendScoreTableCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 23 · `instanceSize`=`144`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_bgImgView` | `UIImageView *` | `0x34` |
| `_youImgView` | `UIImageView *` | `0x38` |
| `_rankImgView01` | `UIImageView *` | `0x3c` |
| `_rankImgView10` | `UIImageView *` | `0x40` |
| `_charaBgImgView` | `UIImageView *` | `0x44` |
| `_charaImgView` | `UIImageView *` | `0x48` |
| `_playerNameLbl` | `UILabel *` | `0x4c` |
| `_scoreBaseImgView` | `UIImageView *` | `0x50` |
| `_scoreLbl` | `UILabel *` | `0x54` |
| `_scoreRankImgView` | `UIImageView *` | `0x58` |
| `_fullcomboMarkImgView` | `UIImageView *` | `0x5c` |
| `isOS7` | `bool` | `0x60` |
| `imgYouX` | `int` | `0x64` |
| `imgFrameX` | `int` | `0x68` |
| `imgFrame10X` | `int` | `0x6c` |
| `imgFrame01X` | `int` | `0x70` |
| `imgOrderX` | `int` | `0x74` |
| `imgCharaX` | `int` | `0x78` |
| `imgPlayerNameX` | `int` | `0x7c` |
| `imgScoreBaseX` | `int` | `0x80` |
| `imgScoreX` | `int` | `0x84` |
| `imgRankX` | `int` | `0x88` |
| `imgFullComboX` | `int` | `0x8c` |

### `GameEffectView` — ✅ complete

Methods **11/11** · unimpl 0 · ivars 0 · `instanceSize`=`162`

### `HowToView` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 2 · `instanceSize`=`60`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_imageList` | `NSArray *` | `0x34` |
| `_bgImage` | `UIImage *` | `0x38` |

### `HowToViewCtrl` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 7 · `instanceSize`=`189`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_fileNameArray` | `NSArray *` | `0xa4` |
| `_scrollView` | `UIScrollView *` | `0xa8` |
| `_pageCtrl` | `UIPageControl *` | `0xac` |
| `_closeBtn` | `UIButton *` | `0xb0` |
| `_fromNaviBarImage` | `UIImage *` | `0xb4` |
| `_backGroundImage` | `UIImage *` | `0xb8` |
| `_isCloseButtonEnable` | `BOOL` | `0xbc` |

### `HowToViewCtrlPad` — ✅ complete

Methods **19/19** · unimpl 0 · ivars 7 · `instanceSize`=`192`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_fileNameArray` | `NSArray *` | `0xa4` |
| `_scrollView` | `UIScrollView *` | `0xa8` |
| `_pageCtrl` | `UIPageControl *` | `0xac` |
| `_backGroundImage` | `UIImage *` | `0xb0` |
| `_isAnimationing` | `BOOL` | `0xb4` |
| `m_CoverView` | `UIView *` | `0xb8` |
| `_pageImgs` | `UIView *` | `0xbc` |

### `HttpConn` — ✅ complete

Methods **10/10** · unimpl 0 · ivars 6 · `instanceSize`=`28`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `receivedData` | `NSMutableData *` | `0x4` |
| `receivedString` | `NSString *` | `0x8` |
| `encoding` | `unsigned int` | `0xc` |
| `conn` | `NSURLConnection *` | `0x10` |
| `statusCode` | `int` | `0x14` |
| `status` | `int` | `0x18` |

### `ImageDownloader` — ✅ complete

Methods **20/20** · unimpl 0 · ivars 6 · `instanceSize`=`28`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_ImageURL` | `NSString *` | `0x4` |
| `m_IndexPathInTableView` | `NSIndexPath *` | `0x8` |
| `delegate` | `<ImageDownloaderDelegate> *` | `0xc` |
| `m_ActiveDownload` | `NSMutableData *` | `0x10` |
| `m_ImageConnection` | `NSURLConnection *` | `0x14` |
| `m_DownloadedImage` | `UIImage *` | `0x18` |

### `InputKidViewController` — ✅ complete

Methods **12/12** · unimpl 0 · ivars 3 · `instanceSize`=`176`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_codeField` | `UITextField *` | `0xa4` |
| `_indicator` | `UIActivityIndicatorView *` | `0xa8` |
| `_downloader` | `Downloader *` | `0xac` |

### `InputOTPViewCtrl` — ✅ complete

Methods **18/18** · unimpl 0 · ivars 5 · `instanceSize`=`184`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_categoryView` | `CheckerCategoryViewController *` | `0xa4` |
| `_scrollView` | `TouchableScrollView *` | `0xa8` |
| `_otpField` | `UITextField *` | `0xac` |
| `_dummyView` | `UIViewController *` | `0xb0` |
| `_scrollOffset` | `float` | `0xb4` |

### `InviteTopViewController` — ✅ complete

Methods **8/8** · unimpl 0 · ivars 1 · `instanceSize`=`163`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `isAnimationing` | `BOOL` | `0xa2` |

### `InviteTopViewControllerPad` — ✅ complete

Methods **16/16** · unimpl 0 · ivars 5 · `instanceSize`=`180`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `isAnimationing` | `BOOL` | `0xa2` |
| `_codeField` | `UITextField *` | `0xa4` |
| `_indicator` | `UIActivityIndicatorView *` | `0xa8` |
| `_downloader` | `Downloader *` | `0xac` |
| `_scrollView` | `UIScrollView *` | `0xb0` |

### `LimitedCharaInfo` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 3 · `instanceSize`=`13`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_musicIds` | `NSArray *` | `0x4` |
| `_charaIds` | `NSArray *` | `0x8` |
| `_getFlg` | `BOOL` | `0xc` |

### `LoginBonusView` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 3 · `instanceSize`=`61`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_BgImgView` | `UIImageView *` | `0x34` |
| `m_OldLoginCnt` | `int` | `0x38` |
| `m_IsTouch` | `BOOL` | `0x3c` |

### `MainViewController` — ✅ complete

Methods **95/95** · unimpl 0 · ivars 51 · `instanceSize`=`356`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_glView` | `neGLView *` | `0xa4` |
| `_settingViewing` | `bool` | `0xa8` |
| `_cameraRollSaving` | `bool` | `0xa9` |
| `_isDefaultDlFailed` | `bool` | `0xaa` |
| `_rewardListViweing` | `bool` | `0xab` |
| `_isGotoTitle` | `bool` | `0xac` |
| `_acMusicSelViewing` | `bool` | `0xad` |
| `_settingNaviCtrl` | `UINavigationController *` | `0xb0` |
| `_friendMngNaviCtrl` | `UINavigationController *` | `0xb4` |
| `_popnLinkNaviCtrl` | `UINavigationController *` | `0xb8` |
| `_friendScoreNaviCtrl` | `UINavigationController *` | `0xbc` |
| `_recommendNaviCtrl` | `UINavigationController *` | `0xc0` |
| `_mapSelectNaviCtrl` | `UINavigationController *` | `0xc4` |
| `_sortSelectNaviCtrl` | `UINavigationController *` | `0xc8` |
| `_inputNameNaviCtrl` | `UINavigationController *` | `0xcc` |
| `_inputConvPassNaviCtrl` | `UINavigationController *` | `0xd0` |
| `_inviteNaviCtrl` | `UINavigationController *` | `0xd4` |
| `_searchNaviCtrl` | `UINavigationController *` | `0xd8` |
| `_acViewerNaviCtrl` | `UINavigationController *` | `0xdc` |
| `_presentBoxNaviCtrl` | `UINavigationController *` | `0xe0` |
| `_overScoreLogNaviCtrl` | `UINavigationController *` | `0xe4` |
| `_storeViewController` | `StoreViewController *` | `0xe8` |
| `_defaultDlViewController` | `DefaultDataDownloadView *` | `0xec` |
| `_acceptPolicyCtrl` | `AcceptPolicyViewController *` | `0xf0` |
| `_communicatingView` | `CommunicatingView *` | `0xf4` |
| `_cameraRollError` | `NSError *` | `0xf8` |
| `m_LoopInterval` | `int` | `0xfc` |
| `m_DisplayLink` | `CADisplayLink *` | `0x100` |
| `m_TaskTime` | `struct C_TIME` | `0x104` |
| `m_RenderTime` | `struct C_TIME` | `0x10c` |
| `m_IsPause` | `bool` | `0x114` |
| `m_IsLoop` | `bool` | `0x115` |
| `m_AepManager` | `struct AepManager *` | `0x118` |
| `m_AlertViewCallback` | `void /*unknown*/ *` | `0x11c` |
| `m_AlertViewCallbackParam` | `void *` | `0x120` |
| `m_capturedImg` | `UIImage *` | `0x124` |
| `m_flgCapture` | `BOOL` | `0x128` |
| `_coverView` | `UIButton *` | `0x12c` |
| `_presentBoxViewCtrl` | `PresentBoxViewController *` | `0x130` |
| `_sortSelectViewCtrl` | `SortSelectViewController *` | `0x134` |
| `_recommendViewCtrl` | `RecommendViewController *` | `0x138` |
| `_overScoreLogViewCtrl` | `OverScoreLogViewController *` | `0x13c` |
| `_settingViewCtrl` | `SettingTableSplitViewController *` | `0x140` |
| `_mapSelectViewCtrl` | `MapSelectSplitViewController *` | `0x144` |
| `_friendMngViewCtrl` | `FriendMngTopSplitViewController *` | `0x148` |
| `_popnLinkViewCtrl` | `PopnLinkTopSplitViewController *` | `0x14c` |
| `_inputNameViewCtrl` | `InputNameViewCtrl *` | `0x150` |
| `_inputConvPassViewCtrl` | `InputConversionPassViewController *` | `0x154` |
| `_acViewerViewCtrl` | `AcViewerSplitViewController *` | `0x158` |
| `_inviteViewCtrl` | `InviteTopViewControllerPad *` | `0x15c` |
| `_blackBoardView` | `UIView *` | `0x160` |

### `MapAnnotation` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 4 · `instanceSize`=`32`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Coordinate` | `struct ?` | `0x4` |
| `m_Title` | `NSString *` | `0x14` |
| `m_SubTitle` | `NSString *` | `0x18` |
| `m_ModelName` | `NSString *` | `0x1c` |

### `MapListCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 2 · `instanceSize`=`60`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_mapVal` | `NSValue *` | `0x34` |
| `_bgImgView` | `UIImageView *` | `0x38` |

### `MusicData` — ✅ complete

Methods **34/34** · unimpl 0 · ivars 16 · `instanceSize`=`68`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_FilePath` | `NSString *` | `0x4` |
| `m_DecodeType` | `int` | `0x8` |
| `m_MusicID` | `int` | `0xc` |
| `m_lvNormal` | `int` | `0x10` |
| `m_lvHyper` | `int` | `0x14` |
| `m_lvEx` | `int` | `0x18` |
| `m_BPM_MIN` | `int` | `0x1c` |
| `m_BPM_MAX` | `int` | `0x20` |
| `m_MusicName` | `NSString *` | `0x24` |
| `m_MusicHira` | `NSString *` | `0x28` |
| `m_ArtistName` | `NSString *` | `0x2c` |
| `m_ArtistHira` | `NSString *` | `0x30` |
| `m_MusicSortName` | `NSString *` | `0x34` |
| `m_ArtistSortName` | `NSString *` | `0x38` |
| `m_MusicNameInitial` | `NSString *` | `0x3c` |
| `m_ArtistNameInitial` | `NSString *` | `0x40` |

### `MusicManager` — ✅ complete

Methods **37/37** · unimpl 0 · ivars 13 · `instanceSize`=`56`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_DefaultMusicIDs` | `NSArray *` | `0x4` |
| `m_OpenTreasureMusicIDs` | `NSMutableArray *` | `0x8` |
| `m_OpenInviteMusicIDs` | `NSMutableArray *` | `0xc` |
| `m_OpenCollaboMusicIDs` | `NSMutableArray *` | `0x10` |
| `m_OpenLoginBonusMusicIDs` | `NSMutableArray *` | `0x14` |
| `m_PurchasedMusicDictionaris` | `NSMutableArray *` | `0x18` |
| `m_PurchasedAcMusicDictionaris` | `NSMutableArray *` | `0x1c` |
| `m_AcDefaultMusicIDs` | `NSArray *` | `0x20` |
| `m_MusicDataArray` | `NSMutableArray *` | `0x24` |
| `m_MusicDataArrayDirty` | `BOOL` | `0x28` |
| `m_AcMusicDataArray` | `NSMutableArray *` | `0x2c` |
| `m_AcMusicDataArrayDirty` | `BOOL` | `0x30` |
| `m_MusicLvPatchArray` | `NSArray *` | `0x34` |

### `MusicPatch` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 4 · `instanceSize`=`20`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_musicId` | `int` | `0x4` |
| `_lvN` | `int` | `0x8` |
| `_lvH` | `int` | `0xc` |
| `_lvEx` | `int` | `0x10` |

### `MyInviteCodeViewController` — ✅ complete

Methods **4/4** · unimpl 0 · ivars 0 · `instanceSize`=`162`

### `OverScoreData` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`48`

### `OverScoreLogCell` — ✅ complete

Methods **4/4** · unimpl 0 · ivars 7 · `instanceSize`=`104`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_lblMusicName` | `UILabel *` | `0x34` |
| `m_imgViewSheet` | `UIImageView *` | `0x38` |
| `m_lblFriendName` | `UILabel *` | `0x3c` |
| `m_lblUpdateDate` | `UILabel *` | `0x40` |
| `m_lblMyScore` | `UILabel *` | `0x44` |
| `m_lblFriendScore` | `UILabel *` | `0x48` |
| `m_overScoreLogData` | `struct OverScoreLogData` | `0x4c` |

### `OverScoreLogViewController` — ✅ complete

Methods **18/18** · unimpl 0 · ivars 6 · `instanceSize`=`188`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_isAnimationing` | `BOOL` | `0xa8` |
| `_overScoreLogDataArray` | `NSMutableArray *` | `0xac` |
| `_musicSelTask` | `struct MusicSelTask *` | `0xb0` |
| `m_musicId` | `int` | `0xb4` |
| `m_sheet` | `int` | `0xb8` |

### `PolicyView` — ✅ complete

Methods **11/11** · unimpl 0 · ivars 1 · `instanceSize`=`168`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_textView` | `UITextView *` | `0xa4` |

### `PopkunSizeViewCtrl` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 12 · `instanceSize`=`224`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_infoView` | `UIImageView *` | `0xa4` |
| `_popkun` | `UIImageView *` | `0xa8` |
| `_sizeSlider` | `UISlider *` | `0xac` |
| `_resetButton` | `UIButton *` | `0xb0` |
| `_sizeLbl` | `UILabel *` | `0xb4` |
| `_size` | `float` | `0xb8` |
| `_orgFrame` | `struct CGRect` | `0xbc` |
| `offsetYForPad1` | `int` | `0xcc` |
| `offsetYForPad2` | `int` | `0xd0` |
| `offsetYForPad3` | `int` | `0xd4` |
| `offsetYForPad4` | `int` | `0xd8` |
| `_hoge` | `CustomAlertView *` | `0xdc` |

### `PopnLinkTopSplitViewController` — ✅ complete

Methods **13/13** · unimpl 0 · ivars 12 · `instanceSize`=`280`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_leftViewCtrl` | `PopnLinkTopViewController *` | `0xa4` |
| `_rightViewCtrl` | `UINavigationController *` | `0xa8` |
| `_konamiIdArrowImageView` | `UIImageView *` | `0xac` |
| `_selectedIndex` | `int` | `0xb0` |
| `_konamiIdFrm` | `struct CGRect` | `0xb4` |
| `_checkerFrm` | `struct CGRect` | `0xc4` |
| `_quizFrm` | `struct CGRect` | `0xd4` |
| `_konamiIdArrowFrm` | `struct CGRect` | `0xe4` |
| `_checkerArrowFrm` | `struct CGRect` | `0xf4` |
| `_quizArrowFrm` | `struct CGRect` | `0x104` |
| `_howToView` | `HowToViewCtrlPad *` | `0x114` |

### `PopnLinkTopViewController` — ✅ complete

Methods **17/17** · unimpl 0 · ivars 6 · `instanceSize`=`184`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_btnId` | `UIButton *` | `0xa4` |
| `_btnChecker` | `UIButton *` | `0xa8` |
| `_btnQuiz` | `UIButton *` | `0xac` |
| `_delegate` | `id` | `0xb0` |
| `_scrollView` | `UIScrollView *` | `0xb4` |

### `PreferredCharaInfo` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 3 · `instanceSize`=`13`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_musicIds` | `NSArray *` | `0x4` |
| `_charaIds` | `NSArray *` | `0x8` |
| `_getFlg` | `BOOL` | `0xc` |

### `PresentBoxCell` — ✅ complete

Methods **5/5** · unimpl 0 · ivars 5 · `instanceSize`=`84`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_getBtn` | `UIButton *` | `0x34` |
| `_imageViewIcon` | `UIImageView *` | `0x38` |
| `_lbl` | `UILabel *` | `0x3c` |
| `_lblInfo` | `UILabel *` | `0x40` |
| `_presentData` | `struct PresentData` | `0x44` |

### `PresentBoxViewController` — ✅ complete

Methods **20/20** · unimpl 0 · ivars 7 · `instanceSize`=`192`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_emptyImageView` | `UIImageView *` | `0xa8` |
| `_btnGetAll` | `UIButton *` | `0xac` |
| `_isAnimationing` | `BOOL` | `0xb0` |
| `_presentDataArray` | `NSMutableArray *` | `0xb4` |
| `_customAlert` | `CustomAlertView *` | `0xb8` |
| `_presentDataValue` | `NSValue *` | `0xbc` |

### `PurchaseManager` — ✅ complete

Methods **30/30** · unimpl 0 · ivars 10 · `instanceSize`=`40`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_PurchasedProducts` | `NSMutableArray *` | `0x4` |
| `m_PurchaseCheckTransactions` | `NSMutableArray *` | `0x8` |
| `m_PurchaseCheckedProducts` | `NSMutableArray *` | `0xc` |
| `m_Transactioing` | `BOOL` | `0x10` |
| `m_IsRestored` | `BOOL` | `0x11` |
| `m_RestoredTransactions` | `NSMutableArray *` | `0x14` |
| `m_IsMusicData` | `BOOL` | `0x18` |
| `m_Downloader` | `Downloader *` | `0x1c` |
| `m_Delegate` | `<PurchaseManagerDelegate> *` | `0x20` |
| `m_MusicDataDelegate` | `<PurchaseManagerMusicDelegate> *` | `0x24` |

### `PurchaseStore` — ✅ complete

Methods **4/4** · unimpl 0 · ivars 1 · `instanceSize`=`5`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `nowPurchasing` | `bool` | `0x4` |

### `PurchaseTransactionCache` — ✅ complete

Methods **8/8** · unimpl 0 · ivars 5 · `instanceSize`=`24`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_ProductID` | `NSString *` | `0x4` |
| `m_ReceiptData` | `NSData *` | `0x8` |
| `m_TransactionID` | `NSString *` | `0xc` |
| `m_TransactionDate` | `NSDate *` | `0x10` |
| `m_DigestString` | `NSString *` | `0x14` |

### `QuizCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 2 · `instanceSize`=`60`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_answerId` | `int` | `0x34` |
| `_answerIdView` | `UIImageView *` | `0x38` |

### `QuizMainViewController` — ✅ complete

Methods **19/19** · unimpl 0 · ivars 26 · `instanceSize`=`276`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_questionLbl` | `UILabel *` | `0xa8` |
| `_rightView` | `UIImageView *` | `0xac` |
| `_wrongView` | `UIImageView *` | `0xb0` |
| `_blackBoardView` | `UIImageView *` | `0xb4` |
| `_blackBoardResultView` | `UIImageView *` | `0xb8` |
| `_hanamaruView` | `UIImageView *` | `0xbc` |
| `_presentBaseView` | `UIView *` | `0xc0` |
| `_defSsmView` | `UIImageView *` | `0xc4` |
| `_rightSsmView` | `UIImageView *` | `0xc8` |
| `_wrongSsmView` | `UIImageView *` | `0xcc` |
| `_dlQuiz` | `Downloader *` | `0xd0` |
| `_dlAnswer` | `Downloader *` | `0xd4` |
| `_question` | `NSString *` | `0xd8` |
| `_quizAnswerArray` | `NSArray *` | `0xdc` |
| `_quizId` | `int` | `0xe0` |
| `_rightAnswer` | `int` | `0xe4` |
| `_totalCorrect` | `int` | `0xe8` |
| `_totalIncorrect` | `int` | `0xec` |
| `_consecutive` | `int` | `0xf0` |
| `_finaleAnswer` | `int` | `0xf4` |
| `_selectAnswer` | `int` | `0xf8` |
| `_selectCell` | `UITableViewCell *` | `0xfc` |
| `_isAnswerable` | `BOOL` | `0x100` |
| `_presentSt` | `int` | `0x104` |
| `_sdRscId` | `int[3]` | `0x108` |

### `RandomLoginBonusView` — ✅ complete

Methods **11/11** · unimpl 0 · ivars 9 · `instanceSize`=`104`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_bonus` | `int` | `0x34` |
| `_numImgView1000` | `UIImageView *` | `0x38` |
| `_numImgView0100` | `UIImageView *` | `0x3c` |
| `_numImgView0010` | `UIImageView *` | `0x40` |
| `_numImgView0001` | `UIImageView *` | `0x44` |
| `_seRscId` | `int[3]` | `0x48` |
| `_seInstId` | `int[3]` | `0x54` |
| `_isAnimationing` | `BOOL` | `0x60` |
| `_state` | `int` | `0x64` |

### `RecommendAdId` — ✅ complete

Methods **8/8** · unimpl 0 · ivars 1 · `instanceSize`=`8`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_serviceName` | `NSString *` | `0x4` |

### `RecommendListCell` — ✅ complete

Methods **5/5** · unimpl 0 · ivars 11 · `instanceSize`=`96`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_downloader` | `ImageDownloader *` | `0x34` |
| `_bgImageView` | `UIImageView *` | `0x38` |
| `_newMarkImgView` | `UIImageView *` | `0x3c` |
| `_packImageView` | `UIImageView *` | `0x40` |
| `_packNameLbl` | `UILabel *` | `0x44` |
| `_dateLbl` | `UILabel *` | `0x48` |
| `_playerNameLbl` | `UILabel *` | `0x4c` |
| `isOS7` | `bool` | `0x50` |
| `imgPackX` | `int` | `0x54` |
| `dateX` | `int` | `0x58` |
| `playerNameX` | `int` | `0x5c` |

### `RecommendNetwork` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 1 · `instanceSize`=`8`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_initializeFlg` | `int` | `0x4` |

### `RecommendViewController` — ✅ complete

Methods **18/18** · unimpl 0 · ivars 6 · `instanceSize`=`184`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_storeView` | `StoreViewController *` | `0xa8` |
| `_recommendDataArray` | `NSArray *` | `0xac` |
| `_isAnimationing` | `BOOL` | `0xb0` |
| `_isBack` | `BOOL` | `0xb1` |
| `_pMusicSelTask` | `void *` | `0xb4` |

### `RecommendWebAPI` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`4`

### `RecommendWebViewController` — ✅ complete

Methods **6/6** · unimpl 0 · ivars 0 · `instanceSize`=`153`

### `RewardNetwork` — ✅ complete

Methods **12/12** · unimpl 0 · ivars 2 · `instanceSize`=`12`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_webViewController` | `RewardNetworkWebViewController *` | `0x4` |
| `_initializeFlg` | `int` | `0x8` |

### `RewardNetworkError` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`4`

### `RewardNetworkIndicator` — ✅ complete

Methods **6/6** · unimpl 0 · ivars 1 · `instanceSize`=`52`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_indicator` | `UIActivityIndicatorView *` | `0x30` |

### `RewardNetworkMessage` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`4`

### `RewardNetworkPasteBoard` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 2 · `instanceSize`=`12`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_serviceName` | `NSString *` | `0x4` |
| `_dataType` | `NSString *` | `0x8` |

### `RewardNetworkURLConnection` — ✅ complete

Methods **24/24** · unimpl 0 · ivars 9 · `instanceSize`=`40`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `retryCount` | `int` | `0x4` |
| `_request` | `NSURLRequest *` | `0x8` |
| `_connection` | `NSURLConnection *` | `0xc` |
| `_ApplilinkFailedBlock` | `@?` | `0x10` |
| `_receiveData` | `NSMutableData *` | `0x14` |
| `_isConnection` | `BOOL` | `0x18` |
| `_timer` | `NSTimer *` | `0x1c` |
| `_url` | `NSString *` | `0x20` |
| `_ApplilinkFinishedBlock` | `@?` | `0x24` |

### `RewardNetworkUdid` — ✅ complete

Methods **4/4** · unimpl 0 · ivars 1 · `instanceSize`=`8`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_pasteBoard` | `RewardNetworkPasteBoard *` | `0x4` |

### `RewardNetworkUtilities` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`4`

### `RewardNetworkWebAPI` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 1 · `instanceSize`=`8`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `retryCount` | `int` | `0x4` |

### `RewardNetworkWebViewController` — ✅ complete

Methods **25/25** · unimpl 0 · ivars 6 · `instanceSize`=`180`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_webView` | `UIWebView *` | `0x9c` |
| `_navigationBar` | `UINavigationBar *` | `0xa0` |
| `_indicator` | `RewardNetworkIndicator *` | `0xa4` |
| `_isNavigationBarHidden` | `BOOL` | `0xa8` |
| `_delegate` | `<RewardNetworkDelegate> *` | `0xac` |
| `_parentView` | `UIView *` | `0xb0` |

### `ScoreData` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`48`

### `SettingCustomerTableViewController` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 2 · `instanceSize`=`168`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_policyView` | `UINavigationController *` | `0xa4` |

### `SettingGameTableViewController` — ✅ complete

Methods **17/17** · unimpl 0 · ivars 4 · `instanceSize`=`288`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_selectedIndexPath` | `NSIndexPath *` | `0xa4` |
| `_detailView` | `UIViewController *[6]` | `0xa8` |
| `_dummyFrm` | `struct CGRect[6]` | `0xc0` |

### `SettingHowtoTableViewController` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 2 · `instanceSize`=`168`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `howtoViewCtrlPad` | `HowToViewCtrlPad *` | `0xa4` |

### `SettingOtherTableViewController` — ✅ complete

Methods **23/23** · unimpl 0 · ivars 8 · `instanceSize`=`208`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_treasureRetireAlertView` | `CommonAlertView *` | `0xa4` |
| `_isAnimationing` | `BOOL` | `0xa8` |
| `_viewCmnDelegate` | `<ViewCmnProtocol> *` | `0xac` |
| `_selectedIndexPath` | `NSIndexPath *` | `0xb0` |
| `_convDetailView` | `UIViewController *` | `0xb4` |
| `_convDummyFrm` | `struct CGRect` | `0xb8` |
| `_arrowTopView` | `UIImageView *` | `0xc8` |
| `_arrowUnderView` | `UIImageView *` | `0xcc` |

### `SettingTableSplitViewController` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 7 · `instanceSize`=`308`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_leftViewCtrl` | `SettingTopViewController *` | `0xa4` |
| `_rightViewCtrl` | `UINavigationController *` | `0xa8` |
| `_arrowImageView` | `UIImageView *` | `0xac` |
| `_selectedIndex` | `int` | `0xb0` |
| `_viewFrm` | `struct CGRect[4]` | `0xb4` |
| `_arrowFrm` | `struct CGRect[4]` | `0xf4` |

### `SettingTableViewController` — ✅ complete

Methods **20/20** · unimpl 0 · ivars 7 · `instanceSize`=`186`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_effectSwitch` | `UIButton *` | `0xa4` |
| `_simpleModeSwitch` | `UISwitch *` | `0xa8` |
| `_treasureRetireAlertView` | `CommonAlertView *` | `0xac` |
| `_isAnimationing` | `BOOL` | `0xb0` |
| `howtoViewCtrlPad` | `HowToViewCtrlPad *` | `0xb4` |
| `isPad` | `BOOL` | `0xb8` |
| `_isEffectOn` | `BOOL` | `0xb9` |

### `SettingTopViewController` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 2 · `instanceSize`=`168`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_settingTopDelegate` | `<SettingTopViewControllerDalegate> *` | `0xa4` |

### `SortCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 4 · `instanceSize`=`68`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_sortVal` | `NSValue *` | `0x34` |
| `_titleImageView` | `UIImageView *` | `0x38` |
| `_checkImageView` | `UIImageView *` | `0x3c` |
| `_bgImgView` | `UIImageView *` | `0x40` |

### `SortSelectViewController` — ✅ complete

Methods **17/17** · unimpl 0 · ivars 4 · `instanceSize`=`176`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_pMusicSelTask` | `void *` | `0xa4` |
| `_sortDataArray` | `NSArray *` | `0xa8` |
| `_dummyView` | `UIViewController *` | `0xac` |

### `SoundSettingView` — ✅ complete

Methods **22/22** · unimpl 0 · ivars 8 · `instanceSize`=`196`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_bgmSlider` | `UISlider *` | `0xa4` |
| `_seSlider` | `UISlider *` | `0xa8` |
| `_touchSoundSlider` | `UISlider *` | `0xac` |
| `_touchSoundRscId` | `int` | `0xb0` |
| `_seRscId` | `int` | `0xb4` |
| `_selectedTouchSoundNo` | `int` | `0xb8` |
| `_touchSoundHaveFlg` | `int` | `0xbc` |
| `_touchSoundArray` | `NSMutableArray *` | `0xc0` |

### `StoreAcMusicInfo` — ✅ complete

Methods **8/8** · unimpl 0 · ivars 5 · `instanceSize`=`24`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `acMusicId` | `int` | `0x4` |
| `title` | `NSString *` | `0x8` |
| `genre` | `NSString *` | `0xc` |
| `itemURL` | `NSString *` | `0x10` |
| `sampleURL` | `NSString *` | `0x14` |

### `StoreAcvManageViewController` — ✅ complete

Methods **24/24** · unimpl 0 · ivars 10 · `instanceSize`=`204`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `tableView` | `UITableView *` | `0xa4` |
| `storeViewCtrl` | `StoreViewController *` | `0xa8` |
| `working_index` | `unsigned int` | `0xac` |
| `m_InfoDownloader` | `Downloader *` | `0xb0` |
| `dlManager` | `StoreDownloadManager *` | `0xb4` |
| `deleteAlertView` | `CommonAlertView *` | `0xb8` |
| `imgDelete` | `UIImage *` | `0xbc` |
| `imgDownload` | `UIImage *` | `0xc0` |
| `isPad` | `BOOL` | `0xc4` |
| `checkMusicIds` | `NSMutableArray *` | `0xc8` |

### `StoreDetailCopyrightCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 1 · `instanceSize`=`56`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `labelCopyright` | `UILabel *` | `0x34` |

### `StoreDetailHeaderView` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 7 · `instanceSize`=`80`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_BgView` | `UIImageView *` | `0x34` |
| `m_ArtworkView` | `UIImageView *` | `0x38` |
| `m_ReflectionArtworkView` | `UIImageView *` | `0x3c` |
| `m_LabelName` | `UILabel *` | `0x40` |
| `m_LabelComment` | `UILabel *` | `0x44` |
| `m_ButtonPurchase` | `UIButton *` | `0x48` |
| `m_NewMarker` | `UIImageView *` | `0x4c` |

### `StoreDetailMusicCell` — ✅ complete

Methods **15/15** · unimpl 0 · ivars 11 · `instanceSize`=`96`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `bgView` | `UIImageView *` | `0x34` |
| `artworkView` | `UIImageView *` | `0x38` |
| `labelName` | `UILabel *` | `0x3c` |
| `labelArtist` | `UILabel *` | `0x40` |
| `labelLevels` | `UILabel *` | `0x44` |
| `sampleView` | `UIView *` | `0x48` |
| `indicator` | `UIActivityIndicatorView *` | `0x4c` |
| `playingView` | `UIImageView *` | `0x50` |
| `buttonLink` | `UIButton *` | `0x54` |
| `linkURL` | `NSURL *` | `0x58` |
| `arcadeViewer` | `UIImageView *` | `0x5c` |

### `StoreDetailViewController` — ✅ complete

Methods **48/48** · unimpl 0 · ivars 17 · `instanceSize`=`232`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `packInfo` | `StorePackInfo *` | `0xa4` |
| `m_HeaderView` | `StoreDetailHeaderView *` | `0xa8` |
| `m_BirthDayView` | `BirthDayViewController *` | `0xac` |
| `m_PackTableView` | `UITableView *` | `0xb0` |
| `m_AccessingIndicator` | `UIActivityIndicatorView *` | `0xb4` |
| `m_AccessingLabel` | `UILabel *` | `0xb8` |
| `m_StorePackInfoDownloader` | `StorePackInfoDownloader *` | `0xbc` |
| `sampleDownloader` | `Downloader *` | `0xc0` |
| `packBgImage0` | `UIImage *` | `0xc4` |
| `packBgImage1` | `UIImage *` | `0xc8` |
| `artworkDownloaders` | `NSMutableDictionary *` | `0xcc` |
| `recommendPackIdArr` | `NSArray *` | `0xd0` |
| `rowSamplePlayed` | `int` | `0xd4` |
| `isDownloadingSample` | `BOOL` | `0xd8` |
| `delegate` | `id` | `0xdc` |
| `recommendDownloader` | `Downloader *` | `0xe0` |
| `dummyView` | `UIViewController *` | `0xe4` |

### `StoreDialogView` — ✅ complete

Methods **11/11** · unimpl 0 · ivars 5 · `instanceSize`=`72`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_IndicatorView` | `UIActivityIndicatorView *` | `0x34` |
| `m_LabelMessage` | `UILabel *` | `0x38` |
| `m_ProgressView` | `UIProgressView *` | `0x3c` |
| `m_ButtonAbort` | `UIButton *` | `0x40` |
| `delegate` | `id` | `0x44` |

### `StoreDownloadManager` — ✅ complete

Methods **12/12** · unimpl 0 · ivars 5 · `instanceSize`=`21`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Tasks` | `NSArray *` | `0x4` |
| `m_FileDownloader` | `Downloader *` | `0x8` |
| `m_Delegate` | `<StoreDownloadManagerDelegate> *` | `0xc` |
| `m_CurrentIndex` | `unsigned int` | `0x10` |
| `m_IsStarted` | `BOOL` | `0x14` |

### `StoreDownloadTask` — ✅ complete

Methods **5/5** · unimpl 0 · ivars 3 · `instanceSize`=`16`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_FileURL` | `NSString *` | `0x4` |
| `m_FilePath` | `NSString *` | `0x8` |
| `m_AddObject` | `id` | `0xc` |

### `StoreImageView` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 2 · `instanceSize`=`64`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_ImageURL` | `NSString *` | `0x38` |
| `m_ImageDownloader` | `ImageDownloader *` | `0x3c` |

### `StoreMainViewController` — ✅ complete

Methods **64/64** · unimpl 0 · ivars 25 · `instanceSize`=`252`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_StoreViewCtrl` | `StoreViewController *` | `0xa4` |
| `m_PackListCtrl` | `StorePackListController *` | `0xa8` |
| `m_ArtworkDownloaders` | `NSMutableDictionary *` | `0xac` |
| `m_DownloadManager` | `StoreDownloadManager *` | `0xb0` |
| `m_PurchasingPackInfo` | `StorePackInfo *` | `0xb4` |
| `m_PromotionView` | `StorePromotionView *` | `0xb8` |
| `m_PromotionViewDummy` | `UIImageView *` | `0xbc` |
| `m_PackTableLabel` | `UILabel *` | `0xc0` |
| `m_ShowMoreButton` | `UIButton *` | `0xc4` |
| `m_ShowMoreIndicator` | `UIActivityIndicatorView *` | `0xc8` |
| `m_CoverViewPad` | `UIView *` | `0xcc` |
| `m_PackDetailViewPad` | `StorePackDetailViewPad *` | `0xd0` |
| `m_RestoreProductID` | `NSMutableArray *` | `0xd4` |
| `m_RestorePackInfo` | `NSMutableArray *` | `0xd8` |
| `m_RestoreButton` | `UIButton *` | `0xdc` |
| `m_StorePackInfoDownloader` | `StorePackInfoDownloader *` | `0xe0` |
| `m_PackBgImage0` | `UIImage *` | `0xe4` |
| `m_PackBgImage1` | `UIImage *` | `0xe8` |
| `m_IsPad` | `BOOL` | `0xec` |
| `m_IsLoadingMoreList` | `BOOL` | `0xed` |
| `m_IsAnimationing` | `BOOL` | `0xee` |
| `m_OffsetForOS` | `int` | `0xf0` |
| `m_IsStoreClosing` | `BOOL` | `0xf4` |
| `_isAlertViewShowing` | `BOOL` | `0xf5` |
| `m_RecommendPackListCtrl` | `StorePackListController *` | `0xf8` |

### `StoreManageViewController` — ✅ complete

Methods **23/23** · unimpl 0 · ivars 9 · `instanceSize`=`197`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `tableView` | `UITableView *` | `0xa4` |
| `storeViewCtrl` | `StoreViewController *` | `0xa8` |
| `working_index` | `unsigned int` | `0xac` |
| `m_InfoDownloader` | `Downloader *` | `0xb0` |
| `dlManager` | `StoreDownloadManager *` | `0xb4` |
| `deleteAlertView` | `CommonAlertView *` | `0xb8` |
| `imgDelete` | `UIImage *` | `0xbc` |
| `imgDownload` | `UIImage *` | `0xc0` |
| `isPad` | `BOOL` | `0xc4` |

### `StoreMusicInfo` — ✅ complete

Methods **13/13** · unimpl 0 · ivars 10 · `instanceSize`=`44`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `musicID` | `int` | `0x4` |
| `name` | `NSString *` | `0x8` |
| `artist` | `NSString *` | `0xc` |
| `itemURL` | `NSString *` | `0x10` |
| `artworkURL` | `NSString *` | `0x14` |
| `sampleURL` | `NSString *` | `0x18` |
| `itunesURL` | `NSString *` | `0x1c` |
| `lvBasic` | `int` | `0x20` |
| `lvMedium` | `int` | `0x24` |
| `lvHard` | `int` | `0x28` |

### `StorePackCell` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 8 · `instanceSize`=`84`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `bgView` | `UIImageView *` | `0x34` |
| `artworkView` | `UIImageView *` | `0x38` |
| `labelName` | `UILabel *` | `0x3c` |
| `labelPrice` | `UILabel *` | `0x40` |
| `labelPurchased` | `UILabel *` | `0x44` |
| `newMarker` | `UIImageView *` | `0x48` |
| `charaTicket` | `UIImageView *` | `0x4c` |
| `arcadeViewer` | `UIImageView *` | `0x50` |

### `StorePackDetailViewPad` — ✅ complete

Methods **32/32** · unimpl 0 · ivars 20 · `instanceSize`=`144`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `packInfo` | `StorePackInfo *` | `0x34` |
| `packView` | `UIView *` | `0x38` |
| `musicView` | `StorePackMusicView *[4]` | `0x3c` |
| `packArtworkView` | `StoreImageView *` | `0x4c` |
| `labelPackName` | `UILabel *` | `0x50` |
| `labelComment` | `UILabel *` | `0x54` |
| `copyrightView` | `UITextView *` | `0x58` |
| `buttonPurchase` | `UIButton *` | `0x5c` |
| `indicator` | `UIActivityIndicatorView *` | `0x60` |
| `labelLoading` | `UILabel *` | `0x64` |
| `m_StorePackInfoDownloader` | `StorePackInfoDownloader *` | `0x68` |
| `m_SampleDownloader` | `Downloader *` | `0x6c` |
| `samplePlaying` | `int` | `0x70` |
| `isInfoLoaded` | `BOOL` | `0x74` |
| `m_ArtistSiteButton` | `UIButton *` | `0x78` |
| `delegate` | `id` | `0x7c` |
| `recommendDownloader` | `Downloader *` | `0x80` |
| `dummyView` | `UIViewController *` | `0x84` |
| `recommendPackIdArr` | `NSArray *` | `0x88` |
| `m_BirthDayView` | `BirthDayViewController *` | `0x8c` |

### `StorePackInfo` — ✅ complete

Methods **24/24** · unimpl 0 · ivars 13 · `instanceSize`=`56`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Product` | `SKProduct *` | `0x4` |
| `m_PackID` | `int` | `0x8` |
| `m_IsNew` | `BOOL` | `0xc` |
| `m_ArtworkURL` | `NSString *` | `0x10` |
| `m_PackName` | `NSString *` | `0x14` |
| `m_Comment` | `NSString *` | `0x18` |
| `m_ShortComment` | `NSString *` | `0x1c` |
| `m_Copyright` | `NSString *` | `0x20` |
| `m_ArtistURL` | `NSString *` | `0x24` |
| `m_ArtistBunnerURL` | `NSString *` | `0x28` |
| `m_MusicInfos` | `NSArray *` | `0x2c` |
| `m_AcvMusicInfos` | `NSArray *` | `0x30` |
| `m_AcvNum` | `int` | `0x34` |

### `StorePackInfoDownloader` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 3 · `instanceSize`=`16`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_PackInfo` | `StorePackInfo *` | `0x4` |
| `m_Downloader` | `Downloader *` | `0x8` |
| `m_Delegate` | `<StorePackInfoDownloaderDelegate> *` | `0xc` |

### `StorePackListController` — ✅ complete

Methods **19/19** · unimpl 0 · ivars 10 · `instanceSize`=`41`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_ArrayPackInfo` | `NSMutableArray *` | `0x4` |
| `m_ListPackID` | `NSMutableArray *` | `0x8` |
| `m_PromotionList` | `NSArray *` | `0xc` |
| `m_PacklistDownloader` | `Downloader *` | `0x10` |
| `tmp_pack_list` | `NSDictionary *` | `0x14` |
| `m_ProductsRequest` | `SKProductsRequest *` | `0x18` |
| `m_SelfRetain` | `StorePackListController *` | `0x1c` |
| `m_Delegate` | `<StorePackListDelegate> *` | `0x20` |
| `m_FetchedPackNum` | `unsigned int` | `0x24` |
| `m_PacklistContinued` | `BOOL` | `0x28` |

### `StorePackMusicView` — ✅ complete

Methods **14/14** · unimpl 0 · ivars 9 · `instanceSize`=`88`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `artworkView` | `StoreImageView *` | `0x34` |
| `labelName` | `UILabel *` | `0x38` |
| `labelArtist` | `UILabel *` | `0x3c` |
| `labelLevels` | `UILabel *` | `0x40` |
| `indicatorSample` | `UIActivityIndicatorView *` | `0x44` |
| `buttonSample` | `UIButton *` | `0x48` |
| `buttonLink` | `UIButton *` | `0x4c` |
| `m_BG` | `UIImageView *` | `0x50` |
| `arcadeViewer` | `UIImageView *` | `0x54` |

### `StorePackView` — ✅ complete

Methods **11/11** · unimpl 0 · ivars 11 · `instanceSize`=`96`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_BackGroundImageView` | `UIImageView *` | `0x34` |
| `m_ArtworkImageView` | `UIImageView *` | `0x38` |
| `m_ArcadeViewerImageView` | `UIImageView *` | `0x3c` |
| `m_TicketImageView` | `UIImageView *` | `0x40` |
| `m_NameLabel` | `UILabel *` | `0x44` |
| `m_CommentLabel` | `UILabel *` | `0x48` |
| `m_PriceLabel` | `UILabel *` | `0x4c` |
| `m_PurchasedButton` | `UIButton *` | `0x50` |
| `m_NewMarker` | `UIImageView *` | `0x54` |
| `m_Index` | `unsigned int` | `0x58` |
| `m_Delegate` | `<StorePackViewDelegate> *` | `0x5c` |

### `StorePromotionTableCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 0 · `instanceSize`=`52`

### `StorePromotionView` — ✅ complete

Methods **19/19** · unimpl 0 · ivars 8 · `instanceSize`=`84`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Indicator` | `UIActivityIndicatorView *` | `0x34` |
| `m_Timer` | `NSTimer *` | `0x38` |
| `m_FrontImageView` | `UIImageView *` | `0x3c` |
| `m_NextImageView` | `UIImageView *` | `0x40` |
| `m_PromotionDataArray` | `NSMutableArray *` | `0x44` |
| `m_Index` | `int` | `0x48` |
| `m_ImageDownloader` | `NSMutableArray *` | `0x4c` |
| `m_Delegate` | `<StorePromotionViewDelegate> *` | `0x50` |

### `StoreTableCell` — ✅ complete

Methods **4/4** · unimpl 0 · ivars 2 · `instanceSize`=`60`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_LeftPackView` | `StorePackView *` | `0x34` |
| `m_RightPackView` | `StorePackView *` | `0x38` |

### `StoreUtil` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`4`

### `StoreViewController` — ✅ complete

Methods **21/21** · unimpl 0 · ivars 8 · `instanceSize`=`192`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_CoverView` | `UIView *` | `0xa4` |
| `m_ModalDialog` | `StoreDialogView *` | `0xa8` |
| `m_MainNavCtrl` | `UINavigationController *` | `0xac` |
| `m_ManageNavCtrl` | `UINavigationController *` | `0xb0` |
| `m_AcvManageNavCtrl` | `UINavigationController *` | `0xb4` |
| `m_Animation` | `BOOL` | `0xb8` |
| `m_IsModalDialogAnimation` | `BOOL` | `0xb9` |
| `_recommendPackId` | `int` | `0xbc` |

### `SubMapListCell` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 1 · `instanceSize`=`56`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_mapVal` | `NSValue *` | `0x34` |

### `SubMapSelectViewController` — ✅ complete

Methods **16/16** · unimpl 0 · ivars 4 · `instanceSize`=`180`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_subMapArray` | `NSArray *` | `0xa8` |
| `_isDecide` | `BOOL` | `0xac` |
| `_delegate` | `id` | `0xb0` |

### `SystemHardware` — ✅ complete

Methods **5/5** · unimpl 0 · ivars 2 · `instanceSize`=`12`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_HardwareType` | `int` | `0x4` |
| `m_HardwareName` | `NSString *` | `0x8` |

### `TouchRangeView` — ✅ complete

Methods **7/7** · unimpl 0 · ivars 3 · `instanceSize`=`61`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_untouchedPopkun` | `UIImage *` | `0x34` |
| `_touchedPopkun` | `UIImage *` | `0x38` |
| `_isTouched` | `BOOL` | `0x3c` |

### `TouchRangeViewCtrl` — ✅ complete

Methods **11/11** · unimpl 0 · ivars 6 · `instanceSize`=`192`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_infoView` | `UIImageView *` | `0xa4` |
| `_radiusSlider` | `UISlider *` | `0xa8` |
| `_resetButton` | `UIButton *` | `0xac` |
| `_toucheRangeView` | `TouchRangeView *` | `0xb0` |
| `_touchedPoint` | `struct CGPoint` | `0xb4` |
| `_radius` | `float` | `0xbc` |

### `TouchableScrollView` — ✅ complete

Methods **2/2** · unimpl 0 · ivars 0 · `instanceSize`=`56`

### `TouchableTableView` — ✅ complete

Methods **3/3** · unimpl 0 · ivars 0 · `instanceSize`=`56`

### `TreasureData` — ✅ complete

Methods **1/1** · unimpl 0 · ivars 0 · `instanceSize`=`48`

### `TwitterUtil` — ✅ complete

Methods **6/6** · unimpl 0 · ivars 2 · `instanceSize`=`172`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Text` | `NSString *` | `0xa4` |
| `m_Img` | `UIImage *` | `0xa8` |

### `UserSettingData` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`4`

### `ViewUtility` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`4`

### `YearAndMonthPicker` — ✅ complete

Methods **9/9** · unimpl 0 · ivars 3 · `instanceSize`=`64`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_year` | `int` | `0x34` |
| `_month` | `int` | `0x38` |
| `monthArr` | `NSMutableArray *` | `0x3c` |

### `neGLView` — ✅ complete

Methods **15/15** · unimpl 0 · ivars 8 · `instanceSize`=`84`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_GLContext` | `EAGLContext *` | `0x34` |
| `m_FrontBufferWidth` | `int` | `0x38` |
| `m_FrontBufferHeight` | `int` | `0x3c` |
| `m_DefaultFramebuffer` | `unsigned int` | `0x40` |
| `m_ColorRenderbuffer` | `unsigned int` | `0x44` |
| `m_RenderBufferID` | `unsigned int` | `0x48` |
| `m_GLInterface` | `struct neIGLES *` | `0x4c` |
| `delegate` | `<GLViewDelegate> *` | `0x50` |

### `neTextureForiOS` — ✅ complete

Methods **0/0** · unimpl 0 · ivars 0 · `instanceSize`=`4`

### `neWindow` — ✅ complete

Methods **1/1** · unimpl 0 · ivars 0 · `instanceSize`=`144`


---

## C++ classes (engine / game core)

Recovered from Ghidra namespace metadata (functions named `Class::method`). Many more C++ methods
remain in the flat *free-function* pool — functions whose `param_1` is an implicit `this`; the plan is
to identify them by that `this` arg (and `___assert_rtn` source paths) and rename them into Ghidra
namespaces, promoting the pool into these class tables.

| C++ class | Methods (done/total) |
| --- | ---: |
| `AcMainTask` | 0/2 |
| `AcNoteMng` | 0/2 |
| `AepLyrCtrl` | 1/4 |
| `AepManager` | 0/9 |
| `AepOrderingTable` | 0/1 |
| `BootLogoTask` | 0/6 |
| `CharaManager` | 0/5 |
| `MainTask` | 0/4 |
| `MenuMainTask` | 0/3 |
| `NEAppEventCenter` | 0/3 |
| `NEEngine` | 0/7 |
| `NEGraphics` | 0/10 |
| `NESceneManager` | 0/4 |
| `NoteMng` | 14/16 |
| `PlayTask` | 0/2 |
| `TitleTask` | 0/4 |
