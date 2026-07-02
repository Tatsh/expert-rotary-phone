//
//  AppDelegate.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Original path (from embedded __FILE__): Project/AppDelegate.mm
//  Objective-C++ (ARC): drives the C++ "ne" engine singletons.
//  Cited addresses are relative to the program image base (0x4000).
//

#import <stdlib.h>
#import <string.h>

#import <Security/Security.h>
#import <sys/sysctl.h>

#import "AppDelegate.h"
#import "AudioManager.h"
#import "CommonAlertView.h"
#import "DownloadMain.h"
#import "AcNoteMng.h"
#import "MainViewController.h"
#import "MusicManager.h"
#import "NoteMng.h"
#import "PurchaseManager.h"
#import "RewardNetwork.h"   // -> Stubs/RewardNetwork.h (no-op ad SDK; see below)
#import "StoreUtil.h"
#import "TreasureData+Store.h"
#import "TreasureData.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neWindow.h"

// Ad/analytics dependency intentionally removed (see README "Ad / analytics").
// The original launch path called +[RewardNetwork startWithAppliId:env:callback:];
// it is stubbed to a no-op and not linked.

// Global set elsewhere: YES when running on iPad idiom (Ghidra: DAT_00187b84).
BOOL gIsPad = NO;
// Global flag: a push notification launched/woke the app (Ghidra: DAT_00187bed).
BOOL gLaunchedFromPush = NO;

@implementation AppDelegate {
    // Whether the run loop should be resumed on becoming active again; captured
    // in applicationWillResignActive: (Ghidra ivar _isNecessaryToResume).
    BOOL _isNecessaryToResume;
    // Live background C++ engine tasks (Ghidra ivars _mainTask / _acMainTask).
    void *_mainTask;
    void *_acMainTask;
    // Device model index (into the hw.machine table) + rendering tier.
    int _hardwareType;
    int _displayType;
    // Backing store for the lazy Core Data getters.
    NSManagedObjectContext *_managedObjectContext;
    NSManagedObjectContext *_managedObjectContextSub;
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
}

#pragma mark - Launch

