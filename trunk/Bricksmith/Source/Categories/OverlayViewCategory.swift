//==============================================================================
//
// File:		OverlayViewCategory.swift
//
// Purpose:		Overlay views: an NSView drawn in a child window over another
//				view (OverlayHelperView / OverlayHelperWindow do the work).
//
//				Ported from OverlayViewCategory.m (P5). The four optional hooks
//				(-viewWillBecomeOverlay etc.) are declared, not implemented, in
//				OverlayHelperWindow.m, which calls them via -respondsToSelector:.
//
//==============================================================================
import AppKit

extension NSView {

	//========== addOverlayView: ===============================================
	//
	// Purpose:		Adds a helper view that hosts overlayView in a child window.
	//
	//==========================================================================
	@objc(addOverlayView:)
	func addOverlayView(_ overlayView: NSView!) {
		// Add a special NSView to the parent so we can track a few things...
		let helperView: OverlayHelperView = OverlayHelperView(overlayView: overlayView)

		self.addSubview(helperView)
	}

	//========== removeOverlayView: ============================================
	//
	// Purpose:		Removes the helper view that manages overlayViewIn, if any.
	//
	//==========================================================================
	@objc(removeOverlayView:)
	func removeOverlayView(_ overlayViewIn: NSView!) {
		var overlayHelper: NSView? = nil

		// Find the helper view which manages the given overlay
		for currentView in self.subviews {
			let overlaySelector = NSSelectorFromString("overlayView")
			if currentView.responds(to: overlaySelector) {
				// Sent to whatever answers it, as the ObjC original did (not only OverlayHelperView).
				let currentOverlay = currentView.perform(overlaySelector)?.takeUnretainedValue() as AnyObject?

				if currentOverlay === overlayViewIn {
					overlayHelper = currentView
					break
				}
			}
		}

		overlayHelper?.removeFromSuperview()

		self.needsDisplay = true
	}
}
