//==============================================================================
//
// File:		LDrawLine.swift
//
// Purpose:		Line command.
//				Draws a line between two points.
//
//				Line format:
//				2 colour x1 y1 z1 x2 y2 z2
//
//				where
//
//				* colour is a colour code: 0-15, 16, 24, 32-47, 256-511
//				* x1, y1, z1 is the position of the first point
//				* x2, y2, z2 is the position of the second point
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6b. The superclass (LDrawDrawableElement) is still ObjC,
//  so its ivars (color, hidden) are read through -isHidden, -LDrawColor and the
//  LDrawDrawableElementCollectorColor() seam. LDrawConditionalLine (Swift)
//  subclasses this class, so it is not final.
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


@objc(LDrawLine)
class LDrawLine: LDrawDrawableElement {

	// Storage. Named apart from the accessor methods, which keep their selectors.
	@exclusivity(unchecked) private var v1: Point3 = ZeroPoint3
	@exclusivity(unchecked) private var v2: Point3 = ZeroPoint3

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
	//				2 colour x1 y1 z1 x2 y2 z2
	//
	//==========================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init?(lines: [Any]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		// No lines: the ObjC messaged nil all the way to its failure branch.
		guard let lines else {
			NSLog("the line primitive %@ was fatally invalid", "(null)")
			NSLog(" raised exception %@", "BricksmithParseException")
			return nil
		}
		// P6b: ObjC raised here (-objectAtIndex: past the end of the lines); see
		// KNOWN-BUGS BUG-P6B-drawables-1
		guard range.location < lines.count else {
			return nil
		}

		var workingLine: NSString?	= lines[range.location] as? NSString
		var parsedField: NSString?	= nil

		super.init(lines: lines, in: range, parentGroup: parentGroup)

