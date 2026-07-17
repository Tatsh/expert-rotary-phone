//
//  C_SINGLE_SPRITE.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The single
//  sprite record (ne::C_SINGLE_SPRITE) and the multi-frame set (neTextureFrames);
//  both drop their ne::C_TEXTURE cache references (neTextureRelease) and free their
//  backing arrays.
//

#import "C_SINGLE_SPRITE.h"
#import "C_TEXTURE.h" // neTextureRelease (shared cache release)

namespace ne {

// Ghidra: FUN_00015eb4 — clears the two render-state words and defaults the tile
// span to 7x7; the vtable pointer is written by the compiler-generated prologue.
// @complete
C_SINGLE_SPRITE::C_SINGLE_SPRITE() = default;

// Ghidra: FUN_00015edc — NOT a defaulted destructor: it drops the reference the
// upload path retained on the sprite's bound texture (+0x04) via neTextureRelease
// (FUN_00018200), then leaves the compiler-emitted operator-delete thunk to free
// the storage.
// @complete
C_SINGLE_SPRITE::~C_SINGLE_SPRITE() {
    if (texture != nullptr) {
        neTextureRelease(texture);
        texture = nullptr;
    }
}

// @ 0x16710
// Ghidra: FUN_00016710 — write one per-frame render-state slot (meta[slot] =
// value).
// @complete
void C_SINGLE_SPRITE::setRenderStateSlot(int slot, int value) {
    meta[slot] = value;
}

} // namespace ne

// Ghidra: FUN_00011838 — release every frame texture; the parallel arrays (and,
// with them, each C_SINGLE_SPRITE record's own cache reference) are freed by their
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
