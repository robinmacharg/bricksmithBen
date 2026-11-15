//
//  PreferencesContractTests.swift
//  BricksmithTests
//
//  P2 row 14: the preferences contract. Users' saved settings are keyed by these strings; a port that renamed
//  one would silently lose a setting. Goldens: Fixtures/golden/prefs/{constants.tsv,registered-defaults.json}
//

import Foundation
import Testing
@testable import Bricksmith

@Suite("Preferences contract (P2 row 14)", .serialized)
struct PreferencesContractTests {

	@Test("Every exported string constant (preference keys, notifications, pasteboard types) keeps its value")
	func constants() throws {
		#expect(StringConstants.all.count >= 175)
		let rows = ["header\tname\tvalue"] + StringConstants.all.map { "\($0.header)\t\($0.name)\t\($0.value)" }
		try Golden.check(Data((rows.joined(separator: "\n") + "\n").utf8), against: "prefs/constants.tsv")
	}

	@Test("Registered default values (+[PreferencesDialogController ensureDefaults])")
	func registeredDefaults() throws {
		PreferencesDialogController.ensureDefaults()
		// System/test-runner keys vary by machine; LDrawGLView keys are registered by views as they are created,
		// so they depend on which earlier tests opened documents. Keep only the app's own, stable keys.
		let excludedPrefixes = ["Apple", "NS", "METAL_", "XCT", "LDrawGLView "]
		let registered = UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)
			.filter { key, _ in !excludedPrefixes.contains { key.hasPrefix($0) } }
		// Data values (archived colours) as base64 so the JSON is stable and reviewable.
		#expect(registered["Syntak Color Colors"] != nil, "the misspelt key must stay misspelt: users' saved setting uses it")
		let normalised = registered.mapValues { value -> Any in
			if let data = value as? Data { return "data:" + data.base64EncodedString() }
			return value
		}
		let json = try JSONSerialization.data(withJSONObject: normalised, options: [.prettyPrinted, .sortedKeys])
		try Golden.check(json, against: "prefs/registered-defaults.json")
	}
}
