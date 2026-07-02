//
//  AepFrameDraw.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. Populates the
//  ordering-table command buffer from a layer's animation: interpolate each
//  keyframe channel at the current frame, compose with the parent transform, and
//  emit one sprite command per leaf (recursing for nested layers).
//  Ghidra: drawLayer FUN_0000fd64, drawFrameData FUN_0000fe8c, fill FUN_000113d0.
//
//  The original works in 16.16 fixed point with SIMD; the equivalent float lerp
//  is used here (same algorithm, cleaner for the 64-bit rebuild).
//

#import "AepFrameDraw.h"
#import "AepOrderingTable.h"

// Linearly interpolate a keyframe channel at `frame`. Each keyframe is
// { int16 frame, int16 values[n] }; the list is terminated by frame == -1. Before
// the first / after the last keyframe the nearest value is held. Ghidra: the
// per-channel walk-and-lerp blocks inside FUN_0000fe8c.
static void interpChannel(const int16_t *ch, int frame, int n, float *out) {
    if (ch == nullptr) {
        return;   // absent channel: keep the caller's defaults
    }
    const int stride = 1 + n;
    const int16_t *prev = ch;
    const int16_t *cur = ch;
    while (cur[0] != -1 && cur[0] <= frame) {
        prev = cur;
        cur += stride;
    }
    if (cur[0] == -1 || cur == prev) {
        for (int i = 0; i < n; i++) {
            out[i] = (float)prev[1 + i];
        }
    } else {
        const float t = (float)(frame - prev[0]) / (float)(cur[0] - prev[0]);
        for (int i = 0; i < n; i++) {
            out[i] = (float)prev[1 + i] + t * (float)(cur[1 + i] - prev[1 + i]);
        }
    }
}

// Ghidra: FUN_0000fe8c (via drawLayer FUN_0000fd64).
void AepDrawLayer(AepOrderingTable *ot, const AepFrameEntry *entries, int layerNo,
                  int frame, const AepTransform &parent) {
    for (const AepFrameEntry *e = &entries[layerNo]; e->type >= 0 && e->frameStart >= 0; e++) {
        if (frame < e->frameStart || frame >= e->frameEnd) {
            continue;   // this entry is not active on the current frame
        }

        float pos[2] = { 0, 0 };
        float scale[2] = { 100, 100 };
        float rot[1] = { 0 };
        float color[1] = { 255 };
        interpChannel(e->posChannel, frame, 2, pos);
        interpChannel(e->scaleChannel, frame, 2, scale);
        interpChannel(e->rotChannel, frame, 1, rot);
        interpChannel(e->colorChannel, frame, 1, color);

        // Compose this entry's animated transform under the parent's.
        AepTransform xform;
        xform.x = parent.x + pos[0] * parent.sx / 100.0f;
        xform.y = parent.y + pos[1] * parent.sy / 100.0f;
        xform.sx = parent.sx * scale[0] / 100.0f;
        xform.sy = parent.sy * scale[1] / 100.0f;
        xform.rotation = parent.rotation + rot[0];
        xform.priority = parent.priority;

        if (e->type == 0) {
            // Leaf sprite: write a draw command into the ordering table (FUN_000113d0).
            AepSpriteCommand *cmd = ot->allocEntry(xform.priority);
            cmd->textureId = e->child;
            cmd->x = (int)xform.x;
            cmd->y = (int)xform.y;
            cmd->w = e->width;
            cmd->h = e->height;
            cmd->sx = (int)xform.sx;
            cmd->sy = (int)xform.sy;
            cmd->rotation = (int)xform.rotation;
            cmd->color0 = (int16_t)color[0];
        } else if (e->type == 2) {
            // Nested layer: recurse with the composed transform.
            AepDrawLayer(ot, entries, e->child, frame, xform);
        }
        // else: callback-driven entry (the original invokes a per-frame hook).
    }
}
