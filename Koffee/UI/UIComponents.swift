import SwiftUI

struct DoseRowView: View {
    let dose: DoseModel
    let beverages: [BeverageModel]
    @ObservedObject var appState: AppState
    let onRemove: () -> Void

    @State private var selectedTime: Date
    @State private var selectedBeverageId: String?

    init(dose: DoseModel, beverages: [BeverageModel], appState: AppState, onRemove: @escaping () -> Void) {
        self.dose = dose
        self.beverages = beverages
        self.appState = appState
        self.onRemove = onRemove
        _selectedTime = State(initialValue: dose.timestamp)
        _selectedBeverageId = State(initialValue: dose.beverageId)
    }

    var body: some View {
        HStack(spacing: 12) {
            EditableTimePicker(selection: $selectedTime)
                .frame(width: 100)

            Picker("", selection: $selectedBeverageId) {
                Text("Unknown").tag(nil as String?)
                ForEach(beverages, id: \.id) { beverage in
                    Text("\(beverage.icon) \(beverage.name) - \(beverage.caffeineMg)mg")
                        .tag(beverage.id as String?)
                }
            }
            .pickerStyle(.menu)

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct SensitivityButton: View {
    let sensitivity: Sensitivity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.orange : Color.clear)

                Text(sensitivity.displayName.prefix(1))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
    }
}

struct StackCompoundButton: View {
    let compound: NootropicCompound
    let isSelected: Bool
    let action: () -> Void

    @State private var showingInfo = false

    private var compoundColor: Color {
        switch compound {
        case .caffeine: return .orange
        case .lTheanine: return .blue
        case .magnesium: return .purple
        case .ashwagandha: return .green
        case .vitaminB: return .yellow
        case .rhodiola: return .orange
        case .theacrine: return .cyan
        case .creatine: return .red
        case .alphaGPC: return .mint
        case .lTyrosine: return .teal
        case .psylliumHusk: return .brown
        case .glycine: return .pink
        case .custom: return .gray
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(compound.rawValue)
                    .font(.system(size: 9, weight: .medium))
                Text("\(Int(compound.optimalDoseMg))mg")
                    .font(.system(size: 7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? compoundColor : Color.gray.opacity(0.3))
            .foregroundStyle(isSelected ? .white : .gray)
            .clipShape(.capsule)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.black.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingInfo, arrowEdge: .bottom) {
            CompoundInfoView(compound: compound)
                .frame(width: 260)
        }
        .onTapGesture {
            showingInfo = true
        }
    }
}

struct CompoundInfoView: View {
    let compound: NootropicCompound

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(compound.rawValue)
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text("\(Int(compound.optimalDoseMg))mg")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text(compound.intendedPurpose)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("How It Works").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    Text(compound.mechanismOfAction).font(.system(size: 11))
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Details").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    InfoRow(icon: "clock.fill", label: "Peak Time", value: "\(Int(compound.peakTimeMinutes))min")
                    InfoRow(icon: "hourglass", label: "Half-Life", value: "\(compound.halfLifeHours)h")
                    InfoRow(icon: "arrow.up.arrow.down", label: "Timing", value: compound.recommendedTimingMinutes >= 0 ? "After caffeine" : "Before caffeine")
                }

                if compound.elementalYieldFactor < 1.0 {
                    Divider()
                    Text(compound.elementalYieldDescription)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }

                Divider()

                Text(compound.explanation)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)

                if let benefit = compound.synergyBenefit {
                    Divider()
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles").foregroundStyle(.blue)
                        Text(benefit).font(.system(size: 10))
                    }
                }
            }
            .padding()
        }
        .frame(width: 260, height: 320)
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
        }
    }
}

struct RiskLevelBadge: View {
    let level: RiskLevel

    private var color: Color {
        switch level {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(level.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .clipShape(.capsule)
    }
}

func colorForCompound(_ compound: String) -> Color {
    switch compound.lowercased() {
    case "caffeine": return .orange
    case "l-theanine": return .blue
    case "magnesium": return .purple
    case "ashwagandha": return .green
    case "vitamin b": return .yellow
    case "rhodiola": return .orange
    case "theacrine": return .cyan
    case "creatine": return .red
    case "alpha-gpc": return .mint
    case "l-tyrosine": return .teal
    case "psyllium husk": return .brown
    case "glycine": return .pink
    case "custom": return .indigo
    default: return .gray
    }
}
