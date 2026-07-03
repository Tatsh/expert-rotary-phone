# CMakeLists.txt — Project/System/src/Util
#
# Adds this directory's translation units (and headers, for Xcode project navigation +
# its dep tracking) to the single app target defined in the root CMakeLists, and puts the
# directory on the include path. Bare filenames — this CMakeLists is co-located with them.
# (Make/Ninja track header deps automatically via compiler depfiles; the headers are listed
# for the Xcode generator's benefit.)

target_sources(popnrhythmin PRIVATE
    BFCodec.m
    NSData+Crypt.m
    RhCrypto.c
    RhUtil.m
    BFCodec.h
    NSData+Crypt.h
    RhCrypto.h
    RhUtil.h
    neFrameTimer.h
)

target_include_directories(popnrhythmin PRIVATE .)