// -[AppDelegate application:didFinishLaunchingWithOptions:]  @ 0x8cf0
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Custom OpenGL-backed window sized to the main screen.
    CGRect bounds = UIScreen.mainScreen ? UIScreen.mainScreen.bounds : CGRectZero;
    self.window = [[neWindow alloc] initWithFrame:bounds];
    self.window.backgroundColor = UIColor.blackColor;

    srand((unsigned)time(nullptr));

    // Device/hardware probing + engine bring-up.
    [self initHardware];
    neAppEventCenter::shared().begin();   // Ghidra: FUN_0000b150 -> FUN_00028c70
    neSceneManager::shared();             // Ghidra: FUN_0000b194 (lazily ctors, FUN_0002c5c0)

    // iPad vs iPhone idiom (guarded for pre-3.2 responders, as in the original).
    UIDevice *dev = UIDevice.currentDevice;
    if ([dev respondsToSelector:@selector(userInterfaceIdiom)]) {
        gIsPad = (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone);
    } else {
        gIsPad = NO;
    }

    // Build the HTTP User-Agent: "SHISHAMO MUSIC/<ver> (<model>; iOS <os>; <locale>)".
    // Ghidra: format "%@/%@ (%@; iOS %@; %@)" @ 0x101788, product @ 0x101769.
    NSString *bundleVersion = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];
    NSString *osVersion = [UIDevice.currentDevice.systemVersion
                           stringByReplacingOccurrencesOfString:@"." withString:@"."];
    NSString *locale = NSLocale.currentLocale.localeIdentifier;
    self.userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; %@)",
                      @"SHISHAMO MUSIC", bundleVersion, self.hardwareName, osVersion, locale];

    // StoreKit purchase pipeline.
    [[PurchaseManager sharedManager] start];
    [[PurchaseManager sharedManager] loadProductList];

    // Audio subsystem.
    [[AudioManager sharedManager] systemStartBlock];

    // Root view controller into the window.
    self.viewController = [[MainViewController alloc] init];
    self.viewController.view.tag = 1;
    [self.window addSubview:self.viewController.view];
    neSceneManager::shared().attachRoot((__bridge void *)self.viewController); // Ghidra: FUN_0002c5b8
    [self.window makeKeyAndVisible];

    // Renderer setup at the screen's content scale, then engine bootstrap.
    neGraphics::configure((float)UIScreen.mainScreen.scale); // Ghidra: FUN_00012368
    neEngine::bootstrapB();                                     // Ghidra: FUN_0001ba2c
    neEngine::bootstrapC(0);                                    // Ghidra: FUN_0001796c

    // Load persisted settings and seed the treasure (sugoroku) save record.
    [UserSettingData loadSettingData];
    [TreasureData init:self.managedObjectContext];

    // Music catalog: load purchased songs, mark caches dirty for rebuild.
    [[MusicManager getInstance] loadPurchasedMusics];
    [[MusicManager getInstance] setMusicDataArrayDirty];
    [[MusicManager getInstance] setAcMusicDataArrayDirty];

    // Old, non-iPad hardware: force effects off to keep the frame rate.
    if ([self isOldHardware] && !gIsPad) {
        [UserSettingData saveIsEffectOn:NO];
        [UserSettingData saveIsLongNotesEffectOn:NO];
    }

    // --- Ad-reward SDK removed. Original:
    //     self.rewardAppId = [NSString stringWithFormat:@"%d", 24];
    //     [RewardNetwork startWithAppliId:self.rewardAppId env:... callback:...];
    RewardNetwork_startDisabled();

    // Kick off the download-list fetch (-1 = full list).
    [[DownloadMain getInstance] startGetDlFileListHttp:-1];

    // Create + register the app's boot task at priority 3.
    neEngine::startBootTask();   // Ghidra: operator_new(0x4c) + FUN_0002af58 + FUN_00027f08(_,3)

    // Start the render/update loop on the root controller.
    [self.viewController SetLoopInterval:1];
    [self.viewController StartLoop];

    // Prepare (but do not yet show) the low-storage warning alert.
    self.strageAlert = [[CommonAlertView alloc] initWithTitle:nil
                                                      message:nil
                                                     delegate:nil
                                            cancelButtonTitle:nil
                                            otherButtonTitles:nil];

    // Launched from a remote notification?
    if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]) {
        neAppEventCenter::shared();
        gLaunchedFromPush = YES;
    }

    [application setApplicationIconBadgeNumber:0];

    // Fetch event info and schedule periodic refresh.
    [[DownloadMain getInstance] startGetEventInfoHttp];
    self.getEventInfoTimer =
        [NSTimer scheduledTimerWithTimeInterval:/* interval @ DAT_00009560 */ 60.0
                                         target:[DownloadMain getInstance]
                                       selector:@selector(startGetEventInfoHttp)
                                       userInfo:nil
                                        repeats:YES];

    return YES;
}

#pragma mark - Lifecycle

// -[AppDelegate applicationWillResignActive:]  @ 0x95a8
- (void)applicationWillResignActive:(UIApplication *)application {
    NoteMng::shared();                         // Ghidra: NoteMng_shared (FUN_0000b278)
    if (/* DAT_00187b5a */ gLaunchedFromPush) {
        // Ghidra: NEEngine_onResignActivePushHook (FUN_00034510) on the global NoteMng.
        NoteMng::shared().onResignActivePushHook();
    }
    AcNoteMng::shared();                        // Ghidra: AcNoteMng_shared (FUN_0000b35c)

    [[AudioManager sharedManager] systemSuspend];

    // Remember whether we were actively looping (and not paused) so we can
    // resume on reactivation.
    BOOL resume = NO;
    if (![self.viewController isPause]) {
        resume = [self.viewController isLoop];
    }
    _isNecessaryToResume = resume;
    [self.viewController PauseLoop];

    if (_mainTask)   neEngine::stopMainTask(_mainTask);      // Ghidra: FUN_00030710
    if (_acMainTask) neEngine::stopAcMainTask(_acMainTask);  // Ghidra: FUN_0002314c

    // If a resume is expected, pump the loop once so the last frame is flushed.
    if (_isNecessaryToResume) {
        [self.viewController mainLoop];
        [self.viewController mainLoop];
    }
}

