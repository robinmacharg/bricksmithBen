//
//  SnappingTests.swift
//  BricksmithTests
//
//  P2 row 6: grid/angle snapping, moving, rotating, view-orientation mapping.
//  Golden: Fixtures/golden/transforms/snapping.tsv (what snapping does today), plus properties.
//

import Foundation
import Testing
@testable import Bricksmith

enum PartFactory {
	/// A part parsed from a single type-1 line (through the normal parser).
	static func part(_ line: String) throws -> LDrawPart {
		let file = try #require(RoundTrip.load(Data((line + "\n").utf8)))
		return try #require(ObjectModel.all(file).compactMap { $0 as? LDrawPart }.first)
	}

	static func describe(_ c: TransformComponents) -> String {
		func f(_ v: Float) -> String { String(format: "%.4f", v == 0 ? 0 : v) }   // print -0 as 0
		let deg = V3MulScalar(c.rotate, 180 / .pi)
		return "T(\(f(c.translate.x)) \(f(c.translate.y)) \(f(c.translate.z))) R°(\(f(deg.x)) \(f(deg.y)) \(f(deg.z))) S(\(f(c.scale.x)) \(f(c.scale.y)) \(f(c.scale.z)))"
	}
}

@Suite("Snapping and transforms (P2 row 6)", .fixtureLibrary, .serialized)
struct SnappingTests {

	/// Positions/rotations deliberately off-grid; rotations built as matrices from degrees.
	static let parts: [(name: String, line: String)] = [
		("off-grid position, no rotation", "1 4 3.7 -12.2 25.1 1 0 0 0 1 0 0 0 1 3001.dat"),
		("negative coordinates near grid", "1 4 -9.6 -0.4 -20.6 1 0 0 0 1 0 0 0 1 3001.dat"),
		("rotated 37 deg about Y", "1 4 0 0 0 0.798636 0 0.601815 0 1 0 -0.601815 0 0.798636 3001.dat"),
		("rotated 44 deg about Y", "1 4 0 0 0 0.71934 0 0.694658 0 1 0 -0.694658 0 0.71934 3001.dat"),
		("rotated 91 deg about Z", "1 4 0 0 0 -0.0174524 -0.999848 0 0.999848 -0.0174524 0 0 0 1 3001.dat"),
		("mirrored (negative scale)", "1 4 5 5 5 -1 0 0 0 1 0 0 0 1 3001.dat"),
	]
	static let grids: [Float] = [1, 10, 20]
	static let angles: [Float] = [15, 45, 90]

	@Test("componentsSnappedToGrid: characterisation table")
	func snappingTable() throws {
		var rows = ["part\tgrid\tminAngle\tsnapped"]
		for p in Self.parts {
			let part = try PartFactory.part(p.line)
			rows.append("\(p.name)\t-\t-\toriginal \(PartFactory.describe(part.transformComponents()))")
			for g in Self.grids { for a in Self.angles {
				rows.append("\(p.name)\t\(g)\t\(a)\t\(PartFactory.describe(part.componentsSnapped(toGrid: g, minimumAngle: a)))")
			} }
		}
		try Golden.check(Data((rows.joined(separator: "\n") + "\n").utf8), against: "transforms/snapping.tsv")
	}

	@Test("Snapping is idempotent", arguments: SnappingTests.parts.map(\.line))
	func snappingIdempotent(line: String) throws {
		let part = try PartFactory.part(line)
		for g in Self.grids { for a in Self.angles {
			var once = part.componentsSnapped(toGrid: g, minimumAngle: a)
			let twice = part.components(once, snappedToGrid: g, minimumAngle: a)
			#expect(M4.approx(Matrix4CreateTransformation(&once), { var t = twice; return Matrix4CreateTransformation(&t) }(), 1e-3),
					"grid \(g) angle \(a): \(PartFactory.describe(once)) -> \(PartFactory.describe(twice))")
		} }
	}

	/// Documented in -[LDrawPart components:snappedToGrid:minimumAngle:]: along the part's own Y axis a 20 LDU
	/// grid ("1 stud") becomes 24 (1 brick high) and a 10 LDU grid becomes 8 (1 plate high).
	static func verticalGrid(_ g: Float) -> Float {
		g.truncatingRemainder(dividingBy: 20) == 0 ? g * 24 / 20 : g.truncatingRemainder(dividingBy: 10) == 0 ? g * 8 / 10 : g
	}

	@Test("position:snappedToGrid: lands on the (LDraw-aware) grid and is idempotent")
	func positionSnapping() throws {
		let part = try PartFactory.part(Self.parts[0].line)   // unrotated: part Y axis == world Y
		for g in Self.grids {
			let snapped = part.position(V3Make(3.7, -12.2, 25.1), snappedToGrid: g)
			let gy = Self.verticalGrid(g)
			for (v, grid) in [(snapped.x, g), (snapped.y, gy), (snapped.z, g)] {
				#expect(abs(v / grid - (v / grid).rounded()) < 1e-4, "grid \(g) (vertical \(gy)): \(snapped)")
			}
			#expect(approx(part.position(snapped, snappedToGrid: g), snapped))
		}
	}

	@Test("moveBy adds exactly the displacement")
	func moveBy() throws {
		let part = try PartFactory.part(Self.parts[0].line)
		let before = part.position()
		part.move(by: V3Make(10, -24, 0.5))
		#expect(approx(part.position(), V3Add(before, V3Make(10, -24, 0.5))))
	}

	@Test("Four 90° rotations about each axis return to the start", arguments: [V3Make(90, 0, 0), V3Make(0, 90, 0), V3Make(0, 0, 90)])
	func rotateFullTurn(step: Tuple3) throws {
		let part = try PartFactory.part(Self.parts[2].line)
		let before = part.transformationMatrix()
		for _ in 0..<4 { part.rotate(byDegrees: step) }
		#expect(M4.approx(part.transformationMatrix(), before, 1e-3),
				"\(M4.describe(before))\n->\n\(M4.describe(part.transformationMatrix()))")
	}

	@Test("Rotating about a centre point keeps that point fixed")
	func rotateAboutCentre() throws {
		// Put the part AT the centre; its position must not move under rotation about that centre.
		let part = try PartFactory.part("1 4 40 -24 60 1 0 0 0 1 0 0 0 1 3001.dat")
		part.rotate(byDegrees: V3Make(0, 90, 0), centerPoint: V3Make(40, -24, 60))
		#expect(approx(part.position(), V3Make(40, -24, 60)))
		// And a part off-centre moves on a circle: distance to the centre is preserved.
		let other = try PartFactory.part("1 4 50 -24 60 1 0 0 0 1 0 0 0 1 3001.dat")
		other.rotate(byDegrees: V3Make(0, 90, 0), centerPoint: V3Make(40, -24, 60))
		#expect(approx(V3DistanceBetween2Points(other.position(), V3Make(40, -24, 60)), 10, 1e-3))
	}

	@Test("View orientations map to angles and back", arguments: [
		ViewOrientationT.orientationFront, .orientationBack, .orientationLeft, .orientationRight,
		.orientationTop, .orientationBottom])
	func viewOrientationRoundTrip(orientation: ViewOrientationT) {
		let angle = LDrawUtilities.angle(forViewOrientation: orientation)
		#expect(LDrawUtilities.viewOrientation(forAngle: angle) == orientation, "\(orientation.rawValue) -> \(angle)")
	}
}
