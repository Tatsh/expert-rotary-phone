# CMakeLists.txt — Project/System/src/Render
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(popnrhythmin PRIVATE
    AepTexture.mm
    C_SINGLE_SPRITE.cpp
    neGLView.mm
    neGraphics.cpp
    neRenderer.cpp
    neTextTexture.mm
    neTextureForiOS.cpp
    AepTexture.h
    C_SINGLE_SPRITE.h
    neGLView.h
    neGraphics.h
    neRenderer.h
    neTextTexture.h
    neTextureForiOS.h
)

target_include_directories(popnrhythmin PRIVATE .)
