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


// Delete every persisted ScoreData row (called by -[UserSettingData initForConvert]).
+ (void)deleteAll:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"ScoreData" inManagedObjectContext:context];
    NSArray *all = [context executeFetchRequest:request error:NULL];
    for (NSManagedObject *object in all) {
        [context deleteObject:object];
    }
}

@end
