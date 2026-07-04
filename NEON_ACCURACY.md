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
| 2 | AEP render dispatch + primitive path | AepOrderingTable.mm:77 (drawCommand) | **Fully diagnosed.** The binary `renderAepOrderingTable`(0x115d0) dispatches cmd.type 0-6 (sprite/stretch/line/tri/rect/quad/text) through the `drawAepOt*` set. The reconstruction's `flush->drawCommand` is a DELIBERATE simplification: it draws a textured quad for EVERY command regardless of type (already using GLfloat verts + glVertexPointer GL_FLOAT), so text renders as a textured quad and the untextured primitives don't render as solids. The whole `drawAepOt* -> neDraw*` set is dark code (zero callers) -- so the `neColorVertex` int-vs-GL_FLOAT issue is moot until that path is wired. Faithful fix = replace drawCommand with the type-0-6 dispatch AND reconcile the drawAepOt* signatures (binary's drawAepOtLine call passes 6 command fields; the reconstruction's sig expects 8) AND float the neColorVertex path. A dedicated core-render pass with real regression risk; NOT a clean isolated fix. | HIGH | ☐ (diagnosed; deferred as a dedicated render-path pass) |
| 3 | `menuButtonHit` (MenuMainTask_update) @0x6af58 | neEngineBridge.mm:596 | drops the `÷ g_dwUiScale` tap scale-divide before `pointInRect` → mode buttons mis-hit on Retina/iPad. menuButtonHit is MenuMainTask-only (contained). | MED | ☑ (scaled tap; g_dwUiScale, trunc) |

## Tier 2 — PARTIAL (dropped NEON / wrong constant, clear fix)

| # | Function @ addr | Source | Defect | Effort | Status |
|---|---|---|---|---|---|
| 4 | `drawAepSpriteClipped` @0x1211c | AepOrderingTable.mm:252 | rotation constant **sign flip**: binary `*(-π/180)` (DAT=-π); source `+M_PI/180`. | LOW | ☑ (0x12238=-π verified) |
| 5 | `PlayResultDrawCallback` @0x3f5f0 | PlayResultTask.mm:925 | RESULT_CHARA portrait **w/h swapped** — binary w=0x38c h=0x75e; source passes 0x75e,0x38c. | LOW | ☑ (swapped) |
| 6 | `PlayTaskDraw` @0x30944 | PlayScene.mm:927 | demo chara-window index `i==4` dead code -> `i==1`. Fix exposed latent undefined `PlayDrawCharaWindow` (FUN_000313b0, dead-stripped while unreachable); implemented it (beat-sync pulse table). | LOW | ☑ |
| 7 | `Downloader.currentProgress` @0x62912 | Downloader.m:120 | dropped `min(ratio,1.0f)` saturation clamp after the divide. | LOW | ☑ (clamp added) |
| 8 | `neDrawTexturedQuad` @0x16020 | neRenderer.cpp:407 | `rotation != 0` clip-plane rotation block (cos/sin SIMD) not reconstructed; always axis-aligned. | MED | ☑ (disasm-verified 0x1639c-0x1646a: a'=c·a-s·b, b'=s·a+c·b, d'=d+px(a-a')+py(b-b')) |
| 9 | `drawAepOtSprite` @0x10d86 | AepOrderingTable.mm:289 | dropped `/100` normalization of scaled transform args + tint 16-byte vector SIMD scale. **VERIFIED entangled:** the callee `drawAepSpriteClipped` currently `(void)sx;(void)sy;` (ignores scale) and discards `renderScale` — so a piecemeal `/100` would patch a value the callee throws away and could double-normalize once sprite-scale is reconstructed. Group with #10 as one **AepOrderingTable sprite-scale path** unit (drawAepOtSprite/Stretch → drawAepSpriteClipped → neDrawTexturedQuad w/h + sx/sy + tint), like #2. | MED-HIGH | ☐ (verified; deferred as a unit with #10) |
| 10 | `drawAepOtSpriteStretch` @0x10f2c | AepOrderingTable.mm:319 | same dropped ops as #9; part of the same sprite-scale-path unit. | MED-HIGH | ☐ (with #9) |
| 11 | `AcMainSugorokuDraw` @0xa3724 | AcMainTask.mm:2088 | digit strips (2 not 4/3), wall-grid scale 100 not 0x26, + 5 missing dispatch branches (9/13 grids, 17 chara button, 11/14 result popups w/ the 1.6949f zoom + reveal SE). | MED | ☑ (all 5 branches in; disasm-verified, byte-exact fields) |

## Tier 3 — PARTIAL (best-effort seams / large, HIGH effort)

| # | Function @ addr | Source | Defect | Effort | Status |
|---|---|---|---|---|---|
| 12 | `AcViewerTask::update` case 0xb/0xd @0x2174e | AcViewerTask.mm:611/634 | case 0xd pause-menu 3-button y-band hit-test DONE; case 0xb inverted iPad-resume condition fixed + tap resume/pause-rect tests wired. Residual seam: the case-0xb seek-scrub (drag accumulator + gauge quantize v*24/1023 + live acNoteMng seek) needs a per-frame drag accumulator the preamble doesn't maintain. | HIGH | ◐ (menu+taps done; seek-scrub deferred) |
| 13 | `AcMainTask::update` scroll-norm @0x9a716/0x9cbb2 | AcMainTask.mm:62 | m_dragAnchorX/Y retyped int->float + dropped the bogus /65536 (binary stores plain (float)touch, disasm 0x99e3e; fields are write-only so zero-risk). Residual: the consuming scroll-norm delta=((float)touch-anchor)/m_screenScale lives in the unreconstructed arcade states 0x10/0x4d of the 24KB update(). | HIGH | ◐ (anchor float fixed; consuming states deferred) |
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
