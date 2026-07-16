//
//  AppDelegate.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Cited @ addresses are relative to the program image base (0x4000).
//

#import <stdlib.h>
#import <string.h>

#import <GameKit/GameKit.h>
#import <Security/Security.h>
#import <StoreKit/StoreKit.h>
#import <sys/sysctl.h>
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
#import <UserNotifications/UserNotifications.h>
#endif

#import "AcNoteMng.h"
#import "AppDelegate.h"
#import "AudioManager.h"
#import "CommonAlertView.h"
#import "DownloadMain.h"
#import "MainViewController.h"
#import "MusicManager.h"
#import "NoteMng.h"
#import "PurchaseManager.h"
#import "RewardNetwork.h"
#import "StoreUtil.h"
#import "TreasureData+Store.h"
#import "TreasureData.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neWindow.h"

// Ghidra: DAT_00187b5a (read in applicationWillResignActive:).
BOOL gLaunchedFromPush = NO;

@implementation AppDelegate {
    BOOL _isNecessaryToResume;
    void *_mainTask;
    void *_acMainTask;
    int _hardwareType;
    int _displayType;
    NSManagedObjectContext *_managedObjectContext;
    NSManagedObjectContext *_managedObjectContextSub;
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
}

// -[AppDelegate dealloc]  @ 0x8c74 — ARC-omitted.

#pragma mark - Launch

/**
 * -[AppDelegate application:didFinishLaunchingWithOptions:]  @ 0x8cf0
 * @complete
 */
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    CGRect bounds = UIScreen.mainScreen ? UIScreen.mainScreen.bounds : CGRectZero;
    self.mainWindow = [[neWindow alloc] initWithFrame:bounds];
    self.mainWindow.backgroundColor = UIColor.blackColor;

    srand((unsigned)time(nullptr));

#ifdef ENABLE_PATCHES
    // Preservation build: Konami's Terms-of-Service acceptance server is defunct,
    // so its first-run dialog can never complete. Pre-accept the policy here -- the
    // setting the game actually gates on -- so every isPolicyAccepted check passes
    // and the dialog is never shown, wherever it is triggered from.
    if (![UserSettingData isPolicyAccepted]) {
        [UserSettingData saveIsPolicyAccepted:YES];
    }
#endif

    [self initHardware];
    neAppEventCenter::shared().begin();
    neSceneManager::shared();

    UIDevice *dev = UIDevice.currentDevice;
    if ([dev respondsToSelector:@selector(userInterfaceIdiom)]) {
        neSceneManager::setPadDisplay(UIDevice.currentDevice.userInterfaceIdiom !=
                                      UIUserInterfaceIdiomPhone);
    } else {
        neSceneManager::setPadDisplay(false);
    }

    // User-Agent: "SHISHAMO MUSIC/<ver> (<model>; iOS <os>; <locale>)".
    NSString *bundleVersion = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];
    NSString *osVersion =
        [UIDevice.currentDevice.systemVersion stringByReplacingOccurrencesOfString:@"."
                                                                        withString:@"."];
    NSString *locale = NSLocale.currentLocale.localeIdentifier;
    self.userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; %@)",
                                                @"SHISHAMO MUSIC",
                                                bundleVersion,
                                                self.hardwareName,
                                                osVersion,
                                                locale];

    [[PurchaseManager sharedManager] start];
    [[PurchaseManager sharedManager] loadProductList];

    [[AudioManager sharedManager] systemStartBlock];

    self.viewController = [[MainViewController alloc] init];
    self.viewController.view.tag = 1;
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0
    // iOS 13+ SDKs require the key window to own a root view controller by the end
    // of launch; the binary's addSubview: path aborts at runtime under them.
    self.mainWindow.rootViewController = self.viewController;
#else
    [self.mainWindow addSubview:self.viewController.view]; // Ghidra @ 0x8cf0
