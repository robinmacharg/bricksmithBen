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

/// P6a pins for LDrawColor, written against the ObjC class before its port to Swift: inits, NSCoding keys,
/// copying, identity equality, the complement colour, KVC keys used by the colour panel, `write` edge cases
/// (C int conversions that would trap in Swift), and the hex helpers.
@Suite("LDrawColor pins (P6a)", .serialized)
struct LDrawColorPinTests {

	static func parse(_ line: String) -> LDrawColor? {
		LDrawMetaCommand.directive(lines: [line], in: NSRange(location: 0, length: 1), parentGroup: nil) as? LDrawColor
	}

	static func colour(code: Int32, rgba: [GLfloat], name: String? = nil) -> LDrawColor {
		let c = LDrawColor()
		var v = rgba
		c.setColorCode(LDrawColorT(rawValue: code))
		c.setColorRGBA(&v)
		c.setName(name)
		return c
	}

	/// Every field visible through the API, on one line.
	static func fields(_ c: LDrawColor) -> String {
		"code \(c.colorCode().rawValue) rgba \(Colour.rgba(c)) edge \(c.edgeColorCode().rawValue) edgeRGBA \(Colour.edgeRGBA(c))"
			+ " lum \(c.luminance()) mat \(c.material().rawValue) params \(c.materialParameters() ?? "nil") name \(c.name() ?? "nil")"
			+ " | \(c.write() ?? "nil")"
	}

	@Test("init: defaults, and the line-based inits (nil for no lines)")
	func inits() throws {
		let c = LDrawColor()
		#expect(Self.fields(c) == "code -1 rgba [0.0, 0.0, 0.0, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.0, 0.0] lum 0 mat 0 params nil name  | 0 !COLOUR  CODE -1 VALUE #000000 EDGE #000000")
		#expect(c.alpha() == 1)
		#expect(c.browsingDescription() == "")
		#expect(c.iconName() == "ColorDroplet")
		#expect(c.inspectorClassName() == nil)
		#expect(c.stringValue() == "")
		#expect(LDrawColor(lines: [], in: NSRange(location: 0, length: 0)) == nil)
		#expect(LDrawColor(lines: [], in: NSRange(location: 0, length: 0), parentGroup: nil) == nil)
		let fromLines = try #require(LDrawColor(lines: ["0 !COLOUR X CODE 1 VALUE #000000 EDGE #000000"], in: NSRange(location: 0, length: 1)))
		#expect(Self.fields(fromLines) == Self.fields(LDrawColor()), "the line-based init only calls -init")
		let fromLines2 = try #require(LDrawColor(lines: ["x"], in: NSRange(location: 0, length: 1), parentGroup: nil))
		#expect(Self.fields(fromLines2) == Self.fields(LDrawColor()))
	}

