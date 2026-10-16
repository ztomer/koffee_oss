import XCTest
@testable import Koffee

/// The clock seam is one door, and this is the lock on it.
///
/// Routing the app's "when is now" reads through `DateHelper.now` (G4's limit) is a change one pass
/// can make and the next can quietly undo: a view calls `Date()`, its fixture renders the wall clock
/// again, and **nothing announces it** — the harness's own reproducibility test still passes, because
/// two renders a second apart read the same second. That is why the seam has to be *enumerable* rather
/// than a habit, which is what this test is for.
///
/// Every direct read of the clock left in the product is listed below with the reason it is not app
/// state. Anything else is a bypass.
final class WallClockDoorTests: XCTestCase {

    /// `path: how many lines are allowed to read the clock`, and why each one may.
    private let allowed: [String: Int] = [
        // The seam itself.
        "Koffee/Domain/DateHelper.swift": 1,
        // The harness, three times: which day to draw, which day a `KOFFEE_RENDER_AT` applies to, and
        // the settle that *waits in real time* for SwiftUI to lay out. A pinned clock makes the last
        // one impossible to express through the seam — a runloop deadline of "the pinned instant plus
        // 0.4s" would return immediately for a fixture dated in the past.
        "Koffee/App/RenderHarness.swift": 3,
        // The process log's timestamp. A log says when the line was written; it does not say what the
        // app thinks today is, and a run's log should not have the fixture's date in it.
        "Koffee/App/main.swift": 1
    ]

    func test_the_wall_clock_is_read_only_where_this_test_lists_it() throws {
        let root = URL(fileURLWithPath: #filePath)   // …/KoffeeTests/Data/WallClockDoorTests.swift
            .deletingLastPathComponent()             // …/KoffeeTests/Data
            .deletingLastPathComponent()             // …/KoffeeTests
            .deletingLastPathComponent()             // …/koffee_oss

        var problems: [String] = []
        var mentioned: [String: Int] = [:]

        for file in try swiftFiles(under: root.appendingPathComponent("Koffee")) {
            let relative = file.path.replacingOccurrences(of: root.path + "/", with: "")
            let source = try String(contentsOf: file, encoding: .utf8)

            for (index, line) in source.components(separatedBy: .newlines).enumerated() {
                // Code, not prose: a comment that says "reads `now` rather than calling `Date()`" is
                // describing this rule, not breaking it.
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//") else { continue }
                guard code.contains("Date()") || code.contains("Date.now") else { continue }

                mentioned[relative, default: 0] += 1
                if mentioned[relative, default: 0] > (allowed[relative] ?? 0) {
                    problems.append("\(relative):\(index + 1): \(code)")
                }
            }
        }

        // And the other direction: an entry that is no longer true is a rug. An allowlist nobody
        // prunes stops describing the code it was written against.
        for (path, expected) in allowed.sorted(by: { $0.key < $1.key })
        where (mentioned[path] ?? 0) < expected {
            problems.append(
                "\(path): allowlisted for \(expected) wall-clock read(s), found \(mentioned[path] ?? 0) — the entry is stale"
            )
        }

        XCTAssertTrue(
            problems.isEmpty,
            """
            the wall clock is read outside the seam:
            \(problems.joined(separator: "\n"))

            App state and anything a surface draws reads `DateHelper.now`, so a render can pin the \
            instant (G4's limit: a fixture whose doses are behind the clock, drawn the same on any day). \
            Read it through the seam, or add the file here with the reason it is not app state.
            """
        )
    }

    private func swiftFiles(under directory: URL) throws -> [URL] {
        guard let walk = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return walk.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}
