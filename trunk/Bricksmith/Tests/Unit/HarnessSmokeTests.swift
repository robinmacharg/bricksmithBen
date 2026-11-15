//
//  HarnessSmokeTests.swift
//  BricksmithTests
//
//  Proves the hosted test harness works end to end: the test bundle loads into
//  the app, sees the app's Swift module, and sees Objective-C classes through the
//  app's bridging header.
//

import Foundation
import Testing
@testable import Bricksmith

@Suite("Harness smoke")
struct HarnessSmokeTests {

	@Test("Swift module of the app is visible")
	func swiftModuleVisible() {
		#expect(SwiftSupport.isPresent)
	}

	@Test("ObjC class from the bridging header is usable", arguments: [5, 1, 0, -3])
	func transformerSubtractsOne(input: Int) {
		let transformer = TransformerIntMinus1()
		let output = transformer.transformedValue(NSNumber(value: input)) as? NSNumber
		#expect(output?.intValue == input - 1)
	}
}
