//
//  ScoreData+Store.h
//  pop'n rhythmin
//
//  Fetch / insert / integrity class methods on the ScoreData entity.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//
//  The score record carries an MD5 tamper-check (`chksco`) computed over the
//  music id and the three difficulty scores; `checkScore:` validates it and the
//  caller resets the record if it fails.
//

#import "ScoreData.h"
#import <CoreData/CoreData.h>

@interface ScoreData (Store)

// Fetch the record for `musicId`, creating a fresh (reset) one if absent.
// If an existing record fails its integrity check it is reset in place.
// Ghidra: +[ScoreData getScoreData:inManagedObjectContext:] @ 0x6da30
+ (ScoreData *)getScoreData:(int)musicId inManagedObjectContext:(NSManagedObjectContext *)context;

// Insert a new record for `musicId`, reset it to defaults, and save.
// Ghidra: +[ScoreData recordWithMusicId:inManagedObjectContext:] @ 0x6ded0
+ (ScoreData *)recordWithMusicId:(int)musicId
          inManagedObjectContext:(NSManagedObjectContext *)context;

// Fetch every ScoreData row.
// Ghidra: +[ScoreData getAllScoreData:] @ 0x6dca4
+ (NSArray *)getAllScoreData:(NSManagedObjectContext *)context;

// Reset a record to default/empty values and re-stamp its checksum.
// Ghidra: +[ScoreData reset:] @ 0x6df80
+ (void)reset:(ScoreData *)record;

// YES if `record`'s stored checksum matches a freshly computed one.
// Ghidra: +[ScoreData checkScore:] @ 0x6e354
+ (BOOL)checkScore:(ScoreData *)record;

// Compute the MD5 checksum NSData for a record's current scores.
// Ghidra: +[ScoreData hashScore:] @ 0x6e260
+ (NSData *)hashScore:(ScoreData *)record;

// Compute the raw 16-byte checksum for explicit score values.
// Ghidra: +[ScoreData hashScoreForTune:Normal:Hyper:Ex:Hash:] @ 0x6e20c
+ (void)hashScoreForTune:(int)musicId
                  Normal:(int)scoreN
                   Hyper:(int)scoreH
                      Ex:(int)scoreEx
                    Hash:(unsigned char *)outDigest16;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
