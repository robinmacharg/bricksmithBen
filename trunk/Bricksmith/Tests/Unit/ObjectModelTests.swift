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
