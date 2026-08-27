/** @file
 * Lazily-detected device model (engine-side, coarser 14-entry table than the AppDelegate
 * variant). Reconstructed from Ghidra project rb420, program PopnRhythmin.
 */

#import <Foundation/Foundation.h>

/**
 * @brief The engine-side device-model probe, resolved lazily from `hw.machine`.
 */
@interface SystemHardware : NSObject

/**
 * @brief The lazily-created shared instance.
 * @return The singleton.
 * @ghidraAddress 0x127ac
 */
+ (instancetype)getInstance;

/**
 * @brief Detect the model via `hw.machine`. A no-op once the model has been detected.
 * @ghidraAddress 0x127f4
 */
- (void)initHardware;

/**
 * @brief Lazily detect the model, then report its table index.
 * @return The model index; 14 for an unknown device.
 * @ghidraAddress 0x128e8
 */
- (int)getHardwareType;

/**
 * @brief Lazily detect the model, then report its raw name.
 * @return The `hw.machine` string.
 * @ghidraAddress 0x1291c
 */
- (NSString *)getHardwareName;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
