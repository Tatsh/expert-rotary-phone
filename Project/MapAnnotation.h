//
//  MapAnnotation.h
//  pop'n rhythmin
//
//  A map pin for the arcade-locator map: an MKAnnotation carrying a coordinate,
//  a title/subtitle and the arcade's model name. Reconstructed from Ghidra
//  project rb420, program PopnRhythmin
//  (initWithCoordinate:Title:SubTitle:Model: @ 0x850e4, dealloc @ 0x851c8,
//  setCoordinate: @ 0x85264, modelName @ 0x85288, coordinate @ 0x85298, title @
//  0x852b0, subtitle @ 0x852c4).
//
//  Binary Objective-C metadata: superclass NSObject, adopts <MKAnnotation>.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface MapAnnotation : NSObject <MKAnnotation>

// Store the coordinate (copied by value) and copies of the title / subtitle /
// model strings.
- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                   Title:(NSString *)title
                SubTitle:(NSString *)subtitle
                   Model:(NSString *)model;

// MKAnnotation accessors. `coordinate` is read/write here (the class ships
// -setCoordinate:).
@property(nonatomic) CLLocationCoordinate2D coordinate;
@property(nonatomic, readonly, copy) NSString *title;
@property(nonatomic, readonly, copy) NSString *subtitle;

// The arcade's model name (extra, non-protocol accessor).
- (NSString *)modelName;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
