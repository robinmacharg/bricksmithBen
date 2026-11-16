//
//  TextureAndHelpersTests.swift
//  BricksmithTests
//
//  P2 exit (coverage): LDrawTexture, StringUtilities and the categories.
//    - LDrawTexture: parsing the planar !TEXMAP header, START/FALLBACK/END sections, nesting, NEXT, write,
//      textures inside library parts (-optimizeStructure -> flattenIntoLines:...), selection handles.
//    - StringUtilities: the "copy N" names used when pasting/adding a model whose name already exists.
//    - BezierPathCategory, TableViewCategory, WindowCategory, OverlayViewCategory.
//  Goldens: golden/texture-helpers/*.
//

import AppKit
import Foundation
import Testing
@testable import Bricksmith

// MARK: - LDrawTexture

enum Tex {
	static let header = "0 Texture case\n0 Name: texcase.ldr\n0 Author: Fixture Author\n"

	/// Parse `body` as a file, with a header first (LEARNINGS L71).
	static func parse(_ body: String) -> LDrawFile? {
		RoundTrip.load(Data((header + body + "\n").utf8))
	}

	static func load(_ body: String) throws -> LDrawFile {
		try #require(try ObjC.run { parse(body) })
	}

	/// The written file without its 3 header lines.
	static func body(_ text: String) -> String {
		text.components(separatedBy: "\n").dropFirst(3).joined(separator: "\n")
	}

	static func text(_ file: LDrawFile) -> String {
		String(decoding: RoundTrip.save(file), as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
	}

	/// One line per directive, indented by depth. Textures show their names and children.
	static func tree(_ directive: LDrawDirective, _ indent: String = "") -> [String] {
		if let texture = directive as? LDrawTexture {
			var out = ["\(indent)texture image=\(texture.imageDisplayName() ?? "nil") ref=\(texture.imageReferenceName() ?? "nil") "
					   + "gloss=\(texture.glossmapName() ?? "nil") browsing=\(texture.browsingDescription() ?? "nil") "
					   + "icon=\(texture.iconName() ?? "nil")"]
			for child in texture.subdirectives() { out += tree(child as! LDrawDirective, indent + "  ") }
			return out
		}
		if let step = directive as? LDrawStep {
			var out = ["\(indent)step"]
			for child in step.subdirectives() { out += tree(child as! LDrawDirective, indent + "  ") }
			return out
		}
		let firstLine = Prim.write(directive).components(separatedBy: "\n").first ?? ""
		return ["\(indent)\(type(of: directive)): \(firstLine)"]
	}

	static func tree(_ file: LDrawFile) -> [String] {
		file.activeModel().steps().flatMap { tree($0 as! LDrawDirective) }
	}

	static let triA = "3 16 -10 0 -10 10 0 -10 10 0 10"
	static let triB = "3 16 -10 0 -10 10 0 10 -10 0 10"
	static let start = "0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 sticker.png"
	static let part = "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3005.dat"
}

@MainActor
@Suite("LDrawTexture: !TEXMAP parsing, sections, write, library parts (P2 exit)", .fixtureLibrary, .serialized)
struct TextureCoverageTests {
	/// Textures ask PartLibrary for GL texture names, and selecting one creates drag handles (L70).
	init() throws { try OffscreenGL.makeCurrent() }

