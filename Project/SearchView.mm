//
//  SearchView.mm
//  pop'n rhythmin
//
//  Objective-C++ because it drives the C++ engine bridge (neEngine / neSceneManager).
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Every method cites the
//  address it was decompiled from. ARC: the binary's manual retain/release/autorelease and
//  [super dealloc] are dropped; object stores are left to ARC.
//

#import "SearchView.h"

#import "MapAnnotation.h"        // the MKAnnotation dropped for each arcade
#import "Downloader.h"           // master + per-region request helpers
#import "ImageDownloader.h"      // marker-image loader
#import "DownloadMain.h"         // app download stack (shared networking headers)
#import "CommonAlertView.h"      // styled modal alert
#import "StoreUtil.h"            // +searchMasterURL / +searchURL / urlEncodeString
#import "MainViewController.h"   // -ArcadeSearchEndCallBack (nav host)
#import "AppFont.h"              // AppFontName() (== Ghidra getFontNameDFSoGei)

#import "neEngineBridge.h"       // neEngine::playSystemSe, neSceneManager::shared/rootViewController/isPadDisplay

#import <CoreLocation/CoreLocation.h>

// --- Recovered constants (little-endian doubles read straight out of the binary) ---

// Initial map region: central Tokyo. Ghidra DAT_00085ac0 (lat) / DAT_00085ab8 (lon) and the
// setRegion:animated: span literals.
static const CLLocationDegrees kInitialLatitude  = 35.6839;
static const CLLocationDegrees kInitialLongitude = 139.7744;
static const CLLocationDegrees kInitialLatDelta  = 0.01003;
static const CLLocationDegrees kInitialLonDelta  = 0.01158;

// The map must be zoomed in to at least this longitudeDelta before pins are shown; wider than
// this and the "zoom in" prompt appears instead. Ghidra DAT_00086e78 = 0.26.
static const CLLocationDegrees kMarkerSpanThreshold = 0.26;

// Loose Japan bounding box; the server is only re-queried while the map centre sits inside it.
// Ghidra DAT_00087080/88/90/98.
static const CLLocationDegrees kJPLatMin = 20.5;
static const CLLocationDegrees kJPLatMax = 45.6;
static const CLLocationDegrees kJPLonMin = 24.45;
static const CLLocationDegrees kJPLonMax = 153.0;

// Metres-per-degree divisor + degree threshold: re-query only after the centre has moved far
// enough. Ghidra DAT_000870a0 = 111132.0 / DAT_000870a8 = 0.15.
static const double kMetresPerDegree = 111132.0;
static const double kRequeryDegrees  = 0.15;

// mapRectForCoordinateRegion: expands the region's centre by ±span*0.6 to get the corner
// coordinates. Ghidra DAT_00086328 = 0.6.
static const double kRegionCornerFactor = 0.6;

// Animation timings. Ghidra: open 0.5 (0x3fe00000), close ~0.3 (DAT_00088a90), error fade 0.3
// (DAT_00086478).
static const NSTimeInterval kOpenAnimationDuration  = 0.5;
static const NSTimeInterval kCloseAnimationDuration = 0.3;
static const NSTimeInterval kErrorFadeDuration      = 0.3;

// --- Recovered UI strings (UTF-16LE CFStrings in the binary) ---
static NSString *const kSubtitleFormat        = @"営業時間: %@";                 // cf_UmiBf_ @ 0x12ca20
static NSString *const kNetworkErrorMessage   = @"サーバに接続できません。\nネットワーク接続をご確認下さい。"; // 0x136808
static NSString *const kServerErrorMessage    = @"サーバエラーが発生しました。\n後ほど再接続して下さい。";     // 0x136828
static NSString *const kOpenInMapsMessage     = @"この場所を\n『マップ』で開きますか?";                       // 0x1388e8
static NSString *const kLocationDisabledTitle = @"Information";                                              // 0x1388a8
static NSString *const kLocationDisabledText  = @"現在位置を表示するには\n「設定」アプリより\n位置情報サービスを\n『オン』にしてください"; // 0x1388b8
// These two localized UTF-16 CFStrings are now located and characterized (encoding + length
// verified via read_memory): the zoom prompt is the cfstringStruct @ 0x138868 (flags 0x7d0 =
// UTF-16, dataPtr 0x12c978, len 20) that viewDidLoad @ 0x85a58 sets on m_MessageLabel; the data
// error is cf_000k0c_g0M0_0_000, passed to -showError: on the master-feed parse-failure path
// @ 0x875a0. The literals below are faithful-meaning reconstructions of that functional UI text
// (2-line zoom-to-search hint / data-fetch-failure notice) and match the verified 20-unit length.
static NSString *const kZoomInPrompt          = @"地図を拡大すると\nゲームセンターを検索します";
static NSString *const kDataErrorMessage      = @"データの取得に失敗しました。";

