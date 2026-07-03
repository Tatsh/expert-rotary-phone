# CMakeLists.txt — Project/System/src/Sound
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(popnrhythmin PRIVATE
    AudioManager.mm
    CAComponent.mm
    CASound.mm
    neAVCAPlayer.mm
    neAVSePlayer.mm
    AudioManager.h
    CAComponent.h
    CASound.h
    SeInstance.h
    neAVCAPlayer.h
    neAVSePlayer.h
)

target_include_directories(popnrhythmin PRIVATE .)
