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

/// P6a pins for LDrawFile and LDrawMPDModel, written against the ObjC classes before the Swift port:
/// active-model bookkeeping and its notification, the name lookup table, undo of renames, copy, the
/// factories, and the nil cases the ObjC handled by messaging nil.
@Suite("MPD and LDrawFile edge behaviour (P6a pins)", .fixtureLibrary, .serialized)
struct MPDFileEdgeTests {

	private func load() throws -> LDrawFile {
		try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/05-multipart.mpd"))
	}

	private func named(_ name: String) -> LDrawMPDModel {
		let model = LDrawMPDModel()
		model.setModelName(name)
		return model
	}

	/// Counts notifications with the given name whose object passes `matches`, while `body` runs.
	private func count(_ name: String, matching matches: @escaping (AnyObject) -> Bool, _ body: () throws -> Void) rethrows -> Int {
		var seen = 0
		let token = NotificationCenter.default.addObserver(forName: NSNotification.Name(name), object: nil, queue: nil) { note in
			if let object = note.object as AnyObject?, matches(object) { seen += 1 }
		}
		defer { NotificationCenter.default.removeObserver(token) }
		try body()
		return seen
	}

	@Test("setActiveModel: posts only on a real change, and only when the file posts notifications",
		  arguments: [false, true])
	func setActiveModel(postsNotifications: Bool) throws {
		let file = try load()
		file.setPostsNotifications(postsNotifications)
		let main = try #require(file.model(withName: "main.ldr"))
		let sub = try #require(file.model(withName: "sub.ldr"))
		let stranger = named("stranger.ldr")

		let posted = count(LDrawFileActiveModelDidChangeNotification, matching: { $0 === file }) {
			file.setActiveModel(sub)			// a change
			file.setActiveModel(sub)			// no change
			file.setActiveModel(stranger)		// not in the file: ignored (logged)
			#expect(file.activeModel() === sub)
			file.setActiveModel(nil)			// clears, silently
			#expect(file.activeModel() == nil)
			file.setActiveModel(main)			// a change
		}
		#expect(posted == (postsNotifications ? 2 : 0))
		#expect(file.activeModel() === main)
	}

	@Test("Removing the active model activates the first remaining one; removing the last leaves none")
	func removeActiveModel() throws {
		let file = try load()
		let main = try #require(file.model(withName: "main.ldr"))
		let sub = try #require(file.model(withName: "sub.ldr"))
		file.setActiveModel(sub)
		file.remove(sub as LDrawDirective)
		#expect(file.activeModel() === main)
		#expect(file.model(withName: "sub.ldr") == nil, "lookup table rebuilt")
		#expect((file.modelNames() as? [String]) == ["main.ldr"])
		file.remove(main as LDrawDirective)
		#expect(file.activeModel() == nil)
		#expect(file.submodels()?.count == 0)
		#expect(file.write() == "")
	}

	@Test("removeDirectiveAtIndex: rebuilds the lookup table but leaves the active model alone")
	func removeAtIndexKeepsActiveModel() throws {
		let file = try load()
		let sub = try #require(file.model(withName: "sub.ldr"))
		file.setActiveModel(sub)
		file.removeDirective(at: 1)
		#expect(file.activeModel() === sub)
		#expect(file.model(withName: "sub.ldr") == nil)
	}

	@Test("Lookup follows a submodel renamed directly (MessageNameChanged), and tolerates duplicate names")
	func lookupTable() throws {
		let file = try load()
		let sub = try #require(file.model(withName: "sub.ldr"))
		sub.setModelName("Other.LDR")
		#expect(file.model(withName: "other.ldr") === sub)
		#expect(file.model(withName: "sub.ldr") == nil)
		#expect(file.model(withName: nil) == nil)

		let dupes = LDrawFile()
		let first = named("dup.ldr"), second = named("DUP.ldr")
		dupes.addSubmodel(first)
		dupes.addSubmodel(second)
		#expect(dupes.model(withName: "Dup.ldr") === first, "the earlier submodel wins")
		#expect((dupes.modelNames() as? [String]) == ["dup.ldr", "DUP.ldr"])
	}

