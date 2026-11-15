//
//  MatrixMathTests.swift
//  BricksmithTests
//
//  P2 row 5: MatrixMath.c (stays C in this port; C -> Swift is a follow-on goal). Tier A target.
//  Convention-independent properties (inverse, transpose, determinant, compose/decompose,
//  project/unproject) plus table tests for the 2D/3D helpers. Randomised tests use a fixed seed
//  and report it on failure.
//

import Foundation
import Testing
@testable import Bricksmith

// MARK: - Helpers

/// Deterministic RNG (SplitMix64) so property tests are reproducible.
struct SeededRNG: RandomNumberGenerator {
	var state: UInt64
	init(seed: UInt64) { state = seed }
	mutating func next() -> UInt64 {
		state &+= 0x9E3779B97F4A7C15
		var z = state
		z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
		z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
		return z ^ (z >> 31)
	}
}

enum M4 {
	static func rows(_ m: Matrix4) -> [[Float]] {
		withUnsafeBytes(of: m.element) { raw in
			let f = Array(raw.bindMemory(to: Float.self))
			return (0..<4).map { r in Array(f[(r * 4)..<(r * 4 + 4)]) }
		}
	}
	static func make(_ rows: [[Float]]) -> Matrix4 {
		var m = IdentityMatrix4
		withUnsafeMutableBytes(of: &m.element) { raw in
			let f = raw.bindMemory(to: Float.self)
			for r in 0..<4 { for c in 0..<4 { f[r * 4 + c] = rows[r][c] } }
		}
		return m
	}
	static func approx(_ a: Matrix4, _ b: Matrix4, _ tol: Float = 1e-4) -> Bool {
		zip(rows(a).joined(), rows(b).joined()).allSatisfy { abs($0 - $1) <= tol * max(1, abs($0), abs($1)) }
	}
	static func describe(_ m: Matrix4) -> String {
		rows(m).map { $0.map { String(format: "%9.4f", $0) }.joined(separator: " ") }.joined(separator: "\n")
	}
}

func approx(_ a: Float, _ b: Float, _ tol: Float = 1e-4) -> Bool { abs(a - b) <= tol * max(1, abs(a), abs(b)) }
func approx(_ a: Vector3, _ b: Vector3, _ tol: Float = 1e-4) -> Bool {
	approx(a.x, b.x, tol) && approx(a.y, b.y, tol) && approx(a.z, b.z, tol)
}

// MARK: - Matrix properties

@Suite("MatrixMath: matrices (P2 row 5)")
struct MatrixMathMatrixTests {
	static let seed: UInt64 = 0xB51C_5317

	/// Random rigid transform with scale (no shear/perspective), as Bricksmith parts use.
	static func randomComponents(_ rng: inout SeededRNG) -> TransformComponents {
		var c = IdentityComponents
		c.scale = V3Make(.random(in: 0.25...4, using: &rng), .random(in: 0.25...4, using: &rng), .random(in: 0.25...4, using: &rng))
		c.rotate = V3Make(.random(in: -3...3, using: &rng), .random(in: -1.4...1.4, using: &rng), .random(in: -3...3, using: &rng))
		c.translate = V3Make(.random(in: -500...500, using: &rng), .random(in: -500...500, using: &rng), .random(in: -500...500, using: &rng))
		return c
	}

	@Test("Identity is neutral for Multiply; Transpose is an involution")
	func identityAndTranspose() {
		var rng = SeededRNG(seed: Self.seed)
		for _ in 0..<50 {
			var comps = Self.randomComponents(&rng)
			let m = Matrix4CreateTransformation(&comps)
			#expect(M4.approx(Matrix4Multiply(m, IdentityMatrix4), m))
			#expect(M4.approx(Matrix4Multiply(IdentityMatrix4, m), m))
			#expect(M4.approx(Matrix4Transpose(Matrix4Transpose(m)), m))
		}
	}

	@Test("Invert: M x M^-1 = I, and det(M) x det(M^-1) = 1 (seed 0xB51C5317)")
	func invert() {
		var rng = SeededRNG(seed: Self.seed)
		for i in 0..<100 {
			var comps = Self.randomComponents(&rng)
			var m = Matrix4CreateTransformation(&comps)
			var inv = Matrix4Invert(m)
			#expect(M4.approx(Matrix4Multiply(m, inv), IdentityMatrix4, 1e-3), "case \(i)\n\(M4.describe(m))")
			#expect(approx(Matrix4x4Determinant(&m) * Matrix4x4Determinant(&inv), 1, 1e-3), "case \(i)")
		}
	}

