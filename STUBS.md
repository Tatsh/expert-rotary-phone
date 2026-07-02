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
    * PlayBuildFieldLayers (16 AepLyrCtrl layers + handle table), PlayLoadCharaTextures.
    * PlayTaskDraw (FUN_00030944) — large per-note draw dispatcher (delegated draw unit,
      like PlayJudge's note-quad geometry).
    * PlayResultCreateTask (FUN_0003d5bc) — a NEW task class, PlayResultTask (object
      0x3a0 = C_TASK 0x28 + 0x378 data; ctor just memsets the data + sets the vptr).
      Its update (FUN_0003d690) is a 13-state result screen (analysed, not yet written):
        0  enterResult:   FUN_0003dfe0 (result setup) -> playBgm; ->1
        1  transitionIn:  playTransition(1,30,0); play layers +0x214/+0x228/+0x224;
                          [rootVC releaseCapturedImage]; ->2
        2  sharePresent:  wait +0x214 SE done, then build the Twitter share UIButton
                          (TwitterUtil, UIImage bt_twitter, device-branched geometry) +
                          run the rank-SE cascade; tap dismisses; big state.
        3  playSe + play layer +0x218; ->4
        4  wait +0x218; rank(+0x35c)!=6 ->5 else ->7
        5  stop +0x218, play +0x21c/+0x220; reset +0x388; playSe; ->6
        6  score count-up: SE every 5 counts (+0x37c/+0x388 vs +0x368+0x380); done ->7
        7  tap ->8
        8  DownloadMain isSaveScoreDownLoading ? [rootVC InsertCommunicating],->9 : ->10
        9  wait download done -> [rootVC DeleteCommunicating]; ->10
        10 playTransition(2,30,0); ->0xb
        0xb wait isTransitionDone; ->0xc
        0xc FUN_0003f2e0 (goto next scene)
      Preamble: same released-touch tap detection as AcMainTask; tail calls FUN_0002c924(0).
      New decls it needs: DownloadMain isSaveScoreDownLoading; MainViewController
      InsertCommunicating/DeleteCommunicating/get+releaseCapturedImage; SeInstance ops
      FUN_0002cb64 (is-playing) / FUN_0002cb5c (stop); TwitterUtil initWithText:image:/tweet.
    * DONE: PlayNoteMngDetach (FUN_0003395c) — clears NoteMng's play-active flag.
    * DONE: PlayLoadSong (FUN_00030720) — song resolve + async BGM block + sheet parse +
      tap SE. Pulled in the full MusicData zip-entry accessor family (music/musicPre/
      sheetNormal/Hyper/Ex @ 0xc78d8.. — all reconstructed) and the AudioManager
      loadBgmData:isLoop: method (@ 0x1e5b0, body now built in AudioManager.mm).
  Note: NoteMng::setPlayActive(true) still unlocated (only the read in
  applicationWillResignActive and the clear in PlayNoteMngDetach are found).

## Whole subsystems not started
- Task #7: settings sub-tables, map/sugoroku UI (SugorokuMainTask FUN_000215a0), tutorial task (FUN_0002db10)
- Task #6 friend VCs (data/networking layer done; the request/score VCs remain)
- Task #5 store detail VCs (StoreDetailViewController @0x72d1c) + the StoreMainVC table datasource
