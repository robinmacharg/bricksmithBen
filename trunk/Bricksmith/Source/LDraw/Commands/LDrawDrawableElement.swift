//==============================================================================
//
// File:		LDrawDrawableElement.swift
//
// Purpose:		Abstract superclass for all LDraw elements that can actually be
//				drawn (polygons and parts). The class wraps common functionality
//				such as color and mouse-selection.
//
//  Created by Allen Smith on 4/20/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6c. The superclass (LDrawDirective) is still ObjC.
//  LDrawDrawableElement.h keeps the VBOVertexData struct and its imports.
//  The P6a C seam LDrawDrawableElementCollectorColor() is now the Swift
//  method collectorColor(_:_:), which the Swift subclasses call directly.
//==============================================================================

import Foundation
import OpenGL.GL


@objc(LDrawDrawableElement)
class LDrawDrawableElement: LDrawDirective, LDrawColorable, LDrawMovableDirective {

	// Storage (the ObjC ivars `color` and `hidden`). Read per primitive on the
	// collect and draw paths; mutated only through -setLDrawColor: and -setHidden:
	// (and the decoder, through those setters).
	@exclusivity(unchecked) private var elementColor: LDrawColor? = nil
	@exclusivity(unchecked) private var elementHidden: Bool = false		//YES if we don't draw this.


	// MARK: - INITIALIZATION

	//========== init ==========================================================
	//
	// Purpose:		Create a fresh object. This is the default initializer.
	//
	//==========================================================================
	@objc(init)
	override init() {
		super.init()

		self.elementHidden = false
	}


