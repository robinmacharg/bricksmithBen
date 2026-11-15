//
//  DocumentActionTests.swift
//  BricksmithTests
//
//  P2 row 10: model-changing document actions, each followed by undo and redo, on a real LDrawDocument
//  (nib loaded, window never shown). For every action:
//    - the document text after the action matches a golden (Fixtures/golden/document/<action>.ldr);
//    - undo restores the original bytes exactly;
//    - redo reproduces the post-action bytes exactly.
//  Actions that present UI (alerts, panels, save dialogs) are on TESTING.md's manual-only list.
//

import AppKit
import Foundation
import Testing
@testable import Bricksmith

@MainActor
enum DocOps {
	static func parts(_ doc: LDrawDocument) -> [LDrawPart] {
		ObjectModel.all(doc.documentContents()).compactMap { $0 as? LDrawPart }
	}
	static func directives<T: LDrawDirective>(_ doc: LDrawDocument, _ type: T.Type) -> [T] {
		ObjectModel.all(doc.documentContents()).compactMap { $0 as? T }
	}
	static func select(_ doc: LDrawDocument, _ items: [LDrawDirective]) throws {
		try ObjC.run { doc.selectDirectives(items) }
	}

	/// name -> (fixture, perform). `perform` selects what it needs, then acts.
	static let all: [String: (fixture: String, perform: @MainActor (LDrawDocument) throws -> Void)] = [
		"nudge-x": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.nudgeSelection(by: V3Make(20, 0, 0)) } }),
		"move-by": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.moveSelection(by: V3Make(10, -8, 0)) } }),
		"quick-rotate-y": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.rotateSelectionAround(V3Make(0, 1, 0)) } }),
		"rotate-selection-centre": ("02-line-types.ldr", { d in try select(d, Array(parts(d).prefix(2)))
			try DocHarness.action(d) { d.rotateSelection(V3Make(0, 45, 0), mode: RotateAroundSelectionCenter, fixedCenter: nil) } }),
		"rotate-fixed-point": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]])
			var origin = V3Make(0, 0, 0)
			try DocHarness.action(d) { d.rotateSelection(V3Make(90, 0, 0), mode: RotateAroundFixedPoint, fixedCenter: &origin) } }),
		"snap-to-grid": ("10-floats.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.snapSelectionToGrid(nil) } }),
		"hide": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.setSelectionToHidden(true) } }),
		"show-all": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.setSelectionToHidden(true) }
			try DocHarness.action(d) { d.showAllParts(nil) } }),
		"set-colour": ("02-line-types.ldr", { d in let p = parts(d)[0]
			try DocHarness.action(d) { d.setObject(p, to: ColorLibrary.shared()!.color(forCode: LDrawColorT(rawValue: 2))) } }),
		"set-transformation": ("02-line-types.ldr", { d in let p = parts(d)[0]
			var c = p.transformComponents(); c.translate = V3Make(100, 0, 0)
			try DocHarness.action(d) { d.setTransformation(c, for: p) } }),
		"delete-line": ("02-line-types.ldr", { d in try select(d, [directives(d, LDrawLine.self).first { !($0 is LDrawConditionalLine) }!])
			try DocHarness.action(d) { d.delete(nil as Any?) } }),
		"duplicate": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.duplicate(nil) } }),
		"split-step": ("04-steps-rotstep.ldr", { d in try select(d, [parts(d)[1]]); try DocHarness.action(d) { d.splitStep(nil) } }),
		"add-step": ("04-steps-rotstep.ldr", { d in try select(d, [directives(d, LDrawStep.self)[1]]); try DocHarness.action(d) { d.addStepClicked(nil) } }),
		"add-model": ("05-multipart.mpd", { d in try DocHarness.action(d) { d.addModelClicked(nil) } }),
		"add-line": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.addLineClicked(nil) } }),
		"add-triangle": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.addTriangleClicked(nil) } }),
		"add-quadrilateral": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.addQuadrilateralClicked(nil) } }),
		"add-conditional": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.addConditionalClicked(nil) } }),
		"add-comment": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.addCommentClicked(nil) } }),
		"add-raw-command": ("02-line-types.ldr", { d in try select(d, [parts(d)[0]]); try DocHarness.action(d) { d.addRawCommandClicked(nil) } }),
		"change-origin": ("02-line-types.ldr", { d in try select(d, [parts(d)[1]]); try DocHarness.action(d) { d.changeOrigin(nil) } }),
		"copy-paste": ("02-line-types.ldr", { d in
			let board = NSPasteboard(name: NSPasteboard.Name("BricksmithTests-\(UUID().uuidString)"))
			defer { board.releaseGlobally() }
			try ObjC.run { d.writeDirectives([parts(d)[0]], to: board) }
			let step = directives(d, LDrawStep.self)[0]
			try DocHarness.action(d) { _ = d.paste(from: board, preventNameCollisions: true, parent: step, index: NSNotFound) } }),
		"delete-directive": ("02-line-types.ldr", { d in let p = parts(d)[1]; try DocHarness.action(d) { d.delete(p as LDrawDirective) } }),
		"add-directive": ("02-line-types.ldr", { d in let step = directives(d, LDrawStep.self)[0]
			let comment = LDrawComment(); comment.setStringValue("added by test")
			try DocHarness.action(d) { d.add(comment, toParent: step) } }),
	]
}

