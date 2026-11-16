//
//  SmokeUITests.swift
//  BricksmithUITests
//
//  P2 row 17: thin UI smoke tests driving the real app. Each test opens a TEMP COPY of a fixture (never the
//  fixture itself - L34), with test mode on and the fixture LDraw library, and checks the main flows:
//  open, outline selection, inspector, edit + undo + save (bytes compared with the approved round-trip golden),
//  Save As, and that the main panels open.
//

import XCTest

final class SmokeUITests: XCTestCase {

	private var workDir: URL!
	private var app: XCUIApplication!
	private let trunk = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
		.deletingLastPathComponent().deletingLastPathComponent()

	override func setUpWithError() throws {
		continueAfterFailure = false
		workDir = FileManager.default.temporaryDirectory.appendingPathComponent("BricksmithUITests-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
		try FileManager.default.copyItem(at: trunk.appendingPathComponent("Fixtures/ldraw-mini"), to: workDir.appendingPathComponent("ldraw"))
	}

	override func tearDownWithError() throws {
		app?.terminate()
		try? FileManager.default.removeItem(at: workDir)
	}

	/// Launch isolated, opening a temp copy of `fixture`; returns the copy's URL.
	@discardableResult
	private func launch(opening fixture: String? = nil) throws -> URL? {
		app = XCUIApplication()
		app.launchEnvironment["BRICKSMITH_TEST_MODE"] = "1"
		app.launchEnvironment["BRICKSMITH_TEST_LDRAW_PATH"] = workDir.appendingPathComponent("ldraw").path
		app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
		// Also put the library in the volatile argument domain: Preferences runs a modal "Choose LDraw Folder"
		// panel when the "LDraw Path" default is unset (PreferencesDialogController setLDrawTabValues). Never persisted.
		app.launchArguments += ["-LDraw Path", workDir.appendingPathComponent("ldraw").path]
		var copy: URL?
		if let fixture {
			let url = workDir.appendingPathComponent(fixture)
			try FileManager.default.copyItem(at: trunk.appendingPathComponent("Fixtures/ldr/\(fixture)"), to: url)
			app.launchArguments.append(url.path)
			copy = url
		}
		app.launch()
		return copy
	}

	/// Click a menu-bar menu, then an item whose title starts with `item` (titles such as "Undo Duplicate" change
	/// with state; the items have only auto-generated `_NS:` identifiers).
	private func menu(_ top: String, _ item: String, or alternative: String? = nil) {
		app.menuBars.menuBarItems[top].click()
		let match = NSPredicate(format: "title BEGINSWITH %@ OR title BEGINSWITH %@", item, alternative ?? item)
		let entry = app.menuBars.menuBarItems[top].menuItems.matching(match).firstMatch
		XCTAssertTrue(entry.waitForExistence(timeout: 5), "menu item \(top) > \(item) missing")
		entry.click()
	}

	/// The document window's outline, fully expanded (option-click the model's disclosure triangle).
	private func expandedOutline() -> XCUIElement {
		let window = app.windows.containing(.outline, identifier: nil).firstMatch
		XCTAssertTrue(window.waitForExistence(timeout: 15), "document window did not open")
		let outline = window.outlines.firstMatch
		XCTAssertTrue(outline.waitForExistence(timeout: 5))
		// The first click can land before the outline has finished loading: wait for the triangle, and retry once.
		let triangle = outline.disclosureTriangles.firstMatch
		XCTAssertTrue(triangle.waitForExistence(timeout: 5))
		for _ in 0..<2 where outline.outlineRows.count <= 2 {
			XCUIElement.perform(withKeyModifiers: .option) { triangle.click() }
			_ = outline.outlineRows.element(boundBy: 2).waitForExistence(timeout: 3)
		}
		XCTAssertGreaterThan(outline.outlineRows.count, 2, "outline did not expand")
		return outline
	}

	private func windowTitles() -> [String] {
		(app.windows.allElementsBoundByIndex + app.dialogs.allElementsBoundByIndex).map(\.title)
	}

	/// Click an outline row. AppKit reports outline rows as not hittable, so click by coordinate.
	private func click(row index: Int, in outline: XCUIElement) {
		outline.outlineRows.element(boundBy: index).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
	}

	func testOpenSelectAndInspect() throws {
		try launch(opening: "02-line-types.ldr")
		let outline = expandedOutline()
		click(row: outline.outlineRows.count - 1, in: outline)
		menu("Tools", "Show Inspector")
		// The title follows the selection ("Model Inspector", ...).
		let inspector = app.windows.matching(NSPredicate(format: "title CONTAINS 'Inspector'")).firstMatch
		XCTAssertTrue(inspector.waitForExistence(timeout: 5), "Inspector did not appear; windows: \(windowTitles())")
		XCTAssertGreaterThan(inspector.textFields.count, 0, "Inspector shows no fields for the selection")
	}

	func testEditUndoSave() throws {
		let file = try XCTUnwrap(try launch(opening: "02-line-types.ldr"))
		let outline = expandedOutline()
		click(row: outline.outlineRows.count - 1, in: outline)
		let rows = outline.outlineRows.count

		menu("Edit", "Duplicate")
		XCTAssertEqual(outline.outlineRows.count, rows + 1, "Duplicate added no row")
		menu("File", "Save")
		let edited = try Data(contentsOf: file)

		menu("Edit", "Undo")
		XCTAssertEqual(outline.outlineRows.count, rows, "Undo did not remove the duplicate")
		menu("File", "Save")
		let undone = try Data(contentsOf: file)

		let golden = try Data(contentsOf: trunk.appendingPathComponent("Fixtures/golden/roundtrip/02-line-types.ldr"))
		XCTAssertNotEqual(edited, undone, "the saved duplicate did not change the file")
		XCTAssertEqual(undone, golden, "after undo + save the file must equal the approved round-trip golden")
	}

	func testPanelsOpen() throws {
		try launch(opening: "04-steps-rotstep.ldr")
		XCTAssertTrue(app.windows.containing(.outline, identifier: nil).firstMatch.waitForExistence(timeout: 15))

		// The parts browser is a floating panel (an accessibility Dialog); test mode does not open it at launch.
		XCTAssertFalse(app.dialogs["Parts Browser"].exists)
		menu("Tools", "Parts Browser")
		XCTAssertTrue(app.dialogs["Parts Browser"].waitForExistence(timeout: 5), "Parts Browser")
		XCTAssertTrue(app.dialogs["Parts Browser"].searchFields.firstMatch.exists)

		menu("Piece", "Show Colors")
		XCTAssertTrue(app.windows["LDraw Colors"].waitForExistence(timeout: 5), "Colors panel")

		menu("Bricksmith", "Settings", or: "Preferences")  // macOS 13+ retitles "Preferences…"
		// Panels (NSPanel) surface as Dialogs, plain windows as Windows: accept either.
		let prefs = app.descendants(matching: .any).matching(NSPredicate(format:
			"(elementType == %d OR elementType == %d) AND (title CONTAINS 'Preferences' OR title CONTAINS 'Settings')",
			XCUIElement.ElementType.window.rawValue, XCUIElement.ElementType.dialog.rawValue)).firstMatch
		XCTAssertTrue(prefs.waitForExistence(timeout: 5), "windows: \(windowTitles()). Preferences (BUG-002 bites only with keyed colour prefs; the test domain has none)")
	}

	func testSaveAsAndReopen() throws {
		try launch(opening: "05-multipart.mpd")
		XCTAssertTrue(app.windows.containing(.outline, identifier: nil).firstMatch.waitForExistence(timeout: 15))
		// Typed as .ldr: typing "saved-as.mpd" here saves "saved-as.ldr" (KNOWN-BUGS S26, suspected).
		let target = workDir.appendingPathComponent("saved-as.ldr")

		menu("File", "Save As")
		let sheet = app.sheets.firstMatch
		XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Save As sheet")
		// Go to the folder and type the name: Cmd-Shift-G accepts a full path.
		sheet.typeKey("g", modifierFlags: [.command, .shift])
		app.typeText(target.path + "\r")
		XCTAssertTrue(sheet.buttons["Save"].waitForExistence(timeout: 5))
		sheet.buttons["Save"].click()
		let retitled = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'saved-as'")).firstMatch
		XCTAssertTrue(retitled.waitForExistence(timeout: 10), "window not retitled after Save As; windows: \(windowTitles()); "
					  + "files: \((try? FileManager.default.contentsOfDirectory(atPath: workDir.path)) ?? [])")

		let golden = try Data(contentsOf: trunk.appendingPathComponent("Fixtures/golden/roundtrip/05-multipart.ldr"))
		let files = (try? FileManager.default.contentsOfDirectory(atPath: workDir.path)) ?? []
		XCTAssertTrue(FileManager.default.fileExists(atPath: target.path), "Save As wrote elsewhere; windows: \(windowTitles()); files: \(files)")
		XCTAssertEqual(try Data(contentsOf: target), golden, "Save As output must equal the approved round-trip golden")

		// Reopen the saved file in a fresh launch: it must load with the same outline.
		let rows = expandedOutline().outlineRows.count
		app.terminate()
		app.launchArguments.removeLast()   // the original fixture copy
		app.launchArguments.append(target.path)
		app.launch()
		XCTAssertEqual(expandedOutline().outlineRows.count, rows, "reopened file shows a different outline")
	}
}
