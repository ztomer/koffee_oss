// tools/greyscale/Judge.swift -- the verdict.
//
// The question, for every distinction the sources hold: if the colour channel is removed, is
// the state still identifiable?
//
// Two states of one distinction are told apart in greyscale when
//
//   * their colours are far enough apart (CIE L*), in every appearance and over the
//     worst-case background; or
//   * one of them paints nothing where the other paints something (a shape difference); or
//   * they differ in another channel -- different text, a different symbol, a different
//     value, a different shape.
//
// A distinction carried by colour alone, whose colours are closer than the threshold, is the
// defect this gate exists for: it is named, with the file, the declaration, the two states,
// their colours and the measured gap.
//
// ONE DISTINCTION IS NOT ONE GROUP. A view states its condition in more than one place: the
// selected day is bold, is white, and sits on an orange circle. Each of those is a branch
// structure of its own, and a colour in one of them is not a distinction on its own -- the
// other branches may already tell the states apart. So a pair of states is only judged on
// its colour when NOTHING else in the file separates them: a group whose conditions REFINE
// this group's (a refinement states the same thing in more parts) is looked at, and if it
// tells the two states apart -- by a colour that survives greyscale, or by a weight, a word
// or a shape -- the colour is reinforcing and not the distinction.

import Foundation

/// The smallest difference in greyscale lightness (CIE L*) that still reads as a different
/// shade on a small mark. A just-noticeable difference is about 2 L* between adjacent large
/// patches and about 5 L* on small glyphs; 10 sits above both, so a pair that passes here is
/// a pair a reader can tell apart with the colour turned off.
let lStarThreshold = 10.0

/// One state of a distinction, as the source wrote it.
struct StateInfo {
    let condition: String
    let isElse: Bool
    /// The atoms the condition is built from: `a || b` is the set {a, b}.
    let atoms: Set<String>
    var colours: [ColourToken] = []
    var strings: [String] = []
    var shapes: [String] = []
}

/// One distinction: the groups that share a set of conditions, merged.
struct Distinction {
    let file: String
    let key: String
    let conditions: [String]
    var states: [StateInfo] = []
    var lines: [Int] = []
    var groups: [Group] = []
    /// The states are named on the screen, so they are told apart in words.
    var named = false

    /// A distinction that paints: the ones a reader has to tell apart.
    var paints: Bool { states.contains { !$0.colours.isEmpty } }
}

/// One way a pair of states fails.
struct Failure {
    let file: String
    let line: Int
    let key: String
    let first: String
    let second: String
    let firstColour: String
    let secondColour: String
    let gap: Double
    let reason: String
}

/// The verdict on one pair of states.
enum Verdict {
    /// Something other than colour tells them apart.
    case toldApart
    /// Colour alone tells them apart, and it does not survive greyscale.
    case colourOnly
    /// There is no colour to judge.
    case noColour
}

/// The atoms a condition is built from.
func atoms(of condition: String) -> Set<String> {
    if condition == "else" { return [] }
    return Set(condition.components(separatedBy: "||")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty })
}

/// The distinctions, merged by the conditions that select their states.
func distinctions(from groups: [Group], palettes: [String: PaletteEntry]) -> [Distinction] {
    var merged: [String: Distinction] = [:]
    for group in groups {
        var distinction = merged[group.file + "#" + group.key]
            ?? Distinction(file: group.file, key: group.key, conditions: group.states.map(\.condition))
        if distinction.states.isEmpty {
            distinction.states = group.states.map {
                StateInfo(condition: $0.condition, isElse: $0.condition == "else", atoms: atoms(of: $0.condition),
                          colours: [], strings: [], shapes: [])
            }
        }
        for (index, state) in group.states.enumerated() where index < distinction.states.count {
            var colours: [ColourToken] = []
            for reference in colourReferences(in: state.text, palettes: Set(palettes.keys)) {
                colours.append(ColourToken(written: reference,
                                           resolved: resolve(reference, palettes: palettes) ?? [],
                                           alphaScale: opacityScale(after: reference, in: state.text)))
            }
            distinction.states[index].colours.append(contentsOf: colours)
            distinction.states[index].strings.append(contentsOf: stringLiterals(in: state.text))
            distinction.states[index].shapes.append(shapeOnly(state.text, palettes: Set(palettes.keys)))
            distinction.lines.append(state.line)
        }
        distinction.groups.append(group)
        if group.named { distinction.named = true }
        merged[group.file + "#" + group.key] = distinction
    }
    return merged.values.sorted { ($0.file, $0.key) < ($1.file, $1.key) }
}

