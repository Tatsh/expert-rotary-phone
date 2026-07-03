# CMakeLists.txt — Project/System/src/Task
#
# Adds this directory's translation units (and headers, for Xcode project navigation +
# its dep tracking) to the single app target defined in the root CMakeLists, and puts the
# directory on the include path. Bare filenames — this CMakeLists is co-located with them.
# (Make/Ninja track header deps automatically via compiler depfiles; the headers are listed
# for the Xcode generator's benefit.)

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
