//
//  StoreUtil.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StoreUtil.h"
#import "AppDelegate.h"
#import "RhUtil.h"
#import "UserSettingData.h"
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

// StoreKit product-identifier prefix (Ghidra: CFString cf_rhythmin_pack).
static NSString *const kPackProductPrefix = @"rhythmin_pack";

// Embedded digest salt — the game's internal codename. The digest slices
// characters [2, 27) out of it (Ghidra CFString @ 0x1065a3,
// substringWithRange:).
static NSString *const kReceiptSalt = @"Orbit Note Lumion Rhythmin Konami";

// Embedded salt appended to the purchase params before the SHA-256 "key" digest
// (Ghidra CFString @ 0x1064a8, used by purchasedURL:).
static NSString *const kPurchaseKeySalt = @"kdRhdvruVoJ1sUan4TJpsXYvgsSNG2yn";

// A game-API endpoint path. A source-only helper with no distinct binary
// function — the binary inlines this per getter, building "%@%@" of the single
// base CFString cf__apr_main_cgi_ and a "<name>/index.jsp" endpoint string. The
// base is byte-verified to be literally "/apr/main/cgi/" (all slashes; no
// "main.cgi" dot form exists anywhere in the binary).
static NSString *ApiPath(NSString *name) {
    return [NSString stringWithFormat:@"/apr/main/cgi/%@/index.jsp", name];
}

// Server hosts. The compile-time defaults come from CMake (APR_HOST /
// APR_SECURE_HOST / OFFICIAL_HOST); they fall back to the original binary's hosts
// when not defined, so a faithful build is unchanged.
#ifndef APR_HOST
#define APR_HOST "apr.konaminet.jp"
#endif
#ifndef APR_SECURE_HOST
#define APR_SECURE_HOST "apr.s.konaminet.jp"
#endif
#ifndef OFFICIAL_HOST
#define OFFICIAL_HOST "p.eagate.573.jp"
#endif
#ifndef KONAMI_ID_HOST
#define KONAMI_ID_HOST "id.konami.net"
#endif

// Resolve the effective host: the CMake/compile-time default, unless a preferences
// override is present. The override is honoured only in ENABLE_PATCHES builds so
// the faithful build never reads an out-of-band host; it lets a preservation build
// point at a private/revival server by adding the key to the app's .plist without
// rebuilding.
static NSString *ResolveHost(NSString *compileDefault, NSString *prefsKey) {
#ifdef ENABLE_PATCHES
    NSString *override = [NSUserDefaults.standardUserDefaults stringForKey:prefsKey];
    if (override.length > 0) {
        return override;
    }
#else
    (void)prefsKey;
#endif
    return compileDefault;
}

@implementation StoreUtil

// @ 0x58904 — returns the constant "JP" CFString @ 0x136e28 (char* 0x1063ca,
// length 2, byte-verified).
// @complete
+ (NSString *)targetStore {
    return @"JP";
}

// @ 0x589f4
// @complete
+ (NSURL *)createURL:(NSString *)path {
    NSString *host = ResolveHost(@APR_HOST, @"AprHost");
    // The binary used http here, but App Transport Security blocks cleartext on
    // the modern iOS this rebuild targets, so all endpoints use https (the hosts
    // are declared for ATS in Info.plist). Not an ENABLE_PATCHES change.
#if defined(__IPHONE_9_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"https";
    components.host = host;
    components.path = path;
    return components.URL;
#else
    return [[NSURL alloc] initWithScheme:@"https" host:host path:path];
#endif
}

// @ 0x58a58
// @complete
+ (NSURL *)createHttpsURL:(NSString *)path {
    // Ghidra: host CFString char* @ 0x106a3f is literally "apr.s.konaminet.jp"
    // (dots, not a hyphen); verified via read_memory of the CFString struct at
    // 0x1372c8 (length 18). Now the APR_SECURE_HOST default (overridable).
    NSString *host = ResolveHost(@APR_SECURE_HOST, @"AprSecureHost");
#if defined(__IPHONE_9_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"https";
    components.host = host;
    components.path = path;
    return components.URL;
#else
    return [[NSURL alloc] initWithScheme:@"https" host:host path:path];
#endif
}

