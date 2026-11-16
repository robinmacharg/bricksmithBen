//
//  ObjectModelTests.swift
//  BricksmithTests
//
//  P2 row 4: the directive tree as an object model - structure, NSCopying, NSCoding (the
//  copy/paste format) and LDrawObserver notifications.
//
//  Goldens:   Fixtures/golden/model/tree/<fixture>.txt, Fixtures/golden/model/observer-events.txt
//  Archives:  Fixtures/archives/<fixture>.archive - keyed archives produced by the ObjC build.
//             They must keep decoding after classes move to Swift (@objc names, NSCoding keys).
//

import Foundation
import Testing
@testable import Bricksmith

enum ObjectModel {
	/// Indented class-name tree, with each leaf's written text (first 60 chars) for orientation.
	static func describe(_ directive: LDrawDirective, depth: Int = 0) -> String {
		let indent = String(repeating: "  ", count: depth)
		let name = String(describing: type(of: directive))
		guard let container = directive as? LDrawContainer else {
			let text = (directive.write() ?? "").replacingOccurrences(of: "\r\n", with: " / ")
			return "\(indent)\(name): \(text.prefix(60))\n"
		}
		let children = (container.subdirectives() as? [LDrawDirective]) ?? []
		return "\(indent)\(name) (\(children.count))\n" + children.map { describe($0, depth: depth + 1) }.joined()
	}

	/// Every object in the tree, depth first.
	static func all(_ directive: LDrawDirective) -> [LDrawDirective] {
		let children = ((directive as? LDrawContainer)?.subdirectives() as? [LDrawDirective]) ?? []
		return [directive] + children.flatMap(all)
	}

	/// Keyed archive exactly like -[LDrawDocument writeDirectives:toPasteboard:]
	/// (+[NSKeyedArchiver archivedDataWithRootObject:], non-secure).
	static func archive(_ object: Any) -> Data {
		let archiver = NSKeyedArchiver(requiringSecureCoding: false)
		archiver.encode(object, forKey: NSKeyedArchiveRootObjectKey)
		archiver.finishEncoding()
		return archiver.encodedData
	}

	/// Unarchive like the paste path (+[NSKeyedUnarchiver unarchiveObjectWithData:], non-secure).
	static func unarchive(_ data: Data) throws -> Any? {
		let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
		unarchiver.requiresSecureCoding = false
		defer { unarchiver.finishDecoding() }
		return unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
	}

	static func load(_ fixture: URL) throws -> LDrawFile {
		try #require(RoundTrip.load(try Data(contentsOf: fixture)))
	}

	static func text(_ file: LDrawFile) -> Data { RoundTrip.save(file) }

	/// Inputs containing direct colours (0x2RRGGBB / 0x3RRGGBB / 0x4...), which archiving loses (BUG-012).
	static func hasDirectColour(_ text: String?) -> Bool {
		(text ?? "").range(of: #"(^|\s)0x[2-4][0-9A-Fa-f]{6}\s"#, options: .regularExpression) != nil
	}

	static func baseName(_ fixture: URL) -> String {
		fixture.deletingPathExtension().lastPathComponent.replacingOccurrences(of: " ", with: "_")
	}
}

/// Records LDrawObserver callbacks as readable lines.
final class ObserverRecorder: NSObject, LDrawObserver {
	var log: [String] = []
	let label: String
	init(label: String) { self.label = label }

	private func who(_ o: Any?) -> String { o.map { String(describing: type(of: $0)) } ?? "nil" }

	func observableSaysGoodbyeCruelWorld(_ doomedObservable: (any LDrawObservable)!) {
		log.append("\(label): goodbye from \(who(doomedObservable))")
	}
	func statusInvalidated(_ flags: CacheFlagsT, who observable: (any LDrawObservable)!) {
		log.append("\(label): statusInvalidated flags=\(flags.rawValue) from \(who(observable))")
	}
	func receiveMessage(_ msg: MessageT, who observable: (any LDrawObservable)!) {
		log.append("\(label): message \(msg.rawValue) from \(who(observable))")
	}
}

@Suite("Object model (P2 row 4)", .fixtureLibrary, .serialized)
struct ObjectModelTests {

	@Test("Tree structure after parsing matches the golden", arguments: RoundTrip.fixtures)
	func treeShape(fixture: URL) throws {
		let file = try ObjectModel.load(fixture)
		try Golden.check(Data(ObjectModel.describe(file).utf8),
						 against: "model/tree/\(ObjectModel.baseName(fixture)).txt")
	}

	@Test("copy() is a deep copy that writes identically", arguments: RoundTrip.fixtures)
	func deepCopy(fixture: URL) throws {
		let original = try ObjectModel.load(fixture)
		let copy = try #require(original.copy() as? LDrawFile)
		// Containers with a single child are unaffected, hence intermittent.
		withKnownIssue("BUG-011: -[LDrawContainer copyWithZone:] reverses children (index never advances)",
					   isIntermittent: true) {
			#expect(ObjectModel.text(copy) == ObjectModel.text(original),
					"\(Golden.firstDifference(ObjectModel.text(original), ObjectModel.text(copy)))")
		}

		let originals = ObjectModel.all(original), copies = ObjectModel.all(copy)
		#expect(originals.count == copies.count)
		let originalIDs = Set(originals.map(ObjectIdentifier.init))
		// LDrawColor deliberately returns self from -copy (documented in LDrawColor.m), so it is shared (see S19).
		let shared = copies.filter { originalIDs.contains(ObjectIdentifier($0)) && !($0 is LDrawColor) }
		#expect(shared.isEmpty, "copy shares \(shared.count) objects with the original: \(shared.map { String(describing: type(of: $0)) })")
	}

