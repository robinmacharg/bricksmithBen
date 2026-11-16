//
//  LSynthCoverageTests.swift
//  BricksmithTests
//
//  P2 exit (coverage): LDrawLSynth and LDrawLSynthDirective beyond the round trip in LSynthTests.
//  Goldens: Fixtures/golden/lsynth-coverage/*.txt
//
//  Covered here (all live; callers in brackets):
//    - parsing every block state, and write with/without stored synthesized parts [file open/save]
//    - drawSelf: which constraints are drawn for hose/band/part/selected/hidden, and lazy resynthesis
//      [LDrawGLRenderer -> -[LDrawFile drawSelf:]]
//    - boxTest:/depthTest: (marquee and click picking) [LDrawGLRenderer ~1900-2090]
//    - colorSelectedSynthesizedParts: in the three LSynth selection modes [setSelected:, preferences notification]
//    - insert/remove/drop of constraints and INSIDE/OUTSIDE/CROSS directives [LDrawDocument]
//    - LDrawLSynthDirective browsingDescription/iconName/write/setSelected: [outline view, selection]
//    - nudge/moveBy:, boundingBox3, transformComponents, the two LSynth notifications, custom lsynth path
//
//  Known issues (withKnownIssue, BUG-TBD-*): HIDE written back as SHOW; coloured selection modes raise with
//  the default (catalog) selection colour; a hidden block is still picked; synthesized parts outside the
//  constraints' bounding box can't be picked through the file; comments/groups/other lines inside a block are dropped.
//
//  NOT covered (dead code, see the coverage ledger): -doAutoHullOnBand (its only call is commented out in
//  -synthesize), -prepareAutoHullData (only called by it) and the whole of ComputationalGeometry.m (only
//  called by those two).
//

import AppKit
import Foundation
import Testing
@testable import Bricksmith

enum SynthKit {
	static let header = "0 LSynth coverage\n0 Name: lsynth-coverage.ldr\n0 Author: Fixture Author\n"

	/// Parse `body` behind a header (L71); returns the file and its first LSynth block.
	static func load(_ body: String) throws -> (LDrawFile, LDrawLSynth) {
		let text = header + body.replacingOccurrences(of: "\t", with: "") + "\n"
		let file = try #require(RoundTrip.load(Data(text.utf8)))
		let synth = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawLSynth }.first)
		return (file, synth)
	}

	/// A block of the given type whose constraints and stored synthesized parts are mini-library bricks, so
	/// they have geometry to draw and pick. Constraints: 3003 at x = -50 and x = +50; synthesized: 3005 at
	/// y = -40 and y = +60 (both on x = 0). An OUTSIDE directive sits between the constraints.
	static func block(_ type: String, colour: Int = 4, visibility: String = "SHOW", synthesized: Bool = true) -> String {
		var lines = ["0 SYNTH BEGIN \(type) \(colour)", "0 SYNTH \(visibility)",
					 "1 4 -50 0 0 1 0 0 0 1 0 0 0 1 3003.dat",
					 "0 SYNTH OUTSIDE",
					 "1 4 50 0 0 1 0 0 0 1 0 0 0 1 3003.dat"]
		if synthesized {
			lines += ["0 SYNTH SYNTHESIZED BEGIN",
					  "1 4 0 -40 0 1 0 0 0 1 0 0 0 1 3005.dat",
					  "1 4 0 60 0 1 0 0 0 1 0 0 0 1 3005.dat",
					  "0 SYNTH SYNTHESIZED END"]
		}
		return (lines + ["0 SYNTH END"]).joined(separator: "\n")
	}

	/// The synthesized parts (no public accessor; read the ivar through KVC).
	static func synthesized(_ synth: LDrawLSynth) -> [LDrawPart] {
		(synth.value(forKey: "synthesizedParts") as? [LDrawPart]) ?? []
	}

	static func lines(_ s: String) -> String { s.replacingOccurrences(of: "\r\n", with: "\n") }

	static func colour(_ c: LDrawColor?) -> String {
		guard let c else { return "nil" }
		return "code \(c.colorCode().rawValue) rgba \(Colour.rgba(c).map { String(format: "%.3f", $0) }.joined(separator: " "))"
	}
}

/// Preferences in the volatile argument domain: it outranks the persistent domains and is never written
/// (L53). Restored afterwards.
enum ArgumentPrefs {
	static func with<T>(_ values: [String: Any], _ body: () throws -> T) rethrows -> T {
		let defaults = UserDefaults.standard
		let saved = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
		defaults.setVolatileDomain(saved.merging(values) { $1 }, forName: UserDefaults.argumentDomain)
		defer { defaults.setVolatileDomain(saved, forName: UserDefaults.argumentDomain) }
		return try body()
	}

	/// A colour archived the way -[NSUserDefaults setColor:forKey:] does (non-keyed NSArchiver). Called through
	/// the runtime so the deprecated class doesn't add a compiler warning.
	static func archivedColour(_ colour: NSColor) -> Data {
		let archiver: AnyObject = NSClassFromString("NSArchiver")!
		return archiver.perform(NSSelectorFromString("archivedDataWithRootObject:"), with: colour)!
			.takeUnretainedValue() as! Data
	}
}

@MainActor
@Suite("LSynth coverage: LDrawLSynth and LDrawLSynthDirective (P2 exit)", .fixtureLibrary, .serialized)
struct LSynthCoverageTests {

	/// Selecting parts makes drag handles, which need a current GL context (L70).
	init() throws { try OffscreenGL.makeCurrent() }

	// MARK: Parsing and writing

