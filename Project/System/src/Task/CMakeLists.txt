# CMakeLists.txt — Project/System/src/Task
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(popnrhythmin PRIVATE
    AcMainTask.mm
    BootLogoTask.mm
    C_TASK.mm
    MainTask.mm
    MenuMainTask.mm
    PlayResultTask.mm
    PlayScene.mm
    PlayScore.mm
    PlayTask.mm
    TaskFactory.mm
    TitleTask.mm
    AcMainTask.h
    BootLogoTask.h
    C_TASK.h
    MainTask.h
    MenuMainTask.h
    PlayResultTask.h
    PlayTask.h
    TaskFactory.h
    TitleTask.h
)

target_include_directories(popnrhythmin PRIVATE .)
