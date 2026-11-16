//==============================================================================
//
// File:		LDrawDragHandle.swift
//
// Purpose:		In-scene widget to manipulate a vertex.
//
// Notes:		Sub-classes LDrawDrawableElement to get some dragging behavior.
//
// Modified:	02/25/2011 Allen Smith. Creation Date.
//
//				Ported to Swift in P6a. The superclass (LDrawDrawableElement) is
//				still ObjC.
//==============================================================================

import Foundation
import OpenGL.GL

// Shared tag to draw the standard drag handle sphere
private let HandleDiameter: Float = 7.0


@objc(LDrawDragHandle)
final class LDrawDragHandle: LDrawDrawableElement {

	// Storage. Named apart from the accessor methods (-tag, -position, ...),
	// which keep their ObjC selectors.
	private var handleTag: Int = 0
	private var handlePosition: Point3 = ZeroPoint3
	private var handleInitialPosition: Point3 = ZeroPoint3

	private var handleTarget: AnyObject?	// strong, as the ARC ivar was
	private var handleAction: Selector?


	//========== initWithTag:position: =========================================
	//
	// Purpose:		Initialize the object with a tag to identify what vertex it
	//				is connected to.
	//
	// Notes:		A convenience init, so every superclass initializer stays
	//				inherited. The ObjC version called [super init], which is
	//				the same method: this class doesn't override -init.
	//
	//==========================================================================
	@objc(initWithTag:position:)
	convenience init!(tag tagIn: Int, position positionIn: Point3) {
		self.init()
		self.handleTag             = tagIn
		self.handlePosition        = positionIn
		self.handleInitialPosition = positionIn
	}


	// MARK: - ACCESSORS

	//========== initialPosition ===============================================
	//
	// Purpose:		Returns the coordinate this handle what at when initialized.
	//
	//==========================================================================
	@objc(initialPosition)
	func initialPosition() -> Point3 {
		return self.handleInitialPosition
	}


	//========== isSelected ====================================================
	//
	// Purpose:		Drag handles only show up when their associated primitive is
	//				selected, so we always report being selected. This will make
	//				us more transparent to the view selection code.
	//
	//==========================================================================
	@objc(isSelected)
	override func isSelected() -> Bool {
		return true
	}


	//========== position ======================================================
	//
	// Purpose:		Returns the world-coordinate location of the handle.
	//
	//==========================================================================
	@objc(position)
	override func position() -> Point3 {
		return self.handlePosition
	}


	//========== tag ===========================================================
	//
	// Purpose:		Returns the identifier for this handle. Used to associate the
	//				handle with a vertex.
	//
	//==========================================================================
	@objc(tag)
	func tag() -> Int {
		return self.handleTag
	}


	//========== target ========================================================
	//
	// Purpose:		Returns the object which owns the drag handle.
	//
	//==========================================================================
	@objc(target)
	func target() -> Any! {
		return self.handleTarget
	}


	//========== setAction: ====================================================
	//
	// Purpose:		Sets the method to invoke when the handle is repositioned.
	//
	//==========================================================================
	@objc(setAction:)
	func setAction(_ actionIn: Selector) {
		self.handleAction = actionIn
	}


	//========== setPosition:updateTarget: =====================================
	//
	// Purpose:		Updates the current handle position, and triggers the action
	//				if update flag is YES.
	//
	//==========================================================================
	@objc(setPosition:updateTarget:)
	func setPosition(_ positionIn: Point3, updateTarget update: Bool) {
		self.handlePosition = positionIn

		if update {
			// -performSelector:withObject:. The action returns void: discard the
			// unretained result, never take a value from it.
			_ = (self.handleTarget as? NSObjectProtocol)?.perform(self.handleAction, with: self)
		}
	}


	//========== setTarget: ====================================================
	//
	// Purpose:		Sets the object to invoke the action on.
	//
	//==========================================================================
	@objc(setTarget:)
	func setTarget(_ sender: Any!) {
		self.handleTarget = sender.map { $0 as AnyObject }
	}


	// MARK: - DRAWING

	//========== drawSelf: =====================================================
	//
	// Purpose:		Draw this directive and its subdirectives by calling APIs on
	//				the passed in renderer, then calling drawSelf on children.
	//
	// Notes:		Drag handles don't use DLs - they simply push their pos
	//				to the renderer immediately.
	//
	//==========================================================================
	@objc(drawSelf:)
	override func drawSelf(_ renderer: (any LDrawRenderer)!) {
		var xyz: (GLfloat, GLfloat, GLfloat) = (self.handlePosition.x, self.handlePosition.y, self.handlePosition.z)
		withUnsafeMutablePointer(to: &xyz) {
			$0.withMemoryRebound(to: GLfloat.self, capacity: 3) {
				renderer.drawDragHandle($0, withSize: HandleDiameter / 2)
			}
		}
	}


	//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =====
	//
	// Purpose:		Tests the directive for an intersection between the pickRay
	//				and spherical drag handle.
	//
	//==========================================================================
	@objc(hitTest:transform:viewScale:boundsOnly:creditObject:hits:)
	override func hitTest(_ pickRay: Ray3, transform: Matrix4, viewScale scaleFactor: Float, boundsOnly: Bool,
						  creditObject: Any!, hits: NSMutableDictionary!) {
		var handleScale: Float		= 0.0
		var drawRadius: Float		= 0.0
		var intersectDepth: Float	= 0
		var intersects				= false

		// The ObjC used double literals here (1.0 / float, float *= 1.5).
		handleScale = Float(1.0 / Double(scaleFactor))
		drawRadius  = HandleDiameter / 2 * handleScale
		drawRadius  = Float(Double(drawRadius) * 1.5) // allow a little fudge

		intersects = V3RayIntersectsSphere(pickRay, self.handlePosition, drawRadius, &intersectDepth)

		if intersects {
			LDrawUtilities.registerHit(for: self, depth: intersectDepth, creditObject: creditObject, hits: hits)
		}
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
		let v1 = V3MulPointByProjMatrix(self.handlePosition, transform)
		if V2BoxContains(bounds, V2Make(v1.x, v1.y)) {
			if v1.z <= bestDepth.pointee {
				bestDepth.pointee  = v1.z
				bestObject.pointee = creditObject.map { $0 as AnyObject } ?? self
			}
		}
	}


	// MARK: - ACTIONS

	//========== moveBy: =======================================================
	//
	// Purpose:		Displace the receiver by the given amounts in each direction.
	//				The amounts in moveVector or relative to the element's
	//				current location.
	//
	//				Subclasses are required to move by exactly this amount. Any
	//				adjustments they wish to make need to be returned in
	//				-displacementForNudge:.
	//
	//==========================================================================
	@objc(moveBy:)
	override func move(by moveVector: Vector3) {
		let newPosition = V3Add(self.handlePosition, moveVector)

		self.setPosition(newPosition, updateTarget: true)
	}
}
