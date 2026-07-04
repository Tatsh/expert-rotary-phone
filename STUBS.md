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
- MenuMainTask_update (FUN_0006ad88) case 0xc button dispatch mis-mapped +0x168..+0x198
  and mis-attributed the +0x168 task class (address-sweep, 2026-07-04). Verified vs the
  decompile/disasm: +0x168 -> AcViewerTask (ctor FUN_000215a0: operator_new(0x210),
  memset 0x1e8, vtable @0x130bb8 / update FUN_00021678), NOT AcMainTask (ctor FUN_00099ab0,
  0x9fc, vtable @0x1327c8) — Ghidra only labels the 0x130bb8 vtable acMainTask* because
  AppDelegate stores the task in its `acMainTask` property. The reconstruction had a
  spurious SugorokuMainTaskCreate()->new AcMainTask() (there is no sugoroku task; the
  treasure/sugoroku board IS AcMainTask, spawned by +0x158). Replaced with
  AcViewerTaskCreate()->new AcViewerTask() (AcViewerTask had never been instantiated
  anywhere — dead task, now wired to its button). Also: +0x178 -> GotoPopnLink (was invite),
  +0x188 -> invite code (was present box), +0x198 -> GotoArcadeSearch (was the sugoroku
  spawn); present box is the +0x9c TOP-cluster button (hitPresentBoxButton added), not an
  array slot; each array button now plays its SE (m_seInst[k]=[audio playSe:0
  resourceId:m_seId[k]]). Enum + setup() labels renamed to true per-offset roles; rect
  VALUES unchanged (already per-offset correct).
  DOCUMENTED GAP (not gameplay): the +0xa0 "featured/reward" top button -> states 0xf/0x10
  (RewardNetwork openAppListWebViewWithCampaignId offer-wall) is still unwired. Its 7-arg
  web-view call is not cleanly recoverable from the decompile (only campaignId + a stray 0
  survive; company/type/offset/limit/parentView/delegate are register/stack spills) and it
  is a third-party offer-wall, not gameplay. Left as a precise deferral, not invented.

## Verification passes (audited, result recorded)
- AcViewerTask::update (acMainTaskUpdate FUN_00021678) — audited 2026-07-04 right after it
  went live (TaskFactory now does new AcViewerTask(); before that AcViewerTask.o was
  dead-stripped, hiding the AcViewerHudDraw link error since fixed in f64da6b). Result:
  the 16-state machine (0 enter/GotoAcViewer -> 1 wait-song -> 2 setup -> 3 transition+play
  -> 4 wait-transition+ready-SE -> 5 wait-SE+startPlayback -> 6 PLAYING -> 7 end-hold ->
  8/9 teardown+Cleanup -> 10/0xb pause-for-song-select -> 0xc/0xd pause menu -> 0xe options
  sheet -> 0x10 no-song exit + MenuMainTask handoff) is structurally 1:1, and every engine
  call + field offset checks out (difficulty @0x1dc read in loadChartData FUN_0002316c;
  end-hold counter @0x204 = the decompiler's field10_0x28.field77_0x1dc, i.e. 0x28+0x1dc,
  NOT a collision with difficulty; pauseTime @0xfc; state @0x20c). NO behavioural bug found.
  NEON touch recovery (2026-07-04, from the disassembly of FUN_00021678):
    * DONE: the tap classifier + case 6 hit-tests. A released touch is a TAP iff it barely
      moved (|scaled(startX)-scaled(upX)| <= 10 and |scaled(startY)-scaled(upY)| < 11;
      scaled = (int)((float)v / m_uiScale@0x10c)); the scaled up-position is the hit point.
      Case 6 now routes it by position via neGraphics::pointInRect (FUN_0002d974(px,py,
      rx,ry,rw,rh)): tap in the play/song-select rect {x@0x1ec,y@0x1f0,w@0x150,h@0x154} ->
      state 10; tap in the exit/pause rect {x@0x1b4,y@0x1b8,w@0x1bc,h@0x1c0} -> state 0xc
      (the previously-missing on-phone pause path). Carved the exit-rect (0x1b4..0x1c0) and
      play-touch w/h (0x150/0x154) fields byte-exact; m_comboDigitX/Y (0x1ec/0x1f0) double
      as the song-select rect origin. Verified the NEON: vdiv.f32 scale-divide, the pointInRect
      arg shape (r0/r1=point, r2/r3=origin, [sp+0/4]=size), and that m_seekCoef@0xf4 IS the
      drag-Y accumulator (scrub feeds seek).
    * REMAINING (follow-up pass): the per-frame drag ANCHOR + accumulator (0xdc drag id,
      0xe0 start, 0xe8 last, 0xf0 accum, 0xf8 moved) and the two states that consume it:
      case 0xb seek-scrub (the fixed-point gauge/seek math at 0x21fac..0x22016 — a signed
      division by the magic constant 0x08020803 via smmul, then FPToFixed) and the case 0xd
      pause-menu 3-button y-only hit-test (rows at 0x1a4/0x1a8/0x1ac, height 0x1b0, +0x114/2:
      top=options/state 0xe, mid=quit/state 8, bottom=resume). Left as-is (simplified) with
      their fields named as _rsvd until that pass; behaviour there is still approximate.

