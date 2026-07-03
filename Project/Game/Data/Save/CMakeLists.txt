# CMakeLists.txt — Project/Game/Data/Save
#
# Per-directory source list for the PopnRhythmin app target (defined in the root
# CMakeLists.txt). Adds this directory's translation units and puts the directory
# on the include path so its quote-imported headers resolve. Regenerate with the
# generator in the repo if you add/rename files, or just edit by hand.

target_sources(popnrhythmin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/ArcadeScoreData+Store.m
    ${CMAKE_CURRENT_SOURCE_DIR}/ArcadeScoreData.m
    ${CMAKE_CURRENT_SOURCE_DIR}/CharaTicketData+Store.m
    ${CMAKE_CURRENT_SOURCE_DIR}/CharaTicketData.m
    ${CMAKE_CURRENT_SOURCE_DIR}/OverScoreData+Store.m
    ${CMAKE_CURRENT_SOURCE_DIR}/OverScoreData.m
    ${CMAKE_CURRENT_SOURCE_DIR}/ScoreData+Store.m
    ${CMAKE_CURRENT_SOURCE_DIR}/ScoreData.m
    ${CMAKE_CURRENT_SOURCE_DIR}/TreasureData+Store.m
    ${CMAKE_CURRENT_SOURCE_DIR}/TreasureData.m
    ${CMAKE_CURRENT_SOURCE_DIR}/UserSettingData.mm
)

target_include_directories(popnrhythmin PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
