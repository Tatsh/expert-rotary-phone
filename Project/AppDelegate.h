/**
 * @file
 * The application delegate.
 *
 * It owns the main window and root view controller, brings up the game
 * engine at launch, drives the app lifecycle (resign/foreground/background/terminate), classifies
 * the device hardware and display class, manages the persistent device UUID and setting-version
 * Keychain records, bridges StoreKit purchases and Game Center, and builds the Core Data stack.
 */

#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
#import <UserNotifications/UserNotifications.h>
#endif

@class MainViewController, neWindow, CommonAlertView, SKProduct;

/**
 * The device display class the app lays out against, derived from the hardware model in
 * -initHardware and returned by the -displayType property. Ordered by screen class, not by iOS
 * device family.
 */
typedef NS_ENUM(NSInteger, DisplayType) {
    DisplayTypePhoneNonRetina = 0,  /**< 320x480 iPhone / iPod (1x). */
    DisplayTypePhoneRetina = 1,     /**< 640x960 iPhone / iPod, 3.5" (2x). */
    DisplayTypePhoneRetinaTall = 2, /**< 640x1136+ iPhone / iPod, 4"+ (2x tall). */
    DisplayTypePadNonRetina = 3,    /**< 1024x768 iPad (1x). */
    DisplayTypePadRetina = 4,       /**< 2048x1536 iPad (2x). */
    DisplayTypeUnknown = 5,         /**< Unrecognised model or simulator. */
};

/**
 * The application delegate for pop'n rhythmin.
 */
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>
#else
@interface AppDelegate : UIResponder <UIApplicationDelegate>
#endif

/**
 * The main window that hosts the game engine's render surface.
 */
@property(nonatomic, strong) neWindow *mainWindow;
/**
 * The root view controller driving the game's screens.
 */
@property(nonatomic, strong) MainViewController *viewController;
/**
 * The HTTP user-agent string sent with the app's network requests.
 * @ghidraAddress 0xa3a8
 */
@property(nonatomic, strong) NSString *userAgent;
/**
 * The human-readable device hardware model name.
 */
@property(nonatomic, strong) NSString *hardwareName;
/**
 * The alert shown when the device is low on storage. The name retains the binary's
 * misspelling of "storage" as it appears in the original binary.
 */
@property(nonatomic, strong) CommonAlertView *strageAlert;
/**
 * The timer that periodically polls for event information.
 */
@property(nonatomic, strong) NSTimer *getEventInfoTimer;
/**
 * The cached StoreKit products received from a products request.
 * @ghidraAddress 0xb0bc
 */
@property(atomic, strong, readonly) NSArray *products;
/**
 * The identifier of the reward app used for cross-promotion.
 * @ghidraAddress 0xb128
 */
@property(atomic, strong, readonly) NSString *rewardAppId;
/**
 * The active main game task.
 * @ghidraAddress 0xb0d0 (getter)
 * @ghidraAddress 0xb0e4 (setter)
 */
@property(atomic, assign) void *mainTask;
/**
 * The active AC-viewer main task.
 * @ghidraAddress 0xb0fc (getter)
 * @ghidraAddress 0xb110 (setter)
 */
@property(atomic, assign) void *acMainTask;
/**
 * The primary Core Data managed object context.
 */
