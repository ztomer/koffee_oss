// tools/greyscale/Source.swift -- finding the distinctions.
//
// A "visual distinction" is a set of mutually exclusive states of the app that the UI tells
// apart by COLOUR. They are FOUND here, in the sources: an if/else chain, a switch, or a
// ternary chain whose branches paint different colours.
//
// Nothing is listed by hand. A hand-kept list is a list that goes stale, and a stale list is
// a gate that checks the wrong thing; a distinction added tomorrow is found tomorrow and one
// that is removed stops being counted.

import Foundation

/// A line of source with the comments blanked out (a colour named in a comment is not a
/// colour in the app) and the string literals left alone (they are channels of their own).
struct Line {
    let text: String
    let trimmed: String
    let depthBefore: Int
    let depthAfter: Int
}

func scanLines(_ source: String) -> [Line] {
    var lines: [Line] = []
    var current = ""
    var depth = 0
    var depthAtStart = 0
    var blockComment = 0
    var inString = false
    var inMultiline = false
    var escaped = false
    let characters = Array(source)
    var index = 0

    func finish() {
        lines.append(Line(text: current, trimmed: current.trimmingCharacters(in: .whitespacesAndNewlines),
                          depthBefore: depthAtStart, depthAfter: depth))
        current = ""
        depthAtStart = depth
    }

    while index < characters.count {
        let character = characters[index]
        let next = index + 1 < characters.count ? characters[index + 1] : "\0"

        if blockComment > 0 {
            if character == "/" && next == "*" { blockComment += 1; current.append("  "); index += 2; continue }
            if character == "*" && next == "/" { blockComment -= 1; current.append("  "); index += 2; continue }
            current.append(character == "\n" ? "\n" : " ")
            index += 1
            continue
        }
        if inMultiline {
            if character == "\"" && next == "\"", index + 2 < characters.count, characters[index + 2] == "\"" {
                current += "\"\"\""
                index += 3
                inMultiline = false
                continue
            }
            current.append(character)
            index += 1
            continue
        }
        if inString {
            if escaped { escaped = false; current.append(character); index += 1; continue }
            if character == "\\" { escaped = true; current.append(character); index += 1; continue }
            if character == "\"" { inString = false }
            current.append(character)
            index += 1
            continue
        }
        if character == "/" && next == "/" {
            while index < characters.count, characters[index] != "\n" { current += " "; index += 1 }
            continue
        }
        if character == "/" && next == "*" { blockComment = 1; current.append("  "); index += 2; continue }
        if character == "\"", next == "\"", index + 2 < characters.count, characters[index + 2] == "\"" {
            inMultiline = true
            current += "\"\"\""
            index += 3
            continue
        }
        if character == "\"" { inString = true; current.append(character); index += 1; continue }
        if character == "{" { depth += 1 }
        if character == "}" { depth -= 1 }
        current.append(character)
        if character == "\n" { finish() }
        index += 1
    }
    if !current.isEmpty { finish() }
    return lines
}

/// The string literals in a piece of text: the text channel, when a state carries one.
func stringLiterals(in text: String) -> [String] {
    var found: [String] = []
    var current = ""
    var inString = false
    var escaped = false
    for character in text {
        if inString {
            if escaped { escaped = false; current.append(character); continue }
            if character == "\\" { escaped = true; continue }
            if character == "\"" { inString = false; found.append(current); current = ""; continue }
            current.append(character)
            continue
        }
        if character == "\"" { inString = true; current = "" }
    }
    return found
}

/// The question marks of a line that are not part of `??` and are not inside a string.
func questionMarks(in text: String) -> [String.Index] {
    var found: [String.Index] = []
    var inString = false
    var escaped = false
    var index = text.startIndex
    while index < text.endIndex {
        let character = text[index]
        let next = text.index(after: index)
        if inString {
            if escaped { escaped = false }
            else if character == "\\" { escaped = true }
            else if character == "\"" { inString = false }
            index = next
            continue
        }
        if character == "\"" { inString = true; index = next; continue }
        if character == "?" {
            if next < text.endIndex, text[next] == "?" {
                index = text.index(after: next)
                continue
            }
            // Optional chaining (`profile?.name`) is not a ternary.
            if next < text.endIndex, text[next] == "." {
                index = text.index(after: next)
                continue
            }
            found.append(index)
        }
        index = next
    }
    return found
}

