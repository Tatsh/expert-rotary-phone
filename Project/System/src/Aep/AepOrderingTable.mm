//
//  AepOrderingTable.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The Aep
//  ordering table as a per-frame sprite command buffer: allocEntry hands out
//  priority-bucketed command entries (get_aepOt FUN_00010be0), and flush walks
//  the buckets high-priority-first, emitting one textured GL quad per command.
//  The binary routes the GL calls through neGLES_11; the equivalent ES 1.1 calls
//  are issued directly here.
//

#include <cassert>

#import <OpenGLES/ES1/gl.h>

#import "AepOrderingTable.h"

AepOrderingTable::AepOrderingTable() {
    reset();
}

// Reset for a new frame: no live commands, empty buckets.
void AepOrderingTable::reset() {
    m_count = 0;
    m_maxPriority = 0;
    m_drawnCount = 0;
    for (int i = 0; i < kOtPriMax; i++) {
        m_buckets[i] = nullptr;
    }
}

// Ghidra: FUN_00010be0 (get_aepOt/allocEntry). Grab the next pool entry, tag it
// with `priority`, and head-insert it into that priority's bucket.
AepSpriteCommand *AepOrderingTable::allocEntry(int priority) {
    assert(m_count < kOtRegistMax);   // AepOrderingTable.mm:0x3d "m_OtCount < OT_REGIST_MAX"
    assert(priority < kOtPriMax);     // AepOrderingTable.mm:0x3e "pri < OT_PRI_MAX"

    AepSpriteCommand *cmd = &m_entries[m_count++];
    cmd->priority = (int16_t)priority;
    if (priority > m_maxPriority) {
        m_maxPriority = priority;
    }
    cmd->next = m_buckets[priority];
    m_buckets[priority] = cmd;
    return cmd;
}

// Emit one command as a textured quad (GL ES 1.1). Position/size/uv/colour come
// from the command the fill (FUN_000113d0) wrote.
static void drawCommand(const AepSpriteCommand &cmd) {
    const float x = (float)cmd.x;
    const float y = (float)cmd.y;
    const float w = (float)cmd.w;
    const float h = (float)cmd.h;

    // Interleaved quad (TRIANGLE_STRIP): top-left, top-right, bottom-left, bottom-right.
    const GLfloat verts[8] = { x, y, x + w, y, x, y + h, x + w, y + h };
    // Source rect in normalised texture space (u/v are 16.16-ish source offsets;
    // reconstructed as a 0..1 span across the sprite's own extent).
    const GLfloat uvs[8] = { 0, 0, 1, 0, 0, 1, 1, 1 };

    glBindTexture(GL_TEXTURE_2D, (GLuint)cmd.textureId);
    glColor4f(1.0f, 1.0f, 1.0f, 1.0f);

    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, verts);
    glTexCoordPointer(2, GL_FLOAT, 0, uvs);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);
}

// Ghidra: FUN_000115d0 — draw the frame: buckets high priority first.
void AepOrderingTable::flush() {
    m_drawnCount = 0;
    for (int pri = m_maxPriority; pri >= 0; pri--) {
        for (AepSpriteCommand *cmd = m_buckets[pri]; cmd != nullptr; cmd = cmd->next) {
            drawCommand(*cmd);
            m_drawnCount++;
        }
    }
    reset();   // the buffer is consumed; ready for the next frame's fill
}
