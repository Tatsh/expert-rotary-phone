//
//  AppDelegate.h
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Class: AppDelegate (UIApplicationDelegate). Owns the window, the root
//  MainViewController, the app's Core Data stack (main + a secondary "sub"
//  context sharing one persistent store coordinator), and app-wide lifecycle.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class MainViewController, neWindow, CommonAlertView;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

// Custom OpenGL-backed window (see Engine/neWindow).
@property (nonatomic, strong) neWindow *window;
@property (nonatomic, strong) MainViewController *viewController;

// HTTP User-Agent string, built once at launch:
//   "%@/%@ (%@; iOS %@; %@)"  =  "SHISHAMO MUSIC/<ver> (<model>; iOS <os>; <locale>)"
@property (nonatomic, strong) NSString *userAgent;
@property (nonatomic, strong) NSString *hardwareName;

// Storage-space warning alert, shown when free space is too low.
@property (nonatomic, strong) CommonAlertView *strageAlert;

// Periodic timer that re-polls DownloadMain for event info.
@property (nonatomic, strong) NSTimer *getEventInfoTimer;

// Core Data stack. `managedObjectContextSub` is a second context on the same
// coordinator, used for background/secondary work.
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContextSub;
@property (nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

// Convenience accessor for the shared delegate instance.  @ 0x... (thunk PTR_s_appDelegate)
+ (instancetype)appDelegate;

// Documents directory + free-space helpers (class methods).
+ (NSString *)appDocumentsDirectory;      // Ghidra: -[AppDelegate appDocumentsDirectory] (class method)
+ (unsigned long long)freeFileSystemSize; // @ 0x... freeFileSystemSize

// Device model / capability probing.
- (void)initHardware;                     // -[AppDelegate initHardware] @ 0xa58c
- (BOOL)isOldHardware;                    // -[AppDelegate isOldHardware] @ 0xad5c
- (int)hardwareType;                      // -[AppDelegate hardwareType]  @ 0xb13c
- (int)displayType;                       // display tier derived in initHardware

// Persisted per-install identifier used in backend requests.
- (NSString *)uuId;                       // -[AppDelegate uuId]

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
