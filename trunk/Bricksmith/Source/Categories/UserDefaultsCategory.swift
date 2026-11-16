//==============================================================================
//
// Category: UserDefaultsCategory.swift
//
//		Allows storing certain objects that otherwise cannot be stored directly.
//
//  Created by Allen Smith on 3/12/05.
//  Copyright 2005. All rights reserved.
//  Ported to Swift in P5; the ObjC selectors are unchanged. Colours are still
//  stored as non-keyed NSArchiver (typedstream) data, byte for byte: existing
//  preferences and the P2 row 7 tests depend on that format.
//==============================================================================
import AppKit


extension UserDefaults {

	//========== setColor:forKey: ==============================================
	//
	// Purpose:		Saves a color into UserDefaults.
	//
	//==========================================================================
	@objc(setColor:forKey:)
	func setColor(_ aColor: NSColor!, forKey aKey: String!) {
		let theData: Data
		if let aColor {
			theData = NSArchiver.archivedData(withRootObject: aColor)
		} else {
			// ObjC archived nil (a 20-byte archive). Swift can't pass nil to
			// archivedData(withRootObject: Any), and Optional-as-Any would archive NSNull.
			theData = Self.archivedDataOfNil()
		}

		// [self setObject:theData forKey:nil] was a silent no-op.
		guard let aKey else { return }
		self.set(theData, forKey: aKey)

	}//end setColor:forKey:


	//========== colorForKey: ==================================================
	//
	// Purpose:		Retrieves a color stored in UserDefaults.
	//
	// Notes:		nil if absent or not a non-keyed NSArchiver blob (BUG-002).
	//				Whatever object the archive holds is returned unchecked, as
	//				the ObjC cast did. A truncated archive still raises
	//				NSArchiverArchiveInconsistency (BUG-035).
	//
	//==========================================================================
	@objc(colorForKey:)
	func color(forKey aKey: String!) -> NSColor? {
		var theColor: NSColor? = nil
		// [self dataForKey:nil] returned nil.
		guard let aKey else { return nil }
		let theData = self.data(forKey: aKey)

		if let theData {
			if let object = NSUnarchiver.unarchiveObject(with: theData) {
				// Unchecked, like (NSColor *) in ObjC: a checked cast would turn a
				// non-colour object into nil.
				theColor = unsafeBitCast(object as AnyObject, to: NSColor.self)
			}
		}

		return theColor

	}//end colorForKey:


	//---------- archivedDataOfNil ---------------------------------[private]--
	//
	// Purpose:		[NSArchiver archivedDataWithRootObject:nil], called through
	//				the runtime because the Swift overlay takes a non-optional Any.
	//
	//--------------------------------------------------------------------------
	private static func archivedDataOfNil() -> Data {
		let archiverClass: AnyObject = NSArchiver.self
		let result = archiverClass.perform(#selector(NSArchiver.archivedData(withRootObject:)), with: nil)
		return result!.takeUnretainedValue() as! Data
	}

}
