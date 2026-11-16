//
//  DrawingTests.swift
//  BricksmithTests
//
//  P2 exit (coverage): the live drawing path. LDrawGLRenderer builds an LDrawShaderRenderer and calls
//  -[LDrawFile drawSelf:]; models collect their primitives into display lists (-collectSelf:), parts push
//  their transform and colour, selected primitives draw drag handles. RecordingRenderer logs that call
//  stream as text, so it is characterised without GL. Goldens: golden/drawing/*.txt.
//
//  (The fixed-function draw path was deleted in P4; -draw:viewScale:parentColor: now only walks the
//  LDConfig file so LDrawColor directives register themselves with ColorLibrary.)
//

import AppKit
import Foundation
import Testing
@testable import Bricksmith

/// Texture directives ask PartLibrary for a GL texture name while drawing, so a GL context must be current.
@MainActor
enum OffscreenGL {
	static let context: NSOpenGLContext? = {
		let attributes: [NSOpenGLPixelFormatAttribute] = [UInt32(NSOpenGLPFAAllowOfflineRenderers), 0]
		return NSOpenGLPixelFormat(attributes: attributes).flatMap { NSOpenGLContext(format: $0, share: nil) }
	}()
	static func makeCurrent() throws { try #require(context).makeCurrentContext() }
}

@MainActor
enum DrawHarness {
	static func load(_ name: String) throws -> LDrawFile {
		if name == "hit-layout" { return try HitLayout.load() }
		return try #require(RoundTrip.load(try Data(contentsOf: FixturePaths.fixtures.appendingPathComponent("ldr/\(name)"))))
	}

	/// Draw `file` `passes` times through one recorder (the second pass shows display-list reuse).
	static func record(_ file: LDrawFile, passes: Int = 2, cull: Int32 = Int32(cull_draw),
					   between: (Int) throws -> Void = { _ in }) throws -> String {
		try OffscreenGL.makeCurrent()
		let renderer = RecordingRenderer()
		renderer.cullAnswer = cull
		var out: [String] = []
		var seen = 0
		for pass in 1...passes {
			if pass > 1 { try between(pass) }
			try ObjC.run { file.drawSelf(renderer) }
			out.append("# pass \(pass)")
			out += renderer.log[seen...]
			seen = renderer.log.count
		}
		return out.joined(separator: "\n") + "\n"
	}

	static func step(_ file: LDrawFile) throws -> LDrawStep {
		try #require(file.activeModel().steps().first as? LDrawStep)
	}
}

@MainActor
@Suite("Drawing: renderer call stream (P2 exit)", .fixtureLibrary, .serialized)
struct DrawingTests {

	@Test("drawSelf call stream", arguments: ["hit-layout", "03-colours.ldr", "05-multipart.mpd", "07-texmap.ldr",
											  "14-direct-colours.ldr"])
	func stream(_ name: String) throws {
		let file = try DrawHarness.load(name)
		let golden = "drawing/" + (name as NSString).deletingPathExtension + ".txt"
		try Golden.check(Data(try DrawHarness.record(file).utf8), against: golden)
	}

	@Test("Selected primitives draw drag handles; selected parts draw in wireframe")
	func selection() throws {
		let file = try DrawHarness.load("hit-layout")
		let step = try DrawHarness.step(file)
		for case let d as LDrawDirective in step.subdirectives() { d.setSelected(true) }
		try Golden.check(Data(try DrawHarness.record(file, passes: 1).utf8), against: "drawing/selected.txt")
	}

	@Test("Culling: 'box' draws a bounding box instead, 'skip' draws nothing")
	func culling() throws {
		let box = try DrawHarness.record(try DrawHarness.load("hit-layout"), passes: 1, cull: Int32(cull_box))
		let skip = try DrawHarness.record(try DrawHarness.load("hit-layout"), passes: 1, cull: Int32(cull_skip))
		try Golden.check(Data(("# cull_box\n" + box + "# cull_skip\n" + skip).utf8), against: "drawing/cull.txt")
	}

	@Test("Directives being dragged are drawn from a temporary display list")
	func dragging() throws {
		let file = try DrawHarness.load("hit-layout")
		let step = try DrawHarness.step(file)
		let dragged = [step.subdirectives()[0], step.subdirectives()[3]].map { ($0 as! NSObject).copy() as! LDrawDirective }
		try ObjC.run { file.setDraggingDirectives(dragged) }
		try Golden.check(Data(try DrawHarness.record(file, passes: 1).utf8), against: "drawing/dragging.txt")
	}

	@Test("Editing a primitive invalidates the cached display list")
	func invalidation() throws {
		let file = try DrawHarness.load("hit-layout")
		let triangle = try #require(try DrawHarness.step(file).subdirectives()[3] as? LDrawTriangle)
		let text = try DrawHarness.record(file, passes: 3) { pass in
			if pass == 3 { triangle.setVertex1(V3Make(5, 45, 0)) }   // pass 2: unchanged, pass 3: after the edit
		}
		try Golden.check(Data(text.utf8), against: "drawing/after-edit.txt")
	}
}
