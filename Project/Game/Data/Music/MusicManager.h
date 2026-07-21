/** @file
 * The music-catalogue singleton: builds and caches the arrays of playable @c MusicData (local) and
 * @c AcMusicData (arcade) records, assembles the built-in song tables from unlock gates, loads and
 * saves the Blowfish-encrypted purchased-song lists, applies downloadable level patches, and
 * resolves song IDs to their bundled or purchased chart-file paths. Song data files are @c %09d.orb
 * (local) and @c ac%09d.acv (arcade).
 */

#import <Foundation/Foundation.h>

@class MusicData, AcMusicData;

/**
 * @brief The music-catalogue singleton.
 */
@interface MusicManager : NSObject

/**
 * @brief The shared singleton.
 * @ghidraAddress 0xc7dd8
 */
+ (instancetype)getInstance;

// Cached, lazily (re)built arrays. Rebuilt when the matching dirty flag is set.

/**
 * @brief The cached playable local-song array, rebuilt when its dirty flag is set.
 * @ghidraAddress 0xcae40
 */
- (NSArray *)getMusicDataArray;

/**
 * @brief The cached arcade-song array, rebuilt when its dirty flag is set.
 * @ghidraAddress 0xcae84
 */
- (NSArray *)getAcMusicDataArray;

/**
 * @brief Every treasure song bundled with the app, one per main map.
 * @ghidraAddress 0xcaec8
 */
- (NSArray *)getTreasureMusicDataArray;

/**
 * @brief Linear-search the cached local-song array by its @c MusicID.
 * @param musicId The song id to match.
 * @ghidraAddress 0xcb080
 */
- (MusicData *)getMusicData:(int)musicId;

/**
 * @brief Linear-search the cached arcade-song array by its @c acMusicId.
 * @param acMusicId The arcade-song id to match.
 * @ghidraAddress 0xcb154
 */
- (AcMusicData *)getAcMusicData:(int)acMusicId;

/**
 * @brief Build the @c %09d.orb data-file name for a local song. Class method: stateless.
 * @param musicId The song id.
 * @ghidraAddress 0xc7e20
 */
+ (NSString *)getMusicDataFilename:(int)musicId;

/**
 * @brief Build the @c ac%09d.acv data-file name for an arcade song.
 * @param acMusicId The arcade-song id.
 * @ghidraAddress 0xc7e50
 */
- (NSString *)getAcMusicDataFilename:(int)acMusicId;

/**
 * @brief Rebuild the local-song cache from all unlock sources and apply level patches, clearing the
 * dirty flag.
 * @ghidraAddress 0xca248
 */
- (void)createMusicDataArray;

/**
 * @brief Rebuild the arcade-song cache, clearing the dirty flag.
 * @ghidraAddress 0xcaabc
 */
- (void)createAcMusicDataArray;

/**
 * @brief Load the downloadable @c rhythmin_lv level patches.
 * @ghidraAddress 0xcb610
 */
- (void)createMusicLvPatchArray;

/**
 * @brief Build the always-available bundled song table (IDs {1, 2, 3}).
 * @ghidraAddress 0xc8384
 */
- (void)createDefaultMusics;

/**
 * @brief Build the treasure-song table, gated per main map.
 * @ghidraAddress 0xc8440
 */
- (void)createOpenTreasureMusics;

/**
 * @brief Build the invite-reward song table (id 4), gated by the invite predicate.
 * @ghidraAddress 0xc8554
 */
- (void)createOpenInviteMusics;

/**
 * @brief Build the BEMANI-collabo song table (id 5), gated by the collabo predicate.
 * @ghidraAddress 0xc8604
 */
- (void)createOpenCollaboMusics;

/**
 * @brief Build the login-bonus song table (id 6), gated by the login-bonus predicate.
 * @ghidraAddress 0xc86b4
 */
- (void)createOpenLoginBonusMusics;

/**
 * @brief Build the default arcade catalogue table (IDs {1, 2, 3, 300000000}).
 * @ghidraAddress 0xc8764
 */
- (void)createAcDefaultMusics;

/**
 * @brief Load and Blowfish-decrypt the purchased-song lists (@c mulist / @c acmulist).
 * @ghidraAddress 0xc8820
 */
- (void)loadPurchasedMusics;