	//========== initWithLines:inRange:parentGroup: ============================
	//
	// Purpose:		LDrawDirective's parse initializer, which the ObjC class
	//				inherited. Declared so the Swift subclasses keep overriding it.
	//
	//==========================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init!(lines: [NSObject]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		super.init(lines: lines, in: range, parentGroup: parentGroup)
	}


	//========== initWithLines:inRange: ========================================
	//
	// Purpose:		LDrawDirective's blocking-parse convenience, which the ObjC
	//				class inherited: -[LDrawDirective initWithLines:inRange:] sends
	//				[self initWithLines:inRange:parentGroup:NULL].
	//
	// Notes:		Designated, not convenience: the subclasses override it with
	//				convenience initializers, which Swift allows only over a
	//				designated one (LDrawLine overrides it as designated).
	//
	//==========================================================================
	@objc(initWithLines:inRange:)
	override init!(lines: [NSObject]!, in range: NSRange) {
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

		// (The ObjC passed the decoded object on unchecked; it is always an LDrawColor.)
		self.setLDrawColor(decoder.decodeObject(forKey: "color") as? LDrawColor)
		self.setHidden(decoder.decodeBool(forKey: "hidden"))

		// If the part's color comes from the library, use the library version
		// instead of the dearchived one.
		//
		// Note: This won't help us for file-local colors. They are messy. We don't
		//		 know what model we belong to until after the part's step has been
		//		 fully unpacked and added to the model. Only then can we finally
		//		 retrieve the model's local color library. Currently we have no
		//		 hooks for that operation; we need a -directiveDidMoveToModel: call
		//		 and distribute it to all children.
		// (A nil colour's code is 0, as messaging nil.)
		let colorLibrary	= ColorLibrary.shared()
		let libraryColor	= colorLibrary?.color(forCode: self.elementColor?.colorCode() ?? LDrawColorT(rawValue: 0))
		if let libraryColor {
			self.setLDrawColor(libraryColor)
		}
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

		encoder.encode(self.elementColor, forKey: "color")
		encoder.encode(self.elementHidden, forKey: "hidden")
	}


	//========== copyWithZone: =================================================
	//
	// Purpose:		Returns a duplicate of this file.
	//
	//==========================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copied = (super.copy(with: zone) as AnyObject) as! LDrawDrawableElement	// (a class cast: `as!` from Any is a slow existential cast)

		// Colors are references, so they don't get copied
		copied.setLDrawColor(self.lDrawColor())

		return copied
	}


	// MARK: - DIRECTIVES

	//========== writeToVertexBuffer:parentColor:wireframe: ====================
	//
	// Purpose:		Resolve the correct color
	//
	//==========================================================================
	@objc(writeToVertexBuffer:parentColor:wireframe:)
	func write(toVertexBuffer vertexBuffer: UnsafeMutablePointer<VBOVertexData>!, parentColor: LDrawColor!,
			   wireframe: Bool) -> UnsafeMutablePointer<VBOVertexData>! {
		var endPointer: UnsafeMutablePointer<VBOVertexData>? = nil

		if parentColor == nil || self.elementColor == nil {
			NSLog("nil color")
		}

		switch self.elementColor?.colorCode() ?? LDrawColorT(rawValue: 0) {
		case LDrawCurrentColor:
			//Just draw; don't fool with colors. A significant portion of our
			// drawing code probably falls into this category.
			endPointer = self.write(toVertexBuffer: vertexBuffer, with: parentColor, wireframe: wireframe)

		case LDrawEdgeColor:
			// We'll need to turn this on to support file-local colors.
			//				ColorLibrary	*colorLibrary	= [[[self enclosingDirective] enclosingModel] colorLibrary];
			//				LDrawColor		*colorObject	= [colorLibrary colorForCode:self->color];
			endPointer = self.write(toVertexBuffer: vertexBuffer, with: parentColor?.compliment(), wireframe: wireframe)

		default:	// (LDrawColorCustomRGB and everything else)
			endPointer = self.write(toVertexBuffer: vertexBuffer, with: self.elementColor, wireframe: wireframe)
		}

		return endPointer
	}


	//========== writeElementToVertexBuffer:withColor:wireframe: ===============
	//
	// Purpose:		Copies the actual vertex data into the buffer, now that setup
	//				has been done in -writeToVertexBuffer:
	//
	//==========================================================================
	@objc(writeElementToVertexBuffer:withColor:wireframe:)
	func write(toVertexBuffer vertexBuffer: UnsafeMutablePointer<VBOVertexData>!, with drawingColor: LDrawColor!,
			   wireframe: Bool) -> UnsafeMutablePointer<VBOVertexData>! {
		//implemented by subclasses.
		return nil
	}


	//---------- collectorColor(_:_:) ------------------------------------------
	//
	// Purpose:		The colour argument for the collector (or renderer push), read
	//				straight from the stored properties for the Swift subclasses'
	//				hot paths (no message send or retain per primitive). Formerly
	//				the C function LDrawDrawableElementCollectorColor().
	//
	// Returns:		false if the element is hidden. Otherwise sets outColor exactly
	//				as the ObjC primitives chose it: current colour (16) ->
	//				LDrawRenderCurrentColor (nil), edge colour (24) ->
	//				LDrawRenderComplimentColor (-1), anything else -> `scratch`
	//				filled by -getColorRGBA: (left untouched for a nil colour).
	//
	//--------------------------------------------------------------------------
	@nonobjc @inline(__always)
	final func collectorColor(_ scratch: UnsafeMutablePointer<GLfloat>,
							  _ outColor: inout UnsafeMutablePointer<GLfloat>?) -> Bool {
		if self.elementHidden == true {
			return false
		}

		// Unretained, as the C seam's local was: the element owns the colour.
		unowned(unsafe) let color = self.elementColor
		guard let color else {
			// [nil colorCode] is 0 (neither 16 nor 24); [nil getColorRGBA:] does nothing.
			outColor = scratch
			return true
		}
		let colorCode = color.colorCode()
		if colorCode == LDrawCurrentColor {
			outColor = nil								// LDrawRenderCurrentColor
		}
		else if colorCode == LDrawEdgeColor {
			outColor = UnsafeMutablePointer(bitPattern: -1)	// LDrawRenderComplimentColor
		}
		else {
			color.getRGBA(scratch)
			outColor = scratch
		}
		return true
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
		let bounds = InvalidBox

		//You shouldn't be here. Look in a subclass.

		return bounds
	}


	//========== projectedBoundingBoxWithModelView:projection:view: ============
	//
	// Purpose:		Returns the 2D projection (you should ignore the z) of the
	//				object's bounds.
	//
	//==========================================================================
	@objc(projectedBoundingBoxWithModelView:projection:view:)
	func projectedBoundingBox(withModelView modelView: Matrix4, projection: Matrix4, view viewport: Box2) -> Box3 {
		let bounds			= self.boundingBox3()
		var windowPoint		= ZeroPoint3
		var projectedBounds	= InvalidBox

		if V3EqualBoxes(bounds, InvalidBox) == 0 {
			// front lower left
			windowPoint		= V3Project(bounds.min,
										modelView, projection, viewport)
			projectedBounds	= V3UnionBoxAndPoint(projectedBounds, windowPoint)

			// front lower right
			windowPoint		= V3Project(V3Make(bounds.max.x, bounds.min.y, bounds.min.z),
										modelView, projection, viewport)
			projectedBounds	= V3UnionBoxAndPoint(projectedBounds, windowPoint)

			// front upper right
			windowPoint		= V3Project(V3Make(bounds.max.x, bounds.max.y, bounds.min.z),
										modelView, projection, viewport)
			projectedBounds	= V3UnionBoxAndPoint(projectedBounds, windowPoint)

			// front upper left
			windowPoint		= V3Project(V3Make(bounds.min.x, bounds.max.y, bounds.min.z),
										modelView, projection, viewport)
			projectedBounds	= V3UnionBoxAndPoint(projectedBounds, windowPoint)

			// back lower left
			windowPoint		= V3Project(V3Make(bounds.min.x, bounds.min.y, bounds.max.z),
										modelView, projection, viewport)
			projectedBounds	= V3UnionBoxAndPoint(projectedBounds, windowPoint)

			// back lower right
			windowPoint		= V3Project(V3Make(bounds.max.x, bounds.min.y, bounds.max.z),
										modelView, projection, viewport)
			projectedBounds	= V3UnionBoxAndPoint(projectedBounds, windowPoint)

			// back upper right
			windowPoint		= V3Project(V3Make(bounds.max.x, bounds.max.y, bounds.max.z),
										modelView, projection, viewport)
			projectedBounds	= V3UnionBoxAndPoint(projectedBounds, windowPoint)

			// back upper left
			windowPoint		= V3Project(V3Make(bounds.min.x, bounds.max.y, bounds.max.z),
										modelView, projection, viewport)
			projectedBounds	= V3UnionBoxAndPoint(projectedBounds, windowPoint)
		}

		return projectedBounds
	}


	//========== isHidden ======================================================
	//
	// Purpose:		Returns whether this element will be drawn or not.
	//
	//==========================================================================
	@objc(isHidden)
	func isHidden() -> Bool {
		return self.elementHidden
	}


	//========== LDrawColor ====================================================
	//
	// Purpose:		Returns the LDraw color code of the receiver.
	//
	//==========================================================================
	@objc(LDrawColor)
	func lDrawColor() -> LDrawColor! {
		return self.elementColor
	}


	//========== position ======================================================
	//
	// Purpose:		Returns some position for the element. This is used by
	//				drag-and-drop. This is not necessarily human-usable information.
	//
	//==========================================================================
	@objc(position)
	func position() -> Point3 {
		return ZeroPoint3
	}


	//========== setHidden: ====================================================
	//
	// Purpose:		Sets whether this part will be drawn, or whether it will be
	//				skipped during drawing. This setting only affects drawing;
	//				hidden parts will always be written out. Also, note that
	//				hiddenness is a temporary state; it is not saved and restored.
	//
	//==========================================================================
	@objc(setHidden:)
	func setHidden(_ flag: Bool) {
		if self.elementHidden != flag {
			self.elementHidden = flag
			self.invalCache([.CacheFlagBounds, .DisplayList])
		}
	}


	//========== setLDrawColor: ================================================
	//
	// Purpose:		Sets the color of this element.
	//
	//==========================================================================
	@objc(setLDrawColor:)
	func setLDrawColor(_ newColor: LDrawColor!) {
		self.elementColor = newColor
		self.invalCache(.DisplayList)	// Needed to force anyone who is cached to recompute the new DL with possibly baked color!
	}


	// MARK: - MOVEMENT

	//========== displacementForNudge: =========================================
	//
	// Purpose:		Returns the amount by which the element wants to move, given a
	//				"nudge" in the specified direction. A "nudge" is generated by
	//				pressing the arrow keys. If they feel it appropriate, subclasses
	//				are perfectly welcome to scale this value. (LDrawParts do this.)
	//
	//==========================================================================
	@objc(displacementForNudge:)
	func displacement(forNudge nudgeVector: Vector3) -> Vector3 {
		//possibly refined by subclasses.
		return nudgeVector
	}


	//========== moveBy: =======================================================
	//
	// Purpose:		Displace the receiver by the given amounts in each direction.
	//				The amounts in moveVector or relative to the element's current
	//				location.
	//
	//				Subclasses are required to move by exactly this amount. Any
	//				adjustments they wish to make need to be returned in
	//				-displacementForNudge:.
	//
	//==========================================================================
	@objc(moveBy:)
	func move(by moveVector: Vector3) {
		//implemented by subclasses.
	}


	//========== position:snappedToGrid: =======================================
	//
	// Purpose:		Orients position at discrete points separated by the given grid
	//				spacing.
	//
	// Notes:		This method may be overridden by subclasses to provide more
	//				intelligent grid alignment.
	//
	//				This method is provided mainly as a service to drag-and-drop.
	//				In the case of LDrawParts, you should generally avoid this
	//				method in favor of
	//				-[LDrawPart components:snappedToGrid:minimumAngle:].
	//
	//==========================================================================
	@objc(position:snappedToGrid:)
	func position(_ position: Point3, snappedToGrid gridSpacing: Float) -> Point3 {
		var position = position
		position.x = roundf(position.x/gridSpacing) * gridSpacing
		position.y = roundf(position.y/gridSpacing) * gridSpacing
		position.z = roundf(position.z/gridSpacing) * gridSpacing

		return position
	}


	// MARK: - UTILITIES

	//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =
	//
	// Purpose:		Appends the directive into the appropriate container.
	//
	// Notes:		This is used to flatten a complicated hiearchy of primitives and
	//				part references to files containing yet more primitives into a
	//				single flat list, which may be drawn to produce a shape visually
	//				identical to the original structure. The flattened structure,
	//				however, has the advantage that it is much faster to traverse
	//				during drawing.
	//
	//				This is the core of -[LDrawModel optimizeStructure].
	//
	//==========================================================================
	@objc(flattenIntoLines:triangles:quadrilaterals:other:currentColor:currentTransform:normalTransform:recursive:)
	override func flatten(intoLines lines: NSMutableArray!, triangles: NSMutableArray!, quadrilaterals: NSMutableArray!,
						  other everythingElse: NSMutableArray!, currentColor parentColor: LDrawColor!,
						  currentTransform transform: Matrix4, normalTransform: Matrix3, recursive: Bool) {
		// Resolve the correct color and set it. Our subclasses will be responsible
		// for then adding themselves to the correct list.

		// Figure out the actual color of the directive.
		// (Codes of nil colours are 0, as messaging nil.)
		let noColor = LDrawColorT(rawValue: 0)

		if (self.elementColor?.colorCode() ?? noColor) == LDrawCurrentColor {
			if (parentColor?.colorCode() ?? noColor) == LDrawCurrentColor {
				// just add
			}
			else {
				// set directiveCopy to parent color
				self.setLDrawColor(parentColor)
			}
		}
		else if (self.elementColor?.colorCode() ?? noColor) == LDrawEdgeColor {
			if (parentColor?.colorCode() ?? noColor) == LDrawCurrentColor {
				// just add
			}
			else {
				// set directiveCopy to compliment color
				let complimentColor = parentColor?.compliment()

				self.setLDrawColor(complimentColor)

				// then add.
			}
		}
		else {
			// This directive is already explicitly colored. Just add.
		}
	}
}
