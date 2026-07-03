# CMakeLists.txt — Project/Game/Data/Chara
#
# Adds this directory's translation units (and headers, for Xcode) to the single app target
# defined in the root CMakeLists, and puts the directory on the include path. Bare filenames.

target_sources(popnrhythmin PRIVATE
    CharaData.mm
    CharaInfo.m
    CharaManager.mm
    LimitedCharaInfo.m
    PreferredCharaInfo.m
    SkillData.mm
    CharaData.h
    CharaInfo.h
    CharaManager.h
    LimitedCharaInfo.h
    PreferredCharaInfo.h
    SkillData.h
)

target_include_directories(popnrhythmin PRIVATE .)
