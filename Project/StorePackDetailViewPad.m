//
//  StorePackDetailViewPad.m
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#import "StorePackDetailViewPad.h"
#import "StorePackInfo.h"

@implementation StorePackDetailViewPad

@synthesize delegate = m_Delegate;

// @ 0x50b58 — retaining setter for the displayed pack (synthesized in the binary).
- (StorePackInfo *)packInfo {
    return m_PackInfo;
}

- (void)setPackInfo:(StorePackInfo *)packInfo {
    if (m_PackInfo != packInfo) {
        [m_PackInfo release];
        m_PackInfo = [packInfo retain];
    }
}

- (void)dealloc {
    [m_PackInfo release];
    [super dealloc];
}

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