## Explicitly-deferred large units (documented in-file, not disguised)
- AcMainTask::update (FUN_00099d18) — 24KB arcade state machine, the binary's largest function.
  Being reconstructed IN PIECES from .decompile/AcMainTask_update.c:
    * DONE: ctor, update() touch/SE preamble + state dispatch, states 0 (stateInit),
      1 (stateFadeIn), 2 (stateTreasureCheck).
    * TODO states 3..9+ (case 3 saves treasureTmp + AepLyrCtrl combo layers, etc.).
    * DONE (agent, reviewed): AcMainTask::setupScene (FUN_0009fc90, the sugoroku scene
      builder — ~50 handle tables, ~35 AepLyrCtrl overlays, textures + mode BGM; split
      into setupResolveHandles/BuildOverlays/LoadTextures) and AcMainTask::loadTreasureMap
      (FUN_000a0b58, map load + per-map field snapshot + bg/BGM). New TreasureMap class
      (Game/Data/TreasureMap/, ctor+findArea done; load FUN_000ce340 + dtor are seams).
      All strings byte-verified; no defect found on review (NEON map-scroll math flagged
      best-effort inline). NEW arcade-sugoroku seams now tracked (declared, bodies pending):
      free fns
      AcMainSugorokuDraw (FUN_000a3724, ~5.8KB group-5 draw pass).
    * DONE (agent, reviewed): TreasureMap::load (FUN_000ce340, the map-file parser — header
      0x50, node file-stride 0xaa -> mem-stride 0x120, ShiftJIS messages, rand bonus pick
      persisted via saveTreasureTmp, ConnectStruct edge list), TreasureMap::reset/dtor
      (FUN_000ce2e4/ce330), AcMainUnlockBonusTreasure (FUN_000a345c, board-8 unlock on
      prereq songs 200000204-207 + 208-211). Map format fully byte-verified; no defect on
      review. +[UserSettingData saveTreasureTmp:] (@0x614f0) — DONE (dataWithBytes:len 0x54
      -> saveData:Key:"TreasureTmpData", the inverse of treasureTmp).
    * DONE (agent, reviewed): computeStepValues (FUN_000a1950, step tables {1,2,1,3,1,2,3}/
      {4,5,4,6,4,5,6}), buildSelectListLayout (FUN_000a21a8 — actually loads the 15 roulette
      SEs @+0x438; name inherited from the seam is misleading, documented in-file),
      buildMapCharaLayers (FUN_000a2264 — TreasureData getAllTreasureData -> dual music/wall
      tables), buildMapPanelLayers (FUN_000a2650 — actually loads the goal-chara texture
      @+0xe0; name misleading, documented). All byte-verified; no defect on review. Added
      TreasureData +getAllTreasureData: (@0xc09a4).
    * DONE: refreshMapScroll (FUN_000a3550 — reloads the 9 map-panel jacket textures via
      getTreasureMusicDataArray + the MapPanelOrder permutation DAT_0012faa0, NOT scroll)
      and unloadMapBgGroup (FUN_000a4e84 — unlink +0xd0 bg layer + unloadGroup(6); the
      earlier "applyMapScrollBounds(float)" seam name+arg were a mis-read of an adjacent
      scroll-rect float, corrected). Both are misnamed-seam corrections.
    * DONE: the +0x4f4 sub-object is the xorshift128 PRNG, now fully reconstructed as
      Project/Game/Util/Random.{h,cpp} (ctor FUN_00062b20, dtor FUN_00062b54, setSeed
      FUN_00062b5c, getRandRangeInt FUN_00062be0 == GetRandRangeInt in the original
      Random.cpp). The ctor placement-constructs it.
