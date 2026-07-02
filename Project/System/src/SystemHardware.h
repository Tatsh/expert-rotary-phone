//
//  SystemHardware.h
//  pop'n rhythmin
//
//  Lazily-detected device model (engine-side, coarser 14-entry table than the
//  AppDelegate variant). Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#import <Foundation/Foundation.h>

@interface SystemHardware : NSObject

// Detect the model via hw.machine (no-op once detected). Ghidra: @ 0x127f4
- (void)initHardware;

// Lazily detect, then return the model index (14 = unknown). Ghidra: @ 0x128e8
- (int)getHardwareType;

// Lazily detect, then return the hw.machine string. Ghidra: @ 0x1291c
- (NSString *)getHardwareName;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