	/// Each case: input body -> parsed tree -> written file -> is a second parse/write stable?
	static let cases: [(String, String)] = [
		("START with !: geometry, then FALLBACK geometry",
		 [Tex.start, "0 !: \(Tex.triA)", "0 !TEXMAP FALLBACK", Tex.triB, "0 !TEXMAP END", Tex.part].joined(separator: "\n")),
		("mixed !: and plain lines of every type",
		 [Tex.start, "0 !: 2 24 0 0 0 10 0 0", Tex.triA, "0 !: 4 16 0 0 0 10 0 0 10 0 10 0 0 10",
		  "5 24 0 0 0 10 0 0 0 5 0 0 -5 0", "0 !: \(Tex.part)", "0 // comment in a texture", "0 !TEXMAP END"].joined(separator: "\n")),
		("GLOSSMAP name",
		 [Tex.start + " GLOSSMAP gloss.png", "0 !: \(Tex.triA)", "0 !TEXMAP END"].joined(separator: "\n")),
		("quoted image name with spaces",
		 ["0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 \"my sticker.png\"", "0 !: \(Tex.triA)", "0 !TEXMAP END"].joined(separator: "\n")),
		("upper-case image name (reference name is lower-cased)",
		 ["0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 Sticker.PNG", "0 !: \(Tex.triA)", "0 !TEXMAP END"].joined(separator: "\n")),
		("no END, end of file (spec: texture runs to the end of the file; see unterminated())",
		 [Tex.start, "0 !: \(Tex.triA)", Tex.part].joined(separator: "\n")),
		("no END, then STEP (spec: texture runs to the STEP; see unterminated())",
		 [Tex.start, "0 !: \(Tex.triA)", "0 STEP", Tex.part].joined(separator: "\n")),
		("empty texture",
		 [Tex.start, "0 !TEXMAP END", Tex.part].joined(separator: "\n")),
		("FALLBACK with nothing after it",
		 [Tex.start, "0 !: \(Tex.triA)", "0 !TEXMAP FALLBACK", "0 !TEXMAP END"].joined(separator: "\n")),
		("nested START/END, as many lines after the inner END as inside it",
		 [Tex.start, "0 !TEXMAP START PLANAR 0 0 0 1 0 0 0 0 1 inner.png", Tex.triA, "0 !TEXMAP END", Tex.triB,
		  "0 !TEXMAP END", Tex.part].joined(separator: "\n")),
		("nested START/END, more lines after the inner END than inside it",
		 [Tex.start, "0 !TEXMAP START PLANAR 0 0 0 1 0 0 0 0 1 inner.png", Tex.triA, "0 !TEXMAP END", Tex.triB, Tex.triA,
		  "0 !TEXMAP END", Tex.part].joined(separator: "\n")),
		("NEXT followed by two lines (spec: applies to the next line only; see nextCoversOneLine())",
		 ["0 !TEXMAP NEXT PLANAR -10 0 -10 10 0 -10 -10 0 10 sticker.png", Tex.triA, Tex.part].joined(separator: "\n")),
		("CYLINDRICAL (not supported: not a texture)",
		 ["0 !TEXMAP START CYLINDRICAL 0 0 0 0 10 0 10 0 0 90 sticker.png", "0 !: \(Tex.triA)", "0 !TEXMAP END"].joined(separator: "\n")),
		("PLANAR header with no image name",
		 ["0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10", "0 !: \(Tex.triA)", "0 !TEXMAP END"].joined(separator: "\n")),
		("PLANAR header with too few coordinates",
		 ["0 !TEXMAP START PLANAR -10 0 -10 10 0", "0 !: \(Tex.triA)", "0 !TEXMAP END"].joined(separator: "\n")),
	]

	@Test("Parse -> tree -> write for START/FALLBACK/END, nesting, NEXT and malformed headers")
	func parseAndWrite() throws {
		var out: [String] = []
		for (name, body) in Self.cases {
			out.append("## \(name)")
			out += body.components(separatedBy: "\n").map { "< \($0)" }
			let parsed = try Tex.load(body)
			out += Tex.tree(parsed).map { "  \($0)" }
			let written = Tex.text(parsed)
			out += Tex.body(written).components(separatedBy: "\n").filter { !$0.isEmpty }.map { "> \($0)" }
			let rewritten = Tex.text(try Tex.load(Tex.body(written)))
			out.append(rewritten == written ? "stable: yes" : "stable: NO, second write:")
			if rewritten != written {
				out += Tex.body(rewritten).components(separatedBy: "\n").filter { !$0.isEmpty }.map { ">> \($0)" }
			}
			out.append("")
		}
		try Golden.check(Data(out.joined(separator: "\n").utf8), against: "texture-helpers/texture-cases.txt")
	}

