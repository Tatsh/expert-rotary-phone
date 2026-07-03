# CMakeLists.txt — Project/Game
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_include_directories(popnrhythmin PRIVATE .)

add_subdirectory(Data)
add_subdirectory(Note)
add_subdirectory(Purchase)
add_subdirectory(Util)
