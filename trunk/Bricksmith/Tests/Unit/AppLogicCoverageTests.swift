//
//  AppLogicCoverageTests.swift
//  BricksmithTests
//
//  P2 exit (coverage): PartLibrary (non-GL), PartBrowserDataSource, MinifigureDialogController, RelatedParts, LDrawPaths, ModelManager.
//  Builds on AppLogicTests (row 12); goldens: Fixtures/golden/app-coverage/*
//

import AppKit
import Foundation
import Testing
@testable import Bricksmith

/// Defaults written by the code under test land in the Debug/test-host domain (com.AllenSmith.Bricksmith.debug).
/// scripts/test.sh restores that domain after the run; this also restores it after each test, so tests that
/// write defaults don't leak into each other. Volatile argument-domain values are restored by .fixtureLibrary.
enum DefaultsSandbox {
	static let debugDomain = "com.AllenSmith.Bricksmith.debug"

	static func run<T>(_ body: () throws -> T) throws -> T {
		let defaults = UserDefaults.standard
		// Never snapshot/restore anything but the Debug domain (the real one is strictly off limits).
		let domain = try #require(Bundle.main.bundleIdentifier.flatMap { $0 == debugDomain ? $0 : nil },
								  "test host is not using the Debug defaults domain")
		let saved = defaults.persistentDomain(forName: domain)
		defer {
			if let saved { defaults.setPersistentDomain(saved, forName: domain) }
			else { defaults.removePersistentDomain(forName: domain) }
		}
		return try body()
	}

	/// Put values in the volatile argument domain (outranks the persistent domains, never written to disk).
	static func setArguments(_ values: [String: Any]) {
		let defaults = UserDefaults.standard
		var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
		arguments.merge(values) { _, new in new }
		defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
	}

	static func removeArguments(_ keys: [String]) {
		let defaults = UserDefaults.standard
		var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
		for key in keys { arguments.removeValue(forKey: key) }
		defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
	}
}

/// Records the favourites the library hands its delegate (the app's delegate is PartLibraryController).
final class FavoritesDelegateSpy: NSObject, PartLibraryDelegate {
	var calls: [[String]] = []
	func partLibrary(_ partLibrary: PartLibrary!, didChangeFavorites newFavorites: [Any]!) {
		calls.append((newFavorites ?? []).map { "\($0)" })
	}
}

// MARK: - PartLibrary

@Suite("App logic coverage: PartLibrary (P2 exit)", .fixtureLibrary, .serialized, .timeLimit(.minutes(1)))
struct PartLibraryCoverageTests {

	static func line(_ text: String, into lines: inout [String]) { lines.append(text) }

	@Test("load: no catalog file -> NO; catalog without a version -> NO (catalog untouched); a built catalog -> YES")
	func load() async throws {
		let catalogPath = try #require(LDrawPaths.shared().partCatalogPath())
		try? FileManager.default.removeItem(atPath: catalogPath)
		let library = PartLibrary.shared()
		#expect(library.load() == false, "no parts.plist yet")

		// An old-format catalog (no Version key) is rejected and leaves the current catalog alone.
		try (["Categories": [:], "Part List": [:]] as NSDictionary).write(to: URL(fileURLWithPath: catalogPath))
		library.setPartCatalog(["Part List": ["x.dat": ["Part Number": "x.dat"]]])
		#expect(library.load() == false, "a catalog without VERSION_KEY must be rejected")
		#expect((library.allPartCatalogRecords() ?? []).count == 1, "rejected catalog must not replace the current one")

		// A real catalog written by the builder loads, and its records match what the builder produced.
		let built = try #require(await LibraryCatalogTests.buildCatalog())
		PartLibrary.resetForTesting()
		let fresh = PartLibrary.shared()
		#expect((fresh.allPartCatalogRecords() ?? []).isEmpty)
		#expect(fresh.load() == true)
		let builtCount = (built["Part List"] as? [String: Any])?.count ?? -1
		#expect((fresh.allPartCatalogRecords() ?? []).count == builtCount)
		#expect(fresh.description(forPartName: "3001.dat") == "Brick  2 x  4")
	}

	@Test("categoryHierarchy: the part browser's outline (groups, children, display names)")
	func categoryHierarchy() async throws {
		let catalog = try #require(await LibraryCatalogTests.buildCatalog())
		let library = PartLibrary.shared()
		library.setPartCatalog(catalog)
		let hierarchy = try #require(library.categoryHierarchy() as? [[String: Any]])
		// Compact sorted JSON per group (L61: never Foundation -description in a golden).
		var lines: [String] = []
		for group in hierarchy {
			let data = try JSONSerialization.data(withJSONObject: group, options: [.sortedKeys])
			lines.append(String(decoding: data, as: UTF8.self))
		}
		try Golden.check(Data((lines.joined(separator: "\n") + "\n").utf8), against: "app-coverage/category-hierarchy.txt")
	}

