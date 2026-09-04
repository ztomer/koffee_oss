import SwiftUI
import GRDB

struct NutritionSearchView: View {
    @ObservedObject var appState: AppState
    @State private var searchText: String = ""
    @State private var searchResults: [NutritionTemplateModel] = []
    @State private var isSearching: Bool = false
    @State private var importError: String?
    @State private var showImportSuccess: Bool = false

    private let referenceRepo = ReferenceRepository()

    var body: some View {
        NavigationStack {
            List {
                if isSearching && searchResults.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Searching...")
                        Spacer()
                    }
                } else if !searchText.isEmpty && searchResults.isEmpty && !isSearching {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                } else {
                    ForEach(searchResults) { item in
                        NutritionSearchRow(item: item) {
                            importTemplate(item)
                        }
                    }
                }
            }
            .navigationTitle("Nutrition Search")
            .searchable(text: $searchText, prompt: "Search foods...")
            .task(id: searchText) {
                await performSearch()
            }
            .overlay {
                if showImportSuccess {
                    VStack {
                        Spacer()
                        Text("Imported!")
                            .font(.caption)
                            .padding(8)
                            .background(Color.green.opacity(0.9))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 20)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showImportSuccess)
        }
    }

    private func performSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        try? await Task.sleep(nanoseconds: 300_000_000)

        guard !Task.isCancelled else { return }

        do {
            let results = try await referenceRepo.searchNutrition(query: query)

            guard !Task.isCancelled else { return }

            searchResults = results
        } catch {
            print("[NutritionSearch] Error: \(error)")
            searchResults = []
        }

        isSearching = false
    }

    private func importTemplate(_ template: NutritionTemplateModel) {
        do {
            try appState.importNutritionTemplate(template)
            importError = nil
            showImportSuccess = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showImportSuccess = false
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}

struct NutritionSearchRow: View {
    let item: NutritionTemplateModel
    let onImport: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                Text(item.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label("\(Int(item.calories))cal", systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)

                    Label("\(Int(item.proteinG))g protein", systemImage: "p.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)

                    if item.isAbsorptionBlocker {
                        Label("Blocker", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer()

            Button(action: onImport) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    // Previews need a throwaway in-memory store; a failed queue is a
    // programmer error, so the force-try is contained to this boundary.
    NutritionSearchView(appState: makePreviewAppState())
}

@MainActor
private func makePreviewAppState() -> AppState {
    // swiftlint:disable:next force_try - preview-only: empty DB cannot fail here
    let db = try! DatabaseQueue()
    return AppState(
        profileRepo: UserProfileRepository(db: db),
        doseRepo: DoseRepository(db: db),
        beverageRepo: BeverageRepository(db: db),
        supplementRepo: SupplementLogRepository(db: db),
        hydrationRepo: HydrationRepository(db: db),
        exerciseRepo: ExerciseRepository(db: db),
        planRepo: DailyPlanRepository(db: db)
    )
}
