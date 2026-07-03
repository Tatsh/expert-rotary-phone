# CMakeLists.txt — Project/System/src/Aep
#
# Adds this directory's translation units (and headers, for Xcode project navigation +
# its dep tracking) to the single app target defined in the root CMakeLists, and puts the
# directory on the include path. Bare filenames — this CMakeLists is co-located with them.
# (Make/Ninja track header deps automatically via compiler depfiles; the headers are listed
# for the Xcode generator's benefit.)

target_sources(popnrhythmin PRIVATE
    AepFrameDraw.mm
    AepLyrCtrl.mm
    AepManager.mm
    AepOrderingTable.mm
    AepFrameDraw.h
    AepLyrCtrl.h
    AepManager.h
    AepOrderingTable.h
)

target_include_directories(popnrhythmin PRIVATE .)
