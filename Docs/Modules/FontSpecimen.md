# Swift Font Specimen

A font file's face and the lines of a specimen, read from the file's bytes with nothing installed.

```swift
import FontSpecimen

guard let specimen = FontSpecimen(fileAt: url) else { return }  // .ttf, .otf, .woff, .woff2
print(specimen.fullName)  // "JetBrains Mono Regular"
for line in specimen.lines {
    let font = line.role == .label || line.role == .title ? uiFont(line.size) : specimen.font(size: line.size)
    draw(line.text, in: font)
}
```

## Features

- **Any font file CoreText reads**: TrueType, OpenType, WOFF and WOFF2, straight from the bytes. The face is never registered, so previewing a font installs nothing.
- **The specimen's lines, not its drawing**: the file name, the alphabet, digits and punctuation, then one sentence at 72, 54, 40, 30, 24, 19, 15 and 12 points, each with a role, so any renderer (AppKit, UIKit, SwiftUI, a PDF) styles them its own way.
- **Fast**: 2 to 6 ms for a 200 KB face on Apple silicon, against hundreds of milliseconds to bring up a web view for an `@font-face` page.
- **Zero dependencies**: CoreText and Foundation; every Apple platform, headless.
