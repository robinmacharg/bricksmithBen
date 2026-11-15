//
//  HitTestingTests.swift
//  BricksmithTests
//
//  P2 exit (coverage): selection picking in the model classes. The GL renderer turns a click into
//  -depthTest:inBox:... (nearest object under the point) and a marquee into -boxTest:... (everything in a
//  clip-space box); see LDrawGLRenderer.m ~1900-2090. Those are pure maths on the model, so they are
//  characterised here without GL:
//
//      depth.txt  a grid of "clicks" over the view: which object wins at each cell, and its depth
//      box.txt    a set of marquee boxes: which objects each one selects
//
//  -hitTest:... (pick rays) is NOT tested: its only caller, -[LDrawGLRenderer getDirectivesUnderPoint:...],
//  is never called (dead code; uncovered-line ledger in port-status.md).
//
//  The transform stands in for camera * projection: an orthographic front view mapping model x/y in
//  [-100, 100] onto clip space, y flipped (LDraw y points down), depth = -z / 1000.
//

import Foundation
import Testing
@testable import Bricksmith

enum HitLayout {
	/// Every primitive type, spread out so each has its own screen area, plus one overlap (a red
	/// triangle 10 LDU in front of the quad) to show which object depth testing prefers.
	static let text = """
		0 Hit-test layout
		0 Name: hit-layout.ldr
		0 Author: Fixture Author
		1 4 -50 0 0 1 0 0 0 1 0 0 0 1 3003.dat
		1 1 50 -40 20 1 0 0 0 1 0 0 0 1 3005.dat
		2 24 -80 60 0 -20 60 0
		3 16 0 40 0 30 40 0 0 80 0
		4 2 40 40 0 80 40 0 80 80 0 40 80 0
		3 4 50 50 10 70 50 10 50 70 10
		5 24 -80 -60 0 -20 -60 0 -50 -70 0 -50 -50 0
		0 !TEXMAP START PLANAR -20 -40 0 20 -40 0 -20 -80 0 sticker.png
		3 16 -20 -40 0 20 -40 0 20 -80 0
		0 !TEXMAP END
		"""

	/// Orthographic front view: clip = (x / 100, -y / 100, -z / 1000).
	static let transform = M4.make([[0.01, 0, 0, 0], [0, -0.01, 0, 0], [0, 0, -0.001, 0], [0, 0, 0, 1]])

	static func load() throws -> LDrawFile {
		try #require(LDrawFile.parse(fromFileContents: text.replacingOccurrences(of: "\t", with: "")))
	}

	/// Stable labels for every directive in the file: "A".."Z" in walk order, with "index class" legend lines.
	static func labels(_ file: LDrawFile) -> (byObject: [ObjectIdentifier: String], legend: [String]) {
		var byObject: [ObjectIdentifier: String] = [:]
		var legend: [String] = []
		var path: [Int] = []
		func walk(_ directive: LDrawDirective) {
			if !(directive is LDrawFile) && !(directive is LDrawModel) && !(directive is LDrawStep) {
				let letter = String(UnicodeScalar(UInt8(65 + byObject.count)))
				byObject[ObjectIdentifier(directive)] = letter
				legend.append("\(letter) \(path.map(String.init).joined(separator: ".")) \(type(of: directive))")
			}
			// Only walk containers the user sees as such; a part's geometry is credited to the part.
			guard let container = directive as? LDrawContainer, !(directive is LDrawPart) else { return }
			for (i, child) in container.subdirectives().enumerated() {
				path.append(i); walk(child as! LDrawDirective); path.removeLast()
			}
		}
		walk(file)
		return (byObject, legend)
	}

	static func pointer(_ object: AnyObject) -> UnsafeMutableRawPointer { Unmanaged.passUnretained(object).toOpaque() }

	/// Resolve an NSValue hit key (a wrapped pointer) back to a label.
	static func label(of key: Any, in file: LDrawFile, labels: [ObjectIdentifier: String]) -> String {
		let raw = (key as! NSValue).pointerValue
		var all: [LDrawDirective] = []
		func walk(_ d: LDrawDirective) {
			all.append(d)
			if let c = d as? LDrawContainer, !(d is LDrawPart) { c.subdirectives().forEach { walk($0 as! LDrawDirective) } }
		}
		walk(file)
		return all.first { pointer($0) == raw }.flatMap { labels[ObjectIdentifier($0)] } ?? "?"
	}
}

@Suite("Hit testing: depth, box and ray picking (P2 exit)", .fixtureLibrary, .serialized)
struct HitTestingTests {

