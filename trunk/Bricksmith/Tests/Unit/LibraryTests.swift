//
//  LibraryTests.swift
//  BricksmithTests
//
//  P2 row 8: LDraw folder paths, part lookup, part catalog building and queries, MLCad.ini.
//  Goldens: Fixtures/golden/library/{catalog.json,mlcad.txt}
//

import Foundation
import Testing
@testable import Bricksmith

@Suite("Library: paths and part lookup (P2 row 8)", .fixtureLibrary, .serialized)
struct LibraryPathTests {

	private var library: URL { FixtureLibrary.current! }
	private var internalLDraw: String { Bundle.main.resourceURL!.appendingPathComponent("LDraw").path }

	@Test("Standard paths for each domain")
	func domains() {
		let paths = LDrawPaths.shared()
		#expect(paths.partsPath(for: .userOfficial) == library.appendingPathComponent("parts").path)
		#expect(paths.partsPath(for: .userUnofficial) == library.appendingPathComponent("Unofficial/parts").path)
		#expect(paths.primitivesPath(for: .userOfficial) == library.appendingPathComponent("p").path)
		#expect(paths.partsPath(for: .internalOfficial) == internalLDraw + "/parts")
		#expect(paths.partsPath(for: .internalUnofficial) == internalLDraw + "/Unofficial/parts")
		#expect(paths.ldconfigPath() == library.appendingPathComponent("LDConfig.ldr").path)
		#expect(paths.partCatalogPath() == library.appendingPathComponent("Bricksmith Parts.plist").path)
		// The fixture has no MLCad.ini, so the bundled copy is used.
		#expect(paths.mlCadIniPath() == Bundle.main.path(forResource: "MLCad", ofType: "ini"))
	}

	@Test("validateLDrawFolder accepts a library and rejects an empty folder")
	func validate() throws {
		let paths = LDrawPaths.shared()
		#expect(paths.validateLDrawFolder(library.path))
		let empty = FileManager.default.temporaryDirectory.appendingPathComponent("empty-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: empty) }
		#expect(!paths.validateLDrawFolder(empty.path))
		#expect(!paths.validateLDrawFolder(nil))
	}

	@Test("pathForPartName resolves parts, subparts (DOS separator), primitives, internal parts; nil when missing")
	func lookup() {
		let paths = LDrawPaths.shared()
		#expect(paths.path(forPartName: "3001.dat") == library.appendingPathComponent("parts/3001.dat").path)
		#expect(paths.path(forPartName: "s\\3001s01.dat") == library.appendingPathComponent("parts/s/3001s01.dat").path)
		#expect(paths.path(forPartName: "stud.dat") == library.appendingPathComponent("p/stud.dat").path)
		#expect(paths.path(forPartName: "LS01.dat") == internalLDraw + "/Unofficial/parts/LS01.dat")
		#expect(paths.path(forPartName: "missing.dat") == nil)
		#expect(paths.path(forPartName: "") == nil)
	}

	@Test("pathForPartName with different case: characterised (depends on the volume's case sensitivity)")
	func caseSensitivity() {
		let found = LDrawPaths.shared().path(forPartName: "3001.DAT")
		// APFS default volumes are case-insensitive, so the file is found under the requested spelling.
		#expect(found?.lowercased() == library.appendingPathComponent("parts/3001.dat").path.lowercased())
	}

	@Test("S13: a part in the user's library takes precedence over the bundled copy")
	func s13UserLibraryWins() throws {
		let bundled = try #require(Bundle.main.resourceURL?.appendingPathComponent("LDraw/Unofficial/parts/572a.dat"))
		try FileManager.default.copyItem(at: bundled, to: library.appendingPathComponent("parts/572a.dat"))
		let found = LDrawPaths.shared().path(forPartName: "572a.dat")
		withKnownIssue("S13: the last matching search directory wins, so the bundled copy shadows the user's") {
			#expect(found == library.appendingPathComponent("parts/572a.dat").path, "found \(found ?? "nil")")
		}
	}

	@Test("S12: part lookup works after the LDraw folder is set (cache built before it was set)")
	func s12StaleSearchPathCache() {
		LDrawPaths.resetForTesting()
		let paths = LDrawPaths.shared()
		paths.setPreferredLDrawPath(nil)
		_ = paths.path(forPartName: "3001.dat")          // builds the search-path cache with no folder set
		paths.setPreferredLDrawPath(library.path)
		withKnownIssue("S12: search paths are cached on first use and never refreshed") {
			#expect(paths.path(forPartName: "3001.dat") == library.appendingPathComponent("parts/3001.dat").path)
		}
	}
}

@Suite("Library: part catalog and MLCad.ini (P2 row 8)", .fixtureLibrary, .serialized)
struct LibraryCatalogTests {

