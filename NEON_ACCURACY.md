# NEON accuracy sweep — cited functions with SIMD/fixed-point the decompiler garbled

Ground truth = DISASSEMBLY. The Ghidra decompiler drops information on NEON: coordinate
scale-divides (`vdiv.f32`), fixed-point conversions (`vcvt` → `FixedToFP`/`FPToFixed` with
scale/round args dropped), 2-lane SIMD (`vadd/vmul/vsub` on `d`-registers → `FloatVector*`,
`extraout_s/d`, `unaff_d`), and float constants (recover from `vmov.f32 #imm` / `vldr [pc,#…]`
literal pools). This sweep classified every cited function that contains such NEON.

Status: ☐ todo  ◐ in progress  ☑ fixed & verified  ✓ already accurate (no change)

## Tier 1 — GARBLED (real functional defects)

| # | Function @ addr | Source | Defect | Effort | Status |
|---|---|---|---|---|---|
| 1 | `neFrameTimer::elapsedSeconds` @0x280bc | neFrameTimer.h:30 | binary returns **milliseconds** (`sec*1000 + usec/1000`); source returned seconds (`/1000000`) — 1000× off. | LOW | ☑ (→elapsedMs; chain verified: draw threshold DAT_0000be7c=1000.0 & updateAll FPToFixed both already ms) |
| 2 | `neDrawRect` @0x152f0 (+ neColorVertex path) | neRenderer.cpp:165/213 | **NOT dead code (corrected).** Ghidra call graph: `renderAepOrderingTable`(0x115d0) -> `drawAepOt{Line,Rect,Triangle,Quad}` -> `neDraw*`, so the AEP OT renders rect/line/tri/quad command types. TWO issues: (a) the reconstruction's `AepOrderingTable::flush`/`drawCommand` does NOT dispatch those primitive command types (drawAepOt* have zero source callers) — a missing render path; (b) positions are IEEE float (`vadd.f32` on x+w/y+h), but `neColorVertex{int32 x,y}` + `aepScale`->int + `neDraw*` int params are int-modeled while glVertexPointer is GL_FLOAT. One dedicated unit: wire the primitive command dispatch AND convert the vertex path to float. | HIGH | ☐ (verified live; deferred as a unit) |
| 3 | `menuButtonHit` (MenuMainTask_update) @0x6af58 | neEngineBridge.mm:596 | drops the `÷ g_dwUiScale` tap scale-divide before `pointInRect` → mode buttons mis-hit on Retina/iPad. menuButtonHit is MenuMainTask-only (contained). | MED | ☑ (scaled tap; g_dwUiScale, trunc) |

## Tier 2 — PARTIAL (dropped NEON / wrong constant, clear fix)

| # | Function @ addr | Source | Defect | Effort | Status |
|---|---|---|---|---|---|
| 4 | `drawAepSpriteClipped` @0x1211c | AepOrderingTable.mm:252 | rotation constant **sign flip**: binary `*(-π/180)` (DAT=-π); source `+M_PI/180`. | LOW | ☑ (0x12238=-π verified) |
| 5 | `PlayResultDrawCallback` @0x3f5f0 | PlayResultTask.mm:925 | RESULT_CHARA portrait **w/h swapped** — binary w=0x38c h=0x75e; source passes 0x75e,0x38c. | LOW | ☑ (swapped) |
| 6 | `PlayTaskDraw` @0x30944 | PlayScene.mm:927 | demo chara-window index `i==4` dead code -> `i==1`. Fix exposed latent undefined `PlayDrawCharaWindow` (FUN_000313b0, dead-stripped while unreachable); implemented it (beat-sync pulse table). | LOW | ☑ |
| 7 | `Downloader.currentProgress` @0x62912 | Downloader.m:120 | dropped `min(ratio,1.0f)` saturation clamp after the divide. | LOW | ☑ (clamp added) |
| 8 | `neDrawTexturedQuad` @0x16020 | neRenderer.cpp:407 | `rotation != 0` clip-plane rotation block (cos/sin SIMD) not reconstructed; always axis-aligned. | MED | ☐ |
| 9 | `drawAepOtSprite` @0x10d86 | AepOrderingTable.mm:289 | dropped `/100` normalization of scaled transform args + tint 16-byte vector SIMD scale. **VERIFIED entangled:** the callee `drawAepSpriteClipped` currently `(void)sx;(void)sy;` (ignores scale) and discards `renderScale` — so a piecemeal `/100` would patch a value the callee throws away and could double-normalize once sprite-scale is reconstructed. Group with #10 as one **AepOrderingTable sprite-scale path** unit (drawAepOtSprite/Stretch → drawAepSpriteClipped → neDrawTexturedQuad w/h + sx/sy + tint), like #2. | MED-HIGH | ☐ (verified; deferred as a unit with #10) |
| 10 | `drawAepOtSpriteStretch` @0x10f2c | AepOrderingTable.mm:319 | same dropped ops as #9; part of the same sprite-scale-path unit. | MED-HIGH | ☐ (with #9) |
| 11 | `AcMainSugorokuDraw` @0xa3724 | AcMainTask.mm:2088 | NEON `FloatVectorMult` scale branch + 4 dispatch branches unreconstructed; wall-grid scale 0x26→should be 100; two digit-strip count/offset garbles. | MED | ☐ |

