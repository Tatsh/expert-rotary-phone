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

#import <GameKit/GameKit.h>
#import <Security/Security.h>
#import <StoreKit/StoreKit.h>
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
#import "RewardNetwork.h"   // applilink reward SDK: +startWithAppliId:env:callback:
#import "StoreUtil.h"
#import "TreasureData+Store.h"
#import "TreasureData.h"
#import "UserSettingData.h"
#import "neEngineBridge.h"
#import "neGraphics.h"
#import "neWindow.h"

// The launch path starts the applilink reward SDK via +[RewardNetwork
// startWithAppliId:env:callback:] (reconstructed 1:1; see -application:didFinishLaunching...).

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

// -[AppDelegate dealloc]  @ 0x8c74 — ARC-omitted.
// The original only released the three owned objects (window, viewController,
// strageAlert) and chained to [super dealloc]; ARC synthesizes all of that, so
// no explicit dealloc is needed (object-only teardown).

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
    // MODERNIZATION (not in the 2.0.3 binary): the original does [window addSubview:vc.view]
    // (Ghidra 0x8cf0, the pre-iOS-6 idiom) with no rootViewController. iOS 13+ requires the key
    // window to have a rootViewController by the end of launch, else -[UIApplication
    // _runWithMainScene:...] throws "Application windows are expected to have a root view
    // controller at the end of application launch" -> uncaught NSException -> SIGABRT. Assigning
    // rootViewController is the modern equivalent (it installs vc.view as the window's content),
    // so it preserves the original intent while letting the reconstruction launch on iOS 13+.
    self.window.rootViewController = self.viewController;
    neSceneManager::shared().attachRoot(self.viewController); // Ghidra: FUN_0002c5b8
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

    // Start the applilink reward SDK (appli id 24, env "0").
    _rewardAppId = [NSString stringWithFormat:@"%d", 24];
    [RewardNetwork startWithAppliId:_rewardAppId env:@"0" callback:^(NSError *error) {
        // The launch flow does not act on the applilink start result.
        (void)error;
    }];

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
        [NSTimer scheduledTimerWithTimeInterval:/* interval @ DAT_00009560 = 300.0 */ 300.0
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
    // Ghidra @ 0x95d6: reads AcNoteMng+0x14cc2 (m_playFlag), NOT the launched-from-push global.
    // Disassembly: base 0x15f1b0 (AcNoteMng singleton) + 0x14cc2 = 0x173e72.
    if (AcNoteMng::shared().isPlaying()) {
        // Ghidra: acNotePause (FUN_0007b638) on the global AcNoteMng — pause arcade play on resign.
        AcNoteMng::shared().pause();
    }

    [[AudioManager sharedManager] systemSuspend];

    // Remember whether we were actively looping (and not paused) so we can
    // resume on reactivation.
    BOOL resume = NO;
    if (![self.viewController isPause]) {
        resume = [self.viewController isLoop];
    }
    _isNecessaryToResume = resume;
    [self.viewController PauseLoop];

    if (_mainTask)   neEngine::stopMainTask(static_cast<MainTask *>(_mainTask));      // Ghidra: FUN_00030710
    if (_acMainTask) neEngine::stopAcMainTask(static_cast<AcMainTask *>(_acMainTask));  // Ghidra: FUN_0002314c

    // If a resume is expected, pump the loop so the last frames are flushed
    // (the binary calls mainLoop three times here).
    if (_isNecessaryToResume) {
        [self.viewController mainLoop];
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
    // Flag a pending push so the music-select recommend list refetches on the next visit
    // (Ghidra: g_bRemoteNotifyPending = true — distinct from gLaunchedFromPush @ 0x187b5a).
    neAppEventCenter::shared().setRemoteNotifyPending(true);
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

// -[AppDelegate appAppSupportDirectory]  @ 0x8a1c — downloadable data (rhythmin.lv, chr, ...).
+ (NSString *)appAppSupportDirectory {
    return NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                               NSUserDomainMask, YES).lastObject;
}

// +[AppDelegate addSkipBackupAttributeToItemAtURL:]  @ 0x8af8
// Mark an existing file/dir as excluded from iCloud/iTunes backup
// (NSURLIsExcludedFromBackupKey). The binary asserts the item already exists.
+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL {
    NSAssert([NSFileManager.defaultManager fileExistsAtPath:URL.path],
             @"[[NSFileManager defaultManager] fileExistsAtPath:[URL path]]");
    NSError *error = nil;
    BOOL success = [URL setResourceValue:@YES
                                  forKey:NSURLIsExcludedFromBackupKey
                                   error:&error];
    if (!success) {
        NSLog(@"Error excluding %@ from backup %@", URL.lastPathComponent, error);
    }
    return success;
}

// -[AppDelegate appCachesDirectory] — Caches dir, holds dev-data downloads.  @ 0x89f8
+ (NSString *)appCachesDirectory {
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
}

// -[AppDelegate freeFileSystemSize]  @ 0x8be8
+ (unsigned long long)freeFileSystemSize {
    NSDictionary *attrs = [NSFileManager.defaultManager
        attributesOfFileSystemForPath:[self appDocumentsDirectory] error:nil];
    return [[attrs valueForKey:NSFileSystemFreeSize] longLongValue];
}

// -[AppDelegate hardwareType]  @ 0xb13c
- (int)hardwareType { return _hardwareType; }
// displayType is a synthesized atomic getter (@ 0xb0a8); _displayType is written
// directly in initHardware.

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
                    _displayType = ((i >= 25 && i <= 33) || i == 37 || i == 38) ? 4 : 5;
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

// -[AppDelegate deleteUuid]  @ 0x9c20
// Removes the persisted install UUID keychain item (account "ApplicationUniqueID").
- (void)deleteUuid {
    NSString *service = NSBundle.mainBundle.bundleIdentifier;
    NSDictionary *query = @{
        (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount:      @"ApplicationUniqueID",
        (__bridge id)kSecAttrService:      service,
        (__bridge id)kSecMatchLimit:       (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef attrsRef = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &attrsRef) == errSecSuccess) {
        NSDictionary *deleteQuery = @{
            (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrAccount: @"ApplicationUniqueID",
            (__bridge id)kSecAttrService: service,
            (__bridge id)kSecMatchLimit:  (__bridge id)kSecMatchLimitOne,
            // kSecReturnAttributes/kCFBooleanTrue carried over from the match query.
            (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
        };
        SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    }
}

#pragma mark - Settings-version keychain record

// -[AppDelegate setUsersettingVer:]  @ 0x9d58
// Stores (adds or updates) the settings version string in a keychain generic-
// password item keyed on account "UserSettingVer".
- (void)setUsersettingVer:(NSString *)ver {
    NSData *data = [ver dataUsingEncoding:NSUTF8StringEncoding];
    NSString *service = NSBundle.mainBundle.bundleIdentifier;

    NSDictionary *query = @{
        (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount:      @"UserSettingVer",
        (__bridge id)kSecAttrService:      service,
        (__bridge id)kSecMatchLimit:       (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef found = nullptr;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &found);

    if (status == errSecItemNotFound) {
        // No record yet — add one.
        NSMutableDictionary *add = [NSMutableDictionary dictionary];
        add[(__bridge id)kSecClass]       = (__bridge id)kSecClassGenericPassword;
        add[(__bridge id)kSecAttrAccount] = @"UserSettingVer";
        add[(__bridge id)kSecValueData]   = data;
        add[(__bridge id)kSecAttrService] = NSBundle.mainBundle.bundleIdentifier;
        add[(__bridge id)kSecAttrLabel]       = @"";
        add[(__bridge id)kSecAttrDescription] = @"";
        add[(__bridge id)kSecAttrAccessible]  =
            (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
        if (SecItemAdd((__bridge CFDictionaryRef)add, nullptr) == errSecSuccess) {
            NSLog(@"setUsersettingVer add success.");
        } else {
            NSLog(@"setUsersettingVer add error. (%d)", (int)status);
        }
    } else if (status == errSecSuccess) {
        // Record exists — update its data + modification date.
        NSMutableDictionary *update = [NSMutableDictionary dictionary];
        update[(__bridge id)kSecValueData]              = data;
        update[(__bridge id)kSecAttrModificationDate]   = [NSDate date];
        if (SecItemUpdate((__bridge CFDictionaryRef)query,
                          (__bridge CFDictionaryRef)update) == errSecSuccess) {
            NSLog(@"setUsersettingVer update success.");
        } else {
            NSLog(@"setUsersettingVer update error. (%d)", (int)status);
        }
    }
}

// -[AppDelegate getUsersettingVer]  @ 0xa044
// Reads the stored settings version; returns @"0" when there is no record.
- (NSString *)getUsersettingVer {
    NSDictionary *query = @{
        (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount:      @"UserSettingVer",
        (__bridge id)kSecAttrService:      NSBundle.mainBundle.bundleIdentifier,
        (__bridge id)kSecMatchLimit:       (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef attrsRef = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &attrsRef) == errSecSuccess) {
        NSMutableDictionary *dataQuery =
            [NSMutableDictionary dictionaryWithDictionary:(__bridge_transfer NSDictionary *)attrsRef];
        dataQuery[(__bridge id)kSecClass]      = (__bridge id)kSecClassGenericPassword;
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
    return [NSString stringWithFormat:@"%@", @"0"];
}

// -[AppDelegate deleteUsersettingVer]  @ 0xa270
- (void)deleteUsersettingVer {
    NSString *service = NSBundle.mainBundle.bundleIdentifier;
    NSDictionary *query = @{
        (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount:      @"UserSettingVer",
        (__bridge id)kSecAttrService:      service,
        (__bridge id)kSecMatchLimit:       (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef attrsRef = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &attrsRef) == errSecSuccess) {
        NSDictionary *deleteQuery = @{
            (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrAccount:      @"UserSettingVer",
            (__bridge id)kSecAttrService:      service,
            (__bridge id)kSecMatchLimit:       (__bridge id)kSecMatchLimitOne,
            (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
        };
        SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    }
}

#pragma mark - Environment strings

// -[AppDelegate userAgent]  @ 0xa3a8 — defensive copy of the cached UA string
// (built in application:didFinishLaunchingWithOptions:).
- (NSString *)userAgent {
    return [NSString stringWithString:_userAgent];
}

// -[AppDelegate appVersion]  @ 0xa408 — the bundle build number.
- (NSString *)appVersion {
    return NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];
}

// -[AppDelegate appVersionNum]  @ 0xa458 — build number with dots stripped,
// parsed as an integer ("2.0.3" -> 203).
- (int)appVersionNum {
    NSString *stripped = [self.appVersion stringByReplacingOccurrencesOfString:@"."
                                                                    withString:@""];
    return [stripped intValue];
}

// -[AppDelegate osVersion]  @ 0xa3d4
- (NSString *)osVersion {
    return UIDevice.currentDevice.systemVersion;
}

// -[AppDelegate localeLanguage]  @ 0xa548
- (NSString *)localeLanguage {
    return [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode];
}

// -[AppDelegate localeCountry]  @ 0xa504
- (NSString *)localeCountry {
    return [NSLocale.currentLocale objectForKey:NSLocaleCountryCode];
}

// -[AppDelegate localeString]  @ 0xa4a4 — "<language>_<country>", e.g. "ja_JP".
- (NSString *)localeString {
    return [NSString stringWithFormat:@"%@_%@", self.localeLanguage, self.localeCountry];
}

#pragma mark - StoreKit / purchases

// -[AppDelegate finishRequest:]  @ 0xab44
// PurchaseManager hands back the fetched SKProduct list; cache it and touch the
// first element (as in the original).
- (void)finishRequest:(NSArray *)products {
    _products = products;
    if (_products.count == 0) {
        return;
    }
    (void)[_products objectAtIndex:0];
}

// -[AppDelegate purchaseSucceeded:]  @ 0xab9c — PurchaseManager delegate.
- (void)purchaseSucceeded:(id)transaction {
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"Succeeded"
                                       message:@"購入処理が完了しました。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
}

// -[AppDelegate purchaseFailed:error:]  @ 0xac24 — PurchaseManager delegate.
- (void)purchaseFailed:(id)transaction error:(NSError *)error {
    CommonAlertView *alert =
        [[CommonAlertView alloc] initWithTitle:@"Failed"
                                       message:@"購入処理が失敗しました。"
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK"];
    [alert show];
}

// -[AppDelegate getProduct:]  @ 0xacac
// Linear search of the cached product list for a matching productIdentifier.
- (SKProduct *)getProduct:(NSString *)productId {
    if (self.products != nil) {
        for (NSUInteger i = 0; i < self.products.count; i++) {
            SKProduct *product = [self.products objectAtIndex:i];
            if (product != nil &&
                [product.productIdentifier isEqualToString:productId]) {
                return product;
            }
        }
    }
    return nil;
}

#pragma mark - Game Center

// -[AppDelegate loginGameCenter]  @ 0xb00c
// Authenticates the local Game Center player. The iOS 6 authenticate handler is
// invoked with a login view controller to present (or nil once resolved).
- (void)loginGameCenter {
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    localPlayer.authenticateHandler =
        ^(UIViewController *viewController, NSError *error) {
            // Block invoke @ 0xb07c (copy helper @ 0xb094, dispose @ 0xb0a0);
            // captures self. Reconstructed from the Thumb block: presents the
            // supplied login UI when Game Center asks for it.
            if (viewController != nil) {
                [self.viewController presentViewController:viewController
                                                 animated:YES
                                               completion:nil];
            }
        };
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
