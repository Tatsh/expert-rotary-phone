/** @file
 * The Aep animated frame-tree renderer. For the current frame it walks a layer's frame-entry
 * chain, interpolates every keyframe channel (position, scale, colour/alpha, rotation) in the
 * engine's integer fixed-point form, composes the parent transform and blend flags, clips against
 * the active clip rect, and then per entry type emits a sprite command into the ordering table,
 * recurses into a child layer, or invokes the group draw callback.
 */

#pragma once

#include <cstdint>

#import <Foundation/Foundation.h>

class AepManager;

/**
 * @brief Per-frame group draw callback installed by the play, result, and sugoroku scenes.
 *
 * The callback receives the fully-composed child transform. Scenes that only need the context still
 * install a `void(*)(void*)`; AepManager stores it as this wider type and the two forms share the
 * same first (or, via the context slot, only) argument.
 *
 * @param child Sub-layer index passed through to the scene.
 * @param frame Remapped child frame.
 * @param x Composed translation X.
 * @param y Composed translation Y.
 * @param scaleX Composed scale X as a percentage.
 * @param scaleY Composed scale Y as a percentage.
 * @param anchorX Pivot X.
 * @param anchorY Pivot Y.
 * @param color Colour (brightness) channel value.
 * @param alpha Alpha channel value.
 * @param rotation Composed rotation.
 * @param blend Composed blend word.
 * @param clipRect Pointer to the four-int clip rect.
 * @param priority Ordering-table priority.
 * @param context Scene-supplied context pointer.
 */
using AepGroupDrawFn = void (*)(int child,
                                int frame,
                                int x,
                                int y,
                                int scaleX,
                                int scaleY,
                                int anchorX,
                                int anchorY,
                                int color,
                                int alpha,
                                int rotation,
                                uint32_t blend,
                                int *clipRect,
                                uint32_t priority,
                                void *context);

/**
 * @brief One 36-byte frame-data entry (stride 0x24).
 *
 * Each entry animates one child over the frame range [frameStart, frameEnd); `type` selects how it
 * emits. The four channel fields hold byte offsets into the group's idx buffer (0 = channel
 * absent); AepDrawLayer resolves them against AepManager::channelBase().
 */
struct AepFrameEntry {
    int16_t type;         /*!< Entry kind: 0 = leaf sprite, 2 = nested layer, 3 = group callback
                             (+0x00). */
    int16_t child;        /*!< Sprite record or sub-layer index (+0x02). */
    int16_t blendFlags;   /*!< Per-entry blend bits (0x30 / 0xc0 / 0x400 composed at draw)
                             (+0x04). */
    int16_t frameSpeed;   /*!< Child frame remap divisor (>0 => childFrame = local*100/frameSpeed)
                             (+0x06). */
    int16_t frameStart;   /*!< First frame the entry is active on (+0x08). */
    int16_t frameEnd;     /*!< One past the last active frame (+0x0a). */
    int16_t loopOffset;   /*!< Offset added to the child's local frame (+0x0c). */
    int16_t reserved0e;   /*!< Reserved (+0x0e). */
    int16_t anchorX;      /*!< Pivot X (child arg9); doubles as the sprite width for a leaf
                             (+0x10). */
    int16_t anchorY;      /*!< Pivot Y (child arg10); doubles as the sprite height for a leaf
                             (+0x12). */
    int32_t posChannel;   /*!< x/y keyframes (offset into the idx buffer, 0 = none) (+0x14). */
    int32_t scaleChannel; /*!< sx/sy keyframes (+0x18). */
    int32_t colorChannel; /*!< Colour/alpha keyframes (+0x1c). */
    int32_t rotChannel;   /*!< Rotation keyframes (double-indirect: *(int*)(base+rotChannel) + base)
                             (+0x20). */
};

/**
 * @brief A resolved 2D transform threaded into the compatibility drawLayer overload.
 */
struct AepTransform {
    float x = 0;        /*!< Translation X. */
    float y = 0;        /*!< Translation Y. */
    float sx = 100;     /*!< Scale X as a percentage. */
    float sy = 100;     /*!< Scale Y as a percentage. */
    float rotation = 0; /*!< Rotation in degrees. */
    int priority = 0;   /*!< Ordering-table priority. */
};

/**
 * @brief Draw one already-resolved sprite handle straight into the ordering table.
 *
 * Handles a note, effect, or digit atlas quad. `handle` encodes the resource group in bits 16..
 * (indexing AepManager::groupSlotForHandle) and the 8-byte sprite record in bits 0..15. The
 * remaining arguments are the composed transform, anchor, colour, alpha, rotation, blend, and clip
 * that the play and result per-frame draw passes thread in per sprite.
 *
 * @ghidraAddress 0xfcd0
 * @param mgr The Aep manager owning the sprite records and ordering table.
 * @param handle Packed group slot (bits 16..) and sprite record (bits 0..15).
 * @param x Screen position X.
 * @param y Screen position Y.
 * @param scaleX Scale X as a percentage.
 * @param scaleY Scale Y as a percentage.
 * @param rotation Packed rotation word.
 * @param anchorX Pivot X, which also serves as the quad width.
 * @param anchorY Pivot Y, which also serves as the quad height.
 * @param color Colour (brightness) 0..100.
 * @param alpha Alpha 0..100.
 * @param blend Packed blend word.
 * @param colorMul Packed 0x00RRGGBB colour multiplier.
 * @param clipRect Pointer to the four-int clip rect (nullptr = full screen).
 * @param priority Ordering-table priority.
 * @param visFlag Visibility or natural-scale flag.
 */
