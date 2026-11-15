//
//  DocumentSpikeTests.swift
//  BricksmithTests
//
//  P2 row 10 spike: can a real LDrawDocument be driven headlessly (nib loaded, window never shown),
//  with selection via the outline view and undo/redo?
//

import AppKit
import Foundation
import Testing
@testable import Bricksmith

@MainActor
enum DocHarness {
	/// Open a fixture as a real document with its window controllers (nib) loaded but no window shown.
	static func open(_ fixture: String) throws -> LDrawDocument {
		let source = FixturePaths.fixtures.appendingPathComponent("ldr/\(fixture)")
		// Work on a temp copy: documents can write (save/autosave) next to their file.
		let copy = FileManager.default.temporaryDirectory.appendingPathComponent("doc-\(UUID().uuidString)-\(fixture)")
		try FileManager.default.copyItem(at: source, to: copy)
		let doc = try LDrawDocument(contentsOf: copy, ofType: "LDraw Document")
		try ObjC.run {
			doc.makeWindowControllers()
			// The nib loads lazily on first access to .window (never shown); -windowControllerDidLoadNib:
			// then fills the outline view, which selection depends on (LEARNINGS L57).
			// Order the window in fully transparent: views then get real on-screen geometry. A never-shown
			// window makes OverlayHelperWindow compute an invalid frame and AppKit asserts (LEARNINGS L58).
			if let window = doc.windowControllers.first?.window {
				window.alphaValue = 0
				window.setFrame(NSRect(x: 100, y: 100, width: 1200, height: 800), display: false)
				window.orderFront(nil)
			}
		}
		doc.undoManager?.groupsByEvent = false
		return doc
	}

	/// Run `body` as one undoable user action (one event's worth of changes).
	static func action(_ doc: LDrawDocument, _ body: () -> Void) throws {
		doc.undoManager?.beginUndoGrouping()
		defer { doc.undoManager?.endUndoGrouping() }
		try ObjC.run(body)
	}

	static func text(_ doc: LDrawDocument) -> String {
		String(decoding: RoundTrip.save(doc.documentContents()), as: UTF8.self)
	}

	static func close(_ doc: LDrawDocument) {
		doc.updateChangeCount(.changeCleared)
		doc.close()
	}
}

@MainActor
@Suite("Document spike (P2 row 10)", .fixtureLibrary, .serialized, .timeLimit(.minutes(1)))
struct DocumentSpikeTests {

	@Test("Open headlessly, select a part, nudge, undo, redo")
	func nudgeUndoRedo() throws {
		let doc = try DocHarness.open("02-line-types.ldr")
		defer { DocHarness.close(doc) }
		let before = DocHarness.text(doc)
		let part = try #require(ObjectModel.all(doc.documentContents()).compactMap { $0 as? LDrawPart }.first)

		try ObjC.run { doc.select(part, byExtendingSelection: false) }
		let selected = try ObjC.run { doc.selectedObjects() as? [AnyObject] }
		#expect(selected?.first === part, "selection did not reach the outline view")

		try DocHarness.action(doc) { doc.nudgeSelection(by: V3Make(20, 0, 0)) }
		let after = DocHarness.text(doc)
		#expect(after != before, "nudge changed nothing")

		try ObjC.run { doc.undoManager?.undo() }
		#expect(DocHarness.text(doc) == before, "undo did not restore")
		try ObjC.run { doc.undoManager?.redo() }
		#expect(DocHarness.text(doc) == after, "redo did not reapply")
	}
}
