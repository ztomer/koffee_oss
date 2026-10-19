import Foundation

/// Caffeine pharmacokinetics, and the one empirical dose×timing curve that exists.
///
/// K3. Every cutoff the app draws used to come out of a fixed table of hours
/// (low 6 / medium 9 / high 12, times a metabolism multiplier). The table was
/// unsourced, and worse, it was **dose-blind**: the same wall was drawn for a
/// 50 mg tea and a 400 mg cold brew.
///
/// Dose-blindness is not a rounding error, it is the defect. With the old table
/// and the medium reader (9 h before a 23:00 bedtime, i.e. 14:00), a 200 mg dose
/// taken at that cutoff is still at
///    200 · 0.5^(9 / 5) = 57.4 mg
/// at bedtime — above the 50 mg this reader's own threshold says. The app could
/// say "you respected the cutoff" while its own model put the reader over the
/// line it drew. koffee_big measured exactly this and deleted the same table
/// on 2026-09-08.
///
/// The fix is the longer of two numbers, each with a different warrant:
///
///   * **the derivation** — how long THIS dose takes to decay to THIS reader's
///     bedtime threshold, at THEIR half-life. Exact, and consistent with the
///     bedtime projection by construction, because it inverts the same
///     `calculateCaffeineLevel` model.
///   * **the Gardiner floor** — the only head-to-head dose-by-timing trial
///     data that exists. Sparse, so presented as anchors with linear
///     segments, and honestly labelled as presentation rather than finding.
///
/// Where the floor binds, the empirics are doing the work; where the derivation
/// binds, the reader's own threshold is. Neither is ever shortened by the other.
enum CaffeinePK {

    // MARK: - The Gardiner anchors

    /// Trial dose → hours before bed at which that dose stops disturbing sleep.
    ///
    /// Nodes are trial points. The segments between them are **linear
    /// interpolation**, which is presentation of sparse data, not a finding,
    /// and is labelled as such rather than dressed up as a curve fit.
    ///
    /// The 2023 "avoid total sleep loss" anchors (107 mg → 8.8 h, 217.5 mg →
    /// 13.2 h) are deliberately NOT nodes: they test a stricter endpoint than
    /// the 2024 crossover, and folding both endpoints into one curve would
    /// manufacture a precision neither study has.
    static let floorDoseMg: [Double] = [0, 47, 100, 400]
    static let floorHoursBeforeBed: [Double] = [0, 0, 4, 12]

    static let floorSources = ["gardiner2024sleep", "gardiner2023sleep", "efsa2015sleep"]

    /// Hours before bed the Gardiner data supports for this dose.
    ///
    /// Beyond 400 mg the last segment is **extended, not clamped**. Clamping
    /// would claim knowledge stops mattering past the last node; the honest
    /// unknown is the slope, and the measured slope is the only thing available.
    static func floorHours(doseMg: Double) -> Double {
        let doses = floorDoseMg
        let hours = floorHoursBeforeBed
        guard doses.count == hours.count, let last = doses.indices.last else { return 0 }

        guard doseMg > doses[0] else { return hours[0] }

        for i in 1...last where doseMg <= doses[i] {
            let span = doses[i] - doses[i - 1]
            guard span > 0 else { return hours[i] }
            return hours[i - 1] + (hours[i] - hours[i - 1]) * (doseMg - doses[i - 1]) / span
        }

        let lastSpan = doses[last] - doses[last - 1]
        guard lastSpan > 0 else { return hours[last] }
        let slope = (hours[last] - hours[last - 1]) / lastSpan
        return hours[last] + slope * (doseMg - doses[last])
    }

    // MARK: - The derivation

    /// Hours for a dose to decay to `thresholdMg` at this half-life.
    ///
    /// The exact inverse of `calculateCaffeineLevel`, so the cutoff and the
    /// bedtime projection cannot disagree: a cutoff that says a dose is safe at
    /// bedtime is derived from the same model that decides the bedtime warning.
    ///
    /// A dose already under the threshold needs **no gap at all** — 0, not a
    /// small positive number. Returning a token gap there is what a table does.
    static func hoursToDecay(
        doseMg: Double,
        toMilligrams thresholdMg: Double,
        halfLifeHours: Double
    ) -> Double {
        guard thresholdMg > 0, halfLifeHours > 0, doseMg > thresholdMg else { return 0 }
        return halfLifeHours * log2(doseMg / thresholdMg)
    }

    // MARK: - The caffeine-free forecast

    /// The instant the day's modelled caffeine falls to `thresholdMg` — P1's "caffeine-free at".
    ///
    /// Every dose decays at the same rate, so for any instant at or after the LAST dose the
    /// level is ONE exponential: `C · 0.5^((t - last) / halfLife)`, where `C` is the level at
    /// that last dose. The answer is therefore solved, not stepped:
    ///
    ///     t = last + halfLife · log2(C / threshold)
    ///
    /// `C` is read from the model itself (`calculateCaffeineLevel`), so the forecast and the
    /// drawn curve cannot drift apart: the same decay, the same half-life, the same doses.
    /// A forecast that disagreed with the chart would be the defect L4 closed — one screen,
    /// two caffeine numbers.
    ///
    /// The dose set is the RULED one (L4: planned + logged, deduplicated), so a cup that was
    /// planned and already drunk is counted once.
    ///
    /// - Returns: the instant the level reaches the threshold, or `nil` when there is nothing
    ///   to forecast (no doses) — never a date in the past standing in for an answer.
    static func caffeineFreeAt(
        doses: [(Date, Double)],
        halfLife: Double = 5.0,
        metabolism: MetabolismRate = .medium,
        under thresholdMg: Double = CaffeineConstants.caffeineFreeThresholdMg
    ) -> Date? {
        let effectiveHalfLife = halfLife * metabolism.halfLifeMultiplier
        guard effectiveHalfLife > 0, thresholdMg > 0 else { return nil }

        let usable = doses.filter { $0.1 > 0 }
        guard let last = usable.map(\.0).max() else { return nil }

        let levelAtLast = calculateCaffeineLevel(
            doses: usable,
            at: last,
            halfLife: halfLife,
            metabolism: metabolism
        )
        guard levelAtLast > thresholdMg else { return last }

        let hours = effectiveHalfLife * log2(levelAtLast / thresholdMg)
        return last.addingTimeInterval(hours * 3600)
    }
}
