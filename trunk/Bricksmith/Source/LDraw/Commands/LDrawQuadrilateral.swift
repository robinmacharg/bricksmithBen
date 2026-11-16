//==============================================================================
//
// File:		LDrawQuadrilateral.swift
//
// Purpose:		Quadrilateral command.
//				Draws a four-sided, filled shape between four points.
//
//				Line format:
//				4 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 x4 y4 z4
//
//				where
//
//				* colour is a colour code: 0-15, 16, 24, 32-47, 256-511
//				* x1, y1, z1 is the position of the first point
//				* x2, y2, z2 is the position of the second point
//				* x3, y3, z3 is the position of the third point
//				* x4, y4, z4 is the position of the fourth point
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6a. The superclass (LDrawDrawableElement) is still ObjC,
//  so its ivars (color, hidden) are read through -LDrawColor and -isHidden.
//==============================================================================

import Foundation
import OpenGL.GL

/// -[LDrawUtilities readNextField:remainder:], keeping the fields as NSString.
private func readNextField(_ line: inout NSString?) -> NSString? {
	return LDrawUtilities.readNextField(line as String?, remainder: &line) as NSString?
}

/// Reads three fields as a point, with -floatValue (0 for a missing field, as messaging nil).
private func readVertex(_ line: inout NSString?) -> Point3 {
	var vertex = ZeroPoint3
	vertex.x = readNextField(&line)?.floatValue ?? 0
	vertex.y = readNextField(&line)?.floatValue ?? 0
	vertex.z = readNextField(&line)?.floatValue ?? 0
	return vertex
}



@objc(LDrawQuadrilateral)
final class LDrawQuadrilateral: LDrawDrawableElement {

	// Storage. Named apart from the accessor methods, which keep their selectors.
	@exclusivity(unchecked) private var v1: Point3 = ZeroPoint3
	@exclusivity(unchecked) private var v2: Point3 = ZeroPoint3
	@exclusivity(unchecked) private var v3: Point3 = ZeroPoint3
	@exclusivity(unchecked) private var v4: Point3 = ZeroPoint3

	@exclusivity(unchecked) private var normal: Vector3 = ZeroPoint3

	@exclusivity(unchecked) private var dragHandles: [LDrawDragHandle]? = nil


	// MARK: - INITIALIZATION

	//========== init ==========================================================
	//
	// Purpose:		Plain initializer: copying uses [[[self class] alloc] init],
	//				and LDrawDirective's parse initializer calls [self init].
	//
	//==========================================================================
	@objc(init)
	override init() {
		super.init()
	}


	//========== initWithLines:inRange:parentGroup: ============================
	//
	// Purpose:		Returns the LDraw directive based on lineFromFile, a single
	//				line of LDraw code from a file.
	//
	//				directive should have the format:
	//
	//				4 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 x4 y4 z4
	//
	//==========================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init?(lines: [NSObject]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		var workingLine: NSString?	= lines[range.location] as? NSString
		var parsedField: NSString?	= nil

		super.init(lines: lines, in: range, parentGroup: parentGroup)

