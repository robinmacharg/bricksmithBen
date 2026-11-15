//
//  ObjC.swift
//  BricksmithTests
//
//  Swift cannot catch Objective-C exceptions, and one thrown on a Swift Testing thread is swallowed by
//  AppKit, leaving the test hung (LEARNINGS L57). Run ObjC calls that might throw through ObjC.run so an
//  exception becomes an ordinary, reported test failure.
//

import Foundation
@testable import Bricksmith

struct ObjCException: Error, CustomStringConvertible {
	let name: String
	let reason: String
	var description: String { "Objective-C exception \(name): \(reason)" }
}

enum ObjC {
	@discardableResult
	static func run<T>(_ body: () -> T) throws -> T {
		var result: T?
		if let exception = BricksmithTestSupport.catchException({ result = body() }) {
			throw ObjCException(name: exception.name.rawValue, reason: exception.reason ?? "")
		}
		return result!
	}
}