		//Read in the line code and advance past it.
		parsedField = readNextField(&workingLine)
		//Only attempt to create the part if this is a valid line.
		if (parsedField?.integerValue ?? 0) == 2 {
			//Read in the color code.
			// (color)
			parsedField = readNextField(&workingLine)
			let parsedColor = LDrawUtilities.parseColor(fromField: parsedField as String?)
			self.setLDrawColor(parsedColor)

			//Read Vertex 1 and 2.
			self.setVertex1(readVertex(&workingLine))
			self.setVertex2(readVertex(&workingLine))
		}
		else {
			NSLog("the line primitive %@ was fatally invalid", String(describing: lines[range.location]))
			NSLog(" raised exception %@", "BricksmithParseException")
			return nil
		}
	}


	//========== initWithLines:inRange: ========================================
	//
	// Purpose:		LDrawDirective's blocking-parse convenience, which the ObjC
	//				class inherited: -[LDrawDirective initWithLines:inRange:] sends
	//				[self initWithLines:inRange:parentGroup:NULL], reaching the
	//				parse initializer above (or a subclass's).
	//
	// Notes:		Designated, not convenience: LDrawConditionalLine overrides
	//				it with a convenience initializer, which Swift allows only over
	//				a designated one.
	//
	//==========================================================================
	@objc(initWithLines:inRange:)
	override init?(lines: [Any]!, in range: NSRange) {
		super.init(lines: lines, in: range)
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
		let copied = super.copy(with: zone) as! LDrawLine

		copied.setVertex1(self.vertex1())
		copied.setVertex2(self.vertex2())

		return copied
	}


	// MARK: - DIRECTIVES

	//========== drawSelf: =====================================================
	//
	// Purpose:		Draw this directive and its subdirectives by calling APIs on
	//				the passed in renderer, then calling drawSelf on children.
	//
	// Notes:		Lines use this message to get their drag handles drawn if
	//				needed.  They do not draw their actual GL primitive because
	//				that has already been "collected" by some parent capable of
	//				accumulating a mesh.
	//
	//==========================================================================
	@objc(drawSelf:)
	override func drawSelf(_ renderer: (any LDrawRenderer)!) {
		_ = self.revalCache(.DisplayList)
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
		_ = self.revalCache(.DisplayList)

		// One C call reads `hidden` and `color` straight from the ObjC ivars (no getter sends, no
		// retain per primitive). The colour choice is unchanged: 16 -> current, 24 -> complement,
		// else the RGBA. (For a nil colour the ObjC passed an uninitialised buffer; zeros here.)
		var rgba: (GLfloat, GLfloat, GLfloat, GLfloat) = (0, 0, 0, 0)
		withUnsafeMutablePointer(to: &rgba) { rp in
			rp.withMemoryRebound(to: GLfloat.self, capacity: 4) { scratch in
				var color: UnsafeMutablePointer<GLfloat>? = nil
				guard LDrawDrawableElementCollectorColor(self, scratch, &color) else { return }

				let (v1, v2) = (self.v1, self.v2)
				var v: (GLfloat, GLfloat, GLfloat, GLfloat, GLfloat, GLfloat) = (
					v1.x, v1.y, v1.z,
					v2.x, v2.y, v2.z)
				var n: (GLfloat, GLfloat, GLfloat) = (0, -1, 0)
				withUnsafeMutablePointer(to: &v) { vp in
					vp.withMemoryRebound(to: GLfloat.self, capacity: 6) { v in
						withUnsafeMutablePointer(to: &n) { np in
							np.withMemoryRebound(to: GLfloat.self, capacity: 3) { n in
								renderer.drawLine(v, normal: n, color: color)
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
			let segment					= Segment3(point0: worldVertex1, point1: worldVertex2)
			var tolerance: Float		= 1.0 / scaleFactor
			var intersectDepth: Float	= 0
			var intersects				= false

			// Lines drawn to 1 pixel regardless of scale, so the pick tolerance must be
			// 1 pixel. We approximate this by relying on the view providing a 1 pixel
			// to 1 unit correspondence at 100%.
			tolerance   = 1.0 / scaleFactor
			tolerance  *= 1.5 // allow a little fudge

			intersects = V3RayIntersectsSegment(pickRay, segment, tolerance, &intersectDepth)

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


	//========== boxTest:transform:boundsOnly:creditObject:hits: ===============
	//
	// Purpose:		Check for intersections with screen-space bounding box.
	//
	//==========================================================================
	@objc(boxTest:transform:boundsOnly:creditObject:hits:)
	override func boxTest(_ bounds: Box2, transform: Matrix4, boundsOnly: Bool, creditObject: Any!, hits: NSMutableSet!) -> Bool {
		if self.isHidden() == false {
			let worldVertex1 = V3MulPointByProjMatrix(self.v1, transform)
			let worldVertex2 = V3MulPointByProjMatrix(self.v2, transform)

			var line: (Point2, Point2) = (
				V2Make(worldVertex1.x, worldVertex1.y),
				V2Make(worldVertex2.x, worldVertex2.y))

			let intersects = withUnsafePointer(to: &line) {
				$0.withMemoryRebound(to: Point2.self, capacity: 2) { V2BoxIntersectsPolygon(bounds, $0, 2) }
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
		if self.isHidden() == false {
			let worldVertex1	= V3MulPointByProjMatrix(self.v1, transform)
			let worldVertex2	= V3MulPointByProjMatrix(self.v2, transform)
			let tolerance2		= (bounds.size.width*bounds.size.width+bounds.size.height*bounds.size.height)*0.25

			var probe = V3Make(pt.x, pt.y, bestDepth.pointee)

			if DepthOnLineSegment(worldVertex1, worldVertex2, tolerance2, &probe) {
				if probe.z <= bestDepth.pointee {
					bestDepth.pointee  = probe.z
					bestObject.pointee = creditObject.map { $0 as AnyObject } ?? self
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
	//				2 colour x1 y1 z1 x2 y2 z2
	//
	//==========================================================================
	@objc(write)
	override func write() -> String! {
		// Same bytes as stringWithFormat:@"2 %@ ..." ("%@" of nil printed "(null)").
		let (v1, v2) = (self.v1, self.v2)
		func f(_ number: Float) -> String { LDrawUtilities.outputString(for: number) ?? "(null)" }
		let color = LDrawUtilities.outputString(for: self.lDrawColor()) ?? "(null)"

		return "2 \(color) \(f(v1.x)) \(f(v1.y)) \(f(v1.z)) \(f(v2.x)) \(f(v2.y)) \(f(v2.z))"
	}


	//========== writeElementToVertexBuffer:withColor:wireframe: ===============
	//
	// Purpose:		Writes this object into the specified vertex buffer, which is
	//				a pointer to the offset into which the first vertex point's
	//				data is to be stored. Store subsequent vertexs after the
	//				first.
	//
	//==========================================================================
	@objc(writeElementToVertexBuffer:withColor:wireframe:)
	override func write(toVertexBuffer vertexBuffer: UnsafeMutablePointer<VBOVertexData>!, with drawingColor: LDrawColor!,
						wireframe: Bool) -> UnsafeMutablePointer<VBOVertexData>! {
		let normal: (GLfloat, GLfloat, GLfloat)				= (0.0, -1.0, 0.0) //lines need normals! Who knew?
		var components: (GLfloat, GLfloat, GLfloat, GLfloat)	= (0, 0, 0, 0)

		withUnsafeMutablePointer(to: &components) {
			$0.withMemoryRebound(to: GLfloat.self, capacity: 4) { drawingColor?.getRGBA($0) }
		}

		vertexBuffer[0].position = (self.v1.x, self.v1.y, self.v1.z)
		vertexBuffer[0].normal   = normal
		vertexBuffer[0].color    = components

		vertexBuffer[1].position = (self.v2.x, self.v2.y, self.v2.z)
		vertexBuffer[1].normal   = normal
		vertexBuffer[1].color    = components

		return vertexBuffer + 2
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
		return NSLocalizedString("Line", comment: "")
	}


	//========== iconName ======================================================
	//
	// Purpose:		Returns the name of image file used to display this kind of
	//				object, or nil if there is no icon.
	//
	//==========================================================================
	@objc(iconName)
	override func iconName() -> String! {
		return "LinePrimitive"
	}


	//========== inspectorClassName ============================================
	//
	// Purpose:		Returns the name of the class used to inspect this one.
	//
	//==========================================================================
	@objc(inspectorClassName)
	override func inspectorClassName() -> String! {
		return "InspectionLine"
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

		let bounds = V3BoundsFromPoints(self.v1, self.v2)

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
	//
	// Purpose:		Returns the line's start point.
	//
	//==========================================================================
	@objc(vertex1)
	func vertex1() -> Point3 {
		return self.v1
	}


	//========== vertex2 =======================================================
	//
	// Purpose:		Returns the line's end point.
	//
	//==========================================================================
	@objc(vertex2)
	func vertex2() -> Point3 {
		return self.v2
	}


	//========== setSelected: ==================================================
	//
	// Purpose:		Somebody make this a protocol method.
	//
	//==========================================================================
	@objc(setSelected:)
	override func setSelected(_ flag: Bool) {
		super.setSelected(flag)

		if flag == true {
			let handle1: LDrawDragHandle = LDrawDragHandle(tag: 1, position: self.v1)
			let handle2: LDrawDragHandle = LDrawDragHandle(tag: 2, position: self.v2)

			handle1.setTarget(self)
			handle2.setTarget(self)

			handle1.setAction(#selector(dragHandleChanged(_:)))
			handle2.setAction(#selector(dragHandleChanged(_:)))

			self.dragHandles = [handle1, handle2]
		}
		else {
			self.dragHandles = nil
		}
	}


	//========== setVertex1: ===================================================
	//
	// Purpose:		Sets the line's start point.
	//
	//==========================================================================
	@objc(setVertex1:)
	func setVertex1(_ newVertex: Point3) {
		self.v1 = newVertex
		self.invalCache([.CacheFlagBounds, .DisplayList])

		if let dragHandles = self.dragHandles {
			dragHandles[0].setPosition(newVertex, updateTarget: false)
		}
	}


	//========== setVertex2: ===================================================
	//
	// Purpose:		Sets the line's end point.
	//
	//==========================================================================
	@objc(setVertex2:)
	func setVertex2(_ newVertex: Point3) {
		self.v2 = newVertex
		self.invalCache([.CacheFlagBounds, .DisplayList])

		if let dragHandles = self.dragHandles {
			dragHandles[1].setPosition(newVertex, updateTarget: false)
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

		self.setVertex1(newVertex1)
		self.setVertex2(newVertex2)
	}


	// MARK: - UTILITIES

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

		self.v1 = V3MulPointByProjMatrix(self.v1, transform)
		self.v2 = V3MulPointByProjMatrix(self.v2, transform)

		lines.add(self)
	}


	//========== registerUndoActions ===========================================
	//
	// Purpose:		Registers the undo actions that are unique to this subclass,
	//				not to any superclass.
	//
	// Notes:		The undo proxy is messaged dynamically, as in ObjC. Never ask
	//				it respondsToSelector: (that is recorded as the action).
	//
	//==========================================================================
	@objc(registerUndoActions:)
	override func registerUndoActions(_ undoManager: UndoManager!) {
		super.registerUndoActions(undoManager)

		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setVertex2(self.vertex2())
		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setVertex1(self.vertex1())

		undoManager.setActionName(NSLocalizedString("UndoAttributesLine", comment: ""))
	}
}
