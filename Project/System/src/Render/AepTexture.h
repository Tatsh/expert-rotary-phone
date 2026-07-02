//
//  AepTexture.h
//  pop'n rhythmin
//
//  A GL texture loaded from an image file, referenced by AepLyrCtrl layers.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  Layout from the constructor (FUN_00011818, 0x18 bytes); load = FUN_00011a2c.
//

#pragma once

class AepTexture {
public:
    AepTexture();                    // Ghidra: FUN_00011818
    virtual ~AepTexture();

    // Decode an image file (png/…) and upload it as a GL texture.
    // Returns 0 on success (negative error codes otherwise). Ghidra: FUN_00011a2c
    // -> FUN_0001bbf0 (image decode) + FUN_000166ec (GL upload).
    int load(const char *path);

    int width() const { return m_width; }
    int height() const { return m_height; }

protected:
    void *m_field4;   // +0x04
    int m_width;      // +0x08  (from decoded image, record+0x1c)
    int m_height;     // +0x0c  (record+0x20)
    void *m_image;    // +0x10  (decoded image record / GL name)
    void *m_buffer;   // +0x14
};

// kate: hl C++; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=cpp sw=4 ts=4 et :
// code: language=cpp insertSpaces=true tabSize=4
