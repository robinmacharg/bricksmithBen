# Bricksmith architecture (as of 2026-11-14, pre-Swift-port)

Bricksmith is a macOS LEGO CAD application for editing [LDraw](https://www.ldraw.org) models
(`.ldr`, `.mpd`, `.dat`). It is roughly 69k lines of Objective-C and C. It was exported from
SourceForge CVS and now lives in git.

This document describes the code **as it is**. For where it is going, see
[swift-port-plan.md](swift-port-plan.md). Paths are relative to `trunk/Bricksmith/` unless they say otherwise.

## Repository layout

| Path | What it is |
|---|---|
| `trunk/Bricksmith/Bricksmith.xcodeproj` | The only app project. It has one native target, `Bricksmith`, and no test target. |
| `trunk/Bricksmith/Source/` | All app source (see below). |
| `trunk/Bricksmith/Resources/` | Xibs (`Interface/English.lproj`, 25 files, plus `en.lproj/SearchPanel.xib`), `LDConfig.ldr` (colours), `MLCad.ini` (minifig and LSynth lists), `Shaders/test.glsl`, and a few unofficial LSynth parts under `LDraw/Unofficial/parts`. |
| `trunk/AMSProgressBar/` | Small framework sub-project (progress sheet). It uses a legacy `.nib` bundle. |
| `trunk/ThirdParty/LSynth/` | About 5.7k lines of C. Builds the `lsynthcp` CLI, which is copied into the app bundle and run with `NSTask`. |
| `trunk/ThirdParty/Sparkle/` | Prebuilt Sparkle **2.0.0**. Uses the modern `SPUStandardUpdaterController` API. |
| `trunk/ThirdParty/3DconnexionClient.framework` | Old Carbon-era 3D-mouse SDK, weak-linked. |
| `trunk/Test Data/` | Regression fixtures. `Good/` and `Bad/` hold the same BrickLink Studio export; the Bad copy uses a non-standard line type `11` and crashes the app. |
| `trunk/Bricksmith/arc-migrate.sh`, `update_arc_flags.rb`, `Tools/ARCMigration/` | Tooling for the in-progress MRC → ARC migration. |

## Source layout and layers

```
Source/
  Other/          prefix header (.pch), MacLDraw.h (≈120 #define constants), RegexKitLite, main.m, MLCadIni
  Categories/     NSString, NSUserDefaults, NSView, NSWindow, NSTableView, NSBezierPath categories (the NSEvent category lives in `Widgets/LDrawGLView.h`)
  LDraw/
    Support/      LDrawDirective (root class), LDrawUtilities, ColorLibrary, PartLibrary, PartCatalogBuilder,
                  LDrawPaths, ModelManager, MatrixMath.c, GLMatrixMath.c, LDrawGLRenderer, LDrawGLCamera …
    Commands/     line-level directives: LDrawPart, LDrawLine, LDrawTriangle, LDrawQuadrilateral,
                  LDrawConditionalLine, LDrawMetaCommand, LDrawComment, LDrawColor, LDrawTexture, LDrawLSynth …
    Files/        containers: LDrawContainer, LDrawFile, LDrawModel, LDrawMPDModel, LDrawStep
    Renderer/     shader renderer, display lists, VBO streaming, MeshSmooth.c, LDrawRenderer.h protocols
  Application/
    Document/     LDrawDocument (6,455 lines), panels (Move, Rotation, Dimensions, PieceCount…)
    General/      app delegate (LDrawApplication), ToolPalette, Preferences, PartBrowser, Minifigure generator
    Inspector/    Inspector + one Inspection* controller and xib per directive type
  Widgets/        LDrawGLView (NSOpenGLView, 3,165 lines), outline view, colour well/bar, viewport arranger, cells
```

### Model: the directive tree

Each line of an LDraw file becomes an `LDrawDirective`. Line type codes are: 0 meta/comment,
1 part reference, 2 line, 3 triangle, 4 quad, 5 conditional line.

```
LDrawDirective (NSObject; NSCoding, NSCopying, LDrawObservable)
├─ LDrawContainer
│  ├─ LDrawFile                                     (holds one or more models)
│  ├─ LDrawModel ── LDrawMPDModel                   (MPD submodel; ── = "is subclassed by")
│  ├─ LDrawStep                                     (a model holds steps; a step holds directives)
│  ├─ LDrawTexture                                  (!TEXMAP block)
│  └─ LDrawLSynth                                   (LSynth hose/band block)
├─ LDrawMetaCommand ── LDrawComment, LDrawColor (!COLOUR), LDrawLSynthDirective
└─ LDrawDrawableElement
   ├─ LDrawPart (1)  ├─ LDrawLine (2) ── LDrawConditionalLine (5)
   ├─ LDrawTriangle (3)  ├─ LDrawQuadrilateral (4)  └─ LDrawDragHandle (UI-ish)
```

**Parsing.** `+[LDrawFile parseFromFileContents:]` → `-initWithLines:inRange:parentGroup:`
(recursive descent). Containers find their extent with `+rangeOfDirectiveBeginningAtIndex:`.
`+[LDrawUtilities classForDirectiveBeginningWithLine:]` chooses the class from the line code.
For an unknown code it returns `Nil`, which is the root of the `Test Data/Bad` crash.
The parsing code is written for GCD, but the prefix header sets `USE_BLOCKS 0` and
`#define dispatch_group_t void *`, so **parsing actually runs serially**.

**Serialising.** Every directive implements `-(NSString *)write`. Number and colour formatting
goes through `LDrawUtilities` (`outputStringForFloat:`, `outputStringForColor:`) and the global
column-alignment setting `setColumnizesOutput:`.

**Observation.** Directives use their own `LDrawObserver`/`LDrawObservable` protocols, not
KVO. Undo goes through `NSUndoManager prepareWithInvocationTarget:`, mostly in `LDrawDocument`.

### Global state the model depends on

These singletons matter for tests and for the port:

- `ColorLibrary sharedColorLibrary` is touched by **every coloured line parse**. It loads
  `LDConfig.ldr` from the path that `LDrawPaths` reports.
- `LDrawPaths sharedPaths` reads the LDraw folder from `NSUserDefaults` (key in `MacLDraw.h`).
- `PartLibrary sharedPartLibrary` resolves part references, creates **GL textures**, and builds part
  catalogs through `PartCatalogBuilder`.
- `ModelManager sharedModelManager` resolves cross-document submodel references.
- `MLCadIni iniFile` holds minifig and LSynth type lists.

### Rendering (OpenGL, still in place)

- `LDrawRenderer.h` declares the `LDrawRenderer` and `LDrawCollector` protocols. Directives
  implement `drawSelf:` and `collectSelf:`. **This is the seam a Metal renderer will plug into.**
- The seam leaks in four places:
  - The protocol uses `GLfloat *`.
  - The legacy `draw:viewScale:parentColor:` path in `LDrawPart`/`LDrawDirective` makes immediate-mode GL calls.
  - `LDrawPart` stores `GLfloat glTransformation[16]`.
  - `PartLibrary` uploads textures.
- `LDrawGLRenderer` (camera, picking, projection) and `LDrawGLView` (an `NSOpenGLView`) are
  GL-specific end to end.
- `MatrixMath.c` is the core geometry library (`Point3`, `Vector3`, `Matrix4`, `Box3`,
  `TransformComponents`…). Its only GL dependency is the `GLfloat` type.

### Application and UI

- `LDrawDocument` is the only `NSDocument`. It uses the default window controller and holds the model in
  `documentContents`. Info.plist declares ldr/dat/mpd by extension only, with **no UTIs**.
- UI is built from xibs. They contain deprecated pieces:
  - `NSMatrix`: 19 instances in 7 xibs.
  - `NSDrawer`: the part browser.
  - `NSCell` subclasses: `LDrawColorCell`, `IconTextCell`.
  - 221 Cocoa bindings, 195 of them in `MinifigureGenerator.xib`.
- Preferences: the keys are `#define`s in `Source/Other/MacLDraw.h`, and defaults are registered in
  `+[PreferencesDialogController ensureDefaults]`.

### Build facts

- Xcode 26.3 with Swift 6.2.4 (the built-in toolchain only). The scheme is `Bricksmith` and the configuration is Debug or Release.
- The deployment target is set to 10.11, but the macOS 26 SDK's minimum is 10.13.
- ARC is per-file and mid-migration. About 52 files use `-fobjc-arc` and about 41 use `-fno-objc-arc`.
  See [port-status.md](port-status.md).
- The prefix header imports Cocoa **and Carbon** into every file.
- Code signing is not configured (no team, no entitlements, no hardened runtime).