// @ 0x59f24
// @complete
+ (NSURL *)createOfficialURL:(NSString *)path {
    NSString *host = ResolveHost(@OFFICIAL_HOST, @"OfficialHost");
    // https for modern-iOS ATS (see createURL); host declared in Info.plist.
#if defined(__IPHONE_9_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"https";
    components.host = host;
    components.path = path;
    return components.URL;
#else
    return [[NSURL alloc] initWithScheme:@"https" host:host path:path];
#endif
}

// The Konami ID quick-entry web page (InputKIDViewCtrl opens it). The host was a
// hardcoded https://id.konami.net URL in the binary; now the KONAMI_ID_HOST
// default, overridable like the others.
+ (NSURL *)konamiIdQuickEntryURL {
    NSString *host = ResolveHost(@KONAMI_ID_HOST, @"KonamiIdHost");
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"https";
    components.host = host;
    components.path = @"/quick/Entry";
    return components.URL;
}

// --- Game API endpoints (endpoint names byte-verified against Ghidra) ---
+ (NSURL *)getDlFileListURL {
    return [self createHttpsURL:ApiPath(@"get_dl_file_list")];
} // @ 0x599c8 @complete
+ (NSURL *)getFriendListURL {
    return [self createHttpsURL:ApiPath(@"get_friend_list")];
} // @ 0x594a8 @complete
+ (NSURL *)getEventInfoURL {
    return [self createHttpsURL:ApiPath(@"get_event_info")];
} // @ 0x59d94 @complete
+ (NSURL *)getConvertCodeURL {
    return [self createHttpsURL:ApiPath(@"get_convert_code")];
} // @ 0x59e00 @complete
+ (NSURL *)convertURL {
    return [self createHttpsURL:ApiPath(@"convert")];
} // @ 0x59e6c @complete

// --- Friend actions (endpoint names byte-verified against Ghidra) ---
+ (NSURL *)requestFriendURL {
    return [self createHttpsURL:ApiPath(@"request_friend")];
} // @ 0x59220 @complete
+ (NSURL *)replyFriendURL {
    return [self createHttpsURL:ApiPath(@"reply_friend")];
} // @ 0x5928c @complete
+ (NSURL *)removeFriendURL {
    return [self createHttpsURL:ApiPath(@"remove_friend")];
} // @ 0x5943c @complete
+ (NSURL *)getRecommendFriendURL {
    return [self createHttpsURL:ApiPath(@"get_recommend_friend")];
} // @ 0x59a34 @complete
+ (NSURL *)saveTreasureURL {
    return [self createHttpsURL:ApiPath(@"save_treasure")];
} // @ 0x59884 @complete

// @ 0x59740 — the recommended-pack endpoint. Path is the shared base
// "/apr/main/cgi/" (the single base CFString cf__apr_main_cgi_ @ 0x106a30) plus
// "pack_recommend/index.jsp". It is written out as two literals rather than via
// ApiPath, but the base is identical to every other endpoint here.
// @complete
+ (NSURL *)recommendPackURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@",
                                                           @"/apr/main/cgi/",
                                                           @"pack_recommend/index.jsp"]];
}

// @ 0x59148 — the invite-code redemption endpoint. Same literal-path form as
// recommendPackURL (byte-verified "/apr/main/cgi/" slashes) plus
// "invited/index.jsp".
// @complete
+ (NSURL *)invitedURL {
    return [self
        createHttpsURL:[NSString
                           stringWithFormat:@"%@%@", @"/apr/main/cgi/", @"invited/index.jsp"]];
}

// @ 0x59070 — the "register a new player name" endpoint. Same literal-path form
// (byte-verified "/apr/main/cgi/" slashes) plus "new_player/index.jsp".
// @complete
+ (NSURL *)playerNewURL {
    return [self
        createHttpsURL:[NSString
                           stringWithFormat:@"%@%@", @"/apr/main/cgi/", @"new_player/index.jsp"]];
}

