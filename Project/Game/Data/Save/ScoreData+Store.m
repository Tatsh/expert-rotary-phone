//
//  ScoreData+Store.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "RhCrypto.h"
#import "ScoreData+Store.h"

@implementation ScoreData (Store)

// Ghidra: +[ScoreData getScoreData:inManagedObjectContext:] @ 0x6da30
+ (ScoreData *)getScoreData:(int)musicId
       inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ScoreData"
                                 inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"musicId == %d", musicId];

    NSArray *results = [context executeFetchRequest:request error:nil];
    if (results.count == 0) {
        // No row yet: create one and persist.
        ScoreData *record = [self recordWithMusicId:musicId inManagedObjectContext:context];
        NSError *error = nil;
        if (![context save:&error]) {
            // Original walks NSDetailedErrorsKey here (diagnostic only).
            NSArray *detailed = error.userInfo[NSDetailedErrorsKey];
            for (NSError *sub in detailed) {
                (void)sub;
            }
        }
        return record;
    }

    // Existing row: validate integrity, reset if it was tampered with.
    ScoreData *record = results.lastObject;
    if (![self checkScore:record]) {
        [self reset:record];
    }
    return record;
}

// Ghidra: +[ScoreData recordWithMusicId:inManagedObjectContext:] @ 0x6ded0
+ (ScoreData *)recordWithMusicId:(int)musicId
          inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];

    ScoreData *record = [NSEntityDescription insertNewObjectForEntityForName:@"ScoreData"
                                                     inManagedObjectContext:context];
    record.musicId = [NSNumber numberWithInt:musicId];
    [self reset:record];
    [context save:nil];
    return record;
}

// Ghidra: +[ScoreData getAllScoreData:] @ 0x6dca4
+ (NSArray *)getAllScoreData:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ScoreData"
                                 inManagedObjectContext:context];
    return [context executeFetchRequest:request error:nil];
}

// Ghidra: +[ScoreData reset:] @ 0x6df80
+ (void)reset:(ScoreData *)record {
    record.fullComboN = @NO;
    record.fullComboH = @NO;
    record.fullComboEx = @NO;
    record.perfectN = @NO;
    record.perfectH = @NO;
    record.perfectEx = @NO;

    record.rankN = @(-1);
    record.rankH = @(-1);
    record.rankEx = @(-1);
    record.scoreN = @(-1);
    record.scoreH = @(-1);
    record.scoreEx = @(-1);

    record.lastPlayDate = [NSDate dateWithTimeIntervalSince1970:0];

    record.playCntN = @0;
    record.playCntH = @0;
    record.playCntEx = @0;

    record.chksco = [self hashScore:record];
}

// Ghidra: +[ScoreData checkScore:] @ 0x6e354
+ (BOOL)checkScore:(ScoreData *)record {
    if (record == nil) {
        return NO;
    }
    return [[self hashScore:record] isEqualToData:record.chksco];
}

// Ghidra: +[ScoreData hashScore:] @ 0x6e260
+ (NSData *)hashScore:(ScoreData *)record {
    unsigned char digest[16];
    [self hashScoreForTune:record.musicId.intValue
                    Normal:record.scoreN.intValue
                     Hyper:record.scoreH.intValue
                        Ex:record.scoreEx.intValue
                      Hash:digest];
    return [NSData dataWithBytes:digest length:16];
}

// Ghidra: +[ScoreData hashScoreForTune:Normal:Hyper:Ex:Hash:] @ 0x6e20c
+ (void)hashScoreForTune:(int)musicId
                  Normal:(int)scoreN
                   Hyper:(int)scoreH
                      Ex:(int)scoreEx
                    Hash:(unsigned char *)outDigest16 {
    // 8 x int32 mixing buffer, MD5'd to a 16-byte checksum. Layout must match
    // the original byte-for-byte or existing saves fail their integrity check.
    int32_t buf[8];
    buf[0] = musicId;
    buf[1] = scoreN;
    buf[2] = scoreH;
    buf[3] = scoreEx;
    buf[4] = scoreN + scoreH;
    buf[5] = scoreH + scoreEx;
    buf[6] = scoreN + scoreEx;
    buf[7] = scoreN + scoreH + scoreEx;
    RhMD5(buf, sizeof(buf), outDigest16);
}

@end
