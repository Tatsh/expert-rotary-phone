# CMakeLists.txt — Project/Game/Data/Music
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(popnrhythmin PRIVATE
    AcMusicData.m
    MusicData.m
    MusicManager.m
    MusicPatch.m
    AcMusicData.h
    MusicData.h
    MusicManager.h
    MusicPatch.h
)

target_include_directories(popnrhythmin PRIVATE .)
