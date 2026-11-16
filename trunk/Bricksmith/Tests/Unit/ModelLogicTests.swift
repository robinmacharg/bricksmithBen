//
//  ModelLogicTests.swift
//  BricksmithTests
//
//  P2 exit (coverage): model, colour and utility logic that the earlier rows reached only partly.
//    - outline text, icons and inspector classes for every directive type (what the file-contents outline shows)
//    - ROTSTEP: the view angle each step gets (-[LDrawModel rotationAngleForStepAtIndex:], used when stepping)
//    - step display limits, step setters, drop rules (outline drag and drop), submodel references
//    - "~Moved to" parts (the document offers to update them on open), un-resolving library parts
//    - part nudge directions for rotated parts, colour-field parsing, quoted tokens, view angles, images
//    - !COLOUR definitions: every option written back
//  Goldens: golden/model-logic/*.
//

import AppKit
import Foundation
import Testing
@testable import Bricksmith

enum ModelLogic {
	/// An MPD with every directive type (LSynth is covered by LSynthCoverageTests).
	static let composite = """
		0 FILE main.ldr
		0 Main model
		0 Name: main.ldr
		0 Author: Fixture Author
		0 !COLOUR Test_Colour CODE 500 VALUE #112233 EDGE #445566 ALPHA 128 LUMINANCE 10 CHROME
		0 // a comment
		0 UNKNOWN META
		1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
		1 16 0 -24 0 1 0 0 0 1 0 0 0 1 sub.ldr
		2 24 0 0 0 10 0 0
		3 16 0 0 0 10 0 0 0 10 0
		4 16 0 0 0 10 0 0 10 10 0 0 10 0
		5 24 0 0 0 10 0 0 0 5 0 0 -5 0
		0 STEP
		1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3005.dat
		0 ROTSTEP 0 45 0 ABS
		1 2 0 -72 0 1 0 0 0 1 0 0 0 1 3005.dat
		0 ROTSTEP 30 0 0 REL
		1 14 0 -96 0 1 0 0 0 1 0 0 0 1 3005.dat
		0 ROTSTEP 0 0 15 ADD
		0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 sticker.png
		3 16 -10 0 -10 10 0 -10 10 0 10
		0 !TEXMAP END
		0 ROTSTEP END
		0 NOFILE
		0 FILE sub.ldr
		0 Submodel
		0 Name: sub.ldr
		0 Author: Fixture Author
		1 15 0 0 0 1 0 0 0 1 0 0 0 1 3005.dat
		1 15 0 -24 0 1 0 0 0 1 0 0 0 1 subsub.ldr
		0 NOFILE
		0 FILE subsub.ldr
		0 Sub-submodel
		0 Name: subsub.ldr
		0 Author: Fixture Author
		1 14 0 0 0 1 0 0 0 1 0 0 0 1 3024.dat
		0 NOFILE
		"""

	static func load(_ text: String) throws -> LDrawFile {
		try #require(RoundTrip.load(Data(text.replacingOccurrences(of: "\t", with: "").utf8)))
	}

	static func fixture(_ name: String) throws -> LDrawFile {
		try #require(RoundTrip.load(try Data(contentsOf: FixturePaths.fixtures.appendingPathComponent("ldr/\(name)"))))
	}

	static func f(_ v: Float) -> String { String(format: "%.3f", v == 0 ? 0 : v) }
	static func t(_ v: Tuple3) -> String { "(\(f(v.x)), \(f(v.y)), \(f(v.z)))" }
	static func lines(_ s: [String]) -> Data { Data((s.joined(separator: "\n") + "\n").utf8) }
	static func oneLine(_ s: String) -> String { s.replacingOccurrences(of: "\r\n", with: " / ") }
}

@Suite("Model logic: outline, ROTSTEP, steps, drops, references, moved parts, utilities (P2 exit)",
	   .fixtureLibrary, .serialized)
struct ModelLogicTests {

	@Test("Outline text, icon and inspector class for every directive type")
	func outline() throws {
		let file = try ModelLogic.load(ModelLogic.composite)
		var extra: [LDrawDirective] = [LDrawDirective(), LDrawModel.model() as! LDrawDirective, LDrawColor()]
		for flavor: LDrawStepFlavorT in [.anyDirectives, .lines, .triangles, .quadrilaterals, .conditionalLines] {
			extra.append(LDrawStep.empty(withFlavor: flavor) as! LDrawDirective)
		}
		for rotation: LDrawStepRotationT in [.none, .relative, .absolute, .additive, .end] {
			let step = LDrawStep.empty() as! LDrawStep
			step.setStepRotationType(rotation)
			extra.append(step)
		}
		var out: [String] = []
		try ObjC.run {
			for d in ObjectModel.all(file) + extra {
				out.append("\(type(of: d)) | \(d.browsingDescription() ?? "nil") | \(d.iconName() ?? "nil") | \(d.inspectorClassName() ?? "nil")")
			}
		}
		try Golden.check(ModelLogic.lines(out), against: "model-logic/outline.txt")
	}

	@Test("ROTSTEP: the viewing angle for each step")
	func rotstepAngles() throws {
		var out: [String] = []
		for (name, file) in [("04-steps-rotstep.ldr", try ModelLogic.fixture("04-steps-rotstep.ldr")),
							 ("composite main.ldr", try ModelLogic.load(ModelLogic.composite))] {
			let model = try #require(file.activeModel())
			for i in 0..<model.steps().count {
				let step = model.steps()[i] as! LDrawStep
				var angle = Tuple3()
				try ObjC.run { angle = model.rotationAngleForStep(at: UInt(i)) }
				out.append("\(name) step \(i) (type \(step.stepRotationType().rawValue), angle \(ModelLogic.t(step.rotationAngle()))): view \(ModelLogic.t(angle))")
			}
		}
		try Golden.check(ModelLogic.lines(out), against: "model-logic/rotstep-angles.txt")
	}

