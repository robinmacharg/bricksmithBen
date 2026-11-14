//
//  SwiftSupport.swift
//  Bricksmith
//
//  Placeholder that gives the app target a Swift module, so the bridging header
//  is compiled and test bundles can `@testable import Bricksmith`.
//  Remove once real Swift sources exist.
//

import Foundation

enum SwiftSupport {
	/// Marker used by the test harness to check that the Swift module is present.
	static let isPresent = true
}