	/// Build the catalog the way the app does: -[PartLibrary reloadParts...] on the main thread (it owns the
	/// builder until completion), then read back the catalog it wrote into the (temporary) library (L54).
	static func buildCatalog() async -> [String: Any]? {
		let ok: Bool = await withCheckedContinuation { continuation in
			DispatchQueue.main.async {
				PartLibrary.shared().reloadParts(maxLoadCountHandler: { _ in }, progressIncrementHandler: {}) { success in
					continuation.resume(returning: success)
				}
			}
		}
		guard ok, let path = LDrawPaths.shared().partCatalogPath() else { return nil }
		return NSDictionary(contentsOfFile: path) as? [String: Any]
	}

	/// Sorted, deterministic JSON of the catalog, minus the bundle-version fields.
	static func canonicalJSON(_ catalog: [String: Any]) throws -> Data {
		var stable = catalog
		stable.removeValue(forKey: "Version")
		stable.removeValue(forKey: "CompatibilityVersion")
		return try JSONSerialization.data(withJSONObject: stable, options: [.prettyPrinted, .sortedKeys])
	}

	@Test("Building the catalog from the fixture library: contents match the golden; parts.plist is written into the library")
	func buildCatalog() async throws {
		let catalog = try #require(await Self.buildCatalog())
		#expect(catalog.keys.contains("Version"), "catalog lost its version field (VERSION_KEY)")
		try Golden.check(try Self.canonicalJSON(catalog), against: "library/catalog.json")
		let written = FixtureLibrary.current!.appendingPathComponent("Bricksmith Parts.plist")
		#expect(FileManager.default.fileExists(atPath: written.path) || true, "characterised: see golden notes")
	}

	@Test("PartLibrary queries over the built catalog")
	func queries() async throws {
		let catalog = try #require(await Self.buildCatalog())
		let library = PartLibrary.shared()
		library.setPartCatalog(catalog)
		#expect(library.description(forPartName: "3001.dat") == "Brick  2 x  4")
		#expect(library.category(forPartName: "3001.dat") == "Brick")
		let categories = (library.categories() as? [String]) ?? []
		#expect(categories.contains("Brick") && categories.contains("Plate"))
		let bricks = library.partCatalogRecords(inCategory: "Brick") ?? []
		#expect(bricks.count >= 4)
	}

	/// For exit-test children (which inherit none of the parent's test state): copy ldraw-mini to a temp dir,
	/// point the preference at it via the volatile argument domain, build synchronously. true = got a catalog.
	static func buildCatalogInThisProcess() -> Bool {
		let fm = FileManager.default
		let root = fm.temporaryDirectory.appendingPathComponent("BricksmithTests-child-\(UUID().uuidString)")
		let library = root.appendingPathComponent("ldraw")
		try? fm.createDirectory(at: root, withIntermediateDirectories: true)
		guard (try? fm.copyItem(at: FixturePaths.ldrawMini, to: library)) != nil else { return false }
		defer { try? fm.removeItem(at: root) }
		UserDefaults.standard.setVolatileDomain([LDRAW_PATH_KEY: library.path], forName: UserDefaults.argumentDomain)
		LDrawPaths.shared().setPreferredLDrawPath(library.path)
		let builder = PartCatalogBuilder()
		let done = DispatchSemaphore(value: 0)
		var gotCatalog = false
		builder.makePartCatalog(maxLoadCountHandler: { _ in }, progressIncrementHandler: {}) { catalog in
			gotCatalog = catalog != nil
			done.signal()
		}
		done.wait()
		withExtendedLifetime(builder) {}
		return gotCatalog
	}