	@Test("Step setters and the ROTSTEP line each writes")
	func stepSetters() throws {
		var out: [String] = []
		for rotation: LDrawStepRotationT in [.none, .relative, .absolute, .additive, .end] {
			let step = LDrawStep.empty() as! LDrawStep
			step.setStepRotationType(rotation)
			step.setRotationAngle(V3Make(10, 20, 30))
			out.append("type \(rotation.rawValue) angle (10,20,30): \(ModelLogic.oneLine(step.write())) | ZYX \(ModelLogic.t(step.rotationAngleZYX()))")
			step.setRotationAngleZYX(V3Make(30, 20, 10))
			out.append("  after setRotationAngleZYX (30,20,10): angle \(ModelLogic.t(step.rotationAngle())) | \(ModelLogic.oneLine(step.write()))")
		}
		// A ROTSTEP with no type keyword is relative (LDrawStep parseRotationStepFromLine:).
		let untyped = try #require(ModelLogic.load("0 Untyped\n0 Name: u.ldr\n0 Author: Fixture Author\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 ROTSTEP 10 20 30\n").activeModel())
		let first = untyped.steps()[0] as! LDrawStep
		out.append("untyped ROTSTEP 10 20 30: type \(first.stepRotationType().rawValue) | \(ModelLogic.oneLine(first.write()))")
		let step = LDrawStep.empty() as! LDrawStep
		for flavor: LDrawStepFlavorT in [.lines, .triangles, .quadrilaterals, .conditionalLines, .anyDirectives] {
			step.setStepFlavor(flavor)
			out.append("flavor set \(flavor.rawValue) -> \(step.stepFlavor().rawValue)")
		}
		// A step-display limit: only steps up to the limit are drawn/written for display.
		let model = try #require(try ModelLogic.fixture("04-steps-rotstep.ldr").activeModel())
		model.setStepDisplay(true)
		for limit in [0, 2, 5, 99] {
			do { try ObjC.run { model.setMaximumStepIndexForStepDisplay(UInt(limit)) } }
			catch { out.append("step display limit \(limit): raises \(error)"); continue }
			out.append("step display limit \(limit): maxStepIndexToOutput \(model.maxStepIndexToOutput()), visibleStep \(model.visibleStep().flatMap { v in model.steps().firstIndex { ($0 as AnyObject) === v } }.map(String.init) ?? "nil")")
		}
		model.setStepDisplay(false)
		out.append("step display off: maxStepIndexToOutput \(model.maxStepIndexToOutput())")
		try Golden.check(ModelLogic.lines(out), against: "model-logic/steps.txt")
	}

	@Test("Which containers accept which dropped directives (outline drag and drop)")
	func dropRules() throws {
		let containers: [(String, () -> LDrawContainer)] = [
			("file", { LDrawFile.file() }), ("mpd model", { LDrawMPDModel.model() as! LDrawMPDModel }),
			("model", { LDrawModel.model() as! LDrawModel }), ("step", { LDrawStep.empty() as! LDrawContainer }),
			("lines step", { LDrawStep.empty(withFlavor: .lines) as! LDrawContainer }),
		]
		let dropped: [(String, () -> LDrawDirective)] = [
			("step", { LDrawStep.empty() as! LDrawDirective }), ("part", { LDrawPart() }), ("line", { LDrawLine() }),
			("mpd model", { LDrawMPDModel.model() as! LDrawMPDModel }), ("model", { LDrawModel.model() as! LDrawModel }),
			("comment", { LDrawComment() }), ("file", { LDrawFile.file() }),
		]
		var out = ["container \\ dropped: " + dropped.map(\.0).joined(separator: ", ")]
		for (name, make) in containers {
			var row: [String] = []
			try ObjC.run { row = dropped.map { make().acceptsDroppedDirective($0.1()) ? "yes" : "no" } }
			out.append("\(name): " + row.joined(separator: ", "))
		}
		// The rules that matter: no LSynth directives, and no part that references its own enclosing model.
		// (Bare containers and a bare part above compare two empty names, hence "model: part no".)
		let file = try ModelLogic.load(ModelLogic.composite)
		let main = try #require(file.activeModel())
		let step = try #require(main.steps().first as? LDrawStep)
		for (target, name) in [(main as LDrawContainer, "main.ldr model"), (step, "main.ldr step 1")] {
			for (what, d) in [("part -> main.ldr (itself)", try PartFactory.part("1 4 0 0 0 1 0 0 0 1 0 0 0 1 main.ldr") as LDrawDirective),
							  ("part -> sub.ldr", try PartFactory.part("1 4 0 0 0 1 0 0 0 1 0 0 0 1 sub.ldr")),
							  ("LSynth directive", LDrawLSynthDirective())] {
				var ok = false
				try ObjC.run { ok = target.acceptsDroppedDirective(d) }
				out.append("\(name) accepts \(what): \(ok ? "yes" : "no")")
			}
		}
		try Golden.check(ModelLogic.lines(out), against: "model-logic/drops.txt")
	}

	@Test("Submodel references: containsReferenceTo and the referenced peer file")
	func references() throws {
		let file = try ModelLogic.load(ModelLogic.composite)
		let models = file.submodels() as! [LDrawMPDModel]
		var out: [String] = []
		try ObjC.run {
			for m in models {
				for name in ["main.ldr", "sub.ldr", "subsub.ldr", "SUB.LDR", "3005.dat", "missing.ldr"] {
					out.append("\(m.modelName()!) contains \(name): \(m.containsReference(to: name))")
				}
			}
			out.append("file contains subsub.ldr: \(file.containsReference(to: "subsub.ldr"))")
			for case let part as LDrawPart in ObjectModel.all(file) {
				out.append("part \(part.referenceName()!): peer file \((part.referencedPeerFile() as? LDrawMPDModel)?.modelName() ?? "nil"), contains 'sub.ldr' \(part.containsReference(to: "sub.ldr"))")
			}
		}
		try Golden.check(ModelLogic.lines(out), against: "model-logic/references.txt")
	}