// @ 0x598f0 — the pop'n-link (KONAMI ID) linking endpoint. Same literal-path
// form (byte-verified "/apr/main/cgi/" slashes) plus "link_kid/index.jsp".
// @complete
+ (NSURL *)linkKidURL {
    return [self
        createHttpsURL:[NSString
                           stringWithFormat:@"%@%@", @"/apr/main/cgi/", @"link_kid/index.jsp"]];
}

// --- Game API endpoints (name derived from the selector; identical pattern)
// ---
+ (NSURL *)getFriendRequestURL {
    return [self createHttpsURL:ApiPath(@"get_friend_request")];
} // @ 0x592f8 @complete
+ (NSURL *)getFriendScoreURL {
    return [self createHttpsURL:ApiPath(@"get_friend_score")];
} // @ 0x59364 @complete
+ (NSURL *)getArcadeScoreURL {
    return [self createHttpsURL:ApiPath(@"get_arcade_score")];
} // @ 0x5995c @complete
+ (NSURL *)getOverScoreLogURL {
    return [self createHttpsURL:ApiPath(@"get_over_score_log")];
} // @ 0x59d28 @complete
// The endpoint name is one word "blocklist" (no underscore); Ghidra string @
// 0x106844 is "get_blocklist/index.jsp" (byte-verified).
// @complete
+ (NSURL *)getBlockListURL {
    return [self createHttpsURL:ApiPath(@"get_blocklist")];
} // @ 0x59580
// Endpoint name "add_blocklist" (one word); Ghidra string @ 0x10685c.
// @complete
+ (NSURL *)addBlockListURL {
    return [self createHttpsURL:ApiPath(@"add_blocklist")];
} // @ 0x59514
// Endpoint name "del_blocklist" (one word); Ghidra string @ 0x10682c.
// @complete
+ (NSURL *)delBlockListURL {
    return [self createHttpsURL:ApiPath(@"del_blocklist")];
} // @ 0x595ec
+ (NSURL *)cancelFriendURL {
    return [self createHttpsURL:ApiPath(@"cancel_friend")];
} // @ 0x593d0 @complete

// @ 0x59658 / 0x596cc — daily-quiz endpoints. Path is the shared base
// "/apr/main/cgi/" + "<name>/index.jsp" plus a "?target=JP" query (Ghidra fmt
// "%@%@?target=%@", store "JP").
// @complete
+ (NSURL *)getQuizURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@?target=%@",
                                                           @"/apr/main/cgi/",
                                                           @"get_quiz/index.jsp",
                                                           @"JP"]];
}
// @ 0x596cc — reply-quiz endpoint (same shape as getQuizURL).
// @complete
+ (NSURL *)replyQuizURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@?target=%@",
                                                           @"/apr/main/cgi/",
                                                           @"reply_quiz/index.jsp",
                                                           @"JP"]];
}

// @ 0x59f88 — official app-info page. The binary composes it as two literals
// ("/game/popn/rhythmin/" + "app/appinfo.html"); joined here into one literal
// for readability (identical result).
// @complete
+ (NSURL *)getOfficialAppInfoURL {
    return [self createOfficialURL:@"/game/popn/rhythmin/app/appinfo.html"];
}

// --- StoreKit helpers ---

// @ 0x5a16c — currency-formatted price via NSNumberFormatter using the
// product's own priceLocale. Behavior 10.4, NSNumberFormatterCurrencyStyle.
// The nil-product fallback is the placeholder CFString @ 0x136f58, a UTF-16
// constant byte-verified as "¥573" (U+FFE5 fullwidth yen sign followed by
// "573"), not an empty string.
// @complete
+ (NSString *)priceString:(SKProduct *)product {
    if (product == nil) {
        return @"¥573";
    }
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [formatter setLocale:product.priceLocale];
    NSString *result = [formatter stringFromNumber:product.price];
    return result;
}

// @ 0x5a088 — "rhythmin_pack" + zero-padded 4-digit id; nil for non-positive
// ids.
// @complete
+ (NSString *)productIDForPackID:(int)packID {
    if (packID < 1) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@%04d", kPackProductPrefix, packID];
}

