import SwiftUI

// The banner at the top of the dashboard: the tolerance alert when there is one,
// otherwise the bedtime sentence with the icon that carries the same state and the
// caffeine-free forecast under it.
//
// It takes what it shows and derives nothing. The state, its title, its icon and its
// colour are decided in DashboardView, so this file is a picture and the decisions stay
// with the decisions -- the seam the 500-line cap asked for, cut where the picture
// ends and the reading begins.
struct DashboardOracleBanner: View {
    let toleranceAlert: ToleranceAlert?
    let title: String
    let icon: String
    let color: Color
    let subtitle: String
    let forecast: String?

    var body: some View {
        Group {
            // Show tolerance alert first (highest priority warning)
            if let toleranceAlert {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .frame(width: 40, height: 40)
                        .background(.yellow.opacity(0.2))
                        .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Caffeine Tolerance Alert")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(toleranceAlert.message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.15))
                )
            } else {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 40, height: 40)
                        .background(color.opacity(0.2))
                        .clipShape(.circle)
                        .symbolEffect(.bounce, value: title)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        // P1: the forecast. It rides on the ruled dose set the chart draws
                        // (L4) and on the same decay model, so it is the curve's own answer
                        // rather than a second caffeine number.
                        if let forecast {
                            Text(forecast)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                )
            }
        }
    }
}
