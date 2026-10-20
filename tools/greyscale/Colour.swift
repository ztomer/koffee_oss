// tools/greyscale/Colour.swift -- the colours, measured.
//
// A colour's greyscale value is a property of the platform, not of this repo, so it is
// MEASURED here rather than remembered: every colour is resolved through AppKit, in the
// light and the dark appearance, and turned into the greyscale the reader would see.
//
// A table of remembered numbers would be a table that rots, and a check built on a rotted
// table is a check that cannot fail.

import AppKit
import SwiftUI

/// A colour as the reader would see it, in one appearance.
struct Colour: Equatable {
    let name: String
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    let appearance: String

    /// A colour that paints nothing: the shape is absent where the other state paints.
    var isAbsent: Bool { alpha <= 0.002 }

    private var luminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// The greyscale lightness of this colour over a background of the given relative
    /// luminance. The background under a mark is not known at check time, so a separation
    /// is judged over the worst case: black and white.
    func lStar(over background: Double) -> Double {
        let composed = (1 - alpha) * background + alpha * luminance
        return composed > 0.008856 ? 116 * pow(composed, 1.0 / 3.0) - 16 : 903.3 * composed
    }
}

/// A colour reference as the source wrote it, resolved in every appearance.
struct ColourToken {
    let written: String
    let resolved: [Colour]
    let alphaScale: Double

    /// The colour as it is painted: a `.opacity(0.3)` on the reference is part of the
    /// colour, not a modifier of the shape around it.
    init(written: String, resolved: [Colour], alphaScale: Double) {
        self.written = written
        self.alphaScale = alphaScale
        self.resolved = resolved.map {
            Colour(name: $0.name, red: $0.red, green: $0.green, blue: $0.blue,
                   alpha: $0.alpha * alphaScale, appearance: $0.appearance)
        }
    }

    var isAbsent: Bool { resolved.allSatisfy { $0.isAbsent } }

    /// The smallest lightness gap between this colour and another in ONE appearance, over
    /// the worst-case background: the background under a mark is not known at check time, so
    /// the gap is judged over black and over white.
    func separation(in appearance: Int, from other: ColourToken) -> Double {
        guard appearance < resolved.count, appearance < other.resolved.count else {
            return Double.greatestFiniteMagnitude
        }
        let mine = resolved[appearance]
        let theirs = other.resolved[appearance]
        var worst = Double.greatestFiniteMagnitude
        for background in [0.0, 1.0] {
            let gap = abs(mine.lStar(over: background) - theirs.lStar(over: background))
            worst = min(worst, gap)
        }
        return worst
    }
}

/// SwiftUI's standard palette. SwiftUI's set of standard colours is fixed, so this list is
/// the platform's and not the repo's; a colour the repo invents lives in a palette of its
/// own (`KoffeeColor`) and is read from the source, so a new one is found, not missed.
func standardColour(_ name: String) -> Color? {
    switch name {
    case "black": return .black
    case "blue": return .blue
    case "brown": return .brown
    case "clear": return .clear
    case "cyan": return .cyan
    case "gray": return .gray
    case "green": return .green
    case "indigo": return .indigo
    case "mint": return .mint
    case "orange": return .orange
    case "pink": return .pink
    case "purple": return .purple
    case "red": return .red
    case "teal": return .teal
    case "white": return .white
    case "yellow": return .yellow
    case "primary": return .primary
    case "secondary": return .secondary
    default: return nil
    }
}

/// The system colours the app paints with. A name the checker does not know is a name it
/// cannot measure, and a colour it cannot measure is not a pass.
func systemColour(_ name: String) -> NSColor? {
    switch name {
    case "controlBackgroundColor": return .controlBackgroundColor
    case "separatorColor": return .separatorColor
    case "labelColor": return .labelColor
    case "secondaryLabelColor": return .secondaryLabelColor
    case "tertiaryLabelColor": return .tertiaryLabelColor
    case "quaternaryLabelColor": return .quaternaryLabelColor
    case "windowBackgroundColor": return .windowBackgroundColor
    case "textBackgroundColor": return .textBackgroundColor
    case "underPageBackgroundColor": return .underPageBackgroundColor
    case "gridColor": return .gridColor
    case "linkColor": return .linkColor
    case "selectedTextColor": return .selectedTextColor
    case "selectedContentBackgroundColor": return .selectedContentBackgroundColor
    default: return nil
    }
}

/// The appearances an app can be read in. Both are checked: a distinction that survives in
/// light and vanishes in dark is a distinction half the readers cannot see.
let appearances: [(String, NSAppearance)] = [
    ("light", NSAppearance(named: .aqua)!),
    ("dark", NSAppearance(named: .darkAqua)!)
]

