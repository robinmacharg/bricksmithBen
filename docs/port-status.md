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
| P2 | 🧑 Golden review: row 2 (`golden/format/*`, `golden/roundtrip/1[0-4]*`) | **pending** | | Found BUG-005, BUG-006, S16; disproved suspected RGB truncation (768 values checked) |
| P2 | 🧑 Golden review: row 3 (`golden/robustness/cases.txt`) | **pending** | | Found BUG-007, BUG-008, S17, S18 |
| P1 | 🧑 First UI-test run (macOS permission prompts) | 2026-11-14 | agent (user-requested) | `scripts/test.sh --ui`: 1 UI test passed, defaults unchanged |

## Accepted risks and coverage exceptions

| Class | Tier | Coverage | Reason | Signed off |
|---|---|---|---|---|
| | | | | |

## Nullability annotations (plan §5 P1, v3.1 rule)

| Header | Annotated | Unverified (`null_unspecified`) | First test |
|---|---|---|---|
| `LDrawPaths.h` | 2026-11-14 | — | `HarnessFixtureLibraryTests` |
| `LDrawUtilities.h` | 2026-11-15 | All except `classForDirectiveBeginningWithLine:` (nullable, BUG-001) and `stringFromFileData:` (nullable) | `RoundTripTests`, `KnownIssueTests` |
| `LDrawDirective.h` | 2026-11-15 | All except `parentGroup:` (nullable: callers pass nil) | `RoundTripTests` |
| `LDrawFile.h` | 2026-11-15 | All except `parseFromFileContents:` (nullable). `+file` is pinned as `NS_SWIFT_NAME(file())` (L40) | `RoundTripTests`, `FormatTests` |
| `ColorLibrary.h` | 2026-11-14 | `LDrawColorable` `-LDrawColor` / `-setLDrawColor:` (protocol: implementations not yet reviewed) | `HarnessFixtureLibraryTests` |

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
| `Bricksmith/Source/Application/Document/LDrawDocument.m` | 6455 | MRC | P10 | todo |
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
| `Bricksmith/Source/Other/RegexKitLite.m` | 2636 | MRC | P4 (delete → NSRegularExpression) | todo |
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