@property(nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
/**
 * The secondary Core Data managed object context.
 */
@property(nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContextSub;
/**
 * The Core Data managed object model.
 */
@property(nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
/**
 * The Core Data persistent store coordinator.
 */
@property(nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
/**
 * The classified device display type derived from the hardware model.
 * @ghidraAddress 0xb0a8
 */
@property(atomic, assign, readonly) int displayType;

/**
 * The shared app delegate.
 * @return The delegate.
 * @ghidraAddress 0x89a0
 */
+ (instancetype)appDelegate;

/**
 * The app's Documents directory.
 * @return The directory path.
 * @ghidraAddress 0x89d4
 */
+ (NSString *)appDocumentsDirectory;

/**
 * The app's Application Support directory, lazily created and marked excluded from backup.
 * @return The directory path.
 * @ghidraAddress 0x8a1c
 */
+ (NSString *)appAppSupportDirectory;
#ifdef ENABLE_PATCHES
/**
 * The bundled @c assets/ subdirectory, or @c nil-safe path when absent.
 *
 * Preservation build only: an optional folder shipped inside the app bundle that pre-stages content
 * the original downloaded at runtime (chart @c .orb / @c .acv files and the @c mulist / @c acmulist
 * purchased-song lists). This only builds the path; callers check that it, or a specific file
 * within it, exists before using it, so a build that ships no @c assets folder is unaffected.
 *
 * @return The path to the @c assets subdirectory of the main bundle's resource path.
 */
+ (NSString *)appAssetsDirectory;

/**
 * Build a path to a file inside the bundled @c assets/ subdirectory.
 *
 * Preservation build only, and deliberately with no fallback: assets loaded through this
 * (@c bgm*.m4a, @c chara*.chr, @c rhythmin_lv, and the @c lock* / @c open* / @c result* / @c sgc_* /
 * @c sugo_* PNG families) resolve solely against @c assets/, so a self-contained build serves them
 * from the bundle rather than the original download locations.
 *
 * @param filename The bare file name to resolve under @c assets/.
 * @return The @c assets/ path for @p filename (whether or not the file exists).
 */
+ (NSString *)appAssetsPath:(NSString *)filename;
#endif

/**
 * Mark the item at @p URL as excluded from iCloud/iTunes backup.
 * @param URL The file URL to flag.
 * @return YES when the attribute was set.
 * @ghidraAddress 0x8af8
 */
+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL;

/**
 * The app's Caches directory.
 * @return The directory path.
 * @ghidraAddress 0x89f8
 */
+ (NSString *)appCachesDirectory;

/**
 * The number of free bytes on the file system backing the Documents directory.
 * @return The free byte count.
 * @ghidraAddress 0x8be8
 */
+ (unsigned long long)freeFileSystemSize;

/**
 * Classify the device via sysctl @c hw.machine into the hardware-type and display-type tiers.
 * @ghidraAddress 0xa58c
 */
- (void)initHardware;

/**
 * Whether the device is a low-spec model that should disable effects.
 * @return YES on a low-spec device.
 * @ghidraAddress 0xad5c
 */
- (BOOL)isOldHardware;

/**
 * The cached device-model hardware-type enum.
 * @return The hardware type.
 * @ghidraAddress 0xb13c
 */
- (int)hardwareType;

/**
 * Read, or mint and Keychain-store, the persistent device UUID.
 * @return The device UUID.
 * @ghidraAddress 0x9890
 */
- (NSString *)uuId;

/**
 * Remove the stored device UUID.
 * @ghidraAddress 0x9c20
 */
- (void)deleteUuid;

/**
 * Keychain add-or-update the setting-version record.
 * @param ver The setting version string to store.
 * @ghidraAddress 0x9d58
 */
- (void)setUsersettingVer:(NSString *)ver;

/**
 * Read the setting-version record.
 * @return The stored version, or `"0"` when absent.
 * @ghidraAddress 0xa044
 */
- (NSString *)getUsersettingVer;

/**
 * Remove the setting-version Keychain item.
 * @ghidraAddress 0xa270
 */
- (void)deleteUsersettingVer;

/**
 * The Info.plist @c CFBundleVersion with its dots stripped, as an integer.
 * @return The numeric version.
 * @ghidraAddress 0xa458
 */
- (int)appVersionNum;

/**
 * Retain the StoreKit products array received from a products request.
 * @param products The received StoreKit products.
 * @ghidraAddress 0xab44
 */
- (void)finishRequest:(NSArray *)products;

/**
 * Linear-search the cached StoreKit products for a matching product identifier.
 * @param productId The product identifier to match.
 * @return The matching product, or nil when it is not cached.
 * @ghidraAddress 0xacac
 */
- (SKProduct *)getProduct:(NSString *)productId;

/**
 * Show the global "purchase completed" confirmation alert.
 * @param transaction The completed transaction.
 * @ghidraAddress 0xab9c
 */
- (void)purchaseSucceeded:(id)transaction;

/**
 * Show the global "purchase failed" alert.
 * @param transaction The failed transaction.
 * @param error The failure error.
 * @ghidraAddress 0xac24
 */
- (void)purchaseFailed:(id)transaction error:(NSError *)error;

/**
 * Install the Game Center authenticate handler, presenting its login view controller.
 * @ghidraAddress 0xb00c
 */
- (void)loginGameCenter;

/**
 * The Info.plist @c CFBundleVersion string.
 * @return The version string.
 * @ghidraAddress 0xa408
 */
- (NSString *)appVersion;

/**
 * The device system version.
 * @return The system version string.
 * @ghidraAddress 0xa3d4
 */
- (NSString *)osVersion;

/**
 * The current locale's language code.
 * @return The language code.
 * @ghidraAddress 0xa548
 */
- (NSString *)localeLanguage;

/**
 * The current locale's country code.
 * @return The country code.
 * @ghidraAddress 0xa504
 */
- (NSString *)localeCountry;

/**
 * The current locale as `"language_country"`.
 * @return The locale string.
 * @ghidraAddress 0xa4a4
 */
- (NSString *)localeString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
