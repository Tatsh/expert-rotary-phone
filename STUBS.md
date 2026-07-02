# STUBS — systematic inventory of incomplete reconstructions
# Updated after the second agent round (AepTexture cache + play score/SE).

## (a) (void)local casts remaining
Project/System/src/Task/AcMainTask.mm:30:    (void)aep; (void)nm;

## (b) declared real-ref units still needing a body
PlayTaskInit (FUN_0002e2d8) / PlayTaskGotoResult (FUN_0003003c) — declared in PlayTask.h, called from PlayTask.mm
AepManager .idx internal-pointer format (modelled as offsets; baked-pointer scheme documented)

## (c) large deferred functions
AcMainTask::update — 24KB arcade state machine (FUN_00099d18) — the single largest
StoreMainViewController::viewDidLoad — NEON-obscured CGRect geometry
MenuMainTask::setup tail — news-text/RewardNetwork/event-unlock scan

## DONE this session (removed from stubs):
loadAepData, readIndexFile, AepLoad/UnloadGroup, neTextureForiOS::loadFrames,
AepTextureCacheAcquire, AepTextureUploadTiles(2-arg), PlayJudge milestone SE,
PlayCurrentScore, PlayScoreGaugeUpdate, PlayEndResultSe, SeInstance controllers,
NoteMng::totalNoteCount/isFinished(decl), PlayTask case-6 song-end,
MenuMainTask setup+overlay, all extern seams, all byte-verified strings.
