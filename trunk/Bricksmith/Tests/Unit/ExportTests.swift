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

/// Line-for-line mirror of the save-panel completion block in -[LDrawDocument exportSteps:]
/// (LDrawDocument.m, "exportSteps:"). The logic is inline in that block and can't be called without the
/// panel; P4 extracts it so this test can call the real method. Keep in sync until then.
enum ExportStepsMirror {
	struct Output { let folder: String; let name: String; let text: String }

	static func run(_ document: LDrawFile) -> [Output] {
		let folderFormat = Bundle.main.localizedString(forKey: "ExportedStepsFolderFormat", value: nil, table: nil)
		let fileFormat = Bundle.main.localizedString(forKey: "ExportedStepsFileFormat", value: nil, table: nil)
		var out: [Output] = []
		let submodelCount = document.submodels()?.count ?? 0
		for modelCounter in 0..<submodelCount {
			let fileCopy = document.copy() as! LDrawFile
			let currentModel = fileCopy.submodels()[modelCounter] as! LDrawMPDModel
			fileCopy.remove(currentModel as LDrawDirective)
			fileCopy.insert(currentModel, at: 0)
			fileCopy.setActiveModel(currentModel)
			let folder = String(format: folderFormat, currentModel.modelName())
			var counter = (currentModel.steps()?.count ?? 0) - 1
			while counter >= 0 {
				let name = String(format: fileFormat, currentModel.modelName(), counter + 1)
				out.append(Output(folder: folder, name: name, text: fileCopy.write()))
				currentModel.removeDirective(at: counter)
				counter -= 1
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

	@Test("Export Steps output (mirror of -exportSteps:) matches the golden", arguments: ["04-steps-rotstep.ldr", "05-multipart.mpd"])
	func exportSteps(fixture: String) throws {
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/\(fixture)"))
		let outputs = ExportStepsMirror.run(file)
		try Golden.check(Data(ExportStepsMirror.describe(outputs).utf8),
						 against: "export/steps-\((fixture as NSString).deletingPathExtension).txt")
	}

	@Test("Export Steps: the file for step k contains exactly the first k steps of the model")
	func exportStepsContents() throws {
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/04-steps-rotstep.ldr"))
		let model = try #require(file.activeModel())
		let stepParts: [[String]] = (model.steps() as? [LDrawStep] ?? []).map { step in
			ObjectModel.all(step).compactMap { ($0 as? LDrawPart)?.write() }
		}
		let outputs = ExportStepsMirror.run(file).reversed()   // written last step first
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
