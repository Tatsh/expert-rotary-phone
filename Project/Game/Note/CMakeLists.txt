# CMakeLists.txt — Project/Game/Note
#
# Adds this directory's translation units (and headers, for Xcode project navigation +
# its dep tracking) to the single app target defined in the root CMakeLists, and puts the
# directory on the include path. Bare filenames — this CMakeLists is co-located with them.
# (Make/Ninja track header deps automatically via compiler depfiles; the headers are listed
# for the Xcode generator's benefit.)

target_sources(popnrhythmin PRIVATE
    AcNoteMng.mm
    NoteMng.mm
    PlayJudge.mm
    AcNoteMng.h
    NoteMng.h
    PlayJudge.h
)

target_include_directories(popnrhythmin PRIVATE .)
