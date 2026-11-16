//
//  ColourTests.swift
//  BricksmithTests
//
//  P2 row 7: ColorLibrary, !COLOUR definitions, blended colours (against the LDraw spec), and the
//  colour format stored in preferences (non-keyed NSArchiver, read AND write).
//
//  Goldens: Fixtures/golden/colours/library.tsv, Fixtures/golden/colours/colour-lines.txt
//

import AppKit
import Foundation
import Testing
@testable import Bricksmith

enum Colour {
	static func rgba(_ c: LDrawColor) -> [Float] {
		var v = [GLfloat](repeating: 0, count: 4); c.getRGBA(&v); return v
	}
	static func edgeRGBA(_ c: LDrawColor) -> [Float] {
		var v = [GLfloat](repeating: 0, count: 4); c.getEdgeColorRGBA(&v); return v
	}
	static func hex(_ v: [Float]) -> String { v.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined() }

	/// The 16 original ldraw.exe colours, verbatim from docs/reference/ldraw-spec/file-format.md
	/// ("Blended Colours"): "The red, green, and blue components of the original 16 ldraw.exe colours".
	static let ldrawExe: [[Float]] = [
		[51, 51, 51], [0, 51, 178], [0, 127, 51], [0, 181, 166], [204, 0, 0], [255, 51, 153], [102, 51, 0], [153, 153, 153],
		[102, 102, 88], [0, 128, 255], [51, 255, 102], [171, 253, 249], [255, 0, 0], [255, 176, 204], [255, 229, 0], [255, 255, 255],
	]
}

@Suite("Colours (P2 row 7)", .fixtureLibrary, .serialized)
struct ColourTests {

	@Test("ColorLibrary loaded from LDConfig.ldr: every colour's code, name, RGBA, edge, material, luminance")
	func libraryTable() throws {
		let library = try #require(ColorLibrary.shared())
		let colours = library.colors().sorted { $0.colorCode().rawValue < $1.colorCode().rawValue }
		var rows = ["code\tname\trgba\tedgeCode\tedgeRGBA\tmaterial\tluminance\tmaterialParameters"]
		for c in colours {
			rows.append([String(c.colorCode().rawValue), c.name() ?? "", Colour.hex(Colour.rgba(c)), String(c.edgeColorCode().rawValue),
						 Colour.hex(Colour.edgeRGBA(c)), String(c.material().rawValue), String(c.luminance()),
						 c.materialParameters() ?? ""].joined(separator: "\t"))
		}
		try Golden.check(Data((rows.joined(separator: "\n") + "\n").utf8), against: "colours/library.tsv")
	}

	@Test("!COLOUR lines covering every material keyword survive parse -> write")
	func colourLineRoundTrip() throws {
		// One line per keyword family, taken from the fixture LDConfig.ldr where present.
		let ldconfig = try String(contentsOf: FixturePaths.ldrawMini.appendingPathComponent("LDConfig.ldr"), encoding: .utf8)
		let lines = ldconfig.components(separatedBy: .newlines).filter { $0.hasPrefix("0 !COLOUR") }
		var picked: [String] = []
		for keyword in ["", "ALPHA", "LUMINANCE", "CHROME", "PEARLESCENT", "RUBBER", "MATTE_METALLIC", "METAL", "MATERIAL GLITTER", "MATERIAL SPECKLE", "FABRIC"] {
			if let line = lines.first(where: { keyword.isEmpty ? !$0.contains("ALPHA") && !$0.contains("MATERIAL") : $0.contains(keyword) }) {
				picked.append(line)
			}
		}
		#expect(picked.count >= 8, "fixture LDConfig.ldr lacks expected material variety")
		var out = ""
		for line in picked {
			let written = Robustness.roundTrip(line + "\n") ?? "<nil>"
			let colourLine = written.components(separatedBy: "\r\n").first { $0.hasPrefix("0 !COLOUR") } ?? "<missing>"
			out += "in:  \(line)\nout: \(colourLine)\n\n"
		}
		try Golden.check(Data(out.utf8), against: "colours/colour-lines.txt")
	}

	@Test("Edge colour comes from LDConfig EDGE")
	func edgeColour() throws {
		let red = try #require(ColorLibrary.shared()?.color(forCode: LDrawColorT(rawValue: 4)))
		#expect(Colour.hex(Colour.rgba(red)) == "B40000FF")
		#expect(Colour.hex(Colour.edgeRGBA(red)) == "333333FF")
	}