#endif
    neSceneManager::shared().attachRoot(self.viewController);
    [self.mainWindow makeKeyAndVisible];

    neGraphics::configure((float)UIScreen.mainScreen.scale);
    neEngine::bootstrapB();
    neEngine::bootstrapC(0);

    [UserSettingData loadSettingData];
    [TreasureData init:self.managedObjectContext];

    [[MusicManager getInstance] loadPurchasedMusics];
    [[MusicManager getInstance] setMusicDataArrayDirty];
    [[MusicManager getInstance] setAcMusicDataArrayDirty];

    if ([self isOldHardware] && !neSceneManager::isPadDisplay()) {
        [UserSettingData saveIsEffectOn:NO];
        [UserSettingData saveIsLongNotesEffectOn:NO];
    }

    _rewardAppId = [NSString stringWithFormat:@"%d", 24];
    [RewardNetwork startWithAppliId:_rewardAppId
                                env:@"0"
                           callback:^(NSError *error) {
                             (void)error;
                           }];

    [[DownloadMain getInstance] startGetDlFileListHttp:-1];

    // operator_new(0x4c) + BootLogoTask::BootLogoTask + C_TASK::setPriority(_, 3).
    neEngine::startBootTask();

    [self.viewController SetLoopInterval:1];
    [self.viewController StartLoop];

    self.strageAlert = [[CommonAlertView alloc] initWithTitle:nil
                                                      message:nil
                                                     delegate:nil
                                            cancelButtonTitle:nil
                                            otherButtonTitles:nil];

    if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]) {
        neAppEventCenter::shared().setRemoteNotifyPending(true);
    }

    [application setApplicationIconBadgeNumber:0];

    [[DownloadMain getInstance] startGetEventInfoHttp];
    self.getEventInfoTimer =
        [NSTimer scheduledTimerWithTimeInterval:300.0
                                         target:[DownloadMain getInstance]
                                       selector:@selector(startGetEventInfoHttp)
                                       userInfo:nil
                                        repeats:YES];

    return YES;
}

#pragma mark - Lifecycle

/**
 * -[AppDelegate applicationWillResignActive:] — pause the note engines and audio,
 * remember whether a resume is needed, tear down the running task, and pump the
 * main loop three times when a resume is expected.
 * @ghidraAddress 0x95a8
 * @complete
 */
- (void)applicationWillResignActive:(UIApplication *)application {
    NoteMng::shared();
    if (gLaunchedFromPush) {
        NoteMng::shared().onResignActivePushHook();
    }
    if (AcNoteMng::shared().isPlaying()) {
        AcNoteMng::shared().Pause();
    }

    [[AudioManager sharedManager] systemSuspend];

    BOOL resume = NO;
    if (![self.viewController isPause]) {
        resume = [self.viewController isLoop];
    }
    _isNecessaryToResume = resume;
    [self.viewController PauseLoop];

    if (_mainTask) {
        neEngine::stopMainTask(static_cast<MainTask *>(_mainTask));
    }
    if (_acMainTask) {
        neEngine::stopAcMainTask(static_cast<AcMainTask *>(_acMainTask));
    }

    // The binary pumps mainLoop three times when a resume is expected.
    if (_isNecessaryToResume) {
        [self.viewController mainLoop];
        [self.viewController mainLoop];
        [self.viewController mainLoop];
    }
}

/**
 * -[AppDelegate applicationWillEnterForeground:] — reload every cached texture
 * (the binary inlines the texture-list walk; de-inlined here into
 * neEngine::notifyEnterForeground).
 * @ghidraAddress 0x9728
 * @complete
 */
- (void)applicationWillEnterForeground:(UIApplication *)application {
    neEngine::notifyEnterForeground();
}