// Private + class helpers not exposed in the header.
@interface SearchView ()
// YES when location services are on and this app is authorised. Ghidra: +currentLocationEnabled @ 0x86330.
+ (BOOL)currentLocationEnabled;
// MKMapRect covering `region` (± span * 0.6). Ghidra: +mapRectForCoordinateRegion: @ 0x86250.
+ (MKMapRect)mapRectForCoordinateRegion:(MKCoordinateRegion)region;

- (void)showError:(NSString *)message;
- (BOOL)gotoCurrentPosition;
- (void)startSearchMaster;
- (void)startGameCenter:(MKCoordinateRegion)region;
- (void)addIndicator;
- (void)subIndicator;
- (BOOL)downloadMarkImage;
- (void)onCurrentPosButton;
- (void)backButtonFunc;
- (void)startCloseAnimation;
- (void)endOpenAnimation;
- (void)endCloseAnimation;
@end

@implementation SearchView

// .cxx_construct @ 0x88b04 — compiler-emitted C++ ivar constructor; not hand-written.

// @ 0x85538 — wrap self in a styled UINavigationController and return it (see header).
- (id)initAtNavigationController {
    if (!(self = [super init])) {
        return nil;
    }

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self];

    // Nav bar background.
    UIImage *barImage = [UIImage imageNamed:@"set_nowpoint_navbar"];
    [self.navigationController.navigationBar setBackgroundImage:barImage
                                                  forBarMetrics:UIBarMetricsDefault];

    m_DictSpot = [[NSMutableDictionary alloc] initWithCapacity:0x40];
    m_LoadedMaster = NO;
    m_LoadedImages = NO;
    m_IndicatorCount = 0;

    // Left bar button: back (plays the close animation).
    UIImage *backImage = [UIImage imageNamed:@"navi_btn_back"];
    CGSize backSize = backImage ? backImage.size : CGSizeZero;
    UIButton *backButton = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, backSize.width, backSize.height)];
    [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
    [backButton addTarget:self
                   action:@selector(startCloseAnimation)
         forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:backButton];

    // Right bar button: jump to the user's current position.
    UIImage *posImage = [UIImage imageNamed:@"set_btnnowpoint"];
    CGSize posSize = posImage ? posImage.size : CGSizeZero;
    UIButton *posButton = [[UIButton alloc]
        initWithFrame:CGRectMake(0, 0, posSize.width, posSize.height)];
    [posButton setBackgroundImage:posImage forState:UIControlStateNormal];
    [posButton addTarget:self
                  action:@selector(onCurrentPosButton)
        forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithCustomView:posButton];

    return nav;
}

// @ 0x85888 — KEPT under ARC because it actively tears down live work: detaches the map
// delegate and cancels every in-flight download. ARC releases the ivars, so the object-only
// release lines and [super dealloc] are omitted.
- (void)dealloc {
    [m_Map setDelegate:nil];
    m_Map = nil;
    m_Indicator = nil;
    m_MessageLabel = nil;
    m_ErrorLabel = nil;
    [m_ListDownloader cancel];
    m_ListDownloader = nil;
    [m_MasterDownloader cancel];
    m_MasterDownloader = nil;
    if (m_ImageDownloader) {
        [m_ImageDownloader cancelDownload];
        m_ImageDownloader = nil;
    }
    m_Info = nil;
    m_Models = nil;
    m_ModelNameForArrayIndex = nil;
    m_DictSpot = nil;
    m_GoogleMapURL = nil;
}

