//
//  HarnessFixtureLibraryTests.swift
//  BricksmithTests
//
//  Proves the .fixtureLibrary trait really isolates tests from the user's
//  LDraw library and from global state left by other tests.
//

import Foundation
import Testing
@testable import Bricksmith

@Suite("Harness: fixture library", .fixtureLibrary, .serialized)
struct HarnessFixtureLibraryTests {

	@Test("LDrawPaths points at the temporary copy, not the user's library")
	func pathsPointAtFixtureCopy() throws {
		let library = try #require(FixtureLibrary.current)
		let paths = LDrawPaths.shared()
		#expect(paths.preferredLDrawPath() == library.path)
		#expect(paths.ldconfigPath() == library.appendingPathComponent("LDConfig.ldr").path)
	}

	@Test("ColorLibrary loads LDConfig.ldr from the fixture copy")
	func colorLibraryReadsFixture() throws {
		// Mark the temporary copy so we can tell it apart from the bundled LDConfig.ldr.
		let library = try #require(FixtureLibrary.current)
		let ldconfig = library.appendingPathComponent("LDConfig.ldr")
		let handle = try FileHandle(forWritingTo: ldconfig)
		try handle.seekToEnd()
		try handle.write(contentsOf: Data("\r\n0 !COLOUR Fixture_Marker CODE 9999 VALUE #123456 EDGE #000000\r\n".utf8))
		try handle.close()

		let colors = try #require(ColorLibrary.shared())
		#expect(colors.color(forCode: LDrawColorT(rawValue: 9999))?.name() == "Fixture_Marker")
		#expect(colors.color(forCode: LDrawColorT(rawValue: 4))?.name() == "Red")
	}

	@Test("ColorLibrary.colors contains only LDrawColor (backs the NSArray<LDrawColor *> annotation)")
	func colorsElementType() throws {
		let colors = try #require(ColorLibrary.shared())
		let all = colors.colors() as [Any]
		#expect(all.count > 100)
		#expect(all.allSatisfy { $0 is LDrawColor })
	}
}
