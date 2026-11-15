//
//  PrimitiveEditingTests.swift
//  BricksmithTests
//
//  P2 exit (coverage): editing primitives the way the UI does it.
//    - drag handles: selecting a line/triangle/quad/conditional line/texture creates one handle per
//      vertex (plane point); moving a handle calls -dragHandleChanged: on the primitive.
//    - nudge and move (LDrawMovableDirective), undo registration (-registerUndoActions:).
//    - bowtie quads are re-ordered on parse (-fixBowtie).
//    - -optimizeStructure (how library parts are flattened when loaded).
//  Goldens: golden/editing/*.
//

import Foundation
import Testing
@testable import Bricksmith

enum Prim {
	/// The first directive parsed from `text` (one or more LDraw lines), through the normal parser.
	static func parse(_ text: String) throws -> LDrawDirective {
		// A header first: otherwise a leading "0 ..." line would become the model's title.
		let header = "0 Primitive\n0 Name: prim.ldr\n0 Author: Fixture Author\n"
		let file = try #require(RoundTrip.load(Data((header + text + "\n").utf8)))
		return try #require(ObjectModel.all(file).first { !($0 is LDrawFile || $0 is LDrawModel || $0 is LDrawStep) })
	}

	static func write(_ d: LDrawDirective) -> String { d.write().replacingOccurrences(of: "\r\n", with: "\n") }

	/// One of each editable primitive, with its handle count.
	static let editable: [(name: String, text: String, handles: Int)] = [
		("line", "2 24 0 0 0 10 0 0", 2),
		("triangle", "3 16 0 0 0 10 0 0 0 10 0", 3),
		("quad", "4 16 0 0 0 10 0 0 10 10 0 0 10 0", 4),
		("conditional line", "5 24 0 0 0 10 0 0 0 5 0 0 -5 0", 2),   // inherits LDrawLine's two handles; control points have none
		("texture", "0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 sticker.png\n3 16 -10 0 -10 10 0 -10 10 0 10\n0 !TEXMAP END", 3),
	]
}

extension DrawHarness {
	nonisolated static func stepSync(_ file: LDrawFile) throws -> LDrawStep {
		try #require(file.activeModel().steps().first as? LDrawStep)
	}
}

@MainActor
@Suite("Editing primitives: handles, move, nudge, undo, bowtie, optimise (P2 exit)", .fixtureLibrary, .serialized)
struct PrimitiveEditingTests {
	/// Drag handles build their GL sphere mesh when created, and textures ask for a GL texture.
	init() throws { try OffscreenGL.makeCurrent() }

