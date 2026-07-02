//
//  AepFrameDraw.h
//  pop'n rhythmin
//
//  The Aep animation fill: walks a layer's frame-data channels at the current
//  frame, linearly interpolates each keyframe channel (position, scale, rotation,
//  colour/alpha), applies the parent transform, and emits one sprite command per
//  leaf into the ordering table (recursing for nested layers). Reconstructed from
//  Ghidra project rb420, program PopnRhythmin (drawLayer FUN_0000fd64,
//  drawFrameData FUN_0000fe8c, sprite fill FUN_000113d0).
//

#pragma once

#include <cstdint>

class AepOrderingTable;

// One 36-byte frame-data entry (Ghidra: stride 0x24). Each entry animates one
// child over the frame range [frameStart, frameEnd); `type` picks how it emits.
struct AepFrameEntry {
    int16_t type;         // +0x00  0 = leaf sprite, 2 = nested layer, else callback
    int16_t child;        // +0x02  sprite / sub-layer index
    int16_t reserved4[2]; // +0x04
    int16_t frameStart;   // +0x08
    int16_t frameEnd;     // +0x0a
    int16_t loopOffset;   // +0x0c
    int16_t reserved0e;   // +0x0e
    int16_t width;        // +0x10
    int16_t height;       // +0x12
    const int16_t *posChannel;    // +0x14  x/y keyframes
    const int16_t *scaleChannel;  // +0x18  sx/sy keyframes
    const int16_t *colorChannel;  // +0x1c  colour/alpha keyframes
    const int16_t *rotChannel;    // +0x20  rotation keyframes
};

// A resolved 2D transform threaded down the layer tree.
struct AepTransform {
    float x = 0, y = 0;       // translation
    float sx = 100, sy = 100; // scale (percent)
    float rotation = 0;       // degrees
    int priority = 0;         // ordering-table priority
};

// Draw the layer `layerNo`'s frame `frame` into `ot`, under `parent`. Ghidra:
// drawLayer FUN_0000fd64 -> drawFrameData FUN_0000fe8c.
void AepDrawLayer(AepOrderingTable *ot, const AepFrameEntry *entries, int layerNo,
                  int frame, const AepTransform &parent);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
