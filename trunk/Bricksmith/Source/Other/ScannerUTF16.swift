//
//  ScannerUTF16.swift
//  Bricksmith
//
//  NSScanner's original methods, for Swift ports that must scan exactly as the ObjC did.
//
//  Swift's non-deprecated Scanner API (scanString(_:), scanInt32(), scanCharacters(from:), currentIndex, …)
//  works in grapheme clusters; NSScanner's ObjC methods work in UTF-16 units. On non-ASCII input (a combining
//  mark or zero-width joiner next to a token) the two give different results (LEARNINGS L101). The Swift
//  spellings that reach the ObjC methods (scanString(_:into:), scanInt32(_:), scanLocation, …) are deprecated
//  and would fail the warning gate.
//
//  This protocol re-declares the ObjC selectors under new Swift names; `scanner.utf16` reinterprets the
//  NSScanner as the protocol (a class-bound @objc existential is the object pointer), so each call is a plain
//  objc_msgSend of the original selector. Use it in every port of ObjC code that scanned with NSScanner.
//

import Foundation

@objc protocol UTF16Scanning {
	@objc(scanString:intoString:)
	func scanString(_ string: String, into result: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool
	@objc(scanUpToString:intoString:)
	func scanUpTo(_ string: String, into result: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool
	@objc(scanCharactersFromSet:intoString:)
	func scanCharacters(from set: CharacterSet, into result: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool
	@objc(scanUpToCharactersFromSet:intoString:)
	func scanUpToCharacters(from set: CharacterSet, into result: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool
	@objc(scanInt:)
	func scanInt(_ result: UnsafeMutablePointer<Int32>?) -> Bool
	@objc(scanInteger:)
	func scanInteger(_ result: UnsafeMutablePointer<Int>?) -> Bool
	@objc(scanHexInt:)
	func scanHexInt(_ result: UnsafeMutablePointer<UInt32>?) -> Bool
	@objc(scanFloat:)
	func scanFloat(_ result: UnsafeMutablePointer<Float>?) -> Bool
	@objc(scanDouble:)
	func scanDouble(_ result: UnsafeMutablePointer<Double>?) -> Bool
	/// NSScanner's scanLocation, in UTF-16 units.
	@objc(scanLocation)
	func location() -> Int
	@objc(setScanLocation:)
	func setLocation(_ location: Int)
}

extension Scanner {
	/// This scanner, seen through NSScanner's original UTF-16 methods.
	var utf16: UTF16Scanning { unsafeBitCast(self, to: UTF16Scanning.self) }
}