// -[AppDelegate applicationWillEnterForeground:]  @ 0x9728
- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Notify every foreground observer (engine observer list, head @ DAT_00188464).
    neEngine::notifyEnterForeground();   // Ghidra: FUN_000188ac walk
}

// -[AppDelegate applicationDidBecomeActive:]  @ 0x972c
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[AudioManager sharedManager] systemResume];
    if (_isNecessaryToResume) {
        [self.viewController ResumeLoop];
    }

    // Warn once if free space has dropped below ~24 MB.
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

// -[AppDelegate applicationDidEnterBackground:]  @ 0x96dc
- (void)applicationDidEnterBackground:(UIApplication *)application {
    neAppEventCenter::shared().flush();   // Ghidra: FUN_0000b150 -> FUN_00028c9c
    neEngine::onDidEnterBackground();     // Ghidra: FUN_0001bdf8
    [UIApplication.sharedApplication setApplicationIconBadgeNumber:0];
}

// -[AppDelegate applicationWillTerminate:]  @ 0x9810
- (void)applicationWillTerminate:(UIApplication *)application {
    neAppEventCenter::shared().flush();   // Ghidra: FUN_00028c9c
    [UIApplication.sharedApplication setApplicationIconBadgeNumber:0];
}

// -[AppDelegate applicationDidReceiveMemoryWarning:]  @ 0x985c
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [[MusicManager getInstance] releaseChacheMusicData];
}

#pragma mark - Notifications

// -[AppDelegate application:didReceiveLocalNotification:]  @ 0x9858  (empty in original)
- (void)application:(UIApplication *)application
    didReceiveLocalNotification:(UILocalNotification *)notification {
}

// -[AppDelegate application:didReceiveRemoteNotification:]  @ 0xafb8
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
    (void)userInfo[@"body"];
    // Only react when the app was already backgrounded/inactive.
    if (application.applicationState > UIApplicationStateInactive) {
        return;
    }
    neAppEventCenter::shared();
    gLaunchedFromPush = YES;
}

// -[AppDelegate application:didRegisterForRemoteNotificationsWithDeviceToken:]  @ 0xad90
- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // Normalize "<xxxx xxxx>" description into a bare hex token.
    NSString *token = [deviceToken description];
    token = [token stringByReplacingOccurrencesOfString:@"<" withString:@""];
    token = [token stringByReplacingOccurrencesOfString:@">" withString:@""];
    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];

    NSMutableURLRequest *req =
        [[NSMutableURLRequest alloc] initWithURL:[StoreUtil saveApnsTokenURL]
                                     cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                 timeoutInterval:15.0];
    NSString *body = [NSString stringWithFormat:@"uuid=%@&token=%@",
                      [[AppDelegate appDelegate] uuId], token];
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [req setValue:[[AppDelegate appDelegate] userAgent] forHTTPHeaderField:@"User-Agent"];
    [req setValue:[StoreUtil targetStore] forHTTPHeaderField:@"Accept-Language"];
    // Fire-and-forget; the connection keeps itself alive while running.
    (void)[[NSURLConnection alloc] initWithRequest:req delegate:nil];
}

// -[AppDelegate application:didFailToRegisterForRemoteNotificationsWithError:]  @ 0xafb4  (empty)
- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
}

