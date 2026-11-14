//
//  FixtureLibrary.swift
//  BricksmithTests
//
//  Test isolation for anything that touches the LDraw library or Bricksmith's
//  process-wide state. Apply `.fixtureLibrary` (and `.serialized`) to a suite:
//
//      @Suite(.fixtureLibrary, .serialized) struct MyTests { ... }
//
//  For each test case it:
//    1. copies trunk/Fixtures/ldraw-mini to a fresh temporary directory
//       (the part catalog builder writes into the library folder);
//    2. resets every singleton that caches library data;
//    3. points LDrawPaths at the copy (never the user's real library);
//    4. pins process-wide output settings (column alignment off, author
//       "anonymous"), which the real app sets from preferences at launch;
//    5. undoes all of it afterwards.
//

import Foundation
import Testing
@testable import Bricksmith

enum FixturePaths {
	/// trunk/ — derived from this source file's location so it works from Xcode and scripts alike.
	static let trunk: URL = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()   // Support
		.deletingLastPathComponent()   // Tests
		.deletingLastPathComponent()   // Bricksmith
		.deletingLastPathComponent()   // trunk

	static let ldrawMini = trunk.appendingPathComponent("Fixtures/ldraw-mini")
	static let fixtures = trunk.appendingPathComponent("Fixtures")
	static let testData = trunk.appendingPathComponent("Test Data")
}

/// The temporary library for the currently running test case.
enum FixtureLibrary {
	@TaskLocal static var current: URL?

	static func resetGlobalState() {
		ColorLibrary.resetForTesting()
		PartLibrary.resetForTesting()
		ModelManager.resetForTesting()
		MLCadIni.resetForTesting()
		LDrawPaths.resetForTesting()
		LDrawUtilities.resetForTesting()
	}
}

struct FixtureLibraryTrait: SuiteTrait, TestTrait, TestScoping {
	var isRecursive: Bool { true }

	func provideScope(for test: Test, testCase: Test.Case?,
					  performing function: @Sendable () async throws -> Void) async throws {
		// Set up once per test case; pass straight through at suite level.
		guard testCase != nil else {
			try await function()
			return
		}

		let fileManager = FileManager.default
		let root = fileManager.temporaryDirectory
			.appendingPathComponent("BricksmithTests-\(UUID().uuidString)", isDirectory: true)
		let library = root.appendingPathComponent("ldraw", isDirectory: true)
		try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
		try fileManager.copyItem(at: FixturePaths.ldrawMini, to: library)
		defer {
			FixtureLibrary.resetGlobalState()
			try? fileManager.removeItem(at: root)
		}

		FixtureLibrary.resetGlobalState()
		LDrawPaths.shared().setPreferredLDrawPath(library.path)

		try await FixtureLibrary.$current.withValue(library) {
			try await function()
		}
	}
}

extension Trait where Self == FixtureLibraryTrait {
	/// Isolated copy of the ldraw-mini fixture library plus reset global state. Combine with `.serialized`.
	static var fixtureLibrary: Self { Self() }
}
