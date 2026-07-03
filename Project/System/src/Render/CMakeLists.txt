# CMakeLists.txt — Project/System/src/Render
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(popnrhythmin PRIVATE
    AepTexture.mm
    neGLView.mm
    neGraphics.cpp
    neTextureForiOS.cpp
    AepTexture.h
    neGLView.h
    neGraphics.h
    neTextureForiOS.h
)

target_include_directories(popnrhythmin PRIVATE .)