	@Test("Parsing every block state; written output and object tree")
	func parseAndWrite() throws {
		let cases: [(String, String)] = [
			("band with stored synthesized parts", SynthKit.block("RUBBER_BAND")),
			("HIDE instead of SHOW", SynthKit.block("PNEUMATIC_HOSE", colour: 16, visibility: "HIDE")),
			("INSIDE, OUTSIDE and CROSS directives", """
				0 SYNTH BEGIN TECHNIC_CHAIN_LINK 0
				0 SYNTH SHOW
				0 SYNTH INSIDE
				1 0 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
				0 SYNTH OUTSIDE
				1 0 80 0 0 1 0 0 0 1 0 0 0 1 3001.dat
				0 SYNTH CROSS
				0 SYNTH END
				"""),
			("unknown type, unexpected lines", """
				0 SYNTH BEGIN NOT_A_TYPE 1
				0 SYNTH SHOW
				1 1 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
				0 SYNTH SYNTHESIZED END
				2 24 0 0 0 10 0 0
				0 just a comment
				0 SYNTH END
				"""),
			("LSynth PART type (band class)", SynthKit.block("PLI_TECHNIC_TREAD", colour: 0)),
			("LSynth PART type (hose class)", SynthKit.block("PLI_HOSE_FLEXIBLE_12L", colour: 0)),
		]
		var out: [String] = []
		for (name, body) in cases {
			let (file, synth) = try SynthKit.load(body)
			out.append("## \(name)")
			out.append("lsynthClass \(synth.lsynthClass()) type \(synth.lsynthType() ?? "nil") colour \(synth.lDrawColor()?.colorCode().rawValue ?? -1)")
			out.append("browsingDescription \(synth.browsingDescription() ?? "nil"), iconName \(synth.iconName() ?? "nil"), inspector \(synth.inspectorClassName() ?? "nil")")
			out.append("synthesized parts \(synth.synthesizedPartsCount())")
			out.append("tree:")
			out.append(ObjectModel.describe(synth).trimmingCharacters(in: .newlines))
			out.append("constraint icons: " + ObjectModel.all(synth).dropFirst().map { $0.iconName() ?? "nil" }.joined(separator: " "))
			out.append("written:")
			out.append(SynthKit.lines(String(decoding: RoundTrip.save(file), as: UTF8.self)).trimmingCharacters(in: .newlines))
			out.append("")
		}
		try Golden.check(Data(out.joined(separator: "\n").utf8), against: "lsynth-coverage/parse.txt")
	}

	@Test("With 'Save Synthesized Parts' off, write omits the SYNTHESIZED block")
	func writeWithoutSynthesizedParts() throws {
		let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		let written = ArgumentPrefs.with([LSYNTH_SAVE_SYNTHESIZED_PARTS_KEY: false]) { SynthKit.lines(synth.write()) }
		#expect(!written.contains("SYNTHESIZED"), "\(written)")
		#expect(written.hasPrefix("0 SYNTH BEGIN RUBBER_BAND 4\n0 SYNTH SHOW\n1 4 -50"), "\(written)")
		#expect(written.hasSuffix("0 SYNTH END\n"), "\(written)")
	}

	@Test("0 SYNTH HIDE survives a round trip")
	func hideRoundTrip() throws {
		let (file, _) = try SynthKit.load(SynthKit.block("PNEUMATIC_HOSE", colour: 16, visibility: "HIDE"))
		let written = SynthKit.lines(String(decoding: RoundTrip.save(file), as: UTF8.self))
		withKnownIssue("BUG-027: -[LDrawLSynth write] always writes 0 SYNTH SHOW, so HIDE becomes SHOW on save") {
			#expect(written.contains("\n0 SYNTH HIDE\n"), "\(written)")
		}
	}

	@Test("Other lines inside a block (comments, groups, non-part lines) survive a round trip",
		  arguments: ["0 a comment inside the block", "0 MLCAD BTG group1", "0 GROUP 1 group1", "2 24 0 0 0 10 0 0"])
	func otherLinesRoundTrip(line: String) throws {
		// lsynthcp passes such lines through (lsynthcp.c ~800-832: every unrecognised line is fputs'd, and
		// MLCAD BTG names the group of the synthesized parts). Bricksmith's parser logs them and drops them.
		let body = """
			0 SYNTH BEGIN RUBBER_BAND 4
			0 SYNTH SHOW
			1 4 -50 0 0 1 0 0 0 1 0 0 0 1 3003.dat
			\(line)
			1 4 50 0 0 1 0 0 0 1 0 0 0 1 3003.dat
			0 SYNTH END
			"""
		let (file, _) = try SynthKit.load(body)
		let written = SynthKit.lines(String(decoding: RoundTrip.save(file), as: UTF8.self))
		withKnownIssue("BUG-028: lines other than SYNTH directives and type-1 parts inside an LSynth block are dropped on parse, so lost on save") {
			#expect(written.contains("\n\(line)\n"), "\(written)")
		}
	}

	// MARK: Directives

