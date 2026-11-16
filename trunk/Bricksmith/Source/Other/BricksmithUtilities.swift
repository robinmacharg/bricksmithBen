//==============================================================================
//
// File:		BricksmithUtilities.swift
//
// Purpose:		Miscellaneous utility methods for the Bricksmith application.
//
// Notes:		Utility methods specific to LDraw syntax, manipulation, or
//				display or found in LDrawUtilities.
//
//				Ported from BricksmithUtilities.m (P5). The grid-mode enums stay
//				in BricksmithUtilities.h, because ObjC headers use them.
//
// Modified:	02/07/2011 Allen Smith. Creation Date.
//
//==============================================================================
import AppKit

@objc(BricksmithUtilities)
final class BricksmithUtilities: NSObject {

	//---------- dragImageWithOffset: --------------------------------[static]--
	//
	// Purpose:		Returns the image used to denote drag-and-drop of parts.
	//
	// Notes:		We don't use this image when dragging rows in the file contents,
	//				just when using physically moving parts within the model.
	//
	//--------------------------------------------------------------------------
	@objc(dragImageWithOffset:)
	class func dragImage(withOffset dragImageOffset: NSPointPointer!) -> NSImage! {
		let brickImage = NSImage(named: "Brick")
		let border: CGFloat = 3
		let brickSize = brickImage?.size ?? .zero	// [nil size] in the original
		let dragImageSize = NSSize(width: brickSize.width + border * 2, height: brickSize.height + border * 2)
		let dragImage = NSImage(size: dragImageSize)
		let arrowCursorImage = NSCursor.arrow.image
		let arrowSize = arrowCursorImage.size

		dragImage.lockFocus()

		NSColor(deviceWhite: 0.6, alpha: 0.75).set()
		let background: NSBezierPath? = NSBezierPath(rect: NSRect(x: 0, y: 0, width: dragImageSize.width, height: dragImageSize.height),
													  radiusPercentage: 50.0)
		background?.fill()

		brickImage?.draw(at: NSPoint(x: border, y: border), from: .zero, operation: .sourceOver, fraction: 1.0)

		dragImage.unlockFocus()

		if let dragImageOffset {
			// Now provide an offset to move the image over so it looks like a badge
			// next to the cursor:
			//   ...Turns out the arrow cursor image is a 24 x 24 picture, and the
			//   arrow itself occupies only a small part of the lefthand side of
			//   that space. We have to resort to a hardcoded assumption that the
			//   actual arrow picture fills only half the full image.
			//   ...We subtract from y; that is the natural direction for a lowering
			//   offset. In a flipped view, negate that value.
			dragImageOffset.pointee.x += arrowSize.width / 2
			dragImageOffset.pointee.y -= (arrowSize.height / 2 + dragImage.size.height / 2)
		}

		return dragImage
	}

	//---------- gridSpacingForMode: ---------------------------------[static]--
	//
	// Purpose:		Translates the given grid spacing granularity into an actual
	//				number of LDraw units, according to the user's preferences.
	//
	// Notes:		This value represents distances "along the studs"--that is,
	//			    horizontal along the brick. Vertical distances may be adjusted.
	//
	//--------------------------------------------------------------------------
	@objc(gridSpacingForMode:)
	class func gridSpacing(forMode gridMode: gridSpacingModeT) -> Float {
		let userDefaults = UserDefaults.standard
		var gridSpacing: Float = 0.0

		switch gridMode {
		case .modeFine:
			gridSpacing = userDefaults.float(forKey: GRID_SPACING_FINE)

		case .modeMedium:
			gridSpacing = userDefaults.float(forKey: GRID_SPACING_MEDIUM)

		case .modeCoarse:
			gridSpacing = userDefaults.float(forKey: GRID_SPACING_COARSE)

		@unknown default:
			break	// the original's switch had no default: 0
		}

		return gridSpacing
	}
}
