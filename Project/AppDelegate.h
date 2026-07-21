/** @file
 * The application delegate: owns the main window and root view controller, brings up the game
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
 * @brief The device display class the app lays out against, derived from the hardware model in
 * -initHardware and returned by the -displayType property. Ordered by screen class, not by iOS
 * device family.
 */
typedef NS_ENUM(NSInteger, DisplayType) {
    DisplayTypePhoneNonRetina = 0,  ///< 320x480 iPhone / iPod (1x)
    DisplayTypePhoneRetina = 1,     ///< 640x960 iPhone / iPod, 3.5" (2x)
    DisplayTypePhoneRetinaTall = 2, ///< 640x1136+ iPhone / iPod, 4"+ (2x tall)
    DisplayTypePadNonRetina = 3,    ///< 1024x768 iPad (1x)
    DisplayTypePadRetina = 4,       ///< 2048x1536 iPad (2x)
    DisplayTypeUnknown = 5,         ///< unrecognised model / simulator
};

/**
 * @brief The application delegate for pop'n rhythmin.
 */
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>
#else
@interface AppDelegate : UIResponder <UIApplicationDelegate>
#endif

/**
 * @brief The main window that hosts the game engine's render surface.
 */
@property(nonatomic, strong) neWindow *mainWindow;
/**
 * @brief The root view controller driving the game's screens.
 */
@property(nonatomic, strong) MainViewController *viewController;
/**
 * @brief The HTTP user-agent string sent with the app's network requests.
 * @ghidraAddress 0xa3a8
 */
@property(nonatomic, strong) NSString *userAgent;
/**
 * @brief The human-readable device hardware model name.
 */
@property(nonatomic, strong) NSString *hardwareName;
/**
 * @brief The alert shown when the device is low on storage. The name retains the binary's
 * misspelling of "storage" as it appears in the original binary.
 */
@property(nonatomic, strong) CommonAlertView *strageAlert;
/**
 * @brief The timer that periodically polls for event information.
 */
@property(nonatomic, strong) NSTimer *getEventInfoTimer;
/**
 * @brief The cached StoreKit products received from a products request.
 * @ghidraAddress 0xb0bc
 */
@property(atomic, strong, readonly) NSArray *products;
/**
 * @brief The identifier of the reward app used for cross-promotion.
 * @ghidraAddress 0xb128
 */
@property(atomic, strong, readonly) NSString *rewardAppId;
/**
 * @brief The active main game task.
 * @ghidraAddress 0xb0d0 (getter)
 * @ghidraAddress 0xb0e4 (setter)
 */
@property(atomic, assign) void *mainTask;
/**
 * @brief The active AC-viewer main task.
 * @ghidraAddress 0xb0fc (getter)
 * @ghidraAddress 0xb110 (setter)
 */
@property(atomic, assign) void *acMainTask;
/**
 * @brief The primary Core Data managed object context.
 */
@property(nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
/**
 * @brief The secondary Core Data managed object context.
 */
@property(nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContextSub;
/**
 * @brief The Core Data managed object model.
 */
@property(nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
/**
 * @brief The Core Data persistent store coordinator.
 */
@property(nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
/**
 * @brief The classified device display type derived from the hardware model.
 * @ghidraAddress 0xb0a8
 */
@property(atomic, assign, readonly) int displayType;

/**
 * @brief The shared app delegate.
 * @ghidraAddress 0x89a0
 */
+ (instancetype)appDelegate;

/**
 * @brief The app's Documents directory.
 * @ghidraAddress 0x89d4
 */
+ (NSString *)appDocumentsDirectory;

/**
 * @brief The app's Application Support directory, lazily created and marked excluded from backup.
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
 * @brief Build a path to a file inside the bundled @c assets/ subdirectory.
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
 * @brief Mark the item at @p URL as excluded from iCloud/iTunes backup.
 * @param URL The file URL to flag.
 * @ghidraAddress 0x8af8
 */
+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL;

/**
 * @brief The app's Caches directory.
 * @ghidraAddress 0x89f8
 */
+ (NSString *)appCachesDirectory;

/**
 * @brief The number of free bytes on the file system backing the Documents directory.
 * @ghidraAddress 0x8be8
 */
+ (unsigned long long)freeFileSystemSize;

/**
 * @brief Classify the device via sysctl @c hw.machine into the hardware-type and display-type tiers.
 * @ghidraAddress 0xa58c
 */
- (void)initHardware;

/**
 * @brief Whether the device is a low-spec model that should disable effects.
 * @ghidraAddress 0xad5c
 */
- (BOOL)isOldHardware;

/**
 * @brief The cached device-model hardware-type enum.
 * @ghidraAddress 0xb13c
 */
- (int)hardwareType;

/**
 * @brief Read, or mint and Keychain-store, the persistent device UUID.
 * @ghidraAddress 0x9890
 */
- (NSString *)uuId;

/**
 * @brief Remove the stored device UUID.
 * @ghidraAddress 0x9c20
 */
- (void)deleteUuid;

/**
 * @brief Keychain add-or-update the setting-version record.
 * @param ver The setting version string to store.
 * @ghidraAddress 0x9d58
 */
- (void)setUsersettingVer:(NSString *)ver;

/**
 * @brief Read the setting-version record, returning @c "0" when absent.
 * @ghidraAddress 0xa044
 */
- (NSString *)getUsersettingVer;

/**
 * @brief Remove the setting-version Keychain item.
 * @ghidraAddress 0xa270
 */
- (void)deleteUsersettingVer;

/**
 * @brief The Info.plist @c CFBundleVersion with its dots stripped, as an integer.
 * @ghidraAddress 0xa458
 */
- (int)appVersionNum;

/**
 * @brief Retain the StoreKit products array received from a products request.
 * @param products The received StoreKit products.
 * @ghidraAddress 0xab44
 */
- (void)finishRequest:(NSArray *)products;

/**
 * @brief Linear-search the cached StoreKit products for a matching product identifier.
 * @param productId The product identifier to match.
 * @ghidraAddress 0xacac
 */
- (SKProduct *)getProduct:(NSString *)productId;

/**
 * @brief Show the global "purchase completed" confirmation alert.
 * @param transaction The completed transaction.
 * @ghidraAddress 0xab9c
 */
- (void)purchaseSucceeded:(id)transaction;

/**
 * @brief Show the global "purchase failed" alert.
 * @param transaction The failed transaction.
 * @param error The failure error.
 * @ghidraAddress 0xac24
 */
- (void)purchaseFailed:(id)transaction error:(NSError *)error;

/**
 * @brief Install the Game Center authenticate handler, presenting its login view controller.
 * @ghidraAddress 0xb00c
 */
- (void)loginGameCenter;

/**
 * @brief The Info.plist @c CFBundleVersion string.
 * @ghidraAddress 0xa408
 */
- (NSString *)appVersion;

/**
 * @brief The device system version.
 * @ghidraAddress 0xa3d4
 */
- (NSString *)osVersion;

/**
 * @brief The current locale's language code.
 * @ghidraAddress 0xa548
 */
- (NSString *)localeLanguage;

/**
 * @brief The current locale's country code.
 * @ghidraAddress 0xa504
 */
- (NSString *)localeCountry;

/**
 * @brief The current locale as @c "language_country".
 * @ghidraAddress 0xa4a4
 */
- (NSString *)localeString;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