// @ 0x5a400 — Japan youth-spending-limit check: can a purchase of `price` yen
// proceed? Age is derived from the saved birthday (defaulting to 14 when none
// is set); 18+ has no limit. Under-16 is capped at 5000 yen/month, 16-17 at
// 10000 yen/month, counting the running monthly total (reset implicitly when
// the stored month no longer matches now).
// @complete
+ (BOOL)isPurchasable:(unsigned int)price {
    NSDate *birthDay = [UserSettingData birthDay];
    NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *now = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth)
                                   fromDate:[NSDate date]];

    NSInteger age;
    if (birthDay == nil) {
        age = 14; // no recorded birthday -> treated as a minor
    } else {
        // Age as of the 1st of this month at noon (parsed back through a formatter
        // so the day/time are pinned, matching the binary). The date-format
        // CFString @ 0x1065c5 is "yyyy/MM/dd HH:mm:ss" (slashes, a space before
        // the time) and the build format @ 0x1065d9 is "%04lu/%02lu/01 12:00:00"
        // (unsigned long, slashes, space) — both byte-verified.
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy/MM/dd HH:mm:ss";
        NSString *cutoffStr = [NSString stringWithFormat:@"%04lu/%02lu/01 12:00:00",
                                                         (unsigned long)now.year,
                                                         (unsigned long)now.month];
        NSDate *cutoff = [fmt dateFromString:cutoffStr];
        NSDateComponents *span =
            [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                   fromDate:birthDay
                     toDate:cutoff
                    options:0];
        age = span.year;
        if (age > 17) {
            return YES; // adult: no spending limit
        }
    }

    int spent = 0;
    NSDate *lastUpdate = [UserSettingData lastUpdateSumPurchase];
    if (lastUpdate != nil) {
        NSDateComponents *last = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth)
                                        fromDate:lastUpdate];
        if (last.year == now.year && last.month == now.month) {
            spent = [UserSettingData sumPurchase]; // same month: include the running total
        }
    }

    unsigned int limit = (age < 16) ? 5001 : 10001; // 0x1389 / 0x2711
    return (price + spent) < limit;
}

// @ 0x5a0d0 — strip the prefix and read the trailing integer; -1 on mismatch.
// @complete
+ (int)packIDForProductID:(NSString *)productID {
    if (productID.length <= kPackProductPrefix.length) {
        return -1;
    }
    if (![productID hasPrefix:kPackProductPrefix]) {
        return -1;
    }
    int packID = [[productID substringFromIndex:kPackProductPrefix.length] intValue];
    return packID > 0 ? packID : -1;
}

// --- Receipt verification ---

// @ 0x58f04
// @complete
+ (NSURL *)receiptURL {
    return [self createHttpsURL:ApiPath(@"verify_receipt")];
}

// @ 0x58830 — the binary branches on idiom == UIUserInterfaceIdiomPhone (0):
// phone returns "iphone", every other idiom returns "ipad" (not an explicit
// pad test).
// @complete
+ (NSString *)deviceName {
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return @"iphone";
    }
    return @"ipad";
}

// @ 0x58880 — computed once, then cached (Ghidra global g_pStoreIdentifierParams
// @ DAT_001882f4). The binary retains the MD5 result before storing it; the
// static strong reference here is the ARC-faithful equivalent.
// @complete
+ (NSString *)identifierParams {
    static NSString *sIdentifierParams = nil;
    if (sIdentifierParams != nil) {
        return sIdentifierParams;
    }
    NSString *seed = [[AppDelegate appDelegate].uuId stringByAppendingString:@"STORE"];
    sIdentifierParams = ComputeMD5HexString(seed.UTF8String);
    return sIdentifierParams;
}

// @ 0x5a2ac — wrap the receipt with client info for the verify endpoint. The
// JSON format CFString @ 0x10653c is byte-verified identical to the literal
// below.
// @complete
+ (NSString *)createReceiptCheckJSON:(NSString *)base64Receipt {
    AppDelegate *app = [AppDelegate appDelegate];
    return [NSString stringWithFormat:@"{\"receipt_data\":\"%@\",\"client_info\":{\"uuid\":\"%"
                                      @"@\",\"version\":\"%@\","
                                      @"\"device\":\"%@\",\"os\":\"%@\",\"locale\":\"%@\"}}",
                                      base64Receipt,
                                      [self identifierParams],
                                      [app appVersion],
                                      [self deviceName],
                                      [app osVersion],
                                      [app localeString]];
}