/**
 * -[AppDelegate applicationDidBecomeActive:] — resume audio + the render loop,
 * then show the low-storage alert once free space drops to 24 MB or below.
 * @ghidraAddress 0x972c
 * @complete
 */
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[AudioManager sharedManager] systemResume];
    if (_isNecessaryToResume) {
        [self.viewController ResumeLoop];
    }

    // Warn once when free space runs low.
    unsigned long long freeBytes = [AppDelegate freeFileSystemSize];
    unsigned long long freeMB = freeBytes >> 21;
    if (freeMB > 24) {
        return;
    }
    if ([self.strageAlert isVisible]) {
        return;
    }
    [self.strageAlert show];
}

/**
 * -[AppDelegate applicationDidEnterBackground:] — flush the event center, notify
 * the engine, and clear the app icon badge.
 * @ghidraAddress 0x96dc
 * @complete
 */
- (void)applicationDidEnterBackground:(UIApplication *)application {
    neAppEventCenter::shared().flush();
    neEngine::onDidEnterBackground();
    [UIApplication.sharedApplication setApplicationIconBadgeNumber:0];
}

/**
 * -[AppDelegate applicationWillTerminate:] — flush the event center and clear the
 * app icon badge.
 * @ghidraAddress 0x9810
 * @complete
 */
- (void)applicationWillTerminate:(UIApplication *)application {
    neAppEventCenter::shared().flush();
    [UIApplication.sharedApplication setApplicationIconBadgeNumber:0];
}

/**
 * -[AppDelegate applicationDidReceiveMemoryWarning:] — release MusicManager's
 * cached music data.
 * @ghidraAddress 0x985c
 * @complete
 */
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [[MusicManager getInstance] releaseChacheMusicData];
}

#pragma mark - Notifications

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
/**
 * -[AppDelegate userNotificationCenter:didReceiveNotificationResponse:
 * withCompletionHandler:] — the modern UNUserNotificationCenterDelegate tap
 * callback replacing the iOS 10-deprecated
 * -application:didReceiveLocalNotification: (empty in the binary). Reads the
 * notification's user info and immediately calls the completion handler.
 * @newCode
 */
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completionHandler {
    (void)response.notification.request.content.userInfo;
    completionHandler();
}
#else
/**
 * -[AppDelegate application:didReceiveLocalNotification:] — empty in the binary.
 * @ghidraAddress 0x9858
 * @complete
 */
- (void)application:(UIApplication *)application
    didReceiveLocalNotification:(UILocalNotification *)notification {
}
#endif

/**
 * -[AppDelegate application:didReceiveRemoteNotification:] — when the app is
 * backgrounded/inactive, mark a pending remote-notify on the event center.
 * @ghidraAddress 0xafb8
 * @complete
 */
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
    (void)userInfo[@"body"];
    if (application.applicationState > UIApplicationStateInactive) {
        return;
    }
    neAppEventCenter::shared().setRemoteNotifyPending(true);
}

/**
 * -[AppDelegate application:didRegisterForRemoteNotificationsWithDeviceToken:] —
 * strip the device-token description to hex, then fire-and-forget POST it (with
 * the uuid, user agent, and target store) to the save-APNs-token endpoint.
 * @ghidraAddress 0xad90
 * @complete
 */
- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString *token = [deviceToken description];
    token = [token stringByReplacingOccurrencesOfString:@"<" withString:@""];
    token = [token stringByReplacingOccurrencesOfString:@">" withString:@""];
    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];

    NSMutableURLRequest *req =
        [[NSMutableURLRequest alloc] initWithURL:[StoreUtil saveApnsTokenURL]
                                     cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                 timeoutInterval:15.0];
    NSString *body =
        [NSString stringWithFormat:@"uuid=%@&token=%@", [[AppDelegate appDelegate] uuId], token];
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [req setValue:[[AppDelegate appDelegate] userAgent] forHTTPHeaderField:@"User-Agent"];
    [req setValue:[StoreUtil targetStore] forHTTPHeaderField:@"Accept-Language"];
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    // Fire-and-forget POST of the APNs token; the original used a delegate-less
    // NSURLConnection that started immediately and ignored the result.
    [[[NSURLSession sharedSession]
        dataTaskWithRequest:req
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
          }] resume];