	@MainActor
	@Test("Favorites: add/remove notify the delegate and post the change notification; records follow the catalog")
	func favorites() async throws {
		let catalog = try #require(await LibraryCatalogTests.buildCatalog())
		let library = PartLibrary.shared()
		library.setPartCatalog(catalog)
		let spy = FavoritesDelegateSpy()
		library.setDelegate(spy)
		defer { library.setDelegate(nil) }

		var notifications = 0
		let token = NotificationCenter.default.addObserver(forName: .LDrawPartLibraryDidChange,
														   object: library, queue: nil) { _ in notifications += 1 }
		defer { NotificationCenter.default.removeObserver(token) }

		// setFavorites (as PartLibraryController does at launch) neither notifies nor saves.
		library.setFavorites(["3001.dat", "not-in-catalog.dat"])
		#expect(spy.calls.isEmpty && notifications == 0)
		func records() -> [String] {
			(library.favoritePartCatalogRecords() as? [[String: Any]] ?? []).compactMap { $0["Part Number"] as? String }
		}
		#expect(records() == ["3001.dat"], "names missing from the catalog are skipped")

		library.addPartName(toFavorites: "3024.dat")
		#expect(spy.calls.last == ["3001.dat", "not-in-catalog.dat", "3024.dat"])
		#expect(notifications == 1)
		#expect(records() == ["3001.dat", "3024.dat"])
		let viaCategory = (library.partCatalogRecords(inCategory: Category_Favorites) as? [[String: Any]] ?? [])
			.compactMap { $0["Part Number"] as? String }
		#expect(viaCategory == records(), "the Favorites pseudo-category is favoritePartCatalogRecords")

		library.removePartName(fromFavorites: "3001.dat")
		#expect(spy.calls.last == ["not-in-catalog.dat", "3024.dat"])
		#expect(notifications == 2)
		#expect(records() == ["3024.dat"])
		#expect(spy.calls.count == 2)
	}

	/// A temp folder holding `tex.ldr`, whose TEXMAP names `image`; `place` puts a PNG next to it.
	static func texturedFile(image: String, size: (Int, Int), place: String?) throws -> (LDrawFile, LDrawTexture, URL) {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent("BricksmithTests-tex-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		if let place {
			let target = dir.appendingPathComponent(place)
			try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
			let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size.0, pixelsHigh: size.1,
													 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
													 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
			try #require(rep.representation(using: .png, properties: [:])).write(to: target)
		}
		let text = "0 Textured\r\n0 Name: tex.ldr\r\n0 Author: Fixture Author\r\n" +
			"0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 \(image)\r\n" +
			"3 16 -10 0 -10 10 0 -10 10 0 10\r\n0 !TEXMAP END\r\n"
		let fileURL = dir.appendingPathComponent("tex.ldr")
		try Data(text.utf8).write(to: fileURL)
		let file = try #require(RoundTrip.load(Data(text.utf8)))
		file.setPath(fileURL.path)
		let texture = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawTexture }.first)
		return (file, texture, dir)
	}

	@Test("Texture images not in the library are found next to the model: textures/<name>, then <name>; else nil")
	func neighboringTextures() throws {
		let library = PartLibrary.shared()
		var rows: [String] = []
		for (image, place, size) in [("inTextures.png", "textures/inTextures.png", (8, 4)),
									 ("besidefile.png", "besidefile.png", (4, 2)),
									 ("lowercase.png", "textures/lowercase.png", (2, 2)),
									 ("absent.png", nil, (1, 1))] as [(String, String?, (Int, Int))] {
			let (file, texture, dir) = try Self.texturedFile(image: image, size: size, place: place)
			defer { try? FileManager.default.removeItem(at: dir) }
			let image = library.image(for: texture)?.takeUnretainedValue()
			// Found images are cached under the texture's DISPLAY name, but looked up by its (lower-case)
			// REFERENCE name, so a mixed-case name misses the cache (and is re-read from disk next time).
			let cached = library.image(forTextureName: texture.imageReferenceName()) != nil
			rows.append("\(texture.imageDisplayName() ?? "nil") placed=\(place ?? "-") -> " +
						(image.map { "\($0.width)x\($0.height)" } ?? "nil") + " cachedUnderReferenceName=\(cached)")
			withExtendedLifetime(file) {}
		}
		// A file that was never saved (no path) has no neighbours.
		let (file, texture, dir) = try Self.texturedFile(image: "unsaved.png", size: (2, 2), place: "unsaved.png")
		defer { try? FileManager.default.removeItem(at: dir) }
		file.setPath(nil)
		rows.append("unsaved.png in an unsaved file -> " + (library.imageFromNeighboringFile(for: texture) == nil ? "nil" : "image"))
		try Golden.check(Data((rows.joined(separator: "\n") + "\n").utf8), against: "app-coverage/neighboring-textures.txt")
	}

	@MainActor
	@Test("textureTagForTexture uploads a found image once (GL name cached per image); a missing image gives 0")
	func textureTags() throws {
		try OffscreenGL.makeCurrent()
		let library = PartLibrary.shared()
		let (file, texture, dir) = try Self.texturedFile(image: "tagged.png", size: (16, 8), place: "textures/tagged.png")
		defer { try? FileManager.default.removeItem(at: dir) }
		let tag = library.textureTag(for: texture)
		#expect(tag != 0, "a found image must get a GL texture name")
		#expect(glIsTexture(tag) == GLboolean(GL_TRUE))
		#expect(library.textureTag(for: texture) == tag, "second request must reuse the cached texture name")

		let (missingFile, missing, missingDir) = try Self.texturedFile(image: "nothere.png", size: (1, 1), place: nil)
		defer { try? FileManager.default.removeItem(at: missingDir) }
		#expect(library.textureTag(for: missing) == 0)
		withExtendedLifetime((file, missingFile)) {}
	}
}

// MARK: - PartBrowserDataSource (the Parts panel, PartBrowser.xib)