// @ 0x85a58 — build the map, spinner and the two rounded overlay labels, then kick off the
// master download and try to centre on the user.
- (void)viewDidLoad {
    [super viewDidLoad];

    CGRect bounds = self.view ? self.view.bounds : CGRectZero;

    if (!m_Map) {
        m_Map = [[MKMapView alloc] initWithFrame:bounds];
    }
    // Fill the container on rotation (the binary calls a UIView "setAutoresizingAll" category
    // helper; inlined here as the equivalent full flexible mask to avoid a category seam).
    m_Map.autoresizingMask =
        UIViewAutoresizingFlexibleWidth  | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin  | UIViewAutoresizingFlexibleBottomMargin;
    [m_Map setShowsUserLocation:YES];
    [m_Map setDelegate:self];
    [self.view addSubview:m_Map];

    MKCoordinateRegion initialRegion = MKCoordinateRegionMake(
        CLLocationCoordinate2DMake(kInitialLatitude, kInitialLongitude),
        MKCoordinateSpanMake(kInitialLatDelta, kInitialLonDelta));
    [m_Map setRegion:initialRegion animated:NO];

    // Spinner (top-right-ish, ref-counted show/hide).
    if (!m_Indicator) {
        m_Indicator = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        m_Indicator.frame = CGRectMake(CGRectGetWidth(bounds) - 36.0f, 4.0f, 32.0f, 32.0f);
        m_Indicator.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        m_Indicator.hidesWhenStopped = YES;
        m_Indicator.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        m_Indicator.layer.cornerRadius = 4.0f;
    }
    m_IndicatorCount = 0;
    [self.view addSubview:m_Indicator];

    // "Zoom in to search" prompt (hidden until the map is zoomed out).
    if (!m_MessageLabel) {
        m_MessageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280.0f, 60.0f)];
        [m_MessageLabel setBounds:CGRectMake(0, 0, 280.0f, 60.0f)];
        m_MessageLabel.center = CGPointMake(CGRectGetWidth(bounds) * 0.5f, 70.0f);
        m_MessageLabel.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleBottomMargin;
        m_MessageLabel.opaque = NO;
        m_MessageLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
        m_MessageLabel.font = [UIFont fontWithName:AppFontName() size:18.0f];
        m_MessageLabel.numberOfLines = 2;
        m_MessageLabel.text = kZoomInPrompt;
        m_MessageLabel.textColor = [UIColor whiteColor];
        m_MessageLabel.textAlignment = NSTextAlignmentCenter;
        m_MessageLabel.layer.cornerRadius = 8.0f;
        m_MessageLabel.alpha = 0.0f;
    }
    [self.view addSubview:m_MessageLabel];

    // Error banner (hidden; fades in via -showError:). The binary picks a device-dependent
    // frame (phone vs pad) from the layout; reconstructed here as a centred banner.
    if (!m_ErrorLabel) {
        neSceneManager::shared();
        const BOOL isPad = neSceneManager::isPadDisplay();
        const CGFloat errWidth  = isPad ? 460.0f : 300.0f;
        const CGFloat errHeight = 40.0f;
        m_ErrorLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, errWidth, errHeight)];
        [m_ErrorLabel setBounds:CGRectMake(0, 0, errWidth, errHeight)];
        m_ErrorLabel.center = CGPointMake(CGRectGetWidth(bounds) * 0.5f,
                                          errHeight * 0.5f + 40.0f);
        m_ErrorLabel.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleBottomMargin;
        m_ErrorLabel.opaque = NO;
        m_ErrorLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
        m_ErrorLabel.font = [UIFont fontWithName:AppFontName() size:18.0f];
        m_ErrorLabel.numberOfLines = 2;
        m_ErrorLabel.text = @"";
        m_ErrorLabel.textColor = [UIColor whiteColor];
        m_ErrorLabel.textAlignment = NSTextAlignmentCenter;
        m_ErrorLabel.layer.cornerRadius = 8.0f;
        m_ErrorLabel.hidden = YES;
    }
    [self.view addSubview:m_ErrorLabel];

    [self startSearchMaster];
    [self gotoCurrentPosition];
}

// NOTE: -didReceiveMemoryWarning (@ 0x861f8) and -viewWillDisappear: (@ 0x86224) exist in the
// binary but only forward to super with no added behaviour, so they are intentionally omitted.

// @ 0x863a0 — set the error banner text and fade it in the first time it is shown.
- (void)showError:(NSString *)message {
    [m_ErrorLabel setText:message];
    if (m_ErrorLabel.isHidden) {
        m_ErrorLabel.alpha = 0.0f;
        m_ErrorLabel.hidden = NO;
        [UIView animateWithDuration:kErrorFadeDuration animations:^{
            m_ErrorLabel.alpha = 1.0f;
        }];
    }
}

