# Auto-continue instructions

This file is read by the recurring session schedule (cron `486d177f`, every 45 min) to resume the
PopnRhythmin source reconstruction unattended. Follow it in order.

## Task
Reconstruct the source of **PopnRhythmin** (pop'n rhythmin) into `rhythmin-src/Project/` from the
Ghidra project **rb420**, program **PopnRhythmin**. Majority is Objective-C (some Objective-C++ where
C++ engine classes are called). Modern Obj-C, MRC memory model to match the binary. Do NOT re-implement
compiler/runtime artifacts (statically-linked CF* helpers, SjLj unwinding, `__cxa_guard`, stack-check).
No Xcode/compiler here — write best-effort code, verified against the decompiles, not compiled.

## How to resume
1. Read `HANDOFF.md` (running status board — the source of truth for what's done and what's next).
   It is gitignored; it lives on disk only.
2. Pick up the "REMAINING / next" items. Reconstruct **leaf-first**: build a method's whole
   dependency closure (cells, sub-overlays, helper classes) before the thing that uses it, so no
   dangling references or `extern`s for unimplemented symbols are introduced.
3. Verify every method against `decompile_function` / disassembly. Byte-decode strings (CFString:
   flags@4 0x7c8=ASCII / 0x7d0=UTF16, dataPtr@8, len@0xc). Flag NEON-spilled CGRect frames as
   best-effort in comments rather than inventing exact values.
4. After each completed, dangle-free unit: update `HANDOFF.md`, annotate the Ghidra program with a
   plate comment + `save_program`, and `git commit` (two-scope style: recon vs. build).
5. Do NOT create a second auto-continue schedule (one already exists). Do NOT modify tests / scoring /
   verifier / CI to manufacture success. Keep an honest trace of best-effort and deferred pieces.

## Known deferred (per user, do later)
- Friend **request** sub-screen (`FriendRequestViewController` + `FriendRequestTable` +
  `FreeRequestListViewController` + `FriendRequestCell`): hub `onRequestButtonTouched:` is a documented
  no-op stub; full method/ivar map is in `HANDOFF.md`.

## Big-picture remaining
Task #1 music-game core polish, task #4 in-game UI remainder, task #7 settings + map/sugoroku
(Sugoroku deprioritized). See `HANDOFF.md` for specifics.