	@Test("A part whose library file says '~Moved to' is renamed to the new part")
	func movedPart() async throws {
		// A moved part, written into the test's temporary copy of the fixture library (never the fixture itself).
		let library = try #require(FixtureLibrary.current)
		let moved = """
			0 ~Moved to 3005
			0 Name: 9999.dat
			0 Author: Fixture Author
			0 !LDRAW_ORG Part UPDATE 2004-01
			1 16 0 0 0 1 0 0 0 1 0 0 0 1 3005.dat
			""".replacingOccurrences(of: "\t", with: "")
		try moved.write(to: library.appendingPathComponent("parts/9999.dat"), atomically: true, encoding: .utf8)
		let catalog = try #require(await LibraryCatalogTests.buildCatalog())
		PartLibrary.shared().setPartCatalog(catalog)

		let file = try ModelLogic.load("0 Moved\n0 Name: moved.ldr\n0 Author: Fixture Author\n1 4 10 20 30 0 0 1 0 1 0 -1 0 0 9999.dat\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
		let parts = ObjectModel.all(file).compactMap { $0 as? LDrawPart }
		var out: [String] = []
		try ObjC.run {
			for part in parts {
				let before = part.write()!
				LDrawUtilities.updateName(forMovedPart: part)
				out.append("\(before) -> \(part.write()!)")
			}
		}
		try Golden.check(ModelLogic.lines(out), against: "model-logic/moved-part.txt")
	}

	@MainActor
	@Test("Un-resolving library parts (after a library reload) leaves the model drawing the same")
	func unresolve() throws {
		let file = try ModelLogic.load(ModelLogic.composite)
		let before = try DrawHarness.record(file, passes: 1)
		try ObjC.run { LDrawUtilities.unresolveLibraryParts(file) }
		let after = try DrawHarness.record(file, passes: 1)
		try Golden.check(Data(("# before\n" + before + "# after unresolveLibraryParts\n" + after).utf8), against: "model-logic/unresolve.txt")
		#expect(RoundTrip.save(file) == RoundTrip.save(try ModelLogic.load(ModelLogic.composite)))
	}

	@Test("Nudge direction for rotated parts (the part's own axes)")
	func nudgeRotatedParts() throws {
		let rotations = ["1 0 0 0 1 0 0 0 1", "0 0 1 0 1 0 -1 0 0", "1 0 0 0 0 -1 0 1 0", "0.7071 0 0.7071 0 1 0 -0.7071 0 0.7071",
						 "0 -1 0 1 0 0 0 0 1", "-1 0 0 0 -1 0 0 0 1"]
		var out: [String] = []
		for r in rotations {
			let part = try PartFactory.part("1 4 0 0 0 \(r) 3001.dat")
			// Nudges of exactly 10 or 20 LDU along the brick's own up axis are rescaled (bricks are taller than wide).
			for size: Float in [1, 10, 20] {
				let n = [V3Make(size, 0, 0), V3Make(0, size, 0), V3Make(0, 0, size), V3Make(0, -size, 0)].map { ModelLogic.t(part.displacement(forNudge: $0)) }
				out.append("[\(r)] size \(Int(size)): x \(n[0]) y \(n[1]) z \(n[2]) -y \(n[3])")
			}
		}
		try Golden.check(ModelLogic.lines(out), against: "model-logic/nudge.txt")
	}

	@Test("Drawable element defaults, and drag snapping for primitives (renderer drag uses position:snappedToGrid:)")
	func drawableDefaults() throws {
		var out: [String] = []
		let bare = LDrawDrawableElement()
		let box = bare.boundingBox3()
		bare.move(by: V3Make(1, 2, 3))
		out.append("bare element: position \(ModelLogic.t(bare.position())), box min \(ModelLogic.t(box.min)) max \(ModelLogic.t(box.max))")
		for text in ["2 24 0 0 0 10 0 0", "3 16 0 0 0 10 0 0 0 10 0"] {
			let prim = try Prim.parse(text) as! LDrawDrawableElement
			for grid: Float in [1, 10, 20] {
				let snapped = prim.position(V3Make(13.7, -6.2, 25.1), snappedToGrid: grid)
				out.append("\(text) grid \(Int(grid)): (13.7, -6.2, 25.1) -> \(ModelLogic.t(snapped))")
			}
		}
		try Golden.check(ModelLogic.lines(out), against: "model-logic/drawable.txt")
	}

	@Test("Utilities: colour fields, quoted tokens, view angles")
	func utilities() throws {
		var out: [String] = ["# parseColorFromField"]
		for field in ["4", "16", "24", "0x2FF0000", "0x2ff00aa", "0x3123456", "0x4F00F00", "#FF0000", "abc", "", "-1", "999999", "500"] {
			var line = ""
			do { try ObjC.run {
				if let c = LDrawUtilities.parseColor(fromField: field) {
					var rgba: [Float] = [0, 0, 0, 0]
					c.getRGBA(&rgba)
					line = "\"\(field)\": code \(c.colorCode().rawValue) rgba \(rgba.map { ModelLogic.f($0) }.joined(separator: " "))"
				} else { line = "\"\(field)\": nil" }
			} } catch { line = "\"\(field)\": raises \(error)" }
			out.append(line)
		}
		out.append("# scanQuotableToken")
		for text in ["simple rest", "\"quoted token\" rest", "\"unterminated", "\"a\\\"b\" x", "  leading", ""] {
			let scanner = Scanner(string: text)
			var token = ""
			do {
				try ObjC.run { token = LDrawUtilities.scanQuotableToken(scanner) ?? "nil" }
				out.append("\(text.debugDescription): token \(token.debugDescription), rest at \(scanner.scanLocation)")
			} catch { out.append("\(text.debugDescription): raises \(error)") }
		}
		out.append("# angleForViewOrientation")
		for raw in 0...7 {
			guard let o = ViewOrientationT(rawValue: Int32(raw)) else { continue }
			out.append("orientation \(raw): \(ModelLogic.t(LDrawUtilities.angle(forViewOrientation: o)))")
		}
		try Golden.check(ModelLogic.lines(out), against: "model-logic/utilities.txt")
	}

	@Test("TEXMAP lines with a missing or empty image name: what is saved")
	func texmapWithoutName() throws {
		// scanQuotableToken: raises on an empty remainder (utilities golden), but the TEXMAP parser survives it.
		var out: [String] = []
		for line in ["0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10",
					 "0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 sticker.png GLOSSMAP",
					 "0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 \"\""] {
			let text = "0 Texmap\n0 Name: t.ldr\n0 Author: Fixture Author\n\(line)\n3 16 0 0 0 1 0 0 0 1 0\n0 !TEXMAP END\n"
			var saved = ""
			try ObjC.run { saved = RoundTrip.load(Data(text.utf8)).map { String(decoding: RoundTrip.save($0), as: UTF8.self) } ?? "nil" }
			out.append("\(line)\n" + saved.replacingOccurrences(of: "\r\n", with: "\n") + "\n")
		}
		try Golden.check(ModelLogic.lines(out), against: "model-logic/texmap-missing-name.txt")
		withKnownIssue("BUG-019: a TEXMAP line without an image name is saved with the literal name \"(null)\"") {
			#expect(!out.joined().contains("(null)"))
		}
	}

	@Test("imageAtPath loads PNGs and returns nil for missing files")
	func images() throws {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent("img-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: dir) }
		let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 7, pixelsHigh: 5, bitsPerSample: 8,
											   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
											   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
		let png = dir.appendingPathComponent("tex.png")
		try #require(rep.representation(using: .png, properties: [:])).write(to: png)
		let image = LDrawUtilities.image(atPath: png.path)
		#expect(image.map { ($0.takeUnretainedValue().width, $0.takeUnretainedValue().height) } ?? (0, 0) == (7, 5))
		#expect(LDrawUtilities.image(atPath: dir.appendingPathComponent("missing.png").path) == nil)
		try Data("not an image".utf8).write(to: dir.appendingPathComponent("bad.png"))
		#expect(LDrawUtilities.image(atPath: dir.appendingPathComponent("bad.png").path) == nil)
	}

	@Test("!COLOUR definitions: every option is written back")
	func colourDefinitions() throws {
		let defs = [
			"0 !COLOUR Plain CODE 501 VALUE #102030 EDGE #405060",
			"0 !COLOUR Edge_By_Code CODE 502 VALUE #102030 EDGE 0",
			"0 !COLOUR Alpha CODE 503 VALUE #102030 EDGE #405060 ALPHA 128",
			"0 !COLOUR Glow CODE 504 VALUE #102030 EDGE #405060 LUMINANCE 15",
			"0 !COLOUR Chrome CODE 505 VALUE #102030 EDGE #405060 CHROME",
			"0 !COLOUR Pearl CODE 506 VALUE #102030 EDGE #405060 PEARLESCENT",
			"0 !COLOUR Rubber CODE 507 VALUE #102030 EDGE #405060 RUBBER",
			"0 !COLOUR Matte CODE 508 VALUE #102030 EDGE #405060 MATTE_METALLIC",
			"0 !COLOUR Metal CODE 509 VALUE #102030 EDGE #405060 METAL",
			"0 !COLOUR Glitter CODE 510 VALUE #102030 EDGE #405060 ALPHA 128 MATERIAL GLITTER VALUE #FFFFFF FRACTION 0.17 VFRACTION 0.2 SIZE 1",
			"0 !COLOUR Speckle CODE 511 VALUE #102030 EDGE #405060 MATERIAL SPECKLE VALUE #898788 FRACTION 0.4 MINSIZE 1 MAXSIZE 3",
			"0 !COLOUR Bad_Value CODE 512 VALUE nothex EDGE #405060",
			"0 !COLOUR No_Code VALUE #102030 EDGE #405060",
		]
		var out: [String] = []
		for def in defs {
			let file = try ModelLogic.load("0 Colours\n0 Name: colours.ldr\n0 Author: Fixture Author\n\(def)\n")
			let colour = ObjectModel.all(file).compactMap { $0 as? LDrawColor }.first
			var rgba: [Float] = [0, 0, 0, 0]
			colour?.getRGBA(&rgba)
			out.append("\(def)\n  -> \(colour.map { ModelLogic.oneLine($0.write()) } ?? "(no colour parsed)")"
					   + (colour.map { " | code \($0.colorCode().rawValue) rgba \(rgba.map { ModelLogic.f($0) }.joined(separator: " "))" } ?? ""))
		}
		// Ordering used when colours are sorted: compare: (by code) and HSVACompare: (hue, saturation, value).
		let library = try #require(ColorLibrary.shared())
		let colours = [4, 1, 14, 0, 15, 2].compactMap { library.color(forCode: LDrawColorT(rawValue: Int32($0))) }
		out.append("compare: " + (colours as NSArray).sortedArray(using: NSSelectorFromString("compare:")).map { "\(($0 as! LDrawColor).colorCode().rawValue)" }.joined(separator: " "))
		out.append("HSVACompare: " + (colours as NSArray).sortedArray(using: NSSelectorFromString("HSVACompare:")).map { "\(($0 as! LDrawColor).colorCode().rawValue)" }.joined(separator: " "))
		out.append("unknown code 9999: \(library.color(forCode: LDrawColorT(rawValue: 9999)).map { "code \($0.colorCode().rawValue)" } ?? "nil")")
		try Golden.check(ModelLogic.lines(out), against: "model-logic/colours.txt")
	}
}

/// P6b pins for LDrawStep and LDrawModel, written against the ObjC classes before the Swift port: step
/// parsing and terminators, ROTSTEP scanning, write, notifications and observer messages, copy/archive,
/// undo, model header parsing, step display bookkeeping, dragging, optimisation and the edge cases the
/// ObjC handled by messaging nil or by unsigned wrap-around.
@Suite("LDrawStep and LDrawModel edge behaviour (P6b pins)", .fixtureLibrary, .serialized)
struct ContainerPinTests {

	static let line = "2 24 0 0 0 10 0 0"
	static let tri = "3 16 0 0 0 10 0 0 0 10 0"
	static let quad = "4 16 0 0 0 10 0 0 10 10 0 0 10 0"
	static let cond = "5 24 0 0 0 10 0 0 0 5 0 0 -5 0"

	private func step(_ lines: [String]) -> LDrawStep? {
		LDrawStep(lines: ldrawLines(lines), in: NSRange(location: 0, length: lines.count))
	}

	private func model(_ lines: [String], _ range: NSRange? = nil) -> LDrawModel? {
		LDrawModel(lines: ldrawLines(lines), in: range ?? NSRange(location: 0, length: lines.count))
	}

	private func box(_ b: Box3) -> String { "\(ModelLogic.t(b.min))-\(ModelLogic.t(b.max))" }

	private func text(_ d: LDrawDirective?) -> String {
		(d?.write() ?? "nil").replacingOccurrences(of: "\r\n", with: " / ")
	}

	private func children(_ c: LDrawContainer) -> [String] {
		(c.subdirectives() as? [LDrawDirective] ?? []).map { text($0) }
	}

	/// Counts notifications with the given name whose object passes `matches`, while `body` runs.
	private func count(_ name: String, matching matches: @escaping (AnyObject?) -> Bool, _ body: () throws -> Void) rethrows -> Int {
		var seen = 0
		let token = NotificationCenter.default.addObserver(forName: NSNotification.Name(name), object: nil, queue: nil) { note in
			if matches(note.object as AnyObject?) { seen += 1 }
		}
		defer { NotificationCenter.default.removeObserver(token) }
		try body()
		return seen
	}

	// MARK: LDrawStep

	@Test("Step terminators: STEP and ROTSTEP lines (case-sensitive fields, any whitespace)")
	func terminators() {
		let step: [String?: Bool] = ["0 STEP": true, "  0\tSTEP  ": true, "0 STEP extra": true, "0 step": false,
									 "0 STEPS": false, "0 ROTSTEP 1 2 3": false, "1 STEP": false, "": false, nil: false]
		for (line, expected) in step {
			#expect(LDrawStep.lineIsStepTerminator(line) == expected, "\(String(describing: line))")
		}
		let rot: [String?: Bool] = ["0 ROTSTEP END": true, "0 ROTSTEP": true, " 0 ROTSTEP x": true, "0 rotstep end": false,
									"0 STEP": false, "0 ROTSTEPS": false, "": false, nil: false]
		for (line, expected) in rot {
			#expect(LDrawStep.lineIsRotationStepTerminator(line) == expected, "\(String(describing: line))")
		}
	}

	@Test("Step range: ends after the first STEP or ROTSTEP line, else at maxIndex; empty when maxIndex < index")
	func stepRange() {
		let lines = [Self.line, "0 STEP", Self.tri, "0 ROTSTEP END", Self.quad]
		func r(_ at: UInt, _ max: UInt) -> String {
			let range = LDrawStep.rangeOfDirectiveBeginning(at: at, inLines: ldrawLines(lines), maxIndex: max)
			return "\(range.location),\(range.length)"
		}
		#expect(r(0, 4) == "0,2")
		#expect(r(2, 4) == "2,2")
		#expect(r(4, 4) == "4,1")
		#expect(r(0, 0) == "0,1")
		#expect(r(2, 2) == "2,1")
		#expect(r(3, 1) == "3,0")
		#expect(r(3, 2) == "3,0")
		#expect(r(0, UInt.max) == "0,0", "maxIndex NSUIntegerMax wraps to an empty range")
	}

	@Test("ROTSTEP scanning: forms, case-insensitive keywords, prefixes, and what a failure leaves behind")
	func rotstepScanning() {
		func zyx(_ x: Float, _ y: Float, _ z: Float) -> String {
			let s = LDrawStep.empty() as! LDrawStep
			s.setRotationAngleZYX(V3Make(x, y, z))
			return ModelLogic.t(s.rotationAngle())
		}
		let cases: [(String?, Bool, Int32, String)] = [
			("0 ROTSTEP END", true, 4, ModelLogic.t(ZeroPoint3)),
			("0 rotstep end", true, 4, ModelLogic.t(ZeroPoint3)),
			("0 ROTSTEP 10 20 30", true, 1, zyx(10, 20, 30)),
			("0 ROTSTEP 10 20 30 REL", true, 1, zyx(10, 20, 30)),
			("0 ROTSTEP 10 20 30 ABS", true, 2, zyx(10, 20, 30)),
			("0 ROTSTEP 10 20 30 ADD", true, 3, zyx(10, 20, 30)),
			("0 ROTSTEP 10 20 30 abs", true, 2, zyx(10, 20, 30)),
			("0 ROTSTEP 10 20 30 ABSOLUTELY", true, 2, zyx(10, 20, 30)),
			("   0   ROTSTEP 1.5 -2 3e1 ADD", true, 3, zyx(1.5, -2, 30)),
			("0 ROTSTEP 10 20 30 FOO", false, 0, ModelLogic.t(ZeroPoint3)),
			("0 ROTSTEP 10 20", false, 0, ModelLogic.t(ZeroPoint3)),
			("0 ROTSTEP x y", false, 0, ModelLogic.t(ZeroPoint3)),
			("0 ROTSTEP", false, 0, ModelLogic.t(ZeroPoint3)),
			("1 ROTSTEP 1 2 3", false, 0, ModelLogic.t(ZeroPoint3)),
			("0 STEP", false, 0, ModelLogic.t(ZeroPoint3)),
			("0 ROTSTEPEND", true, 4, ModelLogic.t(ZeroPoint3)),
		]
		for (line, ok, type, angle) in cases {
			let s = LDrawStep.empty() as! LDrawStep
			#expect(s.parseRotationStep(fromLine: line) == ok, "\(String(describing: line))")
			#expect(s.stepRotationType().rawValue == type, "\(String(describing: line))")
			#expect(ModelLogic.t(s.rotationAngle()) == angle, "\(String(describing: line))")
		}
	}

	@Test("Step parsing: children in order, blank lines skipped, the terminator consumed; a bad ROTSTEP fails")
	func stepParsing() throws {
		let plain = try #require(step(["0 // first", "", Self.line, "0 STEP"]))
		#expect(children(plain) == ["0 // first", Self.line])
		#expect(plain.stepRotationType() == .none)
		#expect(plain.stepFlavor() == .anyDirectives)
		#expect(text(plain) == "0 // first / \(Self.line) / 0 STEP")
		#expect(plain.write(withStepCommand: false).replacingOccurrences(of: "\r\n", with: " / ") == "0 // first / \(Self.line)")

		let rot = try #require(step([Self.tri, "0 ROTSTEP 0 90 0 ABS"]))
		#expect(children(rot) == [Self.tri])
		#expect(rot.stepRotationType() == .absolute)
		#expect(rot.write(withStepCommand: false).replacingOccurrences(of: "\r\n", with: " / ") == "\(Self.tri) / 0 ROTSTEP 0.000 90.000 0.000 ABS",
				"a rotation step always writes its ROTSTEP")

		let open = try #require(step([Self.line, Self.tri]))
		#expect(children(open) == [Self.line, Self.tri])
		#expect(text(open) == "\(Self.line) / \(Self.tri) / 0 STEP")

		let onlyStep = try #require(step(["0 STEP"]))
		#expect(children(onlyStep).isEmpty)
		#expect(text(onlyStep) == "0 STEP")
		#expect(onlyStep.write(withStepCommand: false) == "")

		let notLast = try #require(step(["0 STEP", Self.line]))
		#expect(children(notLast) == ["0 STEP", Self.line], "only the last line is a terminator")

		#expect(step([Self.line, "0 ROTSTEP 1 2"]) == nil)
		#expect(step([Self.line, "0 ROTSTEP 1 2 3 SIDEWAYS"]) == nil)
		let empty = try #require(LDrawStep(lines: ldrawLines([Self.line]), in: NSRange(location: 1, length: 0)))
		#expect(children(empty).isEmpty)
	}

	@Test("Step setters post LDrawStepDidChangeNotification only while the step posts notifications")
	func stepNotifications() throws {
		let s = LDrawStep.empty() as! LDrawStep
		let silent = count("LDrawStepDidChangeNotification", matching: { $0 === s }) {
			s.setRotationAngle(V3Make(1, 2, 3))
			s.setStepFlavor(.lines)
			s.setStepRotationType(.relative)
			s.setRotationAngleZYX(V3Make(3, 2, 1))
			_ = s.parseRotationStep(fromLine: "0 ROTSTEP 1 2 3 ABS")
		}
		#expect(silent == 0)
		s.setPostsNotifications(true)
		let loud = count("LDrawStepDidChangeNotification", matching: { $0 === s }) {
			s.setRotationAngle(V3Make(1, 2, 3))
			s.setStepFlavor(.lines)
			s.setStepRotationType(.relative)
			s.setRotationAngleZYX(V3Make(3, 2, 1))
			_ = s.parseRotationStep(fromLine: "0 ROTSTEP 1 2 3 ABS")
			_ = s.parseRotationStep(fromLine: "0 ROTSTEP END")
			_ = s.parseRotationStep(fromLine: "0 ROTSTEP 1 2 3 FOO")
		}
		#expect(loud == 4 + 2 + 1)
	}

	@Test("Step and model: observer messages for insert, remove and bounds revalidation")
	func observerMessages() throws {
		let s = LDrawStep.empty() as! LDrawStep
		let recorder = ObserverRecorder(label: "obs")
		s.add(recorder)
		defer { (s as any LDrawObservable).remove(recorder) }
		let a = try Prim.parse(Self.line), b = try Prim.parse(Self.tri)
		s.add(a)
		s.add(b)
		_ = s.boundingBox3()
		s.removeDirective(at: 0)
		s.collectSelf(NullCollector())
		s.insert(a, at: 1)
		#expect(recorder.log == [
			"obs: statusInvalidated flags=3 from LDrawStep",
			"obs: statusInvalidated flags=1 from LDrawStep",
			"obs: statusInvalidated flags=2 from LDrawStep",
		], "\(recorder.log)")
		#expect(children(s) == [Self.tri, Self.line])