// @ 0x864b8 — follow the user's location if location services are available.
- (BOOL)gotoCurrentPosition {
    if ([SearchView currentLocationEnabled]) {
        [m_Map setUserTrackingMode:MKUserTrackingModeFollow animated:YES];
        return YES;
    }
    return NO;
}

// @ 0x8650c — (re)start the master feed download.
- (void)startSearchMaster {
    m_LoadedMaster = NO;
    m_LoadedImages = NO;
    if (m_MasterDownloader) {
        [m_MasterDownloader cancel];
        m_MasterDownloader = nil;
    }
    m_MasterDownloader = [[Downloader alloc] initWithURL:[StoreUtil searchMasterURL]
                                                delegate:self];
    [m_MasterDownloader startDownloading];
    [self addIndicator];
}

// @ 0x865ec — POST the current region (lat/long/range) to fetch the arcades in view.
- (void)startGameCenter:(MKCoordinateRegion)region {
    if (!m_LoadedImages) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"lat=%.6f&long=%.6f&range=%.6f",
                      region.center.latitude, region.center.longitude,
                      region.span.latitudeDelta];
    [self addIndicator];
    if (m_ListDownloader) {
        [m_ListDownloader cancel];
        m_ListDownloader = nil;
    }
    m_ListDownloader = [[Downloader alloc]
        initWithURL:[StoreUtil searchURL]
           delegate:self
               Post:[body dataUsingEncoding:NSUTF8StringEncoding]
        ContextType:nil];
    m_LastRegion = region;
    [m_ListDownloader startDownloading];
}

// @ 0x867a4 — ref-counted spinner show.
- (void)addIndicator {
    int prev = m_IndicatorCount;
    m_IndicatorCount = prev + 1;
    if (prev < 0) {
        return;
    }
    [m_Indicator startAnimating];
}

// @ 0x867dc — ref-counted spinner hide.
- (void)subIndicator {
    int prev = m_IndicatorCount;
    m_IndicatorCount = prev - 1;
    if (m_IndicatorCount != 0 && prev > 0) {
        return;
    }
    [m_Indicator stopAnimating];
}

// @ 0x86810 — download the next per-model marker image that has not been fetched yet.
// Returns YES if a download was started (so the caller can wait for the callback).
- (BOOL)downloadMarkImage {
    for (NSMutableDictionary *model in m_Models) {
        if (![model objectForKey:@"IMAGE_OBJECT"]) {
            m_ImageDownloader = [[ImageDownloader alloc] init];
            [m_ImageDownloader setDelegate:self];
            [m_ImageDownloader setImageURL:[model objectForKey:@"Image"]];
            [m_ImageDownloader startDownload];
            [self addIndicator];
            return YES;
        }
    }
    return NO;
}

// @ 0x86990 — current-position bar button.
- (void)onCurrentPosButton {
    neEngine::playSystemSe(3);
    if (![self gotoCurrentPosition]) {
        CommonAlertView *alert = [[CommonAlertView alloc]
             initWithTitle:kLocationDisabledTitle
                   message:kLocationDisabledText
                  delegate:nil
         cancelButtonTitle:nil
         otherButtonTitles:@"OK"];
        [alert show];
    }
}

#pragma mark - MKMapViewDelegate

// @ 0x86a48 — super/no-op.
- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView {
}

// @ 0x86a4c — super/no-op.
- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView {
}

// @ 0x86a50 — super/no-op.
- (void)mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error {
}

// @ 0x86a54 — super/no-op.
- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
}

