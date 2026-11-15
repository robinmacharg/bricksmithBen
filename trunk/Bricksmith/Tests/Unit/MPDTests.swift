//
//  MPDTests.swift
//  BricksmithTests
//
//  P2 row 9: multi-part documents (submodel lookup, active model, rename with reference updates,
//  name helpers) and ModelManager's cross-document (peer file) resolution.
//  Goldens: Fixtures/golden/mpd/{rename.ldr,names.tsv}
//

import Foundation
import Testing
@testable import Bricksmith

@Suite("MPD and ModelManager (P2 row 9)", .fixtureLibrary, .serialized)
struct MPDTests {

	private func load(_ name: String) throws -> LDrawFile {
		try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/\(name)"))
	}

	@Test("Submodels: names, case-insensitive lookup, active model")
	func submodels() throws {
		let file = try load("05-multipart.mpd")
		#expect((file.modelNames() as? [String]) == ["main.ldr", "sub.ldr"])
		#expect(file.submodels()?.count == 2)
		let sub = try #require(file.model(withName: "sub.ldr"))
		#expect(file.model(withName: "SUB.LDR") === sub, "lookup is case-insensitive")
		#expect(file.model(withName: "missing.ldr") == nil)
		#expect(file.activeModel() === file.firstModel(), "first model is active after parsing")
		file.setActiveModel(sub)
		#expect(file.activeModel() === sub)
	}

	@Test("A part referencing a submodel resolves to that submodel")
	func partResolvesSubmodel() throws {
		let file = try load("05-multipart.mpd")
		let part = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawPart }.first { $0.referenceName() == "sub.ldr" })
		#expect(part.referencedMPDSubmodel() === file.model(withName: "sub.ldr"))
	}

	@Test("Renaming a submodel updates its FILE line and every reference (golden)")
	func rename() throws {
		let file = try load("05-multipart.mpd")
		let sub = try #require(file.model(withName: "sub.ldr"))
		file.renameModel(sub, toName: "renamed sub.ldr")
		#expect(file.model(withName: "renamed sub.ldr") === sub)
		#expect(file.model(withName: "sub.ldr") == nil)
		try Golden.check(RoundTrip.save(file), against: "mpd/rename.ldr")
	}

	@Test("Name helpers: LDraw-compliant names and FILE/NOFILE line detection (golden)")
	func nameHelpers() throws {
		var rows = ["kind\tinput\tresult"]
		for name in ["My Model", "my model.ldr", "Sub Model 2.mpd", "weird/name:with*chars", "", "  padded  ", "ÜnïcödÉ"] {
			rows.append("compliantName\t\(name.debugDescription)\t\(String(describing: LDrawMPDModel.ldrawCompliantName(forName: name)).debugDescription)")
		}
		for line in ["0 FILE main.ldr", "0 FILE  name with spaces.ldr", "0 file lower.ldr", "0  FILE  extra.ldr", "0 FILE", "0 NOFILE",
					 "0 nofile", "0 //FILE no", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 x.ldr"] {
			var name: NSString?
			// Pass &name directly: Swift's write-back for NSString** out-params (a hand-made
			// AutoreleasingUnsafeMutablePointer over-releases - LEARNINGS L55).
			let start = LDrawMPDModel.lineIsMPDModelStart(line, modelName: &name)
			rows.append("isStart\t\(line.debugDescription)\t\(start) \(name.map { String($0).debugDescription } ?? "nil")")
			rows.append("isEnd\t\(line.debugDescription)\t\(LDrawMPDModel.lineIsMPDModelEnd(line))")
		}
		try Golden.check(Data((rows.joined(separator: "\n") + "\n").utf8), against: "mpd/names.tsv")
	}

	@Test("ModelManager resolves a peer file in the same folder, only while the asking document is signed in")
	func peerFiles() throws {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent("BricksmithTests-peer-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: dir) }
		let a = dir.appendingPathComponent("A.ldr"), b = dir.appendingPathComponent("B.ldr")
		try Data("0 Peer A\r\n0 Name: A.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n".utf8).write(to: a)
		try Data("0 Peer B\r\n0 Name: B.ldr\r\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 A.ldr\r\n".utf8).write(to: b)

		let fileB = try #require(RoundTrip.load(try Data(contentsOf: b)))
		fileB.setPath(b.path)
		let manager = ModelManager.shared()
		manager.documentSign(in: b.path, with: fileB)

		// The app resolves through the part, whose referenceName is lower-cased (-[LDrawPart setDisplayName:...]).
		let part = try #require(ObjectModel.all(fileB).compactMap { $0 as? LDrawPart }.first)
		#expect(part.referenceName() == "a.ldr")
		let resolved = manager.requestModel(part.referenceName(), withDocument: fileB)
		#expect(resolved?.write()?.contains("3001.dat") == true, "peer A.ldr not resolved")
		// Characterised contract: requestModel expects lower-case names (peer names are stored lower-cased).
		#expect(manager.requestModel("A.ldr", withDocument: fileB) == nil)
		#expect(manager.requestModel("missing.ldr", withDocument: fileB) == nil)

		manager.documentSignOut(fileB)
		#expect(manager.requestModel("a.ldr", withDocument: fileB) == nil, "no service after sign-out")
	}
}