	@Test("Keyed archive round trip of a whole file writes identically", arguments: RoundTrip.fixtures)
	func archiveRoundTrip(fixture: URL) throws {
		let original = try ObjectModel.load(fixture)
		let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(original)) as? LDrawFile)
		withKnownIssue("BUG-012: archiving (copy/paste) turns direct colours into 16") {
			#expect(ObjectModel.text(decoded) == ObjectModel.text(original),
					"\(Golden.firstDifference(ObjectModel.text(original), ObjectModel.text(decoded)))")
		} when: { ObjectModel.hasDirectColour(String(decoding: ObjectModel.text(original), as: UTF8.self)) }
	}

	@Test("Copy/paste format: each top-level step directive survives archiving individually", arguments: RoundTrip.fixtures)
	func pasteboardDirectives(fixture: URL) throws {
		let file = try ObjectModel.load(fixture)
		let directives = ObjectModel.all(file).filter { !($0 is LDrawContainer) }
		for directive in directives {
			let decoded = try #require(try ObjectModel.unarchive(ObjectModel.archive(directive)) as? LDrawDirective)
			#expect(type(of: decoded) == type(of: directive))
			withKnownIssue("BUG-012: archiving (copy/paste) turns direct colours into 16") {
				#expect(decoded.write() == directive.write(), "\(String(describing: directive.write())) -> \(String(describing: decoded.write()))")
			} when: { ObjectModel.hasDirectColour(directive.write()) }
		}
	}

	/// Archives recorded from the ObjC build (RECORD_GOLDENS=1) must decode to the same written text, today
	/// and after the port. Not byte-compared: archive bytes are not guaranteed stable.
	@Test("Archives recorded from the Objective-C build still decode", arguments: RoundTrip.fixtures)
	func committedArchivesDecode(fixture: URL) throws {
		let archiveURL = FixturePaths.fixtures.appendingPathComponent("archives/\(ObjectModel.baseName(fixture)).archive")
		let original = try ObjectModel.load(fixture)
		if Golden.isRecording {
			try FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			try ObjectModel.archive(original).write(to: archiveURL)
			return
		}
		let data = try #require(FileManager.default.contents(atPath: archiveURL.path),
								"Missing \(archiveURL.lastPathComponent); record with RECORD_GOLDENS=1")
		let decoded = try #require(try ObjectModel.unarchive(data) as? LDrawFile)
		withKnownIssue("BUG-012: archiving (copy/paste) turns direct colours into 16") {
			#expect(ObjectModel.text(decoded) == ObjectModel.text(original))
		} when: { ObjectModel.hasDirectColour(String(decoding: ObjectModel.text(original), as: UTF8.self)) }
	}

	@Test("Observer callbacks and NSNotifications for common edits match the golden",
		  arguments: [false, true])
	func observerEvents(postsNotifications: Bool) throws {
		let file = try ObjectModel.load(FixturePaths.fixtures.appendingPathComponent("ldr/02-line-types.ldr"))
		// A document turns notifications on for its contents (-[LDrawDocument setDocumentContents:]).
		file.setPostsNotifications(postsNotifications)
		let model = try #require((file.subdirectives() as? [LDrawDirective])?.first as? LDrawContainer)
		let step = try #require((model.subdirectives() as? [LDrawDirective])?.first as? LDrawContainer)
		let part = try #require((step.subdirectives() as? [LDrawDirective])?.first { $0 is LDrawPart } as? LDrawPart)
		let tree = Set(ObjectModel.all(file).map(ObjectIdentifier.init))

		let recorders = [("file", file as LDrawDirective), ("model", model), ("step", step), ("part", part)]
			.map { (ObserverRecorder(label: $0.0), $0.1) }
		recorders.forEach { $0.1.add($0.0) }

		var posted: [String] = []
		let token = NotificationCenter.default.addObserver(forName: nil, object: nil, queue: nil) { note in
			guard let object = note.object as AnyObject?, tree.contains(ObjectIdentifier(object)) else { return }
			posted.append("notification \(note.name.rawValue) object=\(type(of: object))")
		}
		defer { NotificationCenter.default.removeObserver(token) }

		var log: [String] = []
		func record(_ action: String, _ body: () -> Void) {
			recorders.forEach { $0.0.log.removeAll() }
			posted.removeAll()
			body()
			log.append("## \(action)")
			log += recorders.flatMap { $0.0.log } + posted
		}

		record("part.setLDrawColor(4)") { part.setLDrawColor(ColorLibrary.shared()!.color(forCode: LDrawColorT(rawValue: 4))) }
		record("part.moveBy(10,0,0)") { part.move(by: V3Make(10, 0, 0)) }
		let newPart = try #require(part.copy() as? LDrawPart)
		record("step.addDirective(copy of part)") { step.add(newPart as LDrawDirective) }
		record("step.removeDirective(copy of part)") { step.remove(newPart as LDrawDirective) }

		recorders.forEach { $0.1.remove($0.0) }
		try Golden.check(Data((log.joined(separator: "\n") + "\n").utf8),
						 against: "model/observer-events\(postsNotifications ? ".posting" : "").txt")
	}
}

// MARK: - P6b pins: LDrawPart

enum P6bPart {
	/// -[LDrawPart initWithLines:inRange:parentGroup:] on one line, as the step parser calls it.
	static func make(_ line: String) -> LDrawPart? {
		LDrawPart(lines: ldrawLines([line]), in: NSRange(location: 0, length: 1), parentGroup: nil)
	}

	static func write(_ d: LDrawDirective?) -> String {
		d.map { ($0.write() ?? "nil").replacingOccurrences(of: "\r\n", with: "\n") } ?? "<nil>"
	}

	/// A unique, lower-case library part name (PartLibrary caches models for the whole process).
	static func uniqueName(_ stem: String) -> String { "p6b-\(stem)-\(UUID().uuidString.prefix(8)).dat".lowercased() }

	static func writePart(_ name: String, _ text: String) throws {
		let library = try #require(FixtureLibrary.current)
		try Data(text.utf8).write(to: library.appendingPathComponent("parts/\(name)"))
	}

	/// The keys of the archived object of class `className` in a keyed archive (its plist form).
	static func archivedKeys(_ data: Data, className: String) throws -> [String] {
		let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
		let objects = try #require(plist["$objects"] as? [Any])
		for case let dict as [String: Any] in objects {
			guard let classRef = dict["$class"] else { continue }
			// A CFKeyedArchiverUID prints as "<CFKeyedArchiverUID 0x...>{value = N}".
			let text = String(describing: classRef)
			guard let range = text.range(of: #"value = (\d+)"#, options: .regularExpression),
				  let index = Int(text[range].filter(\.isNumber)), objects.indices.contains(index) else { continue }
			if let classInfo = objects[index] as? [String: Any], classInfo["$classname"] as? String == className {
				return dict.keys.filter { $0 != "$class" }.sorted()
			}
		}
		return []
	}
}

@MainActor
@Suite("LDrawPart (P6b pins)", .fixtureLibrary, .serialized)
struct P6bPartPinTests {
	init() throws { try OffscreenGL.makeCurrent() }