// @ 0x86a58 — the heart of the screen: as the region settles, prune off-screen pins, add the
// spots that came into view, and re-query the server when the map has panned far enough.
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    if (!m_LoadedImages) {
        return;
    }

    MKCoordinateRegion region =
        MKCoordinateRegionMake(CLLocationCoordinate2DMake(0, 0), MKCoordinateSpanMake(0, 0));
    if (m_Map) {
        region = m_Map.region;
    }
    MKMapRect visibleRect = [SearchView mapRectForCoordinateRegion:region];

    if (region.span.longitudeDelta <= kMarkerSpanThreshold) {
        m_MessageLabel.alpha = 0.0f;

        // Drop any pin that has scrolled out of the visible rect (never the user dot).
        for (id<MKAnnotation> annotation in m_Map.annotations) {
            if (m_Map.userLocation == annotation) {
                continue;
            }
            MKMapPoint point = MKMapPointForCoordinate(annotation.coordinate);
            if (!MKMapRectContainsPoint(visibleRect, point)) {
                [m_Map removeAnnotation:annotation];
            }
        }

        // Add the known spots that fall inside the visible rect.
        NSMutableArray *toAdd = [NSMutableArray arrayWithCapacity:0];
        for (id key in m_DictSpot) {
            id<MKAnnotation> annotation = [m_DictSpot objectForKey:key];
            if (!annotation) {
                continue;
            }
            MKMapPoint point = MKMapPointForCoordinate(annotation.coordinate);
            if (MKMapRectContainsPoint(visibleRect, point)) {
                [toAdd addObject:annotation];
            }
        }
        if (toAdd.count) {
            [m_Map addAnnotations:toAdd];
        }

        // Re-query the server only while inside Japan and after moving far enough.
        if (region.center.latitude  > kJPLatMin && region.center.latitude  < kJPLatMax &&
            region.center.longitude > kJPLonMin && region.center.longitude < kJPLonMax) {
            CLLocation *last = [[CLLocation alloc]
                initWithLatitude:m_LastRegion.center.latitude
                       longitude:m_LastRegion.center.longitude];
            CLLocation *now = [[CLLocation alloc]
                initWithLatitude:region.center.latitude
                       longitude:region.center.longitude];
            CLLocationDistance distance = [last distanceFromLocation:now];
            if (distance / kMetresPerDegree > kRequeryDegrees) {
                [self startGameCenter:region];
            }
        }
    } else {
        // Zoomed out too far: strip every pin (except the user dot) and show the prompt.
        for (id<MKAnnotation> annotation in m_Map.annotations) {
            if (m_Map.userLocation != annotation) {
                [m_Map removeAnnotation:annotation];
            }
        }
        m_MessageLabel.alpha = 1.0f;
    }
}

// @ 0x870b0 — supply the pin view (custom marker image + detail-disclosure callout button).
- (MKAnnotationView *)mapView:(MKMapView *)mapView
            viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;   // let the map draw the user dot
    }

    NSString *model = [(MapAnnotation *)annotation modelName];
    MKAnnotationView *view =
        [mapView dequeueReusableAnnotationViewWithIdentifier:model];
    if (view) {
        [view setAnnotation:annotation];
        return view;
    }

    view = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:model];

    // Resolve the marker image: this model's master image, else the "sunny" fallback.
    UIImage *image = nil;
    NSNumber *index = [m_ModelNameForArrayIndex objectForKey:model];
    if (index && [index integerValue] < (NSInteger)m_Models.count) {
        NSDictionary *entry = [m_Models objectAtIndex:[index integerValue]];
        UIImage *markImage = [entry objectForKey:@"IMAGE_OBJECT"];
        if (markImage) {
            image = markImage;
        }
    }
    if (!image) {
        image = [UIImage imageNamed:@"sear_icon_sunny.png"];
    }
    [view setImage:image];

    // Anchor the image's bottom edge on the coordinate.
    CGFloat offsetY = image ? (image.size.height * -0.5f) : 0.0f;
    [view setCenterOffset:CGPointMake(0, offsetY)];
    [view setCalloutOffset:CGPointMake(0, 0)];
    [view setCanShowCallout:YES];
    [view setRightCalloutAccessoryView:[UIButton buttonWithType:UIButtonTypeDetailDisclosure]];
    return view;
}

// @ 0x87318 — callout accessory tapped: build the Maps URL and confirm before opening.
- (void)mapView:(MKMapView *)mapView
     annotationView:(MKAnnotationView *)view
    calloutAccessoryControlTapped:(UIControl *)control {
    m_GoogleMapURL = nil;

    id<MKAnnotation> annotation = view.annotation;
    CLLocationCoordinate2D coordinate =
        annotation ? annotation.coordinate : CLLocationCoordinate2DMake(0, 0);
    NSString *title = view.annotation.title;
    m_GoogleMapURL = [[NSString alloc]
        initWithFormat:@"http://map.google.com/maps?q=%0.6f,%0.6f+(%@)",
                       coordinate.latitude, coordinate.longitude, urlEncodeString(title)];

    NSString *cancel = [[NSBundle mainBundle] localizedStringForKey:@"Cancel" value:@"" table:nil];
    NSString *ok = [[NSBundle mainBundle] localizedStringForKey:@"OK" value:@"" table:nil];
    CommonAlertView *alert = [[CommonAlertView alloc]
         initWithTitle:view.annotation.title
               message:kOpenInMapsMessage
              delegate:self
     cancelButtonTitle:cancel
     otherButtonTitles:ok];
    [alert show];
}

