//
//  OverScoreData+Store.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "OverScoreData+Store.h"

@implementation OverScoreData (Store)

// Helper: a fetch request for the OverScoreData entity with an optional predicate.
static NSFetchRequest *OverScoreFetch(NSManagedObjectContext *context, NSPredicate *predicate) {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"OverScoreData"
                                 inManagedObjectContext:context];
    request.predicate = predicate;
    return request;
}

// Ghidra: @ 0xba0a4
+ (OverScoreData *)getOverScoreDataWithMusic:(int)music
                                       sheet:(short)sheet
                                    playerId:(NSString *)playerId
                      inManagedObjectContext:(NSManagedObjectContext *)context {
    NSPredicate *p = [NSPredicate predicateWithFormat:
                      @"music==%d and sheet==%d and playerId==%@", music, (int)sheet, playerId];
    NSArray *results = [context executeFetchRequest:OverScoreFetch(context, p) error:nil];
    return results.count ? results.lastObject : nil;
}

// Ghidra: @ 0xba1c0
+ (NSArray *)getOverScoreDataWithMusic:(int)music
                                 sheet:(short)sheet
                inManagedObjectContext:(NSManagedObjectContext *)context {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"music==%d and sheet==%d",
                      music, (int)sheet];
    return [context executeFetchRequest:OverScoreFetch(context, p) error:nil];
}

// Ghidra: @ 0xba2b0
+ (NSArray *)getAllOverScoreData:(NSManagedObjectContext *)context {
    return [context executeFetchRequest:OverScoreFetch(context, nil) error:nil];
}

// Ghidra: @ 0xba350
+ (OverScoreData *)updateOverScoreDateWithMusic:(int)music
                                          sheet:(short)sheet
                                       playerId:(NSString *)playerId
                                           date:(NSString *)date
                         inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];
    OverScoreData *record = [self getOverScoreDataWithMusic:music
                                                      sheet:sheet
                                                   playerId:playerId
                                     inManagedObjectContext:context];
    if (record != nil) {
        record.updateDate = date;
        [context save:nil];
    }
    return record;
}

// Ghidra: @ 0xba3d4
+ (NSUInteger)updateOverScoreTouchedWithMusic:(int)music
                       inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"music==%d", music];
    NSArray *results = [context executeFetchRequest:OverScoreFetch(context, p) error:nil];
    if (results == nil || results.count == 0) {
        return 0;
    }
    for (OverScoreData *record in results) {
        record.isTouched = [NSNumber numberWithInt:1];
    }
    [context save:nil];
    return results.count;
}

// Ghidra: @ 0xba5e4
+ (OverScoreData *)addRecordWithMusic:(int)music
                                sheet:(short)sheet
                             playerId:(NSString *)playerId
                                 date:(NSString *)date
               inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];
    OverScoreData *record = [NSEntityDescription insertNewObjectForEntityForName:@"OverScoreData"
                                                         inManagedObjectContext:context];
    record.music = [NSNumber numberWithInt:music];
    record.sheet = [NSNumber numberWithShort:sheet];
    record.playerId = playerId;
    record.updateDate = date;
    record.isTouched = nil; // original sets 0 (nil pointer arg to setIsTouched:)
    [context save:nil];
    return record;
}

// Ghidra: @ 0xba6e8
+ (NSUInteger)deleteRecordWithMusic:(int)music
             inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"music==%d", music];
    NSArray *results = [context executeFetchRequest:OverScoreFetch(context, p) error:nil];
    if (results == nil || results.count == 0) {
        return 0;
    }
    for (OverScoreData *record in results) {
        [context deleteObject:record];
    }
    [context save:nil];
    return results.count;
}

// Ghidra: @ 0xba8d8
+ (NSUInteger)deleteRecordWithMusic:(int)music
                              sheet:(short)sheet
             inManagedObjectContext:(NSManagedObjectContext *)context {
    [context reset];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"music==%d and sheet==%d",
                      music, (int)sheet];
    NSArray *results = [context executeFetchRequest:OverScoreFetch(context, p) error:nil];
    if (results == nil || results.count == 0) {
        return 0;
    }
    for (OverScoreData *record in results) {
        [context deleteObject:record];
    }
    [context save:nil];
    return results.count;
}

@end
