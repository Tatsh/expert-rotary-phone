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

@class MainViewController, neWindow, CommonAlertView, SKProduct;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

// Custom OpenGL-backed window (see Engine/neWindow).
@property (nonatomic, strong) neWindow *window;
@property (nonatomic, strong) MainViewController *viewController;

// HTTP User-Agent string, built once at launch:
//   "%@/%@ (%@; iOS %@; %@)"  =  "SHISHAMO MUSIC/<ver> (<model>; iOS <os>; <locale>)"
// The getter hands back a defensive copy of the backing string.
@property (nonatomic, strong) NSString *userAgent;      // getter @ 0xa3a8
@property (nonatomic, strong) NSString *hardwareName;

// Storage-space warning alert, shown when free space is too low.
@property (nonatomic, strong) CommonAlertView *strageAlert;

// Periodic timer that re-polls DownloadMain for event info.
@property (nonatomic, strong) NSTimer *getEventInfoTimer;

// StoreKit product list, delivered by PurchaseManager's finishRequest: callback.
@property (atomic, strong, readonly) NSArray *products;      // getter @ 0xb0bc

// Ad-reward app id (ad SDK removed; kept for structural parity — see .mm launch).
@property (atomic, strong, readonly) NSString *rewardAppId;  // getter @ 0xb128

// Engine play-task handles: standard mode (mainTask) and arcade "ac" mode
// (acMainTask). The play scene registers itself here at build and clears it
// when handing off to the result screen.
@property (atomic, assign) void *mainTask;      // getter @ 0xb0d0, setter @ 0xb0e4
@property (atomic, assign) void *acMainTask;    // getter @ 0xb0fc, setter @ 0xb110

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
+ (NSString *)appAppSupportDirectory;     // Application Support dir (downloadable data) @ 0x8a1c
// Exclude an existing item from iCloud/iTunes backup (NSURLIsExcludedFromBackupKey).
+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL;  // @ 0x8af8
+ (NSString *)appCachesDirectory;         // Caches dir (dev-data downloads) @ 0x89f8
+ (unsigned long long)freeFileSystemSize; // @ 0x... freeFileSystemSize

// Device model / capability probing.
- (void)initHardware;                     // -[AppDelegate initHardware] @ 0xa58c
- (BOOL)isOldHardware;                    // -[AppDelegate isOldHardware] @ 0xad5c
- (int)hardwareType;                      // -[AppDelegate hardwareType]  @ 0xb13c
// Rendering tier derived in initHardware (synthesized atomic getter).
@property (atomic, assign, readonly) int displayType; // getter @ 0xb0a8

// Persisted per-install identifier used in backend requests.
- (NSString *)uuId;                       // -[AppDelegate uuId]
- (void)deleteUuid;                       // -[AppDelegate deleteUuid] @ 0x9c20

// Settings-version record, stored as a keychain generic-password item keyed on
// account "UserSettingVer" (service = bundle id).
- (void)setUsersettingVer:(NSString *)ver; // @ 0x9d58
- (NSString *)getUsersettingVer;           // @ 0xa044  (returns @"0" when absent)
- (void)deleteUsersettingVer;              // @ 0xa270

// CFBundleVersion parsed to an int by stripping dots ("2.0.3" -> 203).
- (int)appVersionNum;                      // @ 0xa458

// StoreKit product handling.
- (void)finishRequest:(NSArray *)products; // @ 0xab44 (product list callback)
- (SKProduct *)getProduct:(NSString *)productId; // @ 0xacac

// PurchaseManager delegate callbacks (show a result alert).
- (void)purchaseSucceeded:(id)transaction;                     // @ 0xab9c
- (void)purchaseFailed:(id)transaction error:(NSError *)error; // @ 0xac24

// Game Center authentication.
- (void)loginGameCenter;                   // @ 0xb00c

// Environment strings sent in backend requests (receipt check, etc.).
- (NSString *)appVersion;                 // CFBundleVersion            @ 0xa408
- (NSString *)osVersion;                  // UIDevice.systemVersion     @ 0xa3d4
- (NSString *)localeLanguage;             // NSLocaleLanguageCode       @ 0xa548
- (NSString *)localeCountry;              // NSLocaleCountryCode        @ 0xa504
- (NSString *)localeString;               // "<language>_<country>"     @ 0xa4a4

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
