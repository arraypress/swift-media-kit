//
//  WaveformAndLevelTests.swift
//  AudioTimbreTests
//
//  The streamed readers against WAV files written here with known samples: a ramp climbs
//  bin by bin, a steady sine is flat at full height, silence is flat at zero; the level of a
//  ramp, a rail-to-rail square, and silence.
//
//  Created by David Sherlock on 9/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import XCTest
@testable import AudioTimbre

final class WaveformAndLevelTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("audio-timbre-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A 16-bit PCM WAV from Int16 samples, interleaved when `channels` > 1.
    private func wav(_ name: String, samples: [Int16], sampleRate: Int = 8_000, channels: Int = 1) throws -> URL {
        var data = Data()
        func put32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func put16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let byteCount = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); put32(36 + byteCount); data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); put32(16); put16(1); put16(UInt16(channels))
        put32(UInt32(sampleRate)); put32(UInt32(sampleRate * channels * 2)); put16(UInt16(channels * 2)); put16(16)
        data.append(contentsOf: Array("data".utf8)); put32(byteCount)
        samples.withUnsafeBufferPointer { data.append(contentsOf: UnsafeRawBufferPointer($0)) }
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private func ramp(seconds: Double, rate: Int = 8_000) -> [Int16] {
        let n = Int(seconds * Double(rate))
        return (0..<n).map { i in Int16(Double(32_000) * (Double(i) / Double(n)) * sin(2 * .pi * 440 * Double(i) / Double(rate))) }
    }

    func testARampClimbsBinByBinAndASineIsFlat() async throws {
        let rampURL = try wav("ramp.wav", samples: ramp(seconds: 2))
        let peaks = try await Waveform.peaks(fileAt: rampURL)
        XCTAssertEqual(peaks.count, Waveform.defaultBins)
        XCTAssertLessThan(peaks.first ?? 1, 0.1, "near silence at the start")
        XCTAssertEqual(peaks.last ?? 0, 1, accuracy: 0.001, "the loudest bin is 1")
        let climbs = zip(peaks, peaks.dropFirst()).allSatisfy { $1 >= $0 - 0.02 }
        XCTAssertTrue(climbs, "each bin is at least as loud as the one before: \(peaks.prefix(8))")

        let sine = try wav("sine.wav", samples: (0..<16_000).map { Int16(30_000 * sin(2 * .pi * 440 * Double($0) / 8_000)) })
        let flat = try await Waveform.peaks(fileAt: sine, bins: 32)
        XCTAssertEqual(flat.count, 32)
        XCTAssertTrue(flat.allSatisfy { $0 > 0.9 }, "a steady tone fills every bin: \(flat)")

        let silence = try wav("silence.wav", samples: [Int16](repeating: 0, count: 16_000), channels: 1)
        let zero = try await Waveform.peaks(fileAt: silence)
        XCTAssertTrue(zero.allSatisfy { $0 == 0 })
    }

    func testStereoIsFoldedToMonoAndAMissingFileThrows() async throws {
        var stereo: [Int16] = []
        for i in 0..<8_000 { stereo.append(Int16(20_000 * sin(2 * .pi * 220 * Double(i) / 8_000))); stereo.append(0) }
        let url = try wav("stereo.wav", samples: stereo, channels: 2)
        let peaks = try await Waveform.peaks(fileAt: url, bins: 8)
        XCTAssertTrue(peaks.allSatisfy { $0 > 0.9 }, "one loud channel still shapes every bin: \(peaks)")
        do {
            _ = try await Waveform.peaks(fileAt: directory.appendingPathComponent("nope.wav"))
            XCTFail("a missing file must throw")
        } catch AudioTimbreError.fileNotFound { } catch { XCTFail("wrong error \(error)") }
    }

    func testLevelOfARampASquareAndSilence() async throws {
        let rampURL = try wav("ramp.wav", samples: ramp(seconds: 2))
        let rampLevel = try await Level.measure(fileAt: rampURL)
        XCTAssertEqual(rampLevel.peakDbfs ?? -99, 20 * log10(32_000.0 / 32_768), accuracy: 0.1, "the ramp's loudest sample is 32,000")
        XCTAssertEqual(rampLevel.clippedSamples, 0)
        XCTAssertEqual(rampLevel.sampleCount, 16_000)
        XCTAssertEqual(rampLevel.analyzedSeconds, 2, accuracy: 0.001)

        let square = try wav("square.wav", samples: (0..<8_000).map { $0 % 2 == 0 ? Int16.max : -Int16.max })
        let squareLevel = try await Level.measure(fileAt: square)
        XCTAssertEqual(squareLevel.peakDbfs ?? -99, 0, accuracy: 0.001)
        XCTAssertEqual(squareLevel.clippedSamples, 8_000, "every sample sits at a rail")
        XCTAssertEqual(squareLevel.clippedShare, 1, accuracy: 0.0001)

        let silence = try wav("silence.wav", samples: [Int16](repeating: 0, count: 8_000))
        let silent = try await Level.measure(fileAt: silence)
        XCTAssertNil(silent.peakDbfs, "silence has no level")
        XCTAssertEqual(silent.clippedSamples, 0)
    }
}
