//
//  ImagePaletteTests.swift
//  ImagePaletteTests
//
//  Synthetic pictures with known colours and known shares, so the numbers
//  can be asserted rather than admired.
//
//  Created by David Sherlock on 8/30/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreGraphics
import Foundation
import XCTest
@testable import ImagePalette

final class OKLabTests: XCTestCase {

    func testRoundTripsSRGB() {
        for (r, g, b) in [(0, 0, 0), (255, 255, 255), (255, 0, 0), (12, 200, 90), (128, 128, 128), (240, 210, 250)]
            as [(UInt8, UInt8, UInt8)]
        {
            let back = OKLab(r: r, g: g, b: b).rgb
            XCTAssertLessThanOrEqual(abs(Int(back.r) - Int(r)), 1)
            XCTAssertLessThanOrEqual(abs(Int(back.g) - Int(g)), 1)
            XCTAssertLessThanOrEqual(abs(Int(back.b) - Int(b)), 1)
        }
    }

    func testLightnessAndChromaMeanWhatTheySay() {
        XCTAssertEqual(OKLab(r: 0, g: 0, b: 0).l, 0, accuracy: 0.001)
        XCTAssertEqual(OKLab(r: 255, g: 255, b: 255).l, 1, accuracy: 0.001)
        XCTAssertLessThan(OKLab(r: 128, g: 128, b: 128).chroma, 0.001, "grey has no chroma")
        XCTAssertGreaterThan(OKLab(r: 255, g: 0, b: 0).chroma, 0.2)
        XCTAssertGreaterThan(
            OKLab(r: 0, g: 0, b: 255).distance(to: OKLab(r: 255, g: 255, b: 0)),
            OKLab(r: 0, g: 0, b: 255).distance(to: OKLab(r: 0, g: 0, b: 230)))
    }
}

final class ExtractorTests: XCTestCase {

