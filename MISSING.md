# PopnRhythmin — Exhaustive Missing Inventory

Machine-generated from Ghidra **rb420 / PopnRhythmin** (`__objc_classlist` walk) diffed against the
reconstructed `@ 0x…` annotations in `Project/`. Self-updating: regenerate after adding sources.

## Totals — app Objective-C classes

| Metric | Count |
| --- | ---: |
| Classes audited | 173 |
| Complete | 21 |
| Partial (file exists, methods missing) | 66 |
| Fully missing (no source file) | 86 |
| **Missing methods** | **1740** |

## Scope decisions

| Component | Owner | Action |
| --- | --- | --- |
| TouchJSON (`CJSON*`, `CDataScanner`, `CSerializedJSONData`) | ours | reconstruct |
| `RewardNetwork*` / `Recommend*` | ours (Konami ad SDK) | reconstruct (may stub first) |
| `BFCodec` (Blowfish) | ours | reconstruct |
| `UnZipArchive` (ZipArchive) | 3rd-party ([ziparchive](https://code.google.com/archive/p/ziparchive/)) | **exclude** |

## Fully missing classes — 86

| Class | Methods | Ivars | `instanceSize` |
| --- | ---: | ---: | ---: |
| `SearchView` | 31 | 17 | `251` |
| `RecommendCore` | 30 | 7 | `32` |
| `InputConversionPassViewController` | 27 | 6 | `188` |
| `InputKIDViewCtrl` | 26 | 11 | `208` |
| `RewardNetworkWebViewController` | 26 | 6 | `180` |
| `RewardNetworkURLConnection` | 25 | 9 | `40` |
| `MapSelectSplitViewController` | 24 | 20 | `248` |
| `MapSelectViewController` | 24 | 10 | `204` |
| `RecommendWebView` | 24 | 7 | `76` |
| `FriendScoreMainView` | 23 | 12 | `212` |
| `CDataScanner` | 22 | 6 | `28` |
| `InputNameViewCtrl` | 22 | 4 | `177` |
| `AcViewerOptionViewController` | 21 | 5 | `180` |
| `ConversionView` | 20 | 5 | `180` |
| `PresentBoxViewController` | 20 | 7 | `192` |
| `HowToViewCtrlPad` | 19 | 7 | `192` |
| `QuizMainViewController` | 19 | 26 | `276` |
| `AcViewerCategoryViewController` | 18 | 3 | `268` |
| `CheckerCategoryViewController` | 18 | 3 | `272` |
| `CustomAlertView` | 18 | 6 | `80` |
| `InputOTPViewCtrl` | 18 | 5 | `184` |
| `OverScoreLogViewController` | 18 | 6 | `188` |
| `RecommendViewController` | 18 | 6 | `184` |
| `PopnLinkTopViewController` | 17 | 6 | `184` |
| `SortSelectViewController` | 17 | 4 | `176` |
| `DefaultDataDownloadView` | 16 | 11 | `204` |
| `FreeRequestDetail` | 16 | 6 | `72` |
| `InviteTopViewControllerPad` | 16 | 5 | `180` |
| `SubMapSelectViewController` | 16 | 4 | `180` |
| `AcViewerMusicViewController` | 15 | 5 | `184` |
| `CustomWebView` | 15 | 10 | `116` |
| `FriendRequestTable` | 15 | 4 | `180` |
| `SettingTableSplitViewController` | 15 | 7 | `308` |
| `FreeRequestListViewController` | 14 | 4 | `180` |
| `FriendMngTopSplitViewController` | 14 | 13 | `284` |
| `FriendRequestViewController` | 14 | 4 | `180` |
| `PopnLinkTopSplitViewController` | 14 | 12 | `280` |
| `SettingTopViewController` | 14 | 2 | `168` |
| `RewardNetwork` | 13 | 2 | `12` |
| `InputKidViewController` | 12 | 3 | `176` |
| `TouchRangeViewCtrl` | 12 | 6 | `192` |
| `CommunicatingView` | 11 | 5 | `178` |
| `RandomLoginBonusView` | 11 | 9 | `104` |
| `StoreDialogView` | 11 | 5 | `72` |
| `AcViewerHiSpeedViewController` | 10 | 0 | `162` |
| `AcceptPolicyViewController` | 10 | 5 | `180` |
| `CJSONScanner` | 10 | 1 | `29` |
| `CheckerMusicViewController` | 10 | 1 | `168` |
| `HttpConn` | 10 | 6 | `28` |
| `RewardNetworkPasteBoard` | 10 | 2 | `12` |
| `AcViewerHidSudViewController` | 9 | 0 | `162` |
| `AcViewerPopKunViewController` | 9 | 0 | `162` |
| `AcViewerRanMirViewController` | 9 | 0 | `162` |
| `CustomSplitViewController` | 9 | 3 | `176` |
| `DevDataDownloader` | 9 | 6 | `25` |
| `LoginBonusView` | 9 | 3 | `61` |
| `RecommendAdId` | 9 | 1 | `8` |
| `RewardNetworkWebAPI` | 9 | 1 | `8` |
| `InviteTopViewController` | 8 | 1 | `163` |
| `MapAnnotation` | 8 | 4 | `32` |
| `CheckerDetail` | 7 | 15 | `368` |
| `DownloadImageView` | 7 | 3 | `68` |
| `DownloadProgresView` | 7 | 4 | `80` |
| `RewardNetworkIndicator` | 7 | 1 | `52` |
| `TouchRangeView` | 7 | 3 | `61` |
| `CJSONDataSerializer` | 6 | 0 | `4` |
| `RecommendWebViewController` | 6 | 0 | `153` |
| `CJSONSerializer` | 5 | 1 | `8` |
| `RewardNetworkUdid` | 5 | 1 | `8` |
| `MyInviteCodeViewController` | 4 | 0 | `162` |
| `PurchaseStore` | 4 | 1 | `5` |
| `AcViewerCategoryCell` | 3 | 0 | `52` |
| `CJSONDeserializer` | 3 | 0 | `4` |
| `CSerializedJSONData` | 3 | 1 | `8` |
| `CheckerMusicCell` | 3 | 10 | `92` |
| `FreeRequestListCell` | 3 | 11 | `96` |
| `QuizCell` | 3 | 2 | `60` |
| `RecommendNetwork` | 3 | 1 | `8` |
| `TouchableTableView` | 3 | 0 | `56` |
| `TouchableScrollView` | 2 | 0 | `56` |
| `neWindow` | 1 | 0 | `144` |
| `RecommendWebAPI` | 0 | 0 | `4` |
| `RewardNetworkError` | 0 | 0 | `4` |
| `RewardNetworkMessage` | 0 | 0 | `4` |
| `RewardNetworkUtilities` | 0 | 0 | `4` |
| `ViewUtility` | 0 | 0 | `4` |

## Partial classes — 66

| Class | Done | Total | Missing |
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
| `RecommendListCell` | 1 | 5 | 4 |
| `StorePromotionView` | 15 | 19 | 4 |
| `TwitterUtil` | 2 | 6 | 4 |
| `FriendReplyCell` | 4 | 7 | 3 |
| `FriendRequestCell` | 1 | 4 | 3 |
| `StoreDetailHeaderView` | 4 | 7 | 3 |
| `StoreDownloadTask` | 2 | 5 | 3 |
| `StoreImageView` | 4 | 7 | 3 |
| `StoreTableCell` | 1 | 4 | 3 |
| `AcViewerOptionCell` | 1 | 3 | 2 |
| `BFCodec` | 4 | 6 | 2 |
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

## Complete classes — 21

- `ArcadeScoreData`
- `CharaTicketData`
- `DelayImageView`
- `FriendListDetail`
- `FriendListDetailChara`
- `FriendListViewController`
- `FriendReplyViewController`
- `GameEffectView`
- `HowToView`
- `OverScoreData`
- `PolicyView`
- `PopkunSizeViewCtrl`
- `ScoreData`
- `SettingCustomerTableViewController`
- `SettingGameTableViewController`
- `SettingHowtoTableViewController`
- `SoundSettingView`
- `StoreUtil`
- `TreasureData`
- `UserSettingData`
- `neTextureForiOS`

---

# Per-class detail

### `SearchView` — ❌ missing

Methods **0/31** · ivars 17 · `instanceSize`=`251`

#### Missing methods

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
| `.cxx_construct` | `0x88b04` |

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

Methods **0/30** · ivars 7 · `instanceSize`=`32`

#### Missing methods

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
| `.cxx_destruct` | `0xfe798` |
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

Methods **0/27** · ivars 6 · `instanceSize`=`188`

#### Missing methods

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

Methods **0/26** · ivars 11 · `instanceSize`=`208`

#### Missing methods

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

### `RewardNetworkWebViewController` — ❌ missing

Methods **0/26** · ivars 6 · `instanceSize`=`180`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xec4d8` |
| `loadView` | `0xec514` |
| `webViewDidStartLoad:` | `0xec868` |
| `didReceiveMemoryWarning` | `0xec87c` |
| `setNavigationBarHidden:` | `0xec8a8` |
| `loadRequestWithURL:parameters:delegate:` | `0xec8b8` |
| `viewDidDisappear:` | `0xecb28` |
| `webViewDidFinishLoad:` | `0xecbd8` |
| `webView:didFailLoadWithError:` | `0xecd24` |
| `btnCloseClicked:` | `0xece64` |
| `appliListClosed` | `0xece74` |
| `updateIndicator:` | `0xecf50` |
| `webView:shouldStartLoadWithRequest:navigationType:` | `0xecf8c` |
| `shouldAutorotateToInterfaceOrientation:` | `0xed62c` |
| `shouldAutorotate` | `0xed684` |
| `supportedInterfaceOrientations` | `0xed688` |
| `rotateWebViewWithInterfaceOrientation:duration:` | `0xed6cc` |
| `willAnimateRotationToInterfaceOrientation:duration:` | `0xedf98` |
| `hasParentViewController:` | `0xee000` |
| `.cxx_destruct` | `0xee178` |
| `isNavigationBarHidden` | `0xee100` |
| `setIsNavigationBarHidden:` | `0xee110` |
| `delegate` | `0xee120` |
| `setDelegate:` | `0xee130` |
| `parentView` | `0xee140` |
| `setParentView:` | `0xee150` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_webView` | `UIWebView *` | `0x9c` |
| `_navigationBar` | `UINavigationBar *` | `0xa0` |
| `_indicator` | `RewardNetworkIndicator *` | `0xa4` |
| `_isNavigationBarHidden` | `BOOL` | `0xa8` |
| `_delegate` | `<RewardNetworkDelegate> *` | `0xac` |
| `_parentView` | `UIView *` | `0xb0` |

### `RewardNetworkURLConnection` — ❌ missing

Methods **0/25** · ivars 9 · `instanceSize`=`40`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xff9d0` |
| `requestAsynchronousWithURL:request:finishedBlock:failedBlock:` | `0xffa6c` |
| `connectionTimeout:` | `0xffd08` |
| `connection:didReceiveResponse:` | `0xffd58` |
| `connection:didReceiveData:` | `0xffe00` |
| `connectionDidFinishLoading:` | `0xffe50` |
| `connection:didFailWithError:` | `0x1001cc` |
| `retryConnection` | `0x1001dc` |
| `.cxx_destruct` | `0x100664` |
| `request` | `0x1004bc` |
| `setRequest:` | `0x1004cc` |
| `connection` | `0x1004f4` |
| `setConnection:` | `0x100504` |
| `ApplilinkFailedBlock` | `0x10052c` |
| `setApplilinkFailedBlock:` | `0x100540` |
| `receiveData` | `0x100564` |
| `setReceiveData:` | `0x100574` |
| `isConnection` | `0x10059c` |
| `setIsConnection:` | `0x1005ac` |
| `timer` | `0x1005bc` |
| `setTimer:` | `0x1005cc` |
| `url` | `0x1005f4` |
| `setUrl:` | `0x100604` |
| `ApplilinkFinishedBlock` | `0x10062c` |
| `setApplilinkFinishedBlock:` | `0x100640` |

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

### `MapSelectSplitViewController` — ❌ missing

Methods **0/24** · ivars 20 · `instanceSize`=`248`

#### Missing methods

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
| `.cxx_construct` | `0x787f0` |
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

### `MapSelectViewController` — ❌ missing

Methods **0/24** · ivars 10 · `instanceSize`=`204`

#### Missing methods

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

### `RecommendWebView` — ❌ missing

Methods **0/24** · ivars 7 · `instanceSize`=`76`

#### Missing methods

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
| `.cxx_destruct` | `0xff974` |
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

### `FriendScoreMainView` — ❌ missing

Methods **0/23** · ivars 12 · `instanceSize`=`212`

#### Missing methods

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

### `CDataScanner` — ❌ missing

Methods **0/22** · ivars 6 · `instanceSize`=`28`

#### Missing methods

| Selector | Address |
| --- | --- |
| `scanCStyleComment:` | `0x65204` |
| `scanCPlusPlusStyleComment:` | `0x65364` |
| `init` | `0x647ac` |
| `dealloc` | `0x64818` |
| `scanLocation` | `0x64870` |
| `data` | `0x64890` |
| `setData:` | `0x648a0` |
| `setScanLocation:` | `0x6496c` |
| `isAtEnd` | `0x6498c` |
| `currentCharacter` | `0x649c0` |
| `scanCharacter` | `0x649d4` |
| `scanCharacter:` | `0x649ec` |
| `scanUTF8String:intoString:` | `0x64a14` |
| `scanString:intoString:` | `0x64a98` |
| `scanCharactersFromSet:intoString:` | `0x64b40` |
| `scanUpToString:intoString:` | `0x64c1c` |
| `scanUpToCharactersFromSet:intoString:` | `0x64cc4` |
| `scanNumber:` | `0x64da0` |
| `skipWhitespace` | `0x64e14` |
| `remainingString` | `0x64e84` |
| `doubleCharacters` | `0x64f0c` |
| `setDoubleCharacters:` | `0x64f1c` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `data` | `NSData *` | `0x4` |
| `start` | `char *` | `0x8` |
| `end` | `char *` | `0xc` |
| `current` | `char *` | `0x10` |
| `length` | `unsigned int` | `0x14` |
| `doubleCharacters` | `NSCharacterSet *` | `0x18` |

### `InputNameViewCtrl` — ❌ missing

Methods **0/22** · ivars 4 · `instanceSize`=`177`

#### Missing methods

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

### `AcViewerOptionViewController` — ❌ missing

Methods **0/21** · ivars 5 · `instanceSize`=`180`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xdeff0` |
| `initForAcMain:` | `0xdfc0c` |
| `viewDidLoad` | `0xdfe30` |
| `viewWillAppear:` | `0xdfee0` |
| `handleGesture:` | `0xdff0c` |
| `numberOfSectionsInTableView:` | `0xdff78` |
| `tableView:numberOfRowsInSection:` | `0xdff7c` |
| `tableView:cellForRowAtIndexPath:` | `0xdff88` |
| `tableView:titleForHeaderInSection:` | `0xe00c0` |
| `tableView:accessoryTypeForRowWithIndexPath:` | `0xe00c4` |
| `tableView:didSelectRowAtIndexPath:` | `0xe00c8` |
| `touchedPlayButton:` | `0xe0374` |
| `touchedResumeButton:` | `0xe0490` |
| `touchedBackButton:` | `0xe053c` |
| `sendLog` | `0xe0664` |
| `startOpenAnimationForAcMain` | `0xe0820` |
| `startCloseAnimation` | `0xe0960` |
| `endCloseAnimation` | `0xe0a78` |
| `endCloseAnimationForAcMain` | `0xe0ad4` |
| `delegate` | `0xe0b20` |
| `setDelegate:` | `0xe0b30` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_naviCtrl` | `UINavigationController *` | `0xa4` |
| `_forAcMain` | `BOOL` | `0xa8` |
| `_isAnimationing` | `BOOL` | `0xa9` |
| `_pAcMain` | `struct AcMainTask *` | `0xac` |
| `_delegate` | `<AcViewerViewControllerDelegate> *` | `0xb0` |

### `ConversionView` — ❌ missing

Methods **0/20** · ivars 5 · `instanceSize`=`180`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x1be48` |
| `dealloc` | `0x1be84` |
| `viewDidLoad` | `0x1beb0` |
| `didReceiveMemoryWarning` | `0x1ca9c` |
| `viewDidUnload` | `0x1cac8` |
| `viewWillAppear:` | `0x1caf4` |
| `viewDidAppear:` | `0x1cb20` |
| `viewWillDisappear:` | `0x1cb4c` |
| `viewDidDisappear:` | `0x1cb78` |
| `shouldAutorotateToInterfaceOrientation:` | `0x1cba4` |
| `backButtonFunc` | `0x1cbb0` |
| `okButtonFunc` | `0x1cc4c` |
| `commonAlertView:clickedButtonAtIndex:` | `0x1cd00` |
| `startConversionHttp` | `0x1cf0c` |
| `downloaderFinished:` | `0x1da60` |
| `downloaderError:` | `0x1dc84` |
| `startCloseAnimation` | `0x1dd50` |
| `endCloseAnimation` | `0x1de20` |
| `delegate` | `0x1de7c` |
| `setDelegate:` | `0x1de8c` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `isAnimationing` | `BOOL` | `0xa2` |
| `_indicator` | `UIActivityIndicatorView *` | `0xa4` |
| `_downloader` | `Downloader *` | `0xa8` |
| `_delegate` | `<ViewCmnProtocol> *` | `0xac` |
| `_convertCodeStr` | `NSString *` | `0xb0` |

### `PresentBoxViewController` — ❌ missing

Methods **0/20** · ivars 7 · `instanceSize`=`192`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:` | `0x24098` |
| `initAtNavigationController` | `0x24938` |
| `dealloc` | `0x24988` |
| `viewDidLoad` | `0x24abc` |
| `viewWillAppear:` | `0x24ba4` |
| `didReceiveMemoryWarning` | `0x24c6c` |
| `startOpenAnimation` | `0x24c98` |
| `endOpenAnimation` | `0x2514c` |
| `startCloseAnimation` | `0x25160` |
| `endCloseAnimation` | `0x255bc` |
| `numberOfSectionsInTableView:` | `0x25628` |
| `tableView:numberOfRowsInSection:` | `0x2562c` |
| `tableView:cellForRowAtIndexPath:` | `0x25668` |
| `downloadMainFinished:` | `0x257a8` |
| `backButtonFunc` | `0x25cdc` |
| `allGetFunc` | `0x25d48` |
| `indexPathForControlEvent:` | `0x25db4` |
| `touchedGetButton:event:` | `0x25e34` |
| `customAlertView:clickedButtonAtIndex:` | `0x260a4` |
| `isAnimationing` | `0x26144` |

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

### `HowToViewCtrlPad` — ❌ missing

Methods **0/19** · ivars 7 · `instanceSize`=`192`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFileNameArray:` | `0x16718` |
| `dealloc` | `0x1676c` |
| `viewDidLoad` | `0x16808` |
| `viewWillAppear:` | `0x16adc` |
| `viewDidAppear:` | `0x16b40` |
| `didReceiveMemoryWarning` | `0x1718c` |
| `viewWillDisappear:` | `0x171b8` |
| `pageControlDidChanged:` | `0x171e4` |
| `scrollViewDidScroll:` | `0x1727c` |
| `startOpenAnimation` | `0x17378` |
| `endOpenAnimation` | `0x174a4` |
| `startCloseAnimation` | `0x174b8` |
| `endCloseAnimation` | `0x175d8` |
| `setPageImages` | `0x17634` |
| `handleTapCoverView:` | `0x178f8` |
| `backGroundImage` | `0x1791c` |
| `setBackGroundImage:` | `0x17930` |
| `pageCtrl` | `0x17940` |
| `setPageCtrl:` | `0x17954` |

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

### `QuizMainViewController` — ❌ missing

Methods **0/19** · ivars 26 · `instanceSize`=`276`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:` | `0xda198` |
| `dealloc` | `0xdb2a4` |
| `viewDidLoad` | `0xdb3d4` |
| `didReceiveMemoryWarning` | `0xdb438` |
| `numberOfSectionsInTableView:` | `0xdb464` |
| `tableView:numberOfRowsInSection:` | `0xdb468` |
| `tableView:cellForRowAtIndexPath:` | `0xdb538` |
| `tableView:titleForHeaderInSection:` | `0xdb674` |
| `tableView:didSelectRowAtIndexPath:` | `0xdb678` |
| `downloaderFinished:` | `0xdb730` |
| `downloaderProceed:` | `0xdb7ac` |
| `downloaderError:` | `0xdb7b0` |
| `touchedBackButton:` | `0xdb8cc` |
| `getQuizFinished` | `0xdb968` |
| `replyQuizFinished` | `0xdbda4` |
| `startGetQuizHttp` | `0xdc2b8` |
| `startReplyQuizHttp` | `0xdc36c` |
| `drawResult` | `0xdc4ec` |
| `touchesBegan:withEvent:` | `0xdca68` |

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

### `AcViewerCategoryViewController` — ❌ missing

Methods **0/18** · ivars 3 · `instanceSize`=`268`

#### Missing methods

| Selector | Address |
| --- | --- |
| `getAcMusicData:` | `0x687f0` |
| `initWithStyle:` | `0x68804` |
| `initAtNavigationController` | `0x68d40` |
| `dealloc` | `0x68ec8` |
| `viewDidLoad` | `0x68f30` |
| `didReceiveMemoryWarning` | `0x6903c` |
| `startOpenAnimation` | `0x69068` |
| `endOpenAnimation` | `0x691a0` |
| `startCloseAnimation` | `0x691b8` |
| `endCloseAnimation` | `0x692c0` |
| `numberOfSectionsInTableView:` | `0x6932c` |
| `tableView:numberOfRowsInSection:` | `0x69330` |
| `tableView:cellForRowAtIndexPath:` | `0x69378` |
| `tableView:titleForHeaderInSection:` | `0x694c4` |
| `tableView:didSelectRowAtIndexPath:` | `0x694c8` |
| `touchedBackButton:` | `0x696c4` |
| `delegate` | `0x69740` |
| `setDelegate:` | `0x69750` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_acMusicDataArray` | `NSArray *[24]` | `0xa4` |
| `_isAnimationing` | `BOOL` | `0x104` |
| `_delegate` | `<AcViewerViewControllerDelegate> *` | `0x108` |

### `CheckerCategoryViewController` — ❌ missing

Methods **0/18** · ivars 3 · `instanceSize`=`272`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:` | `0xcfb88` |
| `dealloc` | `0xd04bc` |
| `viewDidLoad` | `0xd0564` |
| `viewWillAppear:` | `0xd05c4` |
| `didReceiveMemoryWarning` | `0xd0688` |
| `startGetArcadeScoreHttpWithOtp:` | `0xd06b4` |
| `numberOfSectionsInTableView:` | `0xd0810` |
| `tableView:numberOfRowsInSection:` | `0xd0814` |
| `tableView:cellForRowAtIndexPath:` | `0xd085c` |
| `tableView:titleForHeaderInSection:` | `0xd0988` |
| `tableView:didSelectRowAtIndexPath:` | `0xd098c` |
| `downloaderFinished:` | `0xd0ad8` |
| `downloaderProceed:` | `0xd1884` |
| `downloaderError:` | `0xd1888` |
| `touchedBackButton:` | `0xd1960` |
| `touchedGetDataButton:` | `0xd1a18` |
| `convertReplaceChara:` | `0xd1b40` |
| `convertCategoryId:` | `0xd1cac` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_scoreDataArray` | `NSArray *[25]` | `0xa8` |
| `_dlGetArcadeScoreData` | `Downloader *` | `0x10c` |

### `CustomAlertView` — ❌ missing

Methods **0/18** · ivars 6 · `instanceSize`=`80`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x26880` |
| `setTitleColor:` | `0x268ac` |
| `setTextColor:` | `0x268cc` |
| `setTitleFontSize:` | `0x268ec` |
| `setTextFontSize:` | `0x26940` |
| `setOpenAnimeType:` | `0x26994` |
| `setCloseAnimeType:` | `0x269ac` |
| `initWithType:title:message:cancelButtonTitle:otherButtonTitle:` | `0x269c4` |
| `initWithView:type:title:message:cancelButtonTitle:otherButtonTitle:` | `0x26a60` |
| `initWithView:center:type:title:message:cancelButtonTitle:otherButtonTitle:` | `0x26abc` |
| `show` | `0x274fc` |
| `removeView` | `0x277b8` |
| `endCloseAnimation` | `0x27ad0` |
| `clickedYesButton:` | `0x27ae0` |
| `clickedNoButton:` | `0x27b34` |
| `customAlertView:clickedButtonAtIndex:` | `0x27b88` |
| `delegate` | `0x27b8c` |
| `setDelegate:` | `0x27b9c` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `mDelegate` | `<CustomAlertViewDelegate> *` | `0x38` |
| `mBgImageView` | `UIView *` | `0x3c` |
| `_title` | `UILabel *` | `0x40` |
| `_text` | `CustomTextView *` | `0x44` |
| `m_OpenAnimeType` | `int` | `0x48` |
| `m_CloseAnimeType` | `int` | `0x4c` |

### `InputOTPViewCtrl` — ❌ missing

Methods **0/18** · ivars 5 · `instanceSize`=`184`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithCategoryView:` | `0x78d18` |
| `didReceiveMemoryWarning` | `0x79518` |
| `dealloc` | `0x79544` |
| `viewDidLoad` | `0x79590` |
| `viewDidUnload` | `0x795bc` |
| `viewWillAppear:` | `0x795e8` |
| `viewDidAppear:` | `0x79614` |
| `viewWillDisappear:` | `0x79640` |
| `viewDidDisappear:` | `0x7966c` |
| `shouldAutorotateToInterfaceOrientation:` | `0x79698` |
| `textFieldShouldBeginEditing:` | `0x796a4` |
| `textFieldShouldReturn:` | `0x796a8` |
| `touchedDecideButton:` | `0x796d4` |
| `touchedBackButton:` | `0x797c4` |
| `endDirectCloseAnimation` | `0x79860` |
| `textField:shouldChangeCharactersInRange:replacementString:` | `0x798bc` |
| `keyboardWasShown:` | `0x798f8` |
| `keyboardWillBeHidden:` | `0x798fc` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_categoryView` | `CheckerCategoryViewController *` | `0xa4` |
| `_scrollView` | `TouchableScrollView *` | `0xa8` |
| `_otpField` | `UITextField *` | `0xac` |
| `_dummyView` | `UIViewController *` | `0xb0` |
| `_scrollOffset` | `float` | `0xb4` |

### `OverScoreLogViewController` — ❌ missing

Methods **0/18** · ivars 6 · `instanceSize`=`188`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:` | `0x29928` |
| `initAtNavigationController:` | `0x29e24` |
| `dealloc` | `0x29fd8` |
| `viewDidLoad` | `0x2a08c` |
| `didReceiveMemoryWarning` | `0x2a180` |
| `startOpenAnimation` | `0x2a1b0` |
| `endOpenAnimation` | `0x2a664` |
| `startCloseAnimation` | `0x2a678` |
| `endCloseAnimation` | `0x2aad4` |
| `numberOfSectionsInTableView:` | `0x2ab80` |
| `tableView:heightForRowAtIndexPath:` | `0x2ab84` |
| `tableView:numberOfRowsInSection:` | `0x2abe0` |
| `tableView:cellForRowAtIndexPath:` | `0x2ac1c` |
| `tableView:didSelectRowAtIndexPath:` | `0x2ad28` |
| `downloadMainFinished:` | `0x2adac` |
| `backButtonFunc` | `0x2aefc` |
| `musicSelTask` | `0x2af2c` |
| `setMusicSelTask:` | `0x2af40` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_isAnimationing` | `BOOL` | `0xa8` |
| `_overScoreLogDataArray` | `NSMutableArray *` | `0xac` |
| `_musicSelTask` | `struct MusicSelTask *` | `0xb0` |
| `m_musicId` | `int` | `0xb4` |
| `m_sheet` | `int` | `0xb8` |

### `RecommendViewController` — ❌ missing

Methods **0/18** · ivars 6 · `instanceSize`=`184`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:` | `0xbbd68` |
| `initAtNavigationController:` | `0xbc30c` |
| `dealloc` | `0xbc4c0` |
| `viewDidLoad` | `0xbc524` |
| `didReceiveMemoryWarning` | `0xbc5b4` |
| `startOpenAnimation` | `0xbc5e0` |
| `endOpenAnimation` | `0xbca94` |
| `startCloseAnimation` | `0xbcaa8` |
| `endCloseAnimation` | `0xbcf54` |
| `numberOfSectionsInTableView:` | `0xbcfc0` |
| `tableView:numberOfRowsInSection:` | `0xbcfc4` |
| `tableView:cellForRowAtIndexPath:` | `0xbcfec` |
| `tableView:titleForHeaderInSection:` | `0xbd0f8` |
| `tableView:didSelectRowAtIndexPath:` | `0xbd0fc` |
| `touchedBackButton:` | `0xbd2c4` |
| `musicSelTask` | `0xbd3d4` |
| `setMusicSelTask:` | `0xbd3e8` |
| `isAnimationing` | `0xbd400` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_storeView` | `StoreViewController *` | `0xa8` |
| `_recommendDataArray` | `NSArray *` | `0xac` |
| `_isAnimationing` | `BOOL` | `0xb0` |
| `_isBack` | `BOOL` | `0xb1` |
| `_pMusicSelTask` | `void *` | `0xb4` |

### `PopnLinkTopViewController` — ❌ missing

Methods **0/17** · ivars 6 · `instanceSize`=`184`

#### Missing methods

| Selector | Address |
| --- | --- |
| `updateButtonEnable` | `0xcca48` |
| `init` | `0xccacc` |
| `initAtNavigationController` | `0xcd2e0` |
| `viewDidLoad` | `0xcd4b8` |
| `viewWillAppear:` | `0xcd4e4` |
| `didReceiveMemoryWarning` | `0xcd57c` |
| `startOpenAnimation` | `0xcd5a8` |
| `endOpenAnimation` | `0xcd8f4` |
| `startCloseAnimation` | `0xcd908` |
| `endCloseAnimation` | `0xcda68` |
| `onInKidButtonTouched:` | `0xcdad4` |
| `onScoreCheckerButtonTouched:` | `0xcdc18` |
| `onQuizButtonTouched:` | `0xcdd5c` |
| `delegate` | `0xcdea0` |
| `setDelegate:` | `0xcdeb0` |
| `scrollView` | `0xcdec0` |
| `setScrollView:` | `0xcded0` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_btnId` | `UIButton *` | `0xa4` |
| `_btnChecker` | `UIButton *` | `0xa8` |
| `_btnQuiz` | `UIButton *` | `0xac` |
| `_delegate` | `id` | `0xb0` |
| `_scrollView` | `UIScrollView *` | `0xb4` |

### `SortSelectViewController` — ❌ missing

Methods **0/17** · ivars 4 · `instanceSize`=`176`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:` | `0xc5988` |
| `initAtNavigationController:` | `0xc6018` |
| `dealloc` | `0xc61cc` |
| `viewDidLoad` | `0xc6230` |
| `didReceiveMemoryWarning` | `0xc625c` |
| `startOpenAnimation` | `0xc6288` |
| `endOpenAnimation` | `0xc673c` |
| `startCloseAnimation` | `0xc6750` |
| `endCloseAnimation` | `0xc6c0c` |
| `numberOfSectionsInTableView:` | `0xc6c78` |
| `tableView:numberOfRowsInSection:` | `0xc6c7c` |
| `tableView:cellForRowAtIndexPath:` | `0xc6ca4` |
| `tableView:titleForHeaderInSection:` | `0xc6db0` |
| `tableView:didSelectRowAtIndexPath:` | `0xc6db4` |
| `backButtonFunc` | `0xc6fe4` |
| `musicSelTask` | `0xc7028` |
| `setMusicSelTask:` | `0xc703c` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_pMusicSelTask` | `void *` | `0xa4` |
| `_sortDataArray` | `NSArray *` | `0xa8` |
| `_dummyView` | `UIViewController *` | `0xac` |

### `DefaultDataDownloadView` — ❌ missing

Methods **0/16** · ivars 11 · `instanceSize`=`204`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFileDataArray:` | `0xdd158` |
| `viewDidLoad` | `0xdd3d4` |
| `didReceiveMemoryWarning` | `0xdd400` |
| `dealloc` | `0xdd42c` |
| `downloadWithIdx:` | `0xdd4c0` |
| `downloaderFinished:` | `0xdd6fc` |
| `downloaderProceed:` | `0xdd9cc` |
| `downloaderError:` | `0xddaf4` |
| `startOpenAnimation` | `0xddbe8` |
| `endOpenAnimation` | `0xddcd8` |
| `startCloseAnimation` | `0xddf38` |
| `endCloseAnimation` | `0xde028` |
| `isDigit:` | `0xde084` |
| `setJustDownloadedSize` | `0xde114` |
| `isFailed` | `0xde1a0` |
| `setIsFailed:` | `0xde1b8` |

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

### `FreeRequestDetail` — ❌ missing

Methods **0/16** · ivars 6 · `instanceSize`=`72`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:friendData:` | `0xe3170` |
| `addCntNum:sheet:y:view:` | `0xe40ac` |
| `deallc` | `0xe4278` |
| `startOpenAnimation` | `0xe42f8` |
| `endOpenAnimation` | `0xe43d0` |
| `startCloseAnimation` | `0xe43e8` |
| `endCloseAnimation` | `0xe44a8` |
| `downloaderFinished:` | `0xe44e0` |
| `downloaderProceed:` | `0xe46a0` |
| `downloaderError:` | `0xe46a4` |
| `commonAlertView:clickedButtonAtIndex:` | `0xe476c` |
| `startRequestFriendHttp` | `0xe477c` |
| `touchedCancel` | `0xe490c` |
| `touchesEnded:withEvent:` | `0xe493c` |
| `isAnimationing` | `0xe4994` |
| `isEnabled` | `0xe49ac` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIView *` | `0x34` |
| `_friendData` | `NSValue *` | `0x38` |
| `_isAnimationing` | `BOOL` | `0x3c` |
| `_isEnabled` | `BOOL` | `0x3d` |
| `_downloader` | `Downloader *` | `0x40` |
| `_scaleForPad` | `float` | `0x44` |

### `InviteTopViewControllerPad` — ❌ missing

Methods **0/16** · ivars 5 · `instanceSize`=`180`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initAtNavigationController` | `0x5c638` |
| `dealloc` | `0x5d0fc` |
| `touchedDecideButton:` | `0x5d128` |
| `startOpenAnimation` | `0x5d350` |
| `endOpenAnimation` | `0x5d488` |
| `startCloseAnimation` | `0x5d4a0` |
| `endCloseAnimation` | `0x5d5c0` |
| `textFieldShouldBeginEditing:` | `0x5d61c` |
| `textFieldDidEndEditing:` | `0x5d654` |
| `textFieldShouldReturn:` | `0x5d698` |
| `textField:shouldChangeCharactersInRange:replacementString:` | `0x5d6c0` |
| `downloaderFinished:` | `0x5d728` |
| `downloaderError:` | `0x5d944` |
| `commonAlertView:clickedButtonAtIndex:` | `0x5da10` |
| `startInviteHttp:` | `0x5da14` |
| `onTweetButton` | `0x5db50` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `isAnimationing` | `BOOL` | `0xa2` |
| `_codeField` | `UITextField *` | `0xa4` |
| `_indicator` | `UIActivityIndicatorView *` | `0xa8` |
| `_downloader` | `Downloader *` | `0xac` |
| `_scrollView` | `UIScrollView *` | `0xb0` |

### `SubMapSelectViewController` — ❌ missing

Methods **0/16** · ivars 4 · `instanceSize`=`180`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithTreasureData:mapHeadArray:mainMapId:` | `0xc1ea0` |
| `dealloc` | `0xc2910` |
| `viewDidLoad` | `0xc2aa0` |
| `handleGesture:` | `0xc2b80` |
| `didReceiveMemoryWarning` | `0xc2bec` |
| `numberOfSectionsInTableView:` | `0xc2c18` |
| `tableView:numberOfRowsInSection:` | `0xc2c1c` |
| `tableView:cellForRowAtIndexPath:` | `0xc2c44` |
| `tableView:titleForHeaderInSection:` | `0xc2d50` |
| `tableView:didSelectRowAtIndexPath:` | `0xc2d54` |
| `startCloseAnimation` | `0xc3088` |
| `endCloseAnimation` | `0xc31a8` |
| `downloadMainFinished:` | `0xc3204` |
| `backButtonFunc` | `0xc3280` |
| `delegate` | `0xc3334` |
| `setDelegate:` | `0xc3344` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_subMapArray` | `NSArray *` | `0xa8` |
| `_isDecide` | `BOOL` | `0xac` |
| `_delegate` | `id` | `0xb0` |

### `AcViewerMusicViewController` — ❌ missing

Methods **0/15** · ivars 5 · `instanceSize`=`184`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithData:` | `0xcba44` |
| `dealloc` | `0xcc218` |
| `viewDidLoad` | `0xcc2ec` |
| `handleGesture:` | `0xcc31c` |
| `didReceiveMemoryWarning` | `0xcc388` |
| `numberOfSectionsInTableView:` | `0xcc3b4` |
| `tableView:numberOfRowsInSection:` | `0xcc3b8` |
| `tableView:cellForRowAtIndexPath:` | `0xcc3e0` |
| `tableView:titleForHeaderInSection:` | `0xcc588` |
| `touchedBackButton:` | `0xcc58c` |
| `touchedChangeButton:` | `0xcc664` |
| `indexPathForControlEvent:` | `0xcc7ac` |
| `touchedSheetButton:event:` | `0xcc82c` |
| `delegate` | `0xcca24` |
| `setDelegate:` | `0xcca34` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_acMusicDataArray` | `NSArray *` | `0xa4` |
| `_genreButton` | `UIImage *` | `0xa8` |
| `_titleButton` | `UIImage *` | `0xac` |
| `_changeButton` | `UIButton *` | `0xb0` |
| `_delegate` | `<AcViewerViewControllerDelegate> *` | `0xb4` |

### `CustomWebView` — ❌ missing

Methods **0/15** · ivars 10 · `instanceSize`=`116`

#### Missing methods

| Selector | Address |
| --- | --- |
| `setErrorMsg:text:` | `0x5df50` |
| `dealloc` | `0x5df80` |
| `initWithFrame:` | `0x5dfe8` |
| `initWithURL:` | `0x5dfec` |
| `pushCloseBtn` | `0x5e6b8` |
| `close` | `0x5e6e8` |
| `webViewDidStartLoad:` | `0x5e808` |
| `webViewDidFinishLoad:` | `0x5e874` |
| `webView:didFailLoadWithError:` | `0x5eb04` |
| `webView:shouldStartLoadWithRequest:navigationType:` | `0x5ebb4` |
| `observeValueForKeyPath:ofObject:change:context:` | `0x5ec5c` |
| `SetCloseCallback:param:` | `0x5ed7c` |
| `showErrorAlert` | `0x5ed9c` |
| `touchedFollowButton` | `0x5ee38` |
| `.cxx_construct` | `0x5ef8c` |

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

### `FriendRequestTable` — ❌ missing

Methods **0/15** · ivars 4 · `instanceSize`=`180`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:` | `0xb7148` |
| `dealloc` | `0xb794c` |
| `viewDidLoad` | `0xb79e8` |
| `didReceiveMemoryWarning` | `0xb7a28` |
| `reDownloadGetFriendRequest` | `0xb7a54` |
| `numberOfSectionsInTableView:` | `0xb7b98` |
| `tableView:numberOfRowsInSection:` | `0xb7b9c` |
| `tableView:cellForRowAtIndexPath:` | `0xb7bc4` |
| `tableView:titleForHeaderInSection:` | `0xb7cd0` |
| `tableView:didSelectRowAtIndexPath:` | `0xb7cd4` |
| `releaseSendDataArray` | `0xb7cd8` |
| `backButtonFunc` | `0xb7d9c` |
| `downloaderFinished:` | `0xb7e38` |
| `downloaderProceed:` | `0xb84dc` |
| `downloaderError:` | `0xb84e0` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_lonelyImageView` | `UIImageView *` | `0xa8` |
| `dlGetFriendRequest` | `Downloader *` | `0xac` |
| `_sendDataArray` | `NSMutableArray *` | `0xb0` |

### `SettingTableSplitViewController` — ❌ missing

Methods **0/15** · ivars 7 · `instanceSize`=`308`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xb5cb0` |
| `dealloc` | `0xb6614` |
| `viewDidLoad` | `0xb6684` |
| `didReceiveMemoryWarning` | `0xb66b0` |
| `startOpenAnimation` | `0xb66dc` |
| `endOpenAnimation` | `0xb6808` |
| `startCloseAnimation` | `0xb6820` |
| `endCloseAnimation` | `0xb6928` |
| `onGameButtonTouched:` | `0xb6984` |
| `onHowtoButtonTouched:` | `0xb6998` |
| `onCustomerButtonTouched:` | `0xb69ac` |
| `onOtherButtonTouched:` | `0xb69c0` |
| `startViewAnimation:` | `0xb69d4` |
| `handleTapCoverView` | `0xb7100` |
| `.cxx_construct` | `0xb7144` |

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

### `FreeRequestListViewController` — ❌ missing

Methods **0/14** · ivars 4 · `instanceSize`=`180`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:` | `0xe5430` |
| `dealloc` | `0xe5bb4` |
| `viewDidLoad` | `0xe5c5c` |
| `didReceiveMemoryWarning` | `0xe5ccc` |
| `numberOfSectionsInTableView:` | `0xe5cf8` |
| `tableView:numberOfRowsInSection:` | `0xe5cfc` |
| `tableView:cellForRowAtIndexPath:` | `0xe5d24` |
| `tableView:titleForHeaderInSection:` | `0xe5e3c` |
| `tableView:didSelectRowAtIndexPath:` | `0xe5e40` |
| `releaseFriendList` | `0xe60cc` |
| `downloaderFinished:` | `0xe61e0` |
| `downloaderError:` | `0xe6c80` |
| `startGetRecommendFriendHttp` | `0xe6d60` |
| `backButtonFunc` | `0xe6ea4` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_frinedDataArray` | `NSArray *` | `0xa8` |
| `_downloader` | `Downloader *` | `0xac` |
| `_freeRequestDetail` | `FreeRequestDetail *` | `0xb0` |

### `FriendMngTopSplitViewController` — ❌ missing

Methods **0/14** · ivars 13 · `instanceSize`=`284`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xc3358` |
| `dealloc` | `0xc3bbc` |
| `viewDidLoad` | `0xc3c2c` |
| `didReceiveMemoryWarning` | `0xc3c58` |
| `viewWillAppear:` | `0xc3c84` |
| `startOpenAnimation` | `0xc3d08` |
| `endOpenAnimation` | `0xc3e34` |
| `startCloseAnimation` | `0xc3f68` |
| `endCloseAnimation` | `0xc4070` |
| `onListButtonTouched:` | `0xc40d0` |
| `onRequestButtonTouched:` | `0xc4760` |
| `onReplyButtonTouched:` | `0xc4df0` |
| `handleTapCoverView` | `0xc53d0` |
| `.cxx_construct` | `0xc5414` |

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

### `FriendRequestViewController` — ❌ missing

Methods **0/14** · ivars 4 · `instanceSize`=`180`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xb1c08` |
| `dealloc` | `0xb27bc` |
| `viewDidLoad` | `0xb28ac` |
| `didReceiveMemoryWarning` | `0xb2908` |
| `textFieldShouldBeginEditing:` | `0xb2934` |
| `textFieldShouldReturn:` | `0xb2938` |
| `textField:shouldChangeCharactersInRange:replacementString:` | `0xb2960` |
| `touchedRequestButton:` | `0xb29c8` |
| `touchedFreeRequestButton:` | `0xb2bb0` |
| `downloaderFinished:` | `0xb2ccc` |
| `downloaderError:` | `0xb2ecc` |
| `downloadMainFinished:` | `0xb2f98` |
| `startFriendRequestHttp:` | `0xb303c` |
| `backButtonFunc` | `0xb317c` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_playerIdField` | `UITextField *` | `0xa4` |
| `_indicator` | `UIActivityIndicatorView *` | `0xa8` |
| `_requestTable` | `FriendRequestTable *` | `0xac` |
| `_downloader` | `Downloader *` | `0xb0` |

### `PopnLinkTopSplitViewController` — ❌ missing

Methods **0/14** · ivars 12 · `instanceSize`=`280`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xe0b40` |
| `dealloc` | `0xe1430` |
| `viewDidLoad` | `0xe14e0` |
| `didReceiveMemoryWarning` | `0xe150c` |
| `startOpenAnimation` | `0xe1538` |
| `endOpenAnimation` | `0xe1840` |
| `startCloseAnimation` | `0xe1858` |
| `endCloseAnimation` | `0xe1960` |
| `onInKidButtonTouched:` | `0xe19c0` |
| `onScoreCheckerButtonTouched:` | `0xe1fa8` |
| `onQuizButtonTouched:` | `0xe25b0` |
| `reloadLeftView` | `0xe2bb8` |
| `handleTapCoverView` | `0xe2bf4` |
| `.cxx_construct` | `0xe2c38` |

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

### `SettingTopViewController` — ❌ missing

Methods **0/14** · ivars 2 · `instanceSize`=`168`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x13fe8` |
| `initAtNavigationController` | `0x14464` |
| `viewDidLoad` | `0x1463c` |
| `didReceiveMemoryWarning` | `0x14668` |
| `startOpenAnimation` | `0x14694` |
| `endOpenAnimation` | `0x147c0` |
| `startCloseAnimation` | `0x147d8` |
| `endCloseAnimation` | `0x148f8` |
| `onGameButtonTouched:` | `0x14964` |
| `onHowtoButtonTouched:` | `0x14a90` |
| `onCustomerButtonTouched:` | `0x14ae0` |
| `onOtherButtonTouched:` | `0x14b30` |
| `settingTopDelegate` | `0x14b80` |
| `setSettingTopDelegate:` | `0x14b90` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_settingTopDelegate` | `<SettingTopViewControllerDalegate> *` | `0xa4` |

### `RewardNetwork` — ❌ missing

Methods **0/13** · ivars 2 · `instanceSize`=`12`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initializeFlg` | `0xee3f8` |
| `setInitializeFlg:` | `0xee438` |
| `init` | `0xee634` |
| `openAppListWebViewWithCampaignId:inCompany:type:offset:limit:parentView:delegate:` | `0xf0a80` |
| `appListWithCampaignId:inCompany:type:offset:limit:callback:` | `0xf12d4` |
| `rotateAppliListWithInterfaceOrientation:duration:` | `0xf1ff8` |
| `setTemporaryCacheWithKey:value:expiration:` | `0xf2030` |
| `getTemporaryCacheWithKey:` | `0xf2168` |
| `appliIdListWithType:callback:` | `0xf22e0` |
| `postAppliInstallReportWithAppliList:callback:` | `0xf25fc` |
| `postAlreadyInstallAppWithCallback:` | `0xf2a48` |
| `debugLog` | `0xf3bf4` |
| `.cxx_destruct` | `0xf3bf8` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_webViewController` | `RewardNetworkWebViewController *` | `0x4` |
| `_initializeFlg` | `int` | `0x8` |

### `InputKidViewController` — ❌ missing

Methods **0/12** · ivars 3 · `instanceSize`=`176`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xe7cec` |
| `viewDidLoad` | `0xe84ec` |
| `didReceiveMemoryWarning` | `0xe8518` |
| `textFieldShouldBeginEditing:` | `0xe8544` |
| `textFieldShouldReturn:` | `0xe8548` |
| `textField:shouldChangeCharactersInRange:replacementString:` | `0xe8570` |
| `touchedDecideButton:` | `0xe85d8` |
| `touchedBackButton` | `0xe87fc` |
| `downloaderFinished:` | `0xe8840` |
| `downloaderError:` | `0xe8a5c` |
| `commonAlertView:clickedButtonAtIndex:` | `0xe8b28` |
| `startInviteHttp:` | `0xe8b5c` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_codeField` | `UITextField *` | `0xa4` |
| `_indicator` | `UIActivityIndicatorView *` | `0xa8` |
| `_downloader` | `Downloader *` | `0xac` |

### `TouchRangeViewCtrl` — ❌ missing

Methods **0/12** · ivars 6 · `instanceSize`=`192`

#### Missing methods

| Selector | Address |
| --- | --- |
| `viewDidLoad` | `0x8a360` |
| `didReceiveMemoryWarning` | `0x8a9d0` |
| `viewWillDisappear:` | `0x8a9fc` |
| `sliderValChanged:` | `0x8aa9c` |
| `touchedResetButton:` | `0x8aad0` |
| `isEnablePoint:` | `0x8ab04` |
| `touchesBegan:withEvent:` | `0x8abd0` |
| `touchesMoved:withEvent:` | `0x8ad0c` |
| `touchesEnded:withEvent:` | `0x8af28` |
| `touchesCancelled:withEvent:` | `0x8b15c` |
| `backButtonFunc` | `0x8b16c` |
| `.cxx_construct` | `0x8b208` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_infoView` | `UIImageView *` | `0xa4` |
| `_radiusSlider` | `UISlider *` | `0xa8` |
| `_resetButton` | `UIButton *` | `0xac` |
| `_toucheRangeView` | `TouchRangeView *` | `0xb0` |
| `_touchedPoint` | `struct CGPoint` | `0xb4` |
| `_radius` | `float` | `0xbc` |

### `CommunicatingView` — ❌ missing

Methods **0/11** · ivars 5 · `instanceSize`=`178`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xde740` |
| `viewDidLoad` | `0xdec30` |
| `didReceiveMemoryWarning` | `0xdec5c` |
| `dealloc` | `0xdec88` |
| `failed` | `0xdecb4` |
| `startOpenAnimation` | `0xded10` |
| `endOpenAnimation` | `0xdee00` |
| `startCloseAnimation` | `0xdee48` |
| `endCloseAnimation` | `0xdef48` |
| `touchesBegan:withEvent:` | `0xdef94` |
| `isAnimationing` | `0xdefd8` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `communicatingView` | `UIImageView *` | `0xa4` |
| `communicateFailedView` | `UIImageView *` | `0xa8` |
| `indicatorView` | `UIActivityIndicatorView *` | `0xac` |
| `_isAnimationing` | `BOOL` | `0xb0` |
| `_isCloseReserve` | `BOOL` | `0xb1` |

### `RandomLoginBonusView` — ❌ missing

Methods **0/11** · ivars 9 · `instanceSize`=`104`

#### Missing methods

| Selector | Address |
| --- | --- |
| `getBonus` | `0x18a38` |
| `initWithCoder:` | `0x18a90` |
| `initWithFrame:` | `0x18aa0` |
| `init` | `0x18ab0` |
| `dealloc` | `0x19884` |
| `show` | `0x19960` |
| `touchEvent:` | `0x19b9c` |
| `startCloseAnimation` | `0x1a448` |
| `endCloseAnimation` | `0x1a508` |
| `showAlertView` | `0x1a558` |
| `customAlertView:clickedButtonAtIndex:` | `0x1a650` |

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

### `StoreDialogView` — ❌ missing

Methods **0/11** · ivars 5 · `instanceSize`=`72`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:` | `0x416dc` |
| `initWithFrame:abortable:` | `0x41708` |
| `dealloc` | `0x41dc0` |
| `layout:` | `0x41e4c` |
| `btnAbort:` | `0x41f38` |
| `delegate` | `0x41f8c` |
| `setDelegate:` | `0x41f9c` |
| `indicatorView` | `0x41fac` |
| `labelMessage` | `0x41fbc` |
| `progressView` | `0x41fcc` |
| `buttonAbort` | `0x41fdc` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_IndicatorView` | `UIActivityIndicatorView *` | `0x34` |
| `m_LabelMessage` | `UILabel *` | `0x38` |
| `m_ProgressView` | `UIProgressView *` | `0x3c` |
| `m_ButtonAbort` | `UIButton *` | `0x40` |
| `delegate` | `id` | `0x44` |

### `AcViewerHiSpeedViewController` — ❌ missing

Methods **0/10** · ivars 0 · `instanceSize`=`162`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x2cbb0` |
| `viewDidLoad` | `0x2d484` |
| `handleGesture:` | `0x2d4b4` |
| `numberOfSectionsInTableView:` | `0x2d520` |
| `tableView:numberOfRowsInSection:` | `0x2d524` |
| `tableView:cellForRowAtIndexPath:` | `0x2d530` |
| `tableView:titleForHeaderInSection:` | `0x2d660` |
| `tableView:accessoryTypeForRowWithIndexPath:` | `0x2d664` |
| `tableView:didSelectRowAtIndexPath:` | `0x2d668` |
| `touchedBackButton:` | `0x2d738` |

### `AcceptPolicyViewController` — ❌ missing

Methods **0/10** · ivars 5 · `instanceSize`=`180`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xaf848` |
| `dealloc` | `0xb02bc` |
| `onYesBtn:` | `0xb032c` |
| `onNoBtn:` | `0xb037c` |
| `onDetailBtn:` | `0xb03ac` |
| `onBackBtn:` | `0xb04e4` |
| `startOpenAnimation` | `0xb0540` |
| `endOpenAnimation` | `0xb0630` |
| `startCloseAnimation` | `0xb0648` |
| `endCloseAnimation` | `0xb0718` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `isAnimationing` | `BOOL` | `0xa2` |
| `_topView` | `UIView *` | `0xa4` |
| `_detailView` | `UIImageView *` | `0xa8` |
| `_policyView` | `UINavigationController *` | `0xac` |
| `_naviCtrl` | `UINavigationController *` | `0xb0` |

### `CJSONScanner` — ❌ missing

Methods **0/10** · ivars 1 · `instanceSize`=`29`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x67760` |
| `dealloc` | `0x677a0` |
| `setData:` | `0x677cc` |
| `scanJSONObject:error:` | `0x678d0` |
| `scanJSONDictionary:error:` | `0x67a74` |
| `scanJSONArray:error:` | `0x67f48` |
| `scanJSONStringConstant:error:` | `0x682c8` |
| `scanJSONNumberConstant:error:` | `0x68690` |
| `scanNotQuoteCharactersIntoString:` | `0x68734` |
| `strictEscapeCodes` | `0x687e0` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `strictEscapeCodes` | `BOOL` | `0x1c` |

### `CheckerMusicViewController` — ❌ missing

Methods **0/10** · ivars 1 · `instanceSize`=`168`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithScoreData:category:` | `0xd27b8` |
| `dealloc` | `0xd2e20` |
| `viewDidLoad` | `0xd2e98` |
| `didReceiveMemoryWarning` | `0xd2ec4` |
| `numberOfSectionsInTableView:` | `0xd2ef0` |
| `tableView:numberOfRowsInSection:` | `0xd2ef4` |
| `tableView:cellForRowAtIndexPath:` | `0xd2f1c` |
| `tableView:titleForHeaderInSection:` | `0xd3028` |
| `tableView:didSelectRowAtIndexPath:` | `0xd3030` |
| `touchedBackButton:` | `0xd3254` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_scoreDataArray` | `NSArray *` | `0xa4` |

### `HttpConn` — ❌ missing

Methods **0/10** · ivars 6 · `instanceSize`=`28`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x6a550` |
| `get:` | `0x6a58c` |
| `post:paramString:` | `0x6a6c4` |
| `connection:didReceiveResponse:` | `0x6a8c0` |
| `connection:didReceiveData:` | `0x6a978` |
| `connection:didFailWithError:` | `0x6a9c8` |
| `connectionDidFinishLoading:` | `0x6aa38` |
| `receivedString` | `0x6ab60` |
| `status` | `0x6ab74` |
| `setStatus:` | `0x6ab88` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `receivedData` | `NSMutableData *` | `0x4` |
| `receivedString` | `NSString *` | `0x8` |
| `encoding` | `unsigned int` | `0xc` |
| `conn` | `NSURLConnection *` | `0x10` |
| `statusCode` | `int` | `0x14` |
| `status` | `int` | `0x18` |

### `RewardNetworkPasteBoard` — ❌ missing

Methods **0/10** · ivars 2 · `instanceSize`=`12`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithServiceName:dataType:` | `0xf5988` |
| `storageData` | `0xf5a60` |
| `storageDataWithStorageIndex:error:` | `0xf5bb8` |
| `writeStorageData:error:` | `0xf604c` |
| `writeStorageData:storageIndex:error:` | `0xf6214` |
| `deleteWithStorageIndex:error:` | `0xf6560` |
| `convertToData:storageIndex:` | `0xf6b90` |
| `getServiceName` | `0xf6d64` |
| `debugLog` | `0xf6e48` |
| `.cxx_destruct` | `0xf6fbc` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_serviceName` | `NSString *` | `0x4` |
| `_dataType` | `NSString *` | `0x8` |

### `AcViewerHidSudViewController` — ❌ missing

Methods **0/9** · ivars 0 · `instanceSize`=`162`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x1adf4` |
| `viewDidLoad` | `0x1b6c8` |
| `numberOfSectionsInTableView:` | `0x1b6f8` |
| `tableView:numberOfRowsInSection:` | `0x1b6fc` |
| `tableView:cellForRowAtIndexPath:` | `0x1b708` |
| `tableView:titleForHeaderInSection:` | `0x1b838` |
| `tableView:accessoryTypeForRowWithIndexPath:` | `0x1b83c` |
| `tableView:didSelectRowAtIndexPath:` | `0x1b840` |
| `touchedBackButton:` | `0x1b910` |

### `AcViewerPopKunViewController` — ❌ missing

Methods **0/9** · ivars 0 · `instanceSize`=`162`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x7d01c` |
| `viewDidLoad` | `0x7d8f0` |
| `numberOfSectionsInTableView:` | `0x7d920` |
| `tableView:numberOfRowsInSection:` | `0x7d924` |
| `tableView:cellForRowAtIndexPath:` | `0x7d930` |
| `tableView:titleForHeaderInSection:` | `0x7da60` |
| `tableView:accessoryTypeForRowWithIndexPath:` | `0x7da64` |
| `tableView:didSelectRowAtIndexPath:` | `0x7da68` |
| `touchedBackButton:` | `0x7db38` |

### `AcViewerRanMirViewController` — ❌ missing

Methods **0/9** · ivars 0 · `instanceSize`=`162`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xa6c20` |
| `viewDidLoad` | `0xa74f4` |
| `numberOfSectionsInTableView:` | `0xa7520` |
| `tableView:numberOfRowsInSection:` | `0xa7524` |
| `tableView:cellForRowAtIndexPath:` | `0xa7530` |
| `tableView:titleForHeaderInSection:` | `0xa7660` |
| `tableView:accessoryTypeForRowWithIndexPath:` | `0xa7664` |
| `tableView:didSelectRowAtIndexPath:` | `0xa7668` |
| `touchedBackButton:` | `0xa7738` |

### `CustomSplitViewController` — ❌ missing

Methods **0/9** · ivars 3 · `instanceSize`=`176`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:leftViewWidth:leftViewController:rightView:` | `0x5dbc0` |
| `initWithLeftViewWidth:leftViewController:rightView:` | `0x5dde0` |
| `dealloc` | `0x5de28` |
| `viewDidLoad` | `0x5dea0` |
| `didReceiveMemoryWarning` | `0x5decc` |
| `leftViewCtrl` | `0x5def8` |
| `setLeftViewCtrl:` | `0x5df0c` |
| `rightViewCtrl` | `0x5df24` |
| `setRightViewCtrl:` | `0x5df38` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_leftViewCtrl` | `UIViewController *` | `0xa4` |
| `m_rightViewCtrl` | `UIViewController *` | `0xa8` |
| `m_leftViewWidth` | `int` | `0xac` |

### `DevDataDownloader` — ❌ missing

Methods **0/9** · ivars 6 · `instanceSize`=`25`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x8e8ec` |
| `startDownload:file:` | `0x8e984` |
| `downloaderFinished:` | `0x8eb1c` |
| `downloaderProceed:` | `0x8ed78` |
| `downloaderError:` | `0x8ed7c` |
| `delegate` | `0x8ee00` |
| `setDelegate:` | `0x8ee10` |
| `isOld` | `0x8ee20` |
| `setIsOld:` | `0x8ee38` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Downloader` | `Downloader *` | `0x4` |
| `m_Title` | `NSString *` | `0x8` |
| `m_FileName` | `NSString *` | `0xc` |
| `m_IsOld` | `BOOL` | `0x10` |
| `m_Delegate` | `<DevDataDownloaderDelegate> *` | `0x14` |
| `isAcv` | `BOOL` | `0x18` |

### `LoginBonusView` — ❌ missing

Methods **0/9** · ivars 3 · `instanceSize`=`61`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithCoder:` | `0x7bfc8` |
| `initWithFrame:` | `0x7bfd8` |
| `init` | `0x7bfe8` |
| `dealloc` | `0x7c540` |
| `getReward` | `0x7c594` |
| `show` | `0x7c728` |
| `touchEvent:` | `0x7c8e0` |
| `showAlertView` | `0x7cc68` |
| `customAlertView:clickedButtonAtIndex:` | `0x7ce50` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_BgImgView` | `UIImageView *` | `0x34` |
| `m_OldLoginCnt` | `int` | `0x38` |
| `m_IsTouch` | `BOOL` | `0x3c` |

### `RecommendAdId` — ❌ missing

Methods **0/9** · ivars 1 · `instanceSize`=`8`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithCountryCode:categoryId:` | `0xe997c` |
| `getWithCountryCode:categoryId:error:` | `0xe9a34` |
| `setWithAdIdFrom:countryCode:categoryId:adType:error:` | `0xe9eb8` |
| `deleteWithCountryCode:categoryId:error:` | `0xea49c` |
| `convertToData:` | `0xea914` |
| `getPasteboardWithUdid:countryCode:categoryId:error:` | `0xead3c` |
| `setPasteboardWithUdid:countryCode:categoryId:adIdFrom:adType:error:` | `0xeb23c` |
| `deletePasteboardWithUdid:countryCode:categoryId:error:` | `0xeb678` |
| `.cxx_destruct` | `0xeba60` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_serviceName` | `NSString *` | `0x4` |

### `RewardNetworkWebAPI` — ❌ missing

Methods **0/9** · ivars 1 · `instanceSize`=`8`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xfa744` |
| `commonParameters` | `0xfa790` |
| `requestWithURL:method:parameters:cachePolicy:` | `0xfa7e8` |
| `requestForGetWithURL:parameters:` | `0xfa948` |
| `requestForPostWithURL:parameters:` | `0xfa9f0` |
| `requestAsynchronousWithURL:method:parameters:userInfo:tag:cachePolicy:finishedBlock:failedBlock:` | `0xfad84` |
| `responseFromContentsServer:request:data:finishedBlock:failedBlock:` | `0xfb58c` |
| `requestSynchronousWithURL:method:parameters:cachePolicy:error:` | `0xfbb34` |
| `canUseNetworkRetry` | `0xfc048` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `retryCount` | `int` | `0x4` |

### `InviteTopViewController` — ❌ missing

Methods **0/8** · ivars 1 · `instanceSize`=`163`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initAtNavigationController` | `0xe6f88` |
| `touchedInviteButton:` | `0xe7860` |
| `touchedInputButton:` | `0xe7914` |
| `touchedBackButton` | `0xe79c8` |
| `startOpenAnimation` | `0xe7a38` |
| `endOpenAnimation` | `0xe7b70` |
| `startCloseAnimation` | `0xe7b88` |
| `endCloseAnimation` | `0xe7c90` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `isAnimationing` | `BOOL` | `0xa2` |

### `MapAnnotation` — ❌ missing

Methods **0/8** · ivars 4 · `instanceSize`=`32`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithCoordinate:Title:SubTitle:Model:` | `0x850e4` |
| `dealloc` | `0x851c8` |
| `setCoordinate:` | `0x85264` |
| `modelName` | `0x85288` |
| `.cxx_construct` | `0x852d8` |
| `coordinate` | `0x85298` |
| `title` | `0x852b0` |
| `subtitle` | `0x852c4` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Coordinate` | `struct ?` | `0x4` |
| `m_Title` | `NSString *` | `0x14` |
| `m_SubTitle` | `NSString *` | `0x18` |
| `m_ModelName` | `NSString *` | `0x1c` |

### `CheckerDetail` — ❌ missing

Methods **0/7** · ivars 15 · `instanceSize`=`368`

#### Missing methods

| Selector | Address |
| --- | --- |
| `convertGrayScaleImage:` | `0xd7418` |
| `initWithScoreData:` | `0xd752c` |
| `deallc` | `0xd9620` |
| `viewDidLoad` | `0xd964c` |
| `touchedBackButton:` | `0xd9678` |
| `touchedSheetButton:` | `0xd97c4` |
| `touchesBegan:withEvent:` | `0xd9aac` |

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

### `DownloadImageView` — ❌ missing

Methods **0/7** · ivars 3 · `instanceSize`=`68`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithURLString:` | `0x62be8` |
| `initWithURLString:withImage:` | `0x62c5c` |
| `dealloc` | `0x62cd0` |
| `SetupView` | `0x62d30` |
| `startDownload` | `0x62e24` |
| `imageDownloader:didLoad:` | `0x62ef0` |
| `imageDownloaderDidFail:didLoad:` | `0x62f60` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_ImageURL` | `NSString *` | `0x38` |
| `m_ImageDownLoader` | `ImageDownloader *` | `0x3c` |
| `m_IndicatorView` | `UIActivityIndicatorView *` | `0x40` |

### `DownloadProgresView` — ❌ missing

Methods **0/7** · ivars 4 · `instanceSize`=`80`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:` | `0xde1d0` |
| `dealloc` | `0xde630` |
| `layout:` | `0xde65c` |
| `.cxx_construct` | `0xde738` |
| `indicatorView` | `0xde708` |
| `labelMessage` | `0xde718` |
| `progressView` | `0xde728` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_indicatorView` | `UIActivityIndicatorView *` | `0x34` |
| `_labelMessage` | `UILabel *` | `0x38` |
| `_progressView` | `UIProgressView *` | `0x3c` |
| `_dialogFrame` | `struct CGRect` | `0x40` |

### `RewardNetworkIndicator` — ❌ missing

Methods **0/7** · ivars 1 · `instanceSize`=`52`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:` | `0xf3c0c` |
| `layoutSubviews` | `0xf3d58` |
| `show` | `0xf3e14` |
| `close` | `0xf3e64` |
| `.cxx_destruct` | `0xf3eec` |
| `indicator` | `0xf3eb4` |
| `setIndicator:` | `0xf3ec4` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_indicator` | `UIActivityIndicatorView *` | `0x30` |

### `TouchRangeView` — ❌ missing

Methods **0/7** · ivars 3 · `instanceSize`=`61`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFilename:touched:` | `0x8b20c` |
| `dealloc` | `0x8b2c0` |
| `drawRect:` | `0x8b324` |
| `getImageWidth` | `0x8b364` |
| `getImageHeight` | `0x8b3a4` |
| `isTouched` | `0x8b3e4` |
| `setIsTouched:` | `0x8b3fc` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_untouchedPopkun` | `UIImage *` | `0x34` |
| `_touchedPopkun` | `UIImage *` | `0x38` |
| `_isTouched` | `BOOL` | `0x3c` |

### `CJSONDataSerializer` — ❌ missing

Methods **0/6** · ivars 0 · `instanceSize`=`4`

#### Missing methods

| Selector | Address |
| --- | --- |
| `serializeObject:` | `0x66e00` |
| `serializeNull:` | `0x6704c` |
| `serializeNumber:` | `0x6705c` |
| `serializeString:` | `0x670cc` |
| `serializeArray:` | `0x672cc` |
| `serializeDictionary:` | `0x673d0` |

### `RecommendWebViewController` — ❌ missing

Methods **0/6** · ivars 0 · `instanceSize`=`153`

#### Missing methods

| Selector | Address |
| --- | --- |
| `viewDidLoad` | `0xe97ac` |
| `didReceiveMemoryWarning` | `0xe97d8` |
| `viewDidUnload` | `0xe9804` |
| `removeFromSuperview` | `0xe9878` |
| `appliListClosed` | `0xe988c` |
| `webView:shouldStartLoadWithRequest:navigationType:` | `0xe98ec` |

### `CJSONSerializer` — ❌ missing

Methods **0/5** · ivars 1 · `instanceSize`=`8`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x6a2d8` |
| `dealloc` | `0x6a33c` |
| `serializeObject:` | `0x6a38c` |
| `serializeArray:` | `0x6a3f4` |
| `serializeDictionary:` | `0x6a45c` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `serializer` | `CJSONDataSerializer *` | `0x4` |

### `RewardNetworkUdid` — ❌ missing

Methods **0/5** · ivars 1 · `instanceSize`=`8`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xf70c0` |
| `bundleSeedID` | `0xf956c` |
| `.cxx_destruct` | `0xf9860` |
| `pasteBoard` | `0xf9828` |
| `setPasteBoard:` | `0xf9838` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_pasteBoard` | `RewardNetworkPasteBoard *` | `0x4` |

### `MyInviteCodeViewController` — ❌ missing

Methods **0/4** · ivars 0 · `instanceSize`=`162`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xe8c98` |
| `viewDidLoad` | `0xe9194` |
| `didReceiveMemoryWarning` | `0xe91c0` |
| `touchedBackButton` | `0xe91ec` |

### `PurchaseStore` — ❌ missing

Methods **0/4** · ivars 1 · `instanceSize`=`5`

#### Missing methods

| Selector | Address |
| --- | --- |
| `purchaseSucceeded:` | `0x838d4` |
| `purchaseFailed:error:` | `0x83928` |
| `nowPurchasing` | `0x8393c` |
| `setNowPurchasing:` | `0x83954` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `nowPurchasing` | `bool` | `0x4` |

### `AcViewerCategoryCell` — ❌ missing

Methods **0/3** · ivars 0 · `instanceSize`=`52`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:reuseIdentifier:` | `0x1a804` |
| `dealloc` | `0x1a84c` |
| `setData:` | `0x1a878` |

### `CJSONDeserializer` — ❌ missing

Methods **0/3** · ivars 0 · `instanceSize`=`4`

#### Missing methods

| Selector | Address |
| --- | --- |
| `deserialize:error:` | `0x67588` |
| `deserializeAsDictionary:error:` | `0x67628` |
| `deserializeAsArray:error:` | `0x676c4` |

### `CSerializedJSONData` — ❌ missing

Methods **0/3** · ivars 1 · `instanceSize`=`8`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithData:` | `0x6a4c4` |
| `dealloc` | `0x6a4f0` |
| `data` | `0x6a540` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `data` | `NSData *` | `0x4` |

### `CheckerMusicCell` — ❌ missing

Methods **0/3** · ivars 10 · `instanceSize`=`92`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:reuseIdentifier:` | `0xd1d28` |
| `dealloc` | `0xd1ea0` |
| `setData:` | `0xd1ecc` |

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

### `FreeRequestListCell` — ❌ missing

Methods **0/3** · ivars 11 · `instanceSize`=`96`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:reuseIdentifier:` | `0xe49c4` |
| `dealloc` | `0xe4b34` |
| `setFriendData:rank:` | `0xe4b60` |

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

### `QuizCell` — ❌ missing

Methods **0/3** · ivars 2 · `instanceSize`=`60`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithStyle:reuseIdentifier:` | `0xd9bac` |
| `dealloc` | `0xd9bf4` |
| `setData:answerId:rightId:selectId:` | `0xd9c20` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_answerId` | `int` | `0x34` |
| `_answerIdView` | `UIImageView *` | `0x38` |

### `RecommendNetwork` — ❌ missing

Methods **0/3** · ivars 1 · `instanceSize`=`8`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xeba74` |
| `initializeFlg` | `0xec4b4` |
| `setInitializeFlg:` | `0xec4c4` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_initializeFlg` | `int` | `0x4` |

### `TouchableTableView` — ❌ missing

Methods **0/3** · ivars 0 · `instanceSize`=`56`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:` | `0xe96ec` |
| `dealloc` | `0xe9724` |
| `touchesBegan:withEvent:` | `0xe9750` |

### `TouchableScrollView` — ❌ missing

Methods **0/2** · ivars 0 · `instanceSize`=`56`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:` | `0xe30dc` |
| `touchesBegan:withEvent:` | `0xe3114` |

### `neWindow` — ❌ missing

Methods **0/1** · ivars 0 · `instanceSize`=`144`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:` | `0x28a00` |

### `RecommendWebAPI` — ❌ missing

Methods **0/0** · ivars 0 · `instanceSize`=`4`

### `RewardNetworkError` — ❌ missing

Methods **0/0** · ivars 0 · `instanceSize`=`4`

### `RewardNetworkMessage` — ❌ missing

Methods **0/0** · ivars 0 · `instanceSize`=`4`

### `RewardNetworkUtilities` — ❌ missing

Methods **0/0** · ivars 0 · `instanceSize`=`4`

### `ViewUtility` — ❌ missing

Methods **0/0** · ivars 0 · `instanceSize`=`4`

### `DownloadMain` — 🟡 partial

Methods **25/119** · ivars 63 · `instanceSize`=`252`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x93ec0` |
| `startPlayerGetHttp` | `0x93f14` |
| `isPlayerGetDownLoading` | `0x94060` |
| `getPlayerGetProgressSec` | `0x94078` |
| `playerGetFinished` | `0x940c4` |
| `startNewsHttp` | `0x94488` |
| `isNewsDownLoading` | `0x9458c` |
| `releaseInformationData` | `0x945a4` |
| `newsGetFinished` | `0x946b8` |
| `startSaveScoreHttp:sheet:score:medal:charaId:` | `0x952d4` |
| `saveScoreFinished` | `0x95434` |
| `isGetBlockListDownLoading` | `0x96710` |
| `isDelBlockListDownLoading` | `0x96ae4` |
| `delBlockListFinished` | `0x96afc` |
| `startGetRecommendListHttp` | `0x96b54` |
| `isGetRecommendListDownLoading` | `0x96c68` |
| `releaseRecommendData` | `0x96c80` |
| `compareToUpdateDate:` | `0x96db0` |
| `getRecommendListFinished` | `0x96df0` |
| `startGetVisitorHttp:type:` | `0x972e4` |
| `isGetVisitorDownLoading` | `0x97410` |
| `getVisitorFinished` | `0x97428` |
| `isSaveTreasureDownLoading` | `0x97894` |
| `releaseFileListData` | `0x979f0` |
| `startGetPresentListHttp` | `0x97d60` |
| `isGetPresentListDownLoading` | `0x97e74` |
| `releasePresentList` | `0x97e8c` |
| `getPresentListFinished` | `0x97f90` |
| `startGetPresentHttp:` | `0x9829c` |
| `isGetPresentDownLoading` | `0x983c0` |
| `getPresentFinished` | `0x983d8` |
| `startGetOverScoreLogHttp` | `0x984b4` |
| `isGetOverScoreLogDownLoading` | `0x985c8` |
| `releaseOverScoreLogArray` | `0x985e0` |
| `getOverScoreLogFinished` | `0x98700` |
| `startGetEventInfoHttp` | `0x98a6c` |
| `isGetEventInfoDownLoading` | `0x98b7c` |
| `getEventInfoFinished` | `0x98b94` |
| `downloaderFinished:` | `0x98f78` |
| `downloaderProceed:` | `0x9918c` |
| `downloaderError:` | `0x99190` |
| `cppDelegateNews` | `0x995ac` |
| `setCppDelegateNews:` | `0x995c0` |
| `cppDelegateRecommendList` | `0x995d8` |
| `setCppDelegateRecommendList:` | `0x995ec` |
| `setDelegateGetFriendList:` | `0x99618` |
| `setDelegateCancelFriend:` | `0x99644` |
| `delegateGetVisitor` | `0x9965c` |
| `setDelegateGetVisitor:` | `0x99670` |
| `delegateGetPresentList` | `0x99688` |
| `setDelegateGetPresentList:` | `0x9969c` |
| `delegateGetPresent` | `0x996b4` |
| `setDelegateGetPresent:` | `0x996c8` |
| `delegateGetEventInfo` | `0x996e0` |
| `setDelegateGetEventInfo:` | `0x996f4` |
| `informationDataArray` | `0x9970c` |
| `arcadePt` | `0x99720` |
| `errorGetPlayer` | `0x99760` |
| `loginBonusId` | `0x99774` |
| `loginCnt` | `0x99788` |
| `isLoginCntUpdate` | `0x9979c` |
| `setIsLoginCntUpdate:` | `0x997b4` |
| `newsTextArray` | `0x997cc` |
| `newsUrlArray` | `0x997e0` |
| `lastGetNewsTime` | `0x997f4` |
| `serverYear` | `0x99808` |
| `serverMonth` | `0x9981c` |
| `serverDay` | `0x99830` |
| `serverHour` | `0x99844` |
| `serverMinute` | `0x99858` |
| `serverSecond` | `0x9986c` |
| `isNewMusicPackReleased` | `0x99880` |
| `setIsNewMusicPackReleased:` | `0x99898` |
| `frSendPlayerIdArray` | `0x998b0` |
| `frSendNameArray` | `0x998c4` |
| `frReceivePlayerIdArray` | `0x998d8` |
| `frReceiveNameArray` | `0x998ec` |
| `frReceiveMessageArray` | `0x99900` |
| `presentDataArray` | `0x99928` |
| `getPresentId` | `0x9993c` |
| `setGetPresentId:` | `0x99950` |
| `overScoreLogArray` | `0x99968` |
| `blNameArray` | `0x99990` |
| `isGetVisitorSuccess` | `0x999a4` |
| `setIsGetVisitorSuccess:` | `0x999bc` |
| `recommendDataArray` | `0x999d4` |
| `treasureEventIdArray` | `0x999fc` |
| `gameEventIdArray` | `0x99a10` |
| `isTreasureEventInfoUpdated` | `0x99a24` |
| `setIsTreasureEventInfoUpdated:` | `0x99a3c` |
| `isGameEventInfoUpdated` | `0x99a54` |
| `setIsGameEventInfoUpdated:` | `0x99a6c` |
| `delegateGetOverScoreLog` | `0x99a84` |
| `setDelegateGetOverScoreLog:` | `0x99a98` |

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

### `StoreMainViewController` — 🟡 partial

Methods **10/64** · ivars 25 · `instanceSize`=`252`

#### Missing methods

| Selector | Address |
| --- | --- |
| `showError:` | `0x44864` |
| `pushBarBtnRestore:` | `0x44904` |
| `packListDownloadError:errorMessage:` | `0x45108` |
| `packListDownloadNothing:` | `0x45258` |
| `openDetailAnimStop:finished:context:` | `0x45510` |
| `storePromotionViewTaped:PackID:` | `0x45648` |
| `openDetailAnimStopFromPromotion:finished:context:` | `0x45898` |
| `closeDetailAnimStop:finished:context:` | `0x45a80` |
| `startDownloadPackMusics:` | `0x45b48` |
| `detailViewStartPurchase:` | `0x46270` |
| `detailViewClose` | `0x46420` |
| `storeDialogCancel:` | `0x46470` |
| `connectionDidFinishLoading:` | `0x46584` |
| `connection:didFailWithError:` | `0x46588` |
| `updateMusicInfo:Save:` | `0x4658c` |
| `updatePurchasedTableCell:` | `0x46798` |
| `reDownloadPackMusics:` | `0x46a7c` |
| `purchaseSucceeded:` | `0x46ab0` |
| `purchaseFailed:error:` | `0x46d1c` |
| `addRestorePackInfo:` | `0x46e58` |
| `nextRestorePackInfo` | `0x46ef4` |
| `askDownloadAllMusics` | `0x47134` |
| `restoreDownloadAllMusics` | `0x4753c` |
| `commonAlertView:clickedButtonAtIndex:` | `0x47a04` |
| `restoreSucceeded` | `0x47c14` |
| `restoreFailed:` | `0x47d50` |
| `restoreNothing` | `0x47e40` |
| `storePackInfoDownloaderFinished:` | `0x47e60` |
| `storePackInfoDownloaderError:` | `0x47ef4` |
| `downloadManagerStartTask:` | `0x47f38` |
| `downloadManagerCompleted:` | `0x47ffc` |
| `downloadManagerFailed:` | `0x48108` |
| `downloadManagerProceed:` | `0x482c0` |
| `numPackRows` | `0x4832c` |
| `tableView:cellForRowAtIndexPath:` | `0x4837c` |
| `numberOfSectionsInTableView:` | `0x48fc0` |
| `tableView:numberOfRowsInSection:` | `0x48fd8` |
| `tableView:heightForRowAtIndexPath:` | `0x49038` |
| `tableView:willDisplayCell:forRowAtIndexPath:` | `0x4912c` |
| `tableView:didSelectRowAtIndexPath:` | `0x49258` |
| `imageDownloader:didLoad:` | `0x495e4` |
| `imageDownloaderDidFail:didLoad:` | `0x49750` |
| `scrollViewDidScroll:` | `0x49754` |
| `scrollViewWillBeginDragging:` | `0x49b64` |
| `scrollViewDidEndDragging:willDecelerate:` | `0x49b68` |
| `stopDownloadArtworks` | `0x49b6c` |
| `viewWillAppear:` | `0x49c84` |
| `viewDidAppear:` | `0x49d64` |
| `viewWillDisappear:` | `0x49e88` |
| `viewDidDisappear:` | `0x49fe4` |
| `shouldAutorotateToInterfaceOrientation:` | `0x4a010` |
| `willRotateToInterfaceOrientation:duration:` | `0x4a014` |
| `didReceiveMemoryWarning` | `0x4a018` |
| `dealloc` | `0x4a044` |

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

### `MainViewController` — 🟡 partial

Methods **48/96** · ivars 51 · `instanceSize`=`356`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xb440` |
| `didReceiveMemoryWarning` | `0xb4c4` |
| `viewDidUnload` | `0xb4f0` |
| `loadView` | `0xb51c` |
| `viewDidLoad` | `0xb970` |
| `viewWillAppear:` | `0xb9b0` |
| `viewDidAppear:` | `0xb9dc` |
| `viewWillDisappear:` | `0xba08` |
| `viewDidDisappear:` | `0xba34` |
| `shouldAutorotateToInterfaceOrientation:` | `0xba60` |
| `LayoutedGLView:` | `0xba6c` |
| `screenshot` | `0xbb98` |
| `StopLoop` | `0xbed0` |
| `GetGlView` | `0xc150` |
| `IsFriendManageEnable` | `0xcf70` |
| `IsPopnLinkEnable` | `0xd21c` |
| `IsStoreEnable` | `0xd548` |
| `InsertCommunicating` | `0xd6a8` |
| `IsCommunicatingAnimationing` | `0xd764` |
| `IsCommunicatingEnable` | `0xd790` |
| `CommunicatingFailed` | `0xd7a8` |
| `CommunicatingEndCallBack` | `0xd7c8` |
| `IsInviteCodeEnable` | `0xd918` |
| `IsArcadeSearchEnable` | `0xda28` |
| `IsPresentBoxEnable` | `0xe158` |
| `SaveToCameraRoll:` | `0xe704` |
| `onCompleteCapture:didFinishSavingWithError:contextInfo:` | `0xe7c0` |
| `SetAlertViewCallback:param:` | `0xe810` |
| `commonAlertView:clickedButtonAtIndex:` | `0xe914` |
| `customAlertView:clickedButtonAtIndex:` | `0xeac8` |
| `appListDidAppear` | `0xeaec` |
| `appListDidDisappear` | `0xeaf0` |
| `appListFailLoadWithError:` | `0xeb1c` |
| `handleTapCoverView:` | `0xeba8` |
| `InsertBlackBoard` | `0xeca4` |
| `FadeInBlackBoard` | `0xede8` |
| `FadeOutBlackBoard` | `0xefdc` |
| `.cxx_construct` | `0xf1e8` |
| `settingViewing` | `0xf0d0` |
| `cameraRollSaving` | `0xf0e8` |
| `isDefaultDlFailed` | `0xf100` |
| `rewardListViweing` | `0xf118` |
| `setRewardListViweing:` | `0xf130` |
| `isGotoTitle` | `0xf178` |
| `setIsGotoTitle:` | `0xf190` |
| `acMusicSelViewing` | `0xf1a8` |
| `setAcMusicSelViewing:` | `0xf1c0` |
| `cameraRollError` | `0xf1d8` |

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

### `AudioManager` — 🟡 partial

Methods **41/69** · ivars 23 · `instanceSize`=`380`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x1df8c` |
| `cleanupSe` | `0x1e238` |
| `loadBgmDataWithBytes:length:isLoop:` | `0x1e63c` |
| `loadBgmDataWithBytesNoCopy:length:isLoop:` | `0x1e67c` |
| `loadBgmDataWithBytesNoCopy:length:freeWhenDone:isLoop:` | `0x1e6bc` |
| `loadVoiceData:isLoop:` | `0x1e7f0` |
| `releaseSe:resourceId:` | `0x1eba8` |
| `releaseSeAll` | `0x1eda8` |
| `releaseVoice` | `0x1efdc` |
| `prepareSetGroup:resourceId:groupId:` | `0x1f164` |
| `playSeSetGroup:resourceId:groupId:` | `0x1f380` |
| `onPauseSe:` | `0x1f434` |
| `offPauseSe:` | `0x1f498` |
| `isPlayingSe:` | `0x1f4fc` |
| `onPauseSeAll` | `0x1f568` |
| `offPauseSeAll` | `0x1f5cc` |
| `stopAll` | `0x1f694` |
| `orderInstanceList:` | `0x1f7ec` |
| `setJustBgmVolume:` | `0x1fc6c` |
| `bgmDeviceCurrentTime` | `0x1ff84` |
| `onFadeInTimer:` | `0x2002c` |
| `onFadeOutTimer:` | `0x200ec` |
| `isPlayingVoice` | `0x2042c` |
| `audioPlayerDidFinishPlaying:successfully:` | `0x20460` |
| `audioPlayerBeginInterruption:` | `0x204ac` |
| `audioPlayerEndInterruption:` | `0x204d4` |
| `dealloc` | `0x206d8` |
| `.cxx_construct` | `0x207a0` |

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

### `MusicData` — 🟡 partial

Methods **9/34** · ivars 16 · `instanceSize`=`68`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xc779c` |
| `artwork2xData` | `0xc7964` |
| `musicNameImage2xData` | `0xc7980` |
| `artistNameImage2xData` | `0xc799c` |
| `compare:` | `0xc79b8` |
| `compareMusicID:` | `0xc7a28` |
| `compareMusicNameCustom:` | `0xc7a60` |
| `compareArtistNameCustom:` | `0xc7ad4` |
| `compareMusicNameHira:` | `0xc7b3c` |
| `compareArtistNameHira:` | `0xc7bb0` |
| `compareDifficultyNormal:` | `0xc7c18` |
| `compareDifficultyHyper:` | `0xc7c50` |
| `compareDifficultyEx:` | `0xc7c88` |
| `lvNormal` | `0xc7cd4` |
| `lvHyper` | `0xc7ce8` |
| `bpm_MIN` | `0xc7d10` |
| `bpm_MAX` | `0xc7d24` |
| `musicName` | `0xc7d38` |
| `musicNameHira` | `0xc7d4c` |
| `artistName` | `0xc7d60` |
| `artistNameHira` | `0xc7d74` |
| `musicSortName` | `0xc7d88` |
| `artistSortName` | `0xc7d9c` |
| `musicNameInitial` | `0xc7db0` |
| `artistNameInitial` | `0xc7dc4` |

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

### `AcMusicData` — 🟡 partial

Methods **7/31** · ivars 17 · `instanceSize`=`72`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x6629c` |
| `getBackTrack:` | `0x66394` |
| `compare:` | `0x66488` |
| `compareAcMusicId:` | `0x664f8` |
| `compareMusicNameCustom:` | `0x66530` |
| `compareGenreNameCustom:` | `0x665a4` |
| `compareLvEasy:` | `0x6660c` |
| `compareLvNormal:` | `0x66644` |
| `compareLvHyper:` | `0x6667c` |
| `compareLvEx:` | `0x666b4` |
| `lvEasy` | `0x66700` |
| `lvNormal` | `0x66714` |
| `lvHyper` | `0x66728` |
| `bpmEasy` | `0x66750` |
| `bpmNormal` | `0x66764` |
| `bpmHyper` | `0x66778` |
| `bpmEx` | `0x6678c` |
| `category` | `0x667a0` |
| `musicName` | `0x667b4` |
| `musicNameKana` | `0x667c8` |
| `genreName` | `0x667dc` |
| `genreNameKana` | `0x667f0` |
| `musicNameInitial` | `0x66804` |
| `genreNameInitial` | `0x66818` |

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

### `MusicManager` — 🟡 partial

Methods **14/37** · ivars 13 · `instanceSize`=`56`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0xc81dc` |
| `dealloc` | `0xc827c` |
| `createDefaultMusics` | `0xc8384` |
| `createOpenTreasureMusics` | `0xc8440` |
| `createOpenInviteMusics` | `0xc8554` |
| `createOpenCollaboMusics` | `0xc8604` |
| `createOpenLoginBonusMusics` | `0xc86b4` |
| `createAcDefaultMusics` | `0xc8764` |
| `savePurchasedMusics` | `0xc8bec` |
| `getPurchasedMusicDictionaris` | `0xc8f28` |
| `getPurchasedAcMusicDictionaris` | `0xc8f38` |
| `addPurchasedMusic:` | `0xc8f48` |
| `addPurchasedAcMusic:` | `0xc93f0` |
| `deleteMusic:` | `0xc9898` |
| `deleteAcMusic:` | `0xc9914` |
| `isRecommendedPack:` | `0xc9990` |
| `openTreasureMusic` | `0xcafc0` |
| `openInviteMusic` | `0xcaff0` |
| `openCollaboMusic` | `0xcb020` |
| `openLoginBonusMusic` | `0xcb050` |
| `getMusicIDs` | `0xcb24c` |
| `getAcMusicIDs` | `0xcb474` |
| `getMusicPatchArray` | `0xcb948` |

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

### `StoreAcvManageViewController` — 🟡 partial

Methods **1/24** · ivars 10 · `instanceSize`=`204`

#### Missing methods

| Selector | Address |
| --- | --- |
| `loadView` | `0x8c7f0` |
| `tableView:cellForRowAtIndexPath:` | `0x8cf28` |
| `tableView:numberOfRowsInSection:` | `0x8d8b4` |
| `tableView:willDisplayCell:forRowAtIndexPath:` | `0x8d8f8` |
| `numberOfSectionsInTableView:` | `0x8da44` |
| `pushCellButton:` | `0x8da48` |
| `startDownloadMusic` | `0x8de20` |
| `startCheck` | `0x8df94` |
| `downloaderFinished:` | `0x8e03c` |
| `downloaderError:` | `0x8e1a4` |
| `storeDialogCancel:` | `0x8e250` |
| `commonAlertView:clickedButtonAtIndex:` | `0x8e2f8` |
| `downloadManagerCompleted:` | `0x8e3e4` |
| `downloadManagerFailed:` | `0x8e45c` |
| `downloadManagerProceed:` | `0x8e574` |
| `shouldAutorotateToInterfaceOrientation:` | `0x8e5e0` |
| `didReceiveMemoryWarning` | `0x8e5e4` |
| `viewDidUnload` | `0x8e610` |
| `viewWillAppear:` | `0x8e664` |
| `viewDidAppear:` | `0x8e690` |
| `viewWillDisappear:` | `0x8e6f0` |
| `viewDidDisappear:` | `0x8e71c` |
| `dealloc` | `0x8e748` |

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

### `StoreManageViewController` — 🟡 partial

Methods **1/23** · ivars 9 · `instanceSize`=`197`

#### Missing methods

| Selector | Address |
| --- | --- |
| `loadView` | `0x4be00` |
| `tableView:cellForRowAtIndexPath:` | `0x4c308` |
| `tableView:numberOfRowsInSection:` | `0x4cc94` |
| `tableView:willDisplayCell:forRowAtIndexPath:` | `0x4ccd8` |
| `numberOfSectionsInTableView:` | `0x4ce24` |
| `pushCellButton:` | `0x4ce28` |
| `startDownloadMusic` | `0x4d1ec` |
| `downloaderFinished:` | `0x4d360` |
| `downloaderError:` | `0x4d460` |
| `storeDialogCancel:` | `0x4d4b8` |
| `commonAlertView:clickedButtonAtIndex:` | `0x4d560` |
| `downloadManagerCompleted:` | `0x4d64c` |
| `downloadManagerFailed:` | `0x4d6c4` |
| `downloadManagerProceed:` | `0x4d7dc` |
| `shouldAutorotateToInterfaceOrientation:` | `0x4d848` |
| `didReceiveMemoryWarning` | `0x4d84c` |
| `viewDidUnload` | `0x4d878` |
| `viewWillAppear:` | `0x4d8cc` |
| `viewDidAppear:` | `0x4d8f8` |
| `viewWillDisappear:` | `0x4d958` |
| `viewDidDisappear:` | `0x4d984` |
| `dealloc` | `0x4d9b0` |

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

### `AppDelegate` — 🟡 partial

Methods **24/43** · ivars 17 · `instanceSize`=`72`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x8c74` |
| `deleteUuid` | `0x9c20` |
| `setUsersettingVer:` | `0x9d58` |
| `getUsersettingVer` | `0xa044` |
| `deleteUsersettingVer` | `0xa270` |
| `userAgent` | `0xa3a8` |
| `appVersionNum` | `0xa458` |
| `finishRequest:` | `0xab44` |
| `purchaseSucceeded:` | `0xab9c` |
| `purchaseFailed:error:` | `0xac24` |
| `getProduct:` | `0xacac` |
| `loginGameCenter` | `0xb00c` |
| `displayType` | `0xb0a8` |
| `products` | `0xb0bc` |
| `mainTask` | `0xb0d0` |
| `setMainTask:` | `0xb0e4` |
| `acMainTask` | `0xb0fc` |
| `setAcMainTask:` | `0xb110` |
| `rewardAppId` | `0xb128` |

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

### `StorePackDetailViewPad` — 🟡 partial

Methods **15/32** · ivars 20 · `instanceSize`=`144`

#### Missing methods

| Selector | Address |
| --- | --- |
| `selfCheckButtonText` | `0x4ef54` |
| `setButtonTextBuy` | `0x4f024` |
| `setButtonTextInstall` | `0x4f0b8` |
| `setButtonTextInstalling` | `0x4f144` |
| `setButtonTextInstalled` | `0x4f1d0` |
| `showPackInfo` | `0x4f318` |
| `loadInfo` | `0x4f680` |
| `finishBgm:` | `0x50100` |
| `downloaderError:` | `0x505d8` |
| `downloaderProceed:` | `0x507a4` |
| `storePackInfoDownloaderFinished:` | `0x507a8` |
| `storePackInfoDownloaderError:` | `0x50840` |
| `commonAlertView:clickedButtonAtIndex:` | `0x5093c` |
| `dealloc` | `0x50990` |
| `packInfo` | `0x50b48` |
| `delegate` | `0x50b68` |
| `setDelegate:` | `0x50b78` |

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

### `SettingTableViewController` — 🟡 partial

Methods **4/20** · ivars 7 · `instanceSize`=`186`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initAtNavigationController` | `0x7ed98` |
| `dealloc` | `0x7ef98` |
| `endCloseAnimation` | `0x7f250` |
| `viewDidAppear:` | `0x7f2f0` |
| `viewDidLoad` | `0x7f31c` |
| `didReceiveMemoryWarning` | `0x7f348` |
| `numberOfSectionsInTableView:` | `0x7f374` |
| `tableView:numberOfRowsInSection:` | `0x7f378` |
| `tableView:cellForRowAtIndexPath:` | `0x7f390` |
| `tableView:titleForHeaderInSection:` | `0x7f708` |
| `tableView:accessoryTypeForRowWithIndexPath:` | `0x7f764` |
| `tableView:didSelectRowAtIndexPath:` | `0x7f818` |
| `commonAlertView:clickedButtonAtIndex:` | `0x80128` |
| `settingClose` | `0x801dc` |
| `onEffectOnChanged:` | `0x801ec` |
| `onSimpleModeChanged:` | `0x8029c` |

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

### `ImageDownloader` — 🟡 partial

Methods **7/20** · ivars 6 · `instanceSize`=`28`

#### Missing methods

| Selector | Address |
| --- | --- |
| `connection:didReceiveResponse:` | `0x5a79c` |
| `dealloc` | `0x5aaa4` |
| `setImageURL:` | `0x5ab64` |
| `indexPathInTableView` | `0x5ab74` |
| `setIndexPathInTableView:` | `0x5ab84` |
| `delegate` | `0x5ab94` |
| `setDelegate:` | `0x5aba4` |
| `activeDownload` | `0x5abb4` |
| `setActiveDownload:` | `0x5abc4` |
| `imageConnection` | `0x5abd4` |
| `setImageConnection:` | `0x5abe4` |
| `downloadedImage` | `0x5abf4` |
| `setDownloadedImage:` | `0x5ac04` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_ImageURL` | `NSString *` | `0x4` |
| `m_IndexPathInTableView` | `NSIndexPath *` | `0x8` |
| `delegate` | `<ImageDownloaderDelegate> *` | `0xc` |
| `m_ActiveDownload` | `NSMutableData *` | `0x10` |
| `m_ImageConnection` | `NSURLConnection *` | `0x14` |
| `m_DownloadedImage` | `UIImage *` | `0x18` |

### `StoreViewController` — 🟡 partial

Methods **8/21** · ivars 8 · `instanceSize`=`192`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x53708` |
| `loadView` | `0x537d8` |
| `showModalDialog:` | `0x53b10` |
| `openDialogAnimStop:finished:context:` | `0x53c88` |
| `hideModalDialog` | `0x53cd8` |
| `closeDialogAnimStop:finished:context:` | `0x53df0` |
| `shouldAutorotateToInterfaceOrientation:` | `0x53e58` |
| `didReceiveMemoryWarning` | `0x54338` |
| `viewWillAppear:` | `0x54364` |
| `viewDidAppear:` | `0x54390` |
| `viewWillDisappear:` | `0x543bc` |
| `viewDidDisappear:` | `0x543e8` |
| `modalDialog` | `0x54414` |

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

### `HowToViewCtrl` — 🟡 partial

Methods **2/14** · ivars 7 · `instanceSize`=`189`

#### Missing methods

| Selector | Address |
| --- | --- |
| `didReceiveMemoryWarning` | `0x834e0` |
| `viewWillDisappear:` | `0x8350c` |
| `dealloc` | `0x83538` |
| `pageControlDidChanged:` | `0x835d8` |
| `scrollViewDidScroll:` | `0x83670` |
| `backButtonFunc` | `0x837bc` |
| `fromNaviBarImage` | `0x8385c` |
| `setFromNaviBarImage:` | `0x83870` |
| `backGroundImage` | `0x83880` |
| `setBackGroundImage:` | `0x83894` |
| `isCloseButtonEnable` | `0x838a4` |
| `setIsCloseButtonEnable:` | `0x838bc` |

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

### `StoreDetailMusicCell` — 🟡 partial

Methods **3/15** · ivars 11 · `instanceSize`=`96`

#### Missing methods

| Selector | Address |
| --- | --- |
| `handleLink:` | `0x74fb0` |
| `setBgImage:` | `0x74ffc` |
| `sampleDownloading` | `0x750dc` |
| `samplePlaying` | `0x7513c` |
| `dealloc` | `0x7519c` |
| `artworkView` | `0x752b4` |
| `labelName` | `0x752c4` |
| `labelArtist` | `0x752d4` |
| `labelLevels` | `0x752e4` |
| `linkURL` | `0x752f4` |
| `setLinkURL:` | `0x75304` |
| `arcadeViewer` | `0x75314` |

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

### `CharaInfo` — 🟡 partial

Methods **2/13** · ivars 6 · `instanceSize`=`28`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x640b8` |
| `setCharaId:` | `0x64144` |
| `charaName` | `0x6415c` |
| `setCharaName:` | `0x6416c` |
| `info` | `0x6417c` |
| `setInfo:` | `0x6418c` |
| `setSkillId:` | `0x641b0` |
| `skillName` | `0x641c8` |
| `setSkillName:` | `0x641d8` |
| `rarity` | `0x641e8` |
| `setRarity:` | `0x641fc` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_charaId` | `int` | `0x4` |
| `_charaName` | `NSString *` | `0x8` |
| `_info` | `NSString *` | `0xc` |
| `_skillId` | `int` | `0x10` |
| `_skillName` | `NSString *` | `0x14` |
| `_rarity` | `int` | `0x18` |

### `CommonAlertView` — 🟡 partial

Methods **4/15** · ivars 7 · `instanceSize`=`80`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:` | `0x4a308` |
| `dealloc` | `0x4b474` |
| `onYesButton` | `0x4b970` |
| `onNoButton` | `0x4b9a4` |
| `commonAlertView:clickedButtonAtIndex:` | `0x4b9d8` |
| `title` | `0x4bbc0` |
| `setTitle:` | `0x4bbd4` |
| `message` | `0x4bbe4` |
| `setMessage:` | `0x4bbf8` |
| `delegate` | `0x4bc08` |
| `setDelegate:` | `0x4bc1c` |

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

### `StoreDownloadManager` — 🟡 partial

Methods **1/12** · ivars 5 · `instanceSize`=`21`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithTasks:delegate:` | `0x41fec` |
| `currentProgress` | `0x42090` |
| `overallProgress` | `0x420b0` |
| `numTasks` | `0x42120` |
| `start` | `0x42140` |
| `cancel` | `0x422a0` |
| `downloaderProceed:` | `0x42568` |
| `downloaderError:` | `0x425bc` |
| `dealloc` | `0x42664` |
| `currentIndex` | `0x426e0` |
| `tasks` | `0x426f0` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Tasks` | `NSArray *` | `0x4` |
| `m_FileDownloader` | `Downloader *` | `0x8` |
| `m_Delegate` | `<StoreDownloadManagerDelegate> *` | `0xc` |
| `m_CurrentIndex` | `unsigned int` | `0x10` |
| `m_IsStarted` | `BOOL` | `0x14` |

### `StoreMusicInfo` — 🟡 partial

Methods **2/13** · ivars 10 · `instanceSize`=`44`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x566b8` |
| `musicID` | `0x5676c` |
| `name` | `0x5677c` |
| `artist` | `0x5678c` |
| `itemURL` | `0x5679c` |
| `artworkURL` | `0x567ac` |
| `sampleURL` | `0x567bc` |
| `itunesURL` | `0x567cc` |
| `lvBasic` | `0x567dc` |
| `lvMedium` | `0x567ec` |
| `lvHard` | `0x567fc` |

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

### `AcViewerSplitViewController` — 🟡 partial

Methods **7/16** · ivars 12 · `instanceSize`=`256`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x32234` |
| `viewDidLoad` | `0x326d4` |
| `didReceiveMemoryWarning` | `0x32700` |
| `startHiddenAnimation:` | `0x32a80` |
| `hiddenFunc` | `0x32c18` |
| `endHiddenAnimation` | `0x32c7c` |
| `onBackButtonTouched:` | `0x32d44` |
| `handleTapCoverView` | `0x3350c` |
| `.cxx_construct` | `0x33510` |

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

### `FriendMngTopViewController` — 🟡 partial

Methods **5/14** · ivars 3 · `instanceSize`=`172`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xa6488` |
| `viewDidLoad` | `0xa64b4` |
| `didReceiveMemoryWarning` | `0xa64e0` |
| `viewWillAppear:` | `0xa650c` |
| `endOpenAnimation` | `0xa66bc` |
| `startCloseAnimation` | `0xa66d0` |
| `endCloseAnimation` | `0xa6810` |
| `delegate` | `0xa6c00` |
| `setDelegate:` | `0xa6c10` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_markView` | `UIImageView *` | `0xa4` |
| `m_Delegate` | `id` | `0xa8` |

### `StoreDetailViewController` — 🟡 partial

Methods **39/48** · ivars 17 · `instanceSize`=`232`

#### Missing methods

| Selector | Address |
| --- | --- |
| `didReceiveMemoryWarning` | `0x72898` |
| `viewDidUnload` | `0x728c4` |
| `viewWillAppear:` | `0x72ad0` |
| `viewDidAppear:` | `0x72afc` |
| `viewWillDisappear:` | `0x72b60` |
| `viewDidDisappear:` | `0x72c88` |
| `backButtonFunc` | `0x72cb4` |
| `packInfo` | `0x72d0c` |
| `delegate` | `0x72d2c` |

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

### `neGLView` — 🟡 partial

Methods **6/15** · ivars 8 · `instanceSize`=`84`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:` | `0x28100` |
| `dealloc` | `0x28334` |
| `GetFrontBufferWidth` | `0x28524` |
| `GetFrontBufferHeight` | `0x28534` |
| `touchesBegan:withEvent:` | `0x285e8` |
| `touchesMoved:withEvent:` | `0x28718` |
| `touchesCancelled:withEvent:` | `0x289c4` |
| `delegate` | `0x289d4` |
| `setDelegate:` | `0x289e8` |

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

### `PurchaseManager` — 🟡 partial

Methods **22/30** · ivars 10 · `instanceSize`=`40`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x545b8` |
| `end` | `0x546f8` |
| `startProductRequest:` | `0x55170` |
| `downloaderProceed:` | `0x55eb8` |
| `delegate` | `0x56128` |
| `setDelegate:` | `0x56138` |
| `musicDataDelegate` | `0x56148` |
| `setMusicDataDelegate:` | `0x56158` |

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

### `Downloader` — 🟡 partial

Methods **9/16** · ivars 7 · `instanceSize`=`36`

#### Missing methods

| Selector | Address |
| --- | --- |
| `connection:didReceiveResponse:` | `0x62514` |
| `currentSize` | `0x62888` |
| `currentProgress` | `0x628a8` |
| `getProgressSec` | `0x629bc` |
| `dealloc` | `0x629f8` |
| `addData` | `0x62afc` |
| `setAddData:` | `0x62b10` |

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

### `PurchaseTransactionCache` — 🟡 partial

Methods **1/8** · ivars 5 · `instanceSize`=`24`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x56254` |
| `productID` | `0x56338` |
| `receiptData` | `0x56348` |
| `transactionID` | `0x56358` |
| `transactionDate` | `0x56368` |
| `digestString` | `0x56378` |
| `setDigestString:` | `0x56388` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_ProductID` | `NSString *` | `0x4` |
| `m_ReceiptData` | `NSData *` | `0x8` |
| `m_TransactionID` | `NSString *` | `0xc` |
| `m_TransactionDate` | `NSDate *` | `0x10` |
| `m_DigestString` | `NSString *` | `0x14` |

### `StorePackMusicView` — 🟡 partial

Methods **7/14** · ivars 9 · `instanceSize`=`88`

#### Missing methods

| Selector | Address |
| --- | --- |
| `setIsExistAcv:` | `0x5171c` |
| `dealloc` | `0x5191c` |
| `artworkView` | `0x519e4` |
| `labelName` | `0x519f4` |
| `labelArtist` | `0x51a04` |
| `labelLevels` | `0x51a14` |
| `buttonLink` | `0x51a34` |

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

### `AcViewerDetailCell` — 🟡 partial

Methods **1/7** · ivars 5 · `instanceSize`=`72`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x5b668` |
| `setData:` | `0x5b694` |
| `optionName` | `0x5bbb8` |
| `setOptionName:` | `0x5bbc8` |
| `optionKind` | `0x5bbd8` |
| `setOptionKind:` | `0x5bbec` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_optionLbl` | `UILabel *` | `0x34` |
| `_checkImageView` | `UIImageView *` | `0x38` |
| `_optionName` | `NSString *` | `0x3c` |
| `_optionKind` | `int` | `0x40` |
| `_index` | `int` | `0x44` |

### `AcViewerMusicCell` — 🟡 partial

Methods **1/7** · ivars 13 · `instanceSize`=`104`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x40954` |
| `setData:` | `0x409e0` |
| `easyBtn` | `0x4168c` |
| `normalBtn` | `0x416a0` |
| `hyperBtn` | `0x416b4` |
| `exBtn` | `0x416c8` |

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

### `LimitedCharaInfo` — 🟡 partial

Methods **1/7** · ivars 3 · `instanceSize`=`13`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x642e8` |
| `musicIds` | `0x6434c` |
| `setMusicIds:` | `0x6435c` |
| `setCharaIds:` | `0x6437c` |
| `getFlg` | `0x6438c` |
| `setGetFlg:` | `0x643a4` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_musicIds` | `NSArray *` | `0x4` |
| `_charaIds` | `NSArray *` | `0x8` |
| `_getFlg` | `BOOL` | `0xc` |

### `PreferredCharaInfo` — 🟡 partial

Methods **1/7** · ivars 3 · `instanceSize`=`13`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x64214` |
| `musicIds` | `0x64278` |
| `setMusicIds:` | `0x64288` |
| `setCharaIds:` | `0x642a8` |
| `getFlg` | `0x642b8` |
| `setGetFlg:` | `0x642d0` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_musicIds` | `NSArray *` | `0x4` |
| `_charaIds` | `NSArray *` | `0x8` |
| `_getFlg` | `BOOL` | `0xc` |

### `StoreAcMusicInfo` — 🟡 partial

Methods **2/8** · ivars 5 · `instanceSize`=`24`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x85458` |
| `acMusicId` | `0x854e4` |
| `title` | `0x854f4` |
| `genre` | `0x85504` |
| `itemURL` | `0x85514` |
| `sampleURL` | `0x85524` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `acMusicId` | `int` | `0x4` |
| `title` | `NSString *` | `0x8` |
| `genre` | `NSString *` | `0xc` |
| `itemURL` | `NSString *` | `0x10` |
| `sampleURL` | `NSString *` | `0x14` |

### `StorePackCell` — 🟡 partial

Methods **1/7** · ivars 8 · `instanceSize`=`84`

#### Missing methods

| Selector | Address |
| --- | --- |
| `isPurchased` | `0x6f5a8` |
| `setIsPurchased:` | `0x6f5d8` |
| `loadPackInfo:` | `0x6f604` |
| `setBgImage:` | `0x6f7b4` |
| `dealloc` | `0x6f7d4` |
| `artworkView` | `0x6f8b0` |

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

### `StorePackInfo` — 🟡 partial

Methods **18/24** · ivars 13 · `instanceSize`=`56`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x570f4` |
| `downloadDetailInfo` | `0x571e4` |
| `musicInfos` | `0x573f0` |
| `acvMusicInfos` | `0x57400` |
| `artistURL` | `0x57410` |
| `bunnerURL` | `0x57420` |

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

### `StorePackInfoDownloader` — 🟡 partial

Methods **8/14** · ivars 3 · `instanceSize`=`16`

#### Missing methods

| Selector | Address |
| --- | --- |
| `downloaderProceed:` | `0x57690` |
| `packInfo` | `0x57744` |
| `delegate` | `0x57764` |
| `setDelegate:` | `0x57774` |
| `downloader` | `0x57784` |
| `setDownloader:` | `0x57794` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_PackInfo` | `StorePackInfo *` | `0x4` |
| `m_Downloader` | `Downloader *` | `0x8` |
| `m_Delegate` | `<StorePackInfoDownloaderDelegate> *` | `0xc` |

### `StorePackListController` — 🟡 partial

Methods **13/19** · ivars 10 · `instanceSize`=`41`

#### Missing methods

| Selector | Address |
| --- | --- |
| `packInfos` | `0x57a24` |
| `downloaderProceed:` | `0x58540` |
| `request:didFailWithError:` | `0x58698` |
| `dealloc` | `0x58714` |
| `delegate` | `0x58800` |
| `setDelegate:` | `0x58810` |

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

### `StorePackView` — 🟡 partial

Methods **5/11** · ivars 11 · `instanceSize`=`96`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x52448` |
| `setBgImage:` | `0x52488` |
| `setIsPurchased:` | `0x52560` |
| `delegate` | `0x52784` |
| `setDelegate:` | `0x52794` |
| `index` | `0x527a4` |

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

### `BirthDayViewController` — 🟡 partial

Methods **8/13** · ivars 8 · `instanceSize`=`196`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x847e8` |
| `viewDidLoad` | `0x8506c` |
| `didReceiveMemoryWarning` | `0x85098` |
| `delegate` | `0x850c4` |
| `setDelegate:` | `0x850d4` |

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

### `MusicPatch` — 🟡 partial

Methods **4/9** · ivars 4 · `instanceSize`=`20`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x787f4` |
| `musicId` | `0x78820` |
| `setLvN:` | `0x78860` |
| `setLvH:` | `0x7888c` |
| `setLvEx:` | `0x788b8` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_musicId` | `int` | `0x4` |
| `_lvN` | `int` | `0x8` |
| `_lvH` | `int` | `0xc` |
| `_lvEx` | `int` | `0x10` |

### `PresentBoxCell` — 🟡 partial

Methods **1/6** · ivars 5 · `instanceSize`=`84`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x6e438` |
| `setSelected:animated:` | `0x6e464` |
| `setPresentData:` | `0x6e494` |
| `.cxx_construct` | `0x6ed48` |
| `getBtn` | `0x6ed34` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_getBtn` | `UIButton *` | `0x34` |
| `_imageViewIcon` | `UIImageView *` | `0x38` |
| `_lbl` | `UILabel *` | `0x3c` |
| `_lblInfo` | `UILabel *` | `0x40` |
| `_presentData` | `struct PresentData` | `0x44` |

### `CustomButton` — 🟡 partial

Methods **2/6** · ivars 1 · `instanceSize`=`92`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:` | `0xdcf5c` |
| `dealloc` | `0xdcf94` |
| `.cxx_construct` | `0xdd154` |
| `setTappableInsets:` | `0xdd11c` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_tappableInsets` | `struct UIEdgeInsets` | `0x4c` |

### `OverScoreLogCell` — 🟡 partial

Methods **1/5** · ivars 7 · `instanceSize`=`104`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x697a8` |
| `setSelected:animated:` | `0x697d4` |
| `setOverScoreLogData:` | `0x69804` |
| `.cxx_construct` | `0x6a29c` |

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

### `RecommendListCell` — 🟡 partial

Methods **1/5** · ivars 11 · `instanceSize`=`96`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xbd518` |
| `setRecommendData:` | `0xbd578` |
| `imageDownloader:didLoad:` | `0xbe1d0` |
| `imageDownloaderDidFail:didLoad:` | `0xbe244` |

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

### `StorePromotionView` — 🟡 partial

Methods **15/19** · ivars 8 · `instanceSize`=`84`

#### Missing methods

| Selector | Address |
| --- | --- |
| `layoutSubviews` | `0x79c00` |
| `imageDownloaderDidFail:didLoad:` | `0x7a2a4` |
| `delegate` | `0x7a724` |
| `setDelegate:` | `0x7a734` |

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

### `TwitterUtil` — 🟡 partial

Methods **2/6** · ivars 2 · `instanceSize`=`172`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x788d0` |
| `init` | `0x78934` |
| `setText:` | `0x789a8` |
| `setImage:` | `0x78a08` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_Text` | `NSString *` | `0xa4` |
| `m_Img` | `UIImage *` | `0xa8` |

### `FriendReplyCell` — 🟡 partial

Methods **4/7** · ivars 15 · `instanceSize`=`112`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xa9280` |
| `delegate` | `0xa9dc0` |
| `setDelegate:` | `0xa9dd4` |

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

### `FriendRequestCell` — 🟡 partial

Methods **1/4** · ivars 11 · `instanceSize`=`96`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xb9850` |
| `setFriendData:` | `0xb987c` |
| `onTouchedCancelButton` | `0xba048` |

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

### `StoreDetailHeaderView` — 🟡 partial

Methods **4/7** · ivars 7 · `instanceSize`=`80`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x7447c` |
| `labelName` | `0x74544` |
| `labelComment` | `0x74554` |

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

### `StoreDownloadTask` — 🟡 partial

Methods **2/5** · ivars 3 · `instanceSize`=`16`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithURL:path:AddObject:` | `0x42700` |
| `dealloc` | `0x427dc` |
| `addObject` | `0x42874` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_FileURL` | `NSString *` | `0x4` |
| `m_FilePath` | `NSString *` | `0x8` |
| `m_AddObject` | `id` | `0xc` |

### `StoreImageView` — 🟡 partial

Methods **4/7** · ivars 2 · `instanceSize`=`64`

#### Missing methods

| Selector | Address |
| --- | --- |
| `unloadImage:` | `0x42928` |
| `dealloc` | `0x42aa8` |
| `imageURL` | `0x42b20` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_ImageURL` | `NSString *` | `0x38` |
| `m_ImageDownloader` | `ImageDownloader *` | `0x3c` |

### `StoreTableCell` — 🟡 partial

Methods **1/4** · ivars 2 · `instanceSize`=`60`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x5293c` |
| `leftPackView` | `0x529e4` |
| `rightPackView` | `0x529f4` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_LeftPackView` | `StorePackView *` | `0x34` |
| `m_RightPackView` | `StorePackView *` | `0x38` |

### `AcViewerOptionCell` — 🟡 partial

Methods **1/3** · ivars 2 · `instanceSize`=`60`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x654c8` |
| `setData:` | `0x654f4` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_optionKindLbl` | `UILabel *` | `0x34` |
| `_optionDetailLbl` | `UILabel *` | `0x38` |

### `BFCodec` — 🟡 partial

Methods **4/6** · ivars 2 · `instanceSize`=`16`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x5ac14` |
| `dealloc` | `0x5b154` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_iv` | `unsigned char[8]` | `0x4` |
| `_blf` | `struct C_BLOWFISH *` | `0xc` |

### `CheckerCategoryCell` — 🟡 partial

Methods **1/3** · ivars 7 · `instanceSize`=`84`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xcf5c8` |
| `setData:category:` | `0xcf5f4` |

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

### `CustomTextView` — 🟡 partial

Methods **2/4** · ivars 0 · `instanceSize`=`56`

#### Missing methods

| Selector | Address |
| --- | --- |
| `initWithFrame:` | `0x27fd0` |
| `dealloc` | `0x28008` |

### `FriendScoreTableCell` — 🟡 partial

Methods **1/3** · ivars 23 · `instanceSize`=`144`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xae25c` |
| `setScoreData:` | `0xae288` |

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

### `MapListCell` — 🟡 partial

Methods **1/3** · ivars 2 · `instanceSize`=`60`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xbe2b8` |
| `setMapData:isSelect:` | `0xbe2e4` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_mapVal` | `NSValue *` | `0x34` |
| `_bgImgView` | `UIImageView *` | `0x38` |

### `SortCell` — 🟡 partial

Methods **1/3** · ivars 4 · `instanceSize`=`68`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xc5460` |
| `setSortData:` | `0xc548c` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_sortVal` | `NSValue *` | `0x34` |
| `_titleImageView` | `UIImageView *` | `0x38` |
| `_checkImageView` | `UIImageView *` | `0x3c` |
| `_bgImgView` | `UIImageView *` | `0x40` |

### `StoreDetailCopyrightCell` — 🟡 partial

Methods **1/3** · ivars 1 · `instanceSize`=`56`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x7547c` |
| `labelCopyright` | `0x754c8` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `labelCopyright` | `UILabel *` | `0x34` |

### `StorePromotionTableCell` — 🟡 partial

Methods **1/3** · ivars 0 · `instanceSize`=`52`

#### Missing methods

| Selector | Address |
| --- | --- |
| `setSelected:animated:` | `0x738f4` |
| `layoutSubviews` | `0x73924` |

### `SubMapListCell` — 🟡 partial

Methods **1/3** · ivars 1 · `instanceSize`=`56`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xc0fd4` |
| `setMapData:` | `0xc1000` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_mapVal` | `NSValue *` | `0x34` |

### `SystemHardware` — 🟡 partial

Methods **3/5** · ivars 2 · `instanceSize`=`12`

#### Missing methods

| Selector | Address |
| --- | --- |
| `init` | `0x12718` |
| `dealloc` | `0x12758` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `m_HardwareType` | `int` | `0x4` |
| `m_HardwareName` | `NSString *` | `0x8` |

### `YearAndMonthPicker` — 🟡 partial

Methods **7/9** · ivars 3 · `instanceSize`=`64`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0x8efe4` |
| `month` | `0x8f424` |

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_year` | `int` | `0x34` |
| `_month` | `int` | `0x38` |
| `monthArr` | `NSMutableArray *` | `0x3c` |

### `FriendListCell` — 🟡 partial

Methods **2/3** · ivars 19 · `instanceSize`=`128`

#### Missing methods

| Selector | Address |
| --- | --- |
| `dealloc` | `0xb3494` |

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

### `SettingOtherTableViewController` — 🟡 partial

Methods **23/24** · ivars 8 · `instanceSize`=`208`

#### Missing methods

| Selector | Address |
| --- | --- |
| `.cxx_construct` | `0xd5880` |

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

### `ArcadeScoreData` — ✅ complete

Methods **1/1** · ivars 0 · `instanceSize`=`48`

### `CharaTicketData` — ✅ complete

Methods **0/0** · ivars 0 · `instanceSize`=`48`

### `DelayImageView` — ✅ complete

Methods **3/3** · ivars 1 · `instanceSize`=`56`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `image` | `UIImage *` | `0x34` |

### `FriendListDetail` — ✅ complete

Methods **15/15** · ivars 6 · `instanceSize`=`72`

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

Methods **6/6** · ivars 2 · `instanceSize`=`61`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_friendData` | `NSValue *` | `0x38` |
| `_isAnimationing` | `BOOL` | `0x3c` |

### `FriendListViewController` — ✅ complete

Methods **12/12** · ivars 6 · `instanceSize`=`188`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_dummyView` | `UIViewController *` | `0xa4` |
| `_sortButton` | `UIButton *` | `0xa8` |
| `_lonelyImageView` | `UIImageView *` | `0xac` |
| `_detailView` | `FriendListDetail *` | `0xb0` |
| `_isBestScoreSort` | `BOOL` | `0xb4` |
| `_frinedDataArray` | `NSArray *` | `0xb8` |

### `FriendReplyViewController` — ✅ complete

Methods **17/17** · ivars 8 · `instanceSize`=`196`

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

### `GameEffectView` — ✅ complete

Methods **11/11** · ivars 0 · `instanceSize`=`162`

### `HowToView` — ✅ complete

Methods **3/3** · ivars 2 · `instanceSize`=`60`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_imageList` | `NSArray *` | `0x34` |
| `_bgImage` | `UIImage *` | `0x38` |

### `OverScoreData` — ✅ complete

Methods **0/0** · ivars 0 · `instanceSize`=`48`

### `PolicyView` — ✅ complete

Methods **11/11** · ivars 1 · `instanceSize`=`168`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_textView` | `UITextView *` | `0xa4` |

### `PopkunSizeViewCtrl` — ✅ complete

Methods **10/10** · ivars 12 · `instanceSize`=`224`

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

### `ScoreData` — ✅ complete

Methods **0/0** · ivars 0 · `instanceSize`=`48`

### `SettingCustomerTableViewController` — ✅ complete

Methods **14/14** · ivars 2 · `instanceSize`=`168`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_policyView` | `UINavigationController *` | `0xa4` |

### `SettingGameTableViewController` — ✅ complete

Methods **17/17** · ivars 4 · `instanceSize`=`288`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `_selectedIndexPath` | `NSIndexPath *` | `0xa4` |
| `_detailView` | `UIViewController *[6]` | `0xa8` |
| `_dummyFrm` | `struct CGRect[6]` | `0xc0` |

### `SettingHowtoTableViewController` — ✅ complete

Methods **14/14** · ivars 2 · `instanceSize`=`168`

#### Ivars

| Name | Type | Offset |
| --- | --- | ---: |
| `_isAnimationing` | `BOOL` | `0xa2` |
| `howtoViewCtrlPad` | `HowToViewCtrlPad *` | `0xa4` |

### `SoundSettingView` — ✅ complete

Methods **22/22** · ivars 8 · `instanceSize`=`196`

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

### `StoreUtil` — ✅ complete

Methods **0/0** · ivars 0 · `instanceSize`=`4`

### `TreasureData` — ✅ complete

Methods **1/1** · ivars 0 · `instanceSize`=`48`

### `UserSettingData` — ✅ complete

Methods **0/0** · ivars 0 · `instanceSize`=`4`

### `neTextureForiOS` — ✅ complete

Methods **0/0** · ivars 0 · `instanceSize`=`4`

---

## C++ classes (engine / game core)

C++ has no `__objc_classlist`; these are recovered from Ghidra namespace metadata (functions the
reconstruction named `Class::method`). **Many more C++ methods remain hidden in the flat "free function" pool** — functions whose `param_1` is an implicit `this`. The plan (per review): identify those by the `this` first-arg and rename them into Ghidra namespaces (namespace = class), promoting the free-function pool into these class tables over subsequent passes.

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

**Free functions (unclassified C/C++, no namespace yet):** ~0 functions, ~0 reconstructed —
includes real free functions (Aep* renderer, matrix/fixed-point math, `entry`) plus flat-named C++
methods awaiting `this`-based promotion into the classes above. Library/runtime funcs excluded.