	@Test("The planar header parser accepts or rejects each field")
	func planarHeader() throws {
		let numbers = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
		var lines = [
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png",
			"0 !TEXMAP NEXT PLANAR 1 2 3 4 5 6 7 8 9 a.png",
			"1 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png",
			"0 !TEXMOP START PLANAR 1 2 3 4 5 6 7 8 9 a.png",
			"0 !TEXMAP BEGIN PLANAR 1 2 3 4 5 6 7 8 9 a.png",
			"0 !TEXMAP START SPHERICAL 1 2 3 4 5 6 7 8 9 a.png",
		]
		for count in 0..<9 {
			lines.append((["0 !TEXMAP START PLANAR"] + numbers.prefix(count) + ["x"]).joined(separator: " "))
		}
		lines += [
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \"\"",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \"two words.png\"",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \"say \\\"hi\\\".png\"",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 dir\\\\a.png",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png GLOSSMAP g.png",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png GLOSSMAP \"g g.png\"",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png GLOSSMAP",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png SOMETHING else",
			"0 !TEXMAP START PLANAR 1e1 -0.5 +3 4 5 6 7 8 9 a.png",
		]
		var out: [String] = []
		for line in lines {
			let texture = LDrawTexture()
			let ok = try ObjC.run { texture.parsePlanarTexture(fromLine: line, parentGroup: nil) }
			let header = Prim.write(texture).components(separatedBy: "\n").first ?? ""
			out.append("\(line)\n  -> \(ok ? "YES" : "NO "); image=\(texture.imageDisplayName() ?? "nil") "
					   + "gloss=\(texture.glossmapName() ?? "nil"); writes: \(header)")
		}
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "texture-helpers/planar-header.txt")
	}

	@Test("Image names with spaces keep their quotes when written (spec: must be quoted)")
	func quotedNameRoundTrip() throws {
		let file = try Tex.load(["0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 \"my sticker.png\"",
								 "0 !: \(Tex.triA)", "0 !TEXMAP END"].joined(separator: "\n"))
		let texture = try #require(Tex.firstTexture(file))
		#expect(texture.imageDisplayName() == "my sticker.png")
		let again = try Tex.load(Tex.body(Tex.text(file)))
		withKnownIssue("BUG-020: -[LDrawTexture write] drops the quotes around an image name with spaces") {
			#expect(Tex.text(file).contains("\"my sticker.png\""), "written: \(Tex.text(file))")
			#expect(Tex.firstTexture(again)?.imageDisplayName() == "my sticker.png")
		}
	}

	@Test("NEXT applies the texture to the next line only")
	func nextCoversOneLine() throws {
		// Two lines after the NEXT line come out right by accident (see the unterminated test), so use three.
		let file = try Tex.load(["0 !TEXMAP NEXT PLANAR -10 0 -10 10 0 -10 -10 0 10 sticker.png", Tex.triA, Tex.triB, Tex.part]
									.joined(separator: "\n"))
		let step = try DrawHarness.stepSync(file)
		let texture = try #require(Tex.firstTexture(file))
		withKnownIssue("BUG-022: 0 !TEXMAP NEXT is parsed like START with no END, so it takes in the following lines but one") {
			#expect(texture.subdirectives().count == 1, "texture: \(Tex.tree(texture).joined(separator: " | "))")
			#expect(Tex.children(step).count == 3, "step: \(Tex.tree(step).joined(separator: " | "))")
		}
	}

	@Test("START with no END: the texture runs to the end of the file or step (spec)")
	func unterminated() throws {
		// End of file: the texture should hold the triangle and the part.
		let toEnd = try Tex.load([Tex.start, "0 !: \(Tex.triA)", Tex.part].joined(separator: "\n"))
		let textureToEnd = try #require(Tex.firstTexture(toEnd))
		// STEP: the texture should hold the triangle; the part is in the next step.
		let toStep = try Tex.load([Tex.start, "0 !: \(Tex.triA)", "0 STEP", Tex.part].joined(separator: "\n"))
		let textureToStep = try #require(Tex.firstTexture(toStep))
		let stepTree = Tex.tree(try DrawHarness.stepSync(toStep)).joined(separator: " | ")
		withKnownIssue("BUG-021: a texture with no END stops one line short; its last line falls out of the texture (a !: line becomes an undrawn meta command)") {
			#expect(textureToEnd.subdirectives().count == 2, "texture: \(Tex.tree(textureToEnd).joined(separator: " | "))")
			#expect(textureToStep.subdirectives().count == 1, "step: \(stepTree)")
		}
	}

	@Test("Nested START/END: the outer texture ends at its own END")
	func nestedRange() throws {
		let file = try Tex.load([Tex.start, "0 !TEXMAP START PLANAR 0 0 0 1 0 0 0 0 1 inner.png", Tex.triA, "0 !TEXMAP END",
								 Tex.triB, Tex.triA, "0 !TEXMAP END", Tex.part].joined(separator: "\n"))
		let step = try DrawHarness.stepSync(file)
		let outer = try #require(Tex.firstTexture(file))
		#expect(outer.subdirectives().count == 3, "outer children: \(Tex.tree(outer).joined(separator: " | "))")
		withKnownIssue("BUG-023: with a nested START/END, the outer texture's range is wrong unless the lines after the inner END equal the lines inside it") {
			#expect(Tex.children(step).count == 2, "step: \(Tex.tree(step).joined(separator: " | "))")
		}
	}

