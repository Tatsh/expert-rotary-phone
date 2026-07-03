# CMakeLists.txt — Project/System/src
#
# Per-directory source list for the PopnRhythmin app target (defined in the root
# CMakeLists.txt). Adds this directory's translation units and puts the directory
# on the include path so its quote-imported headers resolve. Regenerate with the
# generator in the repo if you add/rename files, or just edit by hand.

target_sources(popnrhythmin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/SystemHardware.m
    ${CMAKE_CURRENT_SOURCE_DIR}/neEngineBridge.mm
)

target_include_directories(popnrhythmin PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

add_subdirectory(Aep)
add_subdirectory(OpenGL)
add_subdirectory(Render)
add_subdirectory(Sound)
add_subdirectory(Task)
add_subdirectory(Util)