// @ 0x5a394 — SHA-256 hex of (salt[2,27) + json). Range is substringWithRange(2,
// 27) of kReceiptSalt @ 0x1065a3, format "%@%@" (byte-verified).
// @complete
+ (NSString *)createReceiptChecckDigest:(NSString *)json {
    NSString *salt = [kReceiptSalt substringWithRange:NSMakeRange(2, 27)];
    NSString *seed = [NSString stringWithFormat:@"%@%@", salt, json];
    return ComputeSHA256HexString(seed.UTF8String);
}

// @ 0x5a240 — must be an http(s) string that NSURL accepts.
// @complete
+ (BOOL)isValidURL:(NSString *)urlString {
    if (![urlString hasPrefix:@"http://"] && ![urlString hasPrefix:@"https://"]) {
        return NO;
    }
    return [NSURL URLWithString:urlString] != nil;
}

// --- Store catalogue ---

// @ 0x58910 — the client-info query fragment shared by catalogue requests.
// Format "uuid=%@&version=%@&device=%@&os=%@&locale=%@" (byte-verified).
// @complete
+ (NSString *)userInfo {
    AppDelegate *app = [AppDelegate appDelegate];
    return [NSString stringWithFormat:@"uuid=%@&version=%@&device=%@&os=%@&locale=%@",
                                      [self identifierParams],
                                      [app appVersion],
                                      [self deviceName],
                                      [app osVersion],
                                      [app localeString]];
}

// @ 0x58abc —
// /apr/main/cgi/packlist/index.jsp?target=JP&head=..&limit=..&<userInfo> with
// an optional &pack_id=.. seed.
// @complete
+ (NSURL *)packListURL:(unsigned int)head limit:(unsigned int)limit packId:(int)packId {
    NSString *path = [NSString stringWithFormat:@"%@%@?target=%@&head=%d&limit=%d&%@",
                                                @"/apr/main/cgi/",
                                                @"packlist/index.jsp",
                                                [self targetStore],
                                                head,
                                                limit,
                                                [self userInfo]];
    if (packId > 0) {
        path = [NSString stringWithFormat:@"%@&pack_id=%d", path, packId];
    }
    return [self createHttpsURL:path];
}

// @ 0x58b80 — /apr/main/cgi/packinfo/index.jsp?target=JP&pack=<id>[&<userInfo>]
// @complete
+ (NSURL *)packInfoURL:(unsigned int)packID UserOpen:(BOOL)userOpen {
    NSString *path;
    if (userOpen) {
        path = [NSString stringWithFormat:@"%@%@?target=%@&pack=%d&%@",
                                          @"/apr/main/cgi/",
                                          @"packinfo/index.jsp",
                                          [self targetStore],
                                          packID,
                                          [self userInfo]];
    } else {
        path = [NSString stringWithFormat:@"%@%@?target=%@&pack=%d",
                                          @"/apr/main/cgi/",
                                          @"packinfo/index.jsp",
                                          [self targetStore],
                                          packID];
    }
    return [self createHttpsURL:path];
}

// @ 0x58c5c — store per-song info page:
// /apr/main/cgi/musicinfo/index.jsp?target=JP&music=<id>&<userInfo>
// @complete
+ (NSURL *)musicInfoURL:(unsigned int)musicId {
    NSString *path = [NSString stringWithFormat:@"%@%@?target=%@&music=%d&%@",
                                                @"/apr/main/cgi/",
                                                @"musicinfo/index.jsp",
                                                [self targetStore],
                                                musicId,
                                                [self userInfo]];
    return [self createHttpsURL:path];
}

