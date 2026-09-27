# Swift Audio Timbre

What a sound *sounds like*, as measured facts — brightness, texture, pitch, envelope, level
and stereo width. Pure Accelerate, no model, no network, no dependencies.

The describing half of [swift-audio-forge](https://github.com/arraypress/swift-audio-forge),
which does the cutting.

```swift
import AudioTimbre

let timbre = try TimbreAnalyzer.analyze(fileAt: url)

timbre.brightness            // .warm
timbre.spectralCentroidHz    // 1894.2
timbre.spectralBandwidthHz   // 620.4   — how tightly the energy is gathered
timbre.spectralRolloffHz     // 3180.0  — where it stops
timbre.pitch?.name           // "C5"
timbre.timeToPeakMs          // 8.0  — always measured
timbre.attackMs              // 8.0  — nil when that time is not an onset
timbre.decayMs               // 1180.0
print(timbre.summary)
```

```
1.42 s, 44.1 kHz stereo
warm (centroid 1894 Hz, range 1620-2210) - tonal (flatness 0.008)
pitched C5 (523.3 Hz, +4 cents, confidence 0.87)
attack 8 ms, decay 1180 ms, sustain 0.34
peak -1.2 dBFS, RMS -18.4 dBFS
stereo: correlation 0.96, S/M -14.2 dB
```

## Why

Apple's sound classifier works on a fixed three-second window and returns **nothing at all**
below it. MusicUnderstanding needs two beats before it will name a tempo. Both are correct
for what they do, and both leave a 400 ms one-shot — the most common object in any sample
library — described by nothing but its file size.

Direct measurement has no such floor. A spectral centroid is well defined over 64 samples,
an attack time over two. Point this at a 40 ms hi-hat and it answers.

## What it will not do

**Name the sound.** No instrument, no genre, no "this is a kick". Classification belongs to
a trained model with held-out accuracy behind it; measuring and guessing are different jobs
and this only does the first.

The two are complementary rather than competing: a classifier says *what* a file is, this
says what it is *like*. Sixteen thousand files in a library are labelled `kick`; this is
what separates one from another.

## Every word ships beside its number

`brightness` never appears without `spectralCentroidHz`, `texture` never without
`spectralFlatness`, `pitch` never without `pitchConfidence`. The words are a convenience
for reading; the numbers are the measurement. Disagree with a boundary and you still have
the figure.

Where a word cannot be justified, there isn't one: `StereoImage` reports correlation and
Side/Mid as numbers with no adjective attached, because no boundary set for stereo width
was available to cite and inventing one would dress a guess as a measurement.

## Pitch classes

`HarmonicAnalyzer` folds the spectrum onto the twelve pitch classes. Separate from
`TimbreAnalyzer` because it needs a 16,384-point frame where the timbre measurements
need 2,048 — eight times the work, for an answer a drum-library sweep does not want.

```swift
let harmony = try HarmonicAnalyzer.analyze(fileAt: url)
harmony.dominantPitchClasses   // ["C", "E", "G"]
harmony.chroma.salience        // 41.2 — how far the top stands above the middle

// Per bar, with boundaries from a beat tracker (muse --full reports them)
let bars = try HarmonicAnalyzer.analyze(channels: ch, sampleRate: sr, segments: spans)
```

**There is no chord namer, and that is a decision taken after building one.** It had 108
templates, cosine matching, and gates on salience and confidence. Measured against a
commercial pack it **named nine of twenty kick drums as "F"** — a kick is one strong
fundamental, and nothing in a sample library is more salient than that. Worse, the pitched
one-shots it *did* name mostly carried a single pitch class: it was reading one note's
harmonic series — a root, a fifth and a major third — as a major triad. It was not
identifying chords, it was identifying fundamentals, which the pitch estimator already does
and does better.

Every threshold available over this feature was measured and none separate a kick from a
chord:

| | pitched one-shots | drum one-shots | pitched loops | drum loops |
|---|---|---|---|---|
| median salience | 5.94 | 1.75 | **2.09** | **1.82** |

A pitched loop and a drum loop are the same shape. Entropy is worse — 0.02 for a clean A
minor loop against 0.03 for a hi-hat. Recover the estimator with
`git log --all -- Sources/AudioTimbre/Core/ChordEstimator.swift` if a future version brings
beat-synchronous segmentation, bass-aware templates or a trained model; it does not need a
better threshold.

## A time-to-peak is not always an attack

Time to the loudest point is the attack on a one-shot and wherever the
arrangement peaked on anything longer. A real 5.65-second pad loop measured
**"attack 3040 ms"** — describing one bar being marginally louder than the one
before it.

So the figure is always reported as `timeToPeakMs`, and the WORD is gated the
same way a pitch estimate is — refused with a reason when the shape does not
support it:

```
Kick - 009.wav   attack 87 ms, decay 286 ms, sustain 0.65
Pad Loop.wav     peaks at 3040 ms (peaksLate, not an attack), no decay, sustain 1.00
```

`reArticulates` is the other reason: a loop struck four times has four attacks
and the file has none.

## Centroid, bandwidth and rolloff answer different questions

Measured on a 2 kHz tone with white noise mixed under it:

| hiss | centroid | rolloff | bandwidth |
|---|---|---|---|
| none | 2000 | 2024 | 49 |
| 0.001 | 2122 | **2024** | 1280 |
| 0.010 | 3093 | **2024** | 3679 |

**Rolloff is the robust one**, which is the opposite of how it looks. It holds through a
tenfold rise in noise while the centroid drifts 55%, because a centroid is pulled by every
one of a thousand high bins and a rolloff ignores a floor until it carries a real share of
the magnitude. Read centroid for brightness *including* the noise, rolloff for where the
sound itself stops, bandwidth for how tightly the energy is gathered.

## Calibration

`Brightness` uses the boundaries from
[serum-mcp](https://github.com/Celian-mrc/serum-mcp)'s `sample_analysis.py` — 500 / 2,000 /
6,000 Hz — checked here against 360 one-shots across twelve classes, where they hold.

`Texture` does **not**. Those boundaries were re-measured, because the inherited pair put 22
of 25 claps in the same bucket as a kick. Median flatness per class, 30 files each:

| | | | |
|---|---|---|---|
| sub bass 0.001 | kick 0.003 | clap 0.071 | ride 0.162 |
| crash 0.177 | open hat 0.234 | snare 0.380 | closed hat 0.601 |

0.025 and 0.25 sit in the gaps between those clusters. The reason the inherited pair did not
transfer is that this library measures flatness **per frame and takes the median**, where the
reference takes one transform over the whole file — a different method gives different
numbers on the same audio, and a threshold does not survive the crossing.

The onset horizon — how far into a file a peak may sit and still be an onset —
is a judgement with a number, like the bucket boundaries, and measured the same
way: kick 10%, clap 10%, pluck 7%, snare 3%, all plainly onsets, against a pad
loop at 54%, a lead loop at 25% and a sub-bass swell at 90%, none of which are.

## Measured

**Pitch agrees with the filename on 58 of 60** note-labelled files from a commercial pack
(`Sub Bassline - 001 - C.wav` → C1). Both misses are loops rather than one-shots, each a
semitone or two under the labelled key — the loudest window of a bassline need not sit on
the root.

Four findings came from real audio that no synthetic signal produced:

- **A 50 Hz pitch floor**, inherited, is above the fundamental of a sub bass. C1 is 32.7 Hz
  and D1 is 36.7, so a sub, a pluck and a lead all had correlation curves with no peak in
  range at all and came back unpitched. The floor is 20 Hz.
- **A fallback returning the edge of the search range.** With no interior peak, the tallest
  correlation sits at the shortest lag searched — 44,100 / 29 = 1,520.7 Hz — so an F-minor
  lead was reported as F#6 with 0.92 confidence. An edge of the window is an artifact of the
  window.
- **A raw autocorrelation is biased toward short lags**, because the overlap shrinks as the
  lag grows. On a 110 Hz sine, lag 29 outscored the true lag 401 on term count alone. Each
  lag is normalised by the energy of the spans it compares.
- **A time-to-peak is not an attack**, which only showed once real loops went through it —
  see the section above.

## Tested

85 tests against signals whose answers are known before they are measured: a 440 Hz sine has
a centroid of 440 Hz, a flatness near zero and a pitch of A4 — by construction, not
approximately. An exponential with a 100 ms time constant reaches −60 dB after 6.908 time
constants, which is arithmetic.

Mutation-verified: restoring the pitch floor, the boundary fallback, the raw correlation,
the DC removal or the bin-0 exclusion each fails the suite.

Six cases run against a real sample pack and assert **rates** rather than single files — one
kick proves nothing, a rate over thirty of them is a claim:

```sh
AUDIOTIMBRE_SAMPLES=~/Samples/SomePack swift test
```

## Waveform and level, streamed

Two readers for files too long to decode whole (a 44.1 kHz stereo hour is 635 million floats):

```swift
let peaks = try await Waveform.peaks(fileAt: url, bins: 1024)   // 0…1 per bin, the loudest bin 1; 8 kHz mono, first 20 minutes
let level = try await Level.measure(fileAt: url)                 // the file's own samples at its own rate
level.peakDbfs        // -0.2, nil for silence
level.clippedSamples  // samples AT the 16-bit rails
level.clippedShare    // 0…1 of what was read
```

## Requirements

macOS 14+ / iOS 17+, Swift 6.2. Accelerate for the maths; AVFoundation only to decode a file
into samples, so everything below `AudioDecoder` takes `[[Float]]` and can be tested in
memory.

## Licence

MIT.
