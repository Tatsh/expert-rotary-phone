/**
 * @file
 * @brief The iPad in-place pack-detail panel.
 *
 * An embedded view, shown over a dimmed cover, that displays a StorePackInfo — jacket, name,
 * price, song list, and the purchase button — without pushing a new screen. It is bound via
 * setPackInfo:.
 *
 * Reconstructed from Ghidra project rb420, program PopnRhythmin (setPackInfo: @ 0x50b58).
 */

#import <UIKit/UIKit.h>

@class StorePackInfo;
@class StorePackDetailViewPad;
@class StorePackInfoDownloader;
@class StorePackMusicView;
@class Downloader;
@class BirthDayViewController;
@class StoreImageView;

/**
 * @brief Receives the iPad detail card's purchase and close requests.
 */
@protocol StorePackDetailViewPadDelegate <NSObject>
@optional
/**
 * @brief The card's buy button was tapped.
 * @param view The detail card.
 * @param packInfo The pack to purchase.
 */
- (void)packDetailViewPad:(StorePackDetailViewPad *)view
        didSelectPurchase:(StorePackInfo *)packInfo;
/**
 * @brief The card asked to close.
 * @param view The detail card.
 */
- (void)packDetailViewPadDidClose:(StorePackDetailViewPad *)view;
@end

/**
 * @brief The iPad in-place pack detail card: the jacket, description, song rows and buy button.
 */
@interface StorePackDetailViewPad : UIView {
    StorePackInfo *m_PackInfo;                            /**< The displayed pack. */
    __weak id<StorePackDetailViewPadDelegate> m_Delegate; /**< The purchase and close delegate. */
    StorePackInfoDownloader *m_StorePackInfoDownloader;   /**< The in-flight detail fetch. */
    StorePackMusicView *musicView[4];                     /**< The up-to-four song rows. */
    Downloader *m_SampleDownloader;                       /**< The in-flight preview clip. */
    int samplePlaying;                      /**< The row index currently sampling, or -1. */
    NSArray *recommendPackIdArr;            /**< The cached recommended-pack ids. */
    BirthDayViewController *m_BirthDayView; /**< The age-gate modal, retained while shown. */
    Downloader *recommendDownloader;        /**< The in-flight "register recommended pack" POST. */
    UIViewController *dummyView;            /**< The cover host shown during the recommend POST. */
    UIButton *buttonPurchase;  /**< The buy or "INSTALLED" button, built in -initWithFrame:. */
    UILabel *labelPackName;    /**< The pack title. */
    UILabel *labelComment;     /**< The pack description. */
    UITextView *copyrightView; /**< The copyright text. */
    StoreImageView *packArtworkView;    /**< The pack jacket, loaded asynchronously. */
    UIView *packView;                   /**< The pack-info container panel. */
    UIButton *m_ArtistSiteButton;       /**< The "web" button that opens the artist site. */
    UIActivityIndicatorView *indicator; /**< The loading spinner. */
    UILabel *labelLoading;              /**< The "loading" caption. */
    BOOL isInfoLoaded;                  /**< The detail has been fully fetched and shown. */
}

/** The displayed pack. Getter @ 0x50b48, setter @ 0x50b58. */
@property(nonatomic, retain) StorePackInfo *packInfo;
/** The purchase and close delegate. Getter @ 0x50b68, setter @ 0x50b78. */
@property(nonatomic, weak) id<StorePackDetailViewPadDelegate> delegate;

/**
 * @brief Kick the pack-detail download: if the pack already has its song list, tint and show the
 * card; otherwise grey it, spin the loading indicator and start a StorePackInfoDownloader.
 * @ghidraAddress 0x4f680
 */
- (void)loadInfo;
/**
 * @brief Tear the bound pack down; the iPad detail-close path.
 */
- (void)removePackInfo;

/**
 * @brief Populate the detail card from the bound pack: the name, comment, copyright, jacket, buy
 * button, and the up-to-four song rows with their .acv and artwork state. It runs once, guarded by
 * isInfoLoaded.
 * @ghidraAddress 0x4f318
 */
- (void)showPackInfo;

/**
 * @brief Choose the purchase button's label for the current ownership and download state.
 * @ghidraAddress 0x4ef54
 */
- (void)selfCheckButtonText;

/**
 * @brief Set the purchase button to its enabled "buy (price)" state.
 * @ghidraAddress 0x4f024
 */
- (void)setButtonTextBuy;

/**
 * @brief Set the purchase button to its enabled, localised "INSTALL" state.
 * @ghidraAddress 0x4f0b8
 */
- (void)setButtonTextInstall;

/**
 * @brief Set the purchase button to its disabled, localised "INSTALLING" state.
 * @ghidraAddress 0x4f144
 */
- (void)setButtonTextInstalling;

/**
 * @brief Set the purchase button to its installed state: a greyed "INSTALLED" once the pack has
 * been recommended, otherwise the tappable "友達に勧める" (recommend) label.
 * @ghidraAddress 0x4f1d0
 */
- (void)setButtonTextInstalled;

/**
 * @brief Abort a pending pack-detail fetch; called when the panel is dismissed.
 * @ghidraAddress 0x4ecd0
 */
- (void)cancelLoading;

/**
 * @brief Stop the preview clip: cancel the in-flight download, reset every song row's button, and
 * mark nothing playing.
 * @ghidraAddress 0x4ed28
 */
- (void)stopSample;

/**
 * @brief A song row's sample button was tapped: toggle its preview.
 *
 * Tapping the row that is already sampling stops it; tapping another row stops that one and starts
 * fetching the new clip, which the Downloader callback plays on completion.
 * @param sender The tapped button.
 * @ghidraAddress 0x4fdf0
 */
- (void)handleSample:(id)sender;

/**
 * @brief A song row's iTunes button was tapped: open that song's iTunes page.
 * @param sender The tapped button.
 * @ghidraAddress 0x4fd04
 */
- (void)handleLink:(id)sender;

/**
 * @brief The artist-site button was tapped: open the pack's artist URL.
 * @ghidraAddress 0x50080
 */
- (void)selectWebButton;

/**
 * @brief Hand the purchase off to the delegate, which drives StoreKit.
 * @ghidraAddress 0x4fca4
 */
- (void)doPurchase;

/**
 * @brief Whether the displayed pack has songs and all of them are already downloaded; the purchase
 * dispatcher uses it to offer a re-download instead of a buy.
 * @return YES when the pack is fully installed.
 * @ghidraAddress 0x4edb8
 */
- (BOOL)allDownloaded;

/**
 * @brief Whether this pack is one of the recommended packs: its id is in the decoded recommend
 * list, which is fetched and cached lazily.
 * @return YES when the pack is recommended.
 * @ghidraAddress 0x4ee14
 */
- (BOOL)isRecommended;

/**
 * @brief The age-gate modal reported the entered birthday: drop it and, now that an age is on
 * record, re-run the spending-limit check — either proceeding to buy or showing the "over limit"
 * alert.
 * @ghidraAddress 0x50154
 */
- (void)birthDayViewClose;

/**
 * @brief The pack purchase button's full decision tree: when the pack is already owned, re-download
 * it or register it as recommended; when it is not, run the spending-limit check and either buy or
 * show the age gate.
 * @param sender The tapped button.
 * @ghidraAddress 0x4f828
 */
- (void)doPurchase:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
