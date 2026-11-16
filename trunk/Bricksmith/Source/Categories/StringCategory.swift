//
//  StringCategory.swift
//  Bricksmith
//
//  Ported from StringCategory.m (Allen Smith, 2/19/05; P5). Handy string utilities.
//
//  The ObjC selectors are kept with @objc(...): xibs sort with numericCompare:, and ObjC callers
//  still use the rest. Signatures match the old header's generated Swift interface (plan §4.4.11).
//

import Foundation

extension NSString {

	//========== ams_containsString:options: ===================================
	//
	// Purpose:		For quick searches.
	//
	//				Every string is reported as containing the empty string (@"").
	//				This is consistent with set theory and other common programming
	//				APIs, but not Cocoa, which specifically disavows the empty
	//				string in -[NSString rangeOfString:]. Bricksmith relies on the
	//				empty string being a substring.
	//
	// Note:		The absurd name prevents collisions with methods which may not
	//				recognize the empty string as a substring (in 10.8.0 a bundle
	//				loaded by contextual menus added -containsString:options:).
	//
	//				A nil substring raised in ObjC (-rangeOfString: nil argument);
	//				here it traps. No caller passes nil.
	//
	//==========================================================================
	@objc(ams_containsString:options:)
	func ams_contains(_ substring: String!, options mask: UInt) -> Bool {
		let foundRange = self.range(of: substring, options: NSString.CompareOptions(rawValue: mask))

		if foundRange.location == NSNotFound && (substring as NSString).length > 0 {
			return false
		}
		else {
			return true
		}
	}


	//---------- CRLF ------------------------------------------------[static]--
	//
	// Purpose:		Returns a DOS line-end marker, which is a hideous two
	//				characters in length.
	//
	//--------------------------------------------------------------------------
	@objc(CRLF)
	class func crlf() -> String! {
		let CRLFchars: [unichar] = [0x000D, 0x000A] // DOS linefeed.
		return NSString(characters: CRLFchars, length: 2) as String
	}


	//========== numericCompare: ===============================================
	//
	// Purpose:		Provides one-stop (Interface Builder-compatible!) method for
	//				doing a numeric sort.
	//
	// Note:		NSSortDescriptor can pass a nil argument. The ObjC
	//				-compare:options: returned NSOrderedDescending for nil
	//				(recorded in StringCategoryTests); that is mirrored here.
	//
	//==========================================================================
	@objc(numericCompare:)
	func numericCompare(_ string: String!) -> ComparisonResult {
		guard let string else { return .orderedDescending }
		return self.compare(string, options: .numeric)
	}


	//========== separateByLine ================================================
	//
	// Purpose:		Returns an array of all the lines in the string, with line
	//				terminators removed.
	//
	//==========================================================================
	@objc(separateByLine)
	func separateByLine() -> [NSObject]! {
		let lines               = NSMutableArray()
		let stringLength        = self.length

		var lineStartIndex      = 0
		var nextlineStartIndex  = 0
		var newlineIndex        = 0 // index of the first newline character in the line.

		while nextlineStartIndex < stringLength {
			// Read the first line. LDraw files are in DOS format. Oh the agony.
			// But Cocoa is nice to us.
			self.getLineStart(&lineStartIndex,
							  end: &nextlineStartIndex,
							  contentsEnd: &newlineIndex,
							  for: NSRange(location: nextlineStartIndex, length: 1)) // that is, contains the first character.

			let lineLength = newlineIndex - lineStartIndex
			let isolatedLine = self.substring(with: NSRange(location: lineStartIndex, length: lineLength))
			lines.add(isolatedLine)
		}

		// [NSObject], not [Any]: a class element type bridges to and from ObjC
		// without copying, so the parse can pass these lines across freely.
		return lines as? [NSObject]
	}


	//========== ams_stringByRemovingWhitespace ================================
	//
	// Purpose:		Returns a new string equal to the receiver, except that it
	//				contains no whitespace characters.
	//
	// Note:		Ben Supnik reports name conflicts on
	//				"stringByRemovingWhitespace" too.
	//
	//==========================================================================
	@objc(ams_stringByRemovingWhitespace)
	func ams_stringByRemovingWhitespace() -> String! {
		let originalLength  = self.length
		var resultBuffer    = [unichar](repeating: 0, count: originalLength)
		let whitespaceSet   = CharacterSet.whitespaces as NSCharacterSet
		var resultLength    = 0

		// Copy only non-whitespace characters into the new string.
		//	* We'll assume the Unicode Consortium will never be sick enough to put
		//	  whitespace outside the BMP, or that our users will never employ such a
		//	  beast if they did. (Works on UTF-16 units, so surrogates pass through.)
		for counter in 0..<originalLength {
			let currentCharacter = self.character(at: counter)
			if whitespaceSet.characterIsMember(currentCharacter) == false {
				resultBuffer[resultLength] = currentCharacter
				resultLength += 1
			}
		}
		return NSString(characters: resultBuffer, length: resultLength) as String
	}
}