/**
 * @brief Blowfish-encrypt and write the purchased-song lists back to @c mulist / @c acmulist.
 * @ghidraAddress 0xc8bec
 */
- (void)savePurchasedMusics;

/**
 * @brief The in-memory purchased local-song list.
 * @ghidraAddress 0xc8f28
 */
- (NSMutableArray *)getPurchasedMusicDictionaris;

/**
 * @brief The in-memory purchased arcade-song list.
 * @ghidraAddress 0xc8f38
 */
- (NSMutableArray *)getPurchasedAcMusicDictionaris;

/**
 * @brief Merge a purchased local song into the list.
 * @param item The purchased-song info to merge.
 * @return @c YES when the list changed.
 * @ghidraAddress 0xc8f48
 */
- (BOOL)addPurchasedMusic:(id)item;

/**
 * @brief Merge a purchased arcade song into the list.
 * @param item The purchased-song info to merge.
 * @return @c YES when the list changed.
 * @ghidraAddress 0xc93f0
 */
- (BOOL)addPurchasedAcMusic:(id)item;

/**
 * @brief Delete a downloaded local (@c .orb) song file.
 * @param musicId The song id whose file to remove.
 * @return @c YES if the file existed.
 * @ghidraAddress 0xc9898
 */
- (BOOL)deleteMusic:(int)musicId;

/**
 * @brief Delete a downloaded arcade (@c .acv) song file.
 * @param acMusicId The arcade-song id whose file to remove.
 * @return @c YES if the file existed.
 * @ghidraAddress 0xc9914
 */
- (BOOL)deleteAcMusic:(int)acMusicId;

/**
 * @brief Whether @p packID appears in the encrypted @c recpack recommended list.
 * @param packID The pack id to look up.
 * @ghidraAddress 0xc9990
 */
- (BOOL)isRecommendedPack:(int)packID;

/**
 * @brief Re-evaluate the treasure unlock gate and mark the local cache dirty.
 * @ghidraAddress 0xcafc0
 */
- (void)openTreasureMusic;

/**
 * @brief Re-evaluate the invite unlock gate and mark the local cache dirty.
 * @ghidraAddress 0xcaff0
 */
- (void)openInviteMusic;

/**
 * @brief Re-evaluate the collabo unlock gate and mark the local cache dirty.
 * @ghidraAddress 0xcb020
 */
- (void)openCollaboMusic;

/**
 * @brief Re-evaluate the login-bonus unlock gate and mark the local cache dirty.
 * @ghidraAddress 0xcb050
 */
- (void)openLoginBonusMusic;

/**
 * @brief A flat list of all currently-available local song IDs (default, purchased, and treasure).
 * @ghidraAddress 0xcb24c
 */
- (NSMutableArray *)getMusicIDs;

/**
 * @brief A flat list of all currently-available arcade song IDs (arcade-default and purchased-ac).
 * @ghidraAddress 0xcb474
 */
- (NSMutableArray *)getAcMusicIDs;

/**
 * @brief The loaded level-patch records (@c rhythmin.lv), or @c nil.
 * @ghidraAddress 0xcb948
 */
- (NSArray *)getMusicPatchArray;

/**
 * @brief Mark the local-song cache stale so the next getter rebuilds it.
 * @ghidraAddress 0xcae18
 */
- (void)setMusicDataArrayDirty;

/**
 * @brief Mark the arcade-song cache stale so the next getter rebuilds it.
 * @ghidraAddress 0xcae2c
 */
- (void)setAcMusicDataArrayDirty;

/**
 * @brief Release the cached music data. A no-op in this build.
 * @ghidraAddress 0xcb248
 */
- (void)releaseChacheMusicData;

/**
 * @brief Resolve a song id to its bundled or purchased (@c .orb) path. Class method: no instance
 * state, so the init-time open-song predicates do not re-enter @c getInstance (see the recursion fix
 * in the implementation).
 * @param musicId The song id to resolve.
 * @ghidraAddress 0xc7e80
 */
+ (NSString *)getPathFromBundle:(int)musicId;

/**
 * @brief Resolve a purchased local song id to its @c .orb path under Application Support.
 * @param musicId The song id to resolve.
 * @ghidraAddress 0xc7edc
 */
- (NSString *)getPathFromPurchased:(int)musicId;