#pragma mark - CommonAlertViewDelegate

// @ 0x87520 — the "open in Maps?" confirm: index 1 (other/OK) opens the stored URL.
- (void)commonAlertView:(CommonAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (index != 1) {
        return;
    }
    if (m_Map) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:m_GoogleMapURL]];
    }
}

#pragma mark - DownloaderDelegate

// @ 0x875a0 — completion for both the arcade-list and the master feeds.
- (void)downloaderFinished:(Downloader *)downloader {
    if (m_ListDownloader == downloader) {
        // --- Per-region arcade list ---
        NSDictionary *json = [downloader getDataInJSON];
        if (json) {
            NSMutableArray *toAdd = [NSMutableArray arrayWithCapacity:0];
            id list = [json objectForKey:@"GameCenterList"];
            if ([list isKindOfClass:[NSArray class]]) {
                MKCoordinateRegion region = MKCoordinateRegionMake(
                    CLLocationCoordinate2DMake(0, 0), MKCoordinateSpanMake(0, 0));
                if (m_Map) {
                    region = m_Map.region;
                }
                MKMapRect visibleRect = [SearchView mapRectForCoordinateRegion:region];

                for (id item in list) {
                    if (![item isKindOfClass:[NSDictionary class]]) {
                        continue;
                    }
                    id arcadeId = [item objectForKey:@"ID"];
                    id lat      = [item objectForKey:@"Lat"];
                    id lng      = [item objectForKey:@"Long"];
                    id name     = [item objectForKey:@"Name"];
                    id open     = [item objectForKey:@"Open"];
                    id models   = [item objectForKey:@"Model"];
                    if (![arcadeId isKindOfClass:[NSNumber class]] ||
                        ![lat      isKindOfClass:[NSNumber class]] ||
                        ![lng      isKindOfClass:[NSNumber class]] ||
                        ![name     isKindOfClass:[NSString class]] ||
                        ![open     isKindOfClass:[NSString class]] ||
                        ![models   isKindOfClass:[NSArray class]]) {
                        continue;
                    }
                    if ([m_DictSpot objectForKey:arcadeId]) {
                        continue;   // already have this arcade
                    }
                    if ([models count] == 0) {
                        continue;
                    }

                    // Pick the marker model: the arcade's model with the lowest master index
                    // (falls back to its first string model).
                    NSString *markModel = nil;
                    NSInteger best = INT_MAX;
                    for (id candidate in models) {
                        if (![candidate isKindOfClass:[NSString class]]) {
                            continue;
                        }
                        if (!markModel) {
                            markModel = candidate;
                        }
                        NSNumber *idx = [m_ModelNameForArrayIndex objectForKey:candidate];
                        if (idx && [idx integerValue] < best) {
                            best = [idx intValue];
                            markModel = candidate;
                        }
                    }

                    CLLocationCoordinate2D coordinate =
                        CLLocationCoordinate2DMake([lat doubleValue], [lng doubleValue]);
                    MapAnnotation *annotation = [[MapAnnotation alloc]
                        initWithCoordinate:coordinate
                                     Title:name
                                  SubTitle:[NSString stringWithFormat:kSubtitleFormat, open]
                                     Model:markModel];
                    [m_DictSpot setObject:annotation forKey:arcadeId];

                    MKMapPoint point = MKMapPointForCoordinate(coordinate);
                    if (MKMapRectContainsPoint(visibleRect, point)) {
                        [toAdd addObject:annotation];
                    }
                }
            }
            if (toAdd.count) {
                [m_Map addAnnotations:toAdd];
            }
        }
        m_ListDownloader = nil;
    } else if (m_MasterDownloader == downloader) {
        // --- Master feed: version gate + marker/model metadata ---
        NSDictionary *json = [downloader getDataInJSON];
        if (!json) {
            [self showError:kDataErrorMessage];
        } else {
            id version = [json objectForKey:@"Version"];
            NSString *appVersion =
                [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
            if (![version isKindOfClass:[NSString class]]) {
                [self showError:kDataErrorMessage];
            } else if (!appVersion ||
                       [appVersion compare:version options:NSNumericSearch] == NSOrderedAscending) {
                // App older than the master's required version.
                [self showError:@""];
            } else {
                id info = [json objectForKey:@"Info"];
                id mark = [json objectForKey:@"Mark"];
                if (![info isKindOfClass:[NSString class]] ||
                    ![mark isKindOfClass:[NSArray class]]) {
                    [self showError:kDataErrorMessage];
                } else {
                    m_Info = [[NSMutableDictionary alloc] initWithCapacity:0];
                    [m_Info setObject:[NSString stringWithString:info] forKey:@"Image"];

                    m_Models = [[NSMutableArray alloc] initWithCapacity:0];
                    for (id item in mark) {
                        if (![item isKindOfClass:[NSDictionary class]]) {
                            continue;
                        }
                        id order = [item objectForKey:@"Order"];
                        id model = [item objectForKey:@"Model"];
                        id name  = [item objectForKey:@"Name"];
                        id image = [item objectForKey:@"Image"];
                        if ([order isKindOfClass:[NSString class]] &&
                            [model isKindOfClass:[NSString class]] &&
                            [name  isKindOfClass:[NSString class]] &&
                            [image isKindOfClass:[NSString class]]) {
                            [m_Models addObject:[NSMutableDictionary
                                dictionaryWithObjectsAndKeys:order, @"Order",
                                                             model, @"Model",
                                                             name,  @"Name",
                                                             image, @"Image", nil]];
                        }
                    }

                    // modelName -> array index lookup table.
                    m_ModelNameForArrayIndex = [[NSMutableDictionary alloc] initWithCapacity:0];
                    for (NSUInteger i = 0; i < m_Models.count; i++) {
                        NSString *model = [[m_Models objectAtIndex:i] objectForKey:@"Model"];
                        [m_ModelNameForArrayIndex setObject:[NSNumber numberWithInt:(int)i]
                                                     forKey:model];
                    }

                    if (m_ImageDownloader) {
                        [m_ImageDownloader cancelDownload];
                        m_ImageDownloader = nil;
                    }

                    NSString *masterImageURL = [m_Info objectForKey:@"Image"];
                    if (!masterImageURL) {
                        [self showError:kServerErrorMessage];
                    } else if ([masterImageURL length] == 0) {
                        [self downloadMarkImage];
                    } else {
                        m_ImageDownloader = [[ImageDownloader alloc] init];
                        [m_ImageDownloader setDelegate:self];
                        [m_ImageDownloader setImageURL:masterImageURL];
                        [m_ImageDownloader startDownload];
                        [self addIndicator];
                    }
                    m_LoadedMaster = YES;
                }
            }
        }
        m_MasterDownloader = nil;
    }
    [self subIndicator];
}

// @ 0x8830c — download failure for either feed.
- (void)downloaderError:(Downloader *)downloader {
    if (m_ListDownloader == downloader) {
        m_ListDownloader = nil;
    } else if (m_MasterDownloader == downloader) {
        m_MasterDownloader = nil;
        [self showError:kNetworkErrorMessage];
    }
    [self subIndicator];
}

#pragma mark - ImageDownloaderDelegate

// @ 0x88398 — a marker image finished: store it, then fetch the next pending one, or, when
// everything is loaded, flip m_LoadedImages and do the first region query.
- (void)imageDownloader:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    UIImage *image = [downloader getImage];
    NSString *url = [downloader imageURL];
    NSString *masterImageURL = [m_Info objectForKey:@"Image"];

    if (!image) {
        m_ImageDownloader = nil;
        [self showError:kNetworkErrorMessage];
    } else {
        if ([masterImageURL isEqual:url]) {
            [m_Info setObject:image forKey:@"IMAGE_OBJECT"];
        } else {
            for (NSMutableDictionary *model in m_Models) {
                if ([[model objectForKey:@"Image"] isEqual:url]) {
                    [model setObject:image forKey:@"IMAGE_OBJECT"];
                    break;
                }
            }
        }
        m_ImageDownloader = nil;

        if ([masterImageURL length] != 0 && ![m_Info objectForKey:@"IMAGE_OBJECT"]) {
            // Master image still pending -> fetch it next.
            m_ImageDownloader = [[ImageDownloader alloc] init];
            [m_ImageDownloader setDelegate:self];
            [m_ImageDownloader setImageURL:[m_Info objectForKey:@"Image"]];
            [m_ImageDownloader startDownload];
            [self addIndicator];
        } else if (![self downloadMarkImage]) {
            // Everything loaded: enable searching and run the first query.
            m_LoadedImages = YES;
            MKCoordinateRegion region = MKCoordinateRegionMake(
                CLLocationCoordinate2DMake(0, 0), MKCoordinateSpanMake(0, 0));
            if (m_Map) {
                region = m_Map.region;
            }
            [self startGameCenter:region];
        }
    }
    [self subIndicator];
}

