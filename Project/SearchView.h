//
//  SearchView.h
//  pop'n rhythmin
//
//  The arcade-locator ("game center" search) screen: a full-screen MKMapView that
//  drops a pin for every nearby arcade. It first downloads a "master" feed (the pin
//  marker images + per-model metadata), then, as the visible region changes, POSTs the
//  current lat/long/range to the server and adds/removes annotations for the arcades in
//  view. Tapping a pin's callout offers to open the location in the Maps app. Hosted
//  inside its own UINavigationController, presented over the GL scene by
//  MainViewController -GotoArcadeSearch. Reconstructed from Ghidra project rb420,
//  program PopnRhythmin (SearchView @ 0x85538..0x88a98, class methods
//  +mapRectForCoordinateRegion: @ 0x86250 / +currentLocationEnabled @ 0x86330).
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

#import "Downloader.h"        // DownloaderDelegate + Downloader ivars
#import "ImageDownloader.h"   // ImageDownloaderDelegate + ImageDownloader ivar
#import "CommonAlertView.h"   // CommonAlertViewDelegate

@interface SearchView : UIViewController <MKMapViewDelegate,
                                          DownloaderDelegate,
                                          ImageDownloaderDelegate,
                                          CommonAlertViewDelegate> {
    // The map filling the screen; user-location dot + arcade pins are drawn on it.
    MKMapView *m_Map;
    // A small spinner shown while any download is in flight (ref-counted by m_IndicatorCount).
    UIActivityIndicatorView *m_Indicator;
    int m_IndicatorCount;
    // Rounded translucent label shown when the map is zoomed out too far to search.
    UILabel *m_MessageLabel;
    // Rounded translucent label used to surface network / server errors (fades in).
    UILabel *m_ErrorLabel;
    // The two request helpers: the master feed and the per-region arcade query.
    Downloader *m_MasterDownloader;
    Downloader *m_ListDownloader;
    // Loads the master + per-model marker images one at a time.
    ImageDownloader *m_ImageDownloader;
    // Master feed's top-level info (holds the master marker image URL + decoded image).
    NSMutableDictionary *m_Info;
    // Per-model marker metadata array ({Order,Model,Name,Image,IMAGE_OBJECT}).
    NSMutableArray *m_Models;
    // modelName -> index into m_Models (drives per-pin marker image lookup).
    NSMutableDictionary *m_ModelNameForArrayIndex;
    // The region last sent to the server (used to decide when to re-query on pan).
    MKCoordinateRegion m_LastRegion;
    // arcade ID -> MapAnnotation for every arcade seen so far.
    NSMutableDictionary *m_DictSpot;
    // The Maps-app URL built for the pin whose callout was tapped.
    NSString *m_GoogleMapURL;
    // Master feed loaded / all marker images loaded / open|close animation running.
    BOOL m_LoadedMaster;
    BOOL m_LoadedImages;
    BOOL m_IsAnimationing;
}

// Designated entry point used by MainViewController -GotoArcadeSearch: runs [super init],
// wraps the receiver in a UINavigationController (styled nav bar + back / current-position
// bar buttons) and returns that navigation controller. Ghidra: @ 0x85538.
- (id)initAtNavigationController;

// Fade the screen (and nav bar) in over the GL scene. Ghidra: @ 0x88838.
- (void)startOpenAnimation;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