@MainActor
enum PartBrowserHarness {
	/// The Parts panel the way Window > Parts opens it: a PartBrowserPanelController (its header is not in the
	/// bridging header, so it is made by name) whose nib wires a PartBrowserDataSource to real widgets.
	/// The window is ordered in fully transparent (L58).
	static func open() throws -> (NSWindowController, PartBrowserDataSource) {
		let type = try #require(NSClassFromString("PartBrowserPanelController") as? NSWindowController.Type)
		let controller = type.init()
		try ObjC.run {
			if let window = controller.window {
				window.alphaValue = 0
				window.setFrame(NSRect(x: 100, y: 100, width: 700, height: 600), display: false)
				window.orderFront(nil)
			}
		}
		let browser = try #require(controller.value(forKey: "partBrowser") as? PartBrowserDataSource)
		return (controller, browser)
	}

	static func outlet<T>(_ browser: PartBrowserDataSource, _ name: String) throws -> T {
		try #require(browser.value(forKey: name) as? T)
	}

	/// What the parts table shows, through the data-source method AppKit calls for each cell.
	static func rows(_ browser: PartBrowserDataSource) throws -> [String] {
		let table: NSTableView = try outlet(browser, "partsTable")
		let source = try #require(table.dataSource)
		#expect(source === browser)
		let count = source.numberOfRows?(in: table) ?? 0
		return (0..<count).map { row in
			table.tableColumns.map { column in
				"\(source.tableView?(table, objectValueFor: column, row: row) ?? "nil")"
			}.joined(separator: " | ")
		}
	}

	static func state(_ browser: PartBrowserDataSource, _ label: String) throws -> String {
		let field: NSSearchField = try outlet(browser, "searchField")
		let allButton: NSButton = try outlet(browser, "searchAllCategoriesButton")
		let favButton: NSButton = try outlet(browser, "addRemoveFavoriteButton")
		let rows = try rows(browser)
		return "## \(label)\ncategory=\(browser.category() ?? "nil") search=\(field.stringValue.debugDescription) " +
			"selected=\(browser.selectedPartName() ?? "nil") scopeButtonsHidden=\(allButton.isHidden) " +
			"favouriteAction=\(favButton.action.map(NSStringFromSelector) ?? "nil")\n" +
			"rows (\(rows.count)):\n" + rows.map { "  \($0)" }.joined(separator: "\n") + "\n"
	}

	/// Close the panel. The data source can outlive its window (MRC nib ownership), and it observes
	/// LDrawPartLibraryDidChangeNotification for any object: unregister it, or later tests' catalog changes
	/// would drive this stale browser (which writes its selection to defaults).
	static func close(_ controller: NSWindowController, _ browser: PartBrowserDataSource) {
		NotificationCenter.default.removeObserver(browser)
		controller.window?.orderOut(nil)
		controller.close()
	}
}

@MainActor
@Suite("App logic coverage: part browser (P2 exit)", .fixtureLibrary, .serialized, .timeLimit(.minutes(1)))
struct PartBrowserCoverageTests {