/// The smallest lightness gap between two colours in one appearance, over the worst-case
/// background, or `nil` when they are the same colour there.
func gap(_ mine: ColourToken, _ theirs: ColourToken, in appearance: Int) -> Double? {
    guard appearance < mine.resolved.count, appearance < theirs.resolved.count else { return nil }
    let left = mine.resolved[appearance]
    let right = theirs.resolved[appearance]
    if left == right { return nil }
    return mine.separation(in: appearance, from: theirs)
}

/// The verdict on one pair of states: are they told apart without the colour channel?
func verdict(_ first: StateInfo, _ second: StateInfo) -> (Verdict, Double, String, String) {
    // Another channel carries the states: text, a symbol, a different value.
    if first.strings != second.strings { return (.toldApart, 0, "", "") }
    if first.shapes != second.shapes { return (.toldApart, 0, "", "") }
    if first.colours.isEmpty || second.colours.isEmpty { return (.noColour, 0, "", "") }

    var closest = Double.greatestFiniteMagnitude
    var closestPair: (String, String) = ("?", "?")
    for appearance in 0..<first.colours[0].resolved.count {
        var differs = false
        var toldApart = false
        for mine in first.colours {
            for theirs in second.colours {
                guard let separation = gap(mine, theirs, in: appearance) else { continue }
                differs = true
                // One paints nothing where the other paints: a shape difference.
                if mine.resolved[appearance].isAbsent != theirs.resolved[appearance].isAbsent {
                    toldApart = true
                    break
                }
                if separation < closest {
                    closest = separation
                    closestPair = (mine.written, theirs.written)
                }
                if separation >= lStarThreshold { toldApart = true; break }
            }
            if toldApart { break }
        }
        if differs && !toldApart {
            return (.colourOnly, closest, closestPair.0, closestPair.1)
        }
    }
    if closest == Double.greatestFiniteMagnitude { return (.noColour, 0, "", "") }
    return (.toldApart, closest, closestPair.0, closestPair.1)
}

/// The verdicts: the distinctions that do not survive greyscale, and how close the rest came.
func judge(_ distinctions: [Distinction], all: [Distinction]) -> (failures: [Failure], closest: (Double, String)?) {
    var failures: [Failure] = []
    var closest: (Double, String)?

    for distinction in distinctions where distinction.paints {
        // The states carry their own names: they are told apart in words, whatever the colour
        // does, so the colour is reinforcing and not the distinction.
        if distinction.named { continue }
        for first in 0..<distinction.states.count {
            for second in (first + 1)..<distinction.states.count {
                let outcome = verdict(distinction.states[first], distinction.states[second])
                if outcome.0 == .toldApart {
                    if outcome.1 > 0, closest == nil || outcome.1 < closest!.0 {
                        closest = (outcome.1, "\(outcome.2) vs \(outcome.3) in \(distinction.file)")
                    }
                    continue
                }
                if outcome.0 == .noColour { continue }

                // Another group in the same file may already tell these states apart: the
                // colour is then reinforcing, and the distinction rides on something else.
                if excused(distinction, first, second, all: all) { continue }

                failures.append(Failure(
                    file: distinction.file,
                    line: distinction.lines.first ?? 0,
                    key: distinction.key,
                    first: distinction.states[first].condition,
                    second: distinction.states[second].condition,
                    firstColour: outcome.2,
                    secondColour: outcome.3,
                    gap: outcome.1,
                    reason: "the states differ in colour alone, and the colours are "
                        + String(format: "%.1f", outcome.1) + " L* apart (the threshold is "
                        + String(format: "%.1f", lStarThreshold) + ")"
                ))
            }
        }
    }
    return (failures, closest)
}

/// Does another group in the same file tell these two states apart?
///
/// A group REFINES another when its conditions state the same thing in more parts: every
/// condition of the refining group implies one of the refined group's. The states of the
/// refining group are then matched to the states of the refined one, and if they differ in
/// a way that survives greyscale -- or in a way that is not colour at all -- the two states
/// of the refined group are already told apart without the colour.
func excused(_ distinction: Distinction, _ first: Int, _ second: Int, all: [Distinction]) -> Bool {
    let left = distinction.states[first]
    let right = distinction.states[second]

    /// Does a state of the other group land in this state of the distinction?
    func lands(in target: StateInfo) -> (StateInfo) -> Bool {
        { state in
            if state.isElse { return target.isElse }
            guard !target.isElse else { return false }
            return state.atoms.isSubset(of: target.atoms)
        }
    }

    for other in all where other.file == distinction.file && other.key != distinction.key {
        let leftMatches = other.states.filter(lands(in: left))
        let rightMatches = other.states.filter(lands(in: right))
        guard !leftMatches.isEmpty, !rightMatches.isEmpty else { continue }
        var toldApart = true
        for one in leftMatches {
            for two in rightMatches {
                if verdict(one, two).0 == .colourOnly { toldApart = false }
            }
        }
        if toldApart { return true }
    }
    return false
}
