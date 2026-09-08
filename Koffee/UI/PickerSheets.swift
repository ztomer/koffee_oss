import SwiftUI

struct BeveragePickerSheet: View {
    let beverages: [BeverageModel]
    let onSelect: (BeverageModel) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Beverage")
                .font(.headline)
                .padding()

            List(beverages) { beverage in
                Button {
                    onSelect(beverage)
                } label: {
                    HStack {
                        Image(systemName: beverage.symbolName)
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text(beverage.name)
                                .font(.headline)
                            Text("\(beverage.caffeineMg)mg caffeine")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            Button("Cancel") {
                onDismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 400)
    }
}