	@Test("Browsing: category selection, part selection, search scopes, favourites and a catalog reload")
	func browse() async throws {
		let catalog = try #require(await LibraryCatalogTests.buildCatalog())
		PartLibrary.shared().setPartCatalog(catalog)
		try DefaultsSandbox.run {
			// Previous session's browser state, as awakeFromNib reads it.
			DefaultsSandbox.setArguments([PART_BROWSER_PREVIOUS_CATEGORY: "Brick", PART_BROWSER_PREVIOUS_SELECTED_ROW: 1,
										  PART_BROWSER_SEARCH_MODE: Int(SearchModeT.allCategories.rawValue)])
			let (controller, browser) = try PartBrowserHarness.open()
			defer { PartBrowserHarness.close(controller, browser) }
			// The browser writes these back while being used; let those writes be visible from here on.
			DefaultsSandbox.removeArguments([PART_BROWSER_PREVIOUS_CATEGORY, PART_BROWSER_PREVIOUS_SELECTED_ROW, PART_BROWSER_SEARCH_MODE])
			var log = try PartBrowserHarness.state(browser, "opened (previous category Brick, row 1)")

			let categoryTable: NSOutlineView = try PartBrowserHarness.outlet(browser, "categoryTable")
			let partsTable: NSTableView = try PartBrowserHarness.outlet(browser, "partsTable")
			let field: NSSearchField = try PartBrowserHarness.outlet(browser, "searchField")

			// Group rows cannot be selected; category rows can.
			let groupRow = (0..<categoryTable.numberOfRows).first { categoryTable.isExpandable(categoryTable.item(atRow: $0)) }
			let plateRow = (0..<categoryTable.numberOfRows).first {
				(categoryTable.item(atRow: $0) as? [String: Any])?[CategoryNameKey] as? String == "Plate"
			}
			let group = try #require(groupRow), plate = try #require(plateRow)
			#expect(browser.outlineView(categoryTable, shouldSelectItem: categoryTable.item(atRow: group)!) == false)
			#expect(browser.outlineView(categoryTable, shouldSelectItem: categoryTable.item(atRow: plate)!) == true)

			// Clicking a category: outlineViewSelectionDidChange: loads it and remembers it.
			try ObjC.run { categoryTable.selectRowIndexes(IndexSet(integer: plate), byExtendingSelection: false) }
			log += try PartBrowserHarness.state(browser, "category row 'Plate' selected")
			#expect(UserDefaults.standard.string(forKey: PART_BROWSER_PREVIOUS_CATEGORY) == "Plate")

			// Clicking a part: tableViewSelectionDidChange: remembers the row.
			try ObjC.run { partsTable.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false) }
			log += try PartBrowserHarness.state(browser, "part row 1 selected")
			#expect(UserDefaults.standard.integer(forKey: PART_BROWSER_PREVIOUS_SELECTED_ROW) == 1)
			let selected = try #require(browser.selectedPartName())
			#expect(browser.index(ofPartNamed: selected) == 1)
			#expect(browser.index(ofPartNamed: "no-such-part.dat") == NSNotFound)

			// Typing a search: all-categories scope (aliases excluded), then the selected-category scope.
			field.stringValue = "1 x"
			try ObjC.run { browser.searchFieldChanged(field) }
			log += try PartBrowserHarness.state(browser, "search '1 x' (scope: all categories)")
			try ObjC.run { browser.searchSelectedCategoryButtonClicked(nil) }
			log += try PartBrowserHarness.state(browser, "search '1 x' (scope: selected category)")
			#expect(UserDefaults.standard.integer(forKey: PART_BROWSER_SEARCH_MODE) == Int(SearchModeT.selectedCategory.rawValue))
			try ObjC.run { browser.searchAllCategoriesButtonClicked(nil) }
			#expect(UserDefaults.standard.integer(forKey: PART_BROWSER_SEARCH_MODE) == Int(SearchModeT.allCategories.rawValue))

			// The catalog is reloaded while a search is showing: category and search are restored.
			try ObjC.run { PartLibrary.shared().setPartCatalog(catalog) }
			log += try PartBrowserHarness.state(browser, "catalog reloaded during the search")

			// Clearing the search reverts to the category.
			field.stringValue = ""
			try ObjC.run { browser.searchFieldChanged(field) }
			log += try PartBrowserHarness.state(browser, "search cleared")

			// Favourites: add the selected part, view the Favorites pseudo-category, remove it again.
			try ObjC.run { browser.addFavoriteClicked(nil) }
			log += try PartBrowserHarness.state(browser, "selected part added to favourites")
			#expect(browser.loadCategory(Category_Favorites))
			log += try PartBrowserHarness.state(browser, "Favorites category")
			try ObjC.run { browser.removeFavoriteClicked(nil) }
			#expect((PartLibrary.shared().favoritePartNames() ?? []).isEmpty)
			#expect(browser.loadCategory(Category_Favorites))
			log += try PartBrowserHarness.state(browser, "favourite removed")

			// Insert / double-click send insertLDrawPart: up the responder chain; with no document nothing handles it.
			try ObjC.run {
				browser.addPartClicked(nil)
				browser.doubleClickedInPartTable(nil)
				browser.scrollSelectedCategoryToCenter()
			}
			try Golden.check(Data(log.utf8), against: "app-coverage/part-browser.txt")
		}
	}

	@Test("Dragging a part out: the pasteboard gets one archived, uninitialised part in the colour panel's colour")
	func pasteboard() async throws {
		let catalog = try #require(await LibraryCatalogTests.buildCatalog())
		PartLibrary.shared().setPartCatalog(catalog)
		try DefaultsSandbox.run {
			DefaultsSandbox.setArguments([PART_BROWSER_PREVIOUS_CATEGORY: "Brick", PART_BROWSER_PREVIOUS_SELECTED_ROW: 0])
			let (controller, browser) = try PartBrowserHarness.open()
			defer { PartBrowserHarness.close(controller, browser) }
			let partsTable: NSTableView = try PartBrowserHarness.outlet(browser, "partsTable")
			// A private pasteboard: never the user's general pasteboard.
			let pasteboard = NSPasteboard(name: NSPasteboard.Name("BricksmithTests-\(UUID().uuidString)"))
			defer { pasteboard.releaseGlobally() }

			// Dragging row 2 from the table selects it, then writes it.
			// -tableView:writeRowsWithIndexes:toPasteboard: is deprecated API that AppKit still calls for this table;
			// call the implementation directly so the test doesn't add a deprecation warning.
			typealias WriteRows = @convention(c) (AnyObject, Selector, NSTableView, NSIndexSet, NSPasteboard) -> ObjCBool
			let writeRows = NSSelectorFromString("tableView:writeRowsWithIndexes:toPasteboard:")
			let implementation = unsafeBitCast(browser.method(for: writeRows), to: WriteRows.self)
			let ok = try ObjC.run { implementation(browser, writeRows, partsTable, NSIndexSet(index: 2), pasteboard).boolValue }
			#expect(ok)
			let dragged = try #require(browser.selectedPartName())
			#expect(partsTable.selectedRow == 2)
			// The pasteboard server adds dynamic ("dyn.") UTIs for these legacy type names; ignore those.
			let types = (pasteboard.types ?? []).map(\.rawValue).filter { !$0.hasPrefix("dyn.") }.sorted()
			#expect(types == [LDrawDraggingIsUninitializedPboardType, LDrawDraggingPboardType].sorted())
			#expect(pasteboard.propertyList(forType: NSPasteboard.PasteboardType(LDrawDraggingIsUninitializedPboardType)) as? Bool == true)
			let archives = try #require(pasteboard.propertyList(forType: NSPasteboard.PasteboardType(LDrawDraggingPboardType)) as? [Data])
			#expect(archives.count == 1)
			let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archives[0])
			unarchiver.requiresSecureCoding = false
			let part = try #require(try ObjC.run { unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) } as? LDrawPart)
			#expect(part.displayName() == dragged)

			// Dragging from the preview (LDrawGLView delegate call) writes the same selection.
			typealias WriteDirectives = @convention(c) (AnyObject, Selector, AnyObject?, NSPasteboard, ObjCBool) -> ObjCBool
			let writeDirectives = NSSelectorFromString("LDrawGLView:writeDirectivesToPasteboard:asCopy:")
			let fromPreview = unsafeBitCast(browser.method(for: writeDirectives), to: WriteDirectives.self)
			pasteboard.clearContents()
			#expect(try ObjC.run { fromPreview(browser, writeDirectives, nil, pasteboard, false).boolValue })
			#expect((pasteboard.propertyList(forType: NSPasteboard.PasteboardType(LDrawDraggingPboardType)) as? [Data])?.count == 1)

			// No part selected (empty category): nothing is written.
			#expect(browser.loadCategory("No Such Category") == true)
			#expect(browser.selectedPartName() == nil)
			pasteboard.clearContents()
			#expect(try ObjC.run { browser.writeSelectedPart(to: pasteboard) } == false)
			#expect((pasteboard.types ?? []).isEmpty)
		}
	}
}

