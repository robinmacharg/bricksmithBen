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

	/// A file whose last line is a texture START (BUG-P6B-meta-13).
	nonisolated static let startAsLastLine = "0 Texture case\n0 Name: texcase.ldr\n0 Author: Fixture Author\n"
		+ "3 16 -10 0 -10 10 0 -10 10 0 10\n0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 sticker.png\n"

	@Test("BUG-P6B-meta-13: a file whose last line is a !TEXMAP START crashes the parse (zero-length texture range)")
	func bug_p6b_meta_13_startAsLastLineCrashes() async {
		// Pins today's crash: LDrawStep's parse loop doesn't advance past the zero-length range and overruns its
		// buffer. The alarm turns a hang into SIGALRM, which this would also count as a failure.
		await #expect(processExitsWith: .failure) {
			alarm(3)
			_ = LDrawFile.parse(fromFileContents: TextureCoverageTests.startAsLastLine)
			exit(EXIT_SUCCESS)
		}
	}

	@Test("A texture and the geometry it parsed are freed when the texture is released")
	func textureIsFreed() throws {
		// The texture is built directly, as LDrawStep builds it: parsed files themselves are not freed in tests
		// (their models outlive the file; outside this suite's scope), so the probe starts below the step.
		weak var weakTexture: LDrawTexture?
		weak var weakChild: LDrawDirective?
		try autoreleasepool {
			let lines = [Tex.start, "0 !: \(Tex.triA)", "0 !TEXMAP END"]
			let texture = try #require(try ObjC.run { LDrawTexture(lines: ldrawLines(lines), in: NSRange(location: 0, length: 3), parentGroup: nil) })
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

// MARK: - LDrawMetaCommand (P6b pre-port)

enum Meta {
	/// One line through +[LDrawMetaCommand directiveWithLines:inRange:parentGroup:].
	static func make(_ line: String) -> LDrawDirective? {
		LDrawMetaCommand.directive(lines: ldrawLines([line]), in: NSRange(location: 0, length: 1), parentGroup: nil)
	}

	/// Class, stringValue and written form, with every non-ASCII scalar escaped.
	static func describe(_ directive: LDrawDirective?) -> String {
		guard let directive else { return "nil" }
		let value = (directive as? LDrawMetaCommand)?.stringValue()
		return "\(type(of: directive)) value=[\(value.map(escape) ?? "nil")] write=[\(escape(directive.write() ?? "nil"))]"
	}

	static func escape(_ s: String) -> String {
		s.unicodeScalars.map { $0.isASCII && $0.value >= 0x20 ? String($0) : String(format: "\\u{%X}", $0.value) }.joined()
	}
}

@MainActor
@Suite("LDrawMetaCommand: meta-command dispatch, stored string, archiving (P6b pre-port)", .fixtureLibrary, .serialized)
struct MetaCommandTests {

	@Test("Dispatch of 0 lines: subclass, stored string (UTF-16 positions next to non-ASCII), written form")
	func dispatch() throws {
		// Combining marks, ZWJ, an astral emoji and a no-break space next to the line code and the command word:
		// NSScanner works in UTF-16 units here (L101).
		let lines = [
			"0 // comment", "0 //comment", "0 WRITE text", "0 PRINT text", "0 // ", "0 //",
			"0 !COLOUR Red CODE 4 VALUE #C91A09 EDGE #333333", "0 !COLOUR",
			"0", "0 ", "0   ", "", "   ", "\t", "0 UNKNOWN  two  spaces ", "\t0\tTAB\tSEP", "  0 LEADING",
			"00 DOUBLE ZERO", "+0 PLUS", "-0 MINUS", "0x1 HEX", "0FOO", "0.5 FRACTION", "abc def",
			"0 \u{301}FOO", "0\u{301} FOO", "0 FOO\u{301} bar", "0 //\u{200D}x", "0 // \u{301}x", "0\u{A0}NBSP x",
			"0 \u{1F600} emoji", "0 \u{1F600}// emoji", "0 é decomposed", "\u{301}0 FOO",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png", "0 SYNTH BEGIN RUBBER_BAND 4", "0 STEP",
			"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "2 24 0 0 0 1 1 1", "9 nine",
		]
		var out: [String] = []
		for line in lines {
			out.append("\(Meta.escape(line)) -> \(Meta.describe(try ObjC.run { Meta.make(line) }))")
		}
		let actual = out.joined(separator: "\n")
		#expect(actual == Self.expectedDispatch, "\(actual)")
	}

	static let expectedDispatch = #"""
		0 // comment -> LDrawComment value=[comment] write=[0 // comment]
		0 //comment -> LDrawMetaCommand value=[//comment] write=[0 //comment]
		0 WRITE text -> LDrawComment value=[text] write=[0 // text]
		0 PRINT text -> LDrawComment value=[text] write=[0 // text]
		0 //  -> LDrawComment value=[] write=[0 // ]
		0 // -> LDrawComment value=[] write=[0 // ]
		0 !COLOUR Red CODE 4 VALUE #C91A09 EDGE #333333 -> LDrawColor value=[] write=[0 !COLOUR Red CODE 4 VALUE #C91A09 EDGE #333333]
		0 !COLOUR -> LDrawColor value=[] write=[0 !COLOUR (null) CODE -1 VALUE #000000 EDGE #000000]
		0 -> LDrawMetaCommand value=[] write=[0 ]
		0  -> LDrawMetaCommand value=[] write=[0 ]
		0    -> LDrawMetaCommand value=[] write=[0 ]
		 -> LDrawMetaCommand value=[] write=[0 ]
		    -> LDrawMetaCommand value=[   ] write=[0    ]
		\u{9} -> LDrawMetaCommand value=[\u{9}] write=[0 \u{9}]
		0 UNKNOWN  two  spaces  -> LDrawMetaCommand value=[UNKNOWN  two  spaces ] write=[0 UNKNOWN  two  spaces ]
		\u{9}0\u{9}TAB\u{9}SEP -> LDrawMetaCommand value=[TAB\u{9}SEP] write=[0 TAB\u{9}SEP]
		  0 LEADING -> LDrawMetaCommand value=[LEADING] write=[0 LEADING]
		00 DOUBLE ZERO -> LDrawMetaCommand value=[DOUBLE ZERO] write=[0 DOUBLE ZERO]
		+0 PLUS -> LDrawMetaCommand value=[PLUS] write=[0 PLUS]
		-0 MINUS -> LDrawMetaCommand value=[MINUS] write=[0 MINUS]
		0x1 HEX -> LDrawMetaCommand value=[x1 HEX] write=[0 x1 HEX]
		0FOO -> LDrawMetaCommand value=[FOO] write=[0 FOO]
		0.5 FRACTION -> LDrawMetaCommand value=[.5 FRACTION] write=[0 .5 FRACTION]
		abc def -> LDrawMetaCommand value=[abc def] write=[0 abc def]
		0 \u{301}FOO -> LDrawMetaCommand value=[\u{301}FOO] write=[0 \u{301}FOO]
		0\u{301} FOO -> LDrawMetaCommand value=[\u{301} FOO] write=[0 \u{301} FOO]
		0 FOO\u{301} bar -> LDrawMetaCommand value=[FOO\u{301} bar] write=[0 FOO\u{301} bar]
		0 //\u{200D}x -> LDrawMetaCommand value=[//\u{200D}x] write=[0 //\u{200D}x]
		0 // \u{301}x -> LDrawComment value=[\u{301}x] write=[0 // \u{301}x]
		0\u{A0}NBSP x -> LDrawMetaCommand value=[NBSP x] write=[0 NBSP x]
		0 \u{1F600} emoji -> LDrawMetaCommand value=[\u{1F600} emoji] write=[0 \u{1F600} emoji]
		0 \u{1F600}// emoji -> LDrawMetaCommand value=[\u{1F600}// emoji] write=[0 \u{1F600}// emoji]
		0 \u{E9} decomposed -> LDrawMetaCommand value=[\u{E9} decomposed] write=[0 \u{E9} decomposed]
		\u{301}0 FOO -> LDrawMetaCommand value=[\u{301}0 FOO] write=[0 \u{301}0 FOO]
		0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png -> LDrawMetaCommand value=[!TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png] write=[0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png]
		0 SYNTH BEGIN RUBBER_BAND 4 -> LDrawMetaCommand value=[SYNTH BEGIN RUBBER_BAND 4] write=[0 SYNTH BEGIN RUBBER_BAND 4]
		0 STEP -> LDrawMetaCommand value=[STEP] write=[0 STEP]
		1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat -> nil
		2 24 0 0 0 1 1 1 -> nil
		9 nine -> nil
		"""#

	@Test("The range picks the line; a subclass receiver still makes generic commands of its own class")
	func rangeAndReceiver() throws {
		let lines = ["0 FIRST", "0 SECOND", "0 // third"]
		let second = LDrawMetaCommand.directive(lines: ldrawLines(lines), in: NSRange(location: 1, length: 1), parentGroup: nil)
		#expect(Meta.describe(second) == "LDrawMetaCommand value=[SECOND] write=[0 SECOND]")
		let third = LDrawMetaCommand.directive(lines: ldrawLines(lines), in: NSRange(location: 2, length: 1), parentGroup: nil)
		#expect(Meta.describe(third) == "LDrawComment value=[third] write=[0 // third]")
		// +directiveWithLines: allocates [self alloc] for an unrecognised command.
		let viaComment = LDrawComment.directive(lines: ldrawLines(["0 NOT A COMMENT"]), in: NSRange(location: 0, length: 1), parentGroup: nil)
		#expect(Meta.describe(viaComment) == "LDrawComment value=[NOT A COMMENT] write=[0 // NOT A COMMENT]")
	}

	@Test("A new meta command: empty string, display, inspector; a nil string; finishParsing: fails")
	func basics() throws {
		let command = LDrawMetaCommand()
		#expect(command.stringValue() == "")
		#expect(command.write() == "0 ")
		#expect(command.browsingDescription() == "")
		#expect(command.iconName() == "Unknown")
		#expect(command.inspectorClassName() == "InspectionUnknownCommand")
		#expect(command.finishParsing(Scanner(string: "anything")) == false)
		command.setStringValue(nil)
		#expect(command.stringValue() == nil)
		#expect(command.write() == "0 (null)")
		#expect(command.browsingDescription() == nil)
		// Drawing does nothing (and doesn't need GL).
		command.draw(0, viewScale: 1, parentColor: nil)
		// The other init paths keep the empty string; no lines gives nil.
		#expect((LDrawMetaCommand(lines: ldrawLines(["0 IGNORED"]), in: NSRange(location: 0, length: 1)) as LDrawMetaCommand?)?.stringValue() == "")
		#expect((LDrawMetaCommand(lines: ldrawLines(["0 IGNORED"]), in: NSRange(location: 0, length: 1), parentGroup: nil) as LDrawMetaCommand?)?.stringValue() == "")
		#expect((LDrawMetaCommand(lines: [], in: NSRange(location: 0, length: 0), parentGroup: nil) as LDrawMetaCommand?) == nil)
	}

	@Test("copy and keyed archiving keep the command string (also nil and non-ASCII)")
	func copyAndArchive() throws {
		for value in ["UNKNOWN meta", "", "\u{1F600} e\u{301}", nil] as [String?] {
			let command = LDrawMetaCommand()
			command.setStringValue(value)
			command.setSelected(true)
			let copied = try #require(command.copy() as? LDrawMetaCommand)
			#expect(type(of: copied) == LDrawMetaCommand.self)
			#expect(copied.stringValue() == value)
			#expect(copied.isSelected())
			let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(command)) as? LDrawMetaCommand)
			#expect(type(of: decoded) == LDrawMetaCommand.self)
			#expect(decoded.stringValue() == value)
			#expect(decoded.write() == command.write())
		}
	}

	@Test("Undo of a string change restores the old string through -setStringValue:")
	func undo() throws {
		let command = try #require(Meta.make("0 BEFORE") as? LDrawMetaCommand)
		let undo = UndoManager()
		undo.groupsByEvent = false
		undo.beginUndoGrouping()
		try ObjC.run { command.registerUndoActions(undo) }
		command.setStringValue("AFTER")
		undo.endUndoGrouping()
		try ObjC.run { undo.undo() }
		#expect(command.stringValue() == "BEFORE")
		// -setStringValue: registers no undo itself, so there is nothing to redo.
		#expect(!undo.canRedo)
	}
}

// MARK: - LDrawTexture (P6b pre-port)

/// Records the texture spec pushed by -drawSelf:/-collectSelf: bit for bit.
final class TextureSpecRecorder: NSObject, LDrawRenderer, LDrawCollector {
	var log: [String] = []
	var tag: GLuint = 7

	static func bits(_ tuple: (GLfloat, GLfloat, GLfloat, GLfloat)) -> String {
		[tuple.0, tuple.1, tuple.2, tuple.3].map { String(format: "%08X", $0.bitPattern) }.joined(separator: " ")
	}

	func pushMatrix(_ matrix: UnsafeMutablePointer<GLfloat>!) {}
	func popMatrix() {}
	func checkCull(_ minXYZ: UnsafeMutablePointer<GLfloat>!, to maxXYZ: UnsafeMutablePointer<GLfloat>!) -> Int32 { Int32(cull_draw) }
	func drawBox(from minXyz: UnsafeMutablePointer<GLfloat>!, to maxXyz: UnsafeMutablePointer<GLfloat>!) {}
	func pushColor(_ color: UnsafeMutablePointer<GLfloat>!) {}
	func popColor() {}
	func pushWireFrame() {}
	func popWireFrame() {}
	func pushTexture(_ tex_spec: UnsafeMutablePointer<LDrawTextureSpec>!) {
		let s = tex_spec.pointee
		log.append("push projection=\(s.projection) tex=\(s.tex_obj) s=[\(Self.bits(s.plane_s))] t=[\(Self.bits(s.plane_t))]")
	}
	func popTexture() { log.append("pop") }
	func drawDragHandle(_ xyz: UnsafeMutablePointer<GLfloat>!, withSize size: GLfloat) {}
	func beginDL() -> (any LDrawCollector)! { self }
	func endDL(_ outHandle: UnsafeMutablePointer<LDrawDLHandle?>!, cleanupFunc: UnsafeMutablePointer<LDrawDLCleanup_f?>!) {
		outHandle.pointee = nil
		cleanupFunc.pointee = { _ in }
	}
	func drawDL(_ dl: LDrawDLHandle!) {}
	func textureTag(for texture: LDrawTexture!) -> GLuint { log.append("textureTag"); return tag }
	func drawQuad(_ vertices: UnsafeMutablePointer<GLfloat>!, normal: UnsafeMutablePointer<GLfloat>!, color: UnsafeMutablePointer<GLfloat>!) { log.append("quad") }
	func drawTri(_ vertices: UnsafeMutablePointer<GLfloat>!, normal: UnsafeMutablePointer<GLfloat>!, color: UnsafeMutablePointer<GLfloat>!) { log.append("tri") }
	func drawLine(_ vertices: UnsafeMutablePointer<GLfloat>!, normal: UnsafeMutablePointer<GLfloat>!, color: UnsafeMutablePointer<GLfloat>!) { log.append("line") }
}

@MainActor
@Suite("LDrawTexture: archiving, copying, plane points, spec, containers (P6b pre-port)", .fixtureLibrary, .serialized)
struct TexturePortTests {
	init() throws { try OffscreenGL.makeCurrent() }

	static let full = [
		"0 !TEXMAP START PLANAR -10.5 0.25 -10 10 0 -10.125 -10 3.5 10 \"My Sticker.PNG\" GLOSSMAP \"gl oss.png\"",
		"0 !: 3 16 -10 0 -10 10 0 -10 10 0 10",
		"4 16 0 0 0 10 0 0 10 0 10 0 0 10",
		"0 !TEXMAP FALLBACK",
		"3 16 -10 0 -10 10 0 10 -10 0 10",
		"0 // fallback comment",
		"0 !TEXMAP END",
	]

	static func texture(_ lines: [String] = full) throws -> LDrawTexture {
		try #require(try ObjC.run { LDrawTexture(lines: ldrawLines(lines), in: NSRange(location: 0, length: lines.count), parentGroup: nil) })
	}

	@Test("A new texture: zero plane points and bounds, nil names, written form")
	func fresh() throws {
		let texture = LDrawTexture()
		let box = texture.boundingBox3()
		#expect([box.min.x, box.min.y, box.min.z, box.max.x, box.max.y, box.max.z] == [0, 0, 0, 0, 0, 0])
		#expect(texture.imageDisplayName() == nil && texture.imageReferenceName() == nil && texture.glossmapName() == nil)
		#expect(texture.browsingDescription() == nil)
		#expect(texture.iconName() == "Texture")
		#expect(Prim.write(texture) == "0 !TEXMAP START PLANAR 0 0 0 0 0 0 0 0 0 (null)\n0 !TEXMAP END")
		texture.setImageDisplayName("Ab C.PNG")
		#expect(texture.imageDisplayName() == "Ab C.PNG" && texture.imageReferenceName() == "ab c.png")
		texture.setImageDisplayName(nil)
		#expect(texture.imageDisplayName() == nil && texture.imageReferenceName() == nil)
	}

	@Test("Parsed directly: children, fallback, names; write; keyed archive and copy write the same")
	func archiveAndCopy() throws {
		let texture = try Self.texture()
		let written = Prim.write(texture)
		#expect(written == Self.expectedFull, "\(written)")
		#expect(texture.imageDisplayName() == "My Sticker.PNG")
		#expect(texture.imageReferenceName() == "my sticker.png")
		#expect(texture.glossmapName() == "gl oss.png")
		#expect(texture.subdirectives().count == 2)

		let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(texture)) as? LDrawTexture)
		#expect(Prim.write(decoded) == written)
		#expect(decoded.imageReferenceName() == "my sticker.png")
		let copied = try #require(texture.copy() as? LDrawTexture)
		#expect(copied.imageDisplayName() == "My Sticker.PNG" && copied.glossmapName() == "gl oss.png")
		// LDrawContainer's copy inserts every copied child at index 0.
		#expect(Prim.write(copied) == Self.expectedCopy, "\(Prim.write(copied))")
		#expect(copied.boundingBox3().max.x == texture.boundingBox3().max.x)
	}

	static let expectedFull = #"""
		0 !TEXMAP START PLANAR -10.5 0.25 -10 10 0 -10.125 -10 3.5 10 My Sticker.PNG GLOSSMAP gl oss.png
		0 !: 3 16 -10 0 -10 10 0 -10 10 0 10
		0 !: 4 16 0 0 0 10 0 0 10 0 10 0 0 10
		0 !TEXMAP FALLBACK
		3 16 -10 0 -10 10 0 10 -10 0 10
		0 // fallback comment
		0 !TEXMAP END
		"""#
	static let expectedCopy = #"""
		0 !TEXMAP START PLANAR -10.5 0.25 -10 10 0 -10.125 -10 3.5 10 My Sticker.PNG GLOSSMAP gl oss.png
		0 !: 4 16 0 0 0 10 0 0 10 0 10 0 0 10
		0 !: 3 16 -10 0 -10 10 0 -10 10 0 10
		0 !TEXMAP FALLBACK
		3 16 -10 0 -10 10 0 10 -10 0 10
		0 // fallback comment
		0 !TEXMAP END
		"""#

	@Test("drawSelf: and collectSelf: push the planar spec computed from the plane points, then pop")
	func spec() throws {
		let texture = try Self.texture()
		let drawn = TextureSpecRecorder()
		try ObjC.run { texture.drawSelf(drawn) }
		let collected = TextureSpecRecorder()
		collected.tag = 9
		try ObjC.run { texture.collectSelf(collected) }
		// The tag is asked for once, then cached in the texture.
		try ObjC.run { texture.collectSelf(collected) }
		let actual = (["draw:"] + drawn.log + ["collect:"] + collected.log).joined(separator: "\n")
		#expect(actual == Self.expectedSpec, "\(actual)")
	}

	static let expectedSpec = #"""
		draw:
		textureTag
		push projection=0 tex=7 s=[3D47C48B BA1BEA91 B99BEA91 3F025FD4] t=[3A9F871B 3C019DC6 3D4768E2 3EFECAEA]
		pop
		collect:
		push projection=0 tex=7 s=[3D47C48B BA1BEA91 B99BEA91 3F025FD4] t=[3A9F871B 3C019DC6 3D4768E2 3EFECAEA]
		tri
		quad
		pop
		push projection=0 tex=7 s=[3D47C48B BA1BEA91 B99BEA91 3F025FD4] t=[3A9F871B 3C019DC6 3D4768E2 3EFECAEA]
		tri
		quad
		pop
		"""#

	@Test("Drag handles move the plane points; setSelected: makes and drops them")
	func dragHandles() throws {
		let texture = try Self.texture()
		for (tag, point) in [(1, V3Make(1, 2, 3)), (2, V3Make(4, 5, 6)), (3, V3Make(7, 8, 9)), (4, V3Make(100, 100, 100))] {
			let handle = try #require(LDrawDragHandle(tag: tag, position: point))
			try ObjC.run { _ = texture.perform(NSSelectorFromString("dragHandleChanged:"), with: handle) }
		}
		#expect(Prim.write(texture).hasPrefix("0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 My Sticker.PNG GLOSSMAP gl oss.png\n"),
				"\(Prim.write(texture))")
		try ObjC.run { texture.setSelected(true) }
		#expect(texture.isSelected())
		let handle = try #require(LDrawDragHandle(tag: 2, position: V3Make(-1, -2, -3)))
		try ObjC.run { _ = texture.perform(NSSelectorFromString("dragHandleChanged:"), with: handle) }
		#expect(Prim.write(texture).hasPrefix("0 !TEXMAP START PLANAR 1 2 3 -1 -2 -3 7 8 9 "), "\(Prim.write(texture))")
		try ObjC.run { texture.setSelected(false) }
		#expect(!texture.isSelected())
	}

	@Test("Insert and remove keep the bounds current; flatten (non-recursive) moves only the plane points")
	func containerEditing() throws {
		let texture = try Self.texture()
		let before = texture.boundingBox3()
		let far = try Prim.parse("3 16 100 0 0 110 0 0 100 10 0")
		try ObjC.run { texture.insert(far, at: 0) }
		#expect(texture.boundingBox3().max.x == 110, "bounds after insert: \(texture.boundingBox3())")
		#expect((far.enclosingDirective() as AnyObject?) === texture)
		try ObjC.run { texture.removeDirective(at: 0) }
		#expect(texture.boundingBox3().max.x == before.max.x)
		#expect(far.enclosingDirective() == nil)

		let lines = NSMutableArray(), tris = NSMutableArray(), quads = NSMutableArray(), other = NSMutableArray()
		var move = IdentityMatrix4
		move.element.3 = (5, 0, 0, 1)
		try ObjC.run {
			texture.flatten(intoLines: lines, triangles: tris, quadrilaterals: quads, other: other, currentColor: nil,
							currentTransform: move, normalTransform: IdentityMatrix3, recursive: false)
		}
		#expect(other.count == 1 && other.firstObject as AnyObject === texture)
		#expect(lines.count == 0 && tris.count == 0 && quads.count == 0)
		#expect(texture.subdirectives().count == 2)
		#expect(Prim.write(texture).hasPrefix("0 !TEXMAP START PLANAR -5.5 0.25 -10 15 0 -10.125 -5 3.5 10 "), "\(Prim.write(texture))")
		// Recursive: children are flattened in place (lines, triangles, quads, others) and the fallback dropped.
		try ObjC.run {
			texture.flatten(intoLines: lines, triangles: tris, quadrilaterals: quads, other: other, currentColor: nil,
							currentTransform: IdentityMatrix4, normalTransform: IdentityMatrix3, recursive: true)
		}
		#expect(!Prim.write(texture).contains("FALLBACK"))
		#expect(texture.subdirectives().count == 2)
	}

	@Test("Line classifiers and the range of a texture block")
	func ranges() throws {
		let checks: [(String?, Bool, Bool, Bool)] = [
			// line, beginning, fallback, terminator
			("0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png", true, false, false),
			("0 !TEXMAP NEXT PLANAR", true, false, false),
			("0 !TEXMAP START CYLINDRICAL", false, false, false),
			("0  !TEXMAP\tSTART  PLANAR", true, false, false),
			("0 !TEXMAP FALLBACK", false, true, false),
			("0 !TEXMAP END", false, false, true),
			("0 !TEXMAP ENDING", false, false, false),
			("0 !texmap end", false, false, false),
			("1 !TEXMAP END", false, false, false),
			("0 !: 0 !TEXMAP END", false, false, false),
			("", false, false, false),
			(nil, false, false, false),
		]
		for (line, begin, fallback, end) in checks {
			#expect(LDrawTexture.lineIsTextureBeginning(line) == begin, "\(String(describing: line))")
			#expect(LDrawTexture.lineIsTextureFallback(line) == fallback, "\(String(describing: line))")
			#expect(LDrawTexture.lineIsTextureTerminator(line) == end, "\(String(describing: line))")
		}
		let start = "0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png"
		let tri = "3 16 0 0 0 1 0 0 0 1 0"
		let cases: [([String], Int, Int, NSRange)] = [
			([start, tri, "0 !TEXMAP END", tri], 0, 3, NSRange(location: 0, length: 3)),
			([start, tri, tri], 0, 2, NSRange(location: 0, length: 2)),
			([tri, start, tri, "0 !TEXMAP END"], 1, 3, NSRange(location: 1, length: 3)),
			([start, start, tri, "0 !TEXMAP END", tri, "0 !TEXMAP END"], 0, 5, NSRange(location: 0, length: 6)),
			([start], 0, 0, NSRange(location: 0, length: 0)),
			([tri, tri], 0, 1, NSRange(location: 0, length: 0)),
			(["0 // not a texture", tri], 0, 1, NSRange(location: 0, length: 0)),
		]
		for (lines, index, maxIndex, expected) in cases {
			let range = LDrawTexture.rangeOfDirectiveBeginning(at: UInt(index), inLines: ldrawLines(lines), maxIndex: UInt(maxIndex))
			#expect(range == expected, "\(lines) from \(index) to \(maxIndex): \(range)")
		}
	}

	@Test("Planar header with non-ASCII next to the fields (UTF-16 scanning, L101)")
	func planarHeaderNonASCII() throws {
		let lines = [
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \u{301}a.png",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9\u{301} a.png",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \"\u{1F600} x\" GLOSSMAP \u{200D}g",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png\u{A0}GLOSSMAP g",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png GLOSSMAP \"\"",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \"\" GLOSSMAP g",
			"0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \"\"\"a b\"",
			"0\u{301} !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png",
		]
		var out: [String] = []
		for line in lines {
			let texture = LDrawTexture()
			let ok = try ObjC.run { texture.parsePlanarTexture(fromLine: line, parentGroup: nil) }
			out.append("\(Meta.escape(line)) -> \(ok) image=[\(texture.imageDisplayName().map(Meta.escape) ?? "nil")] gloss=[\(texture.glossmapName().map(Meta.escape) ?? "nil")] header=[\(Meta.escape(Prim.write(texture).components(separatedBy: "\n")[0]))]")
		}
		let actual = out.joined(separator: "\n")
		#expect(actual == Self.expectedNonASCII, "\(actual)")
	}

	static let expectedNonASCII = #"""
		0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \u{301}a.png -> true image=[\u{301}a.png] gloss=[nil] header=[0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \u{301}a.png]
		0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9\u{301} a.png -> true image=[\u{301}] gloss=[nil] header=[0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \u{301}]
		0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 "\u{1F600} x" GLOSSMAP \u{200D}g -> true image=[\u{1F600} x] gloss=[\u{200D}g] header=[0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 \u{1F600} x GLOSSMAP \u{200D}g]
		0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png\u{A0}GLOSSMAP g -> true image=[a.png] gloss=[g] header=[0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png GLOSSMAP g]
		0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png GLOSSMAP "" -> false image=[a.png] gloss=[nil] header=[0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png]
		0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 "" GLOSSMAP g -> true image=[GLOSSMAP g] gloss=[nil] header=[0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 GLOSSMAP g]
		0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 """a b" -> true image=[a b] gloss=[nil] header=[0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a b]
		0\u{301} !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png -> true image=[a.png] gloss=[nil] header=[0 !TEXMAP START PLANAR 1 2 3 4 5 6 7 8 9 a.png]
		"""#
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

	@Test("Copy-number edge cases: overflow, signs, whitespace, non-ASCII digits, nil (P5 pre-port)")
	func copyNameEdgeCases() {
		// Recorded against the ObjC implementation before the Swift port. The number is read by NSScanner
		// (scanInteger:, skipping whitespace and newlines), and NSIntegerMax + 1 wraps.
		let names: [String?] = [
			"foo copy 9223372036854775807", "foo copy 99999999999999999999", "foo copy -9223372036854775808",
			"foo copy +3", "foo copy\n4", "foo copy 3 ", "foo copy 3\n", "foo copy\t7", "foo copy 00", "foo copy-1",
			"foo copy 1.5", "foo copy 0x10", "foo copy \u{0663}", "foo copy \u{FF13}", "foo copy 3 copy",
			"foo copy copy 2", "\u{1F600} copy 2", "foo copy\u{00A0}5", nil,
		]
		let paths: [String?] = ["dir/foo copy 9223372036854775807.ldr", "foo copy +3.ldr", "foo copy\n4.ldr", nil]
		var out: [String] = []
		for name in names {
			out.append("\(name.debugDescription) -> \(StringUtilities.nextCopyName(for: name).debugDescription)")
		}
		for path in paths {
			out.append("\(path.debugDescription) -> \(StringUtilities.nextCopyPath(forFilePath: path).debugDescription)")
		}
		let expected = [
			#"Optional("foo copy 9223372036854775807") -> Optional("foo copy -9223372036854775808")"#,
			#"Optional("foo copy 99999999999999999999") -> Optional("foo copy -9223372036854775808")"#,
			#"Optional("foo copy -9223372036854775808") -> Optional("foo copy -9223372036854775808 copy")"#,
			#"Optional("foo copy +3") -> Optional("foo copy 4")"#,
			#"Optional("foo copy\n4") -> Optional("foo copy 5")"#,
			#"Optional("foo copy 3 ") -> Optional("foo copy 4")"#,
			#"Optional("foo copy 3\n") -> Optional("foo copy 4")"#,
			#"Optional("foo copy\t7") -> Optional("foo copy 8")"#,
			#"Optional("foo copy 00") -> Optional("foo copy 00 copy")"#,
			#"Optional("foo copy-1") -> Optional("foo copy-1 copy")"#,
			#"Optional("foo copy 1.5") -> Optional("foo copy 1.5 copy")"#,
			#"Optional("foo copy 0x10") -> Optional("foo copy 0x10 copy")"#,
			#"Optional("foo copy ٣") -> Optional("foo copy 4")"#,   // NSScanner reads any Unicode decimal digit
			#"Optional("foo copy ３") -> Optional("foo copy 4")"#,
			#"Optional("foo copy 3 copy") -> Optional("foo copy 3 copy 2")"#,
			#"Optional("foo copy copy 2") -> Optional("foo copy copy 3")"#,
			#"Optional("😀 copy 2") -> Optional("😀 copy 3")"#,
			"Optional(\"foo copy\u{00A0}5\") -> Optional(\"foo copy 6\")",
			#"nil -> nil"#,
			#"Optional("dir/foo copy 9223372036854775807.ldr") -> Optional("dir/foo copy -9223372036854775808.ldr")"#,
			#"Optional("foo copy +3.ldr") -> Optional("foo copy 4.ldr")"#,
			#"Optional("foo copy\n4.ldr") -> Optional("foo copy 5.ldr")"#,
			#"nil -> nil"#,
		]
		#expect(out == expected, "\(Golden.firstDifference(Data(expected.joined(separator: "\n").utf8), Data(out.joined(separator: "\n").utf8)))")
	}
}

// MARK: - StringCategory

@Suite("StringCategory: NSString helpers (P5 pre-port)")
struct StringCategoryTests {

	@Test("The ObjC selectors exist under their original names (xibs sort with numericCompare:)")
	func selectorsKept() {
		for name in ["ams_containsString:options:", "numericCompare:", "separateByLine", "ams_stringByRemovingWhitespace"] {
			#expect(NSString.instancesRespond(to: NSSelectorFromString(name)), "-[NSString \(name)] missing")
		}
		#expect(NSString.responds(to: NSSelectorFromString("CRLF")), "+[NSString CRLF] missing")
		for name in ["nextCopyNameForString:", "nextCopyPathForFilePath:"] {
			#expect(StringUtilities.responds(to: NSSelectorFromString(name)), "+[StringUtilities \(name)] missing")
		}
		#expect(NSStringFromClass(StringUtilities.self) == "StringUtilities")
	}

	@Test("+CRLF is carriage return, line feed")
	func crlf() {
		let crlf: String = NSString.crlf()
		#expect(Array(crlf.utf16) == [13, 10])
	}

	@Test("-separateByLine splits on every line terminator NSString knows, and drops a final terminator")
	func separateByLine() {
		let cases: [(String, [String])] = [
			("", []),
			("a", ["a"]),
			("a\n", ["a"]),
			("a\nb", ["a", "b"]),
			("a\r\nb\r\n", ["a", "b"]),
			("a\rb", ["a", "b"]),
			("a\n\rb", ["a", "", "b"]),
			("\n\n", ["", ""]),
			("\r", [""]),
			("a\r\n\r\nb", ["a", "", "b"]),
			("a\r\r\nb", ["a", "", "b"]),
			("a\u{2028}b\u{2029}c\u{0085}d", ["a", "b", "c", "d"]),
			("a\u{000C}b\u{000B}c", ["a\u{000C}b\u{000B}c"]),
			("\u{1F600}\n\u{1F600}x", ["\u{1F600}", "\u{1F600}x"]),
			(" \t x \t\r\n", [" \t x \t"]),
		]
		for (input, expected) in cases {
			let lines = (input as NSString).separateByLine() as? [String]
			#expect(lines == expected, "\(input.debugDescription) -> \(String(describing: lines))")
		}
	}

	@Test("-separateByLine returns NSString elements and handles a large CRLF file")
	func separateByLineBulk() throws {
		let body = (0..<2000).map { "1 16 0 0 \($0) 1 0 0 0 1 0 0 0 1 3001.dat" }
		let lines = try #require((body.joined(separator: "\r\n") as NSString).separateByLine())
		#expect(lines.count == 2000)
		#expect(lines.allSatisfy { $0 is NSString })
		#expect((lines as? [String]) == body)
	}

	@Test("-ams_stringByRemovingWhitespace removes whitespaceCharacterSet members only, per UTF-16 unit")
	func removingWhitespace() {
		let cases: [(String, String)] = [
			("", ""),
			(" a b\tc ", "abc"),
			("a\nb\rc", "a\nb\rc"),                            // newlines are not in whitespaceCharacterSet
			("a\u{00A0}b\u{3000}c\u{2003}d", "abcd"),           // Zs separators are
			("a\u{200B}b", "ab"),                               // so is U+200B zero-width space (Cf), in Apple's set
			("\u{1F600} \u{1F600}", "\u{1F600}\u{1F600}"),
			("Brick 2 x 2", "Brick2x2"),
		]
		for (input, expected) in cases {
			let result: String? = (input as NSString).ams_stringByRemovingWhitespace()
			#expect(result == expected, "\(input.debugDescription) -> \(result.debugDescription)")
		}
		// A lone surrogate survives (the loop works on UTF-16 units).
		let lone = NSString(characters: [0xD800, 0x20, 0x41], length: 3)
		let stripped: NSString = lone.ams_stringByRemovingWhitespace()! as NSString
		var units = [unichar](repeating: 0, count: stripped.length)
		stripped.getCharacters(&units, range: NSRange(location: 0, length: stripped.length))
		#expect(units == [0xD800, 0x41])
	}

	@Test("-ams_containsString:options: treats the empty string as a substring of everything")
	func containsString() {
		let caseless = NSString.CompareOptions.caseInsensitive.rawValue
		let anchored = NSString.CompareOptions.anchored.rawValue
		let cases: [(String, String, UInt, Bool)] = [
			("abc", "", 0, true),
			("", "", 0, true),
			("", "a", 0, false),
			("abc", "b", 0, true),
			("abc", "B", 0, false),
			("abc", "B", caseless, true),
			("abc", "abcd", 0, false),
			("abc", "bc", anchored, false),
			("abc", "ab", anchored, true),
			("ab c", " ", 0, true),
			("3001.dat", "3001", caseless, true),
		]
		for (receiver, substring, mask, expected) in cases {
			let found = (receiver as NSString).ams_contains(substring, options: mask)
			#expect(found == expected, "\(receiver.debugDescription) contains \(substring.debugDescription) options \(mask)")
		}
	}

	@Test("-numericCompare: is compare:options:NSNumericSearch, and a nil argument sorts first")
	func numericCompare() {
		let cases: [(String, String?, ComparisonResult)] = [
			("2", "10", .orderedAscending),
			("10", "2", .orderedDescending),
			("a9", "a10", .orderedAscending),
			("x 2.ldr", "x 10.ldr", .orderedAscending),
			("abc", "abc", .orderedSame),
			("A", "a", .orderedAscending),
			("007", "7", .orderedSame),
			("a", "", .orderedDescending),
			("", "", .orderedSame),
			("a", nil, .orderedDescending),
			("", nil, .orderedDescending),
		]
		for (receiver, argument, expected) in cases {
			let result = (receiver as NSString).numericCompare(argument)
			#expect(result == expected, "\(receiver.debugDescription) vs \(argument.debugDescription): \(result.rawValue)")
		}
		// As the xibs use it: a sort descriptor with selector numericCompare:.
		let descriptor = NSSortDescriptor(key: "self", ascending: true, selector: NSSelectorFromString("numericCompare:"))
		let sorted = (["10", "9", "1", "3001b", "3001a", "300"] as NSArray).sortedArray(using: [descriptor]) as? [String]
		#expect(sorted == ["1", "9", "10", "300", "3001a", "3001b"])
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