	@Test("LDrawLSynthDirective: description, icon and written form for each direction")
	func directiveDisplay() throws {
		var out: [String] = []
		for value in ["INSIDE", "OUTSIDE", "CROSS", "SIDEWAYS"] {
			let directive = LDrawLSynthDirective()
			directive.setStringValue(value)
			out.append("\(value): '\(directive.browsingDescription() ?? "nil")' icon \(directive.iconName() ?? "nil") write '\(directive.write() ?? "nil")'")
		}
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "lsynth-coverage/directive.txt")
	}

	@Test("Selecting a direction directive marks its LSynth block as having a selected subdirective")
	func directiveSelection() throws {
		let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		let directive = try #require(synth.subdirectives().compactMap { $0 as? LDrawLSynthDirective }.first)
		let parts = SynthKit.synthesized(synth)
		#expect(parts.count == 2)
		let before = parts.map { SynthKit.colour($0.lDrawColor()) }
		try ObjC.run { directive.setSelected(true) }
		#expect(directive.isSelected())
		#expect(synth.value(forKey: "subdirectiveSelected") as? Bool == true)
		let selected = parts.map { SynthKit.colour($0.lDrawColor()) }
		#expect(selected != before, "synthesized parts should be recoloured while a constraint is selected")
		try ObjC.run { directive.setSelected(false) }
		#expect(synth.value(forKey: "subdirectiveSelected") as? Bool == false)
		#expect(parts.map { SynthKit.colour($0.lDrawColor()) } == before)

		// A directive outside any LSynth block can still be selected.
		let loose = LDrawLSynthDirective()
		loose.setStringValue("INSIDE")
		try ObjC.run { loose.setSelected(true) }
		#expect(loose.isSelected())
	}

	// MARK: Selection colouring

	@Test("Selected synthesized parts are recoloured according to the LSynth selection mode")
	func selectionColouring() throws {
		var out: [String] = []
		// Device RGB: -redComponent etc. then return the components as given (no colour-space conversion).
		let green = ArgumentPrefs.archivedColour(NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1))
		let modes: [(String, [String: Any])] = [
			("TransparentSelection (0), 20%", [LSYNTH_SELECTION_MODE_KEY: 0, LSYNTH_SELECTION_TRANSPARENCY_KEY: 20]),
			("ColoredSelection (1), green", [LSYNTH_SELECTION_MODE_KEY: 1, LSYNTH_SELECTION_COLOR_KEY: green]),
			("TransparentColoredSelection (2), green, 50%", [LSYNTH_SELECTION_MODE_KEY: 2, LSYNTH_SELECTION_COLOR_KEY: green,
															  LSYNTH_SELECTION_TRANSPARENCY_KEY: 50]),
		]
		for (name, prefs) in modes {
			let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
			let parts = SynthKit.synthesized(synth)
			out.append("## \(name)")
			out.append("unselected: " + SynthKit.colour(parts.first?.lDrawColor()))
			try ArgumentPrefs.with(prefs) {
				try ObjC.run { synth.setSelected(true) }
				out.append("selected:   " + parts.map { SynthKit.colour($0.lDrawColor()) }.joined(separator: " | "))
				try ObjC.run { synth.setSelected(false) }
				out.append("deselected: " + SynthKit.colour(parts.first?.lDrawColor()))
				try ObjC.run { synth.setSubdirectiveSelected(true) }
				out.append("constraint selected: " + SynthKit.colour(parts.first?.lDrawColor()))
				// The preferences controller posts this when the user changes the selection style; a block
				// with a selected constraint recolours in the new style.
				try ArgumentPrefs.with([LSYNTH_SELECTION_MODE_KEY: 0, LSYNTH_SELECTION_TRANSPARENCY_KEY: 75]) {
					try ObjC.run { NotificationCenter.default.post(name: .LSynthSelectionDisplayDidChange, object: nil) }
				}
				out.append("style changed to transparent 75% + notification: " + SynthKit.colour(parts.first?.lDrawColor()))
				try ObjC.run { synth.setSubdirectiveSelected(false) }
				out.append("constraint deselected: " + SynthKit.colour(parts.first?.lDrawColor()))
			}
			// Written output always uses the block's own colour, whatever the selection colouring.
			out.append("written synthesized line: " + (SynthKit.lines(synth.write()).components(separatedBy: "\n").first { $0.hasSuffix("3005.dat") } ?? "none"))
			out.append("")
		}
		try Golden.check(Data(out.joined(separator: "\n").utf8), against: "lsynth-coverage/selection-colour.txt")
	}

	@Test("Selecting a block in a coloured selection mode with the default selection colour (system red)",
		  arguments: [1, 2])
	func defaultSelectionColour(mode: Int) throws {
		let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		// Exactly what +[PreferencesDialogController ensureDefaults] registers: a catalog colour, on which
		// -redComponent raises (it needs an RGB colour space).
		let systemRed = ArgumentPrefs.archivedColour(NSColor.systemRed)
		try ArgumentPrefs.with([LSYNTH_SELECTION_MODE_KEY: mode, LSYNTH_SELECTION_COLOR_KEY: systemRed]) {
			withKnownIssue("BUG-029: colorSelectedSynthesizedParts: calls -redComponent on the default (catalog) selection colour and raises") {
				#expect(throws: Never.self) { try ObjC.run { synth.setSelected(true) } }
			}
			// Deselecting uses the block's own colour and is unaffected.
			try ObjC.run { synth.setSelected(false) }
		}
	}

	// MARK: Drawing

	@Test("drawSelf: which constraints are drawn, by class and selection; hidden blocks draw nothing")
	func drawing() throws {
		try OffscreenGL.makeCurrent()
		var out: [String] = []
		func record(_ name: String, _ type: String, prepare: (LDrawLSynth) throws -> Void = { _ in }) throws {
			let (_, synth) = try SynthKit.load(SynthKit.block(type))
			try prepare(synth)
			let renderer = RecordingRenderer()
			// Record the second pass only: the first also builds the parts' display lists, and which case
			// builds them first depends on the order of the cases.
			try ObjC.run { synth.drawSelf(renderer) }
			let seen = renderer.log.count
			try ObjC.run { synth.drawSelf(renderer) }
			out.append("## \(name)")
			out += renderer.log[seen...]
		}
		try record("hose, unselected (synthesized parts only)", "PNEUMATIC_HOSE")
		try record("hose, selected (constraints too)", "PNEUMATIC_HOSE") { s in try ObjC.run { s.setSelected(true) } }
		try record("hose, a constraint selected", "PNEUMATIC_HOSE") { s in
			let part = try #require(s.subdirectives().firstObject as? LDrawPart)
			try ObjC.run { part.setSelected(true) }
		}
		try record("band (constraints always drawn)", "RUBBER_BAND")
		try record("LSynth PART of band class (constraints drawn)", "PLI_TECHNIC_TREAD")
		try record("LSynth PART of hose class (synthesized parts only)", "PLI_HOSE_FLEXIBLE_12L")
		try record("hidden band (nothing)", "RUBBER_BAND") { s in
			s.setHidden(true)
			#expect(s.isHidden())
		}
		try record("hidden then shown again", "RUBBER_BAND") { s in s.setHidden(true); s.setHidden(false) }
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "lsynth-coverage/draw.txt")
	}

	@Test("drawSelf resynthesizes an invalidated block (here: a parsed block with no stored parts)")
	func drawResynthesizes() throws {
		try OffscreenGL.makeCurrent()
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/08b-lsynth-show.ldr"))
		let synth = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawLSynth }.first)
		#expect(synth.synthesizedPartsCount() == 0)
		try ObjC.run { synth.drawSelf(RecordingRenderer()) }
		let count = synth.synthesizedPartsCount()
		#expect(count > 0, "drawing should have synthesized the hose")
		// The cache is now valid: a second draw doesn't synthesize again (the parts are the same objects).
		let parts = SynthKit.synthesized(synth).map(ObjectIdentifier.init)
		try ObjC.run { synth.drawSelf(RecordingRenderer()) }
		#expect(SynthKit.synthesized(synth).map(ObjectIdentifier.init) == parts)
	}

	// MARK: Picking

	/// A click box of HANDLE_SIZE-ish half-width around `point` (clip space), as in HitTestingTests.
	static func clickBox(_ point: Point2) -> Box2 {
		Box2(origin: Point2(x: point.x - 0.01, y: point.y - 0.01), size: Size2(width: 0.02, height: 0.02))
	}

	@Test("Marquee and click picking on the block: constraints and synthesized parts, and who gets the credit")
	func picking() throws {
		var out: [String] = []
		// Picking doesn't depend on the block's class; one type is enough.
		for type in ["RUBBER_BAND"] {
			let (file, synth) = try SynthKit.load(SynthKit.block(type))
			let constraints = synth.subdirectives().compactMap { $0 as? LDrawPart }
			let parts = SynthKit.synthesized(synth)
			var names: [ObjectIdentifier: String] = [ObjectIdentifier(synth): "synth"]
			for (i, c) in constraints.enumerated() { names[ObjectIdentifier(c)] = "constraint\(i)" }
			for (i, p) in parts.enumerated() { names[ObjectIdentifier(p)] = "synthesized\(i)" }
			func name(_ o: AnyObject?) -> String { o.map { names[ObjectIdentifier($0)] ?? String(describing: Swift.type(of: $0)) } ?? "nothing" }
			func name(key: Any) -> String {
				let raw = (key as! NSValue).pointerValue
				let all: [AnyObject] = [synth] + constraints + parts
				return all.first { HitLayout.pointer($0) == raw }.map { name($0) } ?? "?"
			}

			out.append("## \(type)")
			let boxes: [(String, Box2)] = [
				("whole view", Box2(origin: Point2(x: -1, y: -1), size: Size2(width: 2, height: 2))),
				("left constraint only", Box2(origin: Point2(x: -0.75, y: -0.3), size: Size2(width: 0.3, height: 0.4))),
				("lower synthesized part only", Box2(origin: Point2(x: -0.1, y: -0.85), size: Size2(width: 0.2, height: 0.2))),
				("empty corner", Box2(origin: Point2(x: 0.9, y: 0.9), size: Size2(width: 0.05, height: 0.05))),
			]
			for (label, box) in boxes {
				for credit in [false, true] {
					let hits = NSMutableSet()
					var any = false
					try ObjC.run {
						any = synth.boxTest(box, transform: HitLayout.transform, boundsOnly: false,
											creditObject: credit ? file : nil, hits: hits)
					}
					let picked = hits.allObjects.map { name(key: $0) }.sorted()
					out.append("box \(label), credit \(credit ? "file" : "nil"): returned \(any ? "YES" : "NO"), hits [\(picked.joined(separator: " "))]")
				}
			}
			let clicks: [(String, Point2)] = [
				("left constraint", Point2(x: -0.5, y: -0.1)),
				("right constraint", Point2(x: 0.5, y: -0.1)),
				("upper synthesized part", Point2(x: 0, y: 0.3)),
				("lower synthesized part", Point2(x: 0, y: -0.7)),
				("nothing", Point2(x: 0.9, y: 0.9)),
			]
			for (label, point) in clicks {
				var best: AnyObject? = nil
				var depth: Float = 1
				let half: Float = 0.01
				try ObjC.run {
					synth.depthTest(point, inBox: Box2(origin: Point2(x: point.x - half, y: point.y - half),
													   size: Size2(width: 2 * half, height: 2 * half)),
									transform: HitLayout.transform, creditObject: nil, bestObject: &best, bestDepth: &depth)
				}
				out.append(String(format: "click %@: %@ depth %.5f", label, name(best), depth))
			}
			out.append("")
		}
		try Golden.check(Data(out.joined(separator: "\n").utf8), against: "lsynth-coverage/picking.txt")
	}

	@Test("Picking through the file (as the renderer does) reaches synthesized parts outside the constraints' bounds")
	func pickSynthesizedThroughFile() throws {
		// The synthesized parts lie at y -44..-16 and 56..84; the constraints' bounding box (the block's
		// boundingBox3) is y -4..24. LDrawModel and LDrawStep skip children whose bounding box can't be hit.
		let (file, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		let constraint = try #require(synth.subdirectives().firstObject as? LDrawPart)
		func click(_ point: Point2) throws -> AnyObject? {
			var best: AnyObject? = nil
			var depth: Float = 1
			try ObjC.run {
				file.depthTest(point, inBox: Self.clickBox(point), transform: HitLayout.transform, creditObject: nil,
							   bestObject: &best, bestDepth: &depth)
			}
			return best
		}
		// Control: a constraint (inside the bounds) is picked through the file.
		#expect(try click(Point2(x: -0.5, y: -0.1)) === constraint)
		let lower = try click(Point2(x: 0, y: -0.7))
		let hits = NSMutableSet()
		try ObjC.run {
			_ = file.boxTest(Box2(origin: Point2(x: -0.1, y: -0.85), size: Size2(width: 0.2, height: 0.2)),
							 transform: HitLayout.transform, boundsOnly: false, creditObject: nil, hits: hits)
		}
		withKnownIssue("BUG-031: LDrawLSynth boundingBox3 covers only the constraints, so synthesized parts outside them can't be clicked or marquee-selected") {
			#expect(lower === synth, "click on the lower synthesized part picked \(String(describing: lower))")
			#expect(hits.count == 1, "marquee around the lower synthesized part hit \(hits.count) objects")
		}
	}

	@Test("A hidden block is never picked")
	func hiddenNotPicked() throws {
		let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		synth.setHidden(true)
		let hits = NSMutableSet()
		var best: AnyObject? = nil
		var depth: Float = 1
		try ObjC.run {
			_ = synth.boxTest(Box2(origin: Point2(x: -1, y: -1), size: Size2(width: 2, height: 2)),
							  transform: HitLayout.transform, boundsOnly: false, creditObject: nil, hits: hits)
			synth.depthTest(Point2(x: -0.5, y: -0.1), inBox: Self.clickBox(Point2(x: -0.5, y: -0.1)),
							transform: HitLayout.transform, creditObject: nil, bestObject: &best, bestDepth: &depth)
		}
		withKnownIssue("BUG-030: boxTest:/depthTest: ignore the block's hidden flag (drawSelf: and hitTest: honour it)") {
			#expect(hits.count == 0, "marquee picked a hidden block")
			#expect(best == nil, "click picked \(String(describing: best)) in a hidden block")
		}
	}

	// MARK: Editing

	@Test("Inserting a constraint picks its icon from the block's class and invalidates the synthesis")
	func insertConstraint() throws {
		var out: [String] = []
		for type in ["PNEUMATIC_HOSE", "RUBBER_BAND", "PLI_HOSE_FLEXIBLE_12L", "PLI_TECHNIC_TREAD", "NOT_A_TYPE"] {
			let (_, synth) = try SynthKit.load(SynthKit.block(type))
			try ObjC.run { synth.setSelected(true) }
			let part = LDrawPart()
			part.setDisplayName("LS01.dat")
			try ObjC.run { synth.insert(part, at: 1) }
			out.append("\(type): class \(synth.lsynthClass()), inserted icon \(part.iconName() ?? "nil"), determineIconName \(synth.determineIconName(part) ?? "nil"), block still selected \(synth.isSelected()), subdirectives \(synth.subdirectives().count)")
		}
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "lsynth-coverage/insert.txt")
	}

	@Test("Removing a constraint deselects the block and its subdirectives")
	func removeConstraint() throws {
		let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		let constraint = try #require(synth.subdirectives().firstObject as? LDrawPart)
		try ObjC.run { constraint.setSelected(true) }
		#expect(synth.value(forKey: "subdirectiveSelected") as? Bool == true)
		try ObjC.run { synth.remove(constraint as LDrawDirective) }
		#expect(synth.subdirectives().count == 2)
		#expect(synth.value(forKey: "subdirectiveSelected") as? Bool == false)
		#expect(!synth.isSelected())
	}

	@Test("Drop target: accepts LSynth constraints and direction directives only; cleanup after the drop")
	func drop() throws {
		let (_, synth) = try SynthKit.load(SynthKit.block("PNEUMATIC_HOSE"))
		let constraint = LDrawPart(); constraint.setDisplayName("LS01.dat")
		let brick = LDrawPart(); brick.setDisplayName("3001.dat")
		let direction = LDrawLSynthDirective(); direction.setStringValue("INSIDE")
		#expect(synth.acceptsDroppedDirective(constraint))
		#expect(!synth.acceptsDroppedDirective(brick))
		#expect(synth.acceptsDroppedDirective(direction))
		#expect(!synth.acceptsDroppedDirective(LDrawComment()))

		// LDrawDocument calls this by selector on the old parent (donor YES) and the new parent (donor NO).
		try ObjC.run { synth.setSelected(true) }
		try ObjC.run { _ = synth.perform(NSSelectorFromString("cleanupAfterDropIsDonor:"), with: NSNumber(value: true)) }
		#expect(!synth.isSelected())
		#expect(synth.value(forKey: "subdirectiveSelected") as? Bool == false)
		try ObjC.run { _ = synth.perform(NSSelectorFromString("cleanupAfterDropIsDonor:"), with: NSNumber(value: false)) }
		#expect(synth.value(forKey: "subdirectiveSelected") as? Bool == true)
	}

	@Test("requiresResynthesis: (the handler for the notification sent when the LSynth executable or config changes) resynthesizes")
	func resynthesisNotification() throws {
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/15-lsynth-band.ldr"))
		let synth = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawLSynth }.first)
		#expect(synth.synthesizedPartsCount() == 0)
		// Called directly rather than by posting: blocks parsed by earlier tests are still alive (they outlive
		// their files; see freed()) and would all resynthesize too. -init registers the observer.
		try ObjC.run { _ = synth.perform(NSSelectorFromString("requiresResynthesis:"), with: nil) }
		#expect(synth.synthesizedPartsCount() > 0, "the band should have been synthesized")
	}

	// MARK: Moving, bounds, transform

	@Test("Nudging a block moves its constraints (not its direction directives) and marks it for resynthesis")
	func nudge() throws {
		let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		let displacement = synth.displacement(forNudge: V3Make(1, 0, 0))
		let before = SynthKit.lines(synth.write())
		let stored = SynthKit.synthesized(synth).map(ObjectIdentifier.init)
		try ObjC.run { synth.move(by: displacement) }
		let after = SynthKit.lines(synth.write())
		// Only directives: nothing can say how far a nudge goes.
		let directivesOnly = LDrawLSynth()
		let d = LDrawLSynthDirective(); d.setStringValue("INSIDE")
		directivesOnly.add(d)
		let none = directivesOnly.displacement(forNudge: V3Make(1, 0, 0))
		// The moved constraints told the block (receiveMessage:who:), so the next draw resynthesizes.
		try ObjC.run { synth.drawSelf(RecordingRenderer()) }
		let resynthesized = SynthKit.synthesized(synth).map(ObjectIdentifier.init) != stored
		let text = """
			displacement for nudge (1,0,0): \(displacement.x) \(displacement.y) \(displacement.z)
			displacement with no movable constraint: \(none.x) \(none.y) \(none.z)
			before:
			\(before)after:
			\(after)resynthesized on next draw: \(resynthesized)

			"""
		try Golden.check(Data(text.utf8), against: "lsynth-coverage/nudge.txt")
	}

	@Test("Bounding box is that of the constraints (synthesized parts are not included)")
	func bounds() throws {
		let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		let box = synth.boundingBox3()
		let f = { (v: Point3) in "\(v.x) \(v.y) \(v.z)" }
		let text = "min \(f(box.min)) max \(f(box.max))\n"
		try Golden.check(Data(text.utf8), against: "lsynth-coverage/bounds.txt")
	}

	@Test("A block has no transform of its own; its transform components decompose to the identity")
	func transform() throws {
		// LDrawDocument uses the last selected part's transformComponents for a newly added part or LSynth
		// constraint, and an LDrawLSynth can be that part (LDrawDocument+Outline.m drag and drop, LDrawDocument+ModelsMenu.m LSynth insertion).
		let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		let c = synth.transformComponents()
		let f = { (v: Point3) in [v.x, v.y, v.z] }
		#expect(f(c.scale) == [1, 1, 1] && f(c.rotate) == [0, 0, 0] && f(c.translate) == [0, 0, 0], "\(c)")
		#expect(c.shear_XY == 0 && c.shear_XZ == 0 && c.shear_YZ == 0, "\(c)")
		// The matrix behind it is all zeros: glTransformation is never written. Decomposing that singular
		// matrix gives up and leaves the identity components.
		#expect(M4.rows(synth.transformationMatrix()).flatMap { $0 }.allSatisfy { $0 == 0 })
	}

	@Test("A block is freed when its last owner releases it")
	func freed() throws {
		// Parsed on the calling thread. (Parsed through a file, the step parses on GCD worker threads and
		// -initWithLines: posts a notification whose object is the block, so the block lives until that
		// worker's autorelease pool drains: not deterministic enough to test.)
		weak var weakSynth: LDrawLSynth?
		autoreleasepool {
			let lines = SynthKit.block("RUBBER_BAND").components(separatedBy: "\n")
			let synth = LDrawLSynth(lines: lines, in: NSRange(location: 0, length: lines.count), parentGroup: nil)
			#expect(synth?.synthesizedPartsCount() == 2)
			weakSynth = synth
		}
		#expect(weakSynth == nil, "the LDrawLSynth leaked")
	}

	@Test("A custom LSynth executable path is used instead of the bundled one")
	func customExecutable() throws {
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/08b-lsynth-show.ldr"))
		let synth = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawLSynth }.first)
		// The bundled lsynthcp, named explicitly, with the bundled config: same result as the default.
		try ArgumentPrefs.with([LSYNTH_EXECUTABLE_PATH_KEY: LSynthCLI.executable.path,
								LSYNTH_CONFIGURATION_PATH_KEY: LSynthCLI.config]) {
			try ObjC.run { synth.synthesize() }
		}
		let custom = synth.synthesizedPartsCount()
		try ArgumentPrefs.with([LSYNTH_EXECUTABLE_PATH_KEY: "   ", LSYNTH_CONFIGURATION_PATH_KEY: ""]) {
			try ObjC.run { synth.synthesize() }
		}
		#expect(custom > 0)
		#expect(custom == synth.synthesizedPartsCount())
	}

	// MARK: Regex semantics (P4: RegexKitLite -> NSRegularExpression must not change them)

	@Test("Line patterns: unanchored search, case-sensitive, ICU \\s (tabs, runs of spaces, no-break space)")
	func linePatterns() throws {
		let beginnings: [(String, Bool)] = [
			("0 SYNTH BEGIN RUBBER_BAND 4", true),
			("0\tSYNTH  BEGIN \t RUBBER_BAND   4 trailing words", true),
			("0 SYNTH BEGIN RUBBER_BAND", false),          // no colour token
			("0 SYNTH BEGIN RUBBER_BAND ", false),
			("0 synth begin RUBBER_BAND 4", false),        // case-sensitive
			("10 SYNTH BEGIN A 4", true),                  // unanchored: found inside the line
			("0 // 0 SYNTH BEGIN A 4", true),
			("0 SYNTH BEGINNER A 4", false),
			("0 SYNTH BEGIN A\u{00A0}4", true),            // U+00A0 is \p{Z}, so \s
			("0SYNTH BEGIN A 4", false),
			("", false),
		]
		let terminators: [(String, Bool)] = [
			("0 SYNTH END", true),
			("0  SYNTH\tEND", true),
			("0 SYNTH ENDING", true),                       // no word boundary in the pattern
			("10 SYNTH END", true),
			("0 SYNTH SYNTHESIZED END", false),
			("0 synth end", false),
			("0 SYNTH", false),
			("", false),
		]
		var mismatches: [String] = []
		for (line, expected) in beginnings where LDrawLSynth.lineIsLSynthBeginning(line) != expected {
			mismatches.append("lineIsLSynthBeginning(\(line.debugDescription)) != \(expected)")
		}
		for (line, expected) in terminators where LDrawLSynth.lineIsLSynthTerminator(line) != expected {
			mismatches.append("lineIsLSynthTerminator(\(line.debugDescription)) != \(expected)")
		}
		#expect(mismatches.isEmpty, "\(mismatches.joined(separator: "\n"))")

		// Range of a block: from BEGIN through the first terminator match.
		let lines = ["0 SYNTH BEGIN A 4", "0 SYNTH SHOW", "0 SYNTH ENDING", "0 SYNTH END"]
		let range = LDrawLSynth.rangeOfDirectiveBeginning(at: 0, inLines: lines, maxIndex: UInt(lines.count - 1))
		#expect(range == NSRange(location: 0, length: 3), "\(range)")
		let notABlock = LDrawLSynth.rangeOfDirectiveBeginning(at: 0, inLines: ["0 SYNTH BEGIN A", "0 SYNTH END"], maxIndex: 1)
		#expect(notABlock == NSRange(location: 0, length: 0), "\(notABlock)")
	}

	@Test("Parsing: capture groups for type and colour, direction words, SHOW/HIDE prefixes, part lines")
	func parsePatterns() throws {
		// Tabs are deliberate here (SynthKit.load strips them), so parse through RoundTrip directly.
		func load(_ body: [String]) throws -> LDrawLSynth {
			let text = SynthKit.header + body.joined(separator: "\n") + "\n"
			let file = try #require(RoundTrip.load(Data(text.utf8)))
			return try #require(ObjectModel.all(file).compactMap { $0 as? LDrawLSynth }.first)
		}
		func summary(_ synth: LDrawLSynth) -> String {
			let children = (synth.subdirectives() as? [LDrawDirective]) ?? []
			let described = children.map { child -> String in
				if let d = child as? LDrawLSynthDirective { return "dir:\(d.stringValue() ?? "nil")" }
				return "\(type(of: child))"
			}
			return "type \(synth.lsynthType() ?? "nil") colour \(synth.lDrawColor()?.colorCode().rawValue ?? -1)"
				+ " children [\(described.joined(separator: " "))] synthesized \(synth.synthesizedPartsCount())"
		}
		let part = "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat"
		let cases: [([String], String)] = [
			(["0 SYNTH BEGIN  RUBBER_BAND\t4 extra", "0 SYNTH SHOW", part, "0 SYNTH END"],
			 "type RUBBER_BAND colour 4 children [LDrawPart] synthesized 0"),
			(["0 SYNTH BEGIN RUBBER_BAND 4x", "0 SYNTH SHOW", part, "0 SYNTH END"],
			 "type RUBBER_BAND colour 4 children [LDrawPart] synthesized 0"),
			// HIDES starts with HIDE: the unanchored (?:SHOW|HIDE) accepts it, so the part is a constraint.
			(["0 SYNTH BEGIN RUBBER_BAND 4", "0 SYNTH HIDES", part, "0 SYNTH END"],
			 "type RUBBER_BAND colour 4 children [LDrawPart] synthesized 0"),
			// HIDDEN doesn't match, so the block stays in its BEGIN state and the part is dropped (BUG-004).
			(["0 SYNTH BEGIN RUBBER_BAND 4", "0 SYNTH HIDDEN", part, "0 SYNTH END"],
			 "type RUBBER_BAND colour 4 children [] synthesized 0"),
			// The direction is the first INSIDE/OUTSIDE/CROSS anywhere in the line (no word boundaries).
			(["0 SYNTH BEGIN RUBBER_BAND 4", "0 SYNTH SHOW", part, "0 SYNTH  OUTSIDE INSIDE", "0 SYNTH INSIDEOUT",
			  "0 SYNTH\tCROSS", "0 SYNTH inside", part, "0 SYNTH END"],
			 "type RUBBER_BAND colour 4 children [LDrawPart dir:OUTSIDE dir:INSIDE dir:CROSS LDrawPart] synthesized 0"),
			(["0 SYNTH BEGIN RUBBER_BAND 4", "0 SYNTH SHOW", part,
			  "0 SYNTH SYNTHESIZED  BEGIN", part, "0 SYNTH\tSYNTHESIZED END", "0 SYNTH END"],
			 "type RUBBER_BAND colour 4 children [LDrawPart] synthesized 1"),
		]
		var mismatches: [String] = []
		for (body, expected) in cases {
			let got = summary(try load(body))
			if got != expected { mismatches.append("\(body):\n  expected \(expected)\n  got      \(got)") }
		}
		#expect(mismatches.isEmpty, "\(mismatches.joined(separator: "\n"))")
	}

	@Test("A whitespace-only executable or config path (tab, newline, U+3000) means the bundled lsynthcp")
	func whitespaceOnlyPaths() throws {
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/08b-lsynth-show.ldr"))
		let synth = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawLSynth }.first)
		try ObjC.run { synth.synthesize() }
		let bundled = synth.synthesizedPartsCount()
		#expect(bundled > 0)
		for blank in ["\t", " \n", "\u{3000}"] {
			try ArgumentPrefs.with([LSYNTH_EXECUTABLE_PATH_KEY: blank, LSYNTH_CONFIGURATION_PATH_KEY: blank]) {
				try ObjC.run { synth.synthesize() }
			}
			#expect(synth.synthesizedPartsCount() == bundled, "path \(blank.debugDescription)")
		}
	}

	// MARK: P6b pre-port

	/// How many times `synth` handles one LSynthSelectionDisplayDidChange notification: each handled one posts
	/// LDrawDirectiveDidChange for the block (-noteNeedsDisplay), so this counts its observer registrations.
	static func displayObserverCount(_ synth: LDrawLSynth) throws -> Int {
		var count = 0
		let token = NotificationCenter.default.addObserver(forName: Notification.Name("LDrawDirectiveDidChangeNotification"),
														   object: synth, queue: nil) { _ in count += 1 }
		defer { NotificationCenter.default.removeObserver(token) }
		try ObjC.run { NotificationCenter.default.post(name: .LSynthSelectionDisplayDidChange, object: nil) }
		return count
	}

	@Test("A new block: defaults, written form, display, bounds, drop rules (P6b pre-port)")
	func freshBlock() throws {
		let synth = LDrawLSynth()
		let box = synth.boundingBox3()
		let colour = synth.lDrawColor()
		let lines = [
			"class \(synth.lsynthClass()) type '\(synth.lsynthType() ?? "nil")' colour \(colour.map { "\($0.colorCode().rawValue)" } ?? "nil")",
			"synthesized \(synth.synthesizedPartsCount()) hidden \(synth.isHidden()) selected \(synth.isSelected())",
			"browsing '\(synth.browsingDescription() ?? "nil")' icon \(synth.iconName() ?? "nil") inspector \(synth.inspectorClassName() ?? "nil")",
			"bounds \(box.min.x) \(box.min.y) \(box.min.z) \(box.max.x) \(box.max.y) \(box.max.z)",
			"determineIconName \(synth.determineIconName(nil) ?? "nil")",
			"written: " + SynthKit.lines(synth.write()).replacingOccurrences(of: "\n", with: " / "),
			"observers \(try Self.displayObserverCount(synth))",
		]
		let actual = lines.joined(separator: "\n")
		#expect(actual == Self.expectedFresh, "\(actual)")
	}

	static let expectedFresh = #"""
		class 0 type '' colour -1
		synthesized 0 hidden false selected false
		browsing '' icon LSynthPart inspector InspectionLSynth
		bounds inf inf inf -inf -inf -inf
		determineIconName Brick
		written: 0 SYNTH BEGIN  -1 / 0 SYNTH SHOW / 0 SYNTH END / 
		observers 1
		"""#

	@Test("Parsed blocks register the preference observers twice (S32), new, copied and decoded ones once (P6b pre-port)")
	func observerRegistrations() throws {
		let (_, parsed) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		#expect(try Self.displayObserverCount(parsed) == 2)
		let lines = SynthKit.block("PNEUMATIC_HOSE").components(separatedBy: "\n")
		let direct = try #require(LDrawLSynth(lines: lines, in: NSRange(location: 0, length: lines.count), parentGroup: nil))
		#expect(try Self.displayObserverCount(direct) == 2)
		let copied = try #require(parsed.copy() as? LDrawLSynth)
		#expect(try Self.displayObserverCount(copied) == 1)
		let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(parsed)) as? LDrawLSynth)
		#expect(try Self.displayObserverCount(decoded) == 1)
	}

	@Test("Keyed archive keeps type, class, colour and constraints (not synthesized parts) and resynthesizes on draw; copy keeps only the children (P6b pre-port)")
	func archiveAndCopy() throws {
		try OffscreenGL.makeCurrent()
		let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		try ObjC.run { synth.setSelected(true) }
		let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(synth)) as? LDrawLSynth)
		#expect(decoded.lsynthType() == "RUBBER_BAND")
		#expect(decoded.lsynthClass() == synth.lsynthClass())
		#expect(decoded.lDrawColor()?.colorCode().rawValue == 4)
		#expect(decoded.synthesizedPartsCount() == 0)
		#expect(decoded.subdirectives().count == 3)
		#expect(decoded.isSelected() == false)
		#expect(decoded.subdirectives().compactMap { ($0 as? LDrawDirective)?.iconName() } == ["LSynthBandConstraint", "LSynthDirection", "LSynthBandConstraint"])
		// A decoded hose with real constraints resynthesizes on its first draw.
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/08b-lsynth-show.ldr"))
		let hose = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawLSynth }.first)
		let decodedHose = try #require(try ObjectModel.unarchive(ObjectModel.archive(hose)) as? LDrawLSynth)
		#expect(decodedHose.synthesizedPartsCount() == 0)
		try ObjC.run { decodedHose.drawSelf(RecordingRenderer()) }
		#expect(decodedHose.synthesizedPartsCount() > 0, "a decoded block resynthesizes on its first draw")

		let copied = try #require(synth.copy() as? LDrawLSynth)
		let text = [
			"copy: class \(copied.lsynthClass()) type '\(copied.lsynthType() ?? "nil")' colour \(copied.lDrawColor()?.colorCode().rawValue ?? -1) selected \(copied.isSelected()) synthesized \(copied.synthesizedPartsCount())",
			"icons: " + copied.subdirectives().compactMap { ($0 as? LDrawDirective)?.iconName() }.joined(separator: " "),
			"written: " + SynthKit.lines(copied.write()).replacingOccurrences(of: "\n", with: " / "),
		].joined(separator: "\n")
		#expect(text == Self.expectedCopy, "\(text)")
	}

	static let expectedCopy = #"""
		copy: class 0 type '' colour -1 selected false synthesized 0
		icons: Brick LSynthDirection Brick
		written: 0 SYNTH BEGIN  -1 / 0 SYNTH SHOW / 1 4 50 0 0 1 0 0 0 1 0 0 0 1 3003.dat / 0 SYNTH OUTSIDE / 1 4 -50 0 0 1 0 0 0 1 0 0 0 1 3003.dat / 0 SYNTH END / 
		"""#

	@Test("'Save Synthesized Parts' is compared with YES (1): other values omit the block (P6b pre-port)", arguments: [0, 1, 2, -1])
	func saveSynthesizedValues(value: Int) throws {
		let (_, synth) = try SynthKit.load(SynthKit.block("RUBBER_BAND"))
		let written = ArgumentPrefs.with([LSYNTH_SAVE_SYNTHESIZED_PARTS_KEY: value]) { SynthKit.lines(synth.write()) }
		#expect(written.contains("0 SYNTH SYNTHESIZED BEGIN") == (value == 1), "\(written)")
	}

	@Test("Mutating accessors: class, type, hidden, colour; hidden invalidates; colour recolours selected parts (P6b pre-port)")
	func accessors() throws {
		let (_, synth) = try SynthKit.load(SynthKit.block("PNEUMATIC_HOSE"))
		synth.setLsynthClass(3)
		#expect(synth.lsynthClass() == 3)
		#expect(synth.determineIconName(nil) == "LSynthBandConstraint")
		synth.setLsynthClass(2)
		#expect(synth.determineIconName(nil) == "LSynthHoseConstraint")
		synth.setLsynthClass(1)
		synth.setLsynthType("PLI_TECHNIC_TREAD")
		#expect(synth.determineIconName(nil) == "LSynthBandConstraint")
		synth.setLsynthType("PLI_HOSE_FLEXIBLE_12L")
		#expect(synth.determineIconName(nil) == "LSynthHoseConstraint")
		synth.setLsynthType("NOT_A_PART")
		#expect(synth.determineIconName(nil) == "Brick")
		synth.setLsynthClass(9)
		#expect(synth.determineIconName(nil) == "Brick")
		synth.setLsynthType(nil)
		#expect(synth.lsynthType() == nil)
		#expect(SynthKit.lines(synth.write()).hasPrefix("0 SYNTH BEGIN (null) 4\n"), "\(synth.write() ?? "nil")")
		synth.setHidden(true)
		synth.setHidden(true)
		#expect(synth.isHidden())
		let blue = try #require(ColorLibrary.shared()?.color(forCode: LDrawColorT(rawValue: 1)))
		synth.setLDrawColor(blue)
		#expect(SynthKit.synthesized(synth).allSatisfy { $0.lDrawColor()?.colorCode().rawValue == 1 })
		synth.setLDrawColor(nil)
		#expect(synth.lDrawColor() == nil)
		#expect(SynthKit.lines(synth.write()).hasPrefix("0 SYNTH BEGIN (null) 0\n"), "\(synth.write() ?? "nil")")
	}

	@Test("Auto-hull preparation (no live caller): one entry per tangent point, none in the hull yet (P6b pre-port)")
	func autoHullData() throws {
		let (_, synth) = try SynthKit.load("""
			0 SYNTH BEGIN RUBBER_BAND 4
			0 SYNTH SHOW
			1 4 -50 0 0 1 0 0 0 1 0 0 0 1 LS01.dat
			1 4 50 0 0 1 0 0 0 1 0 0 0 1 LS01.dat
			1 4 0 0 60 1 0 0 0 1 0 0 0 1 LS01.dat
			0 SYNTH END
			""")
		let data = try #require(try ObjC.run { synth.prepareAutoHullData() })
		let rows = data.map { entry -> String in
			let d = entry as! NSDictionary
			return "\(d["x"]!) \(d["y"]!) \(d["inHull"]!) \((d["directive"] as AnyObject) is LDrawPart)"
		}
		let actual = rows.joined(separator: "\n")
		#expect(actual == Self.expectedHull, "\(actual)")
	}

	static let expectedHull = #"""
		0 0 0 true
		0 0 0 true
		0 0 0 true
		0 0 0 true
		100 0 0 true
		100 0 0 true
		100 0 0 true
		100 0 0 true
		50 0 0 true
		50 0 0 true
		50 0 0 true
		50 0 0 true
		"""#
}