// MARK: - MinifigureDialogController

@MainActor
@Suite("App logic coverage: minifigure generator (P2 exit)", .fixtureLibrary, .serialized, .timeLimit(.minutes(1)))
struct MinifigureCoverageTests {

	static let controllerKeys = ["hatsController", "headsController", "necksController", "torsosController",
								 "rightArmsController", "rightHandsController", "rightHandAccessoriesController",
								 "leftArmsController", "leftHandsController", "leftHandAccessoriesController", "hipsController",
								 "rightLegsController", "rightLegAccessoriesController", "leftLegsController",
								 "leftLegAccessoriesController"]

	/// A dialog as -runModal prepares it (restoreFromPreferences, then generateMinifigure:), without the modal loop.
	static func prepared() throws -> MinifigureDialogController {
		let controller = try ObjC.run { MinifigureDialogController() }
		try ObjC.run {
			_ = controller.perform(NSSelectorFromString("restoreFromPreferences"))
			_ = controller.perform(NSSelectorFromString("generateMinifigure:"), with: nil)
		}
		return controller
	}

	/// What -runModal does after the modal loop ends: break the NSObjectController -> dialog retain cycle.
	static func finish(_ controller: MinifigureDialogController) {
		(controller.value(forKey: "objectController") as? NSObjectController)?.content = nil
	}

	@Test("Customise, OK: the settings are saved and a new dialog rebuilds the same minifigure")
	func customiseSaveRestore() throws {
		try DefaultsSandbox.run {
			let first = try Self.prepared()
			// Change what the user can change: part choices, colours, flags, angles.
			try ObjC.run {
				// The second entry of each (sorted) list. (Not the last: the last torso is the malformed
				// MLCad.ini entry characterised in mlcadEntriesAreParts.)
				for key in Self.controllerKeys {
					if let array = first.value(forKey: key) as? NSArrayController,
					   let count = (array.arrangedObjects as? [Any])?.count, count > 1 {
						array.setSelectionIndex(1)
					}
				}
				for (key, value) in [("hasHat", true), ("hasNeckAccessory", true), ("hasRightHand", false),
									 ("hasLeftHand", true), ("hasLeftHandAccessory", true), ("hasRightHandAccessory", true),
									 ("hasLeftLegAccessory", true), ("hasRightLegAccessory", true)] {
					first.setValue(value, forKey: key)
				}
				for (key, value) in [("headElevation", 4.0), ("angleOfHead", 30.0), ("angleOfRightArm", 45.0),
									 ("angleOfLeftLeg", -20.0), ("angleOfRightHandAccessory", 90.0)] {
					first.setValue(value, forKey: key)
				}
				if let well = first.value(forKey: "torsosColorWell") as? NSControl {
					_ = well.perform(NSSelectorFromString("setLDrawColor:"), with: ColorLibrary.shared()?.color(forCode: LDrawRed))
				}
				_ = first.perform(NSSelectorFromString("colorWellChanged:"), with: nil)
			}
			let custom = try #require(first.minifigure())
			let customText = (custom as LDrawDirective).write() ?? ""
			try Golden.check(Data(customText.utf8), against: "app-coverage/minifigure-custom.ldr")

			// OK stops the (here absent) modal session and closes the panel; windowWillClose: saves the settings.
			try ObjC.run { _ = first.perform(NSSelectorFromString("okButtonClicked:"), with: nil) }
			let defaults = UserDefaults.standard
			#expect(defaults.bool(forKey: MINIFIGURE_HAS_HAT) == true)
			#expect(defaults.bool(forKey: MINIFIGURE_HAS_HAND_RIGHT) == false)
			#expect(defaults.float(forKey: MINIFIGURE_HEAD_ELEVATION) == 4)
			#expect(defaults.float(forKey: MINIFIGURE_ANGLE_ARM_RIGHT) == 45)
			#expect(defaults.integer(forKey: MINIFIGURE_COLOR_TORSO) == Int(LDrawRed.rawValue))
			let torsos = try #require(first.value(forKey: "torsosController") as? NSArrayController)
			let torso = try #require(torsos.selectedObjects.first as? LDrawPart)
			#expect(defaults.string(forKey: MINIFIGURE_PARTNAME_TORSO) == torso.referenceName())
			Self.finish(first)

			// A new dialog restores everything and generates the identical minifigure.
			let second = try Self.prepared()
			let restored = (try #require(second.minifigure()) as LDrawDirective).write() ?? ""
			#expect(restored == customText, "restored minifigure differs: \(Golden.firstDifference(Data(customText.utf8), Data(restored.utf8)))")

			// Cancel also closes the panel (and so saves again, unchanged).
			try ObjC.run { _ = second.perform(NSSelectorFromString("cancelButtonClicked:"), with: nil) }
			#expect(defaults.string(forKey: MINIFIGURE_PARTNAME_TORSO) == torso.referenceName())
			Self.finish(second)
		}
	}

	@Test("Every minifigure choice from the bundled MLCad.ini is a real part reference")
	func mlcadEntriesAreParts() throws {
		let ini = try #require(MLCadIni.iniFile())
		let lists: [(String, [Any]?)] = [
			("hats", ini.minifigureHats()), ("heads", ini.minifigureHeads()), ("necks", ini.minifigureNecks()),
			("torsos", ini.minifigureTorsos()), ("hips", ini.minifigureHips()),
			("armsLeft", ini.minifigureArmsLeft()), ("armsRight", ini.minifigureArmsRight()),
			("handsLeft", ini.minifigureHandsLeft()), ("handsLeftAccessories", ini.minifigureHandsLeftAccessories()),
			("handsRight", ini.minifigureHandsRight()), ("handsRightAccessories", ini.minifigureHandsRightAccessories()),
			("legsLeft", ini.minifigureLegsLeft()), ("legsLeftAccessories", ini.minifigureLegsLeftAcessories()),
			("legsRight", ini.minifigureLegsRight()), ("legsRightAccessories", ini.minifigureLegsRightAccessories()),
		]
		var bad: [String] = []
		for (name, list) in lists {
			for case let part as LDrawPart in list ?? [] where !(part.referenceName() ?? "").hasSuffix(".dat") {
				bad.append("\(name): \((part.referenceName() ?? "nil").debugDescription) (\(part.browsingDescription() ?? "?"))")
			}
		}
		// MLCad.ini line 1424 ("Rear Sticker White "1" on Transparent Background") has quotes inside its quoted
		// description; the parser splits there and yields a part named " on Transparent Background" with a
		// garbage matrix, which the generator then writes into the model.
		withKnownIssue("BUG-026: an MLCad.ini entry with quotes in its description becomes a bogus part") {
			#expect(bad.isEmpty, "entries that are not part references:\n\(bad.joined(separator: "\n"))")
		}
	}
}

// MARK: - RelatedParts, LDrawPaths, ModelManager

@Suite("App logic coverage: related parts, paths, model manager (P2 exit)", .fixtureLibrary, .serialized)
struct SmallAppLogicCoverageTests {

