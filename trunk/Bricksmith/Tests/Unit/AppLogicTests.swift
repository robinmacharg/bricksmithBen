//
//  AppLogicTests.swift
//  BricksmithTests
//
//  P2 row 12: logic inside application classes - related parts, LSynth configuration, part-browser search,
//  minifigure generation. (Search panel: manual-only - its logic is bound to the panel's controls.)
//  Goldens: Fixtures/golden/app/*
//

import AppKit
import Foundation
import Testing
@testable import Bricksmith

@Suite("App logic (P2 row 12)", .fixtureLibrary, .serialized)
struct AppLogicTests {

	@Test("Related parts (bundled related.ldr): children, roles and child placement for several parents")
	func relatedParts() throws {
		let related = try #require(RelatedParts.shared())
		var rows = ["parent\tchildren\troles\trelated(role)\tchild placement for identity parent"]
		for parent in ["60596.dat", "57894.dat", "3001.dat", "missing.dat"] {
			let children = (related.getChildPartList(parent) as? [Any])?.map { "\($0)" }.sorted() ?? []
			let roles = (related.getChildRoleList(parent) as? [Any])?.map { "\($0)" }.sorted() ?? []
			var relatedText: [String] = []
			var placement = "-"
			for role in roles {
				let list = (related.getRelatedPartList(parent, withRole: role) as? [RelatedPart]) ?? []
				relatedText.append("\(role): " + list.map { $0.child() ?? "?" }.sorted().joined(separator: ","))
				if placement == "-", let first = list.first {
					placement = PartFactory.describe(first.calcChildPosition(IdentityComponents))
				}
			}
			rows.append([parent, children.joined(separator: ","), roles.joined(separator: ","),
						 relatedText.joined(separator: " | "), placement].joined(separator: "\t"))
		}
		try Golden.check(Data((rows.joined(separator: "\n") + "\n").utf8), against: "app/related-parts.tsv")
	}

	@Test("LSynth configuration (bundled lsynth.mpd): lists, defaults, constraint recognition")
	func lsynthConfiguration() throws {
		let config = try #require(LSynthConfiguration.sharedInstance())
		config.parseLsynthConfig(config.defaultConfigPath())
		func summary(_ name: String, _ list: NSMutableArray?) -> String {
			let items = (list as? [Any] ?? []).map { item -> String in
				// Compact sorted JSON: Foundation's -description formatting is not stable across OS versions.
				if JSONSerialization.isValidJSONObject(item),
				   let data = try? JSONSerialization.data(withJSONObject: item, options: [.sortedKeys]) {
					return String(decoding: data, as: UTF8.self)
				}
				return "\(item)"
			}
			return "\(name): \(items.count) [\(items.prefix(2).joined(separator: " | "))]"
		}
		let lines = [
			summary("parts", config.getParts()), summary("hoseTypes", config.getHoseTypes()), summary("bandTypes", config.getBandTypes()),
			summary("hoseConstraints", config.getHoseConstraints()), summary("bandConstraints", config.getBandConstraints()),
			summary("quickRefHoses", config.getQuickRefHoses()), summary("quickRefBands", config.getQuickRefBands()),
			"defaults: hose=\(LSynthConfiguration.defaultHoseType() ?? "nil") band=\(LSynthConfiguration.defaultBandType() ?? "nil") " +
			"hoseConstraint=\(LSynthConfiguration.defaultHoseConstraint() ?? "nil") bandConstraint=\(LSynthConfiguration.defaultBandConstraint() ?? "nil")",
		]
		try Golden.check(Data((lines.joined(separator: "\n") + "\n").utf8), against: "app/lsynth-config.txt")
		#expect(config.isLSynthConstraint(try PartFactory.part("1 16 0 0 0 1 0 0 0 1 0 0 0 1 LS01.dat")))
		#expect(!config.isLSynthConstraint(try PartFactory.part("1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat")))
	}

	@Test("Part browser search over the catalog", arguments: ["brick", "2 x 4", "3001", "plate 1", "chord", "zzz", ""])
	func partSearch(query: String) async throws {
		let catalog = try #require(await LibraryCatalogTests.buildCatalog())
		let library = PartLibrary.shared()
		library.setPartCatalog(catalog)
		let records = library.allPartCatalogRecords() ?? []
		let source = PartBrowserDataSource()
		let matches = source.filterPartRecords(records, bySearch: query, excludeParts: nil) as? [[String: Any]] ?? []
		let names = matches.compactMap { $0["Part Number"] as? String }.sorted()
		try Golden.check(Data((["query \(query.debugDescription): \(names.count)"] + names).joined(separator: "\n").utf8 + Data("\n".utf8)),
						 against: "app/part-search-\(query.isEmpty ? "empty" : query.replacingOccurrences(of: " ", with: "_")).txt")
	}

	@MainActor
	@Test("Minifigure generator: the default minifigure (as built when the dialog opens)", .timeLimit(.minutes(1)))
	func minifigureDefault() throws {
		// The dialog restores the last minifigure from the defaults; start from an empty Debug domain so a minifigure
		// made during manual testing doesn't change the result (the sandbox puts the domain back afterwards).
		try DefaultsSandbox.run {
			UserDefaults.standard.removePersistentDomain(forName: DefaultsSandbox.debugDomain)
			let controller = try ObjC.run { MinifigureDialogController() }
			try ObjC.run {
				_ = controller.perform(NSSelectorFromString("restoreFromPreferences"))
				_ = controller.perform(NSSelectorFromString("generateMinifigure:"), with: nil)
			}
			let model = try #require(controller.minifigure())
			try Golden.check(Data(((model as LDrawDirective).write() ?? "").utf8), against: "app/minifigure-default.ldr")
		}
	}
}
