# STUBS — systematic inventory of incomplete reconstructions
# (void)local markers: 0. All extern seams: removed. All Japanese strings: byte-verified.

## Corrections (verify-before-trust catches)
- Judge-tier enum was reversed. NoteMng's hit-tally columns are, worst->best,
  BAD(flag8,+0x5164) / GOOD(flag1,+0x5168) / GREAT(flag2,+0x516c) / COOL(flag4,+0x5170),
  which is the order the scorer weights 0/0.4/0.7/1.0 (FUN_0002ff7c) and the result path
  (FUN_0003003c) and spotless predicate (FUN_00031868) read. The enum had COOL=0..BAD=3,
  so PlayScore.mm scored the miss column at weight 1.0. Fixed the enum + judgeNoteHit
  labels (indices unchanged, so behaviour of the note engine is identical); this also
  makes PlayScene.mm's result recording read the right columns.
- Minor caveat (not blocking): PlayScore.mm's spotless check uses totalNoteCount()
  (DAT_00178ccc) as the threshold; the binary compares against *(short*)(NoteMng+0x28).
  Almost certainly the same chart-total value, stored separately.

## Explicitly-deferred large units (documented in-file, not disguised)
- AcMainTask::update (FUN_00099d18) — 24KB arcade state machine, the binary's largest function.
  Being reconstructed IN PIECES from .decompile/AcMainTask_update.c:
    * DONE: ctor, update() touch/SE preamble + state dispatch, states 0 (stateInit),
      1 (stateFadeIn), 2 (stateTreasureCheck).
    * TODO states 3..9+ (case 3 saves treasureTmp + AepLyrCtrl combo layers, etc.).
    * TODO sub-pieces called by the above (declared real methods, bodies pending):
      AcMainTask::setupScene (FUN_0009fc90), AcMainTask::loadTreasureMap (FUN_000a0b58).
    * DONE: the +0x4f4 sub-object is the xorshift128 PRNG, now fully reconstructed as
      Project/Game/Util/Random.{h,cpp} (ctor FUN_00062b20, dtor FUN_00062b54, setSeed
      FUN_00062b5c, getRandRangeInt FUN_00062be0 == GetRandRangeInt in the original
      Random.cpp). The ctor placement-constructs it.
- StoreMainViewController::viewDidLoad (FUN_00042eec) — NEON-obscured CGRect geometry
- MenuMainTask::setup tail — news-text / RewardNetwork / event-unlock scan

## Declared real-ref units still needing a body
- PlayTaskInit / PlayTaskGotoResult (FUN_0002e2d8 / FUN_0003003c) — DONE (PlayScene.mm).
  Delegated helpers still needing a body:
    * PlayLoadSong (FUN_00030720) — also the site that should set NoteMng::setPlayActive(true)
      (the +0x13cb6 flag PlayNoteMngDetach clears).
    * PlayBuildFieldLayers (16 AepLyrCtrl layers + handle table), PlayLoadCharaTextures.
    * PlayTaskDraw (FUN_00030944) — large per-note draw dispatcher (delegated draw unit,
      like PlayJudge's note-quad geometry).
    * PlayResultCreateTask (FUN_0003d5bc, the result-screen task ctor).
    * DONE: PlayNoteMngDetach (FUN_0003395c) — clears NoteMng's play-active flag.

## Whole subsystems not started
- Task #7: settings sub-tables, map/sugoroku UI (SugorokuMainTask FUN_000215a0), tutorial task (FUN_0002db10)
- Task #6 friend VCs (data/networking layer done; the request/score VCs remain)
- Task #5 store detail VCs (StoreDetailViewController @0x72d1c) + the StoreMainVC table datasource
