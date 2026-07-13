//
//  StoreUtil.h
//  pop'n rhythmin
//
//  Server configuration + URL builder for the app's web APIs. All endpoints are
//  built through three base URLs (the game API over http/https, and the
//  official eAmusement site) and a per-endpoint path. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin (StoreUtil @ 0x58904..0x5a060).
//

#import <Foundation/Foundation.h>

@class SKProduct;

@interface StoreUtil : NSObject

// The store/region code sent as Accept-Language. Ghidra: targetStore @ 0x58904
// = "JP".
+ (NSString *)targetStore;

// Base URL builders. Ghidra: createURL: 0x589f4 (http://apr.konaminet.jp),
// createHttpsURL: 0x58a58 (https://apr-s.konaminet.jp), createOfficialURL:
// 0x59f24 (http://p.eagate.573.jp).
+ (NSURL *)createURL:(NSString *)path;
+ (NSURL *)createHttpsURL:(NSString *)path;
+ (NSURL *)createOfficialURL:(NSString *)path;

// Game API endpoints (all /apr/main.cgi/<name>/index.jsp over https). Endpoint
// names are verified where noted; the rest follow the identical pattern derived
// from the selector.
+ (NSURL *)getDlFileListURL;      // 0x599c8  get_dl_file_list   (verified)
+ (NSURL *)getFriendListURL;      // 0x594a8  get_friend_list    (verified)
+ (NSURL *)getEventInfoURL;       // 0x59d94  get_event_info     (verified)
+ (NSURL *)getConvertCodeURL;     // 0x59e00  get_convert_code   (verified)
+ (NSURL *)convertURL;            // 0x59e6c  convert            (verified)
+ (NSURL *)getFriendRequestURL;   // 0x592f8  get_friend_request
+ (NSURL *)getFriendScoreURL;     // 0x59364  get_friend_score
+ (NSURL *)requestFriendURL;      // 0x59220  request_friend        (verified)
+ (NSURL *)replyFriendURL;        // 0x5928c  reply_friend          (verified)
+ (NSURL *)removeFriendURL;       // 0x5943c  remove_friend         (verified)
+ (NSURL *)getRecommendFriendURL; // 0x59a34  get_recommend_friend  (verified)
+ (NSURL *)saveTreasureURL;       // 0x59884  save_treasure         (verified)
+ (NSURL *)recommendPackURL;      // 0x59740  pack_recommend/index.jsp (literal
                                  // "/apr/main/cgi/")
+ (NSURL *)invitedURL;            // 0x59148  invited/index.jsp        (literal "/apr/main/cgi/")
+ (NSURL *)playerNewURL;          // 0x59070  new_player/index.jsp     (literal
                                  // "/apr/main/cgi/")
+ (NSURL *)linkKidURL;            // 0x598f0  link_kid/index.jsp       (literal "/apr/main/cgi/")
+ (NSURL *)getArcadeScoreURL;     // 0x5995c  get_arcade_score
+ (NSURL *)getOverScoreLogURL;    // 0x59d28  get_over_score_log
+ (NSURL *)getBlockListURL;       // 0x59580  get_block_list
+ (NSURL *)addBlockListURL;       // 0x59514  add_block_list
+ (NSURL *)delBlockListURL;       // 0x595ec  del_block_list
+ (NSURL *)cancelFriendURL;       // 0x593d0  cancel_friend

// Daily-quiz endpoints. Unlike the ApiPath endpoints above these build the path
// as
// "/apr/main.cgi/" + "<name>/index.jsp" + "?target=<store>" (Ghidra fmt
// "%@%@?target=%@").
+ (NSURL *)getQuizURL;   // 0x59658  get_quiz/index.jsp   (verified)
+ (NSURL *)replyQuizURL; // 0x596cc  reply_quiz/index.jsp (verified)

// Official eAmusement pages. Ghidra: getOfficialAppInfoURL 0x59f88 (verified).
+ (NSURL *)getOfficialAppInfoURL;

// --- StoreKit helpers ---
// Localised currency string for a product's price, or @"" if product is nil.
// Ghidra: priceString: @ 0x5a16c.
+ (NSString *)priceString:(SKProduct *)product;

// StoreKit product identifier for a pack: "rhythmin_pack%04d" (nil if packID <
// 1). Ghidra: productIDForPackID: @ 0x5a088 (prefix CFString cf_rhythmin_pack).
+ (NSString *)productIDForPackID:(int)packID;

// Inverse of productIDForPackID:: parses the numeric pack id out of a product
// identifier, or -1 if it lacks the "rhythmin_pack" prefix / is non-positive.
// Ghidra: packIDForProductID: @ 0x5a0d0.
+ (int)packIDForProductID:(NSString *)productID;

// Youth-spending-limit gate: YES if a purchase of `price` yen is allowed given
// the user's age (from the saved birthday; 18+ unrestricted) and this month's
// running total. Ghidra: isPurchasable: @ 0x5a400.
+ (BOOL)isPurchasable:(unsigned int)price;

// --- Receipt verification (server-side re-validation of StoreKit purchases)
// ---

// Endpoint the base64 receipt + digest are POSTed to. Ghidra: receiptURL @
// 0x58f04 (createHttpsURL of /apr/main.cgi/verify_receipt/index.jsp).
+ (NSURL *)receiptURL;