	@Test("Determinant is multiplicative: det(AB) = det(A) det(B)")
	func determinantMultiplicative() {
		var rng = SeededRNG(seed: Self.seed ^ 1)
		for _ in 0..<50 {
			var ca = Self.randomComponents(&rng), cb = Self.randomComponents(&rng)
			var a = Matrix4CreateTransformation(&ca), b = Matrix4CreateTransformation(&cb)
			var ab = Matrix4Multiply(a, b)
			#expect(approx(Matrix4x4Determinant(&ab), Matrix4x4Determinant(&a) * Matrix4x4Determinant(&b), 1e-3))
		}
	}

	@Test("Create(Decompose(M)) = M for scale/rotate/translate matrices")
	func composeDecompose() {
		var rng = SeededRNG(seed: Self.seed ^ 2)
		for i in 0..<100 {
			var comps = Self.randomComponents(&rng)
			let m = Matrix4CreateTransformation(&comps)
			var decomposed = IdentityComponents
			let ok = Matrix4DecomposeTransformation(m, &decomposed)
			#expect(ok != 0, "case \(i): decomposition reported failure")
			let rebuilt = Matrix4CreateTransformation(&decomposed)
			#expect(M4.approx(rebuilt, m, 1e-3), "case \(i)\n\(M4.describe(m))\nrebuilt\n\(M4.describe(rebuilt))")
		}
	}

	@Test("Translate then extract: translation lands in the matrix's translation row/column consistently")
	func translationRoundTrip() {
		let t = V3Make(10, -20, 30)
		let m = Matrix4Translate(IdentityMatrix4, t)
		var comps = IdentityComponents
		_ = Matrix4DecomposeTransformation(m, &comps)
		#expect(approx(comps.translate, t))
		let moved = V3MulPointByProjMatrix(V3Make(1, 2, 3), m)
		#expect(approx(moved, V3Make(11, -18, 33)))
	}

	@Test("Rotation helpers: Matrix4Rotate followed by DecomposeXYZRotation reproduces the same matrix")
	func rotationDecomposition() {
		var rng = SeededRNG(seed: Self.seed ^ 3)
		for i in 0..<50 {
			// Matrix4Rotate takes degrees (per its parameter name); keep Y away from gimbal lock.
			let deg = V3Make(.random(in: -170...170, using: &rng), .random(in: -80...80, using: &rng), .random(in: -170...170, using: &rng))
			let r = Matrix4Rotate(IdentityMatrix4, deg)
			let angles = Matrix4DecomposeXYZRotation(r)
			// Characterise the units the decomposition returns by rebuilding in both interpretations.
			let asDegrees = Matrix4Rotate(IdentityMatrix4, angles)
			let asRadians = Matrix4Rotate(IdentityMatrix4, V3MulScalar(angles, 180 / .pi))
			#expect(M4.approx(asDegrees, r, 1e-3) || M4.approx(asRadians, r, 1e-3),
					"case \(i): deg \(deg) -> decomposed \(angles)")
		}
	}

	@Test("GL matrix conversion round-trips")
	func glRoundTrip() {
		var rng = SeededRNG(seed: Self.seed ^ 4)
		var comps = Self.randomComponents(&rng)
		let m = Matrix4CreateTransformation(&comps)
		var gl = [GLfloat](repeating: 0, count: 16)
		Matrix4GetGLMatrix4(m, &gl)
		#expect(M4.approx(Matrix4CreateFromGLMatrix4(gl), m, 1e-6))
	}

	@Test("Project then Unproject returns the original point")
	func projectUnproject() {
		var modelview = IdentityMatrix4
		modelview = V3LookAt(V3Make(0, 0, 100), V3Make(0, 0, 0), V3Make(0, 1, 0), modelview)
		// Simple orthographic projection mapping [-50, 50] to clip space.
		let projection = M4.make([[Float(1.0 / 50), 0, 0, 0], [0, Float(1.0 / 50), 0, 0], [0, 0, Float(-1.0 / 500), 0], [0, 0, 0, 1]] as [[Float]])
		let viewport = V2MakeBox(0, 0, 800, 600)
		for p in [V3Make(0, 0, 0), V3Make(10, -20, 5), V3Make(-40, 30, -60)] {
			let screen = V3Project(p, modelview, projection, viewport)
			let back = V3Unproject(screen, modelview, projection, viewport)
			#expect(approx(back, p, 1e-3), "\(p) -> \(screen) -> \(back)")
		}
	}
}

