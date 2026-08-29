/**
 * @file
 * @brief The TreasureData Core Data managed object: sugoroku board progress.
 *
 * Reconstructed from ScoreData.momd/ScoreData_v2.mom (entity "TreasureData").
 *
 * Progress on the "sugoroku" (board-game) meta-mode: which main and sub map the player is on,
 * collectible counts (music pieces, wallpaper pieces, character tickets earned by reaching goals),
 * clear and meet counters, and per-map option flags such as the goal-touch sound and the
 * fast-record toggle.
 *
 * This Core Data entity is unrelated to the third-party TreasureData analytics SDK also present in
 * the binary — the name collision is coincidental; this is the local sugoroku save record.
 *
 * Numeric attributes are NSNumber-backed (non-scalar Core Data codegen; see ScoreData.h for the
 * confirming call site). Every attribute is Integer16.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

/**
 * @brief One row of sugoroku board progress: the player's position on a map plus everything
 * collected there.
 */
@interface TreasureData : NSManagedObject

/** The main map this row tracks. Integer16. */
@property(nonatomic, retain) NSNumber *mainMapId;
/** The sub map this row tracks. Integer16. */
@property(nonatomic, retain) NSNumber *subMapId;
/** How many times the map has been cleared. Integer16. */
@property(nonatomic, retain) NSNumber *clearCnt;
/** How many friends have been met on this map. Integer16. */
@property(nonatomic, retain) NSNumber *friendMeetCnt;
/** The music-piece bits collected on this map. Integer16. */
@property(nonatomic, retain) NSNumber *musicPiece;
/** The wallpaper-piece bits collected on this map. Integer16. */
@property(nonatomic, retain) NSNumber *wallPaperPiece;
/** Character tickets earned by reaching this map's goals. Integer16. */
@property(nonatomic, retain) NSNumber *goalCharaTicket;
/** The goal-touch sound selected for this map. Integer16. */
@property(nonatomic, retain) NSNumber *goalTouchSound;
/** The best (minimum) fast-clear record for this map; -1 when unset. Integer16. */
@property(nonatomic, retain) NSNumber *fastRecord;

/**
 * @brief Fetch every persisted TreasureData record: the whole sugoroku save table.
 * @param context The managed object context to fetch from.
 * @return An array of TreasureData.
 * @ghidraAddress 0xc09a4
 */
+ (NSArray<TreasureData *> *)getAllTreasureData:(NSManagedObjectContext *)context;

/**
 * @brief Whether @p mainMapId is one of the two root ("default") maps, 0 or 6.
 * @param mainMapId The main map id to test.
 * @return YES for a root map.
 * @ghidraAddress 0xc0f64
 */
+ (BOOL)isDefaultMap:(short)mainMapId;

/**
 * @brief Delete every persisted TreasureData record; the device-change and initForConvert reset.
 * @param context The managed object context to delete from.
 */
+ (void)deleteAll:(NSManagedObjectContext *)context;

/**
 * @brief Seed the default treasure-map rows into the store, as part of the device-change reset.
 * @param context The managed object context to seed.
 * @return The seeded rows.
 */
+ (id)init:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