#else
    (void)[[NSURLConnection alloc] initWithRequest:req delegate:nil];
#endif
}

/**
 * -[AppDelegate application:didFailToRegisterForRemoteNotificationsWithError:] —
 * empty in the binary.
 * @ghidraAddress 0xafb4
 * @complete
 */
- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
}

#pragma mark - App identity & hardware

/**
 * -[AppDelegate appDelegate] — shared app delegate.
 * @ghidraAddress 0x89a0
 * @complete
 */
+ (instancetype)appDelegate {
    return (AppDelegate *)UIApplication.sharedApplication.delegate;
}

/**
 * -[AppDelegate appDocumentsDirectory].
 * @ghidraAddress 0x89d4
 * @complete
 */
+ (NSString *)appDocumentsDirectory {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
        .lastObject;
}

/**
 * -[AppDelegate appAppSupportDirectory] — lazily creates the dir + marks it excluded from backup.
 * @ghidraAddress 0x8a1c
 * @complete
 */
+ (NSString *)appAppSupportDirectory {
    NSString *path =
        NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)
            .lastObject;
    if ([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:NULL]) {
        return path;
    }
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:path
                                 withIntermediateDirectories:NO
                                                  attributes:nil
                                                       error:&error]) {
        return nil;
    }
    NSURL *url = [NSURL fileURLWithPath:path isDirectory:YES];
    if (![self addSkipBackupAttributeToItemAtURL:url]) {
        return nil;
    }
    return path;
}

/**
 * +[AppDelegate addSkipBackupAttributeToItemAtURL:] — mark a URL excluded from backup.
 * @ghidraAddress 0x8af8
 * @complete
 */
+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL {
    NSAssert([NSFileManager.defaultManager fileExistsAtPath:URL.path],
             @"[[NSFileManager defaultManager] fileExistsAtPath:[URL path]]");
    NSError *error = nil;
    BOOL success = [URL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error];
    if (!success) {
        NSLog(@"Error excluding %@ from backup %@", URL.lastPathComponent, error);
    }
    return success;
}

/**
 * -[AppDelegate appCachesDirectory].
 * @ghidraAddress 0x89f8
 * @complete
 */
+ (NSString *)appCachesDirectory {
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
}

/**
 * -[AppDelegate freeFileSystemSize].
 * @ghidraAddress 0x8be8
 * @complete
 */
+ (unsigned long long)freeFileSystemSize {
    NSDictionary *attrs =
        [NSFileManager.defaultManager attributesOfFileSystemForPath:[self appDocumentsDirectory]
                                                              error:nil];
    return [[attrs valueForKey:NSFileSystemFreeSize] longLongValue];
}

/**
 * -[AppDelegate hardwareType] — cached device-model enum.
 * @ghidraAddress 0xb13c
 * @complete
 */
- (int)hardwareType {
    return _hardwareType;
}
// displayType is a synthesized atomic getter @ 0xb0a8.

/**
 * -[AppDelegate isOldHardware] — low-spec device test.
 * @ghidraAddress 0xad5c
 * @complete
 */
- (BOOL)isOldHardware {
    unsigned type = (unsigned)_hardwareType;
    if (type < 28 && ((1u << type) & 0x0ff7803f) != 0) {
        return YES;
    }
    return (type - 34) < 3;
}

// hw.machine identifiers ordered by hardwareType. Ghidra: DAT_00130574.
static const char *const kHardwareModels[40] = {
    "iPhone1,1", "iPhone1,2", "iPhone2,1", "iPhone3,1", "iPhone3,2", "iPhone3,3", "iPhone4,1",
    "iPhone4,2", "iPhone4,3", "iPhone5,1", "iPhone5,2", "iPhone5,3", "iPhone5,4", "iPhone6,1",
    "iPhone6,2", "iPod1,1",   "iPod2,1",   "iPod3,1",   "iPod4,1",   "iPod5,1",   "iPad1,1",
    "iPad2,1",   "iPad2,2",   "iPad2,3",   "iPad2,4",   "iPad3,1",   "iPad3,2",   "iPad3,3",
    "iPad3,4",   "iPad3,5",   "iPad3,6",   "iPad4,1",   "iPad4,2",   "iPad4,3",   "iPad2,5",
    "iPad2,6",   "iPad2,7",   "iPad4,4",   "iPad4,5",   "i386",
};

