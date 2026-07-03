# CMakeLists.txt — Project/Game/Data/Save
#
# Adds this directory's translation units (and headers, for Xcode project navigation +
# its dep tracking) to the single app target defined in the root CMakeLists, and puts the
# directory on the include path. Bare filenames — this CMakeLists is co-located with them.
# (Make/Ninja track header deps automatically via compiler depfiles; the headers are listed
# for the Xcode generator's benefit.)

target_sources(popnrhythmin PRIVATE
    ArcadeScoreData+Store.m
    ArcadeScoreData.m
    CharaTicketData+Store.m
    CharaTicketData.m
    OverScoreData+Store.m
    OverScoreData.m
    ScoreData+Store.m
    ScoreData.m
    TreasureData+Store.m
    TreasureData.m
    UserSettingData.mm
    ArcadeScoreData+Store.h
    ArcadeScoreData.h
    CharaTicketData+Store.h
    CharaTicketData.h
    OverScoreData+Store.h
    OverScoreData.h
    ScoreData+Store.h
    ScoreData.h
    TreasureData+Store.h
    TreasureData.h
    TreasureTmpData.h
    UserSettingData.h
)

target_include_directories(popnrhythmin PRIVATE .)