// @ 0x88740 — a marker image failed.
- (void)imageDownloaderDidFail:(ImageDownloader *)downloader didLoad:(NSIndexPath *)indexPath {
    m_ImageDownloader = nil;
    [self showError:kNetworkErrorMessage];
    [self subIndicator];
}

#pragma mark - Navigation / animation

// @ 0x8879c — restore the settings nav bar and pop back.
- (void)backButtonFunc {
    neEngine::playSystemSe(2);
    [self.navigationController.navigationBar
        setBackgroundImage:[UIImage imageNamed:@"settings_navbar"]
             forBarMetrics:UIBarMetricsDefault];
    [self.navigationController popViewControllerAnimated:YES];
}

// @ 0x88838 — fade the screen + nav bar in.
- (void)startOpenAnimation {
    if (m_IsAnimationing) {
        return;
    }
    m_IsAnimationing = YES;
    self.view.alpha = 0.0f;
    self.navigationController.view.alpha = 0.0f;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:kOpenAnimationDuration];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endOpenAnimation)];
    self.view.alpha = 1.0f;
    self.navigationController.view.alpha = 1.0f;
    [UIView commitAnimations];
}

// @ 0x88964 — open animation done.
- (void)endOpenAnimation {
    m_IsAnimationing = NO;
}

