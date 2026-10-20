// tools/greyscale/main.swift -- the greyscale check.
//
// THE GATE. A "visual distinction" is a set of mutually exclusive states of the app that the
// UI tells apart by COLOUR. The house rule is that no distinction rides on one channel:
// colour reinforces, shape and text carry. This checker asks the greyscale half of that
// question -- if the colour channel is removed, is the state still identifiable?
//
// It answers in three parts, in this order:
//
//   1. DISCOVER. The states are found in the sources (Source.swift): an if/else chain, a
//      switch, or a ternary chain whose branches paint different colours. Nothing is listed
//      by hand, so a distinction added tomorrow is found tomorrow and one that is removed
//      stops being counted. A hand-kept list is a list that goes stale, and a stale list is
//      a gate that checks the wrong thing.
//
//   2. MEASURE. Every colour is resolved through AppKit (Colour.swift), in the light AND the
//      dark appearance, and turned into the greyscale the reader would actually see
//      (CIE L*). The values are measured, not remembered: a colour's greyscale value is a
//      property of the platform, and a table of remembered numbers is a table that rots.
//
//   3. JUDGE (Judge.swift). Two states of one distinction are told apart in greyscale when
//      their colours are far enough apart, or when they differ in another channel -- text,
//      symbol, value, shape -- or when one of them paints nothing where the other paints.
//
// A distinction carried by colour alone, whose colours are closer than the threshold, is RED,
// and it is named: the file, the declaration, the two states, their colours, the gap.
//
// Usage: greyscale --root <repo> [--list]

import Foundation

// MARK: - Arguments

var root = FileManager.default.currentDirectoryPath
var listOnly = false
let arguments = Array(CommandLine.arguments.dropFirst())
var cursor = 0
while cursor < arguments.count {
    if arguments[cursor] == "--root", cursor + 1 < arguments.count {
        root = arguments[cursor + 1]
        cursor += 2
        continue
    }
    if arguments[cursor] == "--list" {
        listOnly = true
        cursor += 1
        continue
    }
    cursor += 1
}

// MARK: - The sources that hold the UI

/// Where the app's own views live. LiquidContainer paints one continuous surface and states
/// nothing, but it is read too: a distinction added there is a distinction the app shows.
let sourceDirectories = ["Koffee", "LiquidContainer/Sources"]

var sources: [(String, String)] = []
for directory in sourceDirectories {
    let path = root + "/" + directory
    guard let enumerator = FileManager.default.enumerator(atPath: path) else { continue }
    for case let relative as String in enumerator where relative.hasSuffix(".swift") {
        let full = path + "/" + relative
        guard let source = try? String(contentsOfFile: full, encoding: .utf8) else { continue }
        sources.append((directory + "/" + relative, source))
    }
}
sources.sort { $0.0 < $1.0 }

if sources.isEmpty {
    print("✗ greyscale: no Swift sources under \(root) -- nothing to check")
    exit(2)
}

// MARK: - Discover, measure, judge

let palette = palettes(in: sources)
var found: [Group] = []
for (path, source) in sources {
    found += groups(in: path, source: source)
}
let foundDistinctions = distinctions(from: found, palettes: palette)
let (failures, closest) = judge(foundDistinctions, all: foundDistinctions)
let painted = foundDistinctions.filter(\.paints)

// MARK: - Report

if listOnly {
    for distinction in foundDistinctions {
        let colours = distinction.states.map { $0.colours.map(\.written).joined(separator: "+") }
        let texts = distinction.states.map { $0.strings.joined(separator: "+") }
        print("\(distinction.file):\(distinction.lines.first ?? 0) [\(distinction.key)] named=\(distinction.named)")
        for (index, condition) in distinction.conditions.enumerated() {
            let colour = index < colours.count ? colours[index] : ""
            let text = index < texts.count ? texts[index] : ""
            print("    \(condition)  ->  colour: \(colour)  text: \(text)")
        }
    }
    exit(0)
}

if failures.isEmpty {
    var margin = "no pair was close"
    if let closest {
        margin = String(format: "the closest pair is %.1f L* apart (%@)", closest.0, closest.1)
    }
    print("ok: \(painted.count) visual distinctions in \(sources.count) files survive greyscale; \(margin)")
    exit(0)
}

let broken = Set(failures.map { $0.file + "#" + $0.key })
print("✗ greyscale: \(broken.count) visual distinction(s) do not survive greyscale:")
for failure in failures {
    print("  \(failure.file):\(failure.line)")
    print("    states: \(failure.first) | \(failure.second)")
    print("    colours: \(failure.firstColour) vs \(failure.secondColour)")
    print("    \(failure.reason)")
}
print("")
print("  A distinction that rides on colour alone is invisible to a reader who cannot see the")
print("  hue. Give the states another channel (a word, a symbol, a shape), or pick colours that")
print("  differ in lightness as well as in hue.")
exit(1)