/**
 * -[AppDelegate initHardware] — sysctl hw.machine -> _hardwareType / _displayType tiers.
 * @ghidraAddress 0xa58c
 * @complete
 */
- (void)initHardware {
    size_t size = 0;
    sysctlbyname("hw.machine", nullptr, &size, nullptr, 0);
    char *machine = (char *)malloc(size);
    sysctlbyname("hw.machine", machine, &size, nullptr, 0);

    self.hardwareName = [[NSString alloc] initWithCString:machine encoding:NSUTF8StringEncoding];

    for (int i = 0; i < 40; i++) {
        if (kHardwareModels[i] && strcmp(kHardwareModels[i], machine) == 0) {
            _hardwareType = i;
            switch (i) {
            case 0:
            case 1:
            case 2:
            case 15:
            case 16:
            case 17:
                _displayType = 0;
                break;
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 18:
                _displayType = 1;
                break;
            case 9:
            case 10:
            case 11:
            case 12:
            case 13:
            case 14:
            case 19:
                _displayType = 2;
                break;
            case 20:
            case 21:
            case 22:
            case 23:
            case 24:
            case 34:
            case 35:
            case 36:
                _displayType = 3;
                break;
            default:
                _displayType = ((i >= 25 && i <= 33) || i == 37 || i == 38) ? 4 : 5;
                break;
            }
            free(machine);
            return;
        }
    }

    // Unknown model: classify by family and generation floor.
    if (strncmp("iPhone", machine, 6) == 0) {
        if (strncmp("iPhone5", machine, 7) > 0) {
            _hardwareType = 40;
            _displayType = 5;
        } else {
            _hardwareType = 42;
            _displayType = 2;
        }
    } else if (strncmp("iPad", machine, 4) == 0) {
        if (strncmp("iPad3", machine, 7) > 0) {
            _hardwareType = 40;
            _displayType = 5;
        } else {
            _hardwareType = 43;
            _displayType = 4;
        }
    } else if (strncmp("iPod", machine, 4) == 0 && strncmp("iPod5", machine, 7) <= 0) {
        _hardwareType = 41;
        _displayType = 2;
    } else {
        _hardwareType = 40;
        _displayType = 5;
    }
    free(machine);
}

/**
 * -[AppDelegate uuId] — read (or mint + Keychain-store) the persistent device UUID.
 * @ghidraAddress 0x9890
 * @complete
 */
- (NSString *)uuId {
    NSString *service = NSBundle.mainBundle.bundleIdentifier;

    NSDictionary *attrQuery = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : @"ApplicationUniqueID",
        (__bridge id)kSecAttrService : service,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef attrsRef = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)attrQuery, &attrsRef) == errSecSuccess) {
        NSMutableDictionary *dataQuery = [NSMutableDictionary
            dictionaryWithDictionary:(__bridge_transfer NSDictionary *)attrsRef];
        dataQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
        dataQuery[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
        CFTypeRef dataRef = nullptr;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)dataQuery, &dataRef) == errSecSuccess) {
            NSData *data = (__bridge_transfer NSData *)dataRef;
            NSString *stored = [[NSString alloc] initWithBytes:data.bytes
                                                        length:data.length
                                                      encoding:NSUTF8StringEncoding];
            if (stored != nil) {
                return stored;
            }
        }
    }

    // Nothing stored yet — mint and persist a UUID.
    CFUUIDRef uuid = CFUUIDCreate(nullptr);
    CFStringRef uuidStr = CFUUIDCreateString(nullptr, uuid);
    NSString *result = [NSString stringWithString:(__bridge NSString *)uuidStr];
    CFRelease(uuidStr);
    CFRelease(uuid);

    NSMutableDictionary *add =
        [NSMutableDictionary dictionaryWithObjectsAndKeys:(__bridge id)kSecClassGenericPassword,
                                                          (__bridge id)kSecClass,
                                                          @"ApplicationUniqueID",
                                                          (__bridge id)kSecAttrAccount,
                                                          service,
                                                          (__bridge id)kSecAttrService,
                                                          @"",
                                                          (__bridge id)kSecAttrLabel,
                                                          @"",
                                                          (__bridge id)kSecAttrDescription,
                                                          nil];
    if ([UIDevice.currentDevice.systemVersion compare:@"4.0"
                                              options:NSNumericSearch] != NSOrderedAscending) {
        add[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
    }
    add[(__bridge id)kSecValueData] = [result dataUsingEncoding:NSUTF8StringEncoding];
    SecItemAdd((__bridge CFDictionaryRef)add, nullptr);
    return result;
}

