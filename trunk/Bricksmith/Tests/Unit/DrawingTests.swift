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

/// Hands out numbered display lists and records which ones LDrawModel cleans up (through the C cleanup
/// function it was given), so the cache's lifetime rules are visible. Draws nothing.
final class DLLifetimeRenderer: NSObject, LDrawRenderer, LDrawCollector {
	nonisolated(unsafe) static var cleaned: [Int] = []
	private(set) var built = 0
	private(set) var drawn: [Int] = []
	var cullAnswer: Int32 = Int32(cull_draw)

	func pushMatrix(_ matrix: UnsafeMutablePointer<Float>!) {}
	func popMatrix() {}
	func checkCull(_ minXYZ: UnsafeMutablePointer<Float>!, to maxXYZ: UnsafeMutablePointer<Float>!) -> Int32 { cullAnswer }
	func drawBox(from minXyz: UnsafeMutablePointer<Float>!, to maxXyz: UnsafeMutablePointer<Float>!) {}
	func pushColor(_ color: UnsafeMutablePointer<Float>!) {}
	func popColor() {}
	func pushWireFrame() {}
	func popWireFrame() {}
	func pushTexture(_ tex_spec: UnsafeMutablePointer<LDrawTextureSpec>!) {}
	func popTexture() {}
	func drawDragHandle(_ xyz: UnsafeMutablePointer<Float>!, withSize size: Float) {}
	func textureTag(for texture: LDrawTexture!) -> UInt32 { 0 }
	func beginDL() -> (any LDrawCollector)! { self }
	func endDL(_ outHandle: UnsafeMutablePointer<LDrawDLHandle?>!, cleanupFunc: UnsafeMutablePointer<LDrawDLCleanup_f?>!) {
		built += 1
		outHandle.pointee = UnsafeMutableRawPointer(bitPattern: 1000 + built)
		cleanupFunc.pointee = { handle in DLLifetimeRenderer.cleaned.append(Int(bitPattern: handle)) }
	}
	func drawDL(_ dl: LDrawDLHandle!) { drawn.append(Int(bitPattern: dl)) }
	func drawQuad(_ vertices: UnsafeMutablePointer<Float>!, normal: UnsafeMutablePointer<Float>!, color: UnsafeMutablePointer<Float>!) {}
	func drawTri(_ vertices: UnsafeMutablePointer<Float>!, normal: UnsafeMutablePointer<Float>!, color: UnsafeMutablePointer<Float>!) {}
	func drawLine(_ vertices: UnsafeMutablePointer<Float>!, normal: UnsafeMutablePointer<Float>!, color: UnsafeMutablePointer<Float>!) {}
}

/// P6b pin: LDrawModel's display-list cache (the `dl`/`dl_dtor` pair), written against the ObjC class.
@MainActor
@Suite("Drawing: the model's cached display list (P6b pins)", .fixtureLibrary, .serialized)
struct ModelDisplayListTests {

	private func model(_ text: String) throws -> LDrawModel {
		let file = try #require(LDrawFile.parse(fromFileContents: "0 M\n0 Name: m.ldr\n0 Author: A\n" + text))
		return try #require(file.activeModel())
	}

	@Test("A valid DL is reused; a stale one is cleaned up once and rebuilt; a dealloc cleans nothing")
	func cacheLifetime() throws {
		DLLifetimeRenderer.cleaned = []
		let renderer = DLLifetimeRenderer()
		try autoreleasepool {
			let m = try model("2 24 0 0 0 10 0 0\n0 STEP\n3 16 0 0 0 10 0 0 0 10 0\n")
			m.drawSelf(renderer)
			m.drawSelf(renderer)
			#expect(renderer.built == 1)
			#expect(renderer.drawn == [1001, 1001])
			#expect(DLLifetimeRenderer.cleaned.isEmpty)

			(m.steps()[1] as! LDrawStep).add(try Prim.parse("2 24 0 0 0 0 10 0"))
			m.drawSelf(renderer)
			#expect(renderer.built == 2)
			#expect(DLLifetimeRenderer.cleaned == [1001])
			#expect(renderer.drawn == [1001, 1001, 1002])

			// Step display changes invalidate it too.
			m.setStepDisplay(true)
			m.drawSelf(renderer)
			#expect(DLLifetimeRenderer.cleaned == [1001, 1002])
			m.setMaximumStepIndexForStepDisplay(0)		// same index: still invalidates
			m.drawSelf(renderer)
			#expect(DLLifetimeRenderer.cleaned == [1001, 1002, 1003])
			#expect(renderer.built == 4)

			// Culled: no DL work at all.
			renderer.cullAnswer = Int32(cull_skip)
			m.setStepDisplay(false)
			m.drawSelf(renderer)
			renderer.cullAnswer = Int32(cull_box)
			m.drawSelf(renderer)
			#expect(renderer.built == 4)
			#expect(DLLifetimeRenderer.cleaned == [1001, 1002, 1003])
			renderer.cullAnswer = Int32(cull_draw)
		}
		#expect(DLLifetimeRenderer.cleaned == [1001, 1002, 1003], "the model's last DL is never cleaned up on dealloc")
	}

	@Test("Dragged directives get a temporary DL, built, drawn and cleaned up in the same frame")
	func dragDisplayList() throws {
		DLLifetimeRenderer.cleaned = []
		let renderer = DLLifetimeRenderer()
		let m = try model("2 24 0 0 0 10 0 0\n")
		m.setDraggingDirectives([try Prim.parse("3 16 0 0 0 10 0 0 0 10 0")])
		m.drawSelf(renderer)
		#expect(renderer.built == 2)
		#expect(renderer.drawn == [1001, 1002])
		#expect(DLLifetimeRenderer.cleaned == [1002])
		m.drawSelf(renderer)
		#expect(renderer.drawn == [1001, 1002, 1001, 1003])
		#expect(DLLifetimeRenderer.cleaned == [1002, 1003])
	}

	@Test("An optimized model draws only its DL: no drawSelf recursion, no dragged directives")
	func optimizedModel() throws {
		let m = try model("2 24 0 0 0 10 0 0\n3 16 0 0 0 10 0 0 0 10 0\n")
		m.optimizeStructure()
		m.setDraggingDirectives([try Prim.parse("3 16 0 0 0 10 0 0 0 10 0")])
		let renderer = DLLifetimeRenderer()
		m.drawSelf(renderer)
		#expect(renderer.built == 1)
		#expect(renderer.drawn == [1001])
	}
}