// @ 0x58cf4 — arcade-viewer per-song info page:
// /apr/main/cgi/acv_musicinfo/index.jsp?target=JP&music=<id>&<userInfo>
// @complete
+ (NSURL *)acvMusicInfoURL:(unsigned int)acMusicId {
    NSString *path = [NSString stringWithFormat:@"%@%@?target=%@&music=%d&%@",
                                                @"/apr/main/cgi/",
                                                @"acv_musicinfo/index.jsp",
                                                [self targetStore],
                                                acMusicId,
                                                [self userInfo]];
    return [self createHttpsURL:path];
}

// @ 0x59b0c — arcade-viewer play-log POST endpoint:
// https://apr.s.konaminet.jp/apr/main/cgi/log_acv_play/index.jsp
// @complete
+ (NSURL *)logAcvPlayURL {
    return [self
        createHttpsURL:[NSString
                           stringWithFormat:@"%@%@", @"/apr/main/cgi/", @"log_acv_play/index.jsp"]];
}

// @ 0x58f70 — arcade-locator master feed (marker images + arcade/model info):
// https://apr.s.konaminet.jp/apr/main/cgi/search_master/index.jsp?target=JP&<userInfo>
// The format CFString @ 0x106482 is "%@%@?target=%@&%@" (length 17): a literal
// "&" separates target from the userInfo suffix (byte-verified).
// @complete
+ (NSURL *)searchMasterURL {
    NSString *path = [NSString stringWithFormat:@"%@%@?target=%@&%@",
                                                @"/apr/main/cgi/",
                                                @"search_master/index.jsp",
                                                [self targetStore],
                                                [self userInfo]];
    return [self createHttpsURL:path];
}

// @ 0x59004 — per-region arcade query (POST lat/long/range body attached by the
// caller): https://apr.s.konaminet.jp/apr/main/cgi/gamecenter/index.jsp
// @complete
+ (NSURL *)searchURL {
    return [self
        createHttpsURL:[NSString
                           stringWithFormat:@"%@%@", @"/apr/main/cgi/", @"gamecenter/index.jsp"]];
}

// @ 0x59ed8 — the official eAmusement site base string:
// "http://p.eagate.573.jp/game/popn/rhythmin/".
// @complete
+ (NSString *)getOfficialPath {
    return [NSString stringWithFormat:@"http://%@%@", @"p.eagate.573.jp", @"/game/popn/rhythmin/"];
}

// @ 0x5a060 — official pop'n team Twitter page.
// @complete
+ (NSURL *)getOfficialTwitterURL {
    return [NSURL URLWithString:@"https://twitter.com/popn_team"];
}

// --- Recovered store / player / present endpoints ---
// All use the byte-verified slash-form base "/apr/main/cgi/" (like
// recommendPackURL).

// @ 0x58d8c — "register/refresh player" info feed:
// https://apr.s.konaminet.jp/apr/main/cgi/new/index.jsp?target=JP&<userInfo>
// Format "%@%@?target=%@&%@" (the "&" before userInfo is byte-verified).
// @complete
+ (NSURL *)storeNewInfoURL {
    NSString *path = [NSString stringWithFormat:@"%@%@?target=%@&%@",
                                                @"/apr/main/cgi/",
                                                @"new/index.jsp",
                                                @"JP",
                                                [self userInfo]];
    return [self createHttpsURL:path];
}

// @ 0x58e20 — report a completed purchase:
// https://.../apr/main/cgi/purchase/index.jsp?target=JP&pid=<pid>&<userInfo>&key=<sha256>
// where key = SHA-256 hex of ("target=JP&pid=<pid>&<userInfo>" +
// kPurchaseKeySalt). Params format "target=%@&pid=%d&%@", final format
// "%@%@?%@&key=%@", salt kPurchaseKeySalt @ 0x1064a8 (all byte-verified).
// @complete
+ (NSURL *)purchasedURL:(unsigned int)pid {
    NSString *params =
        [NSString stringWithFormat:@"target=%@&pid=%d&%@", @"JP", pid, [self userInfo]];
    NSString *salted = [params stringByAppendingString:kPurchaseKeySalt];
    NSString *key = ComputeSHA256HexString(salted.UTF8String);
    NSString *path = [NSString
        stringWithFormat:@"%@%@?%@&key=%@", @"/apr/main/cgi/", @"purchase/index.jsp", params, key];
    return [self createHttpsURL:path];
}