	@Test("Related parts by child (the Related Parts menu's per-child lists), sorted by role")
	func relatedByChild() throws {
		let related = try #require(RelatedParts.shared())
		var rows = ["parent\tchild\troles (in returned order)"]
		for parent in ["60596.dat", "57894.dat", "3001.dat"] {
			let children = (related.getChildPartList(parent) ?? []).map { "\($0)" }
			for child in children.sorted() + ["missing.dat"] {
				let list = (related.getRelatedPartList(parent, withChild: child) as? [RelatedPart]) ?? []
				rows.append("\(parent)\t\(child)\t" + list.map { "\($0.role() ?? "?")" }.joined(separator: ","))
			}
		}
		try Golden.check(Data((rows.joined(separator: "\n") + "\n").utf8), against: "app-coverage/related-by-child.tsv")
	}

	@Test("findLDrawPath returns the preferred folder when it is a valid LDraw folder (searched first)")
	func findLDrawPath() throws {
		// Only the preferred-path case: any other case would probe real folders on this machine.
		let library = try #require(FixtureLibrary.current)
		#expect(LDrawPaths.shared().findLDrawPath() == library.path)
	}

	@Test("ModelManager: opening a peer file as a document takes it over from the peer service; re-sign-in is ignored")
	func peerTakeover() throws {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent("BricksmithTests-peer-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: dir) }
		// Lower-case names: peer files are tracked under the part's (lower-cased) reference name.
		let a = dir.appendingPathComponent("a.ldr"), b = dir.appendingPathComponent("b.ldr")
		try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
		try Data("0 Peer A\r\n0 Name: a.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n".utf8).write(to: a)
		try Data("0 Peer B\r\n0 Name: b.ldr\r\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 a.ldr\r\n".utf8).write(to: b)
		try Data("0 Peer C\r\n0 Name: c.ldr\r\n1 2 0 0 0 1 0 0 0 1 0 0 0 1 3024.dat\r\n".utf8)
			.write(to: dir.appendingPathComponent("sub/c.ldr"))

		let manager = ModelManager.shared()
		let fileB = try #require(RoundTrip.load(try Data(contentsOf: b)))
		fileB.setPath(b.path)
		manager.documentSign(in: b.path, with: fileB)
		manager.documentSign(in: b.path, with: fileB)   // already signed in: ignored

		// First request opens a.ldr as a peer; the second returns the tracked copy.
		let peer = try #require(manager.requestModel("a.ldr", withDocument: fileB))
		#expect(manager.requestModel("a.ldr", withDocument: fileB) === peer)
		// Relative paths skip the peer-name fast path and are opened from disk ("\" separators allowed).
		#expect(manager.requestModel("sub\\c.ldr", withDocument: fileB)?.write()?.contains("3024.dat") == true)
		#expect(manager.requestModel("sub\\missing.ldr", withDocument: fileB) == nil)

		// The user opens a.ldr: its peer service is dropped and b now resolves to the user's document.
		let fileA = try #require(RoundTrip.load(try Data(contentsOf: a)))
		fileA.setPath(a.path)
		manager.documentSign(in: a.path, with: fileA)
		let resolved = try #require(manager.requestModel("a.ldr", withDocument: fileB))
		#expect(resolved === fileA.firstModel(), "after opening a.ldr, b must resolve to the open document")
		#expect(resolved !== peer)

		manager.documentSignOut(fileA)
		manager.documentSignOut(fileB)
	}
}

@MainActor
@Suite("Widgets: colour views paint only inside their bounds (BUG-033)", .fixtureLibrary, .serialized)
struct ColorWellTests {

