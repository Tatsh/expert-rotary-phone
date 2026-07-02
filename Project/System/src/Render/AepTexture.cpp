//
//  AepTexture.cpp
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//

#include <cctype>
#include <string>

#include "AepTexture.h"

// Engine helpers (cited; reconstructed elsewhere).
extern "C" {
// Decode an image file into an engine image record (width @ +0x1c, height @ +0x20).
void *neDecodeImage(const char *path);   // Ghidra: FUN_0001bbf0
// Upload the decoded pixels as a GL texture via neGLES_11.
void neUploadGLTexture(void *buffer);    // Ghidra: FUN_000166ec
}

AepTexture::AepTexture()
    : m_field4(nullptr), m_width(0), m_height(0), m_image(nullptr), m_buffer(nullptr) {
    // Ghidra: FUN_00011818.
}

AepTexture::~AepTexture() = default;

// Ghidra: FUN_00011a2c.
int AepTexture::load(const char *path) {
    if (path == nullptr) {
        return -1;
    }

    // The original lowercases a copy of the path (for extension sniffing).
    std::string lower(path);
    for (char &c : lower) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }

    void *record = neDecodeImage(path);
    m_image = record;
    if (record == nullptr) {
        return -5;   // original returns 0xfffffffb on decode failure
    }

    m_width = *reinterpret_cast<int *>(static_cast<char *>(record) + 0x1c);
    m_height = *reinterpret_cast<int *>(static_cast<char *>(record) + 0x20);

    neUploadGLTexture(m_buffer);
    return 0;
}
