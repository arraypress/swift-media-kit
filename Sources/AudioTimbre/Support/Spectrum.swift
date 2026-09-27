//
//  Spectrum.swift
//  AudioTimbre
//
//  A real FFT over a windowed frame, and the two shape measurements taken from it.
//
//  The frame size ADAPTS to the signal rather than being fixed at 2048. A one-shot can
//  be shorter than one frame — a 46 ms hi-hat is 2,028 samples at 44.1 kHz — and the two
//  obvious ways to handle that are both wrong. Refusing to analyse it gives the caller
//  nothing for exactly the material this library exists to describe; zero-padding it up
//  to 2048 and then applying a full-length Hann window tapers the padding rather than the
//  signal, which distorts the very shape being measured. Dropping to the largest power of
//  two that FITS keeps the window matched to real data, at the cost of coarser frequency
//  resolution on short files — which is the right trade, because a 2,028-sample file has
//  no fine spectral detail to lose.
//
//  Created by David Sherlock on 9/11/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Accelerate
import Foundation

/// A reusable real-FFT over frames of one fixed size.
///
/// Not `Sendable` on purpose: it carries scratch buffers and is meant to be created,
/// used and discarded inside a single analysis. Sharing one across concurrent work would
/// corrupt those buffers with no diagnostic.
final class Spectrum {

    /// Frames the analysis prefers, in samples. 46 ms at 44.1 kHz, a 21.5 Hz bin.
    static let preferredFrameSize = 2048

    /// The smallest frame worth transforming, in samples. Below this the bins are so wide
    /// (690 Hz at 44.1 kHz) that a centroid says little, but it is still a real number
    /// rather than a refusal.
    static let minimumFrameSize = 64

    /// Frame length in samples; always a power of two.
    let frameSize: Int

    private let half: Int
    private let fft: vDSP.FFT<DSPSplitComplex>
    private let window: [Float]

    private var windowed: [Float]
    private var realIn: [Float]
    private var imagIn: [Float]
    private var realOut: [Float]
    private var imagOut: [Float]

    /// The frame size to use for a signal of `count` samples: the preferred size, or the
    /// largest power of two that fits, floored at ``minimumFrameSize``.
    static func frameSize(forSignalOf count: Int) -> Int {
        guard count < preferredFrameSize else { return preferredFrameSize }
        var size = minimumFrameSize
        while size * 2 <= count { size *= 2 }
        return size
    }

    /// - Parameter frameSize: samples per frame; must be a power of two of at least 4.
    init?(frameSize: Int) {
        guard frameSize >= 4, frameSize & (frameSize - 1) == 0 else { return nil }
        let log2n = vDSP_Length(log2(Double(frameSize)).rounded())
        guard let fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self) else {
            return nil
        }
        self.frameSize = frameSize
        self.half = frameSize / 2
        self.fft = fft
        self.window = vDSP.window(ofType: Float.self,
                                  usingSequence: .hanningDenormalized,
                                  count: frameSize,
                                  isHalfWindow: false)
        self.windowed = [Float](repeating: 0, count: frameSize)
        self.realIn = [Float](repeating: 0, count: half)
        self.imagIn = [Float](repeating: 0, count: half)
        self.realOut = [Float](repeating: 0, count: half)
        self.imagOut = [Float](repeating: 0, count: half)
    }

    /// Magnitude spectrum of one frame — ``frameSize`` / 2 bins, bin *k* centred on
    /// `k * sampleRate / frameSize` Hz.
    ///
    /// - Parameter frame: exactly ``frameSize`` samples. Shorter input is zero-filled,
    ///   which only happens for the final hop of a signal.
    func magnitudes(of frame: ArraySlice<Float>) -> [Float] {
        let take = min(frame.count, frameSize)
        for i in 0..<take { windowed[i] = frame[frame.startIndex + i] }
        if take < frameSize { for i in take..<frameSize { windowed[i] = 0 } }

        // Remove the frame's DC offset BEFORE windowing. Excluding bin 0 afterwards is not
        // enough on its own: a Hann window's own transform is three bins wide, so a constant
        // offset lands half its energy in bin 1 as well, at a frequency of almost nothing.
        // Measured on a 1 kHz sine carrying a 0.5 offset, bin 0 excluded but the mean left
        // in: the centroid reads 804 Hz instead of 1,000. Subtracting the mean first removes
        // the cause rather than one of its symptoms.
        if take > 0 {
            let mean = vDSP.mean(windowed[0..<take])
            for i in 0..<take { windowed[i] -= mean }
        }

        vDSP.multiply(windowed, window, result: &windowed)

        var magnitudes = [Float](repeating: 0, count: half)
        windowed.withUnsafeBufferPointer { source in
            source.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { interleaved in
                realIn.withUnsafeMutableBufferPointer { rIn in
                    imagIn.withUnsafeMutableBufferPointer { iIn in
                        realOut.withUnsafeMutableBufferPointer { rOut in
                            imagOut.withUnsafeMutableBufferPointer { iOut in
                                var input = DSPSplitComplex(realp: rIn.baseAddress!, imagp: iIn.baseAddress!)
                                var output = DSPSplitComplex(realp: rOut.baseAddress!, imagp: iOut.baseAddress!)
                                vDSP_ctoz(interleaved, 2, &input, 1, vDSP_Length(half))
                                fft.forward(input: input, output: &output)
                                vDSP_zvabs(&output, 1, &magnitudes, 1, vDSP_Length(half))
                            }
                        }
                    }
                }
            }
        }
        return magnitudes
    }
}
