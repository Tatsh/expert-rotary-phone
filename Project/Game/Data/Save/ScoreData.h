//
//  ScoreData.h
//  pop'n rhythmin
//
//  Core Data managed object — per-song play records.
//  Reconstructed from ScoreData.momd/ScoreData_v2.mom (entity "ScoreData").
//
//  One row per music track. Scores/ranks/flags are tracked independently for
//  the three local difficulties Normal (N), Hyper (H) and EX. `chksco` is a
//  binary integrity blob used to detect tampering with the stored scores.
//
//  Numeric attributes are NSNumber-backed (non-scalar codegen): confirmed from
//  -[ScoreData recordWithMusicId:inManagedObjectContext:] @ 0x6ded0, which does
//  `[self setMusicId:[NSNumber numberWithInt:musicId]]`. The comment after each
//  numeric property records the underlying Core Data storage width, which the
//  NSNumber * type otherwise erases.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@interface ScoreData : NSManagedObject

@property(nonatomic, retain) NSNumber *musicId; // Integer32

@property(nonatomic, retain) NSNumber *scoreN;  // Integer32
@property(nonatomic, retain) NSNumber *scoreH;  // Integer32
@property(nonatomic, retain) NSNumber *scoreEx; // Integer32

@property(nonatomic, retain) NSNumber *rankN;  // Integer16
@property(nonatomic, retain) NSNumber *rankH;  // Integer16
@property(nonatomic, retain) NSNumber *rankEx; // Integer16

@property(nonatomic, retain) NSNumber *fullComboN;  // Boolean
@property(nonatomic, retain) NSNumber *fullComboH;  // Boolean
@property(nonatomic, retain) NSNumber *fullComboEx; // Boolean

@property(nonatomic, retain) NSNumber *perfectN;  // Boolean
@property(nonatomic, retain) NSNumber *perfectH;  // Boolean
@property(nonatomic, retain) NSNumber *perfectEx; // Boolean

@property(nonatomic, retain) NSNumber *playCntN;  // Integer64
@property(nonatomic, retain) NSNumber *playCntH;  // Integer64
@property(nonatomic, retain) NSNumber *playCntEx; // Integer64

@property(nonatomic, retain) NSDate *lastPlayDate;
@property(nonatomic, retain) NSData *chksco;

// Delete every persisted ScoreData record (device-change / initForConvert
// reset).
+ (void)deleteAll:(NSManagedObjectContext *)context;

// Fetch every persisted ScoreData row (device-change export). Ghidra:
// getAllScoreData:.
+ (NSArray *)getAllScoreData:(NSManagedObjectContext *)context;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
