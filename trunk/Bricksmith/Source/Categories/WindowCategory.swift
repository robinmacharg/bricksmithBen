//==============================================================================
//
// Category: WindowCategory.swift
//
//		Convenient window utility methods.
//
//  Created by Allen Smith on 3/12/05.
//  Copyright 2005. All rights reserved.
//  Ported to Swift in P5; the ObjC selectors are unchanged.
//==============================================================================
import AppKit


extension NSWindow {

	//========== frameRectForContentSize: ======================================
	//
	// Purpose:		Computes the frame rectangle (in screen coordinates) for
	//				the window if its content view has newSize.
	//
	//				This is a very handy utility method for windows with several
	//				differently-sized panes, like a preferences window.
	//
	//==========================================================================
	@objc(frameRectForContentSize:)
	func frameRect(forContentSize newSize: NSSize) -> NSRect {
		// Get the current size. (ObjC messaging a nil contentView gave a zero size.)
		let currentContentSize = self.contentView?.frame.size ?? .zero
		// And the current frame, which takes into account the title bar and toolbar.
		var newFrameRect = self.frame

		// Now adjust the frame by the difference between the size of its current
		// contents and newSize.
		newFrameRect.size.width  += newSize.width  - currentContentSize.width
		newFrameRect.size.height += newSize.height - currentContentSize.height

		newFrameRect.origin.y    -= newSize.height - currentContentSize.height

		return newFrameRect

	}//end frameRectForContentSize:


	//========== resizeToSize:animate: =========================================
	//
	// Purpose:		Resizes the window to the given frame size, anchoring the
	//				position in the upper-left of the original window frame.
	//
	//==========================================================================
	@objc(resizeToSize:animate:)
	func resize(to newSize: NSSize, animate: Bool) {
		let currentFrame = self.frame
		// NSMinX/NSMaxY, not .minX/.maxY: CGRect's accessors standardise negative sizes, NSMinX/NSMaxY don't.
		let upperLeft    = NSPoint(x: NSMinX(currentFrame), y: NSMaxY(currentFrame))
		let newRect      = NSRect(x: upperLeft.x, y: upperLeft.y - newSize.height,
								  width: newSize.width, height: newSize.height)

		self.setFrame(newRect, display: true, animate: animate)

	}//end resizeToSize:animate:

}