	@Test("A nested texture survives save and reopen")
	func nestedRoundTrip() throws {
		// This input parses correctly (equal line counts inside and after the inner texture).
		let file = try Tex.load([Tex.start, "0 !TEXMAP START PLANAR 0 0 0 1 0 0 0 0 1 inner.png", Tex.triA, "0 !TEXMAP END",
								 Tex.triB, "0 !TEXMAP END", Tex.part].joined(separator: "\n"))
		let before = Tex.tree(file)
		let reopened = try Tex.load(Tex.body(Tex.text(file)))
		withKnownIssue("BUG-024: a nested texture's END is written without 0 !:, so on reopening it closes the outer texture") {
			#expect(Tex.tree(reopened) == before, "reopened: \(Tex.tree(reopened).joined(separator: " | "))")
		}
	}

	@Test("A texture inside a library part is flattened, transformed and loses its FALLBACK section")
	func libraryPart() throws {
		let library = try #require(FixtureLibrary.current)
		let part = """
			0 Texture test part
			0 Name: textest.dat
			0 Author: Fixture Author
			0 !LDRAW_ORG Unofficial_Part
			0 !TEXMAP START PLANAR 0 0 0 10 0 0 0 0 10 sticker.png GLOSSMAP gloss.png
			0 !: 2 24 0 0 0 10 0 0
			0 !: 3 16 0 0 0 10 0 0 0 0 10
			0 !: 4 16 0 0 0 10 0 0 10 0 10 0 0 10
			0 !: 1 16 5 0 5 5 0 0 0 1 0 0 0 5 rect3.dat
			0 !: 5 24 0 0 0 10 0 0 0 5 0 0 -5 0
			0 !TEXMAP FALLBACK
			3 16 0 0 0 10 0 0 0 0 10
			0 !TEXMAP END
			4 16 0 -1 0 10 -1 0 10 -1 10 0 -1 10

			"""
		try Data(part.replacingOccurrences(of: "\t", with: "").utf8)
			.write(to: library.appendingPathComponent("parts/textest.dat"))

		// How PartLibrary loads a part: parse, then -optimizeStructure (identity transform).
		let partModel = try #require(try ObjC.run { PartLibrary.shared().model(forName: "textest.dat") })
		var out = ["# the part as loaded from the library (optimised)"]
		out += Prim.write(partModel).components(separatedBy: "\n").filter { !$0.isEmpty }

		// A texture nested in a library part's texture is flattened into the outer texture as an "other" directive.
		// (Same number of lines inside the inner texture as after it, so it parses correctly; see nestedRange().)
		let nested = """
			0 Nested texture part
			0 Name: texnest.dat
			0 Author: Fixture Author
			0 !TEXMAP START PLANAR 0 0 0 10 0 0 0 0 10 outer.png
			0 !TEXMAP START PLANAR 0 0 0 1 0 0 0 0 1 inner.png
			0 !: 3 16 0 0 0 10 0 0 0 0 10
			0 !TEXMAP END
			0 !: 4 16 0 0 0 10 0 0 10 0 10 0 0 10
			0 !TEXMAP END

			"""
		try Data(nested.replacingOccurrences(of: "\t", with: "").utf8)
			.write(to: library.appendingPathComponent("parts/texnest.dat"))
		let nestedModel = try #require(try ObjC.run { PartLibrary.shared().model(forName: "texnest.dat") })
		out += ["", "# a part with a nested texture, as loaded from the library (optimised)"]
		out += Prim.write(nestedModel).components(separatedBy: "\n").filter { !$0.isEmpty }

		// A model referencing the part, moved and coloured, then optimised the same way (part inside a part).
		let file = try Tex.load("1 4 100 0 0 1 0 0 0 1 0 0 0 1 textest.dat")
		try ObjC.run { file.optimizeStructure() }
		out += ["", "# a model using the part at x=100, colour 4, optimised"]
		out += Tex.body(Tex.text(file)).components(separatedBy: "\n").filter { !$0.isEmpty }
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "texture-helpers/library-part.txt")
	}

	@Test("Marquee over a part whose library model has a texture: the texture credits the part")
	func boxTestCreditsPart() throws {
		let library = try #require(FixtureLibrary.current)
		let part = "0 Tex part\n0 Name: texbox.dat\n0 Author: Fixture Author\n\(Tex.start)\n0 !: \(Tex.triA)\n0 !TEXMAP END\n"
		try Data(part.utf8).write(to: library.appendingPathComponent("parts/texbox.dat"))
		let file = try Tex.load("1 4 0 0 0 1 0 0 0 1 0 0 0 1 texbox.dat")
		let step = try DrawHarness.stepSync(file)
		let partRef = try #require(Tex.children(step).first as? LDrawPart)
		let hits = NSMutableSet()
		var any = false
		let all = Box2(origin: Point2(x: -100, y: -100), size: Size2(width: 200, height: 200))
		try ObjC.run { any = file.boxTest(all, transform: IdentityMatrix4, boundsOnly: false, creditObject: nil, hits: hits) }
		let picked = hits.allObjects.map { ($0 as! NSValue).pointerValue == Unmanaged.passUnretained(partRef).toOpaque() }
		#expect(picked == [true], "hits: \(hits)")
		#expect(any == false, "a top-level marquee test keeps looking (creditObject nil)")
	}

	@Test("Selecting a texture creates three handles; deselecting removes them; handles are picked")
	func selectionHandles() throws {
		let file = try Tex.load([Tex.start, "0 !: \(Tex.triA)", "0 !TEXMAP END"].joined(separator: "\n"))
		let texture = try #require(Tex.firstTexture(file))
		// Front view scaled 1/100: plane point 1 (-10, 0, -10) lands at clip (-0.1, 0).
		let transform = HitLayout.transform
		func pick() throws -> String {
			var best: AnyObject? = nil
			var depth: Float = 1
			try ObjC.run {
				file.depthTest(Point2(x: -0.1, y: 0), inBox: Box2(origin: Point2(x: -0.11, y: -0.01), size: Size2(width: 0.02, height: 0.02)),
							   transform: transform, creditObject: nil, bestObject: &best, bestDepth: &depth)
			}
			guard let best else { return "nothing" }
			if let handle = best as? LDrawDragHandle { return "handle \(handle.tag())" }
			return "\(type(of: best))"
		}
		let unselected = try pick()
		try ObjC.run { texture.setSelected(true) }
		let selected = try pick()
		try ObjC.run { texture.setSelected(false) }
		let deselected = try pick()
		let out = "unselected: \(unselected)\nselected: \(selected)\ndeselected: \(deselected)\n"
		try Golden.check(Data(out.utf8), against: "texture-helpers/selection.txt")
	}

	@Test("A texture and the geometry it parsed are freed when the texture is released")
	func textureIsFreed() throws {
		// The texture is built directly, as LDrawStep builds it: parsed files themselves are not freed in tests
		// (their models outlive the file; outside this suite's scope), so the probe starts below the step.
		weak var weakTexture: LDrawTexture?
		weak var weakChild: LDrawDirective?
		try autoreleasepool {
			let lines = [Tex.start, "0 !: \(Tex.triA)", "0 !TEXMAP END"]
			let texture = try #require(try ObjC.run { LDrawTexture(lines: lines, in: NSRange(location: 0, length: 3), parentGroup: nil) })
			#expect(Tex.children(texture).count == 1)
			weakTexture = texture
			weakChild = Tex.children(texture).first as? LDrawDirective
		}
		#expect(weakTexture == nil, "the texture leaked")
		// BUG-025 (fixed by the P3 ARC conversion): the children used to leak under MRC.
		#expect(weakChild == nil, "the texture's child leaked")
	}
}

