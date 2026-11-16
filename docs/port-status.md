# Port status ledger

This ledger tracks every compiled source file through the port. Update it in the same commit that changes a
file's status. Phase codes refer to [swift-port-plan.md](swift-port-plan.md) §5.

**Status values:**
- `todo`
- `tests` (characterisation tests exist and meet target)
- `ported` (Swift, `.m` deleted)
- `n/a` (stays C, or is deleted)
- `stays-objc (accepted)`: porting stalled. Record the reason and the sign-off, and remember that its ancestors are
  blocked too.

**Memory column:** the file's memory management at the 2026-11-14 snapshot (`ARC`, `MRC`, or `C`). For
`AMSProgressBar` the column is unreliable, because that is a separate project.

**MRC files** are all converted to ARC in **P3**, which comes after the characterisation tests, and before
their own port phase.

**Coverage:** once P1 lands, add a coverage column populated from `scripts/test.sh`. The tier targets are in plan
§5 P2: A ≥ 90%, B ≥ 80%.

## Gate sign-offs (🧑 human gates)

| Phase | Gate | Date | Initials | Notes |
|---|---|---|---|---|
| P0 | Automated: Debug and Release build, no new warnings, `codesign --verify --deep` | 2026-11-14 | agent | Branch `20261114-p0-build-hygiene` |
| P0 | 🧑 Manual smoke checklist (full LDraw library) | 2026-11-14 | maintainer | Passed, apart from Settings, which never opens: BUG-002 is pre-existing, caused by colour preferences written by the installed 3.1.0. Debug builds now use their own preferences domain |
| P1 | Automated: build (Debug/Release), unit tests, defaults unchanged ×3+, swap spike passed, exit-test spike passed, mutation pipeline verified | 2026-11-14 | agent | Branch `20261114-p1-test-harness` |
| P2 | 🧑 Golden review: `Fixtures/golden/roundtrip/*` (row 1) | 2026-11-15 | maintainer | Diffs vs inputs summarised in the P2 row-1 commit message; BUG-003/004 and S14/S15 found |
| P2 | 🧑 Golden review: row 2 (`golden/format/*`, `golden/roundtrip/1[0-4]*`) | 2026-11-15 | maintainer | Found BUG-005, BUG-006, S16; disproved suspected RGB truncation (768 values checked) |
| P2 | 🧑 Golden review: row 3 (`golden/robustness/cases.txt`) | 2026-11-15 | maintainer | Found BUG-007, BUG-008, S17, S18 |
| P2 | 🧑 Golden review: row 4 (`golden/model/**`; archives in `Fixtures/archives`) | 2026-11-15 | maintainer | Found BUG-011, BUG-012, S19 |
| P2 | 🧑 Golden review: row 6 (`golden/transforms/snapping.tsv`) | 2026-11-15 | maintainer | No bugs found; LDraw-aware vertical grid confirmed as documented design |
| P2 | 🧑 Golden review: row 8 (`golden/library/mlcad.txt`, `golden/library/catalog.json`) | 2026-11-15 | maintainer | S12/S13 confirmed; BUG-015 found and fixed (maintainer decision) |
| P2 | 🧑 Golden review: row 9 (`golden/mpd/*`) | 2026-11-15 | maintainer | S21, S22 noted; peer-file contract (lower-case names) characterised |
| P2 | 🧑 Golden review: row 10 (`golden/document/*`, 25 actions) | 2026-11-15 | maintainer | BUG-016 found; S23, S24 noted |
| P2 | 🧑 Golden review: row 11 (`golden/export/*`) | 2026-11-15 | maintainer | BUG-011 user-visible effect confirmed (Export Steps); S25 noted |
| P2 | 🧑 Golden review: row 12 (`golden/app/*`) | 2026-11-15 | maintainer | No new bugs |
| P2 | 🧑 Golden review: row 13 (`golden/lsynth/*`, plus the new `15-lsynth-band` round-trip/tree goldens) | 2026-11-15 | maintainer | S11 confirmed (CLI only) |
| P2 | 🧑 Golden review: row 14 (`golden/prefs/*`) | 2026-11-15 | maintainer | 175 constants + 93 registered defaults; note the misspelt key "Syntak Color Colors" must stay |
| P2 | 🧑 Golden review: row 15 (`golden/render/Mac15,7/*.png`, 8 images) | 2026-11-15 | maintainer | References for this machine only; other machines skip (not a CI gate) |
| P2 | Perf baseline recorded (Mac15,7; `docs/perf-baseline.json`) | 2026-11-15 | agent | Two verification runs within budget (max 116%) |
| P2 | UI smoke (row 17): `scripts/test.sh --ui`, 5 UI tests | 2026-11-15 | agent | No new goldens (reuses approved round-trip goldens). S26 noted. Test-mode focus-ring fix (L67) |
| P2 | 🧑 Manual-only list complete (TESTING.md; checklist steps 14-17 added) | 2026-11-15 | maintainer | Signed off in conversation |
| P2 | Coverage gate: `scripts/dev/coverage-tiers.py` exits 0 (22 tier A + 17 tier B classes at target; dead code in `docs/coverage-ledger.tsv`) | 2026-11-15 | agent | **Deviation for sign-off:** the ledger is per function (dead code), not per uncovered block; residual uncovered branches inside live methods are listed by `coverage-tiers.py --uncovered` but not individually justified |
| P2 | 🧑 Coverage ledger granularity: per-function ledger accepted; residual uncovered branches inside live methods accepted at class level (all classes at target) | 2026-11-15 | maintainer | Signed off in conversation |
| P3 | All app sources ARC (`CLANG_ENABLE_OBJC_ARC = YES`); only RegexKitLite.m stays MRC (P4) | 2026-11-15 | agent | 4 batches + target switch; `scripts/dev/arcmt-migrate.py`; L77-L79 |
| P3 | Build (Debug/Release) no new warnings; baselines re-recorded (5 missing-[super dealloc] warnings gone, BUG-032) | 2026-11-15 | agent | |
| P3 | Tests 185 passed (73 known), no golden changed; ASan run of the unit suite clean (185 passed) | 2026-11-15 | agent | `-enableAddressSanitizer YES`, separate derived data |
| P3 | Leaks smoke (`scripts/dev/leaks-smoke.sh`: 3 fixtures in the Debug app) | 2026-11-15 | agent | 11 leaks / 512 bytes, all one root: Sparkle `SPUStandardUpdaterController` (unreferenced MainMenu.xib top-level object; pre-existing) |
| P3 | 🧑 Perf: copy_20000_parts +25-35% accepted (ARC retain/release, plus freeing 20,000 directives now that BUG-032 is fixed); baseline re-recorded; draw metric now 20 frames per sample (`draw_20000_parts_x20`) | 2026-11-15 | maintainer | Verification run after re-baselining: all metrics 90-100% |
| P3 | UI smoke on the ARC build (`scripts/test.sh --ui-only`): 5/5 passed, twice | 2026-11-15 | agent | Outline-expansion race in the UI helper hardened (wait + one retry) |
| P3 | 🧑 Manual smoke checklist (TESTING.md steps 1-17) on the ARC Debug build | 2026-11-16 | maintainer | First run 2026-11-15: 1-3, 5, 6, 8, 9, 12, 13, 15, 17 OK. 4, 11, 16 (panels painted over) were BUG-033, present before P3, fixed in `d030b04`. 14 works as designed (test added; checklist wording fixed). 7 (earlier parts shift slightly when stepping) is by design: camera distance follows the bounds of the steps shown; no logic change vs master; checklist note added. Build-warning false alarm was a locale bug in build.sh (`1f4b6b1`). Re-check 2026-11-16: build clean, 4, 11, 14, 16 OK. Signed off |
| P3 | UI smoke after the BUG-033 fix (`scripts/test.sh --ui-only`): 5/5 passed; real and Debug defaults unchanged | 2026-11-16 | agent | |
| P3 | Merged to master as 4.0.3 (`015d40b`): Debug/Release no new warnings, 189 tests (73 known), UI 5/5 | 2026-11-16 | agent | |
| P4 | `USE_BLOCKS`, its dead branches and the dispatch typedef hack removed (`9774896`) | 2026-11-16 | agent | Branch `20261116-p4-objc-prep` |
| P4 | D: GL out of the model. Texture upload behind `-textureTagForTexture:` (`LDrawRenderer`/`LDrawCollector`), drag-handle sphere built lazily on the dead legacy path (`4201a47`, `94d5a94`) | 2026-11-16 | agent | Remaining GL in model files is on dead fixed-function paths (coverage ledger rows 16, 29, 33) plus the `glTransformation` ivar name. Perf 78-93% of baseline |
| P4 | C: Randomize Colors `randomSource`, `-exportStepsToURL:` (mirror deleted), `+registerValueTransformers` from `main.m` (`d55cc6e`, `c4f04bd`, `1c69ef5`) | 2026-11-16 | agent | 192 tests, 73 known |
| P4 | A: parse errors return BOOL/nil instead of throwing (`!COLOUR`, ROTSTEP-local, TEXMAP, line types 2-5, model header, RelatedParts); `+[LDrawDirective directiveWithLines:inRange:parentGroup:]` replaces LDrawMetaCommand's substitute-self init (`8ee3d0b`..`52dab3f`, 11 commits) | 2026-11-16 | agent | 194 tests, 73 known. **Open:** the malformed-final-ROTSTEP throw chain (`LDrawStep` → `LDrawPart`/`readFromData:` `@try`) is still exceptions; maintainer decision pending. No `NSError **` (no consumer reads error detail) |
| P4 | Dead fixed-function draw path deleted (maintainer decision; `8714370`) | 2026-11-16 | agent | `-draw:viewScale:parentColor:` kept only for LDConfig colour registration; 15 coverage-ledger rows removed |
| P4 | Malformed-ROTSTEP throw chain converted; BUG-007 fixed (maintainer decision) | 2026-11-16 | agent | Step/model/file return nil; `-[PartLibrary loadModelForName:inGroup:]` returns NO for an unparseable part; `+[LDrawFile parseFromFileContents:parseFailed:]`. Pinned first (`791a469`). 72 known issues. The catch-all `@try`s in `LDrawPart` and `readFromData:` stay: they also catch Foundation raises (L87); P6b/P10 must list every raising call before removing them |
| P2 | 🧑 Golden review: add the "ROTSTEP malformed angles" case to `golden/robustness/cases.txt` (now that it no longer crashes, it can leave `Robustness.crashing`; output would be `<parse returned nil>`) | **pending** | | Proposed after the BUG-007 fix; not done, because adding a case edits the golden |
| P4 | B: 17 `loadNibNamed:owner:` calls → `-loadNibNamed:owner:topLevelObjects:` with the array kept by the owner (S36 resolved); RegexKitLite out of LDrawLSynth and Preferences (`bb59fdd`..`b385871`) | 2026-11-16 | agent | 208 tests, 72 known; 17 deprecation warnings gone, baselines re-recorded (`9495086`). Leaked nib objects are now freed with their owner; manual checklist step 18 added. Perf: parse 102%, others 82-95% (agent's run) |
| P4 | Ivars → properties: all 27 `LDrawDocument` outlets and state (`@synthesize name = name`, ownership kept); `LDrawContainer.postsNotifications` readonly; `DocumentToolbarController.h`, `LDrawFileOutlineView.h` added to the bridging header (L91) | 2026-11-16 | agent | Outside readers found mechanically (L92). `documentContents` stays an ivar behind its accessors (a property would change the tests' `documentContents()` spelling). **P6 note:** `color`/`hidden` (`LDrawDrawableElement`) and `vertex1`/`vertex2` (`LDrawLine`) stay `@protected` ivars; Swift reads them through the existing getters, so the ported leaves' collect/draw/hit-test loops become message sends: perf-gate them. Agent's perf runs were on a loaded machine, inconclusive; P4 exit reruns on a quiet one |
| P4 | S37 confirmed through a real TEXMAP parse → **BUG-034** (hang; `3f5cb32`); exit-test pair plus an in-process control | 2026-11-16 | agent | 211 tests, **73** known issues (BUG-034 added, after BUG-007's removal) |
| P4 | `LDrawDocument.m` split into a core and 8 categories with `LDrawDocument+Private.h` (`39da1fd`..`9d4392a`, 10 commits) | 2026-11-16 | agent | Verbatim checker: 0 missing lines, 206 boilerplate; `nm` symbol list identical to before. Warnings re-recorded only for moved ones, plus one new declaration site of the existing `NSDrawer` deprecation (explicit ivar in the private header) |
| P4 | All P4 code items done (streams A-D, RegexKitLite deleted, ivars → properties, enum aliases, LDrawDocument split); regression from `c0785f7` fixed in `75ebcc6` after adversarial review | 2026-11-16 | agent | Next: P4 exit gate (UI suite, perf 3 runs, manual checklist incl. step 18); maintainer decisions pending: BUG-007 wider scope, attribution-trailer rewrite |
| P2 | Mutation smoke: 30/30 killed (`scripts/mutation-smoke.sh`, patches from `scripts/dev/make-mutations.py`) | 2026-11-15 | agent | Two survivors on the first run: one revealed a missing test (untyped ROTSTEP), one targeted dead code (retargeted) |
| P2 | Default suite time | 2026-11-15 | agent | 185 tests in ~31-60 s (limit 3 min) |
| P2 | 🧑 Golden review: re-recorded render references (`golden/render/Mac15,7/*`, harness now fixes 1x and 625x691, L73) | **pending** | | Same renders, offset a few pixels |
| P1 | 🧑 First UI-test run (macOS permission prompts) | 2026-11-14 | agent (user-requested) | `scripts/test.sh --ui`: 1 UI test passed, defaults unchanged |

## Accepted risks and coverage exceptions

The uncovered-line ledger is machine-readable: [coverage-ledger.tsv](coverage-ledger.tsv), checked by
`scripts/dev/coverage-tiers.py` (run after `scripts/test.sh`). A row names a function and the evidence that it needs
no test (dead code, debug only). A `*` row accepts a whole class below its tier target, and needs a maintainer
sign-off here:

| Class | Tier | Effective coverage | Reason | Signed off |
|---|---|---|---|---|

## Nullability annotations (plan §5 P1, v3.1 rule)

| Header | Annotated | Unverified (`null_unspecified`) | First test |
|---|---|---|---|
| `LDrawPaths.h` | 2026-11-14 | — | `HarnessFixtureLibraryTests` |
| `LDrawUtilities.h` | 2026-11-15 | All except `classForDirectiveBeginningWithLine:` (nullable, BUG-001) and `stringFromFileData:` (nullable) | `RoundTripTests`, `KnownIssueTests` |
| `LDrawDirective.h` | 2026-11-15 | All except `parentGroup:` (nullable: callers pass nil) | `RoundTripTests` |
| `LDrawFile.h` | 2026-11-15 | All except `parseFromFileContents:` (nullable). `+file` is pinned as `NS_SWIFT_NAME(file())` (L40) | `RoundTripTests`, `FormatTests` |
| `LDrawContainer.h` | 2026-11-15 | All (tool) | `ObjectModelTests` |
| `LDrawPart.h`, `LDrawDrawableElement.h` | 2026-11-15 | All (tool) | `SnappingTests` |
| `PartLibrary.h`, `PartCatalogBuilder.h`, `MLCadIni.h` | 2026-11-15 | All except `+sharedPartLibrary` (nonnull: allocated on first use) | `LibraryPathTests`, `LibraryCatalogTests` |
| `LDrawMPDModel.h`, `LDrawModel.h`, `ModelManager.h` | 2026-11-15 | All except `+sharedModelManager` (nonnull). `+model` is pinned with `NS_SWIFT_NAME(model())` | `MPDTests` |
| `LDrawDocument.h` | 2026-11-15 | All (tool) | `DocumentSpikeTests`, `DocumentActionTests` |
| `PartReport.h` | 2026-11-15 | All (tool) | `ExportTests` |
| `RelatedParts.h`, `LSynthConfiguration.h`, `PartBrowserDataSource.h`, `MinifigureDialogController.h` | 2026-11-15 | All (tool) | `AppLogicTests` |
| `ColorLibrary.h` | 2026-11-14 | `LDrawColorable` `-LDrawColor` / `-setLDrawColor:` (protocol: implementations not yet reviewed) | `HarnessFixtureLibraryTests` |
| `LDrawStep.h`, `LDrawLine.h`, `LDrawTriangle.h`, `LDrawQuadrilateral.h`, `LDrawConditionalLine.h`, `LDrawComment.h`, `LDrawMetaCommand.h`, `LDrawTexture.h`, `LDrawDragHandle.h`, `LDrawRenderer.h`, `LDrawMovableDirective.h` | 2026-11-15 | All (tool; `LDrawRenderer.h` `endDL:` and the cleanup typedef by hand) | `HitTestingTests`, `DrawingTests`, `PrimitiveEditingTests` (caught up late, L72) |
| `StringUtilities.h`, `BezierPathCategory.h`, `OverlayViewCategory.h`, `TableViewCategory.h`, `WindowCategory.h` | 2026-11-15 | All (tool; the last two have no pointers) | `TextureAndHelpersTests` |
| `LDrawLSynth.h`, `LDrawLSynthDirective.h` | 2026-11-15 | All (tool; `LDrawLSynth.h` caught up late, L72: `LSynthTests` tested it first) | `LSynthCoverageTests` |

## Uncovered-line ledger (tiers A and B)

| File:lines | Why it's uncovered (GL error path, dead code, can't-happen…) |
|---|---|
| | |

## Totals at the 2026-11-14 snapshot

| Phase | Files | LOC |
|---|---|---|
| P4 delete (RegexKitLite) | 1 | 2,636 |
| P5 utilities and categories | 10 | 1,459 |
| P6 model | 19 | 15,887 |
| P7 libraries and managers | 8 | 4,748 |
| P8 renderer (GL) | 6 | 6,023 |
| P9 UI (incl. AMSProgressBar) | 46 | 18,364 |
| P10 document and app | 4 | 7,754 |
| stays C (C → Swift is a follow-on goal) | 5 | 5,515 |

## Files

| File (relative to `trunk/`) | LOC | Memory | Phase | Status |
|---|---|---|---|---|
| `AMSProgressBar/AMSProgressPanel.m` | 373 | ARC | P9 (replace) | todo |
| `AMSProgressBar/main.c` | 3 | C | stays C | todo |
| `Bricksmith/Source/Application/Document/DimensionsPanel.m` | 326 | MRC | P9 | todo |
| `Bricksmith/Source/Application/Document/DocumentToolbarController.m` | 794 | MRC | P9 | todo |
| `Bricksmith/Source/Application/Document/LDrawDocument.m` | 875 | ARC | P10 | todo (P4 split: core only; categories below) |
| `Bricksmith/Source/Application/Document/LDrawDocument+FileIO.m` | 507 | ARC | P10 | todo |
| `Bricksmith/Source/Application/Document/LDrawDocument+Editing.m` | 1329 | ARC | P10 | todo |
| `Bricksmith/Source/Application/Document/LDrawDocument+ModelsMenu.m` | 664 | ARC | P10 | todo |
| `Bricksmith/Source/Application/Document/LDrawDocument+Undo.m` | 288 | ARC | P10 | todo |
| `Bricksmith/Source/Application/Document/LDrawDocument+Outline.m` | 480 | ARC | P10 | todo |
| `Bricksmith/Source/Application/Document/LDrawDocument+Viewers.m` | 777 | ARC | P10 | todo |
| `Bricksmith/Source/Application/Document/LDrawDocument+Menus.m` | 845 | ARC | P10 | todo |
| `Bricksmith/Source/Application/Document/LDrawDocument+Utilities.m` | 816 | ARC | P10 | todo |
| `Bricksmith/Source/Application/Document/MovePanel.m` | 97 | ARC | P9 | todo |
| `Bricksmith/Source/Application/Document/PieceCountPanel.m` | 452 | MRC | P9 | todo |
| `Bricksmith/Source/Application/Document/RotationPanelController.m` | 204 | MRC | P9 | todo |
| `Bricksmith/Source/Application/Document/SearchPanelController.m` | 578 | MRC | P9 | todo |
| `Bricksmith/Source/Application/General/BricksmithApplication.m` | 105 | ARC | P10 | todo |
| `Bricksmith/Source/Application/General/DonationDialogController.m` | 187 | ARC | P9 | todo |
| `Bricksmith/Source/Application/General/LDrawApplication.m` | 1179 | MRC | P10 | todo |
| `Bricksmith/Source/Application/General/LDrawColorPanelController.m` | 636 | ARC | P9 | todo |
| `Bricksmith/Source/Application/General/LSynthConfiguration.m` | 592 | ARC | P9 | todo |
| `Bricksmith/Source/Application/General/MinifigureDialogController.m` | 984 | MRC | P9 | todo |
| `Bricksmith/Source/Application/General/PartBrowserDataSource.m` | 1186 | MRC | P9 | todo |
| `Bricksmith/Source/Application/General/PartBrowserPanelController.m` | 161 | MRC | P9 | todo |
| `Bricksmith/Source/Application/General/PartLibraryController.m` | 187 | ARC | P9 | todo |
| `Bricksmith/Source/Application/General/PreferencesDialogController.m` | 1306 | MRC | P9 | todo |
| `Bricksmith/Source/Application/General/RelatedParts.m` | 551 | MRC | P9 | todo |
| `Bricksmith/Source/Application/General/ToolPalette.m` | 608 | ARC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/InspectionComment.m` | 96 | ARC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/InspectionConditionalLine.m` | 233 | MRC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/InspectionLSynth.m` | 385 | ARC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/InspectionLine.m` | 167 | MRC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/InspectionMPDModel.m` | 198 | ARC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/InspectionPart.m` | 405 | MRC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/InspectionQuadrilateral.m` | 264 | MRC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/InspectionStep.m` | 357 | ARC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/InspectionTriangle.m` | 227 | MRC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/InspectionUnknownCommand.m` | 96 | ARC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/Inspector.m` | 268 | MRC | P9 | todo |
| `Bricksmith/Source/Application/Inspector/ObjectInspectionController.m` | 261 | ARC | P9 | todo |
| `Bricksmith/Source/Categories/BezierPathCategory.m` | 77 | ARC | P5 | todo |
| `Bricksmith/Source/Categories/OverlayViewCategory.m` | 113 | ARC | P5 | todo |
| `Bricksmith/Source/Categories/StringCategory.m` | 163 | ARC | P5 | todo |
| `Bricksmith/Source/Categories/TableViewCategory.m` | 42 | ARC | P5 | todo |
| `Bricksmith/Source/Categories/UserDefaultsCategory.m` | 48 | ARC | P5 | todo |
| `Bricksmith/Source/Categories/WindowCategory.m` | 60 | ARC | P5 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawColor.m` | 1095 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawComment.m` | 123 | ARC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawConditionalLine.m` | 446 | ARC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawDrawableElement.m` | 511 | ARC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawLSynth.m` | 1487 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawLSynthDirective.m` | 84 | ARC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawLine.m` | 714 | ARC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawMetaCommand.m` | 374 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawPart.m` | 1790 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawQuadrilateral.m` | 1062 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawTexture.m` | 1178 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Commands/LDrawTriangle.m` | 873 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Files/LDrawContainer.m` | 530 | ARC | P6 | todo |
| `Bricksmith/Source/LDraw/Files/LDrawFile.m` | 879 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Files/LDrawMPDModel.m` | 537 | ARC | P6 | todo |
| `Bricksmith/Source/LDraw/Files/LDrawModel.m` | 1608 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Files/LDrawStep.m` | 1168 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Renderer/LDrawBDPAllocator.m` | 150 | ARC | P8 | todo |
| `Bricksmith/Source/LDraw/Renderer/LDrawDataStream.m` | 196 | (not compiled) | — | deleted in P0 (decision 7) |
| `Bricksmith/Source/LDraw/Renderer/LDrawDisplayList.m` | 1443 | ARC | P8 | todo |
| `Bricksmith/Source/LDraw/Renderer/LDrawShaderLoader.m` | 112 | ARC | P8 | todo |
| `Bricksmith/Source/LDraw/Renderer/LDrawShaderRenderer.m` | 713 | ARC | P8 | todo |
| `Bricksmith/Source/LDraw/Renderer/MeshSmooth.c` | 2120 | C | stays C | todo |
| `Bricksmith/Source/LDraw/Support/ColorLibrary.m` | 321 | ARC | P7 | todo |
| `Bricksmith/Source/LDraw/Support/ComputationalGeometry.m` | 360 | ARC | P7 | todo |
| `Bricksmith/Source/LDraw/Support/GLMatrixMath.c` | 639 | C | stays C | todo |
| `Bricksmith/Source/LDraw/Support/LDrawDirective.m` | 1020 | MRC | P6 | todo |
| `Bricksmith/Source/LDraw/Support/LDrawDragHandle.m` | 408 | ARC | P6 | todo |
| `Bricksmith/Source/LDraw/Support/LDrawGLCamera.m` | 1020 | ARC | P8 | todo |
| `Bricksmith/Source/LDraw/Support/LDrawGLRenderer.m` | 2585 | MRC | P8 | todo |
| `Bricksmith/Source/LDraw/Support/LDrawPaths.m` | 486 | ARC | P7 | todo |
| `Bricksmith/Source/LDraw/Support/LDrawUtilities.m` | 825 | ARC | P7 | todo |
| `Bricksmith/Source/LDraw/Support/MatrixMath.c` | 2725 | C | stays C | todo |
| `Bricksmith/Source/LDraw/Support/ModelManager.m` | 466 | MRC | P7 | todo |
| `Bricksmith/Source/LDraw/Support/OpenGLUtilities.c` | 28 | C | stays C | todo |
| `Bricksmith/Source/LDraw/Support/PartCatalogBuilder.m` | 553 | MRC | P7 | todo |
| `Bricksmith/Source/LDraw/Support/PartLibrary.m` | 1322 | MRC | P7 | todo |
| `Bricksmith/Source/LDraw/Support/PartReport.m` | 415 | MRC | P7 | todo |
| `Bricksmith/Source/Other/BricksmithUtilities.m` | 100 | ARC | P5 | todo |
| `Bricksmith/Source/Other/MLCadIni.m` | 666 | ARC | P5 | todo |
| `Bricksmith/Source/Other/RegexKitLite.m` | 2636 | MRC | P4 (delete → NSRegularExpression) | **deleted** (P4; users moved to NSRegularExpression in stream B, `libicucore` link removed) |
| `Bricksmith/Source/Other/StringUtilities.m` | 136 | ARC | P5 | todo |
| `Bricksmith/Source/Other/TransformerIntMinus1.m` | 54 | ARC | P5 | todo |
| `Bricksmith/Source/Other/main.m` | 15 | ARC | P10 | todo |
| `Bricksmith/Source/Widgets/BackgroundColorView.m` | 75 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/DialogPanel.m` | 112 | MRC | P9 | todo |
| `Bricksmith/Source/Widgets/ExtendedSplitView.m` | 260 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/ExtendedTableView.m` | 73 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/FocusRingView.m` | 134 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/IconTextCell.m` | 333 | MRC | P9 | todo |
| `Bricksmith/Source/Widgets/LDrawColorBar.m` | 111 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/LDrawColorCell.m` | 41 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/LDrawColorWell.m` | 265 | MRC | P9 | todo |
| `Bricksmith/Source/Widgets/LDrawDocumentWindow.m` | 81 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/LDrawFileOutlineView.m` | 59 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/LDrawGLView.m` | 3165 | MRC | P9 | todo |
| `Bricksmith/Source/Widgets/LDrawViewerContainer.m` | 210 | MRC | P9 | todo |
| `Bricksmith/Source/Widgets/OverlayHelperView.m` | 139 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/OverlayHelperWindow.m` | 291 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/PartBrowserTableView.m` | 86 | ARC | P9 | todo |
| `Bricksmith/Source/Widgets/ViewportArranger.m` | 750 | MRC | P9 | todo |
