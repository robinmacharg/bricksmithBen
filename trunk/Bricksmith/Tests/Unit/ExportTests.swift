//
//  ExportTests.swift
//  BricksmithTests
//
//  P2 row 11: exports - Export Steps and the piece-count report.
//  Goldens: Fixtures/golden/export/*
//

import Foundation
import Testing
@testable import Bricksmith

/// Runs the real -[LDrawDocument exportStepsToURL:] (the work of Export Steps once its save panel is accepted) into a
/// temp folder, and reads the files back in the order the method writes them: one folder per submodel, in the order
/// of a copy of the file (the method works on copies, so BUG-011 reverses it), and each folder's steps last to first.
///
/// The document is given the fixture as parsed by `ObjectModel.load`, the input the goldens were recorded from (by a
/// line-for-line mirror of the method, until P4 extracted it). Opening the file as a document instead would also run
/// -doMissingModelnameExtensionCheck:, which appends ".ldr" to a model name without an extension, so the folder and
/// file names would differ.
@MainActor
enum ExportStepsRun {
	struct Output { let folder: String; let name: String; let text: String }

	static func run(_ fixture: String) throws -> [Output] {
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/\(fixture)"))
		let doc = LDrawDocument()
		try ObjC.run { doc.setDocumentContents(file) }
		let fm = FileManager.default
		let root = fm.temporaryDirectory.appendingPathComponent("export-steps-\(UUID().uuidString)")
		defer { try? fm.removeItem(at: root) }
		// Something already at the destination: the export replaces it.
		try Data("stale".utf8).write(to: root)
		try ObjC.run { doc.exportSteps(to: root) }
		var isDirectory: ObjCBool = false
		#expect(fm.fileExists(atPath: root.path, isDirectory: &isDirectory) && isDirectory.boolValue,
				"the existing file at the destination was not replaced by a folder")

		let folderFormat = Bundle.main.localizedString(forKey: "ExportedStepsFolderFormat", value: nil, table: nil)
		let copy = try #require(doc.documentContents().copy() as? LDrawFile)
		let folders = (copy.submodels() as? [LDrawMPDModel] ?? []).map { String(format: folderFormat, $0.modelName()) }
		#expect(Set(try fm.contentsOfDirectory(atPath: root.path)) == Set(folders), "unexpected folders")

		var out: [Output] = []
		for folder in folders {
			let dir = root.appendingPathComponent(folder)
			let names = try fm.contentsOfDirectory(atPath: dir.path)
			let numbered = try names.map { name -> (Int, String) in
				let match = try #require(name.firstMatch(of: /Step (\d+)\.ldr$/), "unexpected file \(folder)/\(name)")
				return (Int(match.1)!, name)
			}
			for (_, name) in numbered.sorted(by: { $0.0 > $1.0 }) {
				let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
				out.append(Output(folder: folder, name: name, text: text))
			}
		}
		return out
	}

	static func describe(_ outputs: [Output]) -> String {
		outputs.map { "=== \($0.folder) / \($0.name)\n\($0.text.replacingOccurrences(of: "\r\n", with: "\n"))\n" }.joined(separator: "\n")
	}
}

@Suite("Exports (P2 row 11)", .fixtureLibrary, .serialized)
struct ExportTests {

	@MainActor
	@Test("Export Steps output (-exportStepsToURL:) matches the golden", arguments: ["04-steps-rotstep.ldr", "05-multipart.mpd"])
	func exportSteps(fixture: String) throws {
		let outputs = try ExportStepsRun.run(fixture)
		try Golden.check(Data(ExportStepsRun.describe(outputs).utf8),
						 against: "export/steps-\((fixture as NSString).deletingPathExtension).txt")
	}

	@MainActor
	@Test("Export Steps: the file for step k contains exactly the first k steps of the model")
	func exportStepsContents() throws {
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/04-steps-rotstep.ldr"))
		let model = try #require(file.activeModel())
		let stepParts: [[String]] = (model.steps() as? [LDrawStep] ?? []).map { step in
			ObjectModel.all(step).compactMap { ($0 as? LDrawPart)?.write() }
		}
		let outputs = try ExportStepsRun.run("04-steps-rotstep.ldr").reversed()   // read back last step first
		withKnownIssue("BUG-011: copy reverses steps, so exported step files contain the wrong steps") {
			for (k, output) in outputs.enumerated() {
				let expected = stepParts.prefix(k + 1).flatMap { $0 }
				let actual = output.text.components(separatedBy: "\r\n").filter { $0.hasPrefix("1 ") }
				#expect(actual == expected, "\(output.name): \(actual) vs expected \(expected)")
			}
		}
	}

	@Test("Piece-count report text (as exported from the Piece Count panel)", arguments: ["02-line-types.ldr", "03-colours.ldr"])
	func pieceCount(fixture: String) async throws {
		let catalog = try #require(await LibraryCatalogTests.buildCatalog())
		PartLibrary.shared().setPartCatalog(catalog)
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/\(fixture)"))
		let report = try #require(PartReport(for: file.activeModel()))
		report.getPieceCount()
		let sort = [NSSortDescriptor(key: PART_REPORT_NUMBER_KEY, ascending: true),
					NSSortDescriptor(key: PART_REPORT_COLOR_NAME, ascending: true)]
		let text = try #require(report.textualRepresentation(withSortDescriptors: sort))
		try Golden.check(Data(text.utf8), against: "export/piece-count-\((fixture as NSString).deletingPathExtension).txt")
	}
}
