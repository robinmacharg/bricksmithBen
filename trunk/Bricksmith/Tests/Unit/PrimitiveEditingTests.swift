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

// MARK: - P6a pins: drag handles and primitive geometry

/// Records the action a drag handle sends to its target.
final class HandleActionRecorder: NSObject {
	var calls: [String] = []
	@objc(handleMoved:) func handleMoved(_ sender: Any) {
		guard let handle = sender as? LDrawDragHandle else { calls.append("sender \(type(of: sender))"); return }
		calls.append("tag \(handle.tag()) at \(P6a.p(handle.position()))")
	}
}

enum P6a {
	static func p(_ v: Point3) -> String { "(\(RecordingRenderer.fmt(v.x)), \(RecordingRenderer.fmt(v.y)), \(RecordingRenderer.fmt(v.z)))" }

	static func line<T: LDrawDirective>(_ type: T.Type, _ text: String) -> T? {
		T(lines: [text], in: NSRange(location: 0, length: 1), parentGroup: nil)
	}

	/// The objects registered in a hit dictionary or set (keys are NSValue-wrapped pointers).
	static func objects(_ keys: [Any]) -> [AnyObject] {
		keys.map { Unmanaged<AnyObject>.fromOpaque(($0 as! NSValue).pointerValue!).takeUnretainedValue() }
	}

	static func describe(_ object: AnyObject?) -> String {
		guard let object else { return "nothing" }
		if let handle = object as? LDrawDragHandle { return "handle \(handle.tag())" }
		return "\(type(of: object))"
	}

	static func ray(_ x: Float, _ y: Float) -> Ray3 { Ray3(origin: V3Make(x, y, 100), direction: V3Make(0, 0, -1)) }

	static func collect(_ d: LDrawDirective) -> [String] {
		let r = RecordingRenderer()
		d.collectSelf(r)
		return r.log
	}

	static let tri = "3 16 0 0 0 10 0 0 0 10 0"
	static let quad = "4 16 0 0 0 10 0 0 10 10 0 0 10 0"
}

@MainActor
@Suite("Drag handles and primitive geometry (P6a pins)", .fixtureLibrary, .serialized)
struct P6aGeometryPinTests {

	// MARK: LDrawDragHandle

	@Test("A drag handle keeps its tag, its position and the position it started at")
	func handleState() throws {
		let handle = try #require(LDrawDragHandle(tag: 7, position: V3Make(1, 2, 3)))
		#expect(handle.tag() == 7)
		#expect(P6a.p(handle.position()) == "(1, 2, 3)")
		#expect(P6a.p(handle.initialPosition()) == "(1, 2, 3)")
		#expect(handle.isSelected(), "handles always report being selected")
		#expect(handle.target() == nil)
		handle.setPosition(V3Make(4, 5, 6), updateTarget: false)
		#expect(P6a.p(handle.position()) == "(4, 5, 6)")
		#expect(P6a.p(handle.initialPosition()) == "(1, 2, 3)", "initialPosition doesn't follow the handle")
		handle.setSelected(false)
		#expect(handle.isSelected())
	}

