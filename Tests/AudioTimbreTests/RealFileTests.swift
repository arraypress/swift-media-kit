//
//  RealFileTests.swift
//  AudioTimbreTests
//
//  Measured against a real sample pack, where the filenames carry the answers.
//
//  Synthetic signals prove the maths and cannot prove everything: a pitch floor too high for
//  a sub bass, a fallback returning the edge of the search range as a measurement, and
//  texture boundaries wrong for this implementation are invisible to generated tones and
//  obvious across a real pack.
//
//  These assert RATES, not single files. One kick proves nothing: some kicks are pitched
//  and some are not, and a test pinned to whichever file the directory walk happened to
//  reach first fails for reasons that have nothing to do with the code. A rate over thirty
//  of them is a claim about the measurement.
//
//  Gated because the audio is not in the repository and cannot be:
//
//  AUDIOTIMBRE_SAMPLES=~/Samples/SomePack swift test
//
//  Figures in the assertions were measured on Activa Trance Essentials Volume 2, 30 files
//  per class. Thresholds sit below the measured rate with room for a different pack.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import AudioTimbre

final class RealFileTests: XCTestCase {

    private var root: URL? {
        ProcessInfo.processInfo.environment["AUDIOTIMBRE_SAMPLES"].map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)
        }
    }

    /// Up to `limit` analysed files whose names contain every fragment and none of
    /// `excluding`.
    private func sample(_ fragments: [String], excluding: [String] = [],
                        limit: Int = 30) throws -> [(URL, Timbre)] {
        guard let root else { throw XCTSkip("AUDIOTIMBRE_SAMPLES not set") }
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("could not read \(root.path)")
        }
        var found: [(URL, Timbre)] = []
        for case let url as URL in walker where url.pathExtension.lowercased() == "wav" {
            guard found.count < limit else { break }
            let name = url.lastPathComponent.lowercased()
            guard fragments.allSatisfy({ name.contains($0.lowercased()) }),
                  !excluding.contains(where: { name.contains($0.lowercased()) }) else { continue }
            if let timbre = try? TimbreAnalyzer.analyze(fileAt: url) { found.append((url, timbre)) }
        }
        try XCTSkipIf(found.count < 5, "fewer than 5 files matching \(fragments)")
        return found
    }

    private func assertRate(_ files: [(URL, Timbre)], _ label: String,
                            atLeast fraction: Double, where predicate: (Timbre) -> Bool) {
        let hits = files.filter { predicate($0.1) }.count
        let rate = Double(hits) / Double(files.count)
        XCTAssertGreaterThanOrEqual(rate, fraction,
            "\(label): \(hits)/\(files.count) = \(Int(rate * 100))%, expected at least \(Int(fraction * 100))%")
    }

    func testKicksAreDarkAndTonal() throws {
        let kicks = try sample(["kick"])
        assertRate(kicks, "kicks dark", atLeast: 0.80) { $0.brightness == .dark }      // measured 24/25
        assertRate(kicks, "kicks tonal", atLeast: 0.90) { $0.texture == .tonal }       // measured 25/25
    }

    func testSubBassesAreDarkTonalAndPitched() throws {
        // One-shots only. A sub bass LOOP moves — filter sweeps and note changes put
        // broadband content in it — and measures tonal only 76% of the time, which is a
        // fact about loops rather than about the measurement.
        let subs = try sample(["sub bass"], excluding: ["loop"])
        assertRate(subs, "subs dark", atLeast: 0.90) { $0.brightness == .dark }        // measured 30/30
        // 23/30. The seven that read `mixed` are all one instrument — "Sub Bass - 005",
        // flatness 0.030 to 0.040 against a clean sub's 0.001 — and it is a gritty,
        // driven sub, so broadband content is really there. The boundary is doing its job
        // rather than failing: raising it to swallow this set would put claps (p10 0.033)
        // back in the tonal bucket, which is the fault it was moved to fix.
        assertRate(subs, "subs tonal", atLeast: 0.75) { $0.texture == .tonal }
        // The regression the 50 Hz floor caused: every one of these came back unpitched.
        assertRate(subs, "subs pitched", atLeast: 0.90) { $0.pitch != nil }            // measured 30/30
    }

    func testClosedHatsAreAiryNoisyAndUnpitched() throws {
        let hats = try sample(["closed hat"])
        assertRate(hats, "hats airy", atLeast: 0.90) { $0.brightness == .airy }        // measured 25/25
        assertRate(hats, "hats noisy", atLeast: 0.80) { $0.texture == .noisy }         // measured 25/25
        assertRate(hats, "hats unpitched", atLeast: 0.90) { $0.pitch == nil }          // measured 25/25
    }

    func testClapsAreNotTonal() throws {
        // The finding that moved the texture boundaries: with serum-mcp's 0.15 cut, 22 of
        // 25 claps landed in the same bucket as a kick.
        let claps = try sample(["clap"])
        assertRate(claps, "claps not tonal", atLeast: 0.80) { $0.texture != .tonal }   // measured median 0.071
        assertRate(claps, "claps bright", atLeast: 0.70) { $0.brightness == .bright }
    }

    func testPitchAgreesWithTheNoteInTheFilename() throws {
        guard let root else { throw XCTSkip("AUDIOTIMBRE_SAMPLES not set") }
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("could not read \(root.path)")
        }
        // Files named "… - C.wav" or "… - F#.wav" state their own pitch class.
        let labelled = try NSRegularExpression(pattern: #" - ([A-G]#?)\.wav$"#)
        var agreed = 0, total = 0
        var misses: [String] = []

        for case let url as URL in walker where url.pathExtension.lowercased() == "wav" {
            guard total < 60 else { break }
            let name = url.lastPathComponent
            let range = NSRange(name.startIndex..., in: name)
            guard let match = labelled.firstMatch(in: name, range: range),
                  let noteRange = Range(match.range(at: 1), in: name) else { continue }
            guard let timbre = try? TimbreAnalyzer.analyze(fileAt: url) else { continue }
            total += 1
            if timbre.pitch?.note == String(name[noteRange]) {
                agreed += 1
            } else {
                misses.append("\(name) -> \(timbre.pitch?.name ?? "none")")
            }
        }

        try XCTSkipIf(total < 10, "fewer than 10 note-labelled files")
        let rate = Double(agreed) / Double(total)
        // Measured 58/60. Both misses were LOOPS rather than one-shots, each a semitone or
        // two under the labelled key — the loudest window of a bassline need not sit on the
        // root. One-shots agreed exactly.
        XCTAssertGreaterThanOrEqual(rate, 0.90,
            "note agreement \(agreed)/\(total); misses: \(misses.prefix(5).joined(separator: ", "))")
    }

    func testNoFileReportsTheEdgeOfTheSearchRangeAsAPitch() throws {
        let files = try sample([".wav"], limit: 60)
        // 44,100 / 29 = 1,520.7 Hz is the shortest lag searched. A file reporting exactly
        // that is reporting the search window rather than itself.
        for (url, timbre) in files {
            guard let hz = timbre.pitch?.frequencyHz else { continue }
            XCTAssertNotEqual(hz, 1520.689655172414, accuracy: 0.01,
                              "\(url.lastPathComponent) reported the boundary lag as a pitch")
        }
    }
}
