# Audit log

Last full audit: **22 Sep 2026** — the day the package joined the Sidewatch family (it came from the general
fleet). The MECHANICAL checks below were run on every source file; the logic review was targeted at the
ImageIO reader, where SVG size was added that day. Add a dated line under *History* when you audit again,
and keep *Known non-issues* current so the next pass skips them.

## What a full audit checks

1. `swift build` warnings (none allowed except those listed under known non-issues) and `swift test` green.
2. Dead code: every `func`/type/property declared once and referenced nowhere in the package or the family.
   Public API is NOT dead because Sidewatch does not call it.
3. Risky patterns: `Timer` without `invalidate`, `addObserver(forName:)` without `removeObserver`, `as!`, `try!`
   outside literal regexes, `fatalError` outside `init?(coder:)`, `print(` outside tests, TODO/FIXME left behind.
4. Docs drift: every name in CLAUDE.md's module map exists; AGENTS.md mirrors CLAUDE.md; README Usage matches the API.

## Result on 22 Sep 2026

- Build: clean under tools 6.2 and Swift 6 language mode (the manifest moved from tools 6.0 that day). Tests: 76 green.
- Risk patterns: none (`try!`, `as!`, `fatalError`, `print` — zero outside tests).
- Added: `ImageFacts.svgSize` — an SVG's width/height attributes (a `px` suffix allowed, other units skipped) or its
  viewBox, read from the first 8 KB; pinned by `testSVGSizeComesFromAttributesOrViewBox`.
- File headers carry their first-commit date now (they read "2026." before).

## Known non-issues

- The one dependency, swift-codec-kit, streams the digests; it is stated in the README.

## History

- 22 Sep 2026 — first family audit; SVG size added.