/**
 * @brief Resolve a purchased arcade song id to its @c .acv path under Application Support.
 * @param acMusicId The arcade-song id to resolve.
 * @ghidraAddress 0xc7f38
 */
- (NSString *)getAcPathFromPurchased:(int)acMusicId;

#ifdef ENABLE_PATCHES
/**
 * Resolve a chart data filename, preferring a copy shipped in the bundle.
 *
 * Preservation build only: returns the path to @p filename inside the bundle's assets/ directory
 * when a file exists there, otherwise the Application Support path the original downloaded to. The
 * .orb and .acv chart resolvers route through this so a self-contained build can bundle its charts
 * while still loading songs added to Application Support later.
 *
 * @param filename The bare data file name, for example a @c %09d.orb chart or an @c ac%09d.acv chart.
 * @return The bundle assets/ path when the file is present there, otherwise the Application Support
 *         path.
 */
+ (NSString *)assetOrAppSupportPath:(NSString *)filename;

/**
 * @brief Copy a shipped @c assets/ list into Documents once, if not already present.
 *
 * Preservation build only. The bundle install is read-only, so @c assets/mulist / @c assets/acmulist
 * are copied into Documents on first boot and Documents is the read-write store from then on.
 *
 * @param name The list file name (@c "mulist" or @c "acmulist").
 */
- (void)seedListFromAssets:(NSString *)name;

/**
 * @brief Reconcile the purchased lists with the charts actually present.
 *
 * Preservation build only, run at the end of @c -loadPurchasedMusics. It reconciles both purchased
 * lists (see @c -reconcileList:excluded:prefix:suffix:) so custom songs dropped into Application
 * Support appear without editing @c mulist / @c acmulist and vanished songs drop out, all with the
 * caches marked dirty.
 *
 * @return @c YES when either list was changed (so the caller persists it to Documents).
 */
- (BOOL)reconcilePurchasedMusics;

/**
 * @brief Prune stale/duplicate entries from a purchased list and discover new charts.
 *
 * Preservation build only. Drops an entry that another catalogue source already covers (@p excluded),
 * that a prior entry already listed, or whose chart file no longer resolves in @c assets/ or
 * Application Support; then scans both directories for canonical @c \<prefix\>%09d\<suffix\> charts
 * and registers any that are neither excluded nor already listed, so a dropped chart appears next
 * boot and duplicates can never occur.
 *
 * @param purchased The mutable purchased-song list to reconcile in place.
 * @param excluded IDs a different catalogue source already contributes (never listed as purchased).
 * @param prefix The chart file-name prefix (@c "" for @c .orb, @c "ac" for @c .acv).
 * @param suffix The chart file-name suffix (@c ".orb" or @c ".acv").
 * @return @c YES when an entry was pruned or discovered.
 */
- (BOOL)reconcileList:(NSMutableArray *)purchased
             excluded:(NSSet<NSNumber *> *)excluded
               prefix:(NSString *)prefix
               suffix:(NSString *)suffix;
#endif

/**
 * @brief The recommended-pack id list, decoded from the encrypted @c recpack file.
 * @ghidraAddress 0xc9bd0
 */
- (NSArray *)getRecommendPackArray;

/**
 * @brief Add a pack id to the encrypted @c recpack list. A no-op if already present.
 * @param packID The pack id to add.
 * @ghidraAddress 0xc9e20
 */
- (void)saveRecommendedPack:(unsigned int)packID;

#pragma mark Recovered selectors
// Recovered from call sites (previously declared as a local category seam).

// Unlock-gate queries used by the store / song-select UI.

/**
 * @brief Whether the invite-reward song is open for the given reward tier.
 * @param index The reward tier to test.
 */
+ (BOOL)isOpenInviteMusic:(int)index;

/**
 * @brief Whether @p musicId is the invite-reward song. @c YES if id == 4.
 * @param musicId The song id to test.
 * @ghidraAddress 0xc7fd4
 */
+ (BOOL)isInviteMusic:(int)musicId;

/**
 * @brief Whether the BEMANI-collabo song is open.
 */
+ (BOOL)isOpenBemaniCollaboMusic;

/**
 * @brief Whether the login-bonus song is open for the given reward tier.
 * @param index The reward tier to test.
 */
+ (BOOL)isOpenLoginBonusMusic:(int)index;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
