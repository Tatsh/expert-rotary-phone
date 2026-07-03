# CMakeLists.txt — Project
#
# Per-directory source list for the PopnRhythmin app target (defined in the root
# CMakeLists.txt). Adds this directory's translation units and puts the directory
# on the include path so its quote-imported headers resolve. Regenerate with the
# generator in the repo if you add/rename files, or just edit by hand.

target_sources(popnrhythmin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/AcViewerDetailCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/AcViewerMusicCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/AcViewerOptionCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/AcViewerSplitViewController.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/AppDelegate.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/AppFont.m
    ${CMAKE_CURRENT_SOURCE_DIR}/BirthDayViewController.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/CheckerCategoryCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/CommonAlertView.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/CustomButton.m
    ${CMAKE_CURRENT_SOURCE_DIR}/CustomTextView.m
    ${CMAKE_CURRENT_SOURCE_DIR}/DownloadMain.m
    ${CMAKE_CURRENT_SOURCE_DIR}/Downloader.m
    ${CMAKE_CURRENT_SOURCE_DIR}/FriendListCell.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/FriendListDetailChara.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/FriendMngTopViewController.m
    ${CMAKE_CURRENT_SOURCE_DIR}/FriendReplyCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/FriendRequestCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/FriendScoreTableCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/HowToView.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/HowToViewCtrl.m
    ${CMAKE_CURRENT_SOURCE_DIR}/ImageDownloader.m
    ${CMAKE_CURRENT_SOURCE_DIR}/MainViewController.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/MapListCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/OverScoreLogCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/PresentBoxCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/RecommendListCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/SettingTableViewController.m
    ${CMAKE_CURRENT_SOURCE_DIR}/SortCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreAcMusicInfo.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreAcvManageViewController.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreDetailCopyrightCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreDetailHeaderView.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreDetailMusicCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreDetailViewController.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreDownloadManager.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreDownloadTask.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreImageView.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreMainViewController.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreManageViewController.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreMusicInfo.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StorePackCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StorePackDetailViewPad.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StorePackInfo.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StorePackInfoDownloader.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StorePackListController.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StorePackMusicView.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StorePackView.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/StorePromotionTableCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StorePromotionView.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreTableCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreUtil.m
    ${CMAKE_CURRENT_SOURCE_DIR}/StoreViewController.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/SubMapListCell.m
    ${CMAKE_CURRENT_SOURCE_DIR}/YearAndMonthPicker.m
    ${CMAKE_CURRENT_SOURCE_DIR}/main.m
)

target_include_directories(popnrhythmin PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

add_subdirectory(Game)
add_subdirectory(System)
