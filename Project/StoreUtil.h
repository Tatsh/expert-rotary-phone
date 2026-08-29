/**
 * @file
 * The server configuration and URL builder for the app's web APIs.
 *
 * Every endpoint is built through three base URLs — the game API over HTTP and HTTPS, and the
 * official eAmusement site — plus a per-endpoint path. Reconstructed from Ghidra project rb420,
 * program PopnRhythmin (StoreUtil @ 0x58904..0x5a060).
 */

#import <Foundation/Foundation.h>

@class SKProduct;

/**
 * The server-endpoint builders, StoreKit helpers and receipt-verification helpers the store
 * and the game API share.
 */
@interface StoreUtil : NSObject

/**
 * The store and region code sent as Accept-Language.
 * @return "JP".
 * @ghidraAddress 0x58904
 */
+ (NSString *)targetStore;

/**
 * Build a plain-HTTP game-API URL.
 * @param path The path, appended to http://apr.konaminet.jp.
 * @return The URL.
 * @ghidraAddress 0x589f4
 */
+ (NSURL *)createURL:(NSString *)path;
/**
 * Build an HTTPS game-API URL.
 * @param path The path, appended to https://apr-s.konaminet.jp.
 * @return The URL.
 * @ghidraAddress 0x58a58
 */
+ (NSURL *)createHttpsURL:(NSString *)path;
/**
 * Build an official eAmusement URL.
 * @param path The path, appended to http://p.eagate.573.jp.
 * @return The URL.
 * @ghidraAddress 0x59f24
 */
+ (NSURL *)createOfficialURL:(NSString *)path;

/**
 * The KONAMI ID quick-entry web page.
 * @return https://&lt;KONAMI_ID_HOST&gt;/quick/Entry.
 */
+ (NSURL *)konamiIdQuickEntryURL;

// Game API endpoints, all /apr/main.cgi/<name>/index.jsp over https. Endpoint names are verified
// where noted; the rest follow the identical pattern derived from the selector.

/**
 * The downloadable-file-list endpoint, get_dl_file_list. Verified.
 * @return The URL.
 * @ghidraAddress 0x599c8
 */
+ (NSURL *)getDlFileListURL;
/**
 * The friend-list endpoint, get_friend_list. Verified.
 * @return The URL.
 * @ghidraAddress 0x594a8
 */
+ (NSURL *)getFriendListURL;
/**
 * The event-info endpoint, get_event_info. Verified.
 * @return The URL.
 * @ghidraAddress 0x59d94
 */
+ (NSURL *)getEventInfoURL;
/**
 * The convert-code endpoint, get_convert_code. Verified.
 * @return The URL.
 * @ghidraAddress 0x59e00
 */
+ (NSURL *)getConvertCodeURL;
/**
 * The device-change convert endpoint, convert. Verified.
 * @return The URL.
 * @ghidraAddress 0x59e6c
 */
+ (NSURL *)convertURL;
/**
 * The sent-friend-requests endpoint, get_friend_request.
 * @return The URL.
 * @ghidraAddress 0x592f8
 */
+ (NSURL *)getFriendRequestURL;
/**
 * The friend-score endpoint, get_friend_score.
 * @return The URL.
 * @ghidraAddress 0x59364
 */
+ (NSURL *)getFriendScoreURL;
/**
 * The send-friend-request endpoint, request_friend. Verified.
 * @return The URL.
 * @ghidraAddress 0x59220
 */
+ (NSURL *)requestFriendURL;
/**
 * The accept-or-reject endpoint, reply_friend. Verified.
 * @return The URL.
 * @ghidraAddress 0x5928c
 */
+ (NSURL *)replyFriendURL;
/**
 * The unfriend endpoint, remove_friend. Verified.
 * @return The URL.
 * @ghidraAddress 0x5943c
 */
+ (NSURL *)removeFriendURL;
/**
 * The recommended-friend endpoint, get_recommend_friend. Verified.
 * @return The URL.
 * @ghidraAddress 0x59a34
 */
+ (NSURL *)getRecommendFriendURL;
/**
 * The sugoroku reward-upload endpoint, save_treasure. Verified.
 * @return The URL.
 * @ghidraAddress 0x59884
 */
+ (NSURL *)saveTreasureURL;
/**
 * The recommended-pack endpoint, pack_recommend/index.jsp, built on the literal
 * "/apr/main/cgi/" base.
 * @return The URL.
 * @ghidraAddress 0x59740
 */
+ (NSURL *)recommendPackURL;
/**
 * The invite-redemption endpoint, invited/index.jsp, built on the literal "/apr/main/cgi/"
 * base.
 * @return The URL.
 * @ghidraAddress 0x59148
 */
+ (NSURL *)invitedURL;
/**
 * The new-player endpoint, new_player/index.jsp, built on the literal "/apr/main/cgi/"
 * base.
 * @return The URL.
 * @ghidraAddress 0x59070
 */
+ (NSURL *)playerNewURL;
/**
 * The pop'n-link endpoint, link_kid/index.jsp, built on the literal "/apr/main/cgi/" base.
 * @return The URL.
 * @ghidraAddress 0x598f0
 */
