//
//  FixtureLibrary.swift
//  BricksmithTests
//
//  Test isolation for anything that touches the LDraw library or Bricksmith's
//  process-wide state. Apply `.fixtureLibrary` (and `.serialized`) to a suite:
//
//      @Suite(.fixtureLibrary, .serialized) struct MyTests { ... }
//
//  Tests using the trait run ONE AT A TIME across the whole process (a global async lock):
//  `.serialized` alone only orders tests within a suite, and different suites run concurrently,
//  resetting each other's singletons (LEARNINGS L37).
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

/// Process-wide FIFO lock for tests that touch Bricksmith's global state.
actor GlobalStateLock {
	static let shared = GlobalStateLock()
	private var busy = false
	private var waiters: [CheckedContinuation<Void, Never>] = []

	func acquire() async {
		if !busy { busy = true; return }
		await withCheckedContinuation { waiters.append($0) }
	}

	func release() {
		if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
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

		await GlobalStateLock.shared.acquire()
		do {
			try await withIsolatedLibrary(function)
		} catch {
			await GlobalStateLock.shared.release()
			throw error
		}
		await GlobalStateLock.shared.release()
	}

	private func withIsolatedLibrary(_ function: @Sendable () async throws -> Void) async throws {
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
