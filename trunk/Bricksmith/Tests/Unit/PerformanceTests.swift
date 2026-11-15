//
//  PerformanceTests.swift
//  BricksmithTests
//
//  P2 row 16: self-timed performance baselines, run ONLY in the optimised Perf configuration via
//  `scripts/perf-compare.sh --run` (BRICKSMITH_PERF=1). Each metric is the BEST (minimum) of a fixed number of
//  iterations after warm-up - on a busy desktop interference only ever adds time, so the minimum is the stable
//  statistic (medians of ms-scale timings varied 44-121% between identical runs; LEARNINGS L65). Workload: a
//  deterministic synthetic model built from ldraw-mini parts (no full library needed).
//  Results: build/perf-results.json -> compared with docs/perf-baseline.json (<= +20%).
//

import AppKit
import OpenGL.GL
import Foundation
import Testing
@testable import Bricksmith

enum Perf {
	static var enabled: Bool { ProcessInfo.processInfo.environment["BRICKSMITH_PERF"] == "1" }
	static let iterations = 15
	static let warmUp = 2

	/// 5 submodels x 4000 parts in steps of 20, deterministic (seeded positions and colours).
	static let syntheticModel: String = {
		var rng = SeededRNG(seed: 0x5EED_B11C)
		let parts = ["3001.dat", "3003.dat", "3005.dat", "3023.dat", "3024.dat", "3020.dat", "3039.dat", "3062b.dat"]
		let colours = [0, 1, 2, 4, 14, 15, 71, 72]
		var lines: [String] = []
		for model in 0..<5 {
			lines.append("0 FILE model\(model).ldr")
			lines.append("0 Synthetic model \(model)")
			lines.append("0 Name: model\(model).ldr")
			lines.append("0 Author: perf")
			for i in 0..<4000 {
				let x = Int.random(in: -400...400, using: &rng) * 10, y = -Int.random(in: 0...100, using: &rng) * 8
				let z = Int.random(in: -400...400, using: &rng) * 10
				lines.append("1 \(colours[i % colours.count]) \(x) \(y) \(z) 1 0 0 0 1 0 0 0 1 \(parts[i % parts.count])")
				if i % 20 == 19 { lines.append("0 STEP") }
			}
			lines.append("0 NOFILE")
		}
		return lines.joined(separator: "\r\n") + "\r\n"
	}()

	static func best(_ body: () throws -> Void) rethrows -> Double {
		for _ in 0..<warmUp { try body() }
		var times: [Double] = []
		for _ in 0..<iterations {
			let start = DispatchTime.now().uptimeNanoseconds
			try body()
			times.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9)
		}
		return times.min()!
	}

	/// Merge one metric into build/perf-results.json.
	static func record(_ metric: String, _ seconds: Double) throws {
		let root = ProcessInfo.processInfo.environment["BRICKSMITH_REPO_ROOT"] ?? FixturePaths.trunk.deletingLastPathComponent().path
		let url = URL(fileURLWithPath: root).appendingPathComponent("build/perf-results.json")
		var json = (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: Any] ?? [:]
		var results = json["results"] as? [String: Double] ?? [:]
		results[metric] = seconds
		json["results"] = results
		json["machine"] = RenderHarness.machineName
		try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(to: url)
	}
}

@Suite("Performance (P2 row 16)", .fixtureLibrary, .serialized, .enabled(if: Perf.enabled, "set BRICKSMITH_PERF=1 (scripts/perf-compare.sh --run)"))
struct PerformanceTests {

	@Test("parse, write, copy, archive of the synthetic model")
	func modelOperations() throws {
		let data = Data(Perf.syntheticModel.utf8)
		var file: LDrawFile!
		try Perf.record("parse_20000_parts", Perf.best { file = RoundTrip.load(data) })
		let loaded = try #require(file)
		try Perf.record("write_20000_parts", Perf.best { _ = RoundTrip.save(loaded) })
		try Perf.record("copy_20000_parts", Perf.best { _ = loaded.copy() })
		try Perf.record("archive_20000_parts", Perf.best { _ = ObjectModel.archive(loaded) })
	}

	@MainActor
	@Test("GL draw of the synthetic model", .timeLimit(.minutes(2)))
	func draw() throws {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("perf-synthetic.mpd")
		try Data(Perf.syntheticModel.utf8).write(to: url)
		defer { try? FileManager.default.removeItem(at: url) }
		let doc = try LDrawDocument(contentsOf: url, ofType: "LDraw Document")
		try ObjC.run { doc.makeWindowControllers(); if let w = doc.windowControllers.first?.window {
			w.alphaValue = 0; w.setFrame(NSRect(x: 100, y: 100, width: 1200, height: 800), display: false); w.orderFront(nil) } }
		defer { DocHarness.close(doc) }
		let view = try #require(doc.main3DViewport())
		try ObjC.run { view.zoomToFit(nil); view.draw() }   // warm-up: builds display lists/VBOs
		// glFinish so the timing includes the GPU work, not just command submission.
		try Perf.record("draw_20000_parts", Perf.best { try? ObjC.run { view.draw(); view.openGLContext?.makeCurrentContext(); glFinish() } })
	}
}