+ (NSURL *)linkKidURL;
/**
 * The arcade-score sync endpoint, get_arcade_score.
 * @return The URL.
 * @ghidraAddress 0x5995c
 */
+ (NSURL *)getArcadeScoreURL;
/**
 * The over-score-log endpoint, get_over_score_log.
 * @return The URL.
 * @ghidraAddress 0x59d28
 */
+ (NSURL *)getOverScoreLogURL;
/**
 * The block-list fetch endpoint, get_block_list.
 * @return The URL.
 * @ghidraAddress 0x59580
 */
+ (NSURL *)getBlockListURL;
/**
 * The block endpoint, add_block_list.
 * @return The URL.
 * @ghidraAddress 0x59514
 */
+ (NSURL *)addBlockListURL;
/**
 * The unblock endpoint, del_block_list.
 * @return The URL.
 * @ghidraAddress 0x595ec
 */
+ (NSURL *)delBlockListURL;
/**
 * The cancel-friend-request endpoint, cancel_friend.
 * @return The URL.
 * @ghidraAddress 0x593d0
 */
+ (NSURL *)cancelFriendURL;

// Daily-quiz endpoints. Unlike the endpoints above, these build the path as "/apr/main.cgi/" plus
// "<name>/index.jsp" plus "?target=<store>" (the Ghidra format string is "%@%@?target=%@").

/**
 * The quiz-fetch endpoint, get_quiz/index.jsp. Verified.
 * @return The URL.
 * @ghidraAddress 0x59658
 */
+ (NSURL *)getQuizURL;
/**
 * The quiz-answer endpoint, reply_quiz/index.jsp. Verified.
 * @return The URL.
 * @ghidraAddress 0x596cc
 */
+ (NSURL *)replyQuizURL;

/**
 * The official eAmusement app-info page. Verified.
 * @return The URL.
 * @ghidraAddress 0x59f88
 */
+ (NSURL *)getOfficialAppInfoURL;

// StoreKit helpers.

/**
 * The localised currency string for a product's price.
 * @param product The StoreKit product.
 * @return The price string, or the placeholder "￥573" when @p product is nil.
 * @ghidraAddress 0x5a16c
 */
+ (NSString *)priceString:(SKProduct *)product;

/**
 * The StoreKit product identifier for a pack, formatted "rhythmin.pack%04d".
 * @param packID The pack id.
 * @return The identifier, or nil when @p packID is below 1.
 * @ghidraAddress 0x5a088
 */
+ (NSString *)productIDForPackID:(int)packID;

/**
 * The inverse of +productIDForPackID:: parse the numeric pack id out of a product
 * identifier.
 * @param productID The product identifier.
 * @return The pack id, or -1 when it lacks the "rhythmin.pack" prefix or is not positive.
 * @ghidraAddress 0x5a0d0
 */
+ (int)packIDForProductID:(NSString *)productID;

/**
 * The youth-spending-limit gate.
 * @param price The purchase price, in yen.
 * @return YES when the purchase is allowed, given the user's age from the saved birthday — 18 and
 * over is unrestricted — and this month's running total.
 * @ghidraAddress 0x5a400
 */
+ (BOOL)isPurchasable:(unsigned int)price;

// Receipt verification: the server-side re-validation of StoreKit purchases.

/**
 * The endpoint the base64 receipt and digest are posted to: the HTTPS
 * /apr/main.cgi/verify_receipt/index.jsp.
 * @return The URL.
 * @ghidraAddress 0x58f04
 */
+ (NSURL *)receiptURL;

/**
 * The device class, by interface idiom.
 * @return "iphone" or "ipad".
 * @ghidraAddress 0x58830
 */
+ (NSString *)deviceName;

/**
 * The cached anonymised user token: the hexadecimal MD5 of the device UUID plus "STORE".
 * @return The token.
 * @ghidraAddress 0x58880
 */
+ (NSString *)identifierParams;

/**
 * The receipt-check request body, wrapping the receipt with client info.
 * @param base64Receipt The base64-encoded StoreKit receipt.
 * @return The JSON body.
 * @ghidraAddress 0x5a2ac
 */
+ (NSString *)createReceiptCheckJSON:(NSString *)base64Receipt;

/**
 * The tamper-binding digest: the hexadecimal SHA-256 of the embedded salt plus the JSON.
 *
 * The selector's spelling is the binary's.
 * @param json The receipt-check body.
 * @return The digest.
 * @ghidraAddress 0x5a394
 */
+ (NSString *)createReceiptChecckDigest:(NSString *)json;

/**
 * Whether a string is an HTTP or HTTPS URL that NSURL can parse.
 * @param urlString The string to test.
 * @return YES when it parses.
 * @ghidraAddress 0x5a240
 */
+ (BOOL)isValidURL:(NSString *)urlString;

// Store catalogue.

/**
 * The common client-info query fragment: uuid, version, device, os and locale.
 * @return The query fragment.
 * @ghidraAddress 0x58910
 */
+ (NSString *)userInfo;

/**
 * The paginated pack-list endpoint.
 * @param head The first pack index to return.
 * @param limit How many packs to return.
 * @param packId A specific pack to include, or a non-positive value for none.
 * @return The URL.
 * @ghidraAddress 0x58abc
 */