	@Test("Every insert posts LDrawMPDSubModelAdded on the file, including while copying")
	func subModelAddedNotification() throws {
		let file = try load()
		let added = count(LDrawMPDSubModelAdded, matching: { $0 === file }) {
			file.addSubmodel(named("third.ldr"))
			file.insert(named("fourth.ldr"), at: 0)
		}
		#expect(added == 2)
		let copies = count(LDrawMPDSubModelAdded, matching: { $0 is LDrawFile && $0 !== file }) {
			_ = file.copy()
		}
		#expect(copies == 4)
	}

	@Test("A copy activates the model at the active model's index, and keeps every name")
	func copyKeepsActiveModel() throws {
		let file = try load()
		let sub = try #require(file.model(withName: "sub.ldr"))
		file.setActiveModel(sub)
		let copy = try #require(file.copy() as? LDrawFile)
		#expect(copy.activeModel() !== sub)
		#expect(copy.activeModel() === copy.submodels()?[file.index(of: sub)] as AnyObject?)
		// The copy activates the model at the active model's *index*. BUG-011 reverses the copied
		// submodels, so with two models that is the copy of the other one.
		#expect(Set(copy.modelNames() as? [String] ?? []) == Set(file.modelNames() as? [String] ?? []))
		let activeName = try #require(copy.activeModel()?.modelName())
		#expect(copy.model(withName: activeName.uppercased()) === copy.activeModel())
		#expect(copy.path() == nil)
	}