		//Read in the line code and advance past it.
		parsedField = readNextField(&workingLine)
		//Only attempt to create the part if this is a valid line.
		if (parsedField?.integerValue ?? 0) == 4 {
			//Read in the color code.
			// (color)
			parsedField = readNextField(&workingLine)
			let parsedColor = LDrawUtilities.parseColor(fromField: parsedField as String?)
			self.setLDrawColor(parsedColor)

			//Read Vertex 1, 2, 3 and 4.
			self.setVertex1(readVertex(&workingLine))
			self.setVertex2(readVertex(&workingLine))
			self.setVertex3(readVertex(&workingLine))
			self.setVertex4(readVertex(&workingLine))

			self.fixBowtie()
		}
		else {
			NSLog("the quadrilateral primitive %@ was fatally invalid", String(describing: lines[range.location]))
			NSLog(" raised exception %@", "BricksmithParseException")
			return nil
		}
	}


	//========== initWithLines:inRange: ========================================
	//
	// Purpose:		LDrawDirective's blocking-parse convenience; calls the
	//				parse initializer above, as the ObjC one does.
	//
	//==========================================================================
	@objc(initWithLines:inRange:)
	override convenience init?(lines: [NSObject]!, in range: NSRange) {
		self.init(lines: lines, in: range, parentGroup: nil)
	}


	//========== initWithCoder: ================================================
	//
	// Purpose:		Reads a representation of this object from the given coder,
	//				which is assumed to always be a keyed decoder. This allows us
	//				to read and write LDraw objects as NSData.
	//
	//==========================================================================
	@objc(initWithCoder:)
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)

		//Decoding structures is a bit messy. memcpy: the bytes have no alignment promise.
		memcpy(&self.v1, decoder.decodeBytes(forKey: "vertex1", returnedLength: nil), MemoryLayout<Point3>.size)
		memcpy(&self.v2, decoder.decodeBytes(forKey: "vertex2", returnedLength: nil), MemoryLayout<Point3>.size)
		memcpy(&self.v3, decoder.decodeBytes(forKey: "vertex3", returnedLength: nil), MemoryLayout<Point3>.size)
		memcpy(&self.v4, decoder.decodeBytes(forKey: "vertex4", returnedLength: nil), MemoryLayout<Point3>.size)
		memcpy(&self.normal, decoder.decodeBytes(forKey: "normal", returnedLength: nil), MemoryLayout<Vector3>.size)
	}


	//========== encodeWithCoder: ==============================================
	//
	// Purpose:		Writes a representation of this object to the given coder,
	//				which is assumed to always be a keyed decoder. This allows us
	//				to read and write LDraw objects as NSData.
	//
	//==========================================================================
	@objc(encodeWithCoder:)
	override func encode(with encoder: NSCoder) {
		super.encode(with: encoder)

		encodeBytes(of: self.v1, encoder, "vertex1")
		encodeBytes(of: self.v2, encoder, "vertex2")
		encodeBytes(of: self.v3, encoder, "vertex3")
		encodeBytes(of: self.v4, encoder, "vertex4")
		encodeBytes(of: self.normal, encoder, "normal")
	}

	/// [encoder encodeBytes:&value length:sizeof(Point3) forKey:key]
	private func encodeBytes(of value: Point3, _ encoder: NSCoder, _ key: String) {
		withUnsafeBytes(of: value) {
			encoder.encodeBytes($0.bindMemory(to: UInt8.self).baseAddress, length: MemoryLayout<Point3>.size, forKey: key)
		}
	}


	//========== copyWithZone: =================================================
	//
	// Purpose:		Returns a duplicate of this file.
	//
	//==========================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copied = (super.copy(with: zone) as AnyObject) as! LDrawQuadrilateral	// (a class cast: `as!` from Any is a slow existential cast)

		copied.setVertex1(self.vertex1())
		copied.setVertex2(self.vertex2())
		copied.setVertex3(self.vertex3())
		copied.setVertex4(self.vertex4())

		return copied
	}


	// MARK: - DIRECTIVES

	//========== drawSelf: =====================================================
	//
	// Purpose:		Draw this directive and its subdirectives by calling APIs on
	//				the passed in renderer, then calling drawSelf on children.
	//
	// Notes:		Quads use this message to get their drag handles drawn if
	//				needed.  They do not draw their actual GL primitive because
	//				that has already been "collected" by some parent capable of
	//				accumulating a mesh.
	//
	//==========================================================================
	@objc(drawSelf:)
	override func drawSelf(_ renderer: (any LDrawRenderer)!) {
		if self.isHidden() == false {
			if let dragHandles = self.dragHandles {
				for handle in dragHandles {
					handle.drawSelf(renderer)
				}
			}
		}
	}


	//========== collectSelf: ==================================================
	//
	// Purpose:		Collect self is called on each directive by its parents to
	//				accumulate _mesh_ data into a display list for later drawing.
	//				The collector protocol passed in is some object capable of
	//				remembering the collectable data.
	//
	//				Real GL primitives participate by passing their color and
	//				geometry data to the collector.
	//
	//==========================================================================
	@objc(collectSelf:)
	override func collectSelf(_ renderer: (any LDrawCollector)!) {
		collectPrimitive(renderer)
	}


	//---------- collectPrimitive(_:) ------------------------------------------
	//
	// Purpose:		The body of -collectSelf:. LDrawStep calls it directly for an
	//				instance of exactly this class: entering through the @objc
	//				method costs a retain and release of self and of the renderer
	//				per primitive, which the ObjC primitives never paid.
	//
	//--------------------------------------------------------------------------
	@nonobjc final func collectPrimitive(_ renderer: (any LDrawCollector)!) {
		_ = self.revalCache(.DisplayList)

		// One C call reads `hidden` and `color` straight from the ObjC ivars (no getter sends, no
		// retain per primitive; P6a perf). The colour choice is unchanged: 16 -> current, 24 ->
		// complement, else the RGBA (zeros for a nil colour, where [nil colorCode] was 0).
		var rgba: (GLfloat, GLfloat, GLfloat, GLfloat) = (0, 0, 0, 0)
		withUnsafeMutablePointer(to: &rgba) { rp in
			rp.withMemoryRebound(to: GLfloat.self, capacity: 4) { scratch in
				var color: UnsafeMutablePointer<GLfloat>? = nil
				guard LDrawDrawableElementCollectorColor(self, scratch, &color) else { return }

				let (v1, v2, v3, v4) = (self.v1, self.v2, self.v3, self.v4)
				var v: (GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat) = (
					v1.x, v1.y, v1.z,
					v2.x, v2.y, v2.z,
					v3.x, v3.y, v3.z,
					v4.x, v4.y, v4.z)
				var n: (GLfloat, GLfloat, GLfloat) = (self.normal.x, self.normal.y, self.normal.z)
				withUnsafeMutablePointer(to: &v) { vp in
					vp.withMemoryRebound(to: GLfloat.self, capacity: 12) { v in
						withUnsafeMutablePointer(to: &n) { np in
							np.withMemoryRebound(to: GLfloat.self, capacity: 3) { n in
								renderer.drawQuad(v, normal: n, color: color)
							}
						}
					}
				}
			}
		}
	}


	//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =====
	//
	// Purpose:		Tests the directive and any of its children for
	//				intersections between the pickRay and the directive's drawn
	//				content.
	//
	//==========================================================================
	@objc(hitTest:transform:viewScale:boundsOnly:creditObject:hits:)
	override func hitTest(_ pickRay: Ray3, transform: Matrix4, viewScale scaleFactor: Float, boundsOnly: Bool,
						  creditObject: Any!, hits: NSMutableDictionary!) {
		if self.isHidden() == false {
			let worldVertex1			= V3MulPointByProjMatrix(self.v1, transform)
			let worldVertex2			= V3MulPointByProjMatrix(self.v2, transform)
			let worldVertex3			= V3MulPointByProjMatrix(self.v3, transform)
			let worldVertex4			= V3MulPointByProjMatrix(self.v4, transform)
			var intersectDepth: Float	= 0
			var intersects				= false

			// Tesselate the quad and test both halves for intersections.
			// Note: I am intentionally ignoring multiple intersections possible with
			//		 non-coplanar quads. Don't make such things!
			intersects = V3RayIntersectsTriangle(pickRay,
												 worldVertex1, worldVertex2, worldVertex3,
												 &intersectDepth, nil)
			if intersects == false {
				intersects = V3RayIntersectsTriangle(pickRay,
													 worldVertex3, worldVertex4, worldVertex1,
													 &intersectDepth, nil)
			}

			if intersects {
				LDrawUtilities.registerHit(for: self, depth: intersectDepth, creditObject: creditObject, hits: hits)
			}

			if let dragHandles = self.dragHandles {
				for handle in dragHandles {
					handle.hitTest(pickRay, transform: transform, viewScale: scaleFactor, boundsOnly: boundsOnly, creditObject: nil, hits: hits)
				}
			}
		}
	}


	//========== clipTriangles =================================================
	//
	// Purpose:		The quad in clip space as two triangles (1 2 3, 3 4 1),
	//				clipped into ndc_tris (room for 36 floats). Returns the
	//				number of clipped triangles.
	//
	//==========================================================================
	private func clipTriangles(_ transform: Matrix4, _ ndc_tris: UnsafeMutablePointer<Float>) -> Int {
		let clipVertex1 = V4MulPointByMatrix(V4FromPoint3(self.v1), transform)
		let clipVertex2 = V4MulPointByMatrix(V4FromPoint3(self.v2), transform)
		let clipVertex3 = V4MulPointByMatrix(V4FromPoint3(self.v3), transform)
		let clipVertex4 = V4MulPointByMatrix(V4FromPoint3(self.v4), transform)

		var h_tri1: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float) = (
			clipVertex1.x, clipVertex1.y, clipVertex1.z, clipVertex1.w,
			clipVertex2.x, clipVertex2.y, clipVertex2.z, clipVertex2.w,
			clipVertex3.x, clipVertex3.y, clipVertex3.z, clipVertex3.w)

		var h_tri2: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float) = (
			clipVertex3.x, clipVertex3.y, clipVertex3.z, clipVertex3.w,
			clipVertex4.x, clipVertex4.y, clipVertex4.z, clipVertex4.w,
			clipVertex1.x, clipVertex1.y, clipVertex1.z, clipVertex1.w)

		var triCount = withUnsafePointer(to: &h_tri1) {
			$0.withMemoryRebound(to: Float.self, capacity: 12) { clipTriangle($0, ndc_tris) }
		}
		triCount += withUnsafePointer(to: &h_tri2) {
			$0.withMemoryRebound(to: Float.self, capacity: 12) { clipTriangle($0, ndc_tris + 9 * Int(triCount)) }
		}
		return Int(triCount)
	}


	//========== boxTest:transform:boundsOnly:creditObject:hits: ===============
	//
	// Purpose:		Check for intersections with screen-space geometry.
	//
	//==========================================================================
	@objc(boxTest:transform:boundsOnly:creditObject:hits:)
	override func boxTest(_ bounds: Box2, transform: Matrix4, boundsOnly: Bool, creditObject: Any!, hits: NSMutableSet!) -> Bool {
		boxTestPrimitive(bounds, transform: transform, boundsOnly: boundsOnly, creditObject: creditObject, hits: hits)
	}


	//---------- boxTestPrimitive(...) -----------------------------------------
	//
	// Purpose:		The body of -boxTest:..., which LDrawStep also calls directly
	//				for an instance of exactly this class (as collectPrimitive(_:)).
	//
	//--------------------------------------------------------------------------
	@nonobjc final func boxTestPrimitive(_ bounds: Box2, transform: Matrix4, boundsOnly: Bool, creditObject: Any!, hits: NSMutableSet!) -> Bool {
		if self.isHidden() == false {
			return withUnsafeTemporaryAllocation(of: Float.self, capacity: 36) { ndc_tris in
				let ndc = ndc_tris.baseAddress!
				let triCount = self.clipTriangles(transform, ndc)
				for i in 0 ..< triCount {
					var tri: (Point2, Point2, Point2) = (
						V2Make(ndc[i*9+0], ndc[i*9+1]),
						V2Make(ndc[i*9+3], ndc[i*9+4]),
						V2Make(ndc[i*9+6], ndc[i*9+7]))

					let intersects = withUnsafePointer(to: &tri) {
						$0.withMemoryRebound(to: Point2.self, capacity: 3) { V2BoxIntersectsPolygon(bounds, $0, 3) }
					}
					if intersects {
						LDrawUtilities.registerHit(for: self, creditObject: creditObject, hits: hits)
						if creditObject != nil {
							return true
						}
					}
				}
				return false
			}
		}
		return false
	}


	//========== depthTest:inBox:transform:creditObject:bestObject:bestDepth: ==
	//
	// Purpose:		depthTest finds the closest primitive (in screen space)
	//				overlapping a given point, as well as its device coordinate
	//				depth.
	//
	//==========================================================================
	@objc(depthTest:inBox:transform:creditObject:bestObject:bestDepth:)
	override func depthTest(_ pt: Point2, inBox bounds: Box2, transform: Matrix4, creditObject: Any!,
							bestObject: AutoreleasingUnsafeMutablePointer<AnyObject?>!,
							bestDepth: UnsafeMutablePointer<Float>!) {
		depthTestPrimitive(pt, inBox: bounds, transform: transform, creditObject: creditObject, bestObject: bestObject, bestDepth: bestDepth)
	}


	//---------- depthTestPrimitive(...) ---------------------------------------
	//
	// Purpose:		The body of -depthTest:..., which LDrawStep also calls directly
	//				for an instance of exactly this class (as collectPrimitive(_:)).
	//
	//--------------------------------------------------------------------------
	@nonobjc final func depthTestPrimitive(_ pt: Point2, inBox bounds: Box2, transform: Matrix4, creditObject: Any!,
										   bestObject: AutoreleasingUnsafeMutablePointer<AnyObject?>!,
										   bestDepth: UnsafeMutablePointer<Float>!) {
		if self.isHidden() == false {
			// One probe for the whole loop: DepthOnTriangle writes its z.
			var probe = V3Make(pt.x, pt.y, bestDepth.pointee)

			withUnsafeTemporaryAllocation(of: Float.self, capacity: 36) { ndc_tris in
				let ndc = ndc_tris.baseAddress!
				let triCount = self.clipTriangles(transform, ndc)
				for i in 0 ..< triCount {
					let ndcVertex1 = V3Make(ndc[i*9+0], ndc[i*9+1], ndc[i*9+2])
					let ndcVertex2 = V3Make(ndc[i*9+3], ndc[i*9+4], ndc[i*9+5])
					let ndcVertex3 = V3Make(ndc[i*9+6], ndc[i*9+7], ndc[i*9+8])

					if DepthOnTriangle(ndcVertex1, ndcVertex2, ndcVertex3, &probe) {
						if probe.z <= bestDepth.pointee {
							bestDepth.pointee  = probe.z
							bestObject.pointee = creditObject.map { $0 as AnyObject } ?? self
						}
					}
				}
			}

			if let dragHandles = self.dragHandles {
				for handle in dragHandles {
					handle.depthTest(pt, inBox: bounds, transform: transform, creditObject: creditObject, bestObject: bestObject, bestDepth: bestDepth)
				}
			}
		}
	}


	//========== write =========================================================
	//
	// Purpose:		Returns a line that can be written out to a file.
	//				Line format:
	//				4 colour x1 y1 z1 x2 y2 z2 x3 y3 z3 x4 y4 z4
	//
	//==========================================================================
	@objc(write)
	override func write() -> String! {
		// Same bytes as stringWithFormat:@"4 %@ ..." ("%@" of nil printed "(null)").
		let (v1, v2, v3, v4) = (self.v1, self.v2, self.v3, self.v4)
		func f(_ number: Float) -> String { LDrawUtilities.outputString(for: number) ?? "(null)" }
		let color = LDrawUtilities.outputString(for: self.lDrawColor()) ?? "(null)"

		return "4 \(color) \(f(v1.x)) \(f(v1.y)) \(f(v1.z)) \(f(v2.x)) \(f(v2.y)) \(f(v2.z))"
			+ " \(f(v3.x)) \(f(v3.y)) \(f(v3.z)) \(f(v4.x)) \(f(v4.y)) \(f(v4.z))"
	}


	//========== writeElementToVertexBuffer:withColor:wireframe: ===============
	//
	// Purpose:		Writes this object into the specified vertex buffer, which is
	//				a pointer to the offset into which the first vertex point's
	//				data is to be stored. Store subsequent vertexs after the
	//				first.
	//
	// Notes:		Only the TESSELATE_QUADS == 0 branch (BricksmithBuildConfig.h)
	//				is ported: Swift can't test the C macro.
	//
	//==========================================================================
	@objc(writeElementToVertexBuffer:withColor:wireframe:)
	override func write(toVertexBuffer vertexBuffer: UnsafeMutablePointer<VBOVertexData>!, with drawingColor: LDrawColor!,
						wireframe: Bool) -> UnsafeMutablePointer<VBOVertexData>! {
		var components: (GLfloat, GLfloat, GLfloat, GLfloat) = (0, 0, 0, 0)
		var vertexCount = 0

		withUnsafeMutablePointer(to: &components) {
			$0.withMemoryRebound(to: GLfloat.self, capacity: 4) { drawingColor?.getRGBA($0) }
		}

		let n = (self.normal.x, self.normal.y, self.normal.z)
		func store(_ index: Int, _ p: Point3) {
			vertexBuffer[index].position = (p.x, p.y, p.z)
			vertexBuffer[index].normal   = n
			vertexBuffer[index].color    = components
		}

		if wireframe == false {
			store(0, self.v1)
			store(1, self.v2)
			store(2, self.v3)

			// Last vertex makes the full quad
			store(3, self.v4)

			vertexCount = 4
		}
		else {
			// edge1
			store(0, self.v1)
			store(1, self.v2)

			// edge2
			store(2, self.v2)
			store(3, self.v3)

			// edge3
			store(4, self.v3)
			store(5, self.v4)

			// edge4
			store(6, self.v4)
			store(7, self.v1)

			vertexCount = 8
		}

		return vertexBuffer + vertexCount
	}


	// MARK: - DISPLAY

	//========== browsingDescription ===========================================
	//
	// Purpose:		Returns a representation of the directive as a short string
	//				which can be presented to the user.
	//
	//==========================================================================
	@objc(browsingDescription)
	override func browsingDescription() -> String! {
		return NSLocalizedString("Quadrilateral", comment: "")
	}


	//========== iconName ======================================================
	//
	// Purpose:		Returns the name of image file used to display this kind of
	//				object, or nil if there is no icon.
	//
	//==========================================================================
	@objc(iconName)
	override func iconName() -> String! {
		return "QuadPrimitive"
	}


	//========== inspectorClassName ============================================
	//
	// Purpose:		Returns the name of the class used to inspect this one.
	//
	//==========================================================================
	@objc(inspectorClassName)
	override func inspectorClassName() -> String! {
		return "InspectionQuadrilateral"
	}


	// MARK: - ACCESSORS

	//========== boundingBox3 ==================================================
	//
	// Purpose:		Returns the minimum and maximum points of the box which
	//				perfectly contains this object.
	//
	//==========================================================================
	@objc(boundingBox3)
	override func boundingBox3() -> Box3 {
		_ = self.revalCache(.CacheFlagBounds)

		if self.isHidden() == true {
			return InvalidBox
		}

		var bounds: Box3 = InvalidBox

		bounds = V3BoundsFromPoints(self.v1, self.v2)
		bounds = V3UnionBoxAndPoint(bounds, self.v3)
		bounds = V3UnionBoxAndPoint(bounds, self.v4)

		return bounds
	}


	//========== position ======================================================
	//
	// Purpose:		Returns some position for the element. This is used by
	//				drag-and-drop. This is not necessarily human-usable
	//				information.
	//
	//==========================================================================
	@objc(position)
	override func position() -> Point3 {
		return self.v1
	}


	//========== vertex1 =======================================================
	@objc(vertex1)
	func vertex1() -> Point3 {
		return self.v1
	}


	//========== vertex2 =======================================================
	@objc(vertex2)
	func vertex2() -> Point3 {
		return self.v2
	}


	//========== vertex3 =======================================================
	@objc(vertex3)
	func vertex3() -> Point3 {
		return self.v3
	}


	//========== vertex4 =======================================================
	@objc(vertex4)
	func vertex4() -> Point3 {
		return self.v4
	}


	//========== setSelected: ==================================================
	//
	// Purpose:		Identifies the object as selected.
	//
	//==========================================================================
	@objc(setSelected:)
	override func setSelected(_ flag: Bool) {
		super.setSelected(flag)

		// Create the drag handle objects
		if flag == true {
			let handle1: LDrawDragHandle = LDrawDragHandle(tag: 1, position: self.v1)
			let handle2: LDrawDragHandle = LDrawDragHandle(tag: 2, position: self.v2)
			let handle3: LDrawDragHandle = LDrawDragHandle(tag: 3, position: self.v3)
			let handle4: LDrawDragHandle = LDrawDragHandle(tag: 4, position: self.v4)

			handle1.setTarget(self)
			handle2.setTarget(self)
			handle3.setTarget(self)
			handle4.setTarget(self)

			handle1.setAction(#selector(dragHandleChanged(_:)))
			handle2.setAction(#selector(dragHandleChanged(_:)))
			handle3.setAction(#selector(dragHandleChanged(_:)))
			handle4.setAction(#selector(dragHandleChanged(_:)))

			self.dragHandles = [handle1, handle2, handle3, handle4]
		}
		else {
			self.dragHandles = nil
		}
	}


	//========== setVertex1: ===================================================
	//
	// Purpose:		Sets the quadrilateral's first vertex.
	//
	//==========================================================================
	@objc(setVertex1:)
	func setVertex1(_ newVertex: Point3) {
		self.v1 = newVertex
		self.recomputeNormal()
		self.invalCache([.CacheFlagBounds, .DisplayList])

		if let dragHandles = self.dragHandles {
			dragHandles[0].setPosition(newVertex, updateTarget: false)
		}
	}


	//========== setVertex2: ===================================================
	//
	// Purpose:		Sets the quadrilateral's second vertex.
	//
	//==========================================================================
	@objc(setVertex2:)
	func setVertex2(_ newVertex: Point3) {
		self.v2 = newVertex
		self.recomputeNormal()
		self.invalCache([.CacheFlagBounds, .DisplayList])

		if let dragHandles = self.dragHandles {
			dragHandles[1].setPosition(newVertex, updateTarget: false)
		}
	}


	//========== setVertex3: ===================================================
	//
	// Purpose:		Sets the quadrilateral's third vertex.
	//
	//==========================================================================
	@objc(setVertex3:)
	func setVertex3(_ newVertex: Point3) {
		self.v3 = newVertex
		self.recomputeNormal()
		self.invalCache([.CacheFlagBounds, .DisplayList])

		if let dragHandles = self.dragHandles {
			dragHandles[2].setPosition(newVertex, updateTarget: false)
		}
	}


	//========== setVertex4: ===================================================
	//
	// Purpose:		Sets the quadrilateral's fourth vertex.
	//
	//==========================================================================
	@objc(setVertex4:)
	func setVertex4(_ newVertex: Point3) {
		self.v4 = newVertex
		self.recomputeNormal()
		self.invalCache([.CacheFlagBounds, .DisplayList])

		if let dragHandles = self.dragHandles {
			dragHandles[3].setPosition(newVertex, updateTarget: false)
		}
	}


	// MARK: - ACTIONS

	//========== dragHandleChanged: ============================================
	//
	// Purpose:		One of the drag handles on our vertexes has changed.
	//
	//==========================================================================
	@objc(dragHandleChanged:)
	func dragHandleChanged(_ sender: Any!) {
		let handle			= sender as! LDrawDragHandle
		let newPosition		= handle.position()
		let vertexNumber	= handle.tag()

		switch vertexNumber {
			case 1: self.setVertex1(newPosition)
			case 2: self.setVertex2(newPosition)
			case 3: self.setVertex3(newPosition)
			case 4: self.setVertex4(newPosition)
			default: break
		}
	}


	//========== moveBy: =======================================================
	//
	// Purpose:		Moves the receiver in the specified direction.
	//
	//==========================================================================
	@objc(moveBy:)
	override func move(by moveVector: Vector3) {
		let newVertex1 = V3Add(self.v1, moveVector)
		let newVertex2 = V3Add(self.v2, moveVector)
		let newVertex3 = V3Add(self.v3, moveVector)
		let newVertex4 = V3Add(self.v4, moveVector)

		self.setVertex1(newVertex1)
		self.setVertex2(newVertex2)
		self.setVertex3(newVertex3)
		self.setVertex4(newVertex4)
	}


	// MARK: - UTILITIES

	//========== fixBowtie =====================================================
	//
	// Purpose:		Four points in any order define a quadrilateral, but if you
	//				want to draw one in OpenGL, you need to be able to trace
	//				around the edges in order. If two vertices are out of order,
	//				you wind up with a "bowtie" shape, which needs to be
	//				corrected back into a quadrilateral.
	//
	//					   4        3     3        4     4        2
	//						+------+       +------+       +      +
	//						|      |        \    /        |\    /|
	//						|      |         \  /         | \  / |
	//						|      |          \/          |  \/  |
	//						|      |          /\          |  /\  |
	//						|      |         /  \         | /  \ |
	//						|      |        /    \        |/    \|
	//						+------+       +------+       +      +
	//					   1        2     1        2     1        3
	//
	//						correct         case 1         case 2
	//									switch 3 & 4   switch 2 & 3
	//
	// Notes:		Swaps the stored vertices only: no normal recompute, no
	//				cache invalidation, no handle update (as in ObjC).
	//
	//==========================================================================
	@objc(fixBowtie)
	func fixBowtie() {
		//If correct, the crosses of these three pairs should all point up.
		let vector1_2 = V3Sub(self.v2, self.v1) //1 to 2
		let vector1_4 = V3Sub(self.v4, self.v1) //1 to 4
		let vector3_4 = V3Sub(self.v4, self.v3)
		let vector3_2 = V3Sub(self.v2, self.v3)
		let vector4_1 = V3Sub(self.v1, self.v4)
		let vector4_3 = V3Sub(self.v3, self.v4)

		let cross1 = V3Cross(vector1_2, vector1_4)
		let cross3 = V3Cross(vector3_4, vector3_2)
		let cross4 = V3Cross(vector4_1, vector4_3)

		//When crosses point different directions, we have a bowtie. To test this,
		// recall that cos x = (u • v) / (||u|| ||v||)
		// cos(180) = -1 and cos(0) = 1. So if u•v is negative, we have opposing
		// vectors (since the denominator is always positive, we can ignore it).

		//If 1 & 4 point opposite directions, we have a case 1 bowtie
		if V3Dot(cross1, cross4) < 0 {
			//vectors point in opposite directions
			let swapPoint = self.v3
			self.v3 = self.v4
			self.v4 = swapPoint
		}
		//If 3 & 4 point opposite directions, we have a case 2 bowtie
		else if V3Dot(cross3, cross4) < 0 {
			let swapPoint = self.v2
			self.v2 = self.v3
			self.v3 = swapPoint
		}
	}


	//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =
	//
	// Purpose:		Appends the directive into the appropriate container.
	//
	//==========================================================================
	@objc(flattenIntoLines:triangles:quadrilaterals:other:currentColor:currentTransform:normalTransform:recursive:)
	override func flatten(intoLines lines: NSMutableArray!, triangles: NSMutableArray!, quadrilaterals: NSMutableArray!,
						  other everythingElse: NSMutableArray!, currentColor parentColor: LDrawColor!,
						  currentTransform transform: Matrix4, normalTransform: Matrix3, recursive: Bool) {
		super.flatten(intoLines: lines,
					  triangles: triangles,
					  quadrilaterals: quadrilaterals,
					  other: everythingElse,
					  currentColor: parentColor,
					  currentTransform: transform,
					  normalTransform: normalTransform,
					  recursive: recursive)

		self.v1     = V3MulPointByProjMatrix(self.v1, transform)
		self.v2     = V3MulPointByProjMatrix(self.v2, transform)
		self.v3     = V3MulPointByProjMatrix(self.v3, transform)
		self.v4     = V3MulPointByProjMatrix(self.v4, transform)

		self.normal = V3MulPointByMatrix(self.normal, normalTransform)

		quadrilaterals.add(self)
	}


	//========== recomputeNormal ===============================================
	//
	// Purpose:		Finds the normal vector for this surface.
	//
	//==========================================================================
	@objc(recomputeNormal)
	func recomputeNormal() {
		let vector1 = V3Sub(self.v2, self.v1)
		let vector2 = V3Sub(self.v4, self.v1)

		self.normal = V3Cross(vector1, vector2)
	}


	//========== registerUndoActions ===========================================
	//
	// Purpose:		Registers the undo actions that are unique to this subclass,
	//				not to any superclass.
	//
	// Notes:		The undo proxy is messaged dynamically, as in ObjC. Never ask
	//				it respondsToSelector: (that is recorded as the action) and
	//				never cast it to this final class (static dispatch).
	//
	//==========================================================================
	@objc(registerUndoActions:)
	override func registerUndoActions(_ undoManager: UndoManager!) {
		super.registerUndoActions(undoManager)

		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setVertex4(self.vertex4())
		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setVertex3(self.vertex3())
		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setVertex2(self.vertex2())
		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setVertex1(self.vertex1())

		undoManager.setActionName(NSLocalizedString("UndoAttributesQuadrilateral", comment: ""))
	}
}