/**
 * -[AppDelegate deleteUuid] — remove the stored device UUID.
 * @ghidraAddress 0x9c20
 * @complete
 */
- (void)deleteUuid {
    NSString *service = NSBundle.mainBundle.bundleIdentifier;
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : @"ApplicationUniqueID",
        (__bridge id)kSecAttrService : service,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef attrsRef = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &attrsRef) == errSecSuccess) {
        NSDictionary *deleteQuery = @{
            (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrAccount : @"ApplicationUniqueID",
        };
        SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    }
}

#pragma mark - Settings-version keychain record

/**
 * -[AppDelegate setUsersettingVer:] — Keychain add-or-update the setting version.
 * @ghidraAddress 0x9d58
 * @complete
 */
- (void)setUsersettingVer:(NSString *)ver {
    NSData *data = [ver dataUsingEncoding:NSUTF8StringEncoding];
    NSString *service = NSBundle.mainBundle.bundleIdentifier;

    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : @"UserSettingVer",
        (__bridge id)kSecAttrService : service,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef found = nullptr;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &found);

    if (status == errSecItemNotFound) {
        NSMutableDictionary *add = [NSMutableDictionary dictionary];
        add[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
        add[(__bridge id)kSecAttrAccount] = @"UserSettingVer";
        add[(__bridge id)kSecValueData] = data;
        add[(__bridge id)kSecAttrService] = NSBundle.mainBundle.bundleIdentifier;
        add[(__bridge id)kSecAttrLabel] = @"";
        add[(__bridge id)kSecAttrDescription] = @"";
        add[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
        if (SecItemAdd((__bridge CFDictionaryRef)add, nullptr) == errSecSuccess) {
            NSLog(@"setUsersettingVer add success.");
        } else {
            NSLog(@"setUsersettingVer add error. (%d)", (int)status);
        }
    } else if (status == errSecSuccess) {
        NSMutableDictionary *update = [NSMutableDictionary dictionary];
        update[(__bridge id)kSecValueData] = data;
        update[(__bridge id)kSecAttrModificationDate] = [NSDate date];
        if (SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)update) ==
            errSecSuccess) {
            NSLog(@"setUsersettingVer update success.");
        } else {
            NSLog(@"setUsersettingVer update error. (%d)", (int)status);
        }
    }
}

/**
 * -[AppDelegate getUsersettingVer] — read the setting version ("0" if absent).
 * @ghidraAddress 0xa044
 * @complete
 */