// MARK: - Vectors, boxes, polygons, rays

@Suite("MatrixMath: vectors and geometry (P2 row 5)")
struct MatrixMathGeometryTests {

	@Test("FloorPowerOfTwo", arguments: [(1, 1), (2, 2), (3, 2), (4, 4), (5, 4), (1023, 512), (1024, 1024), (1025, 1024)])
	func floorPowerOfTwo(input: Int, expected: Int) {
		#expect(FloorPowerOfTwo(input) == expected)
	}

	@Test("Vector algebra basics")
	func vectorAlgebra() {
		let a = V3Make(1, 2, 3), b = V3Make(-4, 5, 0.5)
		#expect(approx(V3Add(a, b), V3Make(-3, 7, 3.5)))
		#expect(approx(V3Sub(a, b), V3Make(5, -3, 2.5)))
		#expect(approx(V3Dot(a, b), -4 + 10 + 1.5))
		let c = V3Cross(a, b)
		#expect(approx(V3Dot(c, a), 0) && approx(V3Dot(c, b), 0))
		#expect(approx(V3Length(V3Normalize(b)), 1))
		#expect(approx(V3Lerp(a, b, 0.5), V3Midpoint(a, b)))
		#expect(approx(V3DistanceBetween2Points(V3Make(0, 0, 0), V3Make(3, 4, 0)), 5))
		#expect(approx(V3IsolateGreatestComponent(V3Make(1, -7, 3)), V3Make(0, -7, 0)))
		#expect(approx(V3DistanceFromPointToPlane(V3Make(0, 5, 0), V3Make(0, 1, 0), V3Make(0, 2, 0)), 3))
	}

	@Test("2D boxes")
	func boxes2D() {
		let box = V2MakeBox(10, 20, 30, 40)
		#expect(V2BoxMinX(box) == 10 && V2BoxMaxX(box) == 40 && V2BoxMidX(box) == 25)
		#expect(V2BoxMinY(box) == 20 && V2BoxMaxY(box) == 60 && V2BoxMidY(box) == 40)
		#expect(V2BoxContains(box, V2Make(25, 40)))
		#expect(!V2BoxContains(box, V2Make(5, 40)))
		let inset = V2BoxInset(box, 5, 5)
		#expect(inset.origin.x == 15 && inset.origin.y == 25 && inset.size.width == 20 && inset.size.height == 30)
		withKnownIssue("BUG-013: V2EqualBoxes compares box1.origin.x with box2.origin.y (no callers today)") {
			#expect(V2EqualBoxes(inset, V2MakeBox(15, 25, 20, 30)))
		}
	}

	@Test("Polygon containment: convex and concave")
	func polygons() {
		let square = [V2Make(0, 0), V2Make(10, 0), V2Make(10, 10), V2Make(0, 10)]
		let lShape = [V2Make(0, 0), V2Make(10, 0), V2Make(10, 4), V2Make(4, 4), V2Make(4, 10), V2Make(0, 10)]
		#expect(V2PolygonContains(square, 4, V2Make(5, 5)))
		#expect(!V2PolygonContains(square, 4, V2Make(15, 5)))
		#expect(V2PolygonContains(lShape, 6, V2Make(2, 8)))
		#expect(!V2PolygonContains(lShape, 6, V2Make(8, 8)), "point in the L's notch")
		#expect(V2BoxIntersectsPolygon(V2MakeBox(8, 8, 4, 4), square, 4))
		#expect(!V2BoxIntersectsPolygon(V2MakeBox(20, 20, 4, 4), square, 4))
		#expect(!V2BoxIntersectsPolygon(V2MakeBox(6, 6, 2, 2), lShape, 6), "box entirely in the L's notch")
	}

