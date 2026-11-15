//
//  KnownIssueTests.swift
//  BricksmithTests
//
//  Bugs found while characterising the app (docs/KNOWN-BUGS.md). Each test asserts the
//  CORRECT behaviour inside withKnownIssue, so it is an expected failure today and will be
//  reported if it ever starts passing (which means behaviour changed - investigate).
//  Fixes happen only in P12.
//

import Foundation
import Testing
@testable import Bricksmith

@Suite("Known issues (expected failures)", .fixtureLibrary, .serialized)
struct KnownIssueTests {

	private func roundTrip(_ fixture: String) throws -> String {
		let url = FixturePaths.fixtures.appendingPathComponent("ldr/\(fixture)")
		let file = try #require(RoundTrip.load(try Data(contentsOf: url)))
		return String(decoding: RoundTrip.save(file), as: UTF8.self)
	}

	// MARK: BUG-001 - unknown line type crashes the parser

	@Test("BUG-001 root cause: unknown line codes map to no directive class")
	func bug001RootCause() {
		// Characterises today's behaviour directly (this call does not crash).
		#expect(LDrawUtilities.classForDirectiveBeginning(withLine: "11 16 23 False 0 0 0") == nil)
	}

	@Test("BUG-001: Test Data/Bad crashes the parser today")
	func bug001CrashesToday() async {
		await #expect(processExitsWith: .failure) {
			let url = FixturePaths.testData.appendingPathComponent("Bad/spider gearbox v2 causes crash.ldr")
			let data = try! Data(contentsOf: url)
			_ = LDrawFile.parse(fromFileContents: LDrawUtilities.string(fromFileData: data))
			exit(EXIT_SUCCESS)
		}
	}

	@Test("BUG-001: a file with an unknown line type should open (skipping or preserving the line)")
	func bug001ShouldOpen() async {
		await withKnownIssue("BUG-001: parser crashes on line type 11") {
			await #expect(processExitsWith: .success) {
				let url = FixturePaths.testData.appendingPathComponent("Bad/spider gearbox v2 causes crash.ldr")
				let data = try! Data(contentsOf: url)
				let file = LDrawFile.parse(fromFileContents: LDrawUtilities.string(fromFileData: data))
				exit(file != nil ? EXIT_SUCCESS : EXIT_FAILURE)
			}
		}
	}

	// MARK: BUG-003 - file-local !COLOUR codes are lost on save

	@Test("BUG-003: a part using a colour defined by !COLOUR in the same file keeps that code")
	func bug003LocalColourPreserved() throws {
		let written = try roundTrip("03-colours.ldr")
		withKnownIssue("BUG-003: local colour 900 is written as 16") {
			#expect(written.contains("1 900 60 0 0"))
		}
	}

	// MARK: BUG-004 - LSynth constraints before SHOW/HIDE are dropped

	@Test("BUG-004: LSynth constraints are preserved even without a SYNTH SHOW/HIDE line")
	func bug004LSynthConstraintsPreserved() throws {
		let written = try roundTrip("08-lsynth.ldr")
		withKnownIssue("BUG-004: constraints dropped when SHOW/HIDE is absent") {
			#expect(written.components(separatedBy: "LS01.dat").count - 1 == 2)
		}
	}

	@Test("Control for BUG-004: with SYNTH SHOW the constraints survive")
	func bug004Control() throws {
		let written = try roundTrip("08b-lsynth-show.ldr")
		#expect(written.components(separatedBy: "LS01.dat").count - 1 == 2)
	}
}