+ (NSURL *)packListURL:(unsigned int)head limit:(unsigned int)limit packId:(int)packId;

/**
 * The single-pack detail endpoint.
 * @param packID The pack to fetch.
 * @param userOpen YES for an explicit user tap, which appends the userInfo fragment; NO for a
 * background refresh.
 * @return The URL.
 * @ghidraAddress 0x58b80
 */
+ (NSURL *)packInfoURL:(unsigned int)packID UserOpen:(BOOL)userOpen;

/**
 * The arcade-viewer per-song info endpoint, used to fetch a missing song's metadata before
 * re-download.
 * @param acMusicId The arcade music id.
 * @return The URL.
 * @ghidraAddress 0x5b534
 */
+ (NSURL *)acvMusicInfoURL:(unsigned int)acMusicId;

#pragma mark Recovered selectors

// Recovered from call sites; previously declared as local extern or category seams.

/**
 * The arcade-viewer play-log POST endpoint.
 * @return The URL.
 */
+ (NSURL *)logAcvPlayURL;
/**
 * The official eAmusement site path fragment.
 * @return The path fragment.
 */
+ (NSString *)getOfficialPath;
/**
 * The official Twitter page.
 * @return The URL.
 */
+ (NSURL *)getOfficialTwitterURL;
/**
 * The store's per-song info page.
 * @param musicId The song to show.
 * @return The URL.
 */
+ (NSURL *)musicInfoURL:(unsigned int)musicId;

// Arcade-locator ("game center" map) endpoints, used by SearchView.

/**
 * The master-list feed: the marker-image and model-info master consumed to build the map
 * pins.
 *
 * A GET of https://.../apr/main.cgi/search_master/index.jsp?target=&lt;store&gt;&lt;userInfo&gt;.
 * @return The URL.
 * @ghidraAddress 0x58f70
 */
+ (NSURL *)searchMasterURL;
/**
 * The per-region arcade query, posted a "lat=&long=&range=" body to fetch the arcades in
 * view: https://.../apr/main.cgi/gamecenter/index.jsp.
 * @return The URL.
 * @ghidraAddress 0x59004
 */
+ (NSURL *)searchURL;

#pragma mark Recovered selectors (store / player / present endpoints)

// These all build on the byte-verified slash-form base "/apr/main/cgi/", as recommendPackURL and
// its siblings do.

/**
 * The register-or-refresh player info feed: the HTTPS
 * /apr/main/cgi/new/index.jsp?target=JP&amp;&lt;userInfo&gt;.
 * @return The URL.
 * @ghidraAddress 0x58d8c
 */
+ (NSURL *)storeNewInfoURL;
/**
 * The completed-purchase report, tamper-bound with a trailing SHA-256 key.
 * @param pid The purchased pack id.
 * @return The URL.
 * @ghidraAddress 0x58e20
 */
+ (NSURL *)purchasedURL:(unsigned int)pid;
/**
 * The player-fetch endpoint.
 * @return The URL.
 * @ghidraAddress 0x590dc
 */
+ (NSURL *)playerGetURL;
/**
 * The score-save endpoint.
 * @return The URL.
 * @ghidraAddress 0x591b4
 */
+ (NSURL *)saveScoreURL;
/**
 * The recommend-list endpoint.
 * @return The URL.
 * @ghidraAddress 0x597ac
 */
+ (NSURL *)getRecommendListURL;
/**
 * The sugoroku visitor-list endpoint.
 * @return The URL.
 * @ghidraAddress 0x59818
 */
+ (NSURL *)getVisitorURL;
/**
 * The character-lottery play-log endpoint.
 * @return The URL.
 * @ghidraAddress 0x59aa0
 */
+ (NSURL *)logCharaKujiURL;
/**
 * The APNs token-registration endpoint.
 * @return The URL.
 * @ghidraAddress 0x59b78
 */
+ (NSURL *)saveApnsTokenURL;
/**
 * The reward login-token endpoint.
 * @return The URL.
 * @ghidraAddress 0x59be4
 */
+ (NSURL *)getRewardLoginTokenURL;
/**
 * The present-list endpoint.
 * @return The URL.
 * @ghidraAddress 0x59c50
 */
+ (NSURL *)getPresentListURL;
/**
 * The present-claim endpoint.
 * @return The URL.
 * @ghidraAddress 0x59cbc
 */
+ (NSURL *)getPresentURL;
/**
 * The official eAmusement "old info" page:
 * /game/popn/rhythmin/app/old_info.html.
 * @return The URL.
 * @ghidraAddress 0x59ff4
 */
+ (NSURL *)getOfficialOldInfoURL;

@end

/**
 * Percent-encode a string for use in a URL query.
 *
 * It has C linkage, and is defined in StoreUtil.m, so the C++ (.mm) callers resolve the unmangled
 * symbol.
 * @param s The string to encode.
 * @return The encoded string.
 * @ghidraAddress 0x5c5ec
 */
#ifdef __cplusplus
extern "C"
#endif
    NSString *urlEncodeString(NSString *s);

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