	/// BUG-033: these views filled the dirty rect they were given instead of their bounds. Since the macOS 14 SDK
	/// views don't clip to bounds, so AppKit can pass a dirty rect larger than the view, and the colour covered the
	/// whole panel (Find, Minifigure Generator, inspector) in Debug builds.
	/// Draws `view` (40x20) at (30,40) on a white 100x100 canvas with the whole canvas as the dirty rect.
	static func paint(_ view: NSView) throws -> NSBitmapImageRep {
		let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 100, pixelsHigh: 100, bitsPerSample: 8,
			samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
		let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
		NSGraphicsContext.saveGraphicsState()
		NSGraphicsContext.current = context
		NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 100, height: 100).fill()
		let shift = NSAffineTransform(); shift.translateX(by: 30, yBy: 40); shift.concat()
		view.draw(NSRect(x: -30, y: -40, width: 100, height: 100))
		NSGraphicsContext.restoreGraphicsState()
		return rep
	}

	static func isRed(_ rep: NSBitmapImageRep, _ x: Int, _ y: Int) -> Bool {   // bitmap rows run top-down
		guard let c = rep.colorAt(x: x, y: 99 - y)?.usingColorSpace(.deviceRGB) else { return false }
		return c.redComponent > 0.5 && c.greenComponent < 0.3 && c.blueComponent < 0.3
	}

	static func expectPaintedInsideOnly(_ view: NSView) throws {
		let rep = try paint(view)
		#expect(isRed(rep, 50, 50), "\(type(of: view)): its own centre is not painted")
		for (x, y) in [(5, 5), (95, 95), (5, 95), (95, 5), (50, 10), (50, 90)] {
			#expect(!isRed(rep, x, y), "\(type(of: view)): colour painted outside the view at (\(x), \(y))")
		}
	}

	static func red() throws -> LDrawColor { try #require(ColorLibrary.shared()?.color(forCode: LDrawColorT(rawValue: 4))) }

	@Test("LDrawColorWell") func colorWell() throws {
		let well = LDrawColorWell(frame: NSRect(x: 0, y: 0, width: 40, height: 20))
		well.setLDrawColor(try Self.red())
		try Self.expectPaintedInsideOnly(well)
	}

	@Test("LDrawColorBar") func colorBar() throws {
		let bar = LDrawColorBar(frame: NSRect(x: 0, y: 0, width: 40, height: 20))
		bar.setLDrawColor(try Self.red())
		try Self.expectPaintedInsideOnly(bar)
	}

	@Test("BackgroundColorView") func backgroundView() throws {
		let view = BackgroundColorView(frame: NSRect(x: 0, y: 0, width: 40, height: 20))
		view.setBackgroundColor(.red)
		try Self.expectPaintedInsideOnly(view)
	}
}

// MARK: - Nib top-level objects (P4: +loadNibNamed:owner: -> -loadNibNamed:owner:topLevelObjects:)

/// The legacy loader retained every top-level object; the new one hands back autoreleased objects, and many
/// outlets are __unsafe_unretained (L79). So each owner must keep the top-level objects itself. These tests
/// create the owner inside an autorelease pool, let the pool drain, then touch what the nib made. A missing
/// strong reference shows up as nil, a crash, or (with zombies) a message to a freed object.
@MainActor
@Suite("Nib loading: top-level objects outlive the autorelease pool (P4)", .fixtureLibrary, .serialized,
	   .timeLimit(.minutes(1)))
struct NibLifetimeTests {

	nonisolated static let inspectionClasses = ["InspectionComment", "InspectionConditionalLine", "InspectionLSynth",
									"InspectionLine", "InspectionMPDModel", "InspectionPart", "InspectionQuadrilateral",
									"InspectionStep", "InspectionTriangle", "InspectionUnknownCommand"]

	/// Make an object by class name (these headers are not in the bridging header) inside a drained pool.
	static func make(_ className: String) throws -> NSObject {
		let type = try #require(NSClassFromString(className) as? NSObject.Type, "\(className)")
		var made: NSObject?
		try ObjC.run { autoreleasepool { made = type.init() } }
		return try #require(made)
	}

	/// Every view in the tree, touched (a freed view would crash here).
	static func viewCount(_ view: NSView) -> Int {
		_ = view.frame
		return 1 + view.subviews.reduce(0) { $0 + viewCount($1) }
	}

	@Test("Inspection controllers: window, content view and outlets", arguments: inspectionClasses)
	func inspectionController(_ className: String) throws {
		let controller = try Self.make(className)
		try ObjC.run {
			let window = controller.value(forKey: "window") as? NSWindow
			#expect(window != nil, "\(className): window")
			#expect(window?.title.isEmpty == false, "\(className): title")
			let content = window?.contentView
			#expect(content.map(Self.viewCount) ?? 0 > 1, "\(className): content view")
		}
		if className == "InspectionPart" {
			try ObjC.run {
				for key in ["formatterBasic", "formatterAngle", "formatterScale"] {
					#expect(controller.value(forKey: key) is NumberFormatter, "\(key)")
				}
				let field = controller.value(forKey: "locationXField") as? NSTextField
				#expect(field?.formatter != nil && field?.formatter === controller.value(forKey: "formatterBasic") as AnyObject?)
			}
		}
		if className == "InspectionStep" {
			try ObjC.run {
				// The nib's top-level "Degrees" formatter, reachable only through the fields that use it.
				let field = controller.value(forKey: "rotationXField") as? NSTextField
				#expect(field?.formatter is NumberFormatter)
			}
		}
	}

