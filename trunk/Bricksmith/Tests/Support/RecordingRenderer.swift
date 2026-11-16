//
//  RecordingRenderer.swift
//  BricksmithTests
//
//  A stand-in for LDrawShaderRenderer that records every call the model makes through the
//  LDrawRenderer / LDrawCollector protocols (Source/LDraw/Renderer/LDrawRenderer.h) as text.
//  It characterises the live drawing path (-drawSelf: / -collectSelf:) without GL, and is the
//  reference the Metal renderer must reproduce later.
//
//  Display lists: -beginDL returns this object as the collector; -endDL hands back a fake,
//  numbered handle and a no-op cleanup function (LDrawModel calls the cleanup when a DL goes stale).
//

import Foundation
import OpenGL.GL
@testable import Bricksmith

final class RecordingRenderer: NSObject, LDrawRenderer, LDrawCollector {
	private(set) var log: [String] = []
	/// The answer to -checkCull:to: (cull_skip, cull_box or cull_draw).
	var cullAnswer: Int32 = Int32(cull_draw)
	private var displayLists = 0
	private var indent = 0

	private func emit(_ s: String) { log.append(String(repeating: "  ", count: indent) + s) }

	static func floats(_ p: UnsafePointer<GLfloat>?, _ n: Int) -> String {
		guard let p else { return "nil" }
		return (0..<n).map { fmt(p[$0]) }.joined(separator: " ")
	}

	/// %g with 5 significant digits; -0 printed as 0 so sign noise doesn't churn goldens.
	static func fmt(_ v: Float) -> String { v == 0 ? "0" : String(format: "%.5g", v) }

	/// Colours may be the meta-colour "pointers" 0 (current) and -1 (complement); never dereference those.
	static func colour(_ p: UnsafeMutablePointer<GLfloat>?) -> String {
		guard let p else { return "current" }
		if UInt(bitPattern: p) == UInt.max { return "complement" }
		return "rgba(" + floats(p, 4) + ")"
	}

	// MARK: LDrawRenderer

	func pushMatrix(_ matrix: UnsafeMutablePointer<GLfloat>!) { emit("pushMatrix [\(Self.floats(matrix, 16))]"); indent += 1 }
	func popMatrix() { indent -= 1; emit("popMatrix") }
	func checkCull(_ minXYZ: UnsafeMutablePointer<GLfloat>!, to maxXYZ: UnsafeMutablePointer<GLfloat>!) -> Int32 {
		emit("checkCull [\(Self.floats(minXYZ, 3))] to [\(Self.floats(maxXYZ, 3))] -> \(cullAnswer)")
		return cullAnswer
	}
	func drawBox(from minXyz: UnsafeMutablePointer<GLfloat>!, to maxXyz: UnsafeMutablePointer<GLfloat>!) {
		emit("drawBox [\(Self.floats(minXyz, 3))] to [\(Self.floats(maxXyz, 3))]")
	}
	func pushColor(_ color: UnsafeMutablePointer<GLfloat>!) { emit("pushColor \(Self.colour(color))"); indent += 1 }
	func popColor() { indent -= 1; emit("popColor") }
	func pushWireFrame() { emit("pushWireFrame"); indent += 1 }
	func popWireFrame() { indent -= 1; emit("popWireFrame") }
	func pushTexture(_ tex_spec: UnsafeMutablePointer<LDrawTextureSpec>!) {
		let s = tex_spec.pointee
		let planeS = withUnsafePointer(to: s.plane_s) { $0.withMemoryRebound(to: GLfloat.self, capacity: 4) { Self.floats($0, 4) } }
		let planeT = withUnsafePointer(to: s.plane_t) { $0.withMemoryRebound(to: GLfloat.self, capacity: 4) { Self.floats($0, 4) } }
		// tex_obj is a GL texture name: only whether one was made is stable.
		emit("pushTexture projection=\(s.projection) tex=\(s.tex_obj == 0 ? "none" : "made") s=[\(planeS)] t=[\(planeT)]")
		indent += 1
	}
	func popTexture() { indent -= 1; emit("popTexture") }
	func drawDragHandle(_ xyz: UnsafeMutablePointer<GLfloat>!, withSize size: GLfloat) {
		emit("drawDragHandle [\(Self.floats(xyz, 3))] size \(Self.fmt(size))")
	}
	func beginDL() -> (any LDrawCollector)! {
		displayLists += 1
		emit("beginDL #\(displayLists)"); indent += 1
		return self
	}
	func endDL(_ outHandle: UnsafeMutablePointer<LDrawDLHandle?>!, cleanupFunc: UnsafeMutablePointer<LDrawDLCleanup_f?>!) {
		indent -= 1
		emit("endDL #\(displayLists)")
		outHandle.pointee = UnsafeMutableRawPointer(bitPattern: displayLists)
		cleanupFunc.pointee = { _ in }
	}
	func drawDL(_ dl: LDrawDLHandle!) { emit("drawDL #\(Int(bitPattern: dl))") }

	// MARK: LDrawRenderer and LDrawCollector

	/// Texture names come from the same place LDrawShaderRenderer gets them (PartLibrary's per-image cache, a
	/// real GL upload), so the shared cache stays valid for later real renders. Not logged: it isn't drawing.
	func textureTag(for texture: LDrawTexture!) -> GLuint { PartLibrary.shared().textureTag(for: texture) }

	// MARK: LDrawCollector

	func drawQuad(_ vertices: UnsafeMutablePointer<GLfloat>!, normal: UnsafeMutablePointer<GLfloat>!, color: UnsafeMutablePointer<GLfloat>!) {
		emit("quad [\(Self.floats(vertices, 12))] n [\(Self.floats(normal, 3))] \(Self.colour(color))")
	}
	func drawTri(_ vertices: UnsafeMutablePointer<GLfloat>!, normal: UnsafeMutablePointer<GLfloat>!, color: UnsafeMutablePointer<GLfloat>!) {
		emit("tri [\(Self.floats(vertices, 9))] n [\(Self.floats(normal, 3))] \(Self.colour(color))")
	}
	func drawLine(_ vertices: UnsafeMutablePointer<GLfloat>!, normal: UnsafeMutablePointer<GLfloat>!, color: UnsafeMutablePointer<GLfloat>!) {
		emit("line [\(Self.floats(vertices, 6))] n [\(Self.floats(normal, 3))] \(Self.colour(color))")
	}
}