extension Tex {
	static func children(_ container: LDrawContainer) -> [Any] { (container.subdirectives() as? [Any]) ?? [] }

	static func firstTexture(_ file: LDrawFile) -> LDrawTexture? {
		for step in file.activeModel().steps() {
			if let texture = (step as! LDrawStep).subdirectives().first(where: { $0 is LDrawTexture }) as? LDrawTexture {
				return texture
			}
		}
		return nil
	}
}

// MARK: - StringUtilities

@Suite("StringUtilities: next copy name (P2 exit)")
struct StringUtilitiesTests {
	static let names = ["foo", "foo copy", "foo copy 3", "foo copy 1", "foo copy 0", "foo copy -2", "foo copy x",
						"foo copy 2 3", "foo copy ", "foo Copy", "copy", "copyright", "foo copy.txt", "foo.txt", ""]
	static let paths = ["foo", "foo.ldr", "foo copy.ldr", "foo copy 3.ldr", "sub model.mpd.ldr", "dir/foo.dat",
						"/abs/dir/foo copy 9.ldr", ".hidden", "foo.", "a copy b.ldr", ""]

	@Test("nextCopyNameForString: and nextCopyPathForFilePath: over a table of names")
	func copyNames() throws {
		let suffix = Bundle.main.localizedString(forKey: "CopySuffix", value: nil, table: nil)
		var out = ["# CopySuffix = \"\(suffix)\"", "", "# nextCopyNameForString:"]
		for name in Self.names {
			out.append("\"\(name)\" -> \"\(StringUtilities.nextCopyName(for: name) ?? "nil")\"")
		}
		out += ["", "# nextCopyPathForFilePath:"]
		for path in Self.paths {
			out.append("\"\(path)\" -> \"\(StringUtilities.nextCopyPath(forFilePath: path) ?? "nil")\"")
		}
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "texture-helpers/copy-names.txt")
	}

	@Test("Repeated copies count up, as -addModel:...preventNameCollisions: does")
	func copySequence() {
		var name = "main.ldr"
		var seen: [String] = []
		for _ in 0..<4 {
			name = StringUtilities.nextCopyPath(forFilePath: name)
			seen.append(name)
		}
		#expect(seen == ["main copy.ldr", "main copy 2.ldr", "main copy 3.ldr", "main copy 4.ldr"])
	}
}