/// One state of a distinction: the condition that selects it and the text of the branch that
/// paints it.
struct State {
    let condition: String
    let text: String
    let line: Int
}

/// A branch structure in the source: an if/else chain, a switch, or a ternary chain.
struct Group {
    let file: String
    let key: String
    let states: [State]
    let line: Int
    /// The states are NAMED on the screen: the switch's subject is rendered as its own raw
    /// value, so each state carries its name in words. Swift forbids two cases of an enum
    /// with the same raw value, so the names differ and the states are told apart whatever
    /// the colour does.
    var named = false
}

/// The colour references written in a piece of text.
func colourReferences(in text: String, palettes: Set<String>) -> [String] {
    var found: [String] = []
    let characters = Array(text)
    var index = 0
    while index < characters.count {
        let character = characters[index]
        if character == "C", index + 6 <= characters.count,
           Array(characters[index..<(index + 6)]) == Array("Color(") {
            var depth = 0
            var literal = ""
            while index < characters.count {
                let inner = characters[index]
                literal.append(inner)
                if inner == "(" { depth += 1 }
                if inner == ")" {
                    depth -= 1
                    if depth == 0 { index += 1; break }
                }
                index += 1
            }
            found.append(literal)
            continue
        }
        if character == ".", index + 1 < characters.count, characters[index + 1].isLetter {
            var name = ""
            var cursor = index + 1
            while cursor < characters.count, characters[cursor].isLetter || characters[cursor].isNumber {
                name.append(characters[cursor])
                cursor += 1
            }
            if standardColour(name) != nil { found.append(".\(name)") }
            index = cursor
            continue
        }
        if character.isLetter || character == "_" {
            var name = ""
            var cursor = index
            while cursor < characters.count, characters[cursor].isLetter || characters[cursor].isNumber || characters[cursor] == "_" {
                name.append(characters[cursor])
                cursor += 1
            }
            if cursor < characters.count, characters[cursor] == ".", cursor + 1 < characters.count,
               characters[cursor + 1].isLetter {
                var member = ""
                var memberCursor = cursor + 1
                while memberCursor < characters.count, characters[memberCursor].isLetter || characters[memberCursor].isNumber {
                    member.append(characters[memberCursor])
                    memberCursor += 1
                }
                if palettes.contains(name) {
                    found.append("\(name).\(member)")
                    cursor = memberCursor
                }
            }
            index = cursor
            continue
        }
        index += 1
    }
    return found
}

/// The opacity that follows a colour reference: a 15% yellow is not the yellow a reader
/// compares with a solid one.
func opacityScale(after reference: String, in text: String) -> Double {
    guard let range = text.range(of: reference) else { return 1 }
    let rest = text[range.upperBound...]
    guard rest.hasPrefix(".opacity(") else { return 1 }
    var digits = ""
    for character in rest.dropFirst(".opacity(".count) {
        if character.isNumber || character == "." { digits.append(character) } else { break }
    }
    return Double(digits) ?? 1
}

/// The shape of a branch with the colours and the strings taken out: what is left is the
/// other channel, and two states that differ in it are told apart without colour.
///
/// Only the WORDS are kept. Punctuation is not a channel: a closing parenthesis left over
/// from the parse is not a difference between two states, and a comparison that reads it as
/// one would skip a pair it should judge.
func shapeOnly(_ text: String, palettes: Set<String>) -> String {
    var stripped = text
    for literal in stringLiterals(in: text) {
        stripped = stripped.replacingOccurrences(of: literal, with: " ")
    }
    for reference in colourReferences(in: stripped, palettes: palettes) {
        stripped = stripped.replacingOccurrences(of: reference, with: " ")
        // The opacity belongs to the colour: a 15% green is the same green, paler.
        while let range = stripped.range(of: ".opacity("),
              let end = stripped[range.upperBound...].firstIndex(where: { $0 == ")" }) {
            let from = range.lowerBound
            stripped.replaceSubrange(from..<stripped.index(after: end), with: " ")
        }
    }
    stripped = stripped.replacingOccurrences(of: "Color(", with: " ")
        .replacingOccurrences(of: "NSColor(", with: " ")
    var words: [String] = []
    var current = ""
    for character in stripped {
        if character.isLetter || character.isNumber || character == "_" {
            current.append(character)
            continue
        }
        if !current.isEmpty, current.first?.isLetter == true { words.append(current) }
        current = ""
    }
    if !current.isEmpty, current.first?.isLetter == true { words.append(current) }
    return words.joined(separator: " ")
}