/// Compare two LDraw texts token by token, treating numbers as equal within a tolerance (and -0 == 0).
enum NumericText {
	static func approxEqual(_ a: String, _ b: String, tolerance: Float = 1e-3) -> Bool {
		let la = a.components(separatedBy: "\r\n"), lb = b.components(separatedBy: "\r\n")
		guard la.count == lb.count else { return false }
		for (x, y) in zip(la, lb) {
			let tx = x.split(separator: " "), ty = y.split(separator: " ")
			guard tx.count == ty.count else { return false }
			for (p, q) in zip(tx, ty) where p != q {
				guard let fp = Float(p), let fq = Float(q), abs(fp - fq) <= tolerance else { return false }
			}
		}
		return true
	}
}

@MainActor
@Suite("Document actions with undo/redo (P2 row 10)", .fixtureLibrary, .serialized, .timeLimit(.minutes(1)))
struct DocumentActionTests {

	/// Hidden state is kept only in NSCoding (copy/paste), never in the LDraw text (S23).
	static let textUnchanged: Set<String> = ["hide", "show-all"]
	/// Undo implemented as the inverse transform, so floating-point drift and "-0" appear (BUG-016).
	static let inverseUndo: Set<String> = ["quick-rotate-y", "rotate-selection-centre", "rotate-fixed-point", "change-origin"]

	@Test("Action result, undo and redo", arguments: DocOps.all.keys.sorted())
	func action(_ name: String) throws {
		let op = try #require(DocOps.all[name])
		let doc = try DocHarness.open(op.fixture)
		defer { DocHarness.close(doc) }
		let before = DocHarness.text(doc)
		let firstPart = DocOps.parts(doc).first

		try op.perform(doc)
		let after = DocHarness.text(doc)
		if Self.textUnchanged.contains(name) {
			#expect(after == before, "\(name) is expected not to change the saved text (S23)")
			#expect(firstPart?.isHidden() == (name == "hide"))
		} else {
			#expect(after != before, "\(name) changed nothing")
		}
		try Golden.check(Data(after.utf8), against: "document/\(name).ldr")

		// Undo everything the operation registered (some operations are two user actions, e.g. show-all).
		while doc.undoManager?.canUndo == true { try ObjC.run { doc.undoManager?.undo() } }
		let undone = DocHarness.text(doc)
		if Self.textUnchanged.contains(name) { #expect(firstPart?.isHidden() == false, "undo did not unhide") }
		while doc.undoManager?.canRedo == true { try ObjC.run { doc.undoManager?.redo() } }
		let redone = DocHarness.text(doc)

		if Self.inverseUndo.contains(name) {
			#expect(NumericText.approxEqual(undone, before), "undo is not even numerically close: \(Golden.firstDifference(Data(before.utf8), Data(undone.utf8)))")
			#expect(NumericText.approxEqual(redone, after), "redo is not even numerically close")
			withKnownIssue("BUG-016: undo of rotations/change-origin applies the inverse transform (float drift, -0)", isIntermittent: true) {
				#expect(undone == before, "\(Golden.firstDifference(Data(before.utf8), Data(undone.utf8)))")
				#expect(redone == after)
			}
		} else {
			#expect(undone == before, "undo did not restore: \(Golden.firstDifference(Data(before.utf8), Data(undone.utf8)))")
			#expect(redone == after, "redo did not reapply: \(Golden.firstDifference(Data(after.utf8), Data(redone.utf8)))")
		}
	}

	/// Randomize Colors uses rand(), so it is checked by property rather than golden: every selected part gets one
	/// of the colours already in the selection, neighbours differ when there is more than one colour, and undo
	/// restores the text. With a single colour in the selection nothing can change (by design, not a bug).
	@Test("Randomize Colors: shuffles only the selection's own colours; undo restores")
	func randomizeColors() throws {
		let doc = try DocHarness.open("03-colours.ldr")
		defer { DocHarness.close(doc) }
		let parts = DocOps.parts(doc)
		// Colours compared as LDrawColor objects (isEqual/hash), as the action's own NSSet does.
		let colours = { parts.map { $0.lDrawColor()! as NSObject } }
		let original = colours()
		let palette = NSSet(array: original)
		#expect(palette.count >= 3, "fixture should offer several colours")
		let before = DocHarness.text(doc)

		try DocOps.select(doc, parts)
		var changed = false
		for _ in 0..<5 where !changed {   // a shuffle may land on the identity; try a few times
			try DocHarness.action(doc) { doc.randomizeLDrawColors(nil) }
			let now = colours()
			#expect(now.allSatisfy { palette.contains($0) }, "a colour not in the selection appeared")
			#expect(zip(now, now.dropFirst()).allSatisfy { !$0.isEqual($1) }, "neighbouring parts share a colour")
			changed = !zip(now, original).allSatisfy { $0.isEqual($1) }
		}
		#expect(changed, "five randomizations never changed a colour")

		while doc.undoManager?.canUndo == true { try ObjC.run { doc.undoManager?.undo() } }
		#expect(DocHarness.text(doc) == before, "undo did not restore: \(Golden.firstDifference(Data(before.utf8), Data(DocHarness.text(doc).utf8)))")

		// One colour in the selection: nothing to shuffle.
		try DocOps.select(doc, [parts[0]])
		try DocHarness.action(doc) { doc.randomizeLDrawColors(nil) }
		#expect(DocHarness.text(doc) == before)
	}
}
