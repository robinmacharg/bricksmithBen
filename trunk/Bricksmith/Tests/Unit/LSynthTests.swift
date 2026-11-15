//
//  LSynthTests.swift
//  BricksmithTests
//
//  P2 row 13: LSynth - LDrawLSynth (which runs the bundled lsynthcp via NSTask) and lsynthcp as a black box.
//  Goldens: Fixtures/golden/lsynth/*
//

import Foundation
import Testing
@testable import Bricksmith

enum LSynthCLI {
	static var executable: URL { URL(fileURLWithPath: Bundle.main.path(forAuxiliaryExecutable: "lsynthcp")!) }
	static var config: String { Bundle.main.path(forResource: "lsynth", ofType: "mpd")! }

	/// Run lsynthcp with arguments and optional stdin; returns (exit status, stdout, stderr).
	static func run(_ arguments: [String], stdin: String? = nil) throws -> (Int32, String, String) {
		let process = Process()
		process.executableURL = executable
		process.arguments = arguments
		let input = Pipe(), output = Pipe(), error = Pipe()
		process.standardInput = input; process.standardOutput = output; process.standardError = error
		try process.run()
		if let stdin { input.fileHandleForWriting.write(Data(stdin.utf8)) }
		try input.fileHandleForWriting.close()
		let out = output.fileHandleForReading.readDataToEndOfFile()
		let err = error.fileHandleForReading.readDataToEndOfFile()
		process.waitUntilExit()
		return (process.terminationStatus, String(decoding: out, as: UTF8.self), String(decoding: err, as: UTF8.self))
	}
}

@Suite("LSynth (P2 row 13)", .fixtureLibrary, .serialized)
struct LSynthTests {

	@Test("LDrawLSynth synthesises via lsynthcp; written output matches the golden and re-parses idempotently",
		  arguments: ["08b-lsynth-show.ldr", "15-lsynth-band.ldr"])
	func synthesise(fixture: String) throws {
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/\(fixture)"))
		let synth = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawLSynth }.first)
		try ObjC.run { synth.synthesize() }
		#expect(synth.synthesizedPartsCount() > 0, "lsynthcp produced no parts")
		let written = RoundTrip.save(file)
		try Golden.check(written, against: "lsynth/\((fixture as NSString).deletingPathExtension).synthesized.ldr")
		let reparsed = RoundTrip.save(try #require(RoundTrip.load(written)))
		#expect(reparsed == written, "\(Golden.firstDifference(written, reparsed))")
	}

	@Test("lsynthcp (stdin/stdout mode, as Bricksmith calls it): hose output matches the golden")
	func cliStdinMode() throws {
		let input = try String(contentsOf: FixturePaths.fixtures.appendingPathComponent("ldr/08b-lsynth-show.ldr"), encoding: .utf8)
		let (status, out, _) = try LSynthCLI.run(["-c", LSynthCLI.config, "-"], stdin: input)
		#expect(status == 0)
		try Golden.check(Data(out.utf8), against: "lsynth/cli-hose-stdout.txt")
	}

	@Test("S11: lsynthcp two-file mode reports a missing input file by name")
	func s11MissingInput() throws {
		let missing = FileManager.default.temporaryDirectory.appendingPathComponent("no-such-input-\(UUID().uuidString).ldr").path
		let out = FileManager.default.temporaryDirectory.appendingPathComponent("lsynth-out-\(UUID().uuidString).ldr").path
		defer { try? FileManager.default.removeItem(atPath: out) }
		let (status, stdout, _) = try LSynthCLI.run(["-c", LSynthCLI.config, missing, out])
		#expect(status != 0, "should fail for a missing input")
		withKnownIssue("S11: the error message prints an uninitialised dat_name instead of the file name", isIntermittent: true) {
			#expect(stdout.contains(missing), "stdout: \(stdout.debugDescription)")
		}
	}
}