## Tier 3 — PARTIAL (best-effort seams / large, HIGH effort)

| # | Function @ addr | Source | Defect | Effort | Status |
|---|---|---|---|---|---|
| 12 | `AcViewerTask::update` case 0xb/0xd @0x2174e | AcViewerTask.mm:611/634 | case 0xb seek-scrub SIMD + 2 pointInRect tests missing; case 0xd 3 inline Y-band pause-menu buttons + nav/SE/state routing missing; preamble drag-accumulator missing. (tap classifier + case 6 already fixed) | HIGH | ☐ |
| 13 | `AcMainTask::update` scroll-norm @0x9a716/0x9cbb2 | AcMainTask.mm:62 | inlined per-frame scroll-normalization `vsub/vdiv` not reproduced 1:1 (de-inlined/approx across helpers). | HIGH | ☐ |
| 14 | `MainTask::update` @0x35b02 | MainTask.mm:222 | WidgetRect slot / hit-Y packed-word best-effort (rect scaling itself correct). | MED | ☐ |
| 15 | `MainTask::updateList` @0x3508a | MainTask.mm:884 | sqrt-damped rubber-band 16.16 Q-format modeled as identity (magnitude/sign approximate). | MED | ☐ |
| 16 | `charaSelectTaskInit`/setupScene @0x9fdbe | AcMainTask.mm:294 | char-panel row-count fixed-point round `(/6.0 + 0.5)` approximate, not proven byte-identical. | MED | ☐ |
| 17 | `initAtNavigationControllerWithMusicId:` @0xaaa6e | FriendScoreMainView.mm:125 | iPad tab-header right-align origins (2-lane FloatVectorSub) approx; `/3.0` uses table width vs outer view; dropped anim option 0x18→Repeat-only. | LOW | ☐ |

## Verified ACCURATE (no change needed)

matrixSetOrtho, neDrawLine, neDrawTriangle, neDrawQuad, neDrawText (nit: odd-advance >>1 vs *0.5),
AepDrawLayer, MusicSelAepDraw, computeFinalScore, NoteMng::makeNote, NoteBeatIntervalMs,
NoteMng::advanceRegisterEvent, PlayJudge_update (timing/score path exact; visual math delegated),
noteMngTogglePause (nit: signed/double vs unsigned/single, in-range identical), acNoteResume,
registerScrollSegment (acNoteInsertTempoEvent), PlayTaskInit, resizePopkun, MainViewController capture:,
scrollViewDidScroll: (HowToViewCtrlPad), tableView:heightForRowAtIndexPath: (StoreMainVC),
overallProgress (StoreDownloadManager), AepLyrCtrlUpdateAll, downloaderFinished:, downloaderProceed:,
endOpenAnimation, audioPlaySource, setSeVolume:groupId:.

## Fix order
1. Tier-1 #1 (timing 1000× — verify consumers first) + Tier-2 LOW clear-wins (#4,#5,#6,#7).
2. Tier-1 #2,#3 + Tier-2 MED (#8,#9,#10,#11).
3. Tier-3 HIGH (#12,#13) — each its own disasm-recovery pass (like AcViewerTask case 6).
Each fix: verify defect against Ghidra myself, edit, syntax-gate, commit, keep CI green.