#pragma mark - App identity & hardware

// -[AppDelegate appDelegate]  @ 0x89a0
+ (instancetype)appDelegate {
    return (AppDelegate *)UIApplication.sharedApplication.delegate;
}

// -[AppDelegate appDocumentsDirectory]  @ 0x89d4
+ (NSString *)appDocumentsDirectory {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
}

// -[AppDelegate appAppSupportDirectory] — downloadable data (rhythmin.lv, chr, ...).
+ (NSString *)appAppSupportDirectory {
    return NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                               NSUserDomainMask, YES).lastObject;
}

// -[AppDelegate freeFileSystemSize]  @ 0x8be8
+ (unsigned long long)freeFileSystemSize {
    NSDictionary *attrs = [NSFileManager.defaultManager
        attributesOfFileSystemForPath:[self appDocumentsDirectory] error:nil];
    return [[attrs valueForKey:NSFileSystemFreeSize] longLongValue];
}

// -[AppDelegate hardwareType]  @ 0xb13c
- (int)hardwareType { return _hardwareType; }
- (int)displayType  { return _displayType; }

// -[AppDelegate isOldHardware]  @ 0xad5c
- (BOOL)isOldHardware {
    unsigned type = (unsigned)_hardwareType;
    // Old-hardware set among the first 28 model slots (bitmask), or the
    // 34..36 range.
    if (type < 28 && ((1u << type) & 0x0ff7803f) != 0) {
        return YES;
    }
    return (type - 34) < 3;
}

// Known hw.machine identifiers, in the order that defines hardwareType.
// Ghidra: DAT_00130574 (40 entries).
static const char *const kHardwareModels[40] = {
    "iPhone1,1", "iPhone1,2", "iPhone2,1", "iPhone3,1", "iPhone3,2", "iPhone3,3",
    "iPhone4,1", "iPhone4,2", "iPhone4,3", "iPhone5,1", "iPhone5,2", "iPhone5,3",
    "iPhone5,4", "iPhone6,1", "iPhone6,2", "iPod1,1", "iPod2,1", "iPod3,1",
    "iPod4,1", "iPod5,1", "iPad1,1", "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4",
    "iPad3,1", "iPad3,2", "iPad3,3", "iPad3,4", "iPad3,5", "iPad3,6", "iPad4,1",
    "iPad4,2", "iPad4,3", "iPad2,5", "iPad2,6", "iPad2,7", "iPad4,4", "iPad4,5",
    "i386",
};

// -[AppDelegate initHardware]  @ 0xa58c
// Reads hw.machine, records it as hardwareName, derives hardwareType (table
// index) and displayType (rendering tier); falls back by family/generation for
// models newer than the table.
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
                case 0: case 1: case 2: case 15: case 16: case 17:
                    _displayType = 0; break;
                case 3: case 4: case 5: case 6: case 7: case 8: case 18:
                    _displayType = 1; break;
                case 9: case 10: case 11: case 12: case 13: case 14: case 19:
                    _displayType = 2; break;
                case 20: case 21: case 22: case 23: case 24: case 34: case 35: case 36:
                    _displayType = 3; break;
                default:
                    // Newer slots: retina tier 4, else highest tier 5.
                    _displayType = ((i >= 25 && i <= 34) || i == 37 || i == 38) ? 4 : 5;
                    break;
            }
            free(machine);
            return;
        }
    }

    // Unknown model: classify by family + generation floor.
    if (strncmp("iPhone", machine, 6) == 0) {
        if (strncmp("iPhone5", machine, 7) > 0) { _hardwareType = 40; _displayType = 5; }
        else                                    { _hardwareType = 42; _displayType = 2; }
    } else if (strncmp("iPad", machine, 4) == 0) {
        if (strncmp("iPad3", machine, 7) > 0)   { _hardwareType = 40; _displayType = 5; }
        else                                    { _hardwareType = 43; _displayType = 4; }
    } else if (strncmp("iPod", machine, 4) == 0 && strncmp("iPod5", machine, 7) <= 0) {
        _hardwareType = 41; _displayType = 2;
    } else {
        _hardwareType = 40; _displayType = 5;
    }
    free(machine);
}