	@Test("Moving each drag handle moves that vertex")
	func dragHandles() throws {
		var out: [String] = []
		for (name, text, handles) in Prim.editable {
			out.append("## \(name): \(Prim.write(try Prim.parse(text)))")
			for tag in 1...handles {
				let prim = try Prim.parse(text)
				prim.setSelected(true)
				let handle = try #require(LDrawDragHandle(tag: tag, position: V3Make(0, 0, 0)))
				handle.setTarget(prim)
				handle.setAction(NSSelectorFromString("dragHandleChanged:"))
				try ObjC.run { handle.setPosition(V3Make(Float(tag), 100, -7), updateTarget: true) }
				out.append("handle \(tag) -> (\(tag), 100, -7): \(Prim.write(prim))")
			}
		}
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "editing/drag-handles.txt")
	}

	@Test("Nudge displacement and moveBy, for primitives and a part")
	func moveAndNudge() throws {
		var out: [String] = []
		let cases = Prim.editable.map { ($0.name, $0.text) } + [("part", "1 4 10 0 0 0 0 1 0 1 0 -1 0 0 3005.dat")]
		for (name, text) in cases {
			let prim = try Prim.parse(text)
			guard let movable = prim as? LDrawMovableDirective else { out.append("\(name): not movable"); continue }
			let nudge = movable.displacement(forNudge: V3Make(1, 0, 0))
			try ObjC.run { movable.move(by: V3Make(1, 2, 3)) }
			out.append("\(name): nudge (1,0,0) -> (\(nudge.x), \(nudge.y), \(nudge.z)); moveBy (1,2,3): \(Prim.write(prim))")
		}
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "editing/move.txt")
	}

	@Test("Moving a conditional line moves its end points as well as its control points")
	func conditionalLineMove() throws {
		let line = try Prim.parse("5 24 0 0 0 10 0 0 0 5 0 0 -5 0")
		try ObjC.run { (line as! LDrawMovableDirective).move(by: V3Make(1, 2, 3)) }
		withKnownIssue("BUG-018: -[LDrawConditionalLine moveBy:] moves only the control points (no [super moveBy:])") {
			#expect(Prim.write(line) == "5 24 1 2 3 11 2 3 1 7 3 1 -3 3")
		}
	}

	@Test("registerUndoActions: then an edit, then undo, restores the directive")
	func undo() throws {
		var out: [String] = []
		// Textures are left out: nothing in the app edits a texture's own attributes (no inspector, and only
		// LDrawTexture.m calls its setters), and it registers no undo for them.
		let edits: [(String, String, (LDrawDirective) -> Void)] = Prim.editable.filter { $0.name != "texture" }.map { e in
			(e.name, e.text, { ($0 as! LDrawMovableDirective).move(by: V3Make(1, 2, 3)) })
		} + [
			("part", "1 4 10 0 0 1 0 0 0 1 0 0 0 1 3005.dat", { ($0 as! LDrawPart).setDisplayName("3001.dat") }),
			("comment", "0 // a comment", { ($0 as! LDrawComment).setStringValue("changed") }),
			("meta command", "0 UNKNOWN META", { ($0 as! LDrawMetaCommand).setStringValue("CHANGED") }),
		]
		for (name, text, edit) in edits {
			let prim = try Prim.parse(text)
			let before = Prim.write(prim)
			let undo = UndoManager()
			undo.groupsByEvent = false
			undo.beginUndoGrouping()
			try ObjC.run { prim.registerUndoActions(undo); edit(prim) }
			undo.endUndoGrouping()
			let edited = Prim.write(prim)
			let action = undo.undoActionName
			try ObjC.run { undo.undo() }
			#expect(Prim.write(prim) == before, "\(name): undo did not restore")
			out.append("\(name): action \"\(action)\"; edited: \(edited)")
		}
		// Containers: step rotation, model description, MPD model name.
		let mpd = try #require(RoundTrip.load(try Data(contentsOf: FixturePaths.fixtures.appendingPathComponent("ldr/05-multipart.mpd"))))
		let model = try #require(mpd.activeModel())
		let step = try DrawHarness.stepSync(mpd)
		let containers: [(String, LDrawDirective, () -> Void)] = [
			("step", step, { step.setStepRotationType(.relative); step.setRotationAngle(V3Make(10, 20, 30)) }),
			("model", model, { model.setModelDescription("changed description") }),
			("mpd model", model, { (model as! LDrawMPDModel).setModelName("renamed.ldr") }),
		]
		for (name, directive, edit) in containers {
			let before = mpd.write()
			let undo = UndoManager()
			undo.groupsByEvent = false
			undo.beginUndoGrouping()
			try ObjC.run { directive.registerUndoActions(undo); edit() }
			undo.endUndoGrouping()
			let action = undo.undoActionName
			try ObjC.run { undo.undo() }
			#expect(mpd.write() == before, "\(name): undo did not restore")
			out.append("\(name): action \"\(action)\"")
		}
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "editing/undo.txt")
	}

	@Test("Bowtie quads are re-ordered when parsed")
	func bowtie() throws {
		// Unit square corners A(0,0) B(10,0) C(10,10) D(0,10) in every order that starts at A.
		let orders = ["0 0 0 10 0 0 10 10 0 0 10 0", "0 0 0 10 0 0 0 10 0 10 10 0", "0 0 0 10 10 0 10 0 0 0 10 0",
					  "0 0 0 10 10 0 0 10 0 10 0 0", "0 0 0 0 10 0 10 0 0 10 10 0", "0 0 0 0 10 0 10 10 0 10 0 0"]
		let out = try orders.map { "4 16 \($0) -> \(Prim.write(try Prim.parse("4 16 \($0)")))" }
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "editing/bowtie.txt")
	}

	@Test("optimizeStructure flattens parts, textures and submodels into sorted steps")
	func optimize() throws {
		let text = HitLayout.text.replacingOccurrences(of: "\t", with: "")
		let file = try #require(RoundTrip.load(Data(text.utf8)))
		try ObjC.run { file.optimizeStructure() }
		try Golden.check(RoundTrip.save(file), against: "editing/optimized.ldr")
	}
}
