# CMakeLists.txt — Project/Game/Data/Music
#
# Per-directory source list for the PopnRhythmin app target (defined in the root
# CMakeLists.txt). Adds this directory's translation units and puts the directory
# on the include path so its quote-imported headers resolve. Regenerate with the
# generator in the repo if you add/rename files, or just edit by hand.

target_sources(popnrhythmin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/AcMusicData.m
    ${CMAKE_CURRENT_SOURCE_DIR}/MusicData.m
    ${CMAKE_CURRENT_SOURCE_DIR}/MusicManager.m
    ${CMAKE_CURRENT_SOURCE_DIR}/MusicPatch.m
)

target_include_directories(popnrhythmin PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