	@Test("3D boxes: bounds, union, centre")
	func boxes3D() {
		let b = V3BoundsFromPoints(V3Make(5, -1, 2), V3Make(-3, 4, 0))
		#expect(approx(b.min, V3Make(-3, -1, 0)) && approx(b.max, V3Make(5, 4, 2)))
		let u = V3UnionBoxAndPoint(b, V3Make(10, 0, -5))
		#expect(approx(u.min, V3Make(-3, -1, -5)) && approx(u.max, V3Make(10, 4, 2)))
		#expect(approx(V3CenterOfBox(b), V3Make(1, 1.5, 1)))
		#expect(V3EqualBoxes(V3UnionBox(b, InvalidBox), b) != 0, "union with InvalidBox is identity")
	}

	@Test("Ray intersections: triangle, sphere")
	func rays() {
		let ray = Ray3(origin: V3Make(1, 1, 10), direction: V3Make(0, 0, -1))
		var distance: Float = 0
		var intersect = V2Make(0, 0)
		#expect(V3RayIntersectsTriangle(ray, V3Make(0, 0, 0), V3Make(10, 0, 0), V3Make(0, 10, 0), &distance, &intersect))
		#expect(approx(distance, 10))
		#expect(!V3RayIntersectsTriangle(ray, V3Make(5, 5, 0), V3Make(10, 5, 0), V3Make(5, 10, 0), &distance, &intersect))

		var sphereDistance: Float = 0
		#expect(V3RayIntersectsSphere(Ray3(origin: V3Make(0, 0, 10), direction: V3Make(0, 0, -1)), V3Make(0, 0, 0), 2, &sphereDistance))
		#expect(approx(sphereDistance, 8))
		#expect(!V3RayIntersectsSphere(Ray3(origin: V3Make(5, 0, 10), direction: V3Make(0, 0, -1)), V3Make(0, 0, 0), 2, &sphereDistance))
	}
}

// MARK: - Second batch: remaining helpers and branches (coverage toward tier A)

@Suite("MatrixMath: helpers and edge branches (P2 row 5)")
struct MatrixMathHelperTests {

	@Test("2D helpers")
	func twoD() {
		#expect(V2Add(V2Make(1, 2), V2Make(3, 4)).x == 4 && V2Sub(V2Make(1, 2), V2Make(3, 4)).y == -2)
		#expect(V2MulScalar(V2Make(1.5, -2), 2).x == 3)
		#expect(V2EqualSizes(V2MakeSize(3, 4), V2MakeSize(3, 4)) && !V2EqualSizes(V2MakeSize(3, 4), V2MakeSize(4, 3)))
		let centred = V2SizeCenteredOnPoint(V2MakeSize(10, 20), V2Make(0, 0))
		#expect(centred.origin.x == -5 && centred.origin.y == -10 && centred.size.width == 10)
		let fromPoints = V2MakeBoxFromPoints(V2Make(1, 2), V2Make(4, 8))
		#expect(fromPoints.origin.x == 1 && fromPoints.size.width == 3 && fromPoints.size.height == 6)
		let mid = V2BoxMid(V2MakeBox(0, 0, 10, 4))
		#expect(mid.x == 5 && mid.y == 2)
	}

	@Test("3D/4D helpers")
	func threeAndFourD() {
		#expect(approx(V3Negate(V3Make(1, -2, 3)), V3Make(-1, 2, -3)))
		#expect(approx(V3Mul(V3Make(1, 2, 3), V3Make(4, 5, 6)), V3Make(4, 10, 18)))
		#expect(V3EqualPoints(V3Make(1, 2, 3), V3Make(1, 2, 3)) && !V3EqualPoints(V3Make(1, 2, 3), V3Make(1, 2, 3.1)))
		// FloatsApproximatelyEqual: within 5 ULPs, or within SMALL_NUMBER for values in (-1, 1).
		#expect(V3PointsWithinTolerance(V3Make(1, 2, 3), V3Make(Float(1).nextUp.nextUp, 2, 3)))
		#expect(V3PointsWithinTolerance(V3Make(0.5, 0, 0), V3Make(0.5000001, 0, 0)))
		#expect(!V3PointsWithinTolerance(V3Make(1, 2, 3), V3Make(1.00001, 2, 3)), "~84 ULPs apart: not equal by design")
		#expect(!V3PointsWithinTolerance(V3Make(1, 2, 3), V3Make(2, 2, 3)))
		var original = V3Make(7, 8, 9)
		if let dup = V3Duplicate(&original) {
			#expect(approx(dup.pointee, original))
			free(dup)
		}
		let v4 = V4Make(2, 4, 6, 2)
		#expect(approx(V3FromV4(v4), V3Make(2, 4, 6)))
		#expect(approx(V3FromV4Normalize(v4), V3Make(1, 2, 3)), "homogeneous divide by w")
		let p4 = V4FromPoint3(V3Make(1, 2, 3))
		#expect(p4.x == 1 && p4.y == 2 && p4.z == 3 && p4.w == 1)
		let m = Matrix4Translate(Matrix4Scale(IdentityMatrix4, V3Make(2, 2, 2)), V3Make(1, 0, 0))
		let viaV4 = V4MulPointByMatrix(V4FromPoint3(V3Make(1, 1, 1)), m)
		#expect(approx(V3Make(viaV4.x, viaV4.y, viaV4.z), V3MulPointByProjMatrix(V3Make(1, 1, 1), m)))
	}