	@Test("Inspector: its panel survives, and inspecting a part, nothing, a line, a part, the same part")
	func inspector() throws {
		let inspector = try Self.make("Inspector")
		let part = LDrawPart()
		let line = LDrawLine()
		let steps: [(String, [AnyObject])] = [("part", [part]), ("nothing", []), ("line", [line]),
											  ("part again", [part]), ("same part", [part])]
		for (label, objects) in steps {
			try ObjC.run {
				autoreleasepool {
					_ = inspector.perform(NSSelectorFromString("inspectObjects:"), with: objects as NSArray)
				}
			}
			try ObjC.run {
				let panel = inspector.value(forKey: "inspectorPanel") as? NSPanel
				#expect(panel != nil, "\(label): panel")
				#expect(panel?.contentView.map(Self.viewCount) ?? 0 > 1, "\(label): content view")
				#expect(panel?.title.isEmpty == false, "\(label): title")
			}
		}
		try ObjC.run {
			#expect(inspector.value(forKey: "errorTextField") is NSTextField)
			_ = inspector.perform(NSSelectorFromString("unloadInspector"))
		}
	}

	@Test("Preferences: window and every tab view")
	func preferences() throws {
		let controller = try Self.make("PreferencesDialogController")
		try ObjC.run {
			let window = controller.value(forKey: "preferencesWindow") as? NSWindow
			#expect(window?.contentView != nil)
			#expect(window?.toolbar != nil)
			for key in ["generalTabContentView", "stylesContentView", "ldrawContentView", "lsynthContentView",
						"folderChooserAccessoryView", "lsynthExecutableChooserAccessoryView",
						"lsynthConfigurationChooserAccessoryView"] {
				let view = controller.value(forKey: key) as? NSView
				#expect(view.map(Self.viewCount) ?? 0 > 0, "\(key)")
			}
		}
	}

	@Test("Tool palette: its contents view (shared instance, palette kept hidden)")
	func toolPalette() throws {
		let cls: AnyObject = try #require(NSClassFromString("ToolPalette"))
		try ArgumentPrefs.with([TOOL_PALETTE_HIDDEN: true]) {
			var palette: AnyObject?
			try ObjC.run {
				autoreleasepool {
					palette = cls.perform(NSSelectorFromString("sharedToolPalette"))?.takeUnretainedValue()
				}
			}
			try ObjC.run {
				let contents = palette?.value(forKey: "paletteContents") as? NSView
				#expect(contents.map(Self.viewCount) ?? 0 > 1)
				#expect(contents?.window != nil)
			}
		}
	}

	@Test("Part browser data source: its contextual menu")
	func partBrowserMenu() throws {
		let source = try Self.make("PartBrowserDataSource")
		defer { NotificationCenter.default.removeObserver(source) }
		try ObjC.run {
			let menu = source.value(forKey: "contextualMenu") as? NSMenu
			#expect((menu?.items.count ?? 0) > 0)
			#expect(menu?.items.allSatisfy { $0.title.isEmpty == false || $0.isSeparatorItem } == true)
		}
	}

	@Test("LDrawGLView: its contextual menu (from LDrawGLViewAccessories)")
	func glViewMenu() throws {
		var doc: LDrawDocument?
		try autoreleasepool { doc = try DocHarness.open("02-line-types.ldr") }
		let document = try #require(doc)
		defer { DocHarness.close(document) }
		try ObjC.run {
			func glViews(_ view: NSView) -> [NSView] {
				(NSStringFromClass(type(of: view)) == "LDrawGLView" ? [view] : []) + view.subviews.flatMap(glViews)
			}
			let views = document.windowControllers.first?.window?.contentView.map(glViews) ?? []
			#expect(!views.isEmpty)
			for view in views {
				#expect((view.menu?.items.count ?? 0) > 0)
			}
		}
	}

	@Test("Minifigure generator: panel, object controller, formatter and the 15 array controllers")
	func minifigure() throws {
		let controller = try Self.make("MinifigureDialogController")
		defer { MinifigureCoverageTests.finish(controller as! MinifigureDialogController) }
		try ObjC.run {
			let panel = controller.value(forKey: "minifigureGeneratorPanel") as? NSPanel
			#expect(panel?.contentView.map(Self.viewCount) ?? 0 > 1)
			#expect(controller.value(forKey: "objectController") is NSObjectController)
			#expect(controller.value(forKey: "degreesFormatter") is NumberFormatter)
			for key in MinifigureCoverageTests.controllerKeys {
				let array = controller.value(forKey: key) as? NSArrayController
				#expect(array != nil, "\(key)")
				_ = array?.arrangedObjects
			}
		}
	}

	@Test("Dialog panels (Dimensions, Piece Count, Move): the panel and its object controller",
		  arguments: [("DimensionsPanel", "dimensionPanelForFile:"), ("PieceCountPanel", "pieceCountPanelForFile:"),
					  ("MovePanel", "movePanel")])
	func dialogPanel(_ className: String, _ factory: String) throws {
		let cls: AnyObject = try #require(NSClassFromString(className))
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/02-line-types.ldr"))
		var made: NSPanel?
		try ObjC.run {
			autoreleasepool {
				let result = factory.hasSuffix(":")
					? cls.perform(NSSelectorFromString(factory), with: file)
					: cls.perform(NSSelectorFromString(factory))
				made = result?.takeUnretainedValue() as? NSPanel
			}
		}
		let panel = try #require(made, "\(className)")
		try ObjC.run {
			#expect(NSStringFromClass(type(of: panel)) == className)
			#expect(panel.contentView.map(Self.viewCount) ?? 0 > 1)
			let controller = panel.value(forKey: "objectController") as? NSObjectController
			#expect(controller?.content as AnyObject? === panel, "\(className): object controller content")
		}
	}
}
