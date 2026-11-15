//
//  RoundTripTests.swift
//  BricksmithTests
//
//  P2 row 1: parse -> write round trips, characterising what Bricksmith does to a file
//  today (bugs included). Mirrors the document's real load/save path:
//
//      load:  LDrawUtilities.stringFromFileData (UTF-8 -> Latin-1 -> MacRoman)
//             -> LDrawFile.parseFromFileContents
//      save:  LDrawFile.write -> UTF-8 bytes            (LDrawDocument -dataOfType:error:)
//
//  Goldens: trunk/Fixtures/golden/roundtrip/<fixture>[.columnized].ldr - byte exact.
//

import Foundation
import Testing
@testable import Bricksmith

enum RoundTrip {
	/// Load the way -[LDrawDocument readFromData:ofType:error:] does.
	static func load(_ data: Data) -> LDrawFile? {
		LDrawFile.parse(fromFileContents: LDrawUtilities.string(fromFileData: data))
	}

	/// Save the way -[LDrawDocument dataOfType:error:] does.
	static func save(_ file: LDrawFile) -> Data {
		Data(file.write().utf8)
	}

	/// Every round-trip input: the hand-written feature fixtures plus the real-world Test Data file.
	static let fixtures: [URL] = {
		let dir = FixturePaths.fixtures.appendingPathComponent("ldr")
		let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
		return files.filter { ["ldr", "mpd", "dat"].contains($0.pathExtension.lowercased()) }
			.sorted { $0.lastPathComponent < $1.lastPathComponent }
			+ [FixturePaths.testData.appendingPathComponent("Good/spider gearbox v2 opens.ldr")]
	}()

	static func goldenName(for fixture: URL, columnized: Bool) -> String {
		let base = fixture.deletingPathExtension().lastPathComponent.replacingOccurrences(of: " ", with: "_")
		return "roundtrip/\(base)\(columnized ? ".columnized" : "").ldr"
	}
}

@Suite("Round trip: parse -> write (P2 row 1)", .fixtureLibrary, .serialized)
struct RoundTripTests {

	@Test("Fixtures are present", .tags(.harness))
	func fixturesPresent() {
		#expect(RoundTrip.fixtures.count >= 10)
	}

	@Test("write(parse(file)) matches the golden", arguments: RoundTrip.fixtures, [false, true])
	func matchesGolden(fixture: URL, columnized: Bool) throws {
		LDrawUtilities.setColumnizesOutput(columnized)
		let data = try Data(contentsOf: fixture)
		let file = try #require(RoundTrip.load(data))
		try Golden.check(RoundTrip.save(file),
						 against: RoundTrip.goldenName(for: fixture, columnized: columnized))
	}

	@Test("Saving is idempotent: write(parse(write(parse(x)))) == write(parse(x))",
		  arguments: RoundTrip.fixtures, [false, true])
	func idempotent(fixture: URL, columnized: Bool) throws {
		LDrawUtilities.setColumnizesOutput(columnized)
		let first = RoundTrip.save(try #require(RoundTrip.load(try Data(contentsOf: fixture))))
		let second = RoundTrip.save(try #require(RoundTrip.load(first)))
		#expect(first == second, "\(Golden.firstDifference(first, second))")
	}
}

extension Tag {
	@Tag static var harness: Self
}