// @ 0x88978 — fade the screen + nav bar out. (The binary clears m_IsAnimationing here.)
- (void)startCloseAnimation {
    if (m_IsAnimationing) {
        return;
    }
    m_IsAnimationing = NO;
    neEngine::playSystemSe(2);
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:kCloseAnimationDuration];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(endCloseAnimation)];
    self.view.alpha = 0.0f;
    self.navigationController.view.alpha = 0.0f;
    [UIView commitAnimations];
}

// @ 0x88a98 — close animation done: detach and notify the nav host.
- (void)endCloseAnimation {
    [self.navigationController.view removeFromSuperview];
    neSceneManager::shared();
    MainViewController *root = (MainViewController *)neSceneManager::rootViewController();
    [root ArcadeSearchEndCallBack];
    m_IsAnimationing = NO;
}

#pragma mark - Class helpers

// @ 0x86330 — YES when location services are on and this app is authorised (or the OS predates
// +authorizationStatus).
+ (BOOL)currentLocationEnabled {
    if (![CLLocationManager locationServicesEnabled]) {
        return NO;
    }
    if ([CLLocationManager respondsToSelector:@selector(authorizationStatus)]) {
        return [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized;
    }
    return YES;
}

// @ 0x86250 — MKMapRect enclosing `region`, expanded to ± span * 0.6 around the centre.
+ (MKMapRect)mapRectForCoordinateRegion:(MKCoordinateRegion)region {
    CLLocationCoordinate2D topLeft = CLLocationCoordinate2DMake(
        region.center.latitude  + region.span.latitudeDelta  * kRegionCornerFactor,
        region.center.longitude - region.span.longitudeDelta * kRegionCornerFactor);
    CLLocationCoordinate2D bottomRight = CLLocationCoordinate2DMake(
        region.center.latitude  - region.span.latitudeDelta  * kRegionCornerFactor,
        region.center.longitude + region.span.longitudeDelta * kRegionCornerFactor);

    MKMapPoint a = MKMapPointForCoordinate(topLeft);
    MKMapPoint b = MKMapPointForCoordinate(bottomRight);
    return MKMapRectMake(a.x, a.y, fabs(b.x - a.x), fabs(b.y - a.y));
}

@end

// kate: hl Objective-C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objcpp sw=4 ts=4 et :
// code: language=Objective-C++ insertSpaces=true tabSize=4