/// The condition of a ternary: the text between the last delimiter and the `?`.
func ternaryCondition(in text: String, before question: String.Index) -> String {
    var start = text.startIndex
    var scan = text.startIndex
    while scan < question {
        let character = text[scan]
        let next = text.index(after: scan)
        let previous = scan > text.startIndex ? text[text.index(before: scan)] : " "
        // `=` is a delimiter only when it assigns; `==`, `<=`, `>=` and `!=` are comparisons.
        let comparison = character == "=" && (previous == "<" || previous == ">" || previous == "!" || previous == "=")
            || (character == "=" && next < text.endIndex && text[next] == "=")
        if !comparison, character == "=" || character == "(" || character == "," || character == ";" || character == "{" {
            start = next
        }
        scan = next
    }
    return text[start..<question].trimmingCharacters(in: .whitespacesAndNewlines)
}

/// The two halves of a ternary: what the true branch is, and what the false branch is.
func splitTernary(_ text: Substring) -> (String, String) {
    var depth = 0
    var index = text.startIndex
    while index < text.endIndex {
        let character = text[index]
        if character == "(" || character == "[" { depth += 1 }
        if character == ")" || character == "]" {
            if depth == 0 { break }
            depth -= 1
        }
        if character == ":" && depth == 0 {
            let head = text[text.startIndex..<index].trimmingCharacters(in: .whitespacesAndNewlines)
            return (head, String(text[text.index(after: index)...]))
        }
        index = text.index(after: index)
    }
    return (String(text).trimmingCharacters(in: .whitespacesAndNewlines), "")
}

/// The states of a ternary chain, innermost last.
func ternaryStates(_ text: String) -> [(String, String)] {
    guard let question = questionMarks(in: text).first else { return [] }
    let (thenText, elseText) = splitTernary(text[text.index(after: question)...])
    var states: [(String, String)] = [(ternaryCondition(in: text, before: question), thenText)]
    let nested = ternaryStates(elseText)
    if nested.isEmpty {
        states.append(("else", elseText))
    } else {
        states.append(contentsOf: nested)
    }
    return states
}

