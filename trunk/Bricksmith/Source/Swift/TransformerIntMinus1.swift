//
//  TransformerIntMinus1.swift
//  Bricksmith
//
//  Ported from TransformerIntMinus1.m. Transforms an integer value to that
//  value minus 1, for Cocoa bindings (registered by name in LDrawApplication).
//

import Foundation

@objc(TransformerIntMinus1)
class TransformerIntMinus1: ValueTransformer {

	override class func allowsReverseTransformation() -> Bool {
		return false
	}

	override class func transformedValueClass() -> AnyClass {
		return NSNumber.self
	}

	/// Mirrors `[value integerValue]` in the original: NSNumber and NSString
	/// both respond; anything else (including nil) counted as 0.
	override func transformedValue(_ value: Any?) -> Any? {
		let intValue: Int
		switch value {
		case let number as NSNumber: intValue = number.intValue
		case let string as NSString: intValue = string.integerValue
		default:                     intValue = 0
		}
		return NSNumber(value: intValue - 1)
	}
}
