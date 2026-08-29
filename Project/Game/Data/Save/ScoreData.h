/**
 * @file
 * The ScoreData Core Data managed object: per-song play records.
 *
 * Reconstructed from ScoreData.momd/ScoreData_v2.mom (entity "ScoreData").
 *
 * One row per music track. Scores, ranks and flags are tracked independently for the three local
 * difficulties Normal (N), Hyper (H) and EX. `chksco` is a binary integrity blob used to detect
 * tampering with the stored scores.
 *
 * Numeric attributes are NSNumber-backed (non-scalar codegen), confirmed from -[ScoreData
 * recordWithMusicId:inManagedObjectContext:] @ 0x6ded0, which does `[self setMusicId:[NSNumber
 * numberWithInt:musicId]]`. Each numeric property records the underlying Core Data storage width,
 * which the NSNumber * type otherwise erases.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

/**
 * The per-song local play record: best score, rank, medals and play count for each of the
 * three difficulties.
 */
@interface ScoreData : NSManagedObject

/** The music track this row scores. Integer32. */
@property(nonatomic, retain) NSNumber *musicId;

/** Best Normal-difficulty score. Integer32. */
@property(nonatomic, retain) NSNumber *scoreN;
/** Best Hyper-difficulty score. Integer32. */
@property(nonatomic, retain) NSNumber *scoreH;
/** Best EX-difficulty score. Integer32. */
@property(nonatomic, retain) NSNumber *scoreEx;

/** Best Normal-difficulty rank. Integer16. */
@property(nonatomic, retain) NSNumber *rankN;
/** Best Hyper-difficulty rank. Integer16. */
@property(nonatomic, retain) NSNumber *rankH;
/** Best EX-difficulty rank. Integer16. */
@property(nonatomic, retain) NSNumber *rankEx;

/** Whether Normal difficulty has a full combo. Boolean. */
@property(nonatomic, retain) NSNumber *fullComboN;
/** Whether Hyper difficulty has a full combo. Boolean. */
@property(nonatomic, retain) NSNumber *fullComboH;
/** Whether EX difficulty has a full combo. Boolean. */
@property(nonatomic, retain) NSNumber *fullComboEx;

/** Whether Normal difficulty has been perfected. Boolean. */
@property(nonatomic, retain) NSNumber *perfectN;
/** Whether Hyper difficulty has been perfected. Boolean. */
@property(nonatomic, retain) NSNumber *perfectH;
/** Whether EX difficulty has been perfected. Boolean. */
@property(nonatomic, retain) NSNumber *perfectEx;

/** Normal-difficulty play count. Integer64. */
@property(nonatomic, retain) NSNumber *playCntN;
/** Hyper-difficulty play count. Integer64. */
@property(nonatomic, retain) NSNumber *playCntH;
/** EX-difficulty play count. Integer64. */
@property(nonatomic, retain) NSNumber *playCntEx;

/** When this track was last played. */
@property(nonatomic, retain) NSDate *lastPlayDate;
/** The MD5 tamper-check blob computed over the music id and the three scores. */
@property(nonatomic, retain) NSData *chksco;

/**
 * Delete every persisted ScoreData record; the device-change and initForConvert reset.
 * @param context The managed object context to delete from.
 */
+ (void)deleteAll:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