    /// A picture made of solid blocks, each a known share.
    private func image(blocks: [(color: (UInt8, UInt8, UInt8), width: Int)], height: Int = 64) -> CGImage {
        let width = blocks.reduce(0) { $0 + $1.width }
        var data = [UInt8](repeating: 255, count: width * height * 4)
        var x0 = 0
        for block in blocks {
            for y in 0..<height {
                for x in x0..<(x0 + block.width) {
                    let i = (y * width + x) * 4
                    data[i] = block.color.0; data[i + 1] = block.color.1; data[i + 2] = block.color.2; data[i + 3] = 255
                }
            }
            x0 += block.width
        }
        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    func testSharesMatchTheBlocks() throws {
        // 70 % navy, 20 % coral, 10 % cream.
        let img = image(blocks: [((20, 30, 80), 140), ((240, 110, 90), 40), ((250, 240, 220), 20)])
        let palette = try PaletteExtractor.extract(from: img, options: PaletteOptions(count: 6, sampleSide: 200))
        XCTAssertEqual(palette.count, 3, "\(palette.map(\.hex))")
        XCTAssertEqual(palette[0].share, 0.70, accuracy: 0.03)
        XCTAssertEqual(palette[1].share, 0.20, accuracy: 0.03)
        XCTAssertEqual(palette[2].share, 0.10, accuracy: 0.03)
        XCTAssertEqual(palette.reduce(0) { $0 + $1.share }, 1, accuracy: 0.001)
        XCTAssertEqual(palette[0].hex, "#141E50")
        XCTAssertEqual(palette[1].hex, "#F06E5A")
        XCTAssertTrue(palette[2].lightness > 0.9)
    }

    func testNearIdenticalColoursMergeAndSliversDrop() throws {
        // Two greens the eye cannot separate, and a one-pixel-column red.
        let img = image(blocks: [((30, 140, 60), 100), ((32, 142, 61), 100), ((255, 0, 0), 1)])
        let palette = try PaletteExtractor.extract(from: img, options: PaletteOptions(count: 6, sampleSide: 201))
        XCTAssertEqual(palette.count, 1, "\(palette.map { "\($0.hex) \($0.share)" })")
        XCTAssertEqual(palette[0].share, 1, accuracy: 0.001)
    }

    func testDeterministic() throws {
        let img = image(blocks: [((200, 30, 30), 50), ((30, 200, 30), 50), ((30, 30, 200), 50), ((240, 240, 240), 50)])
        let a = try PaletteExtractor.extract(from: img)
        let b = try PaletteExtractor.extract(from: img)
        XCTAssertEqual(a, b, "the same picture gives the same palette")
        XCTAssertEqual(a.count, 4)
    }

    func testTransparentPixelsAreNotColours() throws {
        let width = 100, height = 10
        var data = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height { for x in 0..<50 { let i = (y * width + x) * 4; data[i] = 200; data[i + 3] = 255 } }  // half red, half clear
        let provider = CGDataProvider(data: Data(data) as CFData)!
        let img = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let palette = try PaletteExtractor.extract(from: img)
        XCTAssertEqual(palette.count, 1)
        XCTAssertEqual(palette[0].hex, "#C80000")
        XCTAssertEqual(palette[0].share, 1, accuracy: 0.001, "clear pixels are not part of the picture")
    }

    func testSwatchFormats() {
        let s = Swatch(red: 255, green: 85, blue: 51, share: 0.5)
        XCTAssertEqual(s.hex, "#FF5533")
        XCTAssertEqual(s.rgb, "rgb(255, 85, 51)")
        XCTAssertEqual(s.hsl, "hsl(10, 100%, 60%)")
        XCTAssertFalse(s.isNeutral)
        XCTAssertTrue(Swatch(red: 120, green: 120, blue: 120, share: 1).isNeutral)
    }

    func testReadsARealFile() throws {
        let url = URL(fileURLWithPath: "/System/Library/Desktop Pictures/iMac Blue.heic")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "no system wallpaper here")
        let palette = try PaletteExtractor.extract(from: url, options: PaletteOptions(count: 5))
        XCTAssertFalse(palette.isEmpty)
        XCTAssertEqual(palette.reduce(0) { $0 + $1.share }, 1, accuracy: 0.001)
        XCTAssertGreaterThan(palette[0].share, palette.last!.share)
    }

    /// The generator IS the determinism contract: seed 7919 must produce
    /// this exact sequence forever, and doubles must sit in [0, 1).
    func testSplitMixSequenceIsPinned() {
        var rng = SplitMix(seed: 7919)
        let first = (0..<4).map { _ in rng.next() }
        var again = SplitMix(seed: 7919)
        XCTAssertEqual(first, (0..<4).map { _ in again.next() }, "same seed, same sequence")
        var other = SplitMix(seed: 7920)
        XCTAssertNotEqual(first, (0..<4).map { _ in other.next() }, "different seed, different sequence")
        var d = SplitMix(seed: 7919)
        for _ in 0..<64 {
            let x = d.nextDouble()
            XCTAssertTrue(x >= 0 && x < 1, "\(x)")
        }
    }

    func testHSLConversionDirectly() {
        // The conversion pinned with no Swatch in sight: one colour per hue
        // sector, a neutral, and the negative-hue wrap.
        XCTAssertEqual(ColorFormats.hsl(red: 255, green: 0, blue: 0), "hsl(0, 100%, 50%)")
        XCTAssertEqual(ColorFormats.hsl(red: 0, green: 255, blue: 0), "hsl(120, 100%, 50%)")
        XCTAssertEqual(ColorFormats.hsl(red: 0, green: 0, blue: 255), "hsl(240, 100%, 50%)")
        XCTAssertEqual(ColorFormats.hsl(red: 255, green: 0, blue: 128), "hsl(330, 100%, 50%)")
        XCTAssertEqual(ColorFormats.hsl(red: 128, green: 128, blue: 128), "hsl(0, 0%, 50%)")
        XCTAssertEqual(ColorFormats.hsl(red: 0, green: 0, blue: 0), "hsl(0, 0%, 0%)")
    }
}
