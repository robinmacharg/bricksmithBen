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

	@Test("Exit-test child processes launch the app in test mode (no LDraw discovery, prompts or prefs writes)")
	func childIsInTestMode() async {
		// Swift Testing relaunches the host without XCTestConfigurationFilePath but with
		// SWT_EXIT_TEST_ID; LDrawApplication must still detect test mode (LEARNINGS L32).
		await #expect(processExitsWith: .success) {
			exit(LDrawApplication.isRunningTests() ? EXIT_SUCCESS : EXIT_FAILURE)
		}
	}

	@Test("Launch registers the value transformers that nibs name, before anything looks them up")
	func valueTransformersRegisteredAtLaunch() async {
		// main() calls +[LDrawApplication registerValueTransformers] before NSApplicationMain (it was +initialize,
		// which Swift can't define). Checked in a fresh child process before any lookup: a lookup by name would
		// itself instantiate and register a class of that name (NSValueTransformer's fallback), so a lookup alone
		// can't tell whether launch registered it.
		await #expect(processExitsWith: .success) {
			let name = NSValueTransformerName("TransformerIntMinus1")
			let registered = ValueTransformer.valueTransformerNames().contains(name)
			exit(registered && ValueTransformer(forName: name) is TransformerIntMinus1 ? EXIT_SUCCESS : EXIT_FAILURE)
		}
	}
}