	@Test("A decoded file activates its first model and rebuilds the lookup table")
	func archiveRoundTrip() throws {
		let file = try load()
		file.setActiveModel(file.model(withName: "sub.ldr"))
		let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(file)) as? LDrawFile)
		#expect(decoded.activeModel() === decoded.firstModel())
		#expect(decoded.model(withName: "SUB.LDR")?.modelName() == "sub.ldr")
	}

	@Test("Undoing a rename: through the file (references follow) and on a loose model")
	func undoRename() throws {
		let file = try load()
		let sub = try #require(file.model(withName: "sub.ldr"))
		let undo = UndoManager()
		undo.groupsByEvent = false
		try ObjC.run {
			undo.beginUndoGrouping()
			sub.registerUndoActions(undo)
			undo.endUndoGrouping()
		}
		file.renameModel(sub, toName: "renamed.ldr")
		let reference = { ObjectModel.all(file).compactMap { $0 as? LDrawPart }.map { $0.referenceName() ?? "nil" } }
		#expect(reference().contains("renamed.ldr"))
		try ObjC.run { undo.undo() }
		#expect(sub.modelName() == "sub.ldr")
		#expect(reference().contains("sub.ldr"))
		#expect(file.model(withName: "sub.ldr") === sub)

		let loose = named("before.ldr")
		let looseUndo = UndoManager()
		looseUndo.groupsByEvent = false
		try ObjC.run {
			looseUndo.beginUndoGrouping()
			loose.registerUndoActions(looseUndo)
			looseUndo.endUndoGrouping()
		}
		loose.setModelName("after.ldr")
		try ObjC.run { looseUndo.undo() }
		#expect(loose.modelName() == "before.ldr")
	}

	@Test("renameModel ignores a model outside the file and an unchanged name")
	func renameNoOps() throws {
		let file = try load()
		let sub = try #require(file.model(withName: "sub.ldr"))
		let before = RoundTrip.save(file)
		let recorder = ObserverRecorder(label: "sub")
		sub.add(recorder)
		defer { (sub as any LDrawObservable).remove(recorder) }
		file.renameModel(sub, toName: "sub.ldr")
		file.renameModel(named("sub.ldr"), toName: "x.ldr")
		file.renameModel(nil, toName: "x.ldr")
		#expect(recorder.log.isEmpty)
		#expect(RoundTrip.save(file) == before)
	}

	@Test("MPD model messages: a rename says MessageNameChanged, a new parent MessageScopeChanged")
	func modelMessages() throws {
		let model = named("a.ldr")
		let recorder = ObserverRecorder(label: "obs")
		model.add(recorder)
		defer { (model as any LDrawObservable).remove(recorder) }
		model.setModelName("b.ldr")
		model.setModelDisplayName("My Model")
		let file = LDrawFile()
		file.addSubmodel(model)
		#expect(recorder.log == ["obs: message 0 from LDrawMPDModel", "obs: message 0 from LDrawMPDModel",
								 "obs: message 1 from LDrawMPDModel"])
		#expect(model.modelName() == "My Model.ldr")
		#expect(model.modelDisplayName() == "My Model")
		#expect(model.browsingDescription() == "My Model")
		#expect(model.inspectorClassName() == "InspectionMPDModel")
	}

	@Test("A nil model name: FILE line prints (null), display name and compliant name are nil")
	func nilModelName() throws {
		let model = LDrawMPDModel()
		#expect(model.modelName() == "")
		model.setModelName(nil)
		#expect(model.modelName() == nil)
		#expect(model.modelDisplayName() == nil)
		#expect(model.browsingDescription() == nil)
		// Through LDrawDirective: Swift imports -writeModel as LDrawMPDModel.write().
		let text = try #require((model as LDrawDirective).write())
		#expect(text.hasPrefix("0 FILE (null)\r\n"), "\(text.debugDescription)")
		#expect(text.hasSuffix("\r\n0 NOFILE"), "\(text.debugDescription)")
		#expect(LDrawMPDModel.ldrawCompliantName(forName: nil) == nil)
	}

	@Test("Factories: +[LDrawMPDModel model] and +[LDrawFile file]")
	func factories() throws {
		let model = try #require(LDrawMPDModel.model() as? LDrawMPDModel)
		#expect(model.modelName() == LDrawMPDModel.ldrawCompliantName(forName: NSLocalizedString("UntitledModel", comment: "")))
		#expect(model.steps()?.count == 1)
		#expect(model.modelDescription() == NSLocalizedString("UntitledModel", comment: ""))

		let file = try #require(LDrawFile.file())
		#expect(file.submodels()?.count == 1)
		#expect(file.activeModel() === file.firstModel())
		#expect(file.path() == nil)
	}

	@Test("An empty file: no active model, empty output, zero bounds, no hits")
	func emptyFile() throws {
		let file = LDrawFile()
		#expect(file.activeModel() == nil)
		#expect(file.submodels()?.count == 0)
		#expect(file.modelNames()?.count == 0)
		#expect(file.model(withName: "x.ldr") == nil)
		#expect(file.write() == "")
		let box = file.boundingBox3()
		#expect([box.min.x, box.min.y, box.min.z, box.max.x, box.max.y, box.max.z] == [0, 0, 0, 0, 0, 0])
		#expect(file.draggingDirectives() == nil)
		#expect(!file.boxTest(V2MakeBox(-1e6, -1e6, 2e6, 2e6), transform: IdentityMatrix4,
							  boundsOnly: false, creditObject: nil, hits: NSMutableSet()))
	}

	@Test("Parsing: nil and empty text give nil without parseFailed; a non-MPD model is named by its description")
	func parsing() throws {
		var failed: ObjCBool = true
		#expect(LDrawFile.parse(fromFileContents: nil, parseFailed: &failed) == nil)
		#expect(!failed.boolValue)
		failed = true
		#expect(LDrawFile.parse(fromFileContents: "", parseFailed: &failed) == nil)
		#expect(!failed.boolValue)

		let single = try #require(LDrawFile.parse(fromFileContents: "0 Plain Title\r\n0 Name: plain.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n"))
		#expect((single.modelNames() as? [String]) == ["Plain Title"])

		// An MPD model with no NOFILE runs to the next FILE line.
		let open = try #require(LDrawFile.parse(fromFileContents: "0 FILE a.ldr\r\n0 A\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 FILE b.ldr\r\n0 B\r\n"))
		#expect((open.modelNames() as? [String]) == ["a.ldr", "b.ldr"])
		#expect((open.model(withName: "a.ldr") as LDrawDirective?)?.write()?.contains("3001.dat") == true)
	}

	@Test("+fileFromContentsAtPath: parses the file and records its path; a missing file gives nil")
	func fromPath() throws {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("BricksmithTests-path-\(UUID().uuidString).ldr")
		try Data("0 FILE p.ldr\r\n0 P\r\n0 NOFILE\r\n".utf8).write(to: url)
		defer { try? FileManager.default.removeItem(at: url) }
		let file = try #require(LDrawFile(fromContentsAtPath: url.path))
		#expect(file.path() == url.path)
		#expect((file.modelNames() as? [String]) == ["p.ldr"])
		#expect(LDrawFile(fromContentsAtPath: url.path + ".missing") == nil)
	}
}