	@Test("Moving a handle sends its action to its target only when asked; moveBy always does")
	func handleTargetAction() throws {
		let handle = try #require(LDrawDragHandle(tag: 2, position: V3Make(1, 1, 1)))
		// No target: updating is a no-op.
		try ObjC.run { handle.setPosition(V3Make(0, 0, 0), updateTarget: true) }
		let recorder = HandleActionRecorder()
		handle.setTarget(recorder)
		handle.setAction(#selector(HandleActionRecorder.handleMoved(_:)))
		#expect((handle.target() as AnyObject?) === recorder)
		try ObjC.run { handle.setPosition(V3Make(1, 2, 3), updateTarget: false) }
		#expect(recorder.calls.isEmpty)
		try ObjC.run { handle.setPosition(V3Make(4, 5, 6), updateTarget: true) }
		try ObjC.run { (handle as LDrawMovableDirective).move(by: V3Make(1, -1, 0.5)) }
		#expect(recorder.calls == ["tag 2 at (4, 5, 6)", "tag 2 at (5, 4, 6.5)"])
		#expect(P6a.p(handle.position()) == "(5, 4, 6.5)")
		#expect(P6a.p(handle.initialPosition()) == "(1, 1, 1)")
	}

	@Test("A drag handle holds its target strongly")
	func handleTargetIsStrong() throws {
		let handle = try #require(LDrawDragHandle(tag: 1, position: V3Make(0, 0, 0)))
		weak var weakTarget: HandleActionRecorder?
		autoreleasepool {
			let recorder = HandleActionRecorder()
			handle.setTarget(recorder)
			weakTarget = recorder
		}
		#expect(weakTarget != nil, "the handle no longer retains its target")
		autoreleasepool { handle.setTarget(nil) }
		#expect(weakTarget == nil, "clearing the target didn't release it")
	}

	@Test("A drag handle draws a sphere of half its diameter at its position")
	func handleDraw() throws {
		let handle = try #require(LDrawDragHandle(tag: 1, position: V3Make(1, -2, 3.5)))
		let renderer = RecordingRenderer()
		try ObjC.run { handle.drawSelf(renderer) }
		#expect(renderer.log == ["drawDragHandle [1 -2 3.5] size 3.5"])
	}

	@Test("Ray picking a drag handle: radius 7/2 * 1.5 / viewScale, ignoring the transform")
	func handleHitTest() throws {
		let handle = try #require(LDrawDragHandle(tag: 1, position: V3Make(0, 0, 0)))
		let scaled = M4.make([[2, 0, 0, 0], [0, 2, 0, 0], [0, 0, 2, 0], [50, 50, 50, 1]])
		func hit(_ x: Float, scale: Float, credit: AnyObject? = nil) throws -> String {
			let hits = NSMutableDictionary()
			try ObjC.run {
				handle.hitTest(P6a.ray(x, 0), transform: scaled, viewScale: scale, boundsOnly: false, creditObject: credit, hits: hits)
			}
			guard hits.count > 0 else { return "miss" }
			let depth = (hits.allValues.first as! NSNumber).floatValue
			return "\(P6a.objects(hits.allKeys).map(P6a.describe)) depth \(RecordingRenderer.fmt(depth))"
		}
		var expected: Float = 0
		#expect(V3RayIntersectsSphere(P6a.ray(5.2, 0), V3Make(0, 0, 0), 5.25, &expected))
		#expect(try hit(5.2, scale: 1) == "[\"handle 1\"] depth \(RecordingRenderer.fmt(expected))")
		#expect(try hit(5.3, scale: 1) == "miss")
		#expect(try hit(2.6, scale: 2) != "miss")
		#expect(try hit(2.65, scale: 2) == "miss")
		let credit = NSObject()
		do { let got = try hit(0, scale: 1, credit: credit); #expect(got == "[\"NSObject\"] depth 94.75") }
	}

	@Test("Click picking a drag handle compares its projected depth with <=")
	func handleDepthTest() throws {
		let handle = try #require(LDrawDragHandle(tag: 3, position: V3Make(10, 20, -30)))
		let transform = HitLayout.transform
		let projected = V3MulPointByProjMatrix(V3Make(10, 20, -30), transform)
		let around = Box2(origin: Point2(x: projected.x - 0.01, y: projected.y - 0.01), size: Size2(width: 0.02, height: 0.02))
		let elsewhere = Box2(origin: Point2(x: 0.5, y: 0.5), size: Size2(width: 0.02, height: 0.02))
		func pick(_ box: Box2, depth start: Float, credit: AnyObject? = nil) throws -> String {
			var best: AnyObject? = nil
			var depth = start
			try ObjC.run {
				handle.depthTest(Point2(x: projected.x, y: projected.y), inBox: box, transform: transform,
								 creditObject: credit, bestObject: &best, bestDepth: &depth)
			}
			return "\(P6a.describe(best)) \(depth == start ? "same depth" : "depth \(RecordingRenderer.fmt(depth))")"
		}
		#expect(try pick(around, depth: 1) == "handle 3 depth \(RecordingRenderer.fmt(projected.z))")
		#expect(try pick(around, depth: projected.z) == "handle 3 same depth", "equal depth still wins (<=)")
		#expect(try pick(around, depth: projected.z - 0.001) == "nothing same depth")
		#expect(try pick(elsewhere, depth: 1) == "nothing same depth")
		#expect(try pick(around, depth: 1, credit: NSObject()) == "NSObject depth \(RecordingRenderer.fmt(projected.z))")
	}

	// MARK: Triangle, quadrilateral, conditional line

	@Test("Parsing a line of the wrong type gives nil; the parse reads the line at range.location")
	func parseWrongType() throws {
		#expect(P6a.line(LDrawTriangle.self, "4 16 0 0 0 1 0 0 1 1 0 0 1 0") == nil)
		#expect(P6a.line(LDrawQuadrilateral.self, P6a.tri) == nil)
		#expect(P6a.line(LDrawConditionalLine.self, "2 24 0 0 0 1 0 0") == nil)
		let tri = try #require(LDrawTriangle(lines: ["0 // skipped", "3 4 1 2 3 4 5 6 7 8 9"], in: NSRange(location: 1, length: 1), parentGroup: nil))
		#expect(Prim.write(tri) == "3 4 1 2 3 4 5 6 7 8 9")
		let quad = try #require(LDrawQuadrilateral(lines: ["0 // skipped", P6a.quad], in: NSRange(location: 1, length: 1), parentGroup: nil))
		#expect(Prim.write(quad) == P6a.quad)
		let cond = try #require(LDrawConditionalLine(lines: ["0 // skipped", "5 24 1 2 3 4 5 6 7 8 9 10 11 12"], in: NSRange(location: 1, length: 1), parentGroup: nil))
		#expect(Prim.write(cond) == "5 24 1 2 3 4 5 6 7 8 9 10 11 12")
		#expect(P6a.p(cond.conditionalVertex1()) == "(7, 8, 9)")
		#expect(P6a.p(cond.conditionalVertex2()) == "(10, 11, 12)")
	}

	@Test("Collecting a triangle or quad: current, complement and RGBA colours, normal, and hidden")
	func collectColours() throws {
		for (text, kind, coords) in [(P6a.tri, "tri", "0 0 0 10 0 0 0 10 0"), (P6a.quad, "quad", "0 0 0 10 0 0 10 10 0 0 10 0")] {
			let body = text.dropFirst(5)   // "3 16 " / "4 16 "
			let head = String(text.prefix(1))
			#expect(P6a.collect(try Prim.parse(text)) == ["\(kind) [\(coords)] n [0 0 100] current"])
			#expect(P6a.collect(try Prim.parse("\(head) 24 \(body)")) == ["\(kind) [\(coords)] n [0 0 100] complement"])
			let red = try Prim.parse("\(head) 4 \(body)")
			let log = P6a.collect(red)
			#expect(log.count == 1 && log[0].hasPrefix("\(kind) [\(coords)] n [0 0 100] rgba("), "\(log)")
			var rgba: (GLfloat, GLfloat, GLfloat, GLfloat) = (0, 0, 0, 0)
			withUnsafeMutablePointer(to: &rgba) { $0.withMemoryRebound(to: GLfloat.self, capacity: 4) { (red as! LDrawColorable).lDrawColor().getRGBA($0) } }
			#expect(log.first?.hasSuffix("rgba(\([rgba.0, rgba.1, rgba.2, rgba.3].map(RecordingRenderer.fmt).joined(separator: " ")))") == true)
			let hidden = try Prim.parse(text) as! LDrawDrawableElement
			hidden.setHidden(true)
			#expect(P6a.collect(hidden).isEmpty)
		}
	}

	@Test("Archiving keeps the stored normal; copying recomputes it through the setters")
	func archiveAndCopyNormal() throws {
		// A bowtie fixed on parse: the stored normal comes from the pre-fix vertex order.
		let bowtie = try Prim.parse("4 16 0 0 0 10 0 0 0 10 0 10 10 0")
		let original = P6a.collect(bowtie)
		let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(bowtie)) as? LDrawQuadrilateral)
		#expect(P6a.collect(decoded) == original)
		let copied = try #require(bowtie.copy() as? LDrawQuadrilateral)
		#expect(Prim.write(copied) == Prim.write(bowtie))
		#expect(original == ["quad [0 0 0 10 0 0 10 10 0 0 10 0] n [0 0 100] current"])
		#expect(P6a.collect(copied) == original)
		for text in [P6a.tri, "5 24 0 0 0 10 0 0 0 5 0 0 -5 0"] {
			let prim = try Prim.parse(text)
			let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(prim)) as? LDrawDirective)
			#expect(Prim.write(decoded) == text)
			#expect(P6a.collect(decoded) == P6a.collect(prim))
			let copied = try #require(prim.copy() as? LDrawDirective)
			#expect(Prim.write(copied) == text)
			#expect(type(of: copied) == type(of: prim))
		}
	}

	@Test("Ray picking a triangle and both halves of a quad, with credit, hidden, and handles when selected")
	func rayHitTest() throws {
		func hit(_ d: LDrawDirective, _ x: Float, _ y: Float, credit: AnyObject? = nil) throws -> String {
			let hits = NSMutableDictionary()
			try ObjC.run {
				d.hitTest(P6a.ray(x, y), transform: IdentityMatrix4, viewScale: 1, boundsOnly: false, creditObject: credit, hits: hits)
			}
			guard hits.count > 0 else { return "miss" }
			let depths = hits.allValues.map { RecordingRenderer.fmt(($0 as! NSNumber).floatValue) }
			return "\(P6a.objects(hits.allKeys).map(P6a.describe).sorted()) depth \(depths.sorted())"
		}
		let tri = try Prim.parse(P6a.tri), quad = try Prim.parse(P6a.quad)
		#expect(try hit(tri, 2, 2) == "[\"LDrawTriangle\"] depth [\"100\"]")
		#expect(try hit(tri, 8, 8) == "miss")
		#expect(try hit(quad, 8, 2) == "[\"LDrawQuadrilateral\"] depth [\"100\"]", "first half (1 2 3)")
		#expect(try hit(quad, 2, 8) == "[\"LDrawQuadrilateral\"] depth [\"100\"]", "second half (3 4 1)")
		#expect(try hit(quad, 12, 2) == "miss")
		#expect(try hit(quad, 2, 8, credit: NSObject()) == "[\"NSObject\"] depth [\"100\"]")
		(quad as! LDrawDrawableElement).setHidden(true)
		#expect(try hit(quad, 2, 8) == "miss")
		// Selected: a handle sphere (radius 5.25) is picked even outside the triangle, credited to itself.
		try ObjC.run { tri.setSelected(true) }
		do { let got = try hit(tri, 10.5, 0.5, credit: NSObject()); #expect(got == "[\"handle 2\"] depth [\"94.798\"]") }
		do { let got = try hit(tri, 2, 2); #expect(got == "[\"LDrawTriangle\", \"handle 1\"] depth [\"100\", \"95.577\"]") }
		try ObjC.run { tri.setSelected(false) }
		#expect(try hit(tri, 10.5, 0.5) == "miss")
	}

	@Test("Marquee: a hit stops the walk only when there is a credit object")
	func boxTestCredit() throws {
		let all = Box2(origin: Point2(x: -1, y: -1), size: Size2(width: 2, height: 2))
		for text in [P6a.tri, P6a.quad] {
			let prim = try Prim.parse(text)
			for credit in [nil, NSObject()] as [AnyObject?] {
				let hits = NSMutableSet()
				var stop = false
				try ObjC.run { stop = prim.boxTest(all, transform: HitLayout.transform, boundsOnly: false, creditObject: credit, hits: hits) }
				#expect(stop == (credit != nil), "\(text) credit \(String(describing: credit))")
				#expect(P6a.objects(hits.allObjects).map(P6a.describe) == [credit == nil ? "\(type(of: prim))" : "NSObject"])
			}
			(prim as! LDrawDrawableElement).setHidden(true)
			let hits = NSMutableSet()
			var stop = true
			try ObjC.run { stop = prim.boxTest(all, transform: HitLayout.transform, boundsOnly: false, creditObject: NSObject(), hits: hits) }
			#expect(!stop && hits.count == 0)
		}
	}

	@Test("Click picking a selected triangle or quad reaches its handles, which get the credit object")
	func depthTestHandles() throws {
		// Clicks just inside the corner; the click box (±0.01) reaches the corner's handle.
		for (text, corner, tag) in [(P6a.tri, Point2(x: 0.095, y: -0.002), 2), (P6a.quad, Point2(x: 0.095, y: -0.095), 3)] {
			let prim = try Prim.parse(text)
			func pick(credit: AnyObject? = nil) throws -> String {
				var best: AnyObject? = nil
				var depth: Float = 1
				try ObjC.run {
					prim.depthTest(corner, inBox: Box2(origin: Point2(x: corner.x - 0.01, y: corner.y - 0.01), size: Size2(width: 0.02, height: 0.02)),
								   transform: HitLayout.transform, creditObject: credit, bestObject: &best, bestDepth: &depth)
				}
				return P6a.describe(best)
			}
			do { let got = try pick(); #expect(got == "\(type(of: prim))") }
			try ObjC.run { prim.setSelected(true) }
			#expect(try pick() == "handle \(tag)")
			#expect(try pick(credit: NSObject()) == "NSObject")
			(prim as! LDrawDrawableElement).setHidden(true)
			#expect(try pick() == "nothing", "hidden primitives skip their handles too")
		}
	}

	@Test("Vertex buffers: triangles, quads (untesselated) and their wireframes; conditional lines write nothing")
	func vertexBuffers() throws {
		let colour = try #require(ColorLibrary.shared()!.color(forCode: LDrawColorT(rawValue: 4)))
		var rgba: (GLfloat, GLfloat, GLfloat, GLfloat) = (0, 0, 0, 0)
		withUnsafeMutablePointer(to: &rgba) { $0.withMemoryRebound(to: GLfloat.self, capacity: 4) { colour.getRGBA($0) } }
		let rgbaText = [rgba.0, rgba.1, rgba.2, rgba.3].map(RecordingRenderer.fmt).joined(separator: " ")
		func write(_ text: String, wireframe: Bool) throws -> [String] {
			let prim = try #require(try Prim.parse(text) as? LDrawDrawableElement)
			let buffer = UnsafeMutablePointer<VBOVertexData>.allocate(capacity: 10)
			defer { buffer.deallocate() }
			buffer.initialize(repeating: VBOVertexData(), count: 10)
			guard let end = prim.write(toVertexBuffer: buffer, with: colour, wireframe: wireframe) else { return ["nil"] }
			return (0..<(end - buffer)).map { i in
				let v = buffer[i]
				let c = [v.color.0, v.color.1, v.color.2, v.color.3].map(RecordingRenderer.fmt).joined(separator: " ")
				return "\(P6a.p(V3Make(v.position.0, v.position.1, v.position.2))) n \(P6a.p(V3Make(v.normal.0, v.normal.1, v.normal.2)))"
					+ (c == rgbaText ? "" : " colour \(c)")
			}
		}
		let a = "(0, 0, 0) n (0, 0, 100)", b = "(10, 0, 0) n (0, 0, 100)", c = "(10, 10, 0) n (0, 0, 100)", d = "(0, 10, 0) n (0, 0, 100)"
		#expect(try write(P6a.tri, wireframe: false) == [a, b, d])
		#expect(try write(P6a.tri, wireframe: true) == [a, b, b, d, d, a])
		#expect(try write(P6a.quad, wireframe: false) == [a, b, c, d])
		#expect(try write(P6a.quad, wireframe: true) == [a, b, b, c, c, d, d, a])
		#expect(try write("5 24 0 0 0 10 0 0 0 5 0 0 -5 0", wireframe: false) == ["nil"])
	}

	@Test("Position is the first vertex; hidden primitives have an invalid bounding box")
	func positionAndBounds() throws {
		for text in ["3 16 1 2 3 10 0 0 0 10 0", "4 16 1 2 3 10 0 0 10 10 0 0 10 0"] {
			let prim = try #require(try Prim.parse(text) as? LDrawDrawableElement)
			#expect(P6a.p(prim.position()) == "(1, 2, 3)")
			let box = prim.boundingBox3()
			#expect(P6a.p(box.min) == "(0, 0, 0)" && P6a.p(box.max) == "(10, 10, 3)")
			prim.setHidden(true)
			let hiddenBox = prim.boundingBox3()
			#expect(V3EqualBoxes(hiddenBox, InvalidBox) != 0)
		}
	}
}