	@Test("IsolateGreatestComponent picks each axis, keeping sign",
		  arguments: [(V3Make(5, 1, -2), V3Make(5, 0, 0)), (V3Make(1, -9, 2), V3Make(0, -9, 0)), (V3Make(1, 2, 3), V3Make(0, 0, 3)),
					  (V3Make(-7, 1, 1), V3Make(-7, 0, 0)), (V3Make(0, 0, 0), V3Make(0, 0, 0))])
	func isolateGreatest(input: Vector3, expected: Vector3) {
		#expect(approx(V3IsolateGreatestComponent(input), expected))
	}

	@Test("Scale and GL-matrix multiply agree with Matrix4Multiply")
	func scaleAndGLMultiply() {
		let s = Matrix4Scale(IdentityMatrix4, V3Make(2, 3, 4))
		#expect(approx(V3MulPointByProjMatrix(V3Make(1, 1, 1), s), V3Make(2, 3, 4)))
		let a = Matrix4Translate(IdentityMatrix4, V3Make(1, 2, 3)), b = Matrix4Rotate(IdentityMatrix4, V3Make(0, 0, 90))
		var ga = [GLfloat](repeating: 0, count: 16), gb = ga, result = ga
		Matrix4GetGLMatrix4(a, &ga); Matrix4GetGLMatrix4(b, &gb)
		Matrix4MultiplyGLMatrices(&ga, &gb, &result)
		let product = Matrix4CreateFromGLMatrix4(result)
		#expect(M4.approx(product, Matrix4Multiply(a, b)) || M4.approx(product, Matrix4Multiply(b, a)),
				"GL multiply matches neither operand order")
	}

	@Test("RotateModelview yields a pure rotation (orthonormal, det 1)")
	func rotateModelview() {
		var r = Matrix4RotateModelview(IdentityMatrix4, V3Make(30, 45, 60))
		#expect(approx(Matrix4x4Determinant(&r), 1, 1e-3))
		let v = V3Make(3, 4, 12)
		#expect(approx(V3Length(V3MulPointByProjMatrix(v, r)), V3Length(v), 1e-3))
	}

	@Test("Rotation decomposition near gimbal lock (Y = ±90°) still rebuilds the matrix", arguments: [Float(90), -90])
	func gimbalLock(y: Float) {
		let r = Matrix4Rotate(IdentityMatrix4, V3Make(20, y, 35))
		for decompose in [Matrix4DecomposeXYZRotation, Matrix4DecomposeZYXRotation] {
			let angles = decompose(r)
			let rebuiltRad = Matrix4Rotate(IdentityMatrix4, V3MulScalar(angles, 180 / .pi))
			let rebuiltDeg = Matrix4Rotate(IdentityMatrix4, angles)
			// ZYX decomposition belongs to the other rotation order; only characterise that it returns finite values.
			#expect(angles.x.isFinite && angles.y.isFinite && angles.z.isFinite)
			_ = (rebuiltRad, rebuiltDeg)
		}
		let xyz = Matrix4DecomposeXYZRotation(r)
		withKnownIssue("BUG-014: at Y = +90° the X angle comes back with the wrong sign") {
			#expect(M4.approx(Matrix4Rotate(IdentityMatrix4, V3MulScalar(xyz, 180 / .pi)), r, 1e-3), "y=\(y) -> \(xyz)")
		} when: { y > 0 }
	}

	@Test("Decomposition: mirrored (negative-determinant) matrices rebuild; singular matrices are rejected")
	func decomposeSpecialCases() {
		var mirror = IdentityComponents
		mirror.scale = V3Make(-1, 1, 1)
		mirror.translate = V3Make(5, 6, 7)
		let m = Matrix4CreateTransformation(&mirror)
		var out = IdentityComponents
		#expect(Matrix4DecomposeTransformation(m, &out) != 0)
		#expect(M4.approx(Matrix4CreateTransformation(&out), m, 1e-3), "mirror rebuild\n\(M4.describe(m))")

		var singular = IdentityComponents
		singular.scale = V3Make(0, 1, 1)
		#expect(Matrix4DecomposeTransformation(Matrix4CreateTransformation(&singular), &out) == 0)

		var sheared = IdentityComponents
		sheared.shear_XY = 0.5
		let s = Matrix4CreateTransformation(&sheared)
		#expect(Matrix4DecomposeTransformation(s, &out) != 0)
		#expect(M4.approx(Matrix4CreateTransformation(&out), s, 1e-3), "shear rebuild")
	}

	@Test("AntiEuler (degrees in, degrees out) undoes a rotation")
	func antiEuler() {
		let degrees = V3Make(30, -40, 50)
		let anti = V3AntiEuler(degrees)
		let combined = Matrix4Multiply(Matrix4Rotate(IdentityMatrix4, degrees), Matrix4Rotate(IdentityMatrix4, anti))
		#expect(M4.approx(combined, IdentityMatrix4, 1e-3), "\(degrees) -> \(anti)")
	}

	@Test("Ray vs segment")
	func raySegment() {
		var distance: Float = 0
		let ray = Ray3(origin: V3Make(0, 0, 0), direction: V3Make(1, 0, 0))
		#expect(V3RayIntersectsSegment(ray, Segment3(point0: V3Make(5, -1, 0), point1: V3Make(5, 1, 0)), 0.01, &distance))
		#expect(approx(distance, 5, 1e-3))
		#expect(!V3RayIntersectsSegment(ray, Segment3(point0: V3Make(5, 2, 3), point1: V3Make(6, 2, 3)), 0.01, &distance))
	}

	@Test("Screen-space volume tests are conservative: never false when the volume overlaps the box")
	func volumeTests() {
		let unit = Box3(min: V3Make(-1, -1, -1), max: V3Make(1, 1, 1))
		#expect(VolumeCanIntersectBox(unit, IdentityMatrix4, V2MakeBox(-0.5, -0.5, 0.25, 0.25)))
		#expect(VolumeCanIntersectPoint(unit, IdentityMatrix4, V2MakeBox(-0.5, -0.5, 0.25, 0.25), 1e9))
		// Clearly disjoint: a 'true' would be allowed by the contract; record what happens.
		let far = VolumeCanIntersectBox(unit, IdentityMatrix4, V2MakeBox(50, 50, 1, 1))
		#expect(far == false, "conservative routine returned true for a box 50 units away (allowed, but notable)")
	}

	@Test("Depth on triangle / line segment in screen space")
	func depthTests() {
		var inside = V3Make(1, 1, 0)
		#expect(DepthOnTriangle(V3Make(0, 0, 0.5), V3Make(10, 0, 0.5), V3Make(0, 10, 0.5), &inside))
		#expect(approx(inside.z, 0.5))
		var outside = V3Make(9, 9, 0)
		#expect(!DepthOnTriangle(V3Make(0, 0, 0.5), V3Make(10, 0, 0.5), V3Make(0, 10, 0.5), &outside))
		var near = V3Make(5, 0.01, 0)
		#expect(DepthOnLineSegment(V3Make(0, 0, 0.25), V3Make(10, 0, 0.75), 0.01, &near))
		#expect(approx(near.z, 0.5, 1e-2))
		var far = V3Make(5, 3, 0)
		#expect(!DepthOnLineSegment(V3Make(0, 0, 0.25), V3Make(10, 0, 0.75), 0.01, &far))
	}
}
