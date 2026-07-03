# CMakeLists.txt — Project/Game/Data
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_include_directories(popnrhythmin PRIVATE .)

add_subdirectory(Chara)
add_subdirectory(Music)
add_subdirectory(Save)
add_subdirectory(TreasureMap)