void AepDrawSpriteHandle(AepManager *mgr,
                         int handle,
                         int x,
                         int y,
                         int scaleX,
                         int scaleY,
                         int rotation,
                         int anchorX,
                         int anchorY,
                         int color,
                         int alpha,
                         uint32_t blend,
                         uint32_t colorMul,
                         int *clipRect,
                         int priority,
                         uint32_t visFlag);

/**
 * @brief The name the task draw passes call the sprite-handle draw by.
 *
 * The Aep group-draw callback carries the clip-rect argument as a plain int (its 32-bit ABI slot),
 * so accept it as such and thread it through. Identical to AepDrawSpriteHandle otherwise.
 *
 * @param mgr The Aep manager owning the sprite records and ordering table.
 * @param handle Packed group slot (bits 16..) and sprite record (bits 0..15).
 * @param x Screen position X.
 * @param y Screen position Y.
 * @param scaleX Scale X as a percentage.
 * @param scaleY Scale Y as a percentage.
 * @param rotation Packed rotation word.
 * @param anchorX Pivot X, which also serves as the quad width.
 * @param anchorY Pivot Y, which also serves as the quad height.
 * @param color Colour (brightness) 0..100.
 * @param alpha Alpha 0..100.
 * @param blend Packed blend word.
 * @param colorMul Packed 0x00RRGGBB colour multiplier.
 * @param clipRect Pointer to the four-int clip rect (nullptr = full screen).
 * @param priority Ordering-table priority.
 * @param visFlag Visibility or natural-scale flag.
 */
inline void drawAepFrameEx(AepManager *mgr,
                           int handle,
                           int x,
                           int y,
                           int scaleX,
                           int scaleY,
                           int rotation,
                           int anchorX,
                           int anchorY,
                           int color,
                           int alpha,
                           uint32_t blend,
                           uint32_t colorMul,
                           int *clipRect,
                           int priority,
                           uint32_t visFlag) {
    // clipRect is a pointer to the 4-int clip rect (nullptr = full screen). It
    // was previously typed `int` and reinterpret-cast to a pointer, which
    // truncated it on 64-bit; pass the real pointer through. Callers passing 0
    // still get a null clip.
    AepDrawSpriteHandle(mgr,
                        handle,
                        x,
                        y,
                        scaleX,
                        scaleY,
                        rotation,
                        anchorX,
                        anchorY,
                        color,
                        alpha,
                        blend,
                        colorMul,
                        clipRect,
                        priority,
                        visFlag);
}

/**
 * @brief Draw a single sprite-atlas frame by its packed handle with a default transform.
 *
 * The transform is 100%, opaque, unrotated, and un-clipped, queued straight into the ordering
 * table. `id` encodes the resource group in bits 16.. and the 8-byte sprite record in bits 0..15.
 * This is the simplified sibling of AepDrawSpriteHandle used by the difficulty-frame and badge UI
 * draws.
 *
 * @ghidraAddress 0xfc58
 * @param mgr The Aep manager owning the sprite records and ordering table.
 * @param id Packed group slot (bits 16..) and sprite record (bits 0..15).
 * @param x Screen position X.
 * @param y Screen position Y.
 * @param blend Packed blend word.
 * @param priority Ordering-table priority.
 */
void drawAepFrame(AepManager *mgr, int id, int x, int y, uint32_t blend, uint32_t priority);

/**
 * @brief The faithful full-signature core of the frame-tree renderer.
 *
 * `mgr` and `groupSlot` locate the frame-entry array, channel buffer, sprite records, ordering
 * table, group callback, and screen extents; the remaining arguments are the composed parent
 * transform, colour/alpha, rotation, blend flags, and clip rect threaded down the frame tree.
 *
 * @ghidraAddress 0xfe8c
 * @param mgr The Aep manager owning the frame data and ordering table.
 * @param groupSlot Resource group slot selecting the frame-entry array.
 * @param layerNo Layer index within the frame-entry array.
 * @param frame Current frame.
 * @param x Composed translation X.
 * @param y Composed translation Y.
 * @param scaleX Composed scale X as a percentage.
 * @param scaleY Composed scale Y as a percentage.
 * @param anchorX Pivot X.
 * @param anchorY Pivot Y.
 * @param color Colour (brightness) channel value.
 * @param colorHi High colour/alpha accumulator value.
 * @param rotation Composed rotation.
 * @param blendFlags Composed blend flags.
 * @param colorRGB Packed 0x00RRGGBB colour.
 * @param clipRect Pointer to the four-int clip rect.
 * @param priority Ordering-table priority.
 * @param context Scene-supplied callback context.
 * @param visFlag Visibility or natural-scale flag.
 */
void AepDrawLayer(AepManager *mgr,
                  int groupSlot,
                  int layerNo,
                  int frame,
                  int x,
                  int y,
                  int scaleX,
                  int scaleY,
                  int anchorX,
                  int anchorY,
                  int color,
                  int colorHi,
                  uint32_t rotation,
                  uint32_t blendFlags,
                  uint32_t colorRGB,
                  int *clipRect,
                  uint32_t priority,
                  void *context,
                  uint32_t visFlag);

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
