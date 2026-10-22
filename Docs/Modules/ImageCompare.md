# Swift Image Compare

Two versions of an image — a file before and after a change — decoded and compared: each side's
facts, and which pixels differ.

```swift
import ImageCompare

let result = ImageComparison.compare(old: headBytes, new: diskBytes)   // either may be nil
result.old?.width, result.new?.width          // pixels (points for an SVG)
result.new?.byteCount, result.new?.typeIdentifier, result.new?.frameCount
if let d = result.difference {                // both read, one size
    d.changedPixels, d.changedFraction        // 312, 0.0019
    d.changedBounds                           // (40, 12, 18, 18), from the top-left
    d.mask                                    // white where a pixel changed, for tinting
} else if result.sizesDiffer {
    // 1024×1024 → 512×512: shown side by side, not compared pixel by pixel
}
```

## Features

- **Pixels, not bytes** — both pictures are drawn into 8-bit premultiplied sRGB and compared a pixel at a time, so the same picture saved as PNG and as TIFF does not differ; a change of opacity alone does
- **Where it changed** — the count, the share, the smallest rectangle holding every change (from the top-left), and a grayscale mask to draw the changes in any colour
- **Facts for each side** — size in pixels, file size, type, frame count; an animation is compared by its first frame
- **SVG** — ImageIO does not read it; where AppKit is present `NSImage` does, and the drawing is rasterized at 2 pixels a point, so two versions are compared at one resolution; its size is reported in points
- **Bounded** — pictures over 40 megapixels are not compared pixel by pixel (`pixelLimit`; `difference(_:_:limit:)` takes another)
- **No UI** — CoreGraphics and ImageIO (and AppKit for SVG on macOS); the view that shows a comparison is the caller's

## Measured

Generated pictures with known changes: one pixel at (3, 5) is found at (3, 5) with a mask white there and nowhere
else; three scattered pixels give their bounding rectangle; opaque black against clear black counts; PNG against
TIFF of the same pixels is no change; 10×8 against 20×16 is a size difference, not a comparison; a two-frame GIF is
compared by its first frame; an SVG rectangle 10×5 points that changed colour is 200 changed pixels at (20, 10).
Eight mutants (alpha ignored, bounds, vector scale, the limit, last frame, sizes, mask, never compared) fail them.
