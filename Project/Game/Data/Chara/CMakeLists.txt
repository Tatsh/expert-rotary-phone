# CMakeLists.txt — Project/Game/Data/Chara
#
# Per-directory source list for the PopnRhythmin app target (defined in the root
# CMakeLists.txt). Adds this directory's translation units and puts the directory
# on the include path so its quote-imported headers resolve. Regenerate with the
# generator in the repo if you add/rename files, or just edit by hand.

target_sources(popnrhythmin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/CharaData.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/CharaInfo.m
    ${CMAKE_CURRENT_SOURCE_DIR}/CharaManager.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/LimitedCharaInfo.m
    ${CMAKE_CURRENT_SOURCE_DIR}/PreferredCharaInfo.m
    ${CMAKE_CURRENT_SOURCE_DIR}/SkillData.mm
)

target_include_directories(popnrhythmin PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