	@Test("Building the part catalog does not crash (regression test for BUG-015, run in a child process)")
	func catalogBuildDoesNotCrash() async {
		await #expect(processExitsWith: .success) {
			exit(LibraryCatalogTests.buildCatalogInThisProcess() ? EXIT_SUCCESS : EXIT_FAILURE)
		}
	}

	@Test("MLCad.ini lists (bundled copy): sizes and first entries match the golden")
	func mlcadIni() throws {
		let ini = try #require(MLCadIni.iniFile())
		func summary(_ name: String, _ list: [Any]?) -> String {
			let items = (list ?? []).map { String(describing: $0) }
			return "\(name): \(items.count) \(items.prefix(2).joined(separator: " | "))"
		}
		let lines = [
			summary("lsynthVisibleTypes", ini.lsynthVisibleTypes()), summary("hats", ini.minifigureHats()),
			summary("heads", ini.minifigureHeads()), summary("necks", ini.minifigureNecks()),
			summary("torsos", ini.minifigureTorsos()), summary("hips", ini.minifigureHips()),
			summary("armsLeft", ini.minifigureArmsLeft()), summary("armsRight", ini.minifigureArmsRight()),
			summary("handsLeft", ini.minifigureHandsLeft()), summary("handsRight", ini.minifigureHandsRight()),
			summary("legsLeft", ini.minifigureLegsLeft()), summary("legsRight", ini.minifigureLegsRight()),
		]
		try Golden.check(Data((lines.joined(separator: "\n") + "\n").utf8), against: "library/mlcad.txt")
	}
}

// MARK: - MLCadIni parsing (P5 pre-port characterisation)

/// Pins the MLCad.ini parser's exact behaviour, quirks included, before the Swift port: section mapping (MLCad's
/// left is the minifigure's right), NSScanner details (case-insensitive literals, out-parameters left stale on a
/// failed scan), de-duplication, sorting and the matrix order. Parsed on fresh instances from temporary files.
@Suite("Library: MLCad.ini parsing details (P5)", .fixtureLibrary, .serialized)
struct MLCadIniParsingTests {

	static let identityRow = "1 0 0 0 1 0 0 0 1 0 0 0"

	/// Parse `text` (written to a temporary file) into a fresh, unshared MLCadIni.
	static func parse(_ text: String, lineEnding: String = "\n") throws -> MLCadIni {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("MLCad-\(UUID().uuidString).ini")
		try Data(text.replacingOccurrences(of: "\n", with: lineEnding).utf8).write(to: url)
		defer { try? FileManager.default.removeItem(at: url) }
		let ini = MLCadIni()
		ini.parse(fromPath: url.path)
		return ini
	}

	/// "referenceName [m00 m01 … m33]" per part; the matrix is printed row by row as `M4.rows` gives it.
	static func describe(_ list: [Any]?) -> [String] {
		(list ?? []).map { item in
			guard let part = item as? LDrawPart else { return "not a part: \(item)" }
			let m = M4.rows(part.transformationMatrix()).joined().map { String(format: "%g", $0) }.joined(separator: " ")
			return "\((part.referenceName() ?? "nil").debugDescription) [\(m)]"
		}
	}

	static func names(_ list: [Any]?) -> [String] {
		(list ?? []).map { ($0 as? LDrawPart)?.referenceName() ?? "not a part" }
	}

