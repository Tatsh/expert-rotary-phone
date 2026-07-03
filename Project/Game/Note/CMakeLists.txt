# CMakeLists.txt — Project/Game/Note
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(popnrhythmin PRIVATE
    AcNoteMng.mm
    NoteMng.mm
    PlayJudge.mm
    AcNoteMng.h
    NoteMng.h
    PlayJudge.h
)

target_include_directories(popnrhythmin PRIVATE .)