	@Test("NSCoding: exact keys, and a keyed round trip keeps every field")
	func coding() throws {
		let lines = [
			"0 !COLOUR Glitter_Test CODE 510 VALUE #102030 EDGE #405060 ALPHA 128 LUMINANCE 15 MATERIAL GLITTER VALUE #FFFFFF FRACTION 0.17",
			"0 !COLOUR By_Code CODE 77 VALUE #A0B0C0 EDGE 4 CHROME",
		]
		for line in lines {
			let c = try #require(Self.parse(line))
			let data = try NSKeyedArchiver.archivedData(withRootObject: c, requiringSecureCoding: false)
			// The keys stored for the colour object itself.
			let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
			let objects = try #require(plist["$objects"] as? [Any])
			let dict = try #require(objects.compactMap { $0 as? [String: Any] }.first { $0["colorCode"] != nil })
			#expect(dict.keys.sorted() == ["$class", "colorCode", "colorRGBAAlpha", "colorRGBABlue", "colorRGBAGreen", "colorRGBARed",
										   "commandString", "edgeColorCode", "edgeColorRGBAAlpha", "edgeColorRGBABlue",
										   "edgeColorRGBAGreen", "edgeColorRGBARed", "enclosingDirective", "hasExplicitAlpha", "hasLuminance", "luminance",
										   "material", "materialParameters", "name"], "\(dict.keys.sorted())")
			let u = try NSKeyedUnarchiver(forReadingFrom: data)
			u.requiresSecureCoding = false
			let back = try #require(u.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? LDrawColor)
			u.finishDecoding()
			#expect(back !== c)
			#expect(Self.fields(back) == Self.fields(c))
		}
	}

	@Test("copy returns the receiver; fullCopyWithZone: makes a distinct, equal-valued colour")
	func copying() throws {
		let c = try #require(Self.parse("0 !COLOUR Copy_Me CODE 600 VALUE #112233 EDGE #445566 ALPHA 77 LUMINANCE 9 MATERIAL SPECKLE VALUE #898788"))
		#expect((c.copy() as AnyObject) === c)
		let full = try #require(c.fullCopy(with: nil) as? LDrawColor)
		#expect(full !== c)
		#expect(Self.fields(full) == Self.fields(c))
		#expect(full.compliment() !== c.compliment())
		let plain = LDrawColor()
		var edge: [GLfloat] = [0.1, 0.2, 0.3, 0.4]
		plain.setEdgeColorCode(LDrawColorT(rawValue: 5))
		let plainCopy = try #require(plain.fullCopy(with: nil) as? LDrawColor)
		#expect(Self.fields(plainCopy) == Self.fields(plain))
		plain.setEdgeColorRGBA(&edge)
		#expect(plain.edgeColorCode() == LDrawColorBogus, "setting edge components clears the edge code")
	}

	@Test("isEqual: and hash are identity-based")
	func identity() {
		let a = Self.colour(code: 4, rgba: [1, 0, 0, 1], name: "Red")
		let b = Self.colour(code: 4, rgba: [1, 0, 0, 1], name: "Red")
		#expect(a.isEqual(a))
		#expect(!a.isEqual(b))
		#expect(!a.isEqual(nil))
		#expect(!a.isEqual("Red"))
		#expect(a.hash == unsafeBitCast(a, to: Int.self), "hash is the object's address")
		let dict = NSMutableDictionary()
		dict[a] = "a"
		dict[b] = "b"
		#expect(dict.count == 2)
		#expect(dict[a] as? String == "a")
	}

	@Test("The complement colour: code 24, cached, components from complimentColor(), no retain cycle")
	func complement() throws {
		let c = Self.colour(code: 4, rgba: [0.7, 0.1, 0.2, 0.5])
		let comp = try #require(c.compliment())
		#expect(comp === c.compliment())
		#expect(comp.colorCode() == LDrawEdgeColor)
		var original: [GLfloat] = [0.7, 0.1, 0.2, 0.5], expected: [GLfloat] = [0, 0, 0, 0]
		complimentColor(&original, &expected)
		#expect(Colour.rgba(comp) == expected)
		#expect(comp.compliment() !== c && comp.compliment() !== comp)
		weak var weakColour: LDrawColor?
		weak var weakComp: LDrawColor?
		autoreleasepool {
			let x = Self.colour(code: 1, rgba: [0, 0, 1, 1])
			weakComp = x.compliment()
			weakColour = x
		}
		#expect(weakColour == nil)
		#expect(weakComp == nil)
	}

	@Test("Blended colours: code, name, opaque")
	func blended() throws {
		let c = try #require(LDrawColor.blendedColor(forCode: LDrawColorT(rawValue: 300)))
		#expect(c.colorCode().rawValue == 300)
		#expect(c.name() == "BlendedColor300")
		#expect(c.alpha() == 1)
		#expect(c.write() == "0 !COLOUR BlendedColor300 CODE 300 VALUE #7F3F19 EDGE #000000")
	}

	@Test("KVC keys and sort selectors used by the colour panel (ColorPanel.xib, LDrawColorPanelController)")
	func panelKeys() throws {
		let red = Self.colour(code: 4, rgba: [1, 0, 0, 1], name: "Not_Localized_Red")
		let trans = Self.colour(code: 9999, rgba: [0, 0, 1, 0.5], name: "Trans_Blue_Thing")
		let chrome = Self.colour(code: 9998, rgba: [0, 1, 0, 1], name: "Chrome_Green")
		chrome.setMaterial(.chrome)
		#expect((red.value(forKey: "colorCode") as? NSNumber)?.intValue == 4)
		#expect((trans.value(forKey: "alpha") as? NSNumber)?.floatValue == 0.5)
		#expect((chrome.value(forKey: "material") as? NSNumber)?.intValue == 1)
		#expect(trans.value(forKey: "localizedName") as? String == "Trans Blue Thing")
		#expect((red.value(forKey: "self") as AnyObject) === red)
		let all = [red, trans, chrome] as NSArray
		func codes(_ format: String, _ args: [Any]) -> [Int32] {
			all.filtered(using: NSPredicate(format: format, argumentArray: args)).map { ($0 as! LDrawColor).colorCode().rawValue }
		}
		#expect(codes("%K == %@", ["colorCode", 9999]) == [9999])
		#expect(codes("%K CONTAINS[cd] %@", ["localizedName", "blue"]) == [9999])
		#expect(codes("(%K == %@) AND (%K == 1.0)", ["material", 0, "alpha"]) == [4])
		#expect(codes("(%K == %@) AND (%K < 1.0)", ["material", 0, "alpha"]) == [9999])
		#expect(codes("(%K == %@)", ["material", 1]) == [9998])
		let byHSV = all.sortedArray(using: [NSSortDescriptor(key: "self", ascending: true, selector: NSSelectorFromString("HSVACompare:"))])
		#expect(byHSV.map { ($0 as! LDrawColor).colorCode().rawValue } == [4, 9998, 9999])
		let byName = all.sortedArray(using: [NSSortDescriptor(key: "localizedName", ascending: true, selector: #selector(NSString.compare(_:)))])
		#expect(byName.map { ($0 as! LDrawColor).colorCode().rawValue } == [9998, 4, 9999])
		for selector in ["alpha", "colorCode", "complimentColor", "edgeColorCode", "getColorRGBA:", "getEdgeColorRGBA:", "localizedName",
						 "luminance", "material", "materialParameters", "name", "setColorCode:", "setColorRGBA:", "setEdgeColorCode:",
						 "setEdgeColorRGBA:", "setLuminance:", "setMaterial:", "setMaterialParameters:", "setName:", "HSVACompare:",
						 "compare:", "hexStringForRGB:", "scanHexString:intoRGB:", "fullCopyWithZone:", "copyWithZone:", "isEqual:", "hash",
						 "finishParsing:", "write", "draw:viewScale:parentColor:", "browsingDescription", "iconName", "inspectorClassName",
						 "initWithCoder:", "encodeWithCoder:", "init", "initWithLines:inRange:", "initWithLines:inRange:parentGroup:"] {
			#expect(LDrawColor.instancesRespond(to: NSSelectorFromString(selector)), "\(selector)")
		}
		#expect(LDrawColor.responds(to: NSSelectorFromString("blendedColorForCode:")))
	}

	@Test("localizedName: a localized standard code, underscores to spaces, and a nil name")
	func localizedNames() {
		let named = Self.colour(code: 9999, rgba: [0, 0, 0, 1], name: "A_B__C")
		#expect(named.localizedName() == "A B  C")
		let unnamed = Self.colour(code: 9999, rgba: [0, 0, 0, 1], name: nil)
		#expect(unnamed.localizedName() == nil)
		let standard = Self.colour(code: 4, rgba: [0, 0, 0, 1], name: "Whatever")
		let expected = Bundle.main.localizedString(forKey: "LDraw: 4", value: "", table: nil)
		#expect(standard.localizedName() == (expected == "LDraw: 4" ? "Whatever" : expected))
	}

	@Test("HSVACompare: orders by hue, then saturation, then value")
	func hsvaOrder() {
		let red = Self.colour(code: 1, rgba: [1, 0, 0, 1])
		let green = Self.colour(code: 2, rgba: [0, 1, 0, 1])
		let paleRed = Self.colour(code: 3, rgba: [1, 0.5, 0.5, 1])
		let darkRed = Self.colour(code: 4, rgba: [0.5, 0, 0, 1])
		let black = Self.colour(code: 5, rgba: [0, 0, 0, 1])
		#expect(red.hsvaCompare(green) == .orderedAscending)
		#expect(green.hsvaCompare(red) == .orderedDescending)
		#expect(paleRed.hsvaCompare(red) == .orderedAscending)   // same hue, lower saturation
		#expect(darkRed.hsvaCompare(red) == .orderedAscending)   // same hue and saturation, lower value
		#expect(red.hsvaCompare(red) == .orderedSame)
		#expect(black.hsvaCompare(red) == .orderedAscending)     // black has hue -1
		#expect((([red, green] as NSArray).sortedArray(using: NSSelectorFromString("compare:")) as! [LDrawColor]).first === red)
	}

	@Test("write: C int conversions of ALPHA/LUMINANCE, missing fields, and MATERIAL edge cases")
	func writeEdgeCases() {
		let lines = [
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 ALPHA 300",
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 ALPHA -1",
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 ALPHA 2147483647",
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 ALPHA",
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 LUMINANCE 300",
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 LUMINANCE -1",
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 MATERIAL",
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 MATERIAL   x  y ",
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 METAL CHROME",
			"0 !COLOUR",
			"0 !COLOUR Only_Name",
			"0 !COLOUR A CODE x VALUE #102030 EDGE #405060",
			"0 !COLOUR A CODE 2147483648 VALUE #102030 EDGE #405060",
			"0 !COLOUR A CODE 1 VALUE #102030",
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE",
			"0 !COLOUR A CODE 1 VALUE #102030 EDGE x",
			"0 !COLOUR A CODE 1 VALUE # EDGE #405060",
			"0 !COLOUR A CODE 1 VALUE 0x77cc00 EDGE 0x",
			"0 !COLOUR A CODE 1 VALUE #123456789 EDGE #FFFFFFFFFFFFFFFFFFFF",
			"0 !COLOUR A CODE 1 VALUE #0x10 EDGE #1g",
			"0 !COLOUR A CODE 1 VALUE 102030 EDGE #405060",
			"0 !COLOUR Ünïcödé_Näme CODE 1 VALUE #102030 EDGE #405060 MATERIAL ÄÖ ü",
		]
		var out: [String] = []
		for line in lines {
			let c = Self.parse(line)
			out.append(c.map { Self.fields($0) } ?? "nil")
		}
		#expect(out == [
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 1.1764706] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 ALPHA 300",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, -0.003921569] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 ALPHA -1",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 8421505.0] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 ALPHA 2147483647",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 0.0] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 ALPHA 0",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 1.0] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 44 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 LUMINANCE 44",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 1.0] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 255 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 LUMINANCE 255",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 1.0] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 0 mat 6 params  name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 MATERIAL ",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 1.0] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 0 mat 6 params x  y  name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 MATERIAL x  y ",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 1.0] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 0 mat 5 params nil name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #405060 METAL",
			"code -1 rgba [0.0, 0.0, 0.0, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.0, 0.0] lum 0 mat 0 params nil name nil | 0 !COLOUR (null) CODE -1 VALUE #000000 EDGE #000000",
			"code -1 rgba [0.0, 0.0, 0.0, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.0, 0.0] lum 0 mat 0 params nil name Only_Name | 0 !COLOUR Only_Name CODE -1 VALUE #000000 EDGE #000000",
			"code -1 rgba [0.0, 0.0, 0.0, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.0, 0.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE -1 VALUE #000000 EDGE #000000",
			"code 2147483647 rgba [0.0627451, 0.1254902, 0.1882353, 1.0] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 2147483647 VALUE #102030 EDGE #405060",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.0, 0.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #000000",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.0, 0.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #000000",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.0, 0.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #102030 EDGE #000000",
			"code 1 rgba [0.0, 0.0, 0.92941177, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.0, 0.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #0000ED EDGE #000000",
			"code 1 rgba [0.46666667, 0.8, 0.0, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.0, 1.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #77CC00 EDGE #000000",
			"code 1 rgba [1.0, 1.0, 1.0, 1.0] edge -1 edgeRGBA [1.0, 1.0, 1.0, 1.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #FFFFFF EDGE #FFFFFF",
			"code 1 rgba [0.0, 0.0, 0.0627451, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.003921569, 1.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #000010 EDGE #000001",
			"code 1 rgba [0.0, 0.0, 0.0, 1.0] edge -1 edgeRGBA [0.0, 0.0, 0.0, 0.0] lum 0 mat 0 params nil name A | 0 !COLOUR A CODE 1 VALUE #000000 EDGE #000000",
			"code 1 rgba [0.0627451, 0.1254902, 0.1882353, 1.0] edge -1 edgeRGBA [0.2509804, 0.3137255, 0.3764706, 1.0] lum 0 mat 6 params ÄÖ ü name Ünïcödé_Näme | 0 !COLOUR Ünïcödé_Näme CODE 1 VALUE #102030 EDGE #405060 MATERIAL ÄÖ ü",
		], "\(out.joined(separator: "\n"))")
	}

	@Test("Setters: luminance and custom material without parameters")
	func setters() throws {
		let c = Self.colour(code: 7, rgba: [0.5, 0.25, 1, 1], name: "S")
		c.setLuminance(200)
		c.setMaterial(.custom)
		#expect(c.write() == "0 !COLOUR S CODE 7 VALUE #7F3FFF EDGE #000000 LUMINANCE 200 MATERIAL (null)")
		c.setMaterialParameters("P Q")
		c.setName(nil)
		#expect(c.write() == "0 !COLOUR (null) CODE 7 VALUE #7F3FFF EDGE #000000 LUMINANCE 200 MATERIAL P Q")
		c.setMaterial(try #require(LDrawColorMaterialT(rawValue: 99)))
		#expect(c.material().rawValue == 99)
		#expect(c.write() == "0 !COLOUR (null) CODE 7 VALUE #7F3FFF EDGE #000000 LUMINANCE 200")
	}

	@Test("hexStringForRGB: truncation, out-of-range, NaN and infinite components")
	func hexStrings() {
		let c = LDrawColor()
		func hex(_ v: [GLfloat]) -> String { var v = v; return c.hexString(forRGB: &v) ?? "nil" }
		#expect(hex([0.5, 1, 0, 1]) == "#7FFF00")
		#expect(hex([-0.5, 1.5, 2, 1]) == "#FFFFFF8117E1FE")
		#expect(hex([.nan, .infinity, -.infinity, 1]) == "#007FFFFFFF80000000")
		#expect(hex([1e10, -1e10, 0.999, 1]) == "#7FFFFFFF80000000FE")
	}

	@Test("scanHexString:intoRGB: prefixes, failure leaves components alone, scanner position")
	func scanHex() {
		let c = LDrawColor()
		func scan(_ s: String) -> String {
			let scanner = Scanner(string: s)
			scanner.charactersToBeSkipped = .whitespaces
			var v: [GLfloat] = [9, 9, 9, 9]
			let ok = c.scanHexString(scanner, intoRGB: &v)
			return "\(ok) \(v) at \(scanner.string.distance(from: scanner.string.startIndex, to: scanner.currentIndex))"
		}
		#expect(scan("#77CC00 rest") == "true [0.46666667, 0.8, 0.0, 1.0] at 7")
		#expect(scan("0x77cc00") == "true [0.46666667, 0.8, 0.0, 1.0] at 8")
		#expect(scan("  #FF") == "true [0.0, 0.0, 1.0, 1.0] at 5")
		#expect(scan("77CC00") == "false [9.0, 9.0, 9.0, 9.0] at 0")
		#expect(scan("#") == "true [0.0, 0.0, 0.0, 1.0] at 1")
		#expect(scan("#123456789") == "true [1.0, 1.0, 1.0, 1.0] at 10")
	}
}