	@Test("Unknown colour codes fall back to colour 16 (current colour)")
	func unknownFallsBack() throws {
		let c = try #require(ColorLibrary.shared()?.color(forCode: LDrawColorT(rawValue: 4321)))
		#expect(c.colorCode() == LDrawColorT(rawValue: 16))
	}

	@Test("Blended colours (256-511) follow the LDraw spec formula", arguments: [256, 257, 300, 383, 511])
	func blendedPerSpec(code: Int32) throws {
		let c = try #require(LDrawColor.blendedColor(forCode: LDrawColorT(rawValue: code)))
		let n1 = Int((code - 256) / 16), n2 = Int((code - 256) % 16)
		let expected = (0..<3).map { (Colour.ldrawExe[n1][$0] + Colour.ldrawExe[n2][$0]) / 2 / 255 }
		let actual = Array(Colour.rgba(c).prefix(3))
		#expect(zip(actual, expected).allSatisfy { abs($0 - $1) < 1.5 / 255 },
				"code \(code): n1=\(n1) n2=\(n2) expected \(Colour.hex(expected)) actual \(Colour.hex(actual))")
	}
}

@Suite("Preferences colour format (P2 row 7)", .serialized)
struct PreferenceColourTests {

	/// A throwaway defaults domain; removed afterwards so nothing persists.
	private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
		let name = "BricksmithTests.colours.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: name)!
		defer { defaults.removePersistentDomain(forName: name) }
		try body(defaults)
	}

	@Test("setColor:forKey: writes a non-keyed NSArchiver blob, and colorForKey: reads it back")
	func writerFormatAndRoundTrip() throws {
		try withDefaults { d in
			let colour = NSColor(calibratedRed: 0.25, green: 0.5, blue: 0.75, alpha: 1)
			d.setColor(colour, forKey: "c")
			let data = try #require(d.data(forKey: "c"))
			// NSArchiver (typedstream) blobs start with 0x04 0x0B "streamtyped"; keyed archives start "bplist".
			#expect(data.prefix(13) == Data([0x04, 0x0B]) + Data("streamtyped".utf8), "writer format changed")
			let back = try #require(d.color(forKey: "c")?.usingColorSpace(.genericRGB))
			#expect(abs(back.redComponent - 0.25) < 1e-6 && abs(back.blueComponent - 0.75) < 1e-6)
		}
	}

	@Test("A committed NSArchiver colour blob (as written by this source) still decodes")
	func committedBlobDecodes() throws {
		let url = FixturePaths.fixtures.appendingPathComponent("prefs/nsarchiver-colour.bin")
		if Golden.isRecording {
			try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
			try withDefaults { d in
				d.setColor(NSColor(calibratedRed: 1, green: 0.5, blue: 0, alpha: 1), forKey: "c")
				try d.data(forKey: "c")!.write(to: url)
			}
			return
		}
		let blob = try Data(contentsOf: url)
		try withDefaults { d in
			d.set(blob, forKey: "c")
			let c = try #require(d.color(forKey: "c")?.usingColorSpace(.genericRGB))
			#expect(abs(c.redComponent - 1) < 1e-6 && abs(c.greenComponent - 0.5) < 1e-6)
		}
	}

	@Test("BUG-002: colours stored as keyed archives (as the installed Bricksmith 3.1.0 writes them) are readable")
	func bug002KeyedColour() throws {
		try withDefaults { d in
			let keyed = try NSKeyedArchiver.archivedData(withRootObject: NSColor.red, requiringSecureCoding: false)
			d.set(keyed, forKey: "c")
			withKnownIssue("BUG-002: colorForKey: only understands non-keyed NSArchiver data") {
				#expect(d.color(forKey: "c") != nil)
			}
		}
	}
}

/// P5 pins for -[NSUserDefaults setColor:forKey:] / -colorForKey: before the port to Swift: the exact bytes
/// written, and every read outcome. Writes go to UserDefaults.standard inside DefaultsSandbox (the Debug domain,
/// restored afterwards); stored blobs are read back through the volatile argument domain (restored by
/// .fixtureLibrary). Nothing touches the real defaults.
@Suite("Preferences colour category: exact bytes and edge cases (P5)", .fixtureLibrary, .serialized)
struct PreferenceColourCategoryTests {
	static let key = "BricksmithTests.P5.colour"

	/// What setColor:forKey: stores for `colour` under `key` (nil if nothing was stored).
	private func written(_ colour: NSColor?, forKey key: String? = Self.key) throws -> (Data?, [String: Any]?, [String: Any]?) {
		try DefaultsSandbox.run {
			let defaults = UserDefaults.standard
			let before = defaults.persistentDomain(forName: DefaultsSandbox.debugDomain)
			defaults.setColor(colour, forKey: key)
			let after = defaults.persistentDomain(forName: DefaultsSandbox.debugDomain)
			return (after?[Self.key] as? Data, before, after)
		}
	}