		let m = LDrawModel.model() as! LDrawModel
		let mRecorder = ObserverRecorder(label: "m")
		m.add(mRecorder)
		defer { (m as any LDrawObservable).remove(mRecorder) }
		m.addStep()
		_ = m.boundingBox3()
		m.setStepDisplay(true)
		m.setMaximumStepIndexForStepDisplay(1)
		m.removeDirective(at: 1)
		#expect(mRecorder.log == ["m: statusInvalidated flags=1 from LDrawModel"], "\(mRecorder.log)")
	}

	@Test("Step copy keeps flavor, rotation and children; an archive keeps rotation but not flavor")
	func stepCopyAndArchive() throws {
		let s = try #require(step([Self.line, Self.tri, "0 ROTSTEP 10 20 30 ADD"]))
		s.setStepFlavor(.triangles)
		let bounds = s.boundingBox3()
		let copy = try #require(s.copy() as? LDrawStep)
		#expect(copy.stepFlavor() == .triangles)
		#expect(copy.stepRotationType() == .additive)
		#expect(ModelLogic.t(copy.rotationAngle()) == ModelLogic.t(s.rotationAngle()))
		#expect(children(copy) == children(s).reversed(), "BUG-011: a container copy reverses its children")
		#expect(box(copy.boundingBox3()) == box(bounds))

		let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(s)) as? LDrawStep)
		#expect(decoded.stepFlavor() == .anyDirectives)
		#expect(decoded.stepRotationType() == .additive)
		#expect(ModelLogic.t(decoded.rotationAngle()) == ModelLogic.t(s.rotationAngle()))
		#expect(children(decoded) == children(s))
		#expect(box(decoded.boundingBox3()) == box(bounds))
		#expect(text(decoded) == text(s))
	}

	@Test("Step outline text: its 1-based index in the enclosing model, or just 'Step'")
	func stepBrowsingDescription() throws {
		let m = LDrawModel.model() as! LDrawModel
		let second = m.addStep()!
		#expect(second.browsingDescription() == "Step 2")
		#expect(second.enclosingModel() === m)
		let loose = LDrawStep.empty() as! LDrawStep
		#expect(loose.browsingDescription() == "Step")
		#expect(loose.enclosingModel() == nil)
		loose.setModel(m)
		#expect(loose.enclosingModel() === m)
		#expect(loose.enclosingDirective() === m)
		// Not one of the model's steps: NSNotFound + 1 wraps.
		#expect(loose.browsingDescription() == "Step \(Int.min)")
		#expect(loose.inspectorClassName() == "InspectionStep")
	}

	@Test("Step undo restores the rotation angle and type")
	func stepUndo() throws {
		let s = try #require(step([Self.line, "0 ROTSTEP 10 0 0 ABS"]))
		let before = ModelLogic.t(s.rotationAngle())
		let undo = UndoManager()
		undo.groupsByEvent = false
		try ObjC.run {
			undo.beginUndoGrouping()
			s.registerUndoActions(undo)
			undo.endUndoGrouping()
		}
		#expect(undo.undoActionName == "Step Rotation")
		s.setStepRotationType(.end)
		s.setRotationAngle(V3Make(1, 1, 1))
		try ObjC.run { undo.undo() }
		#expect(s.stepRotationType() == .absolute)
		#expect(ModelLogic.t(s.rotationAngle()) == before)
	}

	@Test("Step bounds: union of the children, recomputed after an insert; an empty step has none")
	func stepBounds() throws {
		let s = LDrawStep.empty() as! LDrawStep
		#expect(box(s.boundingBox3()) == box(InvalidBox))
		s.add(try Prim.parse(Self.line))
		#expect(ModelLogic.t(s.boundingBox3().max) == "(10.000, 0.000, 0.000)")
		s.add(try Prim.parse(Self.tri))
		#expect(ModelLogic.t(s.boundingBox3().max) == "(10.000, 10.000, 0.000)")
		s.removeDirective(at: 1)
		#expect(ModelLogic.t(s.boundingBox3().max) == "(10.000, 0.000, 0.000)")
	}

	// MARK: LDrawModel

	@Test("Model defaults: -init, +model, and an empty model's unsigned wrap-around")
	func modelDefaults() throws {
		let bare = LDrawModel()
		#expect(bare.modelDescription() == "")
		#expect(bare.fileName() == "")
		#expect(bare.author() == "")
		#expect(bare.stepDisplay() == false)
		#expect(bare.steps().count == 0)
		#expect(bare.colorLibrary() != nil)
		#expect(bare.maxStepIndexToOutput() == UInt.max)
		#expect(bare.visibleStep() == nil)
		#expect(bare.numberElements() == 0)
		#expect(bare.category() == "")
		#expect(ModelLogic.t(bare.rotationCenter()) == ModelLogic.t(ZeroPoint3))
		#expect(text(bare) == "0  / 0 Name:  / 0 Author: ")
		#expect(bare.browsingDescription() == "")
		#expect(bare.iconName() == "Document")
		#expect(bare.draggingDirectives() == nil)

		let made = LDrawModel.model() as! LDrawModel
		#expect(type(of: made) == LDrawModel.self)
		#expect(made.modelDescription() == "untitled model")
		#expect(made.fileName() == "")
		#expect(made.author() == LDrawUtilities.defaultAuthor())
		#expect(made.steps().count == 1)
		#expect(made.colorLibrary() !== bare.colorLibrary())
		#expect(text(made) == "0 untitled model / 0 Name:  / 0 Author: \(LDrawUtilities.defaultAuthor() ?? "") / ", "an empty step writes nothing, but its CRLF stays")

		// Messaging nil: a nil description writes "(null)" and has no category.
		made.setModelDescription(nil)
		made.setFileName(nil)
		made.setAuthor(nil)
		#expect(made.modelDescription() == nil)
		#expect(made.fileName() == nil)
		#expect(made.author() == "", "a nil author becomes empty")
		#expect(made.category() == nil)
		#expect(text(made) == "0 (null) / 0 Name: (null) / 0 Author:  / ")
	}

	@Test("Model category: the first word of the description, without a leading _ or ~")
	func category() {
		let m = LDrawModel()
		for (description, expected) in [("Brick  2 x  4", "Brick"), ("_Hidden Part", "Hidden"), ("~Moved to 3001", "Moved"),
										("NoSpace", "NoSpace"), ("", ""), ("~", ""), (" Leading", ""), ("__x y", "_x")] {
			m.setModelDescription(description)
			#expect(m.category() == expected, "\(description)")
		}
	}

	@Test("Model header: description, Name:, Author: in any order, MLCad's repository line dropped")
	func header() throws {
		let full = try #require(model(["0 Desc  ", "0 Name:  a.ldr ", "0 Author: Me <me@x>", Self.line]))
		#expect(full.modelDescription() == "Desc")
		#expect(full.fileName() == "a.ldr")
		#expect(full.author() == "Me <me@x>")
		#expect(full.steps().count == 1)
		#expect(full.numberElements() == 1)

		let swapped = try #require(model(["0 Desc", "0 Author: A", "0 Name: n.ldr", "0 LDraw.org Official Model Repository", "0 http://x", Self.line]))
		#expect(swapped.fileName() == "n.ldr")
		#expect(swapped.author() == "A")
		#expect(children(try #require(swapped.steps().first as? LDrawStep)) == ["0 http://x", Self.line])

		let unofficial = try #require(model(["0 Desc", "0 Unofficial Model", "0 Name: u.ldr", Self.line]))
		#expect(unofficial.fileName() == "u.ldr")
		#expect(children(try #require(unofficial.steps().first as? LDrawStep)) == [Self.line])

		// The header stops at the first line that is not a header line (the three-line limit moves with it).
		let stops = try #require(model(["0 Desc", "0 // comment", "0 Name: late.ldr", Self.line]))
		#expect(stops.fileName() == "")
		#expect(stops.numberElements() == 3)
		let four = try #require(model(["0 D", "0 Name: a", "0 Author: b", "0 Name: c", Self.line]))
		#expect(four.fileName() == "c")
		#expect(children(try #require(four.steps().first as? LDrawStep)) == [Self.line])

		let none = try #require(model([Self.line, "0 Name: x.ldr"]))
		#expect(none.modelDescription() == "")
		#expect(none.fileName() == "")
		#expect(none.numberElements() == 2)
	}

	@Test("Model header past the end of the model's range, and empty ranges")
	func headerPastRange() throws {
		let lines = ["0 Desc", "0 Name: x.ldr", "0 Author: A", Self.line]
		let short = try #require(model(lines, NSRange(location: 0, length: 1)))
		#expect(short.modelDescription() == "Desc")
		#expect(short.fileName() == "x.ldr")
		#expect(short.author() == "A")
		#expect(short.steps().count == 1)
		#expect(short.numberElements() == 0)

		let empty = try #require(model(lines, NSRange(location: 0, length: 0)))
		#expect(empty.modelDescription() == "Desc")
		#expect(empty.steps().count == 1)
		#expect(empty.numberElements() == 0)

		let tail = try #require(model(lines, NSRange(location: 3, length: 0)))
		#expect(tail.modelDescription() == "")
		#expect(tail.steps().count == 1)
		#expect(tail.numberElements() == 0)
	}

	@Test("parseHeaderFromLines: and line:isValidForHeader:info:")
	func headerHelpers() {
		let m = LDrawModel()
		#expect(m.parseHeader(fromLines: ldrawLines(["0 D", "0 Name: n"]), beginningAt: 2) == 2)
		#expect(m.parseHeader(fromLines: ldrawLines(["x", "0 D", "0 Name: n", "0 Author: a", "0 Author: b", "0 x"]), beginningAt: 1) == 5)
		#expect(m.author() == "b")
		#expect(m.parseHeader(fromLines: ldrawLines([Self.line]), beginningAt: 0) == 0)

		var info: NSString? = "unset"
		#expect(m.line("0 Name:  foo bar \t", isValidForHeader: "Name:", info: &info))
		#expect(info == "foo bar")
		info = "unset"
		#expect(!m.line("0 name: x", isValidForHeader: "Name:", info: &info))
		#expect(info == "unset")
		#expect(!m.line("1 Name: x", isValidForHeader: "Name:", info: &info))
		#expect(m.line("0", isValidForHeader: "", info: &info))
		#expect(info == "")
		#expect(m.line(" 0  Desc ", isValidForHeader: "", info: &info))
		#expect(info == "Desc")
		#expect(m.line("0 Desc", isValidForHeader: nil, info: nil))
		#expect(!m.line(nil, isValidForHeader: "", info: nil))
	}

	@Test("Model parsing: steps split at STEP/ROTSTEP; a trailing STEP adds no step; one bad ROTSTEP fails the model")
	func modelSteps() throws {
		let one = try #require(model([Self.line, "0 STEP"]))
		#expect(one.steps().count == 1)
		#expect(text(one) == "0  / 0 Name:  / 0 Author:  / \(Self.line)", "a one-step model writes no STEP")
		let two = try #require(model([Self.line, "0 STEP", Self.tri]))
		#expect(two.steps().count == 2)
		#expect(text(two) == "0  / 0 Name:  / 0 Author:  / \(Self.line) / 0 STEP / \(Self.tri) / 0 STEP")
		let three = try #require(model([Self.line, "0 ROTSTEP 0 45 0 ABS", Self.tri, "0 STEP", Self.quad, "0 ROTSTEP END"]))
		#expect(three.steps()!.map { ($0 as! LDrawStep).stepRotationType().rawValue } == [2, 0, 4])
		#expect(model([Self.line, "0 ROTSTEP 1 2", Self.tri]) == nil)
		#expect(model([Self.line, "0 STEP", Self.tri, "0 ROTSTEP x"]) == nil)
		for case let s as LDrawStep in three.steps() { #expect(s.enclosingDirective() === three) }
	}

	@Test("Step display: visible steps, makeStepVisible, removing steps, and the unsigned bounds check")
	func stepDisplay() throws {
		let m = try #require(model([Self.line, "0 STEP", Self.tri, "0 STEP", Self.quad, "0 STEP", Self.cond]))
		#expect(m.maxStepIndexToOutput() == 3)
		#expect(m.visibleStep() === m.steps()[3] as AnyObject)
		m.setStepDisplay(true)
		#expect(m.maxStepIndexToOutput() == 0)
		#expect(m.visibleStep() === m.steps()[0] as AnyObject)
		m.makeStepVisible(m.steps()[2] as? LDrawStep)
		#expect(m.maximumStepIndexForStepDisplay() == 2)
		m.makeStepVisible(m.steps()[1] as? LDrawStep)
		#expect(m.maximumStepIndexForStepDisplay() == 2, "already visible")
		m.makeStepVisible(LDrawStep.empty() as? LDrawStep)
		m.makeStepVisible(nil)
		#expect(m.maximumStepIndexForStepDisplay() == 2)
		m.removeDirective(at: 3)
		#expect(m.maximumStepIndexForStepDisplay() == 2, "removed after the visible step")
		m.removeDirective(at: 1)
		#expect(m.maximumStepIndexForStepDisplay() == 1)
		m.removeDirective(at: 0)
		m.removeDirective(at: 0)
		#expect(m.maximumStepIndexForStepDisplay() == 0, "never below zero")
		#expect(m.steps().count == 0)
		m.setMaximumStepIndexForStepDisplay(5)		// count - 1 wraps, so no raise
		#expect(m.maximumStepIndexForStepDisplay() == 5)
		#expect(m.maxStepIndexToOutput() == 5)
		m.setStepDisplay(false)
		#expect(m.maxStepIndexToOutput() == UInt.max)
		#expect(m.visibleStep() == nil)

		let off = try #require(model([Self.line, "0 STEP", Self.tri]))
		off.makeStepVisible(off.steps()[1] as? LDrawStep)
		#expect(off.maximumStepIndexForStepDisplay() == 0, "not in step display: everything is visible already")
	}

	@Test("Model bounds follow step display and include dragged directives")
	func modelBounds() throws {
		let m = try #require(model([Self.line, "0 STEP", "3 16 0 0 0 0 20 0 0 0 30"]))
		#expect(ModelLogic.t(m.boundingBox3().max) == "(10.000, 20.000, 30.000)")
		m.setStepDisplay(true)
		#expect(ModelLogic.t(m.boundingBox3().max) == "(10.000, 0.000, 0.000)")
		let dragged = try Prim.parse("2 24 0 0 0 0 0 50")
		m.setDraggingDirectives([dragged])
		#expect(ModelLogic.t(m.boundingBox3().max) == "(10.000, 0.000, 50.000)")
		#expect((m.draggingDirectives() as? [LDrawDirective])?.count == 1)
		#expect((m.draggingDirectives()?.first as AnyObject?) === dragged)
		#expect(dragged.enclosingStep()?.enclosingDirective() === m)
		#expect(m.steps().count == 2, "the drag step is not one of the model's steps")
		m.setDraggingDirectives(nil)
		#expect(m.draggingDirectives() == nil)
		#expect(ModelLogic.t(m.boundingBox3().max) == "(10.000, 0.000, 0.000)")
		m.setDraggingDirectives([])
		#expect(m.draggingDirectives()?.count == 0)
	}

	@Test("Rotation center: stored, and every change is posted with the old value on the enclosing file")
	func rotationCenter() throws {
		let file = try ModelLogic.load("0 R\n0 Name: r.ldr\n0 Author: A\n\(Self.line)\n")
		let m = try #require(file.activeModel())
		var infos: [String] = []
		let token = NotificationCenter.default.addObserver(forName: NSNotification.Name("LDrawModelRotationCenterDidChangeNotification"), object: nil, queue: nil) { note in
			var old = Point3()
			(note.userInfo?["oldRotationCenter"] as? NSValue)?.getValue(&old, size: MemoryLayout<Point3>.size)
			infos.append("\((note.object as AnyObject?) === file ? "file" : String(describing: note.object)) old \(ModelLogic.t(old)) keys \(note.userInfo?.count ?? 0)")
		}
		defer { NotificationCenter.default.removeObserver(token) }
		m.setRotationCenter(V3Make(1, 2, 3))
		m.setRotationCenter(V3Make(1, 2, 3))
		#expect(ModelLogic.t(m.rotationCenter()) == "(1.000, 2.000, 3.000)")
		let loose = LDrawModel()
		loose.setRotationCenter(V3Make(4, 5, 6))
		#expect(infos == ["file old (0.000, 0.000, 0.000) keys 1", "file old (1.000, 2.000, 3.000) keys 1",
						  "nil old (0.000, 0.000, 0.000) keys 1"], "\(infos)")
		#expect(m.enclosingFile() === file)
	}

	@Test("Model copy keeps header and step display; an archive keeps the header only, and no colour library")
	func modelCopyAndArchive() throws {
		let m = try #require(model(["0 Desc", "0 Name: c.ldr", "0 Author: A", Self.line, "0 STEP", Self.tri, "0 STEP", Self.quad]))
		m.setStepDisplay(true)
		m.setMaximumStepIndexForStepDisplay(1)
		m.setRotationCenter(V3Make(1, 1, 1))
		let copy = try #require(m.copy() as? LDrawModel)
		#expect(copy.modelDescription() == "Desc" && copy.fileName() == "c.ldr" && copy.author() == "A")
		#expect(copy.stepDisplay())
		#expect(copy.maximumStepIndexForStepDisplay() == 1)
		#expect(ModelLogic.t(copy.rotationCenter()) == ModelLogic.t(ZeroPoint3))
		#expect(copy.colorLibrary() != nil && copy.colorLibrary() !== m.colorLibrary())
		#expect(text(copy) == "0 Desc / 0 Name: c.ldr / 0 Author: A / \(Self.quad) / 0 STEP / \(Self.tri) / 0 STEP / \(Self.line) / 0 STEP",
				"BUG-011: the copied steps are reversed")
		#expect(ModelLogic.t(copy.boundingBox3().max) == ModelLogic.t(m.boundingBox3().max))

		let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(m)) as? LDrawModel)
		#expect(decoded.modelDescription() == "Desc" && decoded.fileName() == "c.ldr" && decoded.author() == "A")
		#expect(!decoded.stepDisplay())
		#expect(decoded.maximumStepIndexForStepDisplay() == 0)
		#expect(decoded.colorLibrary() == nil, "-initWithCoder: never ran -init")
		#expect(text(decoded) == text(m))
		#expect(ModelLogic.t(decoded.boundingBox3().max) == "(10.000, 10.000, 0.000)")
	}

	@Test("Model undo restores author, file name and description")
	func modelUndo() throws {
		let m = try #require(model(["0 Desc", "0 Name: u.ldr", "0 Author: A", Self.line]))
		let undo = UndoManager()
		undo.groupsByEvent = false
		try ObjC.run {
			undo.beginUndoGrouping()
			m.registerUndoActions(undo)
			undo.endUndoGrouping()
		}
		#expect(undo.undoActionName == "Model Attributes")
		m.setAuthor("B")
		m.setFileName("v.ldr")
		m.setModelDescription("Other")
		try ObjC.run { undo.undo() }
		#expect(m.author() == "A" && m.fileName() == "u.ldr" && m.modelDescription() == "Desc")
	}

	@Test("optimizeStructure: flattened into a lines, triangles and quads step, in that order; comments and conditional lines are dropped")
	func optimize() throws {
		let m = try #require(model(["0 // c", Self.quad, "0 STEP", Self.tri, Self.line, Self.cond, "0 STEP", Self.tri]))
		m.optimizeStructure()
		let steps = m.steps() as! [LDrawStep]
		#expect(steps.map { $0.stepFlavor().rawValue } == [1, 2, 3])
		#expect(steps.map { $0.subdirectives().count } == [1, 2, 1])
		#expect(steps.allSatisfy { $0.enclosingDirective() === m })
		#expect(m.numberElements() == 4)

		let bare = LDrawModel()
		bare.optimizeStructure()
		#expect((bare.steps() as! [LDrawStep]).map { $0.stepFlavor().rawValue } == [0])
		#expect(bare.numberElements() == 0)

		let linesOnly = try #require(model([Self.line]))
		linesOnly.optimizeStructure()
		#expect((linesOnly.steps() as! [LDrawStep]).map { $0.stepFlavor().rawValue } == [1])
	}

	@Test("Model insert/remove/addStep: steps are wired to the model; adding a step keeps step display")
	func addSteps() throws {
		let m = LDrawModel()
		let added = m.addStep()!
		#expect(added.enclosingDirective() === m)
		let mine = LDrawStep.empty() as! LDrawStep
		m.addStep(mine)
		#expect(m.steps().count == 2)
		#expect(m.steps()[1] as AnyObject === mine)
	}
}
