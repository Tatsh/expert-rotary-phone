# CMakeLists.txt — Project/Game/Data
#
# Adds this directory's translation units (and headers, for Xcode project navigation +
# its dep tracking) to the single app target defined in the root CMakeLists, and puts the
# directory on the include path. Bare filenames — this CMakeLists is co-located with them.
# (Make/Ninja track header deps automatically via compiler depfiles; the headers are listed
# for the Xcode generator's benefit.)

target_include_directories(popnrhythmin PRIVATE .)

add_subdirectory(Chara)
add_subdirectory(Music)
add_subdirectory(Save)
add_subdirectory(TreasureMap)