	@Test("Parsing malformed type-1 lines: what comes back (the cases the @try in -initWithLines: guarded)")
	func malformedLines() throws {
		let cases: [(String, String)] = [
			("good", "1 4 1 2 3 1 0 0 0 1 0 0 0 1 3001.dat"),
			("bare line type", "1"),
			("colour only", "1 4"),
			("truncated position", "1 4 0 0"),
			("no name", "1 4 0 0 0 1 0 0 0 1 0 0 0 1"),
			("no name, trailing spaces", "1 4 0 0 0 1 0 0 0 1 0 0 0 1   "),
			("non-numeric fields", "1 4 a b c 1 0 0 0 1 0 0 0 1 3001.dat"),
			("huge numbers", "1 4 1e40 -1e40 3e38 1 0 0 0 1 0 0 0 1 3001.dat"),
			("nan and inf", "1 4 nan inf -inf 1 0 0 0 1 0 0 0 1 3001.dat"),
			("non-ASCII name", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 brïck😀.dat"),
			("name with spaces and tabs", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 \tmy  part name.dat \t"),
			("tabs between fields", "1\t4\t0\t0\t0\t1\t0\t0\t0\t1\t0\t0\t0\t1\t3001.dat"),
			("non-numeric colour", "1 red 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"),
			("direct colour", "1 0x2FF8000 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"),
			("huge colour code", "1 99999999999999999999 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"),
			("missing library part", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 nosuchpart.dat"),
			("DOS sub-path", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 s\\nosuch.dat"),
			("leading whitespace", "   1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"),
			("wrong line type", "2 4 0 0 0 1 0 0"),
			("empty line", ""),
			("line type 1.5", "1.5 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"),
		]
		var out: [String] = []
		for (name, line) in cases {
			let part = try ObjC.run { P6bPart.make(line) }
			let detail = part.map { "display \($0.displayName().debugDescription) reference \($0.referenceName().debugDescription) missing \($0.partIsMissing())" } ?? ""
			out.append("\(name): \(P6bPart.write(part).debugDescription) \(detail)")
		}
		let expected: [String] = [
			"good: \"1 4 1 2 3 1 0 0 0 1 0 0 0 1 3001.dat\" display Optional(\"3001.dat\") reference Optional(\"3001.dat\") missing false",
			"bare line type: \"1 0 0 0 0 0 0 0 0 0 0 0 0 0 \" display Optional(\"\") reference Optional(\"\") missing true",
			"colour only: \"1 4 0 0 0 0 0 0 0 0 0 0 0 0 \" display Optional(\"\") reference Optional(\"\") missing true",
			"truncated position: \"1 4 0 0 0 0 0 0 0 0 0 0 0 0 \" display Optional(\"\") reference Optional(\"\") missing true",
			"no name: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 \" display Optional(\"\") reference Optional(\"\") missing true",
			"no name, trailing spaces: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 \" display Optional(\"\") reference Optional(\"\") missing true",
			"non-numeric fields: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\" display Optional(\"3001.dat\") reference Optional(\"3001.dat\") missing false",
			"huge numbers: \"1 4 inf -inf 300000000549775 1 0 0 0 1 0 0 0 1 3001.dat\" display Optional(\"3001.dat\") reference Optional(\"3001.dat\") missing false",
			"nan and inf: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\" display Optional(\"3001.dat\") reference Optional(\"3001.dat\") missing false",
			"non-ASCII name: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 brïck😀.dat\" display Optional(\"brïck😀.dat\") reference Optional(\"brïck😀.dat\") missing true",
			"name with spaces and tabs: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 my  part name.dat\" display Optional(\"my  part name.dat\") reference Optional(\"my  part name.dat\") missing true",
			"tabs between fields: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\" display Optional(\"3001.dat\") reference Optional(\"3001.dat\") missing false",
			"non-numeric colour: \"1 0 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\" display Optional(\"3001.dat\") reference Optional(\"3001.dat\") missing false",
			"direct colour: \"1 0x2FF8000 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\" display Optional(\"3001.dat\") reference Optional(\"3001.dat\") missing false",
			"huge colour code: \"1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\" display Optional(\"3001.dat\") reference Optional(\"3001.dat\") missing false",
			"missing library part: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 nosuchpart.dat\" display Optional(\"nosuchpart.dat\") reference Optional(\"nosuchpart.dat\") missing true",
			"DOS sub-path: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 s\\\\nosuch.dat\" display Optional(\"s\\\\nosuch.dat\") reference Optional(\"s\\\\nosuch.dat\") missing true",
			"leading whitespace: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\" display Optional(\"3001.dat\") reference Optional(\"3001.dat\") missing false",
			"wrong line type: \"<nil>\" ",
			"empty line: \"<nil>\" ",
			"line type 1.5: \"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\" display Optional(\"3001.dat\") reference Optional(\"3001.dat\") missing false",
		]
		#expect(out == expected, "\(out.joined(separator: "\n"))")
		// No lines at all: nil (the ObjC messaged nil and logged the failure).
		#expect(LDrawPart(lines: nil, in: NSRange(location: 0, length: 1), parentGroup: nil) == nil)
		#expect(LDrawPart(lines: ldrawLines(["1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"]), in: NSRange(location: 0, length: 1)) != nil)
	}

	@Test("Parsing a reference to a library file: a malformed one fails the part; an empty, unreadable or directory one is just missing")
	func libraryFileCases() throws {
		let library = try #require(FixtureLibrary.current)
		let bad = P6bPart.uniqueName("rotstep")
		try P6bPart.writePart(bad, "0 Bad\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 ROTSTEP x y\n")
		let good = P6bPart.uniqueName("good")
		try P6bPart.writePart(good, "0 Good\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
		let empty = P6bPart.uniqueName("empty")
		try P6bPart.writePart(empty, "")
		let unreadable = P6bPart.uniqueName("unreadable")
		try P6bPart.writePart(unreadable, "0 Unreadable\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
		let unreadableURL = library.appendingPathComponent("parts/\(unreadable)")
		try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: unreadableURL.path)
		defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: unreadableURL.path) }
		let folder = "p6b-dir-\(UUID().uuidString.prefix(8))".lowercased()
		try FileManager.default.createDirectory(at: library.appendingPathComponent("parts/\(folder)"), withIntermediateDirectories: false)
		let latin1 = P6bPart.uniqueName("latin1")
		try Data("0 Caf\u{E9}\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n".data(using: .isoLatin1)!).write(to: library.appendingPathComponent("parts/\(latin1)"))

		#expect(try ObjC.run { P6bPart.make("1 4 0 0 0 1 0 0 0 1 0 0 0 1 \(bad)") } == nil)
		// Upper case in the file finds the same (lower-cased) reference.
		let upper = try #require(try ObjC.run { P6bPart.make("1 4 0 0 0 1 0 0 0 1 0 0 0 1 \(good.uppercased())") })
		#expect(upper.displayName() == good.uppercased() && upper.referenceName() == good)
		#expect(!upper.partIsMissing())
		for name in [empty, unreadable, folder] {
			let part = try #require(try ObjC.run { P6bPart.make("1 4 0 0 0 1 0 0 0 1 0 0 0 1 \(name)") }, "\(name)")
			#expect(part.referenceName() == name)
			#expect(part.partIsMissing(), "\(name)")
		}
		let latin = try #require(try ObjC.run { P6bPart.make("1 4 0 0 0 1 0 0 0 1 0 0 0 1 \(latin1)") })
		#expect(!latin.partIsMissing())
	}

	@Test("Every malformed-input case of the parser robustness suite, as the contents of a referenced library part")
	func robustnessCasesAsLibraryParts() throws {
		// -[LDrawPart initWithLines:] parses the referenced library file (-[PartLibrary loadModelForName:inGroup:]),
		// so its catch-all @try covered the whole parser. Each case (except the known crashers) gives a part or nil.
		var out: [String] = []
		for c in Robustness.cases where !Robustness.crashing.contains(c.name) {
			let name = P6bPart.uniqueName("case")
			try P6bPart.writePart(name, c.input)
			let part = try ObjC.run { P6bPart.make("1 16 0 0 0 1 0 0 0 1 0 0 0 1 \(name)") }
			out.append("\(c.name): \(part.map { "part, missing \($0.partIsMissing())" } ?? "nil")")
		}
		let expected: [String] = [
			"empty file: part, missing true",
			"whitespace only: part, missing false",
			"single 0: part, missing false",
			"leading whitespace before line type: part, missing false",
			"lower-case step: part, missing false",
			"type 1 missing part name: part, missing false",
			"type 1 with too few fields: part, missing false",
			"type 1 non-numeric fields: part, missing false",
			"type 1 extra fields (part name with spaces): part, missing false",
			"type 2 truncated (S2): part, missing false",
			"type 3 truncated: part, missing false",
			"type 4 truncated: part, missing false",
			"type 5 truncated: part, missing false",
			"type 2 bare: part, missing false",
			"colour code non-numeric: part, missing false",
			"negative colour code: part, missing false",
			"malformed !COLOUR missing CODE value (S1): part, missing false",
			"malformed !COLOUR missing VALUE (S1): part, missing false",
			"malformed !COLOUR bad hex: part, missing false",
			"0 FILE without name: part, missing false",
			"MPD missing NOFILE: part, missing false",
			"MPD reference to missing submodel: part, missing false",
			"TEXMAP START without END: part, missing false",
			"SYNTH BEGIN without END: part, missing false",
			"very long comment line: part, missing false",
			"NUL byte in comment: part, missing false",
		]
		#expect(out == expected, "\(out.joined(separator: "\n"))")
	}

	@Test("Names use NSString semantics: -lowercaseString (final sigma) and a literal compare in containsReferenceTo:")
	func nameSemantics() throws {
		let part = LDrawPart()
		part.setDisplayName("ΣΑΣ.DAT")
		#expect(part.referenceName() == "σας.dat", "\(part.referenceName().debugDescription)")
		let precomposed = "caf\u{E9}.dat", decomposed = "cafe\u{301}.dat"
		part.setDisplayName(precomposed)
		#expect(part.containsReference(to: precomposed))
		#expect(!part.containsReference(to: decomposed), "isEqualToString: does not normalise")
		#expect(!part.containsReference(to: nil))
		// A nil name: written as "(null)", no reference matches, and the browsing description is nil.
		part.setDisplayName(nil)
		#expect(part.displayName() == nil && part.referenceName() == nil)
		#expect(P6bPart.write(part).hasSuffix(" (null)"), "\(P6bPart.write(part))")
		#expect(!part.containsReference(to: "") && !part.containsReference(to: nil))
		#expect(part.browsingDescription() == nil)
	}

	@Test("A fresh part, its icon, inspector and class defaults")
	func defaults() throws {
		let part = LDrawPart()
		#expect(part.displayName() == "" && part.referenceName() == "")
		#expect(part.iconName() == "Brick" && LDrawPart.defaultIconName() == "Brick")
		#expect(part.inspectorClassName() == "InspectionPart")
		#expect(P6bPart.write(part) == "1 0 0 0 0 1 0 0 0 1 0 -0 0 1 ", "IdentityComponents give a -0")
		#expect(part.partIsMissing())
		#expect(V3EqualBoxes(part.boundingBox3(), InvalidBox) != 0)
		#expect(part.containsReference(to: "") && !part.containsReference(to: "3001.dat"))
		part.setDisplayName("3001.DAT")
		#expect(part.containsReference(to: "3001.dat") && !part.containsReference(to: "3001.DAT"))
		#expect(part.browsingDescription() == PartLibrary.shared().description(for: part))
	}

	@Test("Archiving: keys, name, icon and matrix survive; copying keeps name and matrix but not the icon")
	func archiveAndCopy() throws {
		let part = try #require(P6bPart.make("1 4 1 2 3 0 0 1 0 1 0 -1 0 0 3001.dat"))
		part.setIconName("LSynthConstraint")
		let data = ObjectModel.archive(part)
		let keys = try P6bPart.archivedKeys(data, className: "LDrawPart")
		#expect(keys == ["color", "displayName", "enclosingDirective", "glTransformation", "hidden", "iconName"], "\(keys)")
		let decoded = try #require(try ObjectModel.unarchive(data) as? LDrawPart)
		#expect(P6bPart.write(decoded) == P6bPart.write(part))
		#expect(decoded.iconName() == "LSynthConstraint")
		#expect(!decoded.partIsMissing())
		let copied = try #require(part.copy() as? LDrawPart)
		#expect(P6bPart.write(copied) == P6bPart.write(part))
		#expect(copied.iconName() == "Brick", "copies start from -init, which sets the default icon")
		#expect(!copied.partIsMissing())
		let m = copied.transformationMatrix()
		#expect(M4.rows(m) == M4.rows(part.transformationMatrix()))
	}

	@Test("Drawing a part: colour push (none for 16, complement for 24, RGBA otherwise), wireframe when selected, nothing when hidden or missing")
	func drawSelf() throws {
		func draw(_ line: String, selected: Bool = false, hidden: Bool = false) throws -> [String] {
			let part = try PartFactory.part(line)
			part.setHidden(hidden)
			if selected { try ObjC.run { part.setSelected(true) } }
			let r = RecordingRenderer()
			try ObjC.run { part.drawSelf(r) }
			return r.log.filter { !$0.hasPrefix(" ") }
		}
		let current = try draw("1 16 1 2 3 1 0 0 0 1 0 0 0 1 3024.dat")
		#expect(current.first == "pushMatrix [1 0 0 0 0 1 0 0 0 0 1 0 1 2 3 1]" && current.last == "popMatrix", "\(current)")
		let edge = try draw("1 24 0 0 0 1 0 0 0 1 0 0 0 1 3024.dat")
		#expect(edge.first == "pushColor complement" && edge.last == "popColor", "\(edge)")
		let red = try draw("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3024.dat")
		#expect(red.first?.hasPrefix("pushColor rgba(") == true && red.last == "popColor", "\(red)")
		let selected = try draw("1 16 0 0 0 1 0 0 0 1 0 0 0 1 3024.dat", selected: true)
		#expect(selected.first == "pushWireFrame" && selected.last == "popWireFrame", "\(selected)")
		#expect(try draw("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3024.dat", hidden: true).isEmpty)
		#expect(try draw("1 4 0 0 0 1 0 0 0 1 0 0 0 1 nosuchpart.dat").isEmpty)
	}

	@Test("Resolution: library, MPD submodel (observed), peer file (observed), not found; renaming, losing and adding the target")
	func resolution() throws {
		let text = "0 FILE main.ldr\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 sub.ldr\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 later.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 main.ldr\n0 NOFILE\n0 FILE sub.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 NOFILE\n"
		let file = try #require(RoundTrip.load(Data(text.utf8)))
		let parts = ObjectModel.all(file).compactMap { $0 as? LDrawPart }
		let (toSub, toLater, toLibrary, toSelf) = (parts[0], parts[1], parts[2], parts[3])
		#expect(toSub.referencedMPDSubmodel() != nil && !toSub.partIsMissing())
		#expect(toSub.referencedPeerFile() == nil && toLibrary.referencedPeerFile() == nil)
		#expect(toLibrary.referencedMPDSubmodel() == nil && !toLibrary.partIsMissing())
		#expect(toSelf.referencedMPDSubmodel() == nil, "a reference to the enclosing model is refused")
		#expect(toSelf.partIsMissing() && toLater.partIsMissing())

		// Bounds of a submodel reference follow edits to the submodel (statusInvalidated:).
		let sub = try #require(file.model(withName: "sub.ldr"))
		let before = toSub.boundingBox3()
		let subStep = try #require(sub.steps().first as? LDrawStep)
		let extra = try PartFactory.part("1 4 0 -100 0 1 0 0 0 1 0 0 0 1 3001.dat")
		try ObjC.run { subStep.add(extra as LDrawDirective) }
		let after = toSub.boundingBox3()
		#expect(after.min.y < before.min.y, "before \(before.min.y) after \(after.min.y)")

		// Adding a submodel the part was missing resolves it (LDrawMPDSubModelAdded).
		let later = LDrawMPDModel()
		later.setModelName("later.ldr")
		try ObjC.run { file.addSubmodel(later) }
		#expect(!toLater.partIsMissing())

		// Collecting a part report through a submodel reference reports the submodel's parts (now two).
		let report = try #require(PartReport(for: nil))
		try ObjC.run { toSub.collect(report); toLibrary.collect(report); toSelf.collect(report) }
		#expect(report.numberOfParts() == 3, "\(report.numberOfParts())")

		// Renaming the submodel unresolves the part (MessageNameChanged); it is then missing. A missing part
		// listens only for added models, so renaming the model back doesn't find it again; unresolving does.
		try ObjC.run { sub.setModelName("renamed.ldr") }
		#expect(toSub.partIsMissing())
		try ObjC.run { sub.setModelName("sub.ldr") }
		#expect(toSub.partIsMissing())
		try ObjC.run { toSub.unresolvePartIfPartLibrary() }
		#expect(!toSub.partIsMissing())

		// Moving the part to another file re-resolves there.
		let other = try #require(RoundTrip.load(Data("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n".utf8)))
		let otherStep = try #require(other.activeModel().steps().first as? LDrawStep)
		try ObjC.run { toSub.enclosingDirective().remove(toSub as LDrawDirective); otherStep.add(toSub as LDrawDirective) }
		#expect(toSub.partIsMissing())
	}

	@Test("Goodbye from an observed model unresolves the part (it resolves again on the next query); a stray goodbye only logs")
	func observedModelGoodbye() throws {
		let file = try #require(RoundTrip.load(Data("0 FILE main.ldr\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 sub.ldr\n0 NOFILE\n0 FILE sub.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 NOFILE\n".utf8)))
		let part = try #require(ObjectModel.all(file).compactMap { $0 as? LDrawPart }.first)
		let sub = try #require(file.model(withName: "sub.ldr"))
		#expect(!part.partIsMissing())
		// The model's own -dealloc sends this; here it is sent directly (the tree would unresolve the part first).
		let recorder = ObserverRecorder(label: "other")
		sub.add(recorder)
		try ObjC.run { part.observableSaysGoodbyeCruelWorld(sub) }
		// Unresolved: the part no longer observes the model, so a rename reaches only the other observer.
		try ObjC.run { sub.setModelName("renamed.ldr") }
		#expect(recorder.log == ["other: message 0 from LDrawMPDModel"], "\(recorder.log)")
		sub.remove(recorder as LDrawObserver)
		#expect(part.partIsMissing())
		// Not resolved, and not from its model: both warnings are logged; nothing else happens.
		let stray = LDrawPart()
		try ObjC.run { stray.observableSaysGoodbyeCruelWorld(sub) }
		#expect(stray.partIsMissing())
	}

	@Test("Peer files: a part resolves to a file next to its document; part reports go through it")
	func peerFile() throws {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent("BricksmithTests-p6b-peer-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: dir) }
		let a = dir.appendingPathComponent("a.ldr"), b = dir.appendingPathComponent("b.ldr")
		try Data("0 Peer A\r\n0 Name: a.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n".utf8).write(to: a)
		try Data("0 Peer B\r\n0 Name: b.ldr\r\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 a.ldr\r\n".utf8).write(to: b)
		let fileB = try #require(RoundTrip.load(try Data(contentsOf: b)))
		fileB.setPath(b.path)
		let manager = ModelManager.shared()
		manager.documentSign(in: b.path, with: fileB)
		defer { manager.documentSignOut(fileB) }
		let part = try #require(ObjectModel.all(fileB).compactMap { $0 as? LDrawPart }.first)
		let peer = try #require(part.referencedPeerFile())
		#expect(peer.write()?.contains("3001.dat") == true)
		#expect(!part.partIsMissing() && part.referencedMPDSubmodel() == nil)
		let report = try #require(PartReport(for: nil))
		try ObjC.run { part.collect(report) }
		#expect(report.numberOfParts() == 2)
		// Signing the document out tells the peer's observers its scope changed: the part unresolves.
		manager.documentSignOut(fileB)
		#expect(part.partIsMissing())
	}

	@Test("Snapping a part whose up axis points along Z uses the stud-height grid on Z")
	func snapAlongZ() throws {
		let part = try PartFactory.part("1 4 30 30 30 1 0 0 0 0 -1 0 1 0 3001.dat")
		let snapped = part.componentsSnapped(toGrid: 20, minimumAngle: 0)
		#expect(P6a.p(snapped.translate) == "(40, 40, 24)", "\(P6a.p(snapped.translate))")
	}

	@Test("followRedirectionAndUpdate does nothing when the library file uses two parts")
	func redirectionAmbiguous() throws {
		let name = P6bPart.uniqueName("two")
		try P6bPart.writePart(name, "0 Two parts\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 16 0 8 0 1 0 0 0 1 0 0 0 1 3024.dat\n")
		let part = try #require(try ObjC.run { P6bPart.make("1 4 1 2 3 1 0 0 0 1 0 0 0 1 \(name)") })
		let before = P6bPart.write(part)
		try ObjC.run { part.followRedirectionAndUpdate() }
		#expect(P6bPart.write(part) == before)
		let missing = try #require(P6bPart.make("1 4 1 2 3 1 0 0 0 1 0 0 0 1 nosuchpart.dat"))
		try ObjC.run { missing.followRedirectionAndUpdate() }
		#expect(P6bPart.write(missing) == "1 4 1 2 3 1 0 0 0 1 0 0 0 1 nosuchpart.dat")
	}

	@Test("Flattening: non-recursive flattening ignores parts; unresolve-if-library only touches library and missing parts")
	func flattenAndUnresolve() throws {
		let part = try PartFactory.part("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat")
		let lines = NSMutableArray(), tris = NSMutableArray(), quads = NSMutableArray(), other = NSMutableArray()
		try ObjC.run {
			part.flatten(intoLines: lines, triangles: tris, quadrilaterals: quads, other: other, currentColor: nil,
						 currentTransform: IdentityMatrix4, normalTransform: Matrix3MakeNormalTransformFromProjMatrix(IdentityMatrix4), recursive: false)
		}
		#expect(lines.count + tris.count + quads.count + other.count == 0)
		try ObjC.run {
			part.flatten(intoLines: lines, triangles: tris, quadrilaterals: quads, other: other, currentColor: nil,
						 currentTransform: IdentityMatrix4, normalTransform: Matrix3MakeNormalTransformFromProjMatrix(IdentityMatrix4), recursive: true)
		}
		#expect(tris.count + quads.count > 0)
		#expect(P6bPart.write(part) == "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "flattening a part doesn't change it")
		#expect(!part.partIsMissing())
		try ObjC.run { part.unresolvePartIfPartLibrary(); part.unresolvePart(); part.unresolvePart() }
		#expect(!part.partIsMissing())
	}
}

// MARK: - P6c pins: LDrawContainer

enum P6cContainer {
	static func children(_ c: LDrawContainer) -> [LDrawDirective] { (c.subdirectives() as? [LDrawDirective]) ?? [] }
	static func same(_ a: [LDrawDirective], _ b: [LDrawDirective]) -> Bool {
		a.count == b.count && zip(a, b).allSatisfy { $0 === $1 }
	}
	static func line(_ text: String) throws -> LDrawLine {
		try #require(LDrawLine(lines: ldrawLines([text]), in: NSRange(location: 0, length: 1)))
	}
	/// Counts LDrawDirectiveDidChangeNotification posts for one object.
	final class ChangeCounter {
		var count = 0
		private var token: NSObjectProtocol?
		init(_ object: AnyObject) {
			token = NotificationCenter.default.addObserver(forName: NSNotification.Name("LDrawDirectiveDidChangeNotification"),
														   object: object, queue: nil) { [unowned self] _ in self.count += 1 }
		}
		deinit { token.map(NotificationCenter.default.removeObserver) }
	}
}

@Suite("LDrawContainer (P6c pins)", .fixtureLibrary, .serialized)
struct P6cContainerPinTests {

	@Test("Insert, add and remove at indices: order, parent links, indexOfDirective:, and out-of-range or nil leaving everything unchanged")
	func insertAndRemove() throws {
		let c = LDrawContainer()
		let a = LDrawDirective(), b = LDrawDirective(), d = LDrawDirective(), stranger = LDrawDirective()
		#expect(c.subdirectives()?.count == 0)
		#expect(!c.postsNotifications)
		c.add(a)
		c.add(d)
		c.insert(b, at: 1)
		#expect(P6cContainer.same(P6cContainer.children(c), [a, b, d]))
		#expect([a, b, d].allSatisfy { $0.enclosingDirective() === c })
		#expect(c.index(of: a) == 0 && c.index(of: b) == 1 && c.index(of: d) == 2)
		#expect(c.index(of: stranger) == NSNotFound)
		#expect(c.index(of: nil) == NSNotFound)

		// Removing a directive that isn't there does nothing.
		c.remove(stranger as LDrawDirective)
		#expect(P6cContainer.same(P6cContainer.children(c), [a, b, d]))

		c.remove(b as LDrawDirective)
		#expect(P6cContainer.same(P6cContainer.children(c), [a, d]))
		#expect(b.enclosingDirective() == nil)

		// A child whose parent was changed elsewhere keeps that parent when removed.
		let other = LDrawContainer()
		d.setEnclosing(other)
		c.removeDirective(at: 1)
		#expect(P6cContainer.same(P6cContainer.children(c), [a]))
		#expect(d.enclosingDirective() === other)

		// Out of range or nil: the ObjC raised before changing anything; nothing changes either way.
		for index in [-1, 2, 99] {
			_ = try? ObjC.run { c.insert(stranger, at: index) }
			#expect(P6cContainer.same(P6cContainer.children(c), [a]), "insert at \(index)")
			#expect(stranger.enclosingDirective() == nil, "insert at \(index)")
		}
		_ = try? ObjC.run { c.insert(nil, at: 0) }
		_ = try? ObjC.run { c.add(nil as LDrawDirective?) }
		#expect(P6cContainer.same(P6cContainer.children(c), [a]))
		for index in [-1, 1, 99] {
			_ = try? ObjC.run { c.removeDirective(at: index) }
			#expect(P6cContainer.same(P6cContainer.children(c), [a]), "remove at \(index)")
		}
		#expect(a.enclosingDirective() === c)
		// subdirectives is the live array.
		#expect(c.subdirectives() === c.subdirectives())
	}

	@Test("Children are observed while contained: their invalidations reach the container's observers, and stop after removal")
	func childObservation() throws {
		let c = LDrawContainer()
		let child = LDrawDirective()
		let recorder = ObserverRecorder(label: "c")
		c.add(recorder)
		defer { c.remove(recorder as LDrawObserver) }
		c.add(child)
		child.invalCache(.DisplayList)
		#expect(recorder.log == ["c: statusInvalidated flags=2 from LDrawContainer"], "\(recorder.log)")

		recorder.log.removeAll()
		_ = child.revalCache([.CacheFlagBounds, .DisplayList])
		_ = c.revalCache([.CacheFlagBounds, .DisplayList])
		child.sendMessage(toObservers: .observedChanged)
		#expect(recorder.log.isEmpty, "receiveMessage:who: does nothing: \(recorder.log)")

		c.remove(child as LDrawDirective)
		_ = child.revalCache([.CacheFlagBounds, .DisplayList])
		_ = c.revalCache([.CacheFlagBounds, .DisplayList])
		child.invalCache(.CacheFlagBounds)
		#expect(recorder.log.isEmpty, "\(recorder.log)")
	}

	@Test("The observer messages: statusInvalidated: invalidates the container with the same flags; receiveMessage: and a goodbye do nothing")
	func observerMessages() throws {
		let c = LDrawContainer()
		let child = LDrawDirective()
		c.add(child)
		let recorder = ObserverRecorder(label: "c")
		c.add(recorder)
		defer { c.remove(recorder as LDrawObserver) }
		try ObjC.run { c.statusInvalidated([.CacheFlagBounds, .DisplayList], who: nil) }
		#expect(recorder.log == ["c: statusInvalidated flags=3 from LDrawContainer"], "\(recorder.log)")
		recorder.log.removeAll()
		try ObjC.run {
			c.receiveMessage(.nameChanged, who: child)
			c.receiveMessage(.observedChanged, who: nil)
			// A contained child saying goodbye only logs; a stranger or nil is ignored.
			c.observableSaysGoodbyeCruelWorld(child)
			c.observableSaysGoodbyeCruelWorld(LDrawDirective())
			c.observableSaysGoodbyeCruelWorld(nil)
		}
		#expect(recorder.log.isEmpty, "\(recorder.log)")
		#expect(P6cContainer.same(P6cContainer.children(c), [child]))
		#expect(child.enclosingDirective() === c)
	}

	@Test("postsNotifications: the setter reaches children that respond to it (recursively); an inserted container takes the parent's setting; insert and remove post only while it is on")
	func postsNotifications() throws {
		let c = LDrawContainer()
		let step = try #require(LDrawStep.empty() as? LDrawStep)
		let inner = try #require(LDrawStep.empty() as? LDrawStep)
		let plain = LDrawDirective()
		step.add(inner as LDrawDirective)
		c.add(step as LDrawDirective)
		c.add(plain)
		c.setPostsNotifications(true)
		#expect(c.postsNotifications && step.postsNotifications && inner.postsNotifications)

		// An inserted container is switched to the parent's setting, in either direction.
		let off = try #require(LDrawStep.empty() as? LDrawStep)
		c.add(off as LDrawDirective)
		#expect(off.postsNotifications)
		let c2 = LDrawContainer()
		let on = try #require(LDrawStep.empty() as? LDrawStep)
		on.setPostsNotifications(true)
		c2.add(on as LDrawDirective)
		#expect(!on.postsNotifications)

		// Notifications from insert and remove.
		let counter = P6cContainer.ChangeCounter(c)
		c.add(LDrawDirective())
		c.removeDirective(at: 3)
		#expect(counter.count == 2)
		c.setPostsNotifications(false)
		#expect(!step.postsNotifications && !inner.postsNotifications && !off.postsNotifications)
		c.add(LDrawDirective())
		c.removeDirective(at: 3)
		#expect(counter.count == 2)
	}

	@Test("allEnclosedElements flattens nested containers (not the containers themselves), in order")
	func allEnclosedElements() throws {
		let c = LDrawContainer()
		let a = LDrawDirective(), b = LDrawDirective(), d = LDrawDirective(), e = LDrawDirective()
		let step = try #require(LDrawStep.empty() as? LDrawStep)
		let inner = LDrawContainer()
		let empty = LDrawContainer()
		inner.add(d)
		step.add(b)
		step.add(inner as LDrawDirective)
		c.add(a)
		c.add(step as LDrawDirective)
		c.add(empty as LDrawDirective)
		c.add(e)
		let all = try #require(c.allEnclosedElements() as? [LDrawDirective])
		#expect(P6cContainer.same(all, [a, b, d, e]))
		#expect(LDrawContainer().allEnclosedElements()?.count == 0)
	}

	@Test("Drop and selection hooks: acceptsDroppedDirective: is YES for anything; setSubdirectiveSelected: changes nothing")
	func hooks() throws {
		let c = LDrawContainer()
		#expect(c.acceptsDroppedDirective(LDrawDirective()))
		#expect(c.acceptsDroppedDirective(LDrawContainer()))
		#expect(c.acceptsDroppedDirective(nil))
		c.add(LDrawDirective())
		c.setSubdirectiveSelected(true)
		#expect(!c.isSelected() && !(P6cContainer.children(c)[0].isSelected()))
		c.setSubdirectiveSelected(false)
	}

	@Test("projectedBoundingBox: the union over children that respond to it; InvalidBox when empty")
	func projectedBoundingBox() throws {
		let l1 = try P6cContainer.line("2 4 0 0 0 10 20 30")
		let l2 = try P6cContainer.line("2 4 -5 7 1 3 3 3")
		let view = V2MakeBox(0, 0, 200, 100)
		var mv = IdentityMatrix4
		mv.element.0.0 = 0.5
		let proj = IdentityMatrix4
		let c = LDrawContainer()
		#expect(V3EqualBoxes(c.projectedBoundingBox(withModelView: mv, projection: proj, view: view), InvalidBox) != 0)
		c.add(LDrawDirective())
		#expect(V3EqualBoxes(c.projectedBoundingBox(withModelView: mv, projection: proj, view: view), InvalidBox) != 0)
		c.add(l1)
		c.add(l2)
		let step = try #require(LDrawStep.empty() as? LDrawStep)
		let l3 = try P6cContainer.line("2 4 100 100 100 101 101 101")
		step.add(l3)
		c.add(step as LDrawDirective)
		let expected = [l1, l2, l3].reduce(InvalidBox) {
			V3UnionBox($0, $1.projectedBoundingBox(withModelView: mv, projection: proj, view: view))
		}
		let got = c.projectedBoundingBox(withModelView: mv, projection: proj, view: view)
		#expect(V3EqualBoxes(got, expected) != 0)
		#expect(V3EqualBoxes(got, InvalidBox) == 0)
	}

	@Test("collectPartReport: and applyToAllParts: reach every part, nested, in order; other children are skipped")
	func partVisits() throws {
		let p1 = try PartFactory.part("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat")
		let p2 = try PartFactory.part("1 1 0 0 0 1 0 0 0 1 0 0 0 1 3024.dat")
		let p3 = try PartFactory.part("1 2 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat")
		let c = LDrawContainer()
		let step = try #require(LDrawStep.empty() as? LDrawStep)
		step.add(p2 as LDrawDirective)
		c.add(p1 as LDrawDirective)
		c.add(LDrawDirective())
		c.add(try P6cContainer.line("2 4 0 0 0 1 1 1"))
		c.add(step as LDrawDirective)
		c.add(p3 as LDrawDirective)
		let report = try #require(PartReport(for: nil))
		try ObjC.run { c.collect(report) }
		#expect(report.numberOfParts() == 3)
		var visited: [LDrawPart] = []
		try ObjC.run { c.apply(toAllParts: { visited.append($0) }) }
		#expect(visited.count == 3 && visited[0] === p1 && visited[1] === p2 && visited[2] === p3)
		// containsReferenceTo: asks each child (nested too) and stops at the first YES.
		#expect(c.containsReference(to: "3024.dat"))
		#expect(c.containsReference(to: "3001.dat"))
		#expect(!c.containsReference(to: "nosuch.dat"))
		#expect(!c.containsReference(to: nil))
	}

	@Test("Archiving: containedObjects plus the inherited enclosingDirective; children decode in order, parented and observed; postsNotifications isn't archived")
	func archiving() throws {
		let c = LDrawContainer()
		let a = try P6cContainer.line("2 4 0 0 0 1 1 1")
		let b = try P6cContainer.line("2 1 0 0 0 2 2 2")
		c.add(a)
		c.add(b)
		c.setPostsNotifications(true)
		let data = ObjectModel.archive(c)
		let keys = try P6bPart.archivedKeys(data, className: "LDrawContainer")
		#expect(keys == ["containedObjects", "enclosingDirective"], "\(keys)")
		let decoded = try #require(try ObjectModel.unarchive(data) as? LDrawContainer)
		#expect(!decoded.postsNotifications)
		let kids = P6cContainer.children(decoded)
		#expect(kids.map { $0.write() ?? "" } == [a.write() ?? "", b.write() ?? ""])
		#expect(kids.allSatisfy { $0.enclosingDirective() === decoded })
		#expect(decoded.subdirectives() is NSMutableArray)
		decoded.add(LDrawDirective())
		#expect(decoded.subdirectives()?.count == 3)
		let recorder = ObserverRecorder(label: "d")
		decoded.add(recorder)
		defer { decoded.remove(recorder as LDrawObserver) }
		_ = kids[0].revalCache([.CacheFlagBounds, .DisplayList])
		_ = decoded.revalCache([.CacheFlagBounds, .DisplayList])
		kids[0].invalCache(.DisplayList)
		#expect(recorder.log == ["d: statusInvalidated flags=2 from LDrawContainer"], "\(recorder.log)")
	}

	@Test("copy: children are copied (new objects, parented and observed by the copy); postsNotifications and selection")
	func copying() throws {
		let c = LDrawContainer()
		let a = try P6cContainer.line("2 4 0 0 0 1 1 1")
		c.add(a)
		c.setPostsNotifications(true)
		c.setSelected(true)
		let copy = try #require(c.copy() as? LDrawContainer)
		#expect(!copy.postsNotifications)
		#expect(copy.isSelected())
		let kids = P6cContainer.children(copy)
		#expect(kids.count == 1 && kids[0] !== a && kids[0].write() == a.write())
		#expect(kids[0].enclosingDirective() === copy)
		#expect(a.enclosingDirective() === c)
		let recorder = ObserverRecorder(label: "copy")
		copy.add(recorder)
		defer { copy.remove(recorder as LDrawObserver) }
		_ = kids[0].revalCache([.CacheFlagBounds, .DisplayList])
		_ = copy.revalCache([.CacheFlagBounds, .DisplayList])
		kids[0].invalCache(.DisplayList)
		#expect(recorder.log == ["copy: statusInvalidated flags=2 from LDrawContainer"], "\(recorder.log)")

		// Several children: copied in reverse (BUG-011).
		let three = LDrawContainer()
		let lines = try ["2 1 0 0 0 1 1 1", "2 2 0 0 0 1 1 1", "2 3 0 0 0 1 1 1"].map(P6cContainer.line)
		lines.forEach { three.add($0) }
		let threeCopy = try #require(three.copy() as? LDrawContainer)
		let written = P6cContainer.children(threeCopy).map { $0.write() ?? "" }
		#expect(Set(written) == Set(lines.map { $0.write() ?? "" }))
		withKnownIssue("BUG-011: -[LDrawContainer copyWithZone:] inserts every copy at index 0, reversing the children") {
			#expect(written == lines.map { $0.write() ?? "" })
		}
	}

	@Test("Dealloc: children outliving the container are unparented and no longer observed; the container's observers get a goodbye")
	func deallocation() throws {
		let child = LDrawDirective()
		let recorder = ObserverRecorder(label: "obs")
		weak var weakContainer: LDrawContainer?
		autoreleasepool {
			let c = LDrawContainer()
			weakContainer = c
			c.add(child)
			c.add(recorder)
			#expect(child.enclosingDirective() === c)
		}
		#expect(weakContainer == nil)
		#expect(recorder.log == ["obs: goodbye from LDrawContainer"], "\(recorder.log)")
		#expect(child.enclosingDirective() == nil)
		// Invalidating the surviving child must not message the freed container.
		_ = child.revalCache([.CacheFlagBounds, .DisplayList])
		child.invalCache([.CacheFlagBounds, .DisplayList])
		child.sendMessage(toObservers: .nameChanged)
	}
}
