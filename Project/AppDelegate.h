//
//  AppDelegate.h
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
#import <UserNotifications/UserNotifications.h>
#endif

@class MainViewController, neWindow, CommonAlertView, SKProduct;

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>
#else
@interface AppDelegate : UIResponder <UIApplicationDelegate>
#endif

@property(nonatomic, strong) neWindow *mainWindow;
@property(nonatomic, strong) MainViewController *viewController;
@property(nonatomic, strong) NSString *userAgent; // getter @ 0xa3a8
@property(nonatomic, strong) NSString *hardwareName;
@property(nonatomic, strong) CommonAlertView *strageAlert;
@property(nonatomic, strong) NSTimer *getEventInfoTimer;
@property(atomic, strong, readonly) NSArray *products;     // getter @ 0xb0bc
@property(atomic, strong, readonly) NSString *rewardAppId; // getter @ 0xb128
@property(atomic, assign) void *mainTask;                  // getter @ 0xb0d0, setter @ 0xb0e4
@property(atomic, assign) void *acMainTask;                // getter @ 0xb0fc, setter @ 0xb110
@property(nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
@property(nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContextSub;
@property(nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
@property(nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property(atomic, assign, readonly) int displayType; // getter @ 0xb0a8

+ (instancetype)appDelegate;                            // @ 0x89a0
+ (NSString *)appDocumentsDirectory;                    // @ 0x89d4
+ (NSString *)appAppSupportDirectory;                   // @ 0x8a1c
+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL; // @ 0x8af8
+ (NSString *)appCachesDirectory;                       // @ 0x89f8
+ (unsigned long long)freeFileSystemSize;               // @ 0x8be8

- (void)initHardware;  // @ 0xa58c
- (BOOL)isOldHardware; // @ 0xad5c
- (int)hardwareType;   // @ 0xb13c

- (NSString *)uuId; // @ 0x9890
- (void)deleteUuid; // @ 0x9c20

- (void)setUsersettingVer:(NSString *)ver; // @ 0x9d58
- (NSString *)getUsersettingVer;           // @ 0xa044
- (void)deleteUsersettingVer;              // @ 0xa270

- (int)appVersionNum; // @ 0xa458

- (void)finishRequest:(NSArray *)products;       // @ 0xab44
- (SKProduct *)getProduct:(NSString *)productId; // @ 0xacac

- (void)purchaseSucceeded:(id)transaction;                     // @ 0xab9c
- (void)purchaseFailed:(id)transaction error:(NSError *)error; // @ 0xac24

- (void)loginGameCenter; // @ 0xb00c

- (NSString *)appVersion;     // @ 0xa408
- (NSString *)osVersion;      // @ 0xa3d4
- (NSString *)localeLanguage; // @ 0xa548
- (NSString *)localeCountry;  // @ 0xa504
- (NSString *)localeString;   // @ 0xa4a4

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