// "iphone" or "ipad" by interface idiom. Ghidra: deviceName @ 0x58830.
+ (NSString *)deviceName;

// Cached anonymised user token: MD5 hex of (uuId + "STORE").
// Ghidra: identifierParams @ 0x58880.
+ (NSString *)identifierParams;

// The receipt-check request body wrapping the base64 receipt with client info.
// Ghidra: createReceiptCheckJSON: @ 0x5a2ac.
+ (NSString *)createReceiptCheckJSON:(NSString *)base64Receipt;

// Tamper-binding digest: SHA-256 hex of (embedded salt + json).
// Ghidra: createReceiptChecckDigest: @ 0x5a394 (sic — misspelled in the
// binary).
+ (NSString *)createReceiptChecckDigest:(NSString *)json;

// YES if the string is an http(s) URL that NSURL can parse.
// Ghidra: isValidURL: @ 0x5a240.
+ (BOOL)isValidURL:(NSString *)urlString;

// --- Store catalogue ---

// Common client-info query fragment: uuid/version/device/os/locale.
// Ghidra: userInfo @ 0x58910.
+ (NSString *)userInfo;

// Paginated pack-list endpoint. Ghidra: packListURL:limit:packId: @ 0x58abc.
+ (NSURL *)packListURL:(unsigned int)head limit:(unsigned int)limit packId:(int)packId;

// Single-pack detail endpoint; appends the userInfo fragment when userOpen is
// YES (an explicit user tap vs a background refresh). Ghidra:
// packInfoURL:UserOpen: @ 0x58b80.
+ (NSURL *)packInfoURL:(unsigned int)packID UserOpen:(BOOL)userOpen;

// Arcade-viewer per-song info endpoint (used by the arcade-viewer manager to
// fetch a missing song's metadata before re-download). Ghidra: acvMusicInfoURL:
// @ 0x5b534.
+ (NSURL *)acvMusicInfoURL:(unsigned int)acMusicId;

#pragma mark Recovered selectors
// Recovered from call sites (previously declared as local extern/category
// seams).

// Arcade-viewer play-log POST endpoint. Ghidra: logAcvPlayURL.
+ (NSURL *)logAcvPlayURL;
// Official eAmusement site path fragment / Twitter page.
+ (NSString *)getOfficialPath;
+ (NSURL *)getOfficialTwitterURL;
// Store per-song info page for a music id.
+ (NSURL *)musicInfoURL:(unsigned int)musicId;

// --- Arcade-locator ("game center" map) endpoints (used by SearchView) ---
// Master list feed: the marker-image / model-info master consumed to build the
// map pins. GET
// https://.../apr/main.cgi/search_master/index.jsp?target=<store><userInfo>.
// Ghidra: searchMasterURL @ 0x58f70 (createHttpsURL of
// search_master/index.jsp).
+ (NSURL *)searchMasterURL;
// Per-region arcade query: POSTed a "lat=&long=&range=" body to fetch the
// arcades in view. https://.../apr/main.cgi/gamecenter/index.jsp. Ghidra:
// searchURL @ 0x59004.
+ (NSURL *)searchURL;

#pragma mark Recovered selectors (store / player / present endpoints)
// All build on the byte-verified slash-form base "/apr/main/cgi/" (as
// recommendPackURL et al.).

// "register/refresh player" info feed. Ghidra: storeNewInfoURL @ 0x58d8c
// (createHttpsURL of /apr/main/cgi/new/index.jsp?target=JP&<userInfo>).
+ (NSURL *)storeNewInfoURL;
// Report a completed purchase (pid), tamper-bound with a trailing SHA-256 key.
// Ghidra: purchasedURL: @ 0x58e20.
+ (NSURL *)purchasedURL:(unsigned int)pid;
// Player fetch / score save. Ghidra: playerGetURL @ 0x590dc, saveScoreURL @
// 0x591b4.
+ (NSURL *)playerGetURL;
+ (NSURL *)saveScoreURL;
// Recommend list / visitor list. Ghidra: getRecommendListURL @ 0x597ac,
// getVisitorURL @ 0x59818.
+ (NSURL *)getRecommendListURL;
+ (NSURL *)getVisitorURL;
// Character-lottery play log / APNs token registration.
// Ghidra: logCharaKujiURL @ 0x59aa0, saveApnsTokenURL @ 0x59b78.
+ (NSURL *)logCharaKujiURL;
+ (NSURL *)saveApnsTokenURL;
// Reward login token / present box. Ghidra: getRewardLoginTokenURL @ 0x59be4,
// getPresentListURL @ 0x59c50, getPresentURL @ 0x59cbc.
+ (NSURL *)getRewardLoginTokenURL;
+ (NSURL *)getPresentListURL;
+ (NSURL *)getPresentURL;
// Official eAmusement "old info" page. Ghidra: getOfficialOldInfoURL @ 0x59ff4
// (createOfficialURL of /game/popn/rhythmin/app/old_info.html).
+ (NSURL *)getOfficialOldInfoURL;

@end

// Percent-encode a string for use in a URL query. Ghidra: urlEncodeString @
// 0x5c5ec. C-linkage (defined in StoreUtil.m) so the C++ (.mm) callers resolve
// the unmangled symbol.
#ifdef __cplusplus
extern "C"
#endif
    NSString *urlEncodeString(NSString *s);

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