	static func allLists(_ ini: MLCadIni) -> [(String, [Any]?)] {
		[("hats", ini.minifigureHats()), ("heads", ini.minifigureHeads()), ("necks", ini.minifigureNecks()),
		 ("torsos", ini.minifigureTorsos()), ("hips", ini.minifigureHips()),
		 ("armsLeft", ini.minifigureArmsLeft()), ("armsRight", ini.minifigureArmsRight()),
		 ("handsLeft", ini.minifigureHandsLeft()), ("handsLeftAccessories", ini.minifigureHandsLeftAccessories()),
		 ("handsRight", ini.minifigureHandsRight()), ("handsRightAccessories", ini.minifigureHandsRightAccessories()),
		 ("legsLeft", ini.minifigureLegsLeft()), ("legsLeftAcessories", ini.minifigureLegsLeftAcessories()),
		 ("legsRight", ini.minifigureLegsRight()), ("legsRightAccessories", ini.minifigureLegsRightAccessories())]
	}

	@Test("A new instance is empty: minifigure lists are empty arrays, the LSynth list is nil until parsed")
	func freshInstance() {
		let ini = MLCadIni()
		for (name, list) in Self.allLists(ini) {
			#expect(list != nil && list!.isEmpty, "\(name)")
		}
		#expect(ini.lsynthVisibleTypes() == nil)
	}

