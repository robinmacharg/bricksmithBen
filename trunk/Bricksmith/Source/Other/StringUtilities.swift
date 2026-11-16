//
//  StringUtilities.swift
//  Bricksmith
//
//  Ported from StringUtilities.m (Allen Smith, 12/21/2008; P5). General string utility methods.
//
//  Signatures match the old header's generated Swift interface (null_unspecified, so String!).
//

import Foundation

@objc(StringUtilities)
class StringUtilities: NSObject {

	//---------- nextCopyNameForString: ----------------------------------[static]--
	//
	// Purpose:		Returns the next name (in sequence) for a copy of the given
	//				name.
	//
	// Notes:		This method does not attempt to check for the existence of the
	//				copy name it returns; that is the caller's responsibility.
	//
	//				nil in gives nil out, as the ObjC did (messages to nil).
	//
	//				The ObjC used -[NSScanner setScanLocation:] and -scanInteger:,
	//				which Swift sees as deprecated; currentIndex and scanInt() are
	//				their replacements. A differential fuzz (300,000 strings: signs,
	//				overflow, whitespace, non-ASCII digits) found no difference, and
	//				StringUtilitiesTests records the edge cases.
	//
	// Examples:	Base Name				New Name
	//				----------				----------
	//				foo						foo copy
	//				foo copy				foo copy 2
	//				foo copy 3				foo copy 4
	//				foo.txt					foo.txt copy		// ignores extensions!
	//				foo copy.txt			foo copy.txt copy
	//
	//------------------------------------------------------------------------------
	@objc(nextCopyNameForString:)
	class func nextCopyName(for originalString: String!) -> String! {
		guard let originalString else { return nil }

		let original            = originalString as NSString
		let copyToken           = NSLocalizedString("CopySuffix", comment: "")
		let rangeOfCopyToken    = original.range(of: copyToken, options: .backwards)
		var currentCopyNumber   = 0
		var newCopyString: String

		// This string doesn't have the word "copy" in it yet.
		if rangeOfCopyToken.location == NSNotFound {
			currentCopyNumber = 0
		}
		// This is already a copy itself; now we need to figure out which copy is
		// next!
		else {
			let copyNumberScanner = Scanner(string: originalString)
			copyNumberScanner.currentIndex = String.Index(utf16Offset: NSMaxRange(rangeOfCopyToken), in: originalString)

			// Is there a number at the end?
			let scannedNumber   = copyNumberScanner.scanInt()
			let foundCopyNumber = (scannedNumber != nil)
			currentCopyNumber   = scannedNumber ?? 0

			if copyNumberScanner.isAtEnd == false {
				// The word "copy" in the name was apparently followed by something
				// other than an integer or the empty string. Thus, it is not a
				// valid copy token. So just append the word copy to the end and be
				// done with it.
				currentCopyNumber = 0
			}
			else if copyNumberScanner.isAtEnd == true && foundCopyNumber == false {
				// The word copy is there, but not followed by a number. So this is
				// the first copy.
				currentCopyNumber = 1
			}

			// Pathological case: It's a negative number!
			if currentCopyNumber < 0 {
				currentCopyNumber = 0
			}
		}

		// Build the copy string.
		switch currentCopyNumber {
		case 0:
			// Just append the word "copy" for the first copy
			newCopyString = original.appendingFormat(" %@", copyToken) as String

		default:
			// Strip the old copy number
			let baseName = original.substring(to: NSMaxRange(rangeOfCopyToken)) as NSString

			// Increment the copy number (NSIntegerMax wraps, as in ObjC).
			newCopyString = baseName.appendingFormat(" %ld", currentCopyNumber &+ 1) as String
		}

		return newCopyString
	}


	//---------- nextCopyPathForFilePath: --------------------------------[static]--
	//
	// Purpose:		Returns the next path or file name (in sequence) for a copy of
	//				the given name. Correctly handles file extensions.
	//
	// Notes:		This method does not attempt to check for the existence of the
	//				copy name it returns; that is the caller's responsibility.
	//
	// Examples:	Base Name				New Name
	//				----------				----------
	//				foo						foo copy
	//				foo copy				foo copy 2
	//				foo copy 3				foo copy 4
	//				foo.txt					foo copy.txt
	//				foo copy.txt			foo copy 2.txt
	//
	//------------------------------------------------------------------------------
	@objc(nextCopyPathForFilePath:)
	class func nextCopyPath(forFilePath basePath: String!) -> String! {
		guard let basePath else { return nil }

		let path                    = basePath as NSString
		let fileName                = path.lastPathComponent as NSString
		let enclosingPath           = path.deletingLastPathComponent as NSString
		let extensionString         = path.pathExtension
		let fileNameSansExtension   = fileName.deletingPathExtension

		// Derive the copy name and reconstitute the new path based on it.
		let copyBaseName    = StringUtilities.nextCopyName(for: fileNameSansExtension)!
		let copyPath        = enclosingPath.appendingPathComponent(copyBaseName) as NSString

		return copyPath.appendingPathExtension(extensionString)
	}
}
