//==============================================================================
//
// File:		BezierPathCategory.swift
//
// Purpose:		Handy Bezier path methods Apple forgot.
//
//  Created by Allen Smith on 6/11/07.
//  Copyright 2007. All rights reserved.
//  Ported to Swift in P5; the ObjC selector is unchanged.
//==============================================================================
import AppKit


extension NSBezierPath {

	//---------- bezierPathWithRect:radiusPercentage: ----------------[static]--
	//
	// Purpose:		Creates a beautiful Round Rect. It's as fun as MacPaint!
	//
	// Parameters:	rect				- bounds in which the round rect is
	//									  inscribed
	//				radiusPercentage	- percentage (0-100) of the width of the
	//									  bounds which should be rounded. Passing
	//									  100 will cause the top and bottom to
	//									  become semicircles.
	//
	// Notes:		The ObjC entry point. It always makes a plain NSBezierPath,
	//				as the original did ([NSBezierPath bezierPath], not [self ...]).
	//
	//--------------------------------------------------------------------------
	@objc(bezierPathWithRect:radiusPercentage:)
	class func bezierPath(withRect rect: NSRect, radiusPercentage: CGFloat) -> NSBezierPath! {
		let roundRect = NSBezierPath()
		roundRect.appendRoundRect(rect, radiusPercentage: radiusPercentage)
		return roundRect

	}//end bezierPathWithRect:radiusPercentage:


	//---------- init(rect:radiusPercentage:) ----------------------------------
	//
	// Purpose:		The Swift spelling. Swift imported the ObjC class factory as
	//				`init!(rect:radiusPercentage:)`; a Swift-defined class method is
	//				not imported that way, so this keeps Swift callers unchanged.
	//				Swift-only (@nonobjc): ObjC sees only the factory above.
	//
	//--------------------------------------------------------------------------
	@nonobjc
	convenience init!(rect: NSRect, radiusPercentage: CGFloat) {
		self.init()
		self.appendRoundRect(rect, radiusPercentage: radiusPercentage)
	}


	//---------- appendRoundRect(_:radiusPercentage:) ------------[private]--
	//
	// Purpose:		The original algorithm, appended to the (empty) receiver.
	//				NSMinX etc., not .minX: CGRect's accessors standardise
	//				negative sizes.
	//
	//--------------------------------------------------------------------------
	private func appendRoundRect(_ rect: NSRect, radiusPercentage: CGFloat) {
		let roundRect = self
		let radius    = NSWidth(rect)/2 * (radiusPercentage/100)

		//start with a blank path.

		// start above the lower left corner, drawing counter-clockwise
		roundRect.move(to: NSPoint(x: NSMinX(rect),          y: NSMinY(rect) + radius))

		//Bottom left corner
		roundRect.appendArc(from: NSPoint(x: NSMinX(rect),          y: NSMinY(rect)),
							to:   NSPoint(x: NSMinX(rect) + radius, y: NSMinY(rect)),
							radius: radius)
		//Bottom side
		roundRect.line(to: NSPoint(x: NSMaxX(rect) - radius, y: NSMinY(rect)))


		//Bottom Right Corner
		roundRect.appendArc(from: NSPoint(x: NSMaxX(rect),          y: NSMinY(rect)),
							to:   NSPoint(x: NSMaxX(rect),          y: NSMinY(rect) + radius),
							radius: radius)
		//Right side
		roundRect.line(to: NSPoint(x: NSMaxX(rect),          y: NSMaxY(rect) - radius))


		//Top right corner
		roundRect.appendArc(from: NSPoint(x: NSMaxX(rect),          y: NSMaxY(rect)),
							to:   NSPoint(x: NSMaxX(rect) - radius, y: NSMaxY(rect)),
							radius: radius)
		//Top side
		roundRect.line(to: NSPoint(x: NSMinX(rect) + radius, y: NSMaxY(rect)))


		//Top left corner
		roundRect.appendArc(from: NSPoint(x: NSMinX(rect),          y: NSMaxY(rect)),
							to:   NSPoint(x: NSMinX(rect),          y: NSMaxY(rect) - radius),
							radius: radius)
		//Left side
		//roundRect.line(to: NSPoint(x: NSMinX(rect), y: NSMinY(rect) + radius))
		roundRect.close()
	}

}