	@Test("Click picking: depthTest over a grid of points")
	func depthGrid() throws {
		let file = try HitLayout.load()
		let (labels, legend) = HitLayout.labels(file)
		let columns = 40, rows = 20, half: Float = 0.01   // half-size of the click box, as HANDLE_SIZE in clip space
		var map: [String] = [], depths: [String] = []
		for r in 0..<rows {
			var line = ""
			for c in 0..<columns {
				let x = -1 + (Float(c) + 0.5) * 2 / Float(columns)
				let y = 1 - (Float(r) + 0.5) * 2 / Float(rows)
				var best: AnyObject? = nil
				var depth: Float = 1.0       // the renderer starts at the far plane
				try ObjC.run {
					file.depthTest(Point2(x: x, y: y), inBox: Box2(origin: Point2(x: x - half, y: y - half),
																  size: Size2(width: 2 * half, height: 2 * half)),
								   transform: HitLayout.transform, creditObject: nil, bestObject: &best, bestDepth: &depth)
				}
				if let best {
					let label = labels[ObjectIdentifier(best)] ?? "?"
					line += label
					depths.append(String(format: "r%02d c%02d %@ %.5f", r, c, label, depth))
				} else {
					line += "."
				}
			}
			map.append(line)
		}
		let text = (["# legend: label, index path, class"] + legend + ["", "# winner per cell (row 0 = top)"] + map
					+ ["", "# depth of each winner"] + depths).joined(separator: "\n") + "\n"
		try Golden.check(Data((text).utf8), against: "hittest/depth.txt")
	}

	@Test("Marquee picking: boxTest selects the objects inside each box")
	func marquee() throws {
		let file = try HitLayout.load()
		let (labels, legend) = HitLayout.labels(file)
		let boxes: [(String, Box2)] = [
			("whole view", Box2(origin: Point2(x: -1, y: -1), size: Size2(width: 2, height: 2))),
			("left half", Box2(origin: Point2(x: -1, y: -1), size: Size2(width: 1, height: 2))),
			("right half", Box2(origin: Point2(x: 0, y: -1), size: Size2(width: 1, height: 2))),
			("top half", Box2(origin: Point2(x: -1, y: 0), size: Size2(width: 2, height: 1))),
			("quad corner only", Box2(origin: Point2(x: 0.75, y: -0.8), size: Size2(width: 0.04, height: 0.04))),
			("empty corner", Box2(origin: Point2(x: 0.9, y: 0.9), size: Size2(width: 0.05, height: 0.05))),
			("crosses the line", Box2(origin: Point2(x: -0.55, y: -0.62), size: Size2(width: 0.02, height: 0.04))),
			("zero size on triangle", Box2(origin: Point2(x: 0.05, y: -0.45), size: Size2(width: 0, height: 0))),
		]
		var out = ["# legend"] + legend + [""]
		for (name, box) in boxes {
			let hits = NSMutableSet()
			var any = false
			try ObjC.run {
				any = file.boxTest(box, transform: HitLayout.transform, boundsOnly: false, creditObject: nil, hits: hits)
			}
			let picked = hits.allObjects.map { HitLayout.label(of: $0, in: file, labels: labels) }.sorted()
			out.append("\(name): returned \(any ? "YES" : "NO"), selected [\(picked.joined(separator: " "))]")
		}
		try Golden.check(Data((out.joined(separator: "\n") + "\n").utf8), against: "hittest/box.txt")
	}

	@Test("Hidden directives are never picked")
	func hiddenNotPicked() throws {
		let file = try HitLayout.load()
		let step = try #require(file.activeModel().steps().first as? LDrawStep)
		let all = step.subdirectives().compactMap { $0 as? LDrawDrawableElement }
		all.forEach { $0.setHidden(true) }
		let hits = NSMutableSet()
		var best: AnyObject? = nil
		var depth: Float = 1
		try ObjC.run {
			_ = file.boxTest(Box2(origin: Point2(x: -1, y: -1), size: Size2(width: 2, height: 2)),
							 transform: HitLayout.transform, boundsOnly: false, creditObject: nil, hits: hits)
			file.depthTest(Point2(x: 0.1, y: -0.5), inBox: Box2(origin: Point2(x: -1, y: -1), size: Size2(width: 2, height: 2)),
						   transform: HitLayout.transform, creditObject: nil, bestObject: &best, bestDepth: &depth)
		}
		// The texture block is not a drawable element, so it can still be picked; everything else is hidden.
		let picked = hits.allObjects.compactMap { key in step.subdirectives().first { HitLayout.pointer($0 as AnyObject) == (key as! NSValue).pointerValue } }
		#expect(picked.allSatisfy { $0 is LDrawTexture }, "picked hidden directives: \(picked)")
		#expect(best == nil || best is LDrawTexture)
	}

	@Test("A hit does not keep the hit object alive")
	func hitDoesNotRetain() throws {
		weak var weakTriangle: LDrawTriangle?
		try autoreleasepool {
			let triangle = LDrawTriangle()
			triangle.setVertex1(V3Make(0, 0, 0)); triangle.setVertex2(V3Make(10, 0, 0)); triangle.setVertex3(V3Make(0, 10, 0))
			weakTriangle = triangle
			let hits = NSMutableSet()
			let all = Box2(origin: Point2(x: -100, y: -100), size: Size2(width: 200, height: 200))
			try ObjC.run { _ = triangle.boxTest(all, transform: IdentityMatrix4, boundsOnly: false, creditObject: nil, hits: hits) }
			#expect(hits.count == 1)
		}
		withKnownIssue("BUG-017: registerHitForObject: CFBridgingRetains every hit object and nothing releases it") {
			#expect(weakTriangle == nil, "the triangle leaked after being hit")
		}
	}
}
