//==============================================================================
//
// File:		TransformerIntMinus1.swift
//
// Purpose:		A value transformer that subtracts one from the integer value of
//				the input.
//
// Notes:		Nibs name it in bindings (MinifigureGenerator.xib), so it is
//				registered under "TransformerIntMinus1" by
//				+[LDrawApplication registerValueTransformers] before any nib
//				loads. Ported from TransformerIntMinus1.m (P5).
//
//  Created by Allen Smith on 7/18/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
import Foundation

@objc(TransformerIntMinus1)
final class TransformerIntMinus1: ValueTransformer {

	//---------- allowsReverseTransformation -------------------------[static]--
	//
	// Purpose:		Returns whether this class knows how to un-transform its value.
	//
	//--------------------------------------------------------------------------
	override class func allowsReverseTransformation() -> Bool {
		return false
	}

	//---------- transformedValueClass -------------------------------[static]--
	//
	// Purpose:		Returns the kind of objects we output.
	//
	//--------------------------------------------------------------------------
	override class func transformedValueClass() -> AnyClass {
		return NSNumber.self
	}

	//========== transformedValue: =============================================
	//
	// Purpose:		Transforms the original value, and returns the result.
	//
	// Notes:		[value integerValue] in the original: any object answering
	//				-integerValue (NSNumber, NSString...) is asked for it, and nil
	//				gives 0. An object that doesn't answer it also gives 0 here,
	//				where ObjC raised (unreachable: the xib passes @count).
	//
	//==========================================================================
	override func transformedValue(_ value: Any?) -> Any? {
		let intValue: Int = (value as AnyObject?)?.integerValue ?? 0

		return NSNumber(value: intValue &- 1)
	}
}