// @ 0x590dc — https://.../apr/main/cgi/get_player/index.jsp
// @complete
+ (NSURL *)playerGetURL {
    return [self
        createHttpsURL:[NSString
                           stringWithFormat:@"%@%@", @"/apr/main/cgi/", @"get_player/index.jsp"]];
}

// @ 0x591b4 — https://.../apr/main/cgi/save_score/index.jsp
// @complete
+ (NSURL *)saveScoreURL {
    return [self
        createHttpsURL:[NSString
                           stringWithFormat:@"%@%@", @"/apr/main/cgi/", @"save_score/index.jsp"]];
}

// @ 0x597ac — https://.../apr/main/cgi/get_recommend_list/index.jsp
// @complete
+ (NSURL *)getRecommendListURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@",
                                                           @"/apr/main/cgi/",
                                                           @"get_recommend_list/index.jsp"]];
}

// @ 0x59818 — https://.../apr/main/cgi/get_visitor/index.jsp
// @complete
+ (NSURL *)getVisitorURL {
    return [self
        createHttpsURL:[NSString
                           stringWithFormat:@"%@%@", @"/apr/main/cgi/", @"get_visitor/index.jsp"]];
}

// @ 0x59aa0 — https://.../apr/main/cgi/log_chara_kuji/index.jsp
// @complete
+ (NSURL *)logCharaKujiURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@",
                                                           @"/apr/main/cgi/",
                                                           @"log_chara_kuji/index.jsp"]];
}

// @ 0x59b78 — https://.../apr/main/cgi/save_apns_token/index.jsp
// @complete
+ (NSURL *)saveApnsTokenURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@",
                                                           @"/apr/main/cgi/",
                                                           @"save_apns_token/index.jsp"]];
}

// @ 0x59be4 — https://.../apr/main/cgi/get_reward_login_token/index.jsp
// @complete
+ (NSURL *)getRewardLoginTokenURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@",
                                                           @"/apr/main/cgi/",
                                                           @"get_reward_login_token/index.jsp"]];
}

// @ 0x59c50 — https://.../apr/main/cgi/get_present_list/index.jsp
// @complete
+ (NSURL *)getPresentListURL {
    return [self createHttpsURL:[NSString stringWithFormat:@"%@%@",
                                                           @"/apr/main/cgi/",
                                                           @"get_present_list/index.jsp"]];
}

// @ 0x59cbc — https://.../apr/main/cgi/get_present/index.jsp
// @complete
+ (NSURL *)getPresentURL {
    return [self
        createHttpsURL:[NSString
                           stringWithFormat:@"%@%@", @"/apr/main/cgi/", @"get_present/index.jsp"]];
}

// @ 0x59ff4 — official eAmusement "old info" page:
// http://p.eagate.573.jp/game/popn/rhythmin/app/old_info.html
// @complete
+ (NSURL *)getOfficialOldInfoURL {
    return [self createOfficialURL:[NSString stringWithFormat:@"%@%@",
                                                              @"/game/popn/rhythmin/",
                                                              @"app/old_info.html"]];
}

@end

// @ 0x5c5ec — percent-encode a string for use in a URL query. Escapes the
// reserved set "!*'();:@&=+$,/?%#[]" (byte-verified @ 0x106c29) using UTF-8
// (encoding 0x8000100 = kCFStringEncodingUTF8). nil in -> nil out.
// @complete
NSString *urlEncodeString(NSString *s) {
    if (s == nil) {
        return nil;
    }
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    // Escape everything except the RFC 3986 unreserved set, which is the
    // complement of the reserved set the original escaped explicitly.
    NSMutableCharacterSet *allowed = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
    [allowed addCharactersInString:@"-_.~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed];
#else
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault,
        (__bridge CFStringRef)s,
        NULL,
        CFSTR("!*'();:@&=+$,/?%#[]"),
        kCFStringEncodingUTF8);
#endif
}
