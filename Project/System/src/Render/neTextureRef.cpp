//
//  neTextureRef.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Destructors
//  for the single-texture handle and the multi-frame set; both drop their
//  AepTexture cache references (neTextureRelease) and free their backing
//  arrays.
//

#import "neTextureRef.h"
#import "AepTexture.h" // neTextureRelease (shared cache release)

// Ghidra: FUN_00015edc — drop this handle's shared-cache reference.
// @complete
neTextureRef::~neTextureRef() {
    if (texture != nullptr) {
        neTextureRelease(texture);
        texture = nullptr;
    }
}

// @ 0x16710
// Ghidra: FUN_00016710 — write one per-frame render-state slot (meta[slot] =
// value).
// @complete
void neTextureRef::setRenderStateSlot(int slot, int value) {
    meta[slot] = value;
}

// Ghidra: FUN_00011838 — release every frame texture; the parallel arrays (and,
// with them, each neTextureRef record's own cache reference) are freed by their
// unique_ptrs in reverse declaration order, matching the shipped last-to-first
// teardown.
// @complete
neTextureFrames::~neTextureFrames() {
    for (int i = 0; i < frameCount; ++i) {
        if (handles && handles[i] != nullptr) {
            neTextureRelease(handles[i]);
        }
    }
}

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
