# STUBS — systematic inventory of incomplete reconstructions
# Every entry is a place the reconstruction is NOT complete. Remove when real.
# Updated after the agent burndown (loadFrames / PlayJudge SE / MenuMainTask setup done).

## (a) (void)local casts — value fetched, consuming logic stubbed
Project/System/src/Task/AcMainTask.mm:30:    (void)aep; (void)nm;
Project/System/src/Task/PlayTask.mm:86:        (void)nm; (void)audio;
## (a2) (void)member.field casts
Project/System/src/Render/neTextureForiOS.cpp:125:    (void)p.clip;

## (b) real-reference units still needing their own reconstruction (declared + called, body pending)
Project/System/src/Render/neTextureForiOS: AepTextureCacheAcquire (FUN_0001bbf0), AepTextureUploadTiles (FUN_000166ec)
Project/Game/Note/PlayJudge: PlayScoreGaugeUpdate (FUN_00031338); note quad/hit-effect draw (FUN_0000fd64/fcd0)
Project/System/src/Task/MenuMainTask: news-text/RewardNetwork/event-unlock tail of setup(); AepManager getFrmNo/getUsrNo/drawSprite for exact overlay
Project/System/src/Aep/AepManager: neTextureForiOS::loadFrames done; .idx internal-pointer format modelled as offsets
Project/System/src/Task/AcMainTask: 24KB arcade state machine (FUN_00099d18)
Project/StoreMainViewController: viewDidLoad geometry (NEON-obscured)

## (c) comment-only / seam function bodies (grep)
Project/StoreMainViewController.mm:74:// the stretchable pack-cell backgrounds (store_pack_bg_0/1). RECONSTRUCTION DEFERRED:
Project/StoreMainViewController.mm:77:// which are not yet reconstructed. Tracked in HANDOFF.md.
Project/System/src/Task/AcMainTask.mm:7://  its full state machine is a large deferred unit — this carries the ctor and the
Project/System/src/Task/AcMainTask.mm:25:// the arcade result screen. The full ~24 KB per-state logic is a deferred unit; the
Project/System/src/Task/AcMainTask.mm:31:    // TODO(deferred): the arcade select+play state machine (FUN_00099d18). Drives
Project/Game/Note/PlayJudge.mm:29:// The play data is the standard-mode MainTask (not yet reconstructed as a whole).
Project/System/src/Task/MenuMainTask.mm:12://  each is its own reconstruction unit (see HANDOFF).
