import Foundation

// The oracle's sentences, as pure functions.
//
// Copy that can be reached from a test can be corrected; copy welded to a view body
// cannot. These were cut out of DashboardView.swift for that reason and for the
// 500-line cap, and they are the file a change to the wording should land in.

// MARK: - Oracle copy (pure, testable)
/// Per-state oracle line. Numbers stay honest: every state names the bedtime mg.
func oracleLine(bedtimeMg: Double, limit: Double, thresholdName: String) -> String {
    let mg = Int(bedtimeMg)
    if bedtimeMg <= limit * 0.5 {
        return "Thanks for keeping it early — \(mg)mg at bedtime."
    } else if bedtimeMg <= limit {
        return "Still wired at \(mg)mg by bedtime — easy on the next cup."
    } else {
        // K4. "over the 50mg limit" read as evidence the app had measured. Only
        // the 100 mg figure is sourced; 50 and 25 are the reader's own stricter
        // choice, and the sentence now says so rather than letting a convention
        // pass as a finding.
        return "Put the pot down — \(mg)mg at bedtime, over \(thresholdName)."
    }
}

/// The forecast line under the oracle sentence: when the day's modelled caffeine falls
/// under the threshold the app calls "none" (P1).
///
/// The line NAMES the threshold, because "caffeine-free" is only ever true of a line the
/// app chose — 1 mg, its own reporting resolution. A sentence that said "caffeine-free"
/// with no line would be a claim the reader has no way to check, which is the shape K4
/// found and closed.
///
/// The day is named too ("today", "tomorrow", or the date): a clock time without its day
/// is a forecast the reader has to guess about, and guessing is how "06:09" becomes
/// "six in the morning".
///
/// - Returns: `nil` when there is nothing to forecast (no doses) — a line with no fact
///   behind it is worse than no line.
func caffeineFreeLine(
    freeAt: Date?,
    now: Date,
    calendar: Calendar = DateHelper.calendar
) -> String? {
    guard let freeAt else { return nil }
    // Printed, so it must not be rounded into a DIFFERENT number: casting the threshold to
    // an Int would print "under 0mg" for anything under 1 mg — a sentence that lies about
    // the line the derivation uses.
    let threshold = String(format: "%g", CaffeineConstants.caffeineFreeThresholdMg)
    guard freeAt > now else {
        return "Caffeine-free now (under \(threshold)mg)."
    }
    let time = clockTime(freeAt, calendar: calendar)
    let day = dayLabel(freeAt, now: now, calendar: calendar)
    return "Caffeine-free at \(time) \(day) (under \(threshold)mg)."
}

/// "HH:mm" in the reader's own zone — the app's clock format (the chart's stat row uses it).
private func clockTime(_ date: Date, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.timeZone = calendar.timeZone
    return formatter.string(from: date)
}

/// How the forecast names the day the instant falls on.
private func dayLabel(_ date: Date, now: Date, calendar: Calendar) -> String {
    if calendar.isDate(date, inSameDayAs: now) {
        return "today"
    }
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
       calendar.isDate(date, inSameDayAs: tomorrow) {
        return "tomorrow"
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "EEE d MMM"
    formatter.timeZone = calendar.timeZone
    return formatter.string(from: date)
}
