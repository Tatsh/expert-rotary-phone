//
//  StorePackDetailViewPad.h
//  pop'n rhythmin
//
//  The iPad in-place pack-detail panel: an embedded view (shown over a dimmed
//  cover) that displays a StorePackInfo — jacket, name, price, song list, and the
//  purchase button — without pushing a new screen. Bound via setPackInfo:.
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (setPackInfo: @ 0x50b58).
//

#import <UIKit/UIKit.h>

@class StorePackInfo;
@class StorePackDetailViewPad;
@class StorePackInfoDownloader;
@class StorePackMusicView;
@class Downloader;
@class BirthDayViewController;
@class StoreImageView;

@protocol StorePackDetailViewPadDelegate <NSObject>
@optional
- (void)packDetailViewPad:(StorePackDetailViewPad *)view didSelectPurchase:(StorePackInfo *)packInfo;
- (void)packDetailViewPadDidClose:(StorePackDetailViewPad *)view;
@end

@interface StorePackDetailViewPad : UIView {
    StorePackInfo *m_PackInfo;
    __weak id<StorePackDetailViewPadDelegate> m_Delegate;
    StorePackInfoDownloader *m_StorePackInfoDownloader;  // in-flight detail fetch (retained)
    StorePackMusicView *musicView[4];                    // the up-to-4 song rows
    Downloader *m_SampleDownloader;                       // in-flight preview clip (retained)
    int samplePlaying;                                    // row index currently sampling, or -1
    NSArray *recommendPackIdArr;                          // cached recommended-pack ids (retained)
    BirthDayViewController *m_BirthDayView;               // age-gate modal (retained while shown)
    Downloader *recommendDownloader;                      // in-flight "register recommended pack" POST
    UIViewController *dummyView;                          // cover host shown during the recommend POST
    UIButton *buttonPurchase;                            // the "buy" / "INSTALLED" button (built in initWithFrame:)
    UILabel *labelPackName;                              // pack title
    UILabel *labelComment;                               // pack description
    UITextView *copyrightView;                           // copyright text
    StoreImageView *packArtworkView;                     // pack jacket (async)
    UIView *packView;                                    // the pack-info container panel
    UIButton *m_ArtistSiteButton;                        // "web" button opening the artist site
    UIActivityIndicatorView *indicator;                  // loading spinner
    UILabel *labelLoading;                               // "loading" caption
    BOOL isInfoLoaded;                                   // detail fully fetched + shown
}

@property (nonatomic, retain) StorePackInfo *packInfo;   // getter @ 0x50b48, setter @ 0x50b58
@property (nonatomic, weak) id<StorePackDetailViewPadDelegate> delegate;  // getter @ 0x50b68, setter @ 0x50b78

// Kick the pack-detail download: if the pack already has its song list, tint + show the card;
// otherwise grey it, spin the loading indicator and start a StorePackInfoDownloader. Ghidra:
// @ 0x4f680.
- (void)loadInfo;

// Populate the detail card from the bound pack (name, comment, copyright, jacket, buy button, the
// up-to-4 song rows and their .acv/artwork state); runs once (guarded by isInfoLoaded). Ghidra:
// @ 0x4f318.
- (void)showPackInfo;

// Choose the purchase button's label for the current ownership/download state. Ghidra: @ 0x4ef54.
- (void)selfCheckButtonText;

// Set the purchase button to its "buy (price)" state (enabled). Ghidra: @ 0x4f024.
- (void)setButtonTextBuy;

// Set the purchase button to its localized "INSTALL" state (enabled). Ghidra: @ 0x4f0b8.
- (void)setButtonTextInstall;

// Set the purchase button to its localized "INSTALLING" state (disabled). Ghidra: @ 0x4f144.
- (void)setButtonTextInstalling;

// Set the purchase button to its "installed" state: greyed "INSTALLED" if already recommended,
// otherwise the tappable "友達に勧める" (recommend) label. Ghidra: @ 0x4f1d0.
- (void)setButtonTextInstalled;

// Abort a pending pack-detail fetch (called when the panel is dismissed). Ghidra:
// @ 0x4ecd0.
- (void)cancelLoading;

// Stop the preview clip: cancel the in-flight download, reset every song row's button,
// and mark nothing playing. Ghidra: @ 0x4ed28.
- (void)stopSample;

// A song row's sample button was tapped: toggle its preview. Tapping the row that is
// already sampling stops it; tapping another row stops that one and starts fetching the
// new clip (played on completion by the Downloader callback). Ghidra: @ 0x4fdf0.
- (void)handleSample:(id)sender;

// A song row's iTunes button was tapped: open that song's iTunes page. Ghidra: @ 0x4fd04.
- (void)handleLink:(id)sender;

// The artist-site button was tapped: open the pack's artist URL. Ghidra: @ 0x50080.
- (void)selectWebButton;

// Hand the purchase off to the delegate (which drives StoreKit). Ghidra: @ 0x4fca4.
- (void)doPurchase;

// YES if the displayed pack has songs and all of them are already downloaded (used by the
// purchase dispatcher to offer a re-download instead of a buy). Ghidra: @ 0x4edb8.
- (BOOL)allDownloaded;

// YES if this pack is one of the recommended packs (its id is in the decoded recommend
// list, fetched + cached lazily). Ghidra: @ 0x4ee14.
- (BOOL)isRecommended;

// The age-gate modal reported the entered birthday: drop it and, now that an age is on
// record, re-run the spending-limit check (proceed to buy, or show the "over limit" alert).
// Ghidra: @ 0x50154 (the BirthDayViewController delegate callback).
- (void)birthDayViewClose;

// The pack purchase button: the full decision tree — already owned (re-download or register
// as recommended), or not owned (spending-limit check -> buy, or show the age gate).
// Ghidra: doPurchase: @ 0x4f828.
- (void)doPurchase:(id)sender;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
