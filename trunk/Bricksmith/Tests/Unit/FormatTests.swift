//
//  FormatTests.swift
//  BricksmithTests
//
//  P2 row 2: output-format edge cases that the round-trip fixtures only touch indirectly.
//  Goldens: trunk/Fixtures/golden/format/*.
//

import Foundation
import Testing
@testable import Bricksmith

@Suite("Format edge cases (P2 row 2)", .fixtureLibrary, .serialized)
struct FormatTests {

	/// Inputs chosen to hit: integers, -0, values not exact in Float, tiny values below the 6 dp of %f,
	/// and magnitudes that overflow the 16-byte formatting buffer (>= 1e8, and the >= 1e14 bug).
	static let floats: [Float] = [
		0, -0.0, 1, -1, 0.5, 0.1, 0.3, 1.0 / 3.0, 3.14159265, -98765.4321, 0.0000001, 0.0000005,
		1e8, 123456789.5, -1e8, 1e9, -1e9, 99999999999999, 1e14, -1e14, 1e15, 1e20,
	]

	@Test("outputStringForFloat: characterisation table (plain and columnized)")
	func floatTable() throws {
		var rows = ["input\tplain\tcolumnized"]
		for value in Self.floats {
			LDrawUtilities.setColumnizesOutput(false)
			let plain = LDrawUtilities.outputString(for: value)!
			LDrawUtilities.setColumnizesOutput(true)
			let columnized = LDrawUtilities.outputString(for: value)!
			rows.append("\(String(format: "%.9g", value))\t\(plain.debugDescription)\t\(columnized.debugDescription)")
		}
		LDrawUtilities.setColumnizesOutput(false)
		try Golden.check(Data((rows.joined(separator: "\n") + "\n").utf8), against: "format/float-output.tsv")
	}

	@Test("Direct colours 0x2RRGGBB survive parse -> write for every channel value", arguments: 0...255)
	func directColourChannel(value: Int) {
		for code in [String(format: "0x2%02X0000", value), String(format: "0x200%02X00", value),
					 String(format: "0x20000%02X", value)] {
			let color = LDrawUtilities.parseColor(fromField: code)
			#expect(LDrawUtilities.outputString(for: color) == code)
		}
	}

	@Test("A new, empty file is written with the compiled-in defaults")
	func newFileDefaults() throws {
		let file: LDrawFile = LDrawFile.file()   // +[LDrawFile file]: one empty, active model
		#expect(file.activeModel() != nil)
		try Golden.check(Data(file.write().utf8), against: "format/new-file.ldr")
	}

	// MARK: Known issues found while reading the formatting code

	@Test("BUG-005: large coordinates are written without losing digits", arguments: [Float(-1e14), -1e15, 1e20])
	func bug005HugeFloats(value: Float) throws {
		LDrawUtilities.setColumnizesOutput(false)
		let written = try #require(LDrawUtilities.outputString(for: value))
		let reparsed = try #require(Float(written))
		withKnownIssue("BUG-005: %f into a 16-byte buffer truncates integer parts of 15+ characters") {
			#expect(abs(reparsed - value) / abs(value) < 1e-6, "\(value) written as \(written)")
		}
	}

	@Test("BUG-006: dithered colour 0x4RGBRGB is preserved on save")
	func bug006DitheredColour() throws {
		let url = FixturePaths.fixtures.appendingPathComponent("ldr/14-direct-colours.ldr")
		let written = String(decoding: RoundTrip.save(try #require(RoundTrip.load(try Data(contentsOf: url)))),
							 as: UTF8.self)
		withKnownIssue("BUG-006: 0x4 colours parsed wrongly (all channels written to red, /255 not /15) and saved as 0x2") {
			#expect(written.contains("1 0x4F00F00 80 0 0"))
			#expect(written.contains("1 0x4123456 100 0 0"))
		}
	}
}
