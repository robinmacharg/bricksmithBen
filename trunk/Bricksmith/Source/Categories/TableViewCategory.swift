//==============================================================================
//
// File:		TableViewCategory.swift
//
// Purpose:		NSTableView added functionality.
//
// Modified:	04/01/2012 Allen Smith. Creation Date.
//				Ported to Swift in P5; the ObjC selector is unchanged.
//
//==============================================================================
import AppKit


extension NSTableView {

	//========== scrollRowToCenter: ============================================
	//
	// Purpose:		Scrolls the table view's clip view such that the row is centered
	//				in the scroll view.
	//
	//==========================================================================
	@objc(scrollRowToCenter:)
	func scrollRow(toCenter rowIndex: Int) {
		let rowRect     = self.rect(ofRow: rowIndex)
		// (ObjC messaging a nil enclosingScrollView gave NSZeroRect, and a nil
		// documentView converts from window coordinates.)
		var scrollFrame = self.enclosingScrollView?.documentVisibleRect ?? .zero
		var scrollPoint = NSPoint.zero

		scrollFrame = self.convert(scrollFrame, from: self.enclosingScrollView?.documentView)
		scrollPoint = rowRect.origin

		// NSHeight, not .height: CGRect's accessor standardises negative sizes.
		scrollPoint.y -= NSHeight(scrollFrame) / 2
		scrollPoint.y += NSHeight(rowRect) / 2

		scrollPoint.y = floor(scrollPoint.y)
		// MAX(0, y) from NSObjCRuntime.h is (0 < y ? y : 0); Swift's max() differs for -0.0 and NaN.
		scrollPoint.y = (0 < scrollPoint.y) ? scrollPoint.y : 0

		self.scroll(scrollPoint)
	}

}
