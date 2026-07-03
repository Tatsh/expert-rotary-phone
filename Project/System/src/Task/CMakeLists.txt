# CMakeLists.txt — Project/System/src/Task
#
# Per-directory source list for the PopnRhythmin app target (defined in the root
# CMakeLists.txt). Adds this directory's translation units and puts the directory
# on the include path so its quote-imported headers resolve. Regenerate with the
# generator in the repo if you add/rename files, or just edit by hand.

target_sources(popnrhythmin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/AcMainTask.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/BootLogoTask.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/C_TASK.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/MainTask.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/MenuMainTask.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/PlayResultTask.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/PlayScene.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/PlayScore.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/PlayTask.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/TaskFactory.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/TitleTask.mm
)

target_include_directories(popnrhythmin PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
