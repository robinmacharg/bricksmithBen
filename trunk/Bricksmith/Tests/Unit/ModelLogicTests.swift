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