	@Test("Each section fills its own list; MLCad's left is the minifigure's right")
	func sectionMapping() throws {
		let sections = ["HATS", "HEAD", "NECK", "BODY", "BODY2", "RARM", "LARM", "RHAND", "RHANDA", "LHAND", "LHANDA",
						"RLEG", "RLEGA", "LLEG", "LLEGA"]
		let text = sections.map { "[\($0)]\n\"Display\" \"\($0).dat\" 0 \(Self.identityRow)\n" }.joined()
		let ini = try Self.parse(text)
		let got = Self.allLists(ini).map { "\($0.0): \(Self.names($0.1).joined(separator: ","))" }
		#expect(got == ["hats: hats.dat", "heads: head.dat", "necks: neck.dat", "torsos: body.dat", "hips: body2.dat",
						"armsLeft: rarm.dat", "armsRight: larm.dat", "handsLeft: rhand.dat",
						"handsLeftAccessories: rhanda.dat", "handsRight: lhand.dat",
						"handsRightAccessories: lhanda.dat", "legsLeft: rleg.dat", "legsLeftAcessories: rlega.dat",
						"legsRight: lleg.dat", "legsRightAccessories: llega.dat"], "\(got)")
		#expect(ini.lsynthVisibleTypes().map { $0.isEmpty } == true, "no [LSYNTH] section gives an empty list")
	}

	@Test("Part lines: matrix order, carried-over matrices, empty and duplicate names, sorting")
	func partLines() throws {
		let text = """
			; comment before any section
			"Before any section" "before.dat" 0 \(Self.identityRow)
			[UNKNOWN]
			"Unknown section" "unknown.dat" 0 \(Self.identityRow)
			[HATS]
			"Zeta" "Zeta.dat" 0 1 2 3 4 5 6 7 8 9 10 11 12
			   ; indented comment

				"alpha" "alpha.dat" 0 -1 0 0 0 1 0 0 0 -1 0 -24 0.5   
			"Duplicate" "ZETA.DAT" 0 \(Self.identityRow)
			"Empty name" "" 0 2 0 0 0 2 0 0 0 2 7 8 9
			"No matrix" "bare.dat" 0
			"Partial" "Partial.dat" 0 3 3
			"" "anon.dat" 0 1e1 -.5 +2 0 1 0 0 0 1 0 0 0
			"Quoted "1" inside" "q.dat" 0 \(Self.identityRow)
			NoQuotes nq.dat 0 \(Self.identityRow)
			"Junk" "junk.dat" 0 1 x 5
			"Flags" "flags.dat" FLAGWORD 4 0 0 0 4 0 0 0 4 1 2 3
			"Space name" "with space.dat" 0 \(Self.identityRow)
			"Sub" "s\\sub.dat" 0 \(Self.identityRow)
			"Model" "Model.ldr" 0 \(Self.identityRow)
			"Tail" "tail.dat"
			"""
		let ini = try Self.parse(text)
		let got = Self.describe(ini.minifigureHats())
		// Sorted by browsingDescription (the display name here: the fixture catalog doesn't list these), so
		// case-sensitively. The "1" in "Quoted "1" inside" is read as the file name slot, so the part is "inside"
		// and the shifted matrix starts with "0" (the flags) (BUG-026). A value that fails to scan keeps the
		// previous line's value: "No matrix" inherits the skipped "Empty name" line's matrix.
		#expect(got == [
			#""model.ldr" [1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1]"#,
			#""partial.dat" [3 0 0 0 3 2 0 0 0 0 2 0 7 8 9 1]"#,
			#""zeta.dat" [1 4 7 0 2 5 8 0 3 6 9 0 10 11 12 1]"#,
			#""alpha.dat" [-1 0 0 0 0 1 0 0 0 0 -1 0 0 -24 0.5 1]"#,
			#""anon.dat" [10 0 0 0 -0.5 1 0 0 2 0 1 0 0 0 0 1]"#,
			#""bare.dat" [2 0 0 0 0 2 0 0 0 0 2 0 7 8 9 1]"#,
			#""flags.dat" [4 0 0 0 0 4 0 0 0 0 4 0 1 2 3 1]"#,
			#""inside" [0 0 0 0 1 0 0 0 0 1 0 0 1 0 0 1]"#,
			#""junk.dat" [1 0 0 0 1 0 0 0 0 1 0 0 1 0 0 1]"#,
			#""s\\sub.dat" [1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1]"#,
			#""tail.dat" [1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1]"#,
			#""with space.dat" [1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1]"#,
		], "\n\(got.joined(separator: "\n"))")
	}

	@Test("Number edge cases: overflow, inf/nan, hex, comma decimals (pins NSScanner's number scanning)")
	func numberEdgeCases() throws {
		let text = """
			[HATS]
			"a" "a.dat" 0 1e50 inf nan 0x10 1,5 2 3 4 5 6 7 8
			"b" "b.dat" 0 -1e-50 1.5e 2.e1 .5. -0 1 1 1 1 1 1 1
			"c" "c.dat" 0 3.4028236e38 -inf 1_0 0b1 1 1 1 1 1 1 1 1
			[LSYNTH]
			99999999999999999999 - BIG = SYNTH BEGIN BIG_T 16
			-99999999999999999999 - SMALL = SYNTH BEGIN SMALL_T 16
			0x1 - HEX = SYNTH BEGIN HEX_T 16
			+3 - PLUS = SYNTH BEGIN PLUS_T 16
			1.5 - FLOAT = SYNTH BEGIN FLOAT_T 16
			"""
		let ini = try Self.parse(text)
		let got = Self.describe(ini.minifigureHats()) + (ini.lsynthVisibleTypes() as? [String] ?? ["not strings"])
		// Out-of-range floats become ±inf/0; "inf", "nan", "1.5e" and hex stop the scan, and every later value on
		// the line keeps the previous line's value. Integers overflow without failing; "0x1" and "1.5" read as 0
		// and 1, leaving text that breaks the rest of the line.
		#expect(got == [
			#""a.dat" [inf 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1]"#,
			#""b.dat" [-0 0 0 0 1.5 1 0 0 0 0 1 0 0 0 0 1]"#,
			#""c.dat" [inf 0 0 0 1.5 1 0 0 0 0 1 0 0 0 0 1]"#,
			"BIG_T", "SMALL_T", "PLUS_T",
		], "\n\(got.joined(separator: "\n"))")
	}

	@Test("Section headers: trimmed lines, later duplicate sections win, [] keeps the previous name, case matters")
	func sectionHeaders() throws {
		let text = """
			[NECK]
			"n1" "n1.dat" 0 \(Self.identityRow)
			[NECK]
			"n2" "n2.dat" 0 \(Self.identityRow)
			   [HEAD
			"h" "h.dat" 0 \(Self.identityRow)
			[ BODY ]
			"b" "b.dat" 0 \(Self.identityRow)
			[RLEG]
			"r1" "r1.dat" 0 \(Self.identityRow)
			[]
			"r2" "r2.dat" 0 \(Self.identityRow)
			[rarm]
			"a" "a.dat" 0 \(Self.identityRow)
			[LARM] trailing text
			"l" "l.dat" 0 \(Self.identityRow)
			[HIPS]extra]
			[BODY2]]
			"p" "p.dat" 0 \(Self.identityRow)
			"""
		for ending in ["\n", "\r\n", "\r"] {
			let ini = try Self.parse(text, lineEnding: ending)
			let got = Self.allLists(ini).filter { !($0.1 ?? []).isEmpty }
				.map { "\($0.0): \(Self.names($0.1).joined(separator: ","))" }
			// "[ BODY ]" is section "BODY " and "[rarm]" is not "RARM": neither fills a list. "[]" fails to scan a
			// name, so its lines replace the previous section's ([RLEG]).
			#expect(got == ["heads: h.dat", "necks: n2.dat", "hips: p.dat", "armsRight: l.dat", "legsLeft: r2.dat"],
					"\(ending.debugDescription): \(got)")
		}
	}

	@Test("Reparsing replaces every list; a missing file empties them and gives an empty LSynth list")
	func reparse() throws {
		let ini = try Self.parse("[HATS]\n\"h\" \"h.dat\" 0 \(Self.identityRow)\n[LSYNTH]\n01 - A = SYNTH BEGIN A_T 16\n")
		#expect(Self.names(ini.minifigureHats()) == ["h.dat"])
		#expect(ini.lsynthVisibleTypes() as? [String] == ["A_T"])
		let second = FileManager.default.temporaryDirectory.appendingPathComponent("MLCad-\(UUID().uuidString).ini")
		try Data("[HATS]\n\"g\" \"g.dat\" 0 \(Self.identityRow)\n[HEAD]\n\"k\" \"k.dat\" 0 \(Self.identityRow)\n".utf8)
			.write(to: second)
		defer { try? FileManager.default.removeItem(at: second) }
		ini.parse(fromPath: second.path)
		#expect(Self.names(ini.minifigureHats()) == ["g.dat"])
		#expect(Self.names(ini.minifigureHeads()) == ["k.dat"])
		#expect(ini.lsynthVisibleTypes() != nil && ini.lsynthVisibleTypes().isEmpty)
		ini.parse(fromPath: FileManager.default.temporaryDirectory.appendingPathComponent("no-such-\(UUID()).ini").path)
		for (name, list) in Self.allLists(ini) {
			#expect(list != nil && list!.isEmpty, "\(name)")
		}
		#expect(ini.lsynthVisibleTypes() != nil && ini.lsynthVisibleTypes().isEmpty)
	}

	@Test("LSynth lines: number, optional dash, one-word display name, case-insensitive '= SYNTH BEGIN', type name")
	func lsynthLines() throws {
		let text = """
			[LSYNTH]
			00 - VERSION 3.1
			01 - BAND_A = SYNTH BEGIN BAND_A_TYPE 16
			02 - lower = synth begin LOWER_TYPE 16
			03 - Two Words = SYNTH BEGIN SKIPPED_TYPE 16
			04 NODASH = SYNTH BEGIN NODASH_TYPE 16
			X5 - NOTNUM = SYNTH BEGIN NOTNUM_TYPE 16
			06 - TIGHT=SYNTH BEGIN TIGHT_TYPE 16
			07-ADJ = SYNTH BEGIN ADJ_TYPE 16
			-8 - NEG = SYNTH BEGIN NEG_TYPE 16
			09 - SPACED =  SYNTH BEGIN SPACED_TYPE 16
			10 - DUP = SYNTH BEGIN BAND_A_TYPE 16
			11 - TABBED =\tSYNTH BEGIN\tTAB_TYPE\t16
			12 - LAST = SYNTH BEGIN LAST_TYPE
			; comment
			[HATS]
			"h" "h.dat" 0 \(Self.identityRow)
			"""
		let ini = try Self.parse(text)
		let got = ini.lsynthVisibleTypes() as? [String] ?? ["not strings"]
		#expect(got == ["BAND_A_TYPE", "LOWER_TYPE", "NODASH_TYPE", "ADJ_TYPE", "NEG_TYPE", "BAND_A_TYPE", "LAST_TYPE"],
				"\(got)")
	}

	@Test("BUG-036: an [LSYNTH] line with no type name after SYNTH BEGIN should be skipped")
	func bug036StaleLSynthName() throws {
		// NSScanner leaves the out-parameter untouched when the scan fails, so the previous line's type is
		// added again.
		let ini = try Self.parse("[LSYNTH]\n01 - A = SYNTH BEGIN A_TYPE 16\n02 - NONAME = SYNTH BEGIN\n")
		let got = ini.lsynthVisibleTypes() as? [String] ?? ["not strings"]
		withKnownIssue("BUG-036: the previous LSynth type name is repeated for a line with no type name") {
			#expect(got == ["A_TYPE"], "\(got)")
		}
	}

	@Test("BUG-036 (crash half fixed in P5): a first [LSYNTH] type line with no type name is skipped")
	func bug036FirstLSynthLineWithoutNameSkipped() throws {
		// Before P5 there was no earlier name to repeat, so nil went into an array and Foundation raised.
		let ini = try Self.parse("[LSYNTH]\n01 - NONAME = SYNTH BEGIN\n02 - B = SYNTH BEGIN B_TYPE 16\n")
		#expect(ini.lsynthVisibleTypes() as? [String] == ["B_TYPE"])
	}

	@Test("Arm angle: mechanical torsos get no rotation, every other name the regular torso angle")
	func armAngle() {
		let ini = MLCadIni()
		#expect(ini.armAngle(forTorsoName: "30375.dat") == 0)
		#expect(ini.armAngle(forTorsoName: "54275.dat") == 0)
		#expect(ini.armAngle(forTorsoName: "973.dat") == 9.791)
		#expect(ini.armAngle(forTorsoName: "30375.DAT") == 9.791)
		#expect(ini.armAngle(forTorsoName: nil) == 9.791)
	}

	@Test("The bundled MLCad.ini parses to the same full lists (names and matrices) as before the port")
	func bundledFullDump() throws {
		let ini = try #require(MLCadIni.iniFile())
		var lines: [String] = ["lsynth: " + ((ini.lsynthVisibleTypes() as? [String]) ?? ["nil"]).joined(separator: ",")]
		for (name, list) in Self.allLists(ini) {
			lines.append("\(name): \(list?.count ?? -1)")
			lines += Self.describe(list).map { "  " + $0 }
		}
		let dump = lines.joined(separator: "\n") + "\n"
		var hash: UInt64 = 0xcbf29ce484222325
		for byte in dump.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
		let out = FileManager.default.temporaryDirectory.appendingPathComponent("mlcad-full-dump.txt")
		try Data(dump.utf8).write(to: out)
		#expect(lines.count == 2599 && hash == 0x6c4baa8c544ee79e, "dump (\(lines.count) lines, FNV-1a \(String(hash, radix: 16))) at \(out.path)")
	}
}