/// A colour a palette declared in the source: `enum KoffeeColor { static let green = ... }`.
struct PaletteEntry {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

/// The palettes declared in the sources, read from the sources. A palette the repo adds
/// tomorrow is in here tomorrow, with its numbers, and not a hardcoded guess.
func palettes(in sources: [(String, String)]) -> [String: PaletteEntry] {
    var found: [String: PaletteEntry] = [:]
    let declaration = try? NSRegularExpression(pattern: #"static\s+let\s+(\w+)\s*=\s*Color\(([^)]*)\)"#)
    let enumPattern = try? NSRegularExpression(pattern: #"enum\s+(\w+)\s*\{"#)
    for (_, source) in sources {
        let full = NSRange(source.startIndex..., in: source)
        guard let declaration, let enumPattern else { continue }
        for match in declaration.matches(in: source, range: full) {
            guard let nameRange = Range(match.range(at: 1), in: source),
                  let argumentRange = Range(match.range(at: 2), in: source) else { continue }
            let arguments = String(source[argumentRange])
            guard let numbers = numbers(in: arguments) else { continue }
            // The palette the entry belongs to: the last `enum X {` before it.
            var namespace = ""
            if let prefix = Range(match.range, in: source) {
                let enums = enumPattern.matches(in: source, range: NSRange(prefix.lowerBound..<prefix.upperBound, in: source))
                if let last = enums.last, let enumRange = Range(last.range(at: 1), in: source) {
                    namespace = String(source[enumRange])
                }
            }
            guard !namespace.isEmpty else { continue }
            found["\(namespace).\(source[nameRange])"] = numbers
        }
    }
    return found
}

/// The numbers of a `Color(red:green:blue:)` or `Color(white:)` argument list.
func numbers(in arguments: String) -> PaletteEntry? {
    let parts = arguments.split(separator: ",")
    var values: [Double] = []
    for part in parts {
        let trimmed = part.trimmingCharacters(in: .whitespaces)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        let label = trimmed[trimmed.startIndex..<colon].trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)) else { return nil }
        switch label {
        case "red": values.append(value)
        case "green": values.append(value)
        case "blue": values.append(value)
        case "white": return PaletteEntry(red: value, green: value, blue: value, alpha: 1)
        case "opacity": continue
        default: return nil
        }
    }
    guard values.count == 3 else { return nil }
    return PaletteEntry(red: values[0], green: values[1], blue: values[2], alpha: 1)
}

/// Resolve one written colour reference in every appearance. `nil` means the checker cannot
/// measure it, and a colour it cannot measure is not a pass.
func resolve(_ written: String, palettes: [String: PaletteEntry]) -> [Colour]? {
    var results: [Colour] = []
    for (label, appearance) in appearances {
        var measured: Colour?
        appearance.performAsCurrentDrawingAppearance {
            measured = measure(written, palettes: palettes, appearance: label)
        }
        guard let colour = measured else { return nil }
        results.append(colour)
    }
    return results
}

/// The measurement of one colour reference in one appearance.
func measure(_ written: String, palettes: [String: PaletteEntry], appearance label: String) -> Colour? {
    if let entry = palettes[written] {
        return Colour(name: written, red: entry.red, green: entry.green, blue: entry.blue,
                      alpha: entry.alpha, appearance: label)
    }
    if let literal = literalColour(written) {
        return literal
    }
    if let name = systemColourName(written), let colour = systemColour(name),
       let components = components(of: colour) {
        return Colour(name: written, red: components.0, green: components.1,
                      blue: components.2, alpha: components.3, appearance: label)
    }
    let bare = written.hasPrefix(".") ? String(written.dropFirst()) : written
    if let standard = standardColour(bare), let components = components(of: NSColor(standard)) {
        return Colour(name: written, red: components.0, green: components.1,
                      blue: components.2, alpha: components.3, appearance: label)
    }
    return nil
}

/// The sRGB components of a colour, in the current appearance.
func components(of colour: NSColor) -> (Double, Double, Double, Double)? {
    guard let resolved = colour.usingColorSpace(.sRGB) else { return nil }
    return (resolved.redComponent, resolved.greenComponent, resolved.blueComponent, resolved.alphaComponent)
}

/// A `Color(red:green:blue:)` or `Color(white:)` written in the source.
func literalColour(_ written: String) -> Colour? {
    guard written.hasPrefix("Color("), let entry = numbers(in: String(written.dropFirst("Color(".count).dropLast())) else {
        return nil
    }
    return Colour(name: written, red: entry.red, green: entry.green, blue: entry.blue,
                  alpha: entry.alpha, appearance: appearances[0].0)
}

/// The name in a `Color(nsColor: .name)`.
func systemColourName(_ written: String) -> String? {
    guard written.hasPrefix("Color(nsColor: .") else { return nil }
    let inner = written.dropFirst("Color(nsColor: .".count)
    guard inner.hasSuffix(")") else { return nil }
    return String(inner.dropLast())
}
