//
//  AepLyrCtrl.h
//  pop'n rhythmin
//
//  A single drawable layer / sprite in the Aep 2D scene (position, size, color,
//  alpha, a texture reference and its slot in the ordering table). Reconstructed
//  from Ghidra project rb420, program PopnRhythmin.
//
//  Layout derived from the constructor (Ghidra: FUN_0002c7d8, 0x60 bytes);
//  init-with-texture is FUN_0002c834. Several vec3 groups are transform/color
//  channels whose exact roles are still being pinned down.
//

#pragma once

class AepTexture;

class AepLyrCtrl {
public:
    AepLyrCtrl();                     // Ghidra: FUN_0002c7d8
    virtual ~AepLyrCtrl();

    virtual void draw();              // vtable @ PTR_LAB_0002c82c

    // Bind a texture / named resource to this layer. Ghidra: FUN_0002c834.
    void init(int group, const char *name);

protected:
    // +0x04 / +0x08: intrusive links in the ordering table.
    void *m_prev;       // +0x04
    void *m_next;       // +0x08
    int m_texId;        // +0x0c  (-1 = unassigned, sentinel)
    int m_field10;      // +0x10
    float m_x, m_y, m_z;// +0x14..0x1c  position
    int m_width;        // +0x20  (default 100)
    int m_height;       // +0x24  (default 100)
    float m_grpA[3];    // +0x28..0x30  (color or uv)  [roles TBD]
    float m_grpB[3];    // +0x34..0x40  (scale or rotation) [roles TBD]
    float m_alpha;      // +0x44  (default 1.0)
    float m_grpC[4];    // +0x48..0x54
    bool m_flag55;      // +0x55
    bool m_visible;     // +0x59
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
