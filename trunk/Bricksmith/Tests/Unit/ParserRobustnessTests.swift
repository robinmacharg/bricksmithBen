//
//  ParserRobustnessTests.swift
//  BricksmithTests
//
//  P2 row 3: how the parser copes with malformed or unusual input. Characterisation only:
//  the golden records what Bricksmith does today (bugs included); crashes are separated out
//  because they would take down the test host.
//
//  Golden: trunk/Fixtures/golden/robustness/cases.txt (one reviewable file for all cases).
//

import Foundation
import Testing
@testable import Bricksmith

struct RobustnessCase: CustomTestStringConvertible, Sendable {
	let name: String
	let input: String
	var testDescription: String { name }
}

enum Robustness {
	/// Inputs that CRASH the parser today. They are excluded from in-process characterisation and
	/// covered by known-issue tests instead. Keep in sync with the crash probe below.
	static let crashing: Set<String> = ["ROTSTEP malformed angles", "unknown line type 6"]

	static let cases: [RobustnessCase] = [
		.init(name: "empty file", input: ""),
		.init(name: "whitespace only", input: "   \n\t\n  \n"),
		.init(name: "single 0", input: "0"),
		.init(name: "leading whitespace before line type", input: "   1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"),
		.init(name: "lower-case step", input: "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 step\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n"),
		.init(name: "type 1 missing part name", input: "1 4 0 0 0 1 0 0 0 1 0 0 0 1\n"),
		.init(name: "type 1 with too few fields", input: "1 4 0 0 0\n"),
		.init(name: "type 1 non-numeric fields", input: "1 4 a b c 1 0 0 0 1 0 0 0 1 3001.dat\n"),
		.init(name: "type 1 extra fields (part name with spaces)", input: "1 4 0 0 0 1 0 0 0 1 0 0 0 1 my part name.dat\n"),
		.init(name: "type 2 truncated (S2)", input: "2 16 1 2\n"),
		.init(name: "type 3 truncated", input: "3 16 0 0 0 1 1\n"),
		.init(name: "type 4 truncated", input: "4 16 0 0 0\n"),
		.init(name: "type 5 truncated", input: "5 24 0 0\n"),
		.init(name: "type 2 bare", input: "2\n"),
		.init(name: "colour code non-numeric", input: "1 red 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"),
		.init(name: "negative colour code", input: "1 -5 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"),
		.init(name: "malformed !COLOUR missing CODE value (S1)", input: "0 !COLOUR Broken CODE\n"),
		.init(name: "malformed !COLOUR missing VALUE (S1)", input: "0 !COLOUR Broken CODE 901\n"),
		.init(name: "malformed !COLOUR bad hex", input: "0 !COLOUR Broken CODE 902 VALUE #XYZ EDGE #000000\n"),
		.init(name: "0 FILE without name", input: "0 FILE\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 NOFILE\n"),
		.init(name: "MPD missing NOFILE", input: "0 FILE a.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 FILE b.ldr\n1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat\n"),
		.init(name: "MPD reference to missing submodel", input: "0 FILE a.ldr\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 missing.ldr\n0 NOFILE\n"),
		.init(name: "ROTSTEP malformed angles", input: "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 ROTSTEP x y\n"),
		.init(name: "TEXMAP START without END", input: "0 !TEXMAP START PLANAR 0 0 0 1 0 0 0 0 1 a.png\n3 16 0 0 0 1 0 0 0 0 1\n"),
		.init(name: "SYNTH BEGIN without END", input: "0 SYNTH BEGIN PNEUMATIC_HOSE 16\n0 SYNTH SHOW\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 LS01.dat\n"),
		.init(name: "very long comment line", input: "0 " + String(repeating: "x", count: 20_000) + "\n"),
		.init(name: "NUL byte in comment", input: "0 before\u{0}after\n"),
		.init(name: "unknown line type 6", input: "6 16 0 0 0\n"),
	]

	/// Parse and write the way the document does; returns written text.
	static func roundTrip(_ input: String) -> String? {
		guard let file = RoundTrip.load(Data(input.utf8)) else { return nil }
		return String(decoding: RoundTrip.save(file), as: UTF8.self)
	}
}

