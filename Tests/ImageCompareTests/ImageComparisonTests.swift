//
//  ImageComparisonTests.swift
//  ImageCompareTests
//
//  Two versions of an image compared: pixels, not bytes; the changed region from the top-left;
//  sizes, formats, frames and vector drawings.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ImageCompare

final class ImageComparisonTests: XCTestCase {
    /// A `width`×`height` picture filled with `fill`, then each of `marks` (x, y from the top-left,
    /// colour) painted as one pixel.
    private func picture(
        _ width: Int, _ height: Int, fill: (UInt8, UInt8, UInt8, UInt8) = (20, 40, 200, 255),
        marks: [(Int, Int, (UInt8, UInt8, UInt8, UInt8))] = []
    ) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) { (bytes[i * 4], bytes[i * 4 + 1], bytes[i * 4 + 2], bytes[i * 4 + 3]) = fill }
        for (x, y, c) in marks { let i = (y * width + x) * 4; (bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]) = c }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    /// `frames` encoded as `type` (one frame, or an animation for GIF).
    private func encoded(_ frames: [CGImage], as type: UTType) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, frames.count, nil)!
        for frame in frames { CGImageDestinationAddImage(destination, frame, nil) }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
    private func png(_ image: CGImage) -> Data { encoded([image], as: .png) }

    func testIdenticalPicturesDifferNowhere() throws {
        let r = ImageComparison.compare(old: png(picture(10, 8)), new: png(picture(10, 8)))
        let d = try XCTUnwrap(r.difference)
        XCTAssertEqual(d.changedPixels, 0)
        XCTAssertEqual(d.totalPixels, 80)
        XCTAssertNil(d.changedBounds)
        XCTAssertNil(d.mask)
        XCTAssertEqual(d.changedFraction, 0)
    }

    func testOnePixelChangedIsFoundWhereItIsCountedFromTheTopLeft() throws {
        let r = ImageComparison.compare(old: png(picture(10, 8)), new: png(picture(10, 8, marks: [(3, 5, (255, 0, 0, 255))])))
        let d = try XCTUnwrap(r.difference)
        XCTAssertEqual(d.changedPixels, 1)
        XCTAssertEqual(d.changedBounds, CGRect(x: 3, y: 5, width: 1, height: 1))
        XCTAssertEqual(d.changedFraction, 1.0 / 80)
        // The mask is white at that pixel only, in the same top-left rows.
        let mask = try XCTUnwrap(d.mask)
        let bytes = try XCTUnwrap(mask.dataProvider?.data as Data?)
        XCTAssertEqual(bytes[5 * mask.bytesPerRow + 3], 255)
        XCTAssertEqual(bytes.filter { $0 == 255 }.count, 1)
    }

    func testTheChangedRegionHoldsEveryChange() throws {
        let marks = [(1, 1, (0, 0, 0, 255)), (7, 2, (0, 0, 0, 255)), (4, 6, (0, 0, 0, 255))] as [(Int, Int, (UInt8, UInt8, UInt8, UInt8))]
        let d = try XCTUnwrap(ImageComparison.compare(old: png(picture(10, 8)), new: png(picture(10, 8, marks: marks))).difference)
        XCTAssertEqual(d.changedPixels, 3)
        XCTAssertEqual(d.changedBounds, CGRect(x: 1, y: 1, width: 7, height: 6))
    }

    /// Opaque black against clear black: premultiplied, the colour channels are 0 in both, and
    /// only the opacity differs.
    func testOpacityAloneIsAChange() throws {
        let black: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 255)
        let d = try XCTUnwrap(
            ImageComparison.compare(
                old: png(picture(4, 4, fill: black)), new: png(picture(4, 4, fill: black, marks: [(0, 0, (0, 0, 0, 0))]))
            ).difference)
        XCTAssertEqual(d.changedPixels, 1)
    }

    func testPixelsAreComparedNotBytes() throws {
        let image = picture(12, 9, marks: [(2, 2, (250, 250, 0, 255))])
        let r = ImageComparison.compare(old: png(image), new: encoded([image], as: .tiff))
        XCTAssertEqual(r.difference?.changedPixels, 0, "the same pixels saved as PNG and as TIFF")
        XCTAssertEqual(r.old?.typeIdentifier, UTType.png.identifier)
        XCTAssertEqual(r.new?.typeIdentifier, UTType.tiff.identifier)
        XCTAssertNotEqual(r.old?.byteCount, r.new?.byteCount)
        XCTAssertEqual(r.old?.byteCount, png(image).count)
    }

    func testDifferentSizesAreSaidAndNotCompared() {
        let r = ImageComparison.compare(old: png(picture(10, 8)), new: png(picture(20, 16)))
        XCTAssertTrue(r.sizesDiffer)
        XCTAssertNil(r.difference)
        XCTAssertEqual(r.old?.width, 10)
        XCTAssertEqual(r.new?.height, 16)
        XCTAssertFalse(ImageComparison.compare(old: png(picture(10, 8)), new: png(picture(10, 8))).sizesDiffer)
    }

    func testAnAddedOrUnreadableSideIsNil() {
        let added = ImageComparison.compare(old: nil, new: png(picture(5, 5)))
        XCTAssertNil(added.old)
        XCTAssertEqual(added.new?.width, 5)
        XCTAssertNil(added.difference)
        XCTAssertFalse(added.sizesDiffer)
        XCTAssertNil(ImageComparison.compare(old: Data("not an image".utf8), new: nil).old)
    }

    func testAnAnimationIsComparedByItsFirstFrameAndCounted() throws {
        let gif = encoded([picture(6, 6), picture(6, 6, marks: [(1, 1, (255, 255, 255, 255))])], as: .gif)
        let r = ImageComparison.compare(old: gif, new: encoded([picture(6, 6)], as: .gif))
        XCTAssertEqual(r.old?.frameCount, 2)
        XCTAssertEqual(r.new?.frameCount, 1)
        XCTAssertEqual(r.difference?.changedPixels, 0, "first frames match")
    }

    func testAnSVGIsADrawingInPointsComparedAtTwicePixels() throws {
        func svg(_ colour: String) -> Data {
            Data(
                #"<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20"><rect width="40" height="20" fill="white"/><rect x="10" y="5" width="10" height="5" fill="\#(colour)"/></svg>"#
                    .utf8)
        }
        let r = ImageComparison.compare(old: svg("red"), new: svg("blue"))
        let old = try XCTUnwrap(r.old)
        XCTAssertTrue(old.isVector)
        XCTAssertEqual(old.typeIdentifier, "public.svg-image")
        XCTAssertEqual([old.width, old.height, old.image.width, old.image.height], [40, 20, 80, 40])
        let d = try XCTUnwrap(r.difference)
        XCTAssertEqual(d.changedPixels, 20 * 10, "the 10×5-point rect at 2 pixels a point")
        XCTAssertEqual(d.changedBounds, CGRect(x: 20, y: 10, width: 20, height: 10))
    }

    func testPicturesOverTheLimitAreNotCompared() {
        XCTAssertNil(ImageComparison.difference(picture(10, 10), picture(10, 10), limit: 99))
        XCTAssertNotNil(ImageComparison.difference(picture(10, 10), picture(10, 10), limit: 100))
    }
}
