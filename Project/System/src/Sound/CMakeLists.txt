# CMakeLists.txt — Project/System/src/Sound
#
# Per-directory source list for the PopnRhythmin app target (defined in the root
# CMakeLists.txt). Adds this directory's translation units and puts the directory
# on the include path so its quote-imported headers resolve. Regenerate with the
# generator in the repo if you add/rename files, or just edit by hand.

target_sources(popnrhythmin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/AudioManager.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/CAComponent.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/CASound.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/neAVCAPlayer.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/neAVSePlayer.mm
)

target_include_directories(popnrhythmin PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