- (NSString *)getUsersettingVer {
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : @"UserSettingVer",
        (__bridge id)kSecAttrService : NSBundle.mainBundle.bundleIdentifier,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef attrsRef = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &attrsRef) == errSecSuccess) {
        NSMutableDictionary *dataQuery = [NSMutableDictionary
            dictionaryWithDictionary:(__bridge_transfer NSDictionary *)attrsRef];
        dataQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
        dataQuery[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
        CFTypeRef dataRef = nullptr;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)dataQuery, &dataRef) == errSecSuccess) {
            NSData *data = (__bridge_transfer NSData *)dataRef;
            NSString *stored = [[NSString alloc] initWithBytes:data.bytes
                                                        length:data.length
                                                      encoding:NSUTF8StringEncoding];
            if (stored != nil) {
                return stored;
            }
        }
    }
    return [NSString stringWithFormat:@"0"];
}

/**
 * -[AppDelegate deleteUsersettingVer] — remove the setting-version Keychain item.
 * @ghidraAddress 0xa270
 * @complete
 */
- (void)deleteUsersettingVer {
    NSString *service = NSBundle.mainBundle.bundleIdentifier;
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : @"UserSettingVer",
        (__bridge id)kSecAttrService : service,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef attrsRef = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &attrsRef) == errSecSuccess) {
        NSDictionary *deleteQuery = @{
            (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrAccount : @"UserSettingVer",
        };
        SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    }
}

#pragma mark - Environment strings

/**
 * -[AppDelegate userAgent] — copy of the cached UA string.
 * @ghidraAddress 0xa3a8
 * @complete
 */
- (NSString *)userAgent {
    return [NSString stringWithString:_userAgent];
}

/**
 * -[AppDelegate appVersion] — Info.plist CFBundleVersion.
 * @ghidraAddress 0xa408
 * @complete
 */
- (NSString *)appVersion {
    return NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];
}

/**
 * -[AppDelegate appVersionNum] — version with dots stripped.
 * @ghidraAddress 0xa458
 * @complete
 */
- (int)appVersionNum {
    NSString *stripped = [self.appVersion stringByReplacingOccurrencesOfString:@"." withString:@""];
    return [stripped intValue];
}

/**
 * -[AppDelegate osVersion] — UIDevice systemVersion.
 * @ghidraAddress 0xa3d4
 * @complete
 */
- (NSString *)osVersion {
    return UIDevice.currentDevice.systemVersion;
}

/**
 * -[AppDelegate localeLanguage] — NSLocaleLanguageCode.
 * @ghidraAddress 0xa548
 * @complete
 */
- (NSString *)localeLanguage {
    return [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode];
}

/**
 * -[AppDelegate localeCountry] — NSLocaleCountryCode.
 * @ghidraAddress 0xa504
 * @complete
 */
- (NSString *)localeCountry {
    return [NSLocale.currentLocale objectForKey:NSLocaleCountryCode];
}

/**
 * -[AppDelegate localeString] — "language_country".
 * @ghidraAddress 0xa4a4
 * @complete
 */
- (NSString *)localeString {
    return [NSString stringWithFormat:@"%@_%@", self.localeLanguage, self.localeCountry];
}

#pragma mark - StoreKit / purchases

/**
 * -[AppDelegate finishRequest:] — retain the received StoreKit products array
 * (the vestigial objectAtIndex:0 whose result is discarded matches the binary).
 * @ghidraAddress 0xab44
 * @complete
 */
- (void)finishRequest:(NSArray *)products {
    _products = products;
    if (_products.count == 0) {
        return;
    }
    (void)[_products objectAtIndex:0];
}

/**
 * -[AppDelegate purchaseSucceeded:] — global "purchase completed" confirm alert
 * (title "Succeeded", the store view controllers do the actual unlock).
 * @ghidraAddress 0xab9c
 * @complete
 */
- (void)purchaseSucceeded:(id)transaction {
    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"Succeeded"
                                                            message:@"購入処理が完了しました。"
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"OK"];
    [alert show];
}

/**
 * -[AppDelegate purchaseFailed:error:] — global "purchase failed" alert (title
 * "Failed"); the store view controller does the real cleanup.
 * @ghidraAddress 0xac24
 * @complete
 */
