# STUBS — systematic inventory of incomplete reconstructions
# (void)local markers: 0. All extern seams: removed. All Japanese strings: byte-verified.

## Explicitly-deferred large units (documented in-file, not disguised)
- AcMainTask::update (FUN_00099d18) — 24KB arcade state machine, the binary's largest function
- StoreMainViewController::viewDidLoad (FUN_00042eec) — NEON-obscured CGRect geometry
- MenuMainTask::setup tail — news-text / RewardNetwork / event-unlock scan

## Declared real-ref units still needing a body
- PlayTaskInit / PlayTaskGotoResult (FUN_0002e2d8 / FUN_0003003c) — IN PROGRESS (agent)

## Whole subsystems not started
- Task #7: settings sub-tables, map/sugoroku UI (SugorokuMainTask FUN_000215a0), tutorial task (FUN_0002db10)
- Task #6 friend VCs (data/networking layer done; the request/score VCs remain)
- Task #5 store detail VCs (StoreDetailViewController @0x72d1c) + the StoreMainVC table datasource
