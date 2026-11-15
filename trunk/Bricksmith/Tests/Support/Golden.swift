//
//  Golden.swift
//  BricksmithTests
//
//  Byte-exact golden-file comparison (plan §5 P2; TESTING.md "Rules").
//
//  - Normal runs compare `actual` with trunk/Fixtures/golden/<name>. A missing golden FAILS
//    (it is never created silently).
//  - `RECORD_GOLDENS=1 scripts/test.sh` writes the goldens instead. A person must review the
//    resulting diff before committing (🧑 HUMAN GATE), and port commits must never change goldens.
//

import Foundation
import Testing

enum Golden {
	static var directory: URL { FixturePaths.fixtures.appendingPathComponent("golden") }

	static var isRecording: Bool {
		ProcessInfo.processInfo.environment["RECORD_GOLDENS"] == "1"
	}

	/// Compare `actual` with the golden file `name` (a path relative to Fixtures/golden).
	static func check(_ actual: Data, against name: String,
					  sourceLocation: SourceLocation = #_sourceLocation) throws {
		let url = directory.appendingPathComponent(name)

		if isRecording {
			try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
													withIntermediateDirectories: true)
			try actual.write(to: url)
			return
		}

		guard let expected = FileManager.default.contents(atPath: url.path) else {
			Issue.record("Missing golden \(name). Record with RECORD_GOLDENS=1 scripts/test.sh and review.",
						 sourceLocation: sourceLocation)
			return
		}
		if expected != actual {
			Issue.record("Output differs from golden \(name): \(firstDifference(expected, actual))",
						 sourceLocation: sourceLocation)
		}
	}

	/// Human-readable description of the first differing line (bytes shown escaped, so CR/LF/BOM are visible).
	static func firstDifference(_ expected: Data, _ actual: Data) -> String {
		func lines(_ d: Data) -> [String] {
			String(decoding: d, as: UTF8.self).components(separatedBy: "\n")
		}
		let e = lines(expected), a = lines(actual)
		for i in 0..<max(e.count, a.count) {
			let el = i < e.count ? e[i] : "<end of file>"
			let al = i < a.count ? a[i] : "<end of file>"
			if el != al {
				return "line \(i + 1):\n  expected: \(el.debugDescription)\n  actual:   \(al.debugDescription)"
			}
		}
		return "same lines, different bytes (expected \(expected.count) B, actual \(actual.count) B)"
	}
}
