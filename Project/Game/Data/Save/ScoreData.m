//
//  ScoreData.m
//  pop'n rhythmin
//

#import "ScoreData.h"

@implementation ScoreData

@dynamic musicId;
@dynamic scoreN;
@dynamic scoreH;
@dynamic scoreEx;
@dynamic rankN;
@dynamic rankH;
@dynamic rankEx;
@dynamic fullComboN;
@dynamic fullComboH;
@dynamic fullComboEx;
@dynamic perfectN;
@dynamic perfectH;
@dynamic perfectEx;
@dynamic playCntN;
@dynamic playCntH;
@dynamic playCntEx;
@dynamic lastPlayDate;
@dynamic chksco;

// Delete every persisted ScoreData row (called by -[UserSettingData
// initForConvert]).
// @ 0x6dd44
+ (void)deleteAll:(NSManagedObjectContext *)context {
    [context reset];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ScoreData"
                                 inManagedObjectContext:context];
    NSArray *all = [context executeFetchRequest:request error:NULL];
    if (all.count != 0) {
        for (NSManagedObject *object in all) {
            [context deleteObject:object];
        }
        NSError *error = nil;
        [context save:&error];
    }
}

@end