- (void)purchaseFailed:(id)transaction error:(NSError *)error {
    CommonAlertView *alert = [[CommonAlertView alloc] initWithTitle:@"Failed"
                                                            message:@"購入処理が失敗しました。"
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"OK"];
    [alert show];
}

/**
 * -[AppDelegate getProduct:] — linear-search the cached StoreKit products for a
 * matching product identifier.
 * @ghidraAddress 0xacac
 * @complete
 */
- (SKProduct *)getProduct:(NSString *)productId {
    if (self.products != nil) {
        for (NSUInteger i = 0; i < self.products.count; i++) {
            SKProduct *product = [self.products objectAtIndex:i];
            if (product != nil && [product.productIdentifier isEqualToString:productId]) {
                return product;
            }
        }
    }
    return nil;
}

#pragma mark - Game Center

/**
 * -[AppDelegate loginGameCenter] — install the local player's authenticate
 * handler, which presents the Game Center login VC when one is provided.
 * @ghidraAddress 0xb00c
 * @complete
 */
- (void)loginGameCenter {
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    localPlayer.authenticateHandler = ^(UIViewController *viewController, NSError *error) {
      // Block invoke @ 0xb07c.
      if (viewController != nil) {
          [self.viewController presentViewController:viewController animated:YES completion:nil];
      }
    };
}

#pragma mark - Core Data stack

/**
 * -[AppDelegate managedObjectContext] — lazily build the main Core Data context
 * wired to the shared store coordinator. The binary uses plain -init; the
 * concurrency-type init is a guarded modernization for current iOS.
 * @ghidraAddress 0xa810
 * @complete
 */
- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext == nil) {
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator != nil) {
#if defined(__IPHONE_5_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_5_0
            _managedObjectContext =
                [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
#else
            _managedObjectContext = [[NSManagedObjectContext alloc] init];
#endif
            [_managedObjectContext setPersistentStoreCoordinator:coordinator];
        }
    }
    return _managedObjectContext;
}

/**
 * -[AppDelegate managedObjectContextSub] — lazily build the secondary Core Data
 * context sharing the same store coordinator (same shape as
 * managedObjectContext).
 * @ghidraAddress 0xa890
 * @complete
 */
- (NSManagedObjectContext *)managedObjectContextSub {
    if (_managedObjectContextSub == nil) {
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator != nil) {
#if defined(__IPHONE_5_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_5_0
            _managedObjectContextSub =
                [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
#else
            _managedObjectContextSub = [[NSManagedObjectContext alloc] init];
#endif
            [_managedObjectContextSub setPersistentStoreCoordinator:coordinator];
        }
    }
    return _managedObjectContextSub;
}

/**
 * -[AppDelegate managedObjectModel] — lazily load the compiled model
 * ScoreData.momd from the app bundle.
 * @ghidraAddress 0xa910
 * @complete
 */
- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel == nil) {
        NSString *path = [NSBundle.mainBundle pathForResource:@"ScoreData" ofType:@"momd"];
        NSURL *url = [NSURL fileURLWithPath:path];
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    }
    return _managedObjectModel;
}

/**
 * -[AppDelegate persistentStoreCoordinator] — lazily build the auto-migrating
 * SQLite store coordinator (Documents/ScoreData.sqlite); aborts if the store
 * cannot be added.
 * @ghidraAddress 0xa9cc
 * @complete
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator == nil) {
        NSString *storePath = [[AppDelegate appDocumentsDirectory]
            stringByAppendingPathComponent:@"ScoreData.sqlite"];
        NSURL *storeURL = [NSURL fileURLWithPath:storePath];

        NSDictionary *options = @{
            NSMigratePersistentStoresAutomaticallyOption : @YES,
            NSInferMappingModelAutomaticallyOption : @YES,
        };

        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
            initWithManagedObjectModel:self.managedObjectModel];
        NSError *error = nil;
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                       configuration:nil
                                                                 URL:storeURL
                                                             options:options
                                                               error:&error]) {
            abort();
        }
    }
    return _persistentStoreCoordinator;
}

@end