// MARK: - AppKit categories

@MainActor
@Suite("AppKit categories: bezier path, table, window, overlay (P2 exit)", .serialized)
struct AppKitCategoryTests {
	@Test("bezierPathWithRect:radiusPercentage: path elements")
	func roundRect() throws {
		let cases: [(NSRect, CGFloat)] = [
			(NSRect(x: 0, y: 0, width: 100, height: 50), 50),
			(NSRect(x: 10, y: 20, width: 100, height: 50), 0),
			(NSRect(x: 0, y: 0, width: 100, height: 100), 100),
			(NSRect(x: 0, y: 0, width: 20, height: 200), 50),   // the radius uses only the width
			(NSRect(x: 0, y: 0, width: 36, height: 36), 50),    // as -dragImageWithOffset: (brick image + border)
		]
		var out: [String] = []
		for (rect, percent) in cases {
			let path = try #require(NSBezierPath(rect: rect, radiusPercentage: percent))
			out.append("## rect \(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height) radius \(percent)%")
			var points = [NSPoint](repeating: .zero, count: 3)
			for index in 0..<path.elementCount {
				let kind = path.element(at: index, associatedPoints: &points)
				let count: Int
				let label: String
				switch kind {
				case .moveTo: label = "move"; count = 1
				case .lineTo: label = "line"; count = 1
				case .curveTo, .cubicCurveTo: label = "curve"; count = 3
				case .quadraticCurveTo: label = "quad"; count = 2
				case .closePath: label = "close"; count = 0
				@unknown default: label = "?"; count = 0
				}
				let text = points.prefix(count).map { String(format: "(%.3f, %.3f)", $0.x, $0.y) }.joined(separator: " ")
				out.append("\(label) \(text)".trimmingCharacters(in: .whitespaces))
			}
			let b = path.bounds
			out.append(String(format: "bounds (%.3f, %.3f) %.3f x %.3f", b.origin.x, b.origin.y, b.width, b.height))
		}
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "texture-helpers/bezier.txt")
	}

	final class Rows: NSObject, NSTableViewDataSource {
		func numberOfRows(in tableView: NSTableView) -> Int { 100 }
		func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? { "\(row)" }
	}

	@Test("scrollRowToCenter: puts the row in the middle of the visible area, clamped at the top")
	func scrollRowToCenter() throws {
		let rows = Rows()
		let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 170))
		let table = NSTableView(frame: scroll.bounds)
		table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c")))
		table.rowHeight = 17
		table.intercellSpacing = NSSize(width: 0, height: 0)
		table.headerView = nil
		table.style = .plain   // no inset padding: row geometry does not depend on the OS default style
		table.dataSource = rows
		scroll.documentView = table
		table.reloadData()
		var out: [String] = []
		for row in [50, 0, 3, 99, -1] {
			table.scrollRow(toCenter: row)
			let visible = scroll.documentVisibleRect
			let rowRect = table.rect(ofRow: row)
			out.append(String(format: "row %d: row y %.1f h %.1f; visible y %.1f h %.1f; row centre offset %.1f",
							  row, rowRect.minY, rowRect.height, visible.minY, visible.height,
							  rowRect.midY - visible.midY))
		}
		withExtendedLifetime(rows) {}
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "texture-helpers/scroll-row.txt")
	}

	static func makeWindow() -> NSWindow {
		let window = NSWindow(contentRect: NSRect(x: 200, y: 300, width: 400, height: 300),
							  styleMask: [.titled, .resizable], backing: .buffered, defer: true)
		window.isReleasedWhenClosed = false
		return window
	}

	@Test("frameRectForContentSize: keeps the top edge and adds the window chrome")
	func frameRectForContentSize() {
		let window = Self.makeWindow()
		defer { window.close() }
		let frame = window.frame
		for size in [NSSize(width: 500, height: 200), NSSize(width: 300, height: 450), NSSize(width: 400, height: 300)] {
			let result = window.frameRect(forContentSize: size)
			let expectedSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: size)).size
			#expect(result.size == expectedSize, "\(size): \(result) vs \(expectedSize)")
			#expect(result.maxY == frame.maxY, "top edge moved: \(result) from \(frame)")
			#expect(result.minX == frame.minX)
		}
	}

	@Test("resizeToSize:animate: sets the frame size and keeps the top-left corner")
	func resizeToSize() {
		let window = Self.makeWindow()
		defer { window.close() }
		let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
		window.resize(to: NSSize(width: 640, height: 480), animate: false)
		#expect(window.frame.size == NSSize(width: 640, height: 480), "\(window.frame)")
		#expect(NSPoint(x: window.frame.minX, y: window.frame.maxY) == topLeft, "\(window.frame)")
	}

	@Test("addOverlayView: attaches the overlay in a child window over the view")
	func addOverlay() throws {
		// A real, on-screen (fully transparent) parent window with fixed geometry, as DocHarness does (L58).
		let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
							  styleMask: [.borderless], backing: .buffered, defer: false)
		window.isReleasedWhenClosed = false
		window.alphaValue = 0
		let host = NSView(frame: NSRect(x: 20, y: 30, width: 200, height: 100))
		window.contentView?.addSubview(host)
		window.orderFront(nil)
		defer { window.orderOut(nil); window.close() }

		let overlay = NSView(frame: .zero)
		let before = host.subviews.count
		try ObjC.run { _ = host.perform(NSSelectorFromString("addOverlayView:"), with: overlay) }
		RunLoop.main.run(until: Date().addingTimeInterval(0.2))

		#expect(host.subviews.count == before + 1)
		let helperView = try #require(host.subviews.last)
		#expect(String(describing: type(of: helperView)) == "OverlayHelperView")
		let child = try #require(window.childWindows?.first, "no overlay child window")
		#expect(child.contentView === overlay)
		let expected = window.convertToScreen(host.convert(host.visibleRect, to: nil))
		#expect(child.frame == expected, "overlay frame \(child.frame), view on screen \(expected)")

		// Detach the way a view leaving its window does (removeOverlayView: has no callers).
		helperView.removeFromSuperview()
		RunLoop.main.run(until: Date().addingTimeInterval(0.1))
		#expect(window.childWindows?.isEmpty ?? true, "overlay window still attached")
		child.orderOut(nil)
	}

	// MARK: P5 pins (before the categories move to Swift)

	@Test("frameRectForContentSize: is the frame plus the content-size difference, growing downwards")
	func frameRectArithmetic() {
		let window = Self.makeWindow()
		defer { window.close() }
		let frame = window.frame
		let content = window.contentView!.frame.size
		for size in [NSSize(width: 10, height: 10), NSSize(width: 1000, height: 20), NSSize(width: 0, height: 0)] {
			let result = window.frameRect(forContentSize: size)
			let expected = NSRect(x: frame.minX, y: frame.minY - (size.height - content.height),
								  width: frame.width + size.width - content.width,
								  height: frame.height + size.height - content.height)
			#expect(result == expected, "\(size): \(result) vs \(expected)")
		}
		#expect(window.frame == frame, "frameRectForContentSize: must not move the window")
	}

	@Test("resizeToSize:animate:YES ends at the same frame as animate:NO")
	func resizeAnimated() {
		let window = Self.makeWindow()
		defer { window.close() }
		let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
		window.resize(to: NSSize(width: 420, height: 330), animate: true)
		#expect(window.frame == NSRect(x: topLeft.x, y: topLeft.y - 330, width: 420, height: 330), "\(window.frame)")
	}

	@Test("scrollRowToCenter: on a table outside a scroll view does nothing and does not raise")
	func scrollRowToCenterWithoutScrollView() throws {
		let rows = Rows()
		let table = NSTableView(frame: NSRect(x: 0, y: 0, width: 200, height: 1700))
		table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c")))
		table.rowHeight = 17
		table.intercellSpacing = NSSize(width: 0, height: 0)
		table.style = .plain
		table.dataSource = rows
		table.reloadData()
		let before = table.visibleRect
		try ObjC.run { table.scrollRow(toCenter: 50) }
		#expect(table.visibleRect == before)
		withExtendedLifetime(rows) {}
	}

	@Test("The four overlay hooks are declared but not implemented: a plain NSView does not respond to them")
	func overlayHooksUnimplemented() {
		for name in ["viewWillBecomeOverlay", "viewDidBecomeOverlay", "viewWillResignOverlay", "viewDidResignOverlay"] {
			#expect(!NSView().responds(to: NSSelectorFromString(name)), "\(name)")
			#expect(!NSView.instancesRespond(to: NSSelectorFromString(name)), "\(name)")
		}
	}

	/// Counts setNeedsDisplay:YES (AppKit may clear needsDisplay again before a test can read it).
	final class DirtyRecordingView: NSView {
		var markedDirty = 0
		override var needsDisplay: Bool {
			get { super.needsDisplay }
			set { if newValue { markedDirty += 1 }; super.needsDisplay = newValue }
		}
	}

	@Test("removeOverlayView: removes only the helper that manages the given overlay, and marks the view dirty")
	func removeOverlay() throws {
		let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
							  styleMask: [.borderless], backing: .buffered, defer: false)
		window.isReleasedWhenClosed = false
		window.alphaValue = 0
		let host = DirtyRecordingView(frame: NSRect(x: 20, y: 30, width: 200, height: 100))
		window.contentView?.addSubview(host)
		let plain = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
		host.addSubview(plain)
		window.orderFront(nil)
		defer { window.orderOut(nil); window.close() }

		let first = NSView(frame: .zero)
		let second = NSView(frame: .zero)
		try ObjC.run {
			_ = host.perform(NSSelectorFromString("addOverlayView:"), with: first)
			_ = host.perform(NSSelectorFromString("addOverlayView:"), with: second)
		}
		RunLoop.main.run(until: Date().addingTimeInterval(0.2))
		#expect(host.subviews.count == 3)
		let helpers = host.subviews.filter { String(describing: type(of: $0)) == "OverlayHelperView" }
		#expect(helpers.count == 2)

		// An overlay that isn't attached: nothing is removed, but the view is still marked dirty.
		host.markedDirty = 0
		try ObjC.run { _ = host.perform(NSSelectorFromString("removeOverlayView:"), with: NSView(frame: .zero)) }
		#expect(host.subviews.count == 3)
		#expect(host.markedDirty == 1)

		host.markedDirty = 0
		try ObjC.run { _ = host.perform(NSSelectorFromString("removeOverlayView:"), with: first) }
		#expect(host.subviews.count == 2)
		#expect(host.subviews.first === plain, "the plain subview must stay")
		let remaining = host.subviews.filter { String(describing: type(of: $0)) == "OverlayHelperView" }
		#expect(remaining.count == 1)
		#expect((remaining.first?.value(forKey: "overlayView") as AnyObject?) === second)
		#expect(host.markedDirty == 1)

		try ObjC.run { _ = host.perform(NSSelectorFromString("removeOverlayView:"), with: second) }
		RunLoop.main.run(until: Date().addingTimeInterval(0.1))
		#expect(host.subviews == [plain])
		#expect(window.childWindows?.isEmpty ?? true, "overlay windows still attached")
	}
}
