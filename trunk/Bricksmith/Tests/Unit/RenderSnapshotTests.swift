//
//  RenderSnapshotTests.swift
//  BricksmithTests
//
//  P2 row 15: render snapshots of fixtures from a fixed camera, captured from the real LDrawGLView via its
//  -saveImageToPath: debugging aid. References are PER MACHINE (GL-on-Metal output differs between GPUs/OS
//  versions) and are a reference for the later Metal port, not a CI gate.
//

import AppKit
import OpenGL.GL
import Foundation
import Testing
@testable import Bricksmith

@MainActor
enum RenderHarness {
	nonisolated static var machineName: String { machineModel() }
	static var machine: String { machineModel() }

	nonisolated static func machineModel() -> String {
		var size = 0
		sysctlbyname("hw.model", nil, &size, nil, 0)
		var model = [CChar](repeating: 0, count: size)
		sysctlbyname("hw.model", &model, &size, nil, 0)
		return String(cString: model)
	}

	/// Render a fixture in the document's main viewport from a fixed camera and return the captured image.
	/// Render a fixture in the document's main viewport from a fixed orthographic camera.
	/// Capture recipe (spike, LEARNINGS L64): explicit -draw with the view's context current, then read the back
	/// buffer; the image is flipped to top-down for humans.
	static func render(_ fixture: String, angle: Tuple3, zoom: CGFloat = 400) throws -> NSBitmapImageRep {
		let doc = try DocHarness.open(fixture)
		defer { DocHarness.close(doc) }
		let view = try #require(doc.main3DViewport())
		try ObjC.run {
			view.setProjectionMode(.orthographic)
			view.setViewingAngle(angle)
			view.zoomToFit(nil)
			view.setZoomPercentage(zoom)
			view.scrollCenter(toModelPoint: V3CenterOfBox(doc.documentContents().activeModel().boundingBox3()))
			view.display()
			// A fixed viewport: the split-view layout comes from autosaved divider positions in the (shared,
			// restored-per-run) debug defaults domain, so the view's natural size is not stable (L73).
			// Set after display() (which re-lays out the split view), then reshape to update GL_VIEWPORT.
			// The viewport follows the visible rect, which the LDrawViewerContainer clips: size both.
			view.superview?.setFrameSize(NSSize(width: 625, height: 691))
			view.setFrameSize(NSSize(width: 625, height: 691))
			view.reshape()
			view.scrollCenter(toModelPoint: V3CenterOfBox(doc.documentContents().activeModel().boundingBox3()))
			view.draw()
			view.openGLContext?.makeCurrentContext()
			glReadBuffer(GLenum(GL_BACK))
		}
		let path = FileManager.default.temporaryDirectory.appendingPathComponent("render-\(UUID().uuidString).tiff").path
		defer { try? FileManager.default.removeItem(atPath: path) }
		try ObjC.run { view.saveImage(toPath: path) }
		let data = try Data(contentsOf: URL(fileURLWithPath: path))
		return flipped(try #require(NSBitmapImageRep(data: data)))
	}

	static func flipped(_ image: NSBitmapImageRep) -> NSBitmapImageRep {
		let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: image.pixelsWide, pixelsHigh: image.pixelsHigh,
								   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
								   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
		NSGraphicsContext.saveGraphicsState()
		NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
		let t = NSAffineTransform(); t.translateX(by: 0, yBy: CGFloat(image.pixelsHigh)); t.scaleX(by: 1, yBy: -1); t.concat()
		image.draw(in: NSRect(x: 0, y: 0, width: image.pixelsWide, height: image.pixelsHigh))
		NSGraphicsContext.restoreGraphicsState()
		return out
	}

	/// (max channel delta, fraction of pixels differing by more than `threshold`).
	static func difference(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep, threshold: Int = 8) -> (Int, Double)? {
		guard a.pixelsWide == b.pixelsWide, a.pixelsHigh == b.pixelsHigh else { return nil }
		var maxDelta = 0, differing = 0
		for y in 0..<a.pixelsHigh { for x in 0..<a.pixelsWide {
			var pa = [Int](repeating: 0, count: 4), pb = pa
			a.getPixel(&pa, atX: x, y: y); b.getPixel(&pb, atX: x, y: y)
			let d = zip(pa.prefix(3), pb.prefix(3)).map { abs($0 - $1) }.max()!
			maxDelta = max(maxDelta, d); if d > threshold { differing += 1 }
		} }
		return (maxDelta, Double(differing) / Double(a.pixelsWide * a.pixelsHigh))
	}
}

@MainActor
@Suite("Render snapshots (P2 row 15)", .fixtureLibrary, .serialized, .timeLimit(.minutes(1)))
struct RenderSnapshotTests {

	static let cases: [(fixture: String, camera: String)] = [
		("01-header-metadata.ldr", "iso"), ("02-line-types.ldr", "iso"), ("03-colours.ldr", "iso"),
		("04-steps-rotstep.ldr", "iso"), ("04-steps-rotstep.ldr", "front"), ("05-multipart.mpd", "iso"),
		("07-texmap.ldr", "iso"), ("14-direct-colours.ldr", "front"),
	]

	@Test("Fixture renders match this machine's reference images", arguments: RenderSnapshotTests.cases.map { "\($0.fixture)|\($0.camera)" })
	func snapshot(_ key: String) throws {
		let parts = key.split(separator: "|").map(String.init)
		let angle = parts[1] == "front" ? V3Make(0, 0, 0) : V3Make(30, 45, 0)
		let image = try RenderHarness.render(parts[0], angle: angle)
		let name = "render/\(RenderHarness.machine)/\((parts[0] as NSString).deletingPathExtension)-\(parts[1]).png"
		let url = Golden.directory.appendingPathComponent(name)
		if Golden.isRecording {
			try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
			try image.representation(using: .png, properties: [:])!.write(to: url)
			return
		}
		guard let data = FileManager.default.contents(atPath: url.path), let reference = NSBitmapImageRep(data: data) else {
			print("No render reference for machine \(RenderHarness.machine): \(name) (not a CI gate; record with RECORD_GOLDENS=1)")
			return
		}
		let diff = try #require(RenderHarness.difference(image, reference), "image size changed")
		#expect(diff.1 <= 0.005, "\(name): \(String(format: "%.2f%%", diff.1 * 100)) pixels differ (max delta \(diff.0))")
	}
}
