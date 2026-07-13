//
//  AppFont.h
//  pop'n rhythmin
//
//  The app's shared UI typeface name.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (FUN_0005ef9c).
//

#import <Foundation/Foundation.h>

// C-linkage (defined in AppFont.m) so the C++ (.mm) callers resolve the
// unmangled symbols.
#ifdef __cplusplus
extern "C" {
#endif

// The bundled DynaFont gothic face used for nearly all UIKit text in the app.
NSString *AppFontName(void);

// The rounded ("maru") DynaFont face used for alert/message text.
// Ghidra: FUN_0005efa8.
NSString *AppMaruFontName(void);

#ifdef __cplusplus
}
#endif

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
