//
//  MapAnnotation.m
//  pop'n rhythmin
//
//  See MapAnnotation.h. Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "MapAnnotation.h"

@implementation MapAnnotation {
    CLLocationCoordinate2D m_Coordinate;   // @+0x4  (16 bytes: latitude + longitude)
    NSString *m_Title;                     // @+0x14
    NSString *m_SubTitle;                  // @+0x18
    NSString *m_ModelName;                 // @+0x1c
}

// @ 0x850e4 — store the coordinate by value and immutable copies of the three strings.
- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                   Title:(NSString *)title
                SubTitle:(NSString *)subtitle
                   Model:(NSString *)model {
    self = [super init];
    if (self != nil) {
        m_Coordinate = coordinate;
        m_Title = [[NSString alloc] initWithString:title];
        m_SubTitle = [[NSString alloc] initWithString:subtitle];
        m_ModelName = [[NSString alloc] initWithString:model];
    }
    return self;
}

// @ 0x85264 — MKAnnotation coordinate setter.
- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
    m_Coordinate = coordinate;
}

// @ 0x85298 — MKAnnotation coordinate getter.
- (CLLocationCoordinate2D)coordinate {
    return m_Coordinate;
}

// @ 0x852b0 — MKAnnotation title (synthesized nonatomic-copy getter over m_Title).
- (NSString *)title {
    return m_Title;
}

// @ 0x852c4 — MKAnnotation subtitle (synthesized nonatomic-copy getter over m_SubTitle).
- (NSString *)subtitle {
    return m_SubTitle;
}

// @ 0x85288 — the arcade's model name.
- (NSString *)modelName {
    return m_ModelName;
}

// dealloc @ 0x851c8 — ARC-omitted (released object ivars only: m_Title, m_SubTitle, m_ModelName).

@end