// -[AppDelegate uuId]  @ 0x9890
// A per-install identifier persisted in the keychain (generic password, account
// "ApplicationUniqueID", service = bundle id). Generated once via CFUUID so it
// survives app reinstalls; used to key backend requests and the Blowfish saves.
- (NSString *)uuId {
    NSString *service = NSBundle.mainBundle.bundleIdentifier;

    NSDictionary *attrQuery = @{
        (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount:      @"ApplicationUniqueID",
        (__bridge id)kSecAttrService:      service,
        (__bridge id)kSecMatchLimit:       (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef attrsRef = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)attrQuery, &attrsRef) == errSecSuccess) {
        NSMutableDictionary *dataQuery =
            [NSMutableDictionary dictionaryWithDictionary:(__bridge_transfer NSDictionary *)attrsRef];
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

    NSMutableDictionary *add = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        (__bridge id)kSecClassGenericPassword, (__bridge id)kSecClass,
        @"ApplicationUniqueID",                (__bridge id)kSecAttrAccount,
        service,                               (__bridge id)kSecAttrService,
        @"",                                   (__bridge id)kSecAttrLabel,
        @"",                                   (__bridge id)kSecAttrDescription,
        nil];
    if ([UIDevice.currentDevice.systemVersion compare:@"4.0" options:NSNumericSearch]
            != NSOrderedAscending) {
        add[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
    }
    add[(__bridge id)kSecValueData] = [result dataUsingEncoding:NSUTF8StringEncoding];
    SecItemAdd((__bridge CFDictionaryRef)add, nullptr);
    return result;
}

#pragma mark - Core Data stack

// -[AppDelegate managedObjectContext]  @ 0xa810
- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext == nil) {
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator != nil) {
            _managedObjectContext = [[NSManagedObjectContext alloc] init];
            [_managedObjectContext setPersistentStoreCoordinator:coordinator];
        }
    }
    return _managedObjectContext;
}

// -[AppDelegate managedObjectContextSub]  @ 0xa890
- (NSManagedObjectContext *)managedObjectContextSub {
    if (_managedObjectContextSub == nil) {
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator != nil) {
            _managedObjectContextSub = [[NSManagedObjectContext alloc] init];
            [_managedObjectContextSub setPersistentStoreCoordinator:coordinator];
        }
    }
    return _managedObjectContextSub;
}

// -[AppDelegate managedObjectModel]  @ 0xa910
- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel == nil) {
        NSString *path = [NSBundle.mainBundle pathForResource:@"ScoreData" ofType:@"momd"];
        NSURL *url = [NSURL fileURLWithPath:path];
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    }
    return _managedObjectModel;
}

// -[AppDelegate persistentStoreCoordinator]  @ 0xa9cc
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator == nil) {
        NSString *storePath = [[AppDelegate appDocumentsDirectory]
                               stringByAppendingPathComponent:@"ScoreData.sqlite"];
        NSURL *storeURL = [NSURL fileURLWithPath:storePath];

        // Lightweight migration enabled (ScoreData_v1 -> _v2 model).
        NSDictionary *options = @{
            NSMigratePersistentStoresAutomaticallyOption: @YES,
            NSInferMappingModelAutomaticallyOption: @YES,
        };

        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
                                       initWithManagedObjectModel:self.managedObjectModel];
        NSError *error = nil;
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                       configuration:nil
                                                                 URL:storeURL
                                                             options:options
                                                               error:&error]) {
            // The original aborts here on an unrecoverable store failure.
            abort();
        }
    }
    return _persistentStoreCoordinator;
}

@end
