//
//  SearchView.h
//  pop'n rhythmin
//
//  The arcade-locator ("game center" search) screen: a full-screen MKMapView
//  that drops a pin for every nearby arcade. It first downloads a "master" feed
//  (the pin marker images + per-model metadata), then, as the visible region
//  changes, POSTs the current lat/long/range to the server and adds/removes
//  annotations for the arcades in view. Tapping a pin's callout offers to open
//  the location in the Maps app. Hosted inside its own UINavigationController,
//  presented over the GL scene by MainViewController -GotoArcadeSearch.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin (SearchView @
//  0x85538..0x88a98, class methods +mapRectForCoordinateRegion: @ 0x86250 /
//  +currentLocationEnabled @ 0x86330).
//

#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>

#import "CommonAlertView.h" // CommonAlertViewDelegate
#import "Downloader.h"      // DownloaderDelegate + Downloader ivars
#import "ImageDownloader.h" // ImageDownloaderDelegate + ImageDownloader ivar

/**
 * @brief The arcade-search map: the user's location plus pins for nearby arcades.
 */
@interface SearchView : UIViewController <MKMapViewDelegate,
                                          DownloaderDelegate,
                                          ImageDownloaderDelegate,
                                          CommonAlertViewDelegate> {
    /** The map filling the screen; the user-location dot and arcade pins are drawn on it. */
    MKMapView *m_Map;
    /** A small spinner shown while any download is in flight; m_IndicatorCount ref-counts it. */
    UIActivityIndicatorView *m_Indicator;
    int m_IndicatorCount; /**< How many downloads are keeping the spinner up. */
    /** The rounded translucent label shown when the map is zoomed out too far to search. */
    UILabel *m_MessageLabel;
    /** The rounded translucent label that fades in to surface network and server errors. */
    UILabel *m_ErrorLabel;
    Downloader *m_MasterDownloader; /**< The master-feed request. */
    Downloader *m_ListDownloader;   /**< The per-region arcade query. */
    /** Loads the master and per-model marker images, one at a time. */
    ImageDownloader *m_ImageDownloader;
    /** The master feed's top-level info: the master marker image URL and its decoded image. */
    NSMutableDictionary *m_Info;
    /** The per-model marker metadata: {Order, Model, Name, Image, IMAGE_OBJECT}. */
    NSMutableArray *m_Models;
    /** Maps a model name to its index in m_Models, driving the per-pin marker image lookup. */
    NSMutableDictionary *m_ModelNameForArrayIndex;
    /** The region last sent to the server; it decides when to re-query on a pan. */
    MKCoordinateRegion m_LastRegion;
    /** Maps an arcade id to its MapAnnotation, for every arcade seen so far. */
    NSMutableDictionary *m_DictSpot;
    /** The Maps-app URL built for the pin whose callout was tapped. */
    NSString *m_GoogleMapURL;
    BOOL m_LoadedMaster;   /**< The master feed has loaded. */
    BOOL m_LoadedImages;   /**< Every marker image has loaded. */
    BOOL m_IsAnimationing; /**< An open or close animation is running. */
}

/**
 * @brief The entry point MainViewController's -GotoArcadeSearch uses: run [super init], then wrap
 * the receiver in a UINavigationController with a styled nav bar and back and current-position bar
 * buttons.
 * @return The navigation controller, not self.
 * @ghidraAddress 0x85538
 */
- (id)initAtNavigationController __attribute__((objc_method_family(none)));

/**
 * @brief Fade the screen and its nav bar in over the GL scene.
 * @ghidraAddress 0x88838
 */
- (void)startOpenAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
