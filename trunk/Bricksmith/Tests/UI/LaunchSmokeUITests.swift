//
//  LaunchSmokeUITests.swift
//  BricksmithUITests
//
//  UI tests launch Bricksmith as a separate process, so they opt into test mode
//  explicitly (BRICKSMITH_TEST_MODE=1) and hand it a temporary copy of the
//  ldraw-mini fixture library. Kept deliberately thin (plan §5 P2 row 17).
//

import XCTest

final class LaunchSmokeUITests: XCTestCase {

	private var libraryCopy: URL!

	override func setUpWithError() throws {
		continueAfterFailure = false
		let trunk = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent().deletingLastPathComponent()
			.deletingLastPathComponent().deletingLastPathComponent()
		let root = FileManager.default.temporaryDirectory
			.appendingPathComponent("BricksmithUITests-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		libraryCopy = root.appendingPathComponent("ldraw")
		try FileManager.default.copyItem(at: trunk.appendingPathComponent("Fixtures/ldraw-mini"), to: libraryCopy)
	}

	override func tearDownWithError() throws {
		try? FileManager.default.removeItem(at: libraryCopy.deletingLastPathComponent())
	}

	private func launchIsolated() -> XCUIApplication {
		let app = XCUIApplication()
		app.launchEnvironment["BRICKSMITH_TEST_MODE"] = "1"
		app.launchEnvironment["BRICKSMITH_TEST_LDRAW_PATH"] = libraryCopy.path
		app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
		app.launch()
		return app
	}

	func testLaunchShowsMenuBar() {
		let app = launchIsolated()
		XCTAssertTrue(app.menuBars.menuBarItems["File"].waitForExistence(timeout: 10))
		app.terminate()
	}
}
