//
//  neTextureRef.h
//  pop'n rhythmin
//
//  Two small ref-counted texture holders that sit on top of the shared AepTexture
//  cache: a single-texture handle (neTextureRef) and a multi-frame set (neTextureFrames,
//  e.g. an animation loaded from an index blob). Both release their AepTexture cache
//  references on destruction. Reconstructed from Ghidra project rb420, program
//  PopnRhythmin.
//

#pragma once

#include <cstdint>
#include <memory>

// A polymorphic single-texture handle. +0x04 holds the cached AepTexture, released on
// destroy; the remaining metadata fills out a 0x18-byte record (neTextureFrames stores
// these contiguously). Ghidra: dtor FUN_00015edc.
class neTextureRef {
public:
    virtual ~neTextureRef();   // Ghidra: FUN_00015edc (+ compiler-emitted deleting dtor FUN_00015f00)

    void *texture = nullptr;   // +0x04 AepTexture* (cache reference)
    int32_t meta[4] = {};      // +0x08..+0x17 per-frame metadata
};

// A set of animation frames: parallel heap arrays (all `frameCount` long) of per-frame
// padded texture size, the cached AepTexture handles and the neTextureRef records. Each
// array is owned (RAII); the handles are additionally cache-released in the destructor.
// Ghidra: dtor FUN_00011838.
class neTextureFrames {
public:
    virtual ~neTextureFrames();   // Ghidra: FUN_00011838 (+ compiler-emitted deleting dtor FUN_0001198c)

    int32_t frameCount = 0;                    // +0x04
    std::unique_ptr<int32_t[]> frameWidths;    // +0x08
    std::unique_ptr<int32_t[]> frameHeights;   // +0x0c
    std::unique_ptr<void *[]> handles;         // +0x10 AepTexture*[] (each cache-released)
    std::unique_ptr<neTextureRef[]> frames;    // +0x14
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
