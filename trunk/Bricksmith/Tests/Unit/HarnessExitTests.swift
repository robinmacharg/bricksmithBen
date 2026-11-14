//
//  HarnessExitTests.swift
//  BricksmithTests
//
//  Proves Swift Testing exit tests work from the app-hosted bundle (P1 spike,
//  passed 2026-11-14). Crashing known bugs (e.g. BUG-001) are recorded with
//  `#expect(processExitsWith:)` - no guard in app code needed.
//

import Foundation
import Testing
@testable import Bricksmith

@Suite("Harness: exit tests")
struct HarnessExitTests {

	@Test("A crash in a child process is observed, not fatal to the run")
	func crashIsObserved() async {
		await #expect(processExitsWith: .failure) {
			abort()
		}
	}

	@Test("ObjC code from the app is reachable inside the child process")
	func appCodeInChild() async {
		await #expect(processExitsWith: .success) {
			let output = TransformerIntMinus1().transformedValue(NSNumber(value: 1)) as? NSNumber
			exit(output?.intValue == 0 ? EXIT_SUCCESS : EXIT_FAILURE)
		}
	}
}