- StoreMainViewController::viewDidLoad (FUN_00042eec) — NEON-obscured CGRect geometry
  (checked: decompile confirms heavy extraout_sN spills throughout; no constant recovery
  without ARM Thumb-2 movt trace; remains open)
- MenuMainTask::setup tail — news-text / RewardNetwork / event-unlock scan

## Declared real-ref units still needing a body
- PlayTaskInit / PlayTaskGotoResult (FUN_0002e2d8 / FUN_0003003c) — DONE (PlayScene.mm).
  Delegated helpers still needing a body:
    * DONE (agent, reviewed): PlayBuildFieldLayers (the 5 effect + 11 bg AepLyrCtrl layers
      @+0x84..+0xc0 with device-tier anchors + the getLyrNo/getFrameNo/getUserNo handle
      tables) and PlayLoadCharaTextures (portraits @+0x30[8] normal / window+panels bundled;
      random unlocked-chara pick via RhTestBitInNumberArray). Build offsets match the
      PlayTaskGotoResult teardown; no defect on review. New decls: RhUtil RhTestBitInNumberArray
      (FUN_00028aa4), CharaManager CharaManagerShared (FUN_0002980c).
    * PlayTaskDraw (FUN_00030944) — large per-note draw dispatcher (delegated draw unit,
      like PlayJudge's note-quad geometry).
    * PlayResultTask (FUN_0003d5bc ctor + FUN_0003d690 update) — DONE: ctor, factory
      PlayResultCreateTask, update() touch preamble + 13-state dispatch with the
      lifecycle states reconstructed inline (0 intro, 1 fade-in, 4/7 waits, 8/9
      communicating, 10/0xb fade-out). Remaining handler bodies (declared, tracked):
      DONE (agent, reviewed): resultSetup (FUN_0003dfe0) + loadNumberTextures +
      resultGotoNext (FUN_0003f2e0) — full asset build/teardown, byte-verified (incl. the
      real v37-skip SE list and the 120 digit-texture names). Review fixed a duplicate
      neAppEventCenter::setLastMusic decl; AepLyrCtrl::init confirmed 5-arg (owner +
      order @0x12e698) via disassembly.
      DONE: updateResultPresent (case 2) — the intro-frame SE cascade (se07_count @+0x300
      on frames 0x18/0x28/0x30/0x38/0x40; v32 @+0x2e8 perfect jingle at 0x46, all traced by
      disasm), the capture gate, and the dismiss tap (tapX>0xdc || tapY<bottomEdge -> state
      3). DONE: buildShareButton (the case-2 UIButton build @ 0x3daf8..0x3df1e) —
      byte-verified the tweet-format CFString @ 0x135FF8 (UTF-16, "%@をプレイしたよ！
      スコア:%d ランク:%@ http://bit.ly/188OxQr #リズミン"; args = musicName, score@+0x344,
      rankLetter[+0x35c] from PTR_cf_S_00131884 {S,AAA,AA,A,B,C,D}); the device-branched
      frame (x=5.0; phone y=435.0 / 527.0@displayType2, Retina board halves the image +
      y+=15.0; pad y=965.0; w/h = bt_twitter image size); TwitterUtil(text,captured-image)
      wired as the @selector(tweet) target; and the two-stage bounce-in (0.2s scale->2.0,
      0.5s ->1.0, completion re-enables taps; options=UIViewAnimationOptionAllowUserInteraction
      =2). The innermost completion (FUN @ 0x3f2ac, unmarked-Thumb "bad data") was hand-
      decoded from raw halfwords to [button setUserInteractionEnabled:YES] — byte-verified:
      48-byte Thumb body (MOVW r1→SEL("setUserInteractionEnabled:"), MOVS r2,#1 (YES),
      LDR r0,[block+0x14]=self, LDR.W r0,[r0,#0x398]=m_shareButton, B tail-call to
      objc_msgSend stub @ 0x100708); SEL confirmed from __objc_methnames @ 0x00117f7b.
      Adjacent function at 0x3f2c4 (setAlpha:0.0f) is a separate block-invoke in the
      same "bad data" region, unrelated to this completion. TwitterUtil
      class fully reconstructed (Social.framework SLComposeViewController). DONE:
      updateScoreCount (cases 3/5/6 count-up) —
      all 4 SE source ids traced by disassembly (v38 @+0x2fc line-in, se08_bonus_fai
      @+0x304 tally, se07_count @+0x300 tick, se09_bonus_cl @+0x308 finish); and
      AepLyrCtrlUpdateAll + PlayResultDrawCallback (see the Draw units section).
      Original 13-state map (for the handler reconstructions):
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

## Known modeling reconciliations needed
- RESOLVED (agent, reviewed): the Aep render core is now a TRUE 1:1 reconstruction.
  AepDrawLayer (FUN_0000fe8c, the full frame-tree fill — 4 keyframe channels [pos+0x14/
  scale+0x18/color+0x1c/rot+0x20 double-indirect], rotation via aepSin/aepCos, blend
  composition, the alpha>=100->0x200 split, type 0 sprite / 2 recurse / 3 callback) and
  AepManager::drawLayer (FUN_0000fd64, full 19-arg form) replace the old lossy simplified
  versions; a 4-arg AepTransform compat overload keeps MenuMainTask/PlayTask/AepLyrCtrl
  callers working (color=100 opaque, priority->OT slot). AepFrameEntry now has the byte-
  exact 0x24 layout. This UNBLOCKS the four draw units: PlayTaskDraw (FUN_00030944),
  AcMainSugorokuDraw (FUN_000a3724), AepLyrCtrlUpdateAll (FUN_0002c924), PlayResultDrawCallback
  (FUN_0003f5f0) — each can now call the full drawLayer / group callback. aepSin/aepCos
  reproduce the DAT_0012ded2 trig LUT at the byte-verified 1.0==0xffff scale (data seam).

## Draw units (agent, partially reviewed — SYSTEMATIC DEFECT caught + corrected)
- AepLyrCtrlUpdateAll (FUN_0002c924) — DONE, fully verified: the per-frame layer list
  tick + draw + frame-advance state machine. The agent claimed the decompiler's drawLayer
  arg order was "ABI-scrambled" and remapped it; DISASSEMBLING the bl @0x2c9ce proved the
  agent WRONG (it shift-rotated loopFlags/p9/p10/color/colorHi and swapped context/p17).
  Corrected to the disasm-verified mapping.
- PlayTaskDraw (FUN_00030944) + PlayResultDrawCallback (FUN_0003f5f0) — DONE, now fully
  verified. The agent introduced the SAME systematic drawLayer arg-order defect in every
  drawLayer call; corrected to loopFlags=1, p9/p10=anchors, colour/alpha through,
  blend as-is, context=the callback p17 word, OT-priority p17=0. Both functions' entire
  child-id -> handle-table dispatch was then re-verified branch-by-branch against the
  decompiles (all offsets match: PlayTaskDraw combo/score/gauge/pause/tone/orb-eyes/frame
  layers; PlayResultDrawCallback FC-stamp/tally-strips/score/jacket/chara/difficulty/
  rank-effects/bonus-strips/treasure), and the corrected drawLayer args were confirmed
  exactly against FUN_0003f5f0's own drawLayer calls (loopFlags=1, p9=param_7, p10=param_8,
  colour=param_9, colourHi=param_10, blend=0x10/0x200, p17=0, context=param_14).
  New seams they added (real, cited): AepDrawSpriteHandle (FUN_0000fcd0, note-quad atlas
  draw), AepManager::groupSlotForHandle, PlayDrawCharaWindow (FUN_000313b0),
  MainViewController screenshot, and 5 NoteMng per-note tone-state accessors
  (FUN_00034bb4/b98/b5c/a5c/bd0) + NoteBeatIntervalMs (FUN_00034664) — the tone accessors
  index NoteMng's unmodeled +0x5248 per-note tone array (stride 0x3c), left as seams.

## Whole subsystems not started
- Task #7: settings sub-tables, map/sugoroku UI (SugorokuMainTask FUN_000215a0), tutorial task (FUN_0002db10)
- Task #6 friend VCs (data/networking layer done; the request/score VCs remain)
- Task #5 store detail VCs (StoreDetailViewController @0x72d1c) + the StoreMainVC table datasource
