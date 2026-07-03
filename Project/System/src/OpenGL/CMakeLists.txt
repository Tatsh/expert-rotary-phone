# CMakeLists.txt — Project/System/src/OpenGL
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(popnrhythmin PRIVATE
    neGLES11.cpp
    neGLES11.h
)

target_include_directories(popnrhythmin PRIVATE .)