	/// colorForKey: on UserDefaults.standard, with `value` in the argument domain under `key`.
	private func read(_ value: Any) throws -> NSColor? {
		DefaultsSandbox.setArguments([Self.key: value])
		defer { DefaultsSandbox.removeArguments([Self.key]) }
		return try ObjC.run { UserDefaults.standard.color(forKey: Self.key) }
	}

	@Test("The writer's bytes equal the committed NSArchiver blob exactly")
	func writerMatchesCommittedBlob() throws {
		let blob = try Data(contentsOf: FixturePaths.fixtures.appendingPathComponent("prefs/nsarchiver-colour.bin"))
		let data = try #require(try written(NSColor(calibratedRed: 1, green: 0.5, blue: 0, alpha: 1)).0)
		#expect(data == blob, "\(data as NSData) vs \(blob as NSData)")
	}

	@Test("The writer's bytes equal +[NSArchiver archivedDataWithRootObject:] for several kinds of colour")
	func writerMatchesNSArchiver() throws {
		let colours: [NSColor] = [
			NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.3, alpha: 0.4),
			NSColor(deviceRed: 0.9, green: 0.8, blue: 0.7, alpha: 1),
			NSColor(srgbRed: 0.5, green: 0.25, blue: 0.125, alpha: 1),
			NSColor(calibratedWhite: 0.6, alpha: 1),
			NSColor(deviceCyan: 0.1, magenta: 0.2, yellow: 0.3, black: 0.4, alpha: 1),
			NSColor.red,
			NSColor.black,
			NSColor.textColor,       // a catalog colour
		]
		for colour in colours {
			let data = try #require(try written(colour).0, "\(colour)")
			let expected = ArgumentPrefs.archivedColour(colour)
			#expect(data == expected, "\(colour): \(data as NSData) vs \(expected as NSData)")
			let back = try #require(try read(data), "\(colour) read back as nil")
			#expect(ArgumentPrefs.archivedColour(back) == data, "\(colour) read back as \(back)")
		}
	}

	@Test("A nil colour stores the 20-byte NSArchiver archive of nil, which reads back as nil")
	func nilColour() throws {
		let data = try #require(try written(nil).0)
		let expected = Data([0x04, 0x0B]) + Data("streamtyped".utf8) + Data([0x81, 0xE8, 0x03, 0x84, 0x01, 0x40, 0x85])
		#expect(data == expected, "\(data as NSData)")
		#expect(try read(data) == nil)
	}

	@Test("A nil key is a silent no-op on write and gives nil on read")
	func nilKey() throws {
		let (_, before, after) = try written(NSColor.red, forKey: nil)
		#expect(NSDictionary(dictionary: before ?? [:]).isEqual(to: after ?? [:]), "the domain changed")
		#expect(try ObjC.run { UserDefaults.standard.color(forKey: nil) } == nil)
	}

	@Test("Absent, non-data and non-archive values read as nil")
	func unreadableValues() throws {
		#expect(try ObjC.run { UserDefaults.standard.color(forKey: "BricksmithTests.P5.absent") } == nil)
		#expect(try read("a string") == nil)
		#expect(try read(42) == nil)
		#expect(try read(Data("garbage".utf8)) == nil)
		#expect(try read(Data()) == nil)
	}

	@Test("A non-colour object in an NSArchiver blob is returned as-is (no type check)")
	func nonColourObjectReturnedAsIs() throws {
		let archiver: AnyObject = NSClassFromString("NSArchiver")!
		let data = archiver.perform(NSSelectorFromString("archivedDataWithRootObject:"), with: "not a colour" as NSString)!
			.takeUnretainedValue() as! Data
		let object: AnyObject? = try read(data)
		let returned = try #require(object as? NSObject)
		#expect(returned.isKind(of: NSString.self), "\(type(of: returned))")
		#expect(returned.description == "not a colour")
	}

	@Test("BUG-035 (fixed in P5): a truncated or corrupt colour blob reads as nil instead of raising")
	func bug035TruncatedBlobShouldReadNil() throws {
		for data in [Data(ArgumentPrefs.archivedColour(NSColor.red).prefix(20)),
					 Data(ArgumentPrefs.archivedColour(NSColor(calibratedRed: 1, green: 0.5, blue: 0, alpha: 1)).prefix(20))] {
			let colour = try read(data)
			#expect(colour == nil)
		}
	}
}