/// The branch structures in one file.
func groups(in file: String, source: String) -> [Group] {
    let lines = scanLines(source)
    var found: [Group] = []

    struct Opener {
        let kind: String
        let condition: String
        let line: Int
        let depth: Int
        let subject: String
        /// The switch statement a case belongs to: two switches on the same value at the same
        /// depth are two switches, not one chain.
        let owner: Int
    }
    struct Chain {
        let kind: String
        let depth: Int
        let subject: String
        let owner: Int
        var openers: [Opener]
    }

    var chains: [Chain] = []
    var switches: [(line: Int, depth: Int, subject: String)] = []

    for (index, line) in lines.enumerated() {
        let trimmed = line.trimmed
        if trimmed.hasPrefix("switch ") {
            var subject = String(trimmed.dropFirst("switch ".count).trimmingCharacters(in: .whitespacesAndNewlines))
            if subject.hasSuffix("{") { subject.removeLast() }
            subject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            switches.append((index, line.depthBefore, subject))
        }
        var opener: Opener?
        if trimmed.hasPrefix("if "), trimmed.contains("{") {
            let body = String(trimmed.dropFirst("if ".count).dropLast().trimmingCharacters(in: .whitespacesAndNewlines))
            opener = Opener(kind: "if", condition: body, line: index, depth: line.depthAfter, subject: "", owner: -1)
        } else if trimmed.hasPrefix("} else if ") {
            let body = String(trimmed.dropFirst("} else if ".count).dropLast().trimmingCharacters(in: .whitespacesAndNewlines))
            opener = Opener(kind: "elseif", condition: body, line: index, depth: line.depthAfter, subject: "", owner: -1)
        } else if trimmed.hasPrefix("} else ") {
            opener = Opener(kind: "else", condition: "else", line: index, depth: line.depthAfter, subject: "", owner: -1)
        } else if trimmed.hasPrefix("case ") || trimmed.hasPrefix("default:") {
            // The switch this case belongs to: the nearest one above it, at the depth the
            // case sits in.
            let owner = switches.last(where: { $0.line < index && $0.depth == line.depthAfter - 1 })?.line ?? -1
            let subject = switches.last(where: { $0.line < index && $0.depth == line.depthAfter - 1 })?.subject ?? ""
            let condition = trimmed.hasPrefix("default:")
                ? "default"
                : "case " + (trimmed.dropFirst("case ".count).split(separator: ":").first.map(String.init) ?? "")
            opener = Opener(kind: trimmed.hasPrefix("default:") ? "default" : "case", condition: condition,
                            line: index, depth: line.depthAfter, subject: subject, owner: owner)
        }
        guard let opener else { continue }

        // A continuation belongs to the chain at its own depth: an if/else inside a branch
        // does not swallow the chain that contains it, and a second switch at the same depth
        // does not continue the first one's cases.
        var continued = false
        if let position = chains.lastIndex(where: { $0.depth == opener.depth }) {
            let chain = chains[position]
            let continues = (chain.kind == "if" && (opener.kind == "elseif" || opener.kind == "else"))
                || (chain.kind == "switch" && (opener.kind == "case" || opener.kind == "default")
                    && chain.owner == opener.owner)
            if continues {
                chains[position].openers.append(opener)
                continued = true
            }
        }
        if continued { continue }
        chains.append(Chain(kind: (opener.kind == "case" || opener.kind == "default") ? "switch" : "if",
                            depth: opener.depth, subject: opener.subject, owner: opener.owner, openers: [opener]))
    }

    for chain in chains {
        guard chain.openers.count > 1 else { continue }
        let isSwitch = chain.kind == "switch"
        var states: [State] = []
        for (position, opener) in chain.openers.enumerated() {
            var text = ""
            if opener.kind == "case" || opener.kind == "default" {
                // A case's value can sit on the case line itself: `case .low: return .green`.
                if let colon = lines[opener.line].text.firstIndex(of: ":") {
                    text += String(lines[opener.line].text[lines[opener.line].text.index(after: colon)...])
                }
            } else if let brace = lines[opener.line].text.firstIndex(of: "{") {
                text += String(lines[opener.line].text[lines[opener.line].text.index(after: brace)...])
            }
            let last: Int
            if position + 1 < chain.openers.count {
                last = chain.openers[position + 1].line - 1
            } else {
                var scan = chain.openers[position].line + 1
                while scan < lines.count, lines[scan].depthAfter >= opener.depth { scan += 1 }
                last = scan - 1
            }
            if last > opener.line {
                text += "\n" + lines[(opener.line + 1)...last].map(\.text).joined(separator: "\n")
            }
            states.append(State(condition: opener.condition, text: text, line: opener.line + 1))
        }
        let key = (isSwitch ? chain.subject + "|" : "") + states.map(\.condition).joined(separator: "|")
        var group = Group(file: file, key: key, states: states, line: chain.openers[0].line + 1)
        group.named = isSwitch && !chain.subject.isEmpty && source.contains(chain.subject + ".rawValue")
        found.append(group)
    }

    // Ternary chains.
    for (index, line) in lines.enumerated() {
        guard !questionMarks(in: line.text).isEmpty else { continue }
        let states = ternaryStates(line.text)
        guard states.count > 1 else { continue }
        let key = states.map { $0.0 }.joined(separator: "|")
        found.append(Group(file: file, key: key,
                           states: states.enumerated().map { State(condition: $0.element.0, text: $0.element.1, line: index + 1) },
                           line: index + 1))
    }
    return found
}