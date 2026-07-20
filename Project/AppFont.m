//
//  AppFont.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "AppFont.h"

#import <UIKit/UIKit.h>

// @ 0x5ef9c — returns the constant font name (CFString
// cf_DFSoGei_W5_WIN_RKSJ_H).
//
// The binary returned this unconditionally: DFSoGei-W5-WIN-RKSJ-H was a Japanese
// system font on the iOS 8 SDK. Modern iOS does not ship it, and the app bundles
// only DFMaruGothic (the prf02w07 TTC has no SoGei face), so fontWithName: returns
// nil for DFSoGei here — which threw in the Store tab-title dictionary and left
// every AppFontName-based UIKit label in the default system face. Fall back to the
// bundled DFMaruGothic (registered by neTextTexture's registerBundledFonts) so
// those labels keep a DynaFont look; still prefer DFSoGei if a device ever has it.
NSString *AppFontName(void) {
    if ([UIFont fontWithName:@"DFSoGei-W5-WIN-RKSJ-H" size:12.0f] != nil) {
        return @"DFSoGei-W5-WIN-RKSJ-H";
    }
    return @"DFMaruGothic-Bd-WIN-RKSJ-H";
}

// @ 0x5efa8 — the rounded gothic face (CFString cf_DFMaruGothic_Bd_WIN_RKSJ_H).
NSString *AppMaruFontName(void) {
    return @"DFMaruGothic-Bd-WIN-RKSJ-H";
}