@Suite("Parser robustness (P2 row 3)", .fixtureLibrary, .serialized)
struct ParserRobustnessTests {

	/// Progress file shared between the parent test and the exit-test child (exit-test bodies cannot
	/// capture values in this toolchain - LEARNINGS L42).
	static let progressFile = FileManager.default.temporaryDirectory
		.appendingPathComponent("BricksmithTests-robustness-progress.txt")

	/// Probe: parse every non-crashing case in ONE child process, recording the case name before each
	/// parse. If the child crashes, the file names the culprit: add it to `Robustness.crashing` and give it
	/// a known-issue test.
	@Test("Parsing the malformed inputs does not crash")
	func doesNotCrash() async throws {
		try? FileManager.default.removeItem(at: Self.progressFile)
		let exited = await #expect(processExitsWith: .success) {
			for c in Robustness.cases where !Robustness.crashing.contains(c.name) {
				try? Data(c.name.utf8).write(to: ParserRobustnessTests.progressFile)
				_ = Robustness.roundTrip(c.input)
			}
			exit(EXIT_SUCCESS)
		}
		if exited == nil || exited?.exitStatus != .exitCode(EXIT_SUCCESS) {
			let last = (try? String(contentsOf: Self.progressFile, encoding: .utf8)) ?? "<unknown>"
			Issue.record("Child crashed while parsing case: \(last)")
		}
	}

	@Test("Characterisation golden: what Bricksmith writes for each malformed input")
	func characterise() throws {
		var out = ""
		for c in Robustness.cases where !Robustness.crashing.contains(c.name) {
			let written = Robustness.roundTrip(c.input)
			out += "### \(c.name)\n"
			out += "in:  \(c.input.debugDescription.prefix(300))\n"
			out += "out: \(written.map { String($0.debugDescription.prefix(300)) } ?? "<parse returned nil>")\n\n"
		}
		try Golden.check(Data(out.utf8), against: "robustness/cases.txt")
	}

	@Test("Meta-command factory: subclass per command; half-parsed !COLOUR (S1); nil for a nonzero line type (S6)")
	func metaCommandFactory() throws {
		func make(_ line: String) -> LDrawDirective? {
			LDrawMetaCommand.directive(lines: ldrawLines([line]), in: NSRange(location: 0, length: 1), parentGroup: nil)
		}
		let comment = try #require(make("0 // hello") as? LDrawComment)
		#expect(comment.stringValue() == "hello")
		let colour = try #require(make("0 !COLOUR Red CODE 4 VALUE #C91A09 EDGE #333333") as? LDrawColor)
		#expect(colour.colorCode().rawValue == 4)
		// S1: a malformed !COLOUR still comes back, with the fields parsed before the error.
		let broken = try #require(make("0 !COLOUR Broken CODE 901") as? LDrawColor)
		#expect(broken.name() == "Broken")
		#expect(broken.colorCode().rawValue == 901)
		let generic = try #require(make("0 UNKNOWN meta"))
		#expect(type(of: generic) == LDrawMetaCommand.self)
		#expect((generic as? LDrawMetaCommand)?.stringValue() == "UNKNOWN meta")
		let blank = try #require(make("   "))
		#expect(type(of: blank) == LDrawMetaCommand.self)
		#expect((blank as? LDrawMetaCommand)?.stringValue() == "   ")
		// S6: a nonzero line type gives no directive at all.
		#expect(make("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat") == nil)
	}

	@Test("readFromData: a malformed-ROTSTEP parse failure gives a bare corrupt-file error (S9 path)")
	@MainActor
	func documentReadOfMalformedRotstep() throws {
		// Before P4 the parse threw (BUG-007) and -readFromData:ofType:error: caught it, writing *outError
		// without a NULL check (S9). Pinned before the conversion; the parse now reports the failure instead.
		let doc = LDrawDocument()
		let before = doc.documentContents()
		var caught: Error?
		try ObjC.run {
			do { try doc.read(from: Data("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 ROTSTEP x y\n".utf8), ofType: "LDraw Document") }
			catch { caught = error }
		}
		let error = try #require(caught) as NSError
		#expect(error.domain == NSCocoaErrorDomain)
		#expect(error.code == NSFileReadCorruptFileError)
		#expect(error.userInfo.isEmpty, "\(error.userInfo)")
		#expect(doc.documentContents() === before, "the document's contents must not be replaced")
	}

	@Test("Document read: a library part whose last line is a malformed ROTSTEP")
	@MainActor func documentReadOfPartWithMalformedRotstep() throws {
		// The part is parsed while the document line referencing it is parsed (-[LDrawPart setDisplayName:parse:]),
		// so the part fails and the document read fails. Pinned before P4 converted the ROTSTEP throw (BUG-007),
		// which used to unwind through the part's @try and the document's. Unique name: PartLibrary caches models
		// for the process.
		let library = try #require(FixtureLibrary.current)
		let name = "p4pin-rotstep-\(UUID().uuidString.prefix(8)).dat".lowercased()
		try Data("0 Part with a malformed ROTSTEP\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 ROTSTEP x y\n".utf8)
			.write(to: library.appendingPathComponent("parts/\(name)"))
		let doc = LDrawDocument()
		let before = doc.documentContents()
		var caught: Error?
		try ObjC.run {
			do { try doc.read(from: Data("1 4 0 0 0 1 0 0 0 1 0 0 0 1 \(name)\n".utf8), ofType: "LDraw Document") }
			catch { caught = error }
		}
		let parts = DocOps.parts(doc).map { "\($0.referenceName() ?? "nil") missing=\($0.partIsMissing())" }
		let error = try #require(caught, "read succeeded: \(parts)") as NSError
		#expect(error.domain == NSCocoaErrorDomain)
		#expect(error.code == NSFileReadCorruptFileError)
		#expect(doc.documentContents() === before, "the document's contents must not be replaced")

		// Control: the same part without the bad ROTSTEP is found and the document opens.
		let goodName = "p4pin-good-\(UUID().uuidString.prefix(8)).dat".lowercased()
		try Data("0 Good part\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n".utf8)
			.write(to: library.appendingPathComponent("parts/\(goodName)"))
		let good = LDrawDocument()
		try ObjC.run { try? good.read(from: Data("1 4 0 0 0 1 0 0 0 1 0 0 0 1 \(goodName)\n".utf8), ofType: "LDraw Document") }
		let goodParts = DocOps.parts(good)
		#expect(goodParts.count == 1)
		#expect(goodParts.first?.partIsMissing() == false, "control part not found: the pin above would prove nothing")
	}

	@Test("Document read: a library part file with no lines (empty file, or a name that is a directory) is just missing")
	@MainActor func documentReadOfPartWithNoLines() throws {
		// Unlike a parse failure, a part file that yields no lines leaves the part unresolved and the document opens
		// (as before P4). Unique names: PartLibrary caches models for the process.
		let library = try #require(FixtureLibrary.current)
		let empty = "p4pin-empty-\(UUID().uuidString.prefix(8)).dat".lowercased()
		try Data().write(to: library.appendingPathComponent("parts/\(empty)"))
		let folder = "p4pin-dir-\(UUID().uuidString.prefix(8))".lowercased()
		try FileManager.default.createDirectory(at: library.appendingPathComponent("parts/\(folder)"), withIntermediateDirectories: false)
		for name in [empty, folder] {
			let doc = LDrawDocument()
			var caught: Error?
			try ObjC.run {
				do { try doc.read(from: Data("1 4 0 0 0 1 0 0 0 1 0 0 0 1 \(name)\n".utf8), ofType: "LDraw Document") }
				catch { caught = error }
			}
			#expect(caught == nil, "\(name): \(String(describing: caught))")
			#expect(DocOps.parts(doc).map { $0.referenceName() } == [name])
		}
	}

	// MARK: Crashers, each confirmed IN ISOLATION (heap corruption can surface in a later case).

	@Test("BUG-007 (fixed in P4): a malformed ROTSTEP line does not crash the parser")
	func bug007RotstepShouldNotCrash() async {
		// Still in a child process: if this regresses, it aborts.
		await #expect(processExitsWith: .success) {
			_ = Robustness.roundTrip("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 ROTSTEP x y\n")
			exit(EXIT_SUCCESS)
		}
	}

	@Test("A malformed ROTSTEP makes the parse return nil and say so; empty text is nil without failing")
	func rotstepParseFailed() {
		var failed: ObjCBool = false
		#expect(LDrawFile.parse(fromFileContents: "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 ROTSTEP x y\n", parseFailed: &failed) == nil)
		#expect(failed.boolValue)
		// Only the last step of a model can fail, but it fails the whole file, later models included.
		failed = false
		#expect(LDrawFile.parse(fromFileContents: "0 FILE a.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 ROTSTEP x y\n0 FILE b.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n", parseFailed: &failed) == nil)
		#expect(failed.boolValue)
		failed = true
		#expect(LDrawFile.parse(fromFileContents: "", parseFailed: &failed) == nil)
		#expect(!failed.boolValue, "empty text is not a parse failure (readFromData: must not report one)")
		failed = true
		#expect(LDrawFile.parse(fromFileContents: "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 ROTSTEP 0 90 0\n", parseFailed: &failed) != nil)
		#expect(!failed.boolValue)
	}

	// MARK: BUG-034 - a TEXMAP image name ending in \" at end of line hangs the parser

	/// `"abc\"` with nothing after it: `+[LDrawUtilities scanQuotableToken:]` un-escapes the `\"`, finds no more
	/// text, keeps the previous `temp` (`abc\`), appends it again and loops forever. `QuotableTokenIsMissing()`
	/// doesn't stop it: the first scan does find a token.
	/// The header lines matter: a model's first lines are read as its description, name and author, so a
	/// TEXMAP line there is never parsed as a texture.
	static let bug034Text = "0 Texmap\n0 Name: t.ldr\n0 Author: Fixture Author\n0 !TEXMAP START PLANAR -10 0 -10 10 0 -10 -10 0 10 \"abc\\\"\n3 16 0 0 0 1 0 0 0 1 0\n0 !TEXMAP END\n"

	@Test("BUG-034: a TEXMAP image name ending in \\\" at end of line hangs the parse today")
	func bug034TexmapTrailingEscapedQuoteHangs() async {
		// The child arms an alarm first, so the hang ends in SIGALRM (not a crash, not a timeout of the run).
		await #expect(processExitsWith: .signal(SIGALRM)) {
			alarm(3)
			_ = LDrawFile.parse(fromFileContents: ParserRobustnessTests.bug034Text)
			exit(EXIT_SUCCESS)
		}
	}

	@Test("BUG-034: parsing a TEXMAP image name ending in \\\" should finish")
	func bug034TexmapTrailingEscapedQuoteShouldFinish() async {
		await withKnownIssue("BUG-034: scanQuotableToken: loops forever on \"abc\\\" at end of line") {
			await #expect(processExitsWith: .success) {
				alarm(3)
				_ = LDrawFile.parse(fromFileContents: ParserRobustnessTests.bug034Text)
				exit(EXIT_SUCCESS)
			}
		}
	}

	@Test("Control for BUG-034: an escaped quote inside a TEXMAP image name parses in process")
	func bug034Control() throws {
		let text = Self.bug034Text.replacingOccurrences(of: "\"abc\\\"", with: "\"a\\\"b.png\"")
		let file = try #require(LDrawFile.parse(fromFileContents: text))
		let texture = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawTexture }.first)
		#expect(texture.imageDisplayName() == "a\"b.png")
	}

	@Test("Isolated: unknown line type 6 crashes today (BUG-001 family)")
	func unknownLineType6CrashesInIsolation() async {
		await #expect(processExitsWith: .failure) {
			_ = Robustness.roundTrip("6 16 0 0 0\n")
			exit(EXIT_SUCCESS)
		}
	}
}

