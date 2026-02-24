//
//  MissingEntriesView.swift
//  FitbitSync
//
//  Displays Fitbit entries that are not yet in Apple Health
//

import SwiftUI

struct MissingEntriesView: View {
    let missingWeightEntries: [WeightEntry]
    let missingBodyFatEntries: [BodyFatEntry]
    let healthKitService: HealthKitService

    @State private var isSyncing = false
    @State private var syncedWeight: WeightEntry?
    @State private var syncedBodyFat: BodyFatEntry?
    @State private var syncError: String?
    @State private var syncProgress: (current: Int, total: Int)?
    @State private var syncedAllCount: (weight: Int, bodyFat: Int)?

    private var hasMissingEntries: Bool {
        !missingWeightEntries.isEmpty || !missingBodyFatEntries.isEmpty
    }

    private var nextEntryToSync: (weight: WeightEntry?, bodyFat: BodyFatEntry?) {
        // Get the oldest missing entry (first to sync chronologically)
        let oldestWeight = missingWeightEntries.min(by: { $0.date < $1.date })
        let oldestBodyFat = missingBodyFatEntries.min(by: { $0.date < $1.date })
        return (oldestWeight, oldestBodyFat)
    }

    var body: some View {
        List {
            // Sync Result Section
            if syncedAllCount != nil || syncedWeight != nil || syncedBodyFat != nil {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)

                        Text("Successfully Synced!")
                            .font(.headline)

                        if let counts = syncedAllCount {
                            VStack(spacing: 8) {
                                if counts.weight > 0 {
                                    HStack {
                                        Image(systemName: "scalemass.fill")
                                            .foregroundColor(.blue)
                                        Text("\(counts.weight) weight entries")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.subheadline)
                                }
                                if counts.bodyFat > 0 {
                                    HStack {
                                        Image(systemName: "percent")
                                            .foregroundColor(.orange)
                                        Text("\(counts.bodyFat) body fat entries")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        } else {
                            if let weight = syncedWeight {
                                HStack {
                                    Image(systemName: "scalemass.fill")
                                        .foregroundColor(.blue)
                                    Text("\(DataProcessor.formatWeight(weight.weight)) kg")
                                        .fontWeight(.semibold)
                                    Text("on \(DataProcessor.formatDate(weight.date))")
                                        .foregroundColor(.secondary)
                                }
                                .font(.subheadline)
                            }

                            if let bodyFat = syncedBodyFat {
                                HStack {
                                    Image(systemName: "percent")
                                        .foregroundColor(.orange)
                                    Text(DataProcessor.formatBodyFat(bodyFat.fat))
                                        .fontWeight(.semibold)
                                    Text("on \(DataProcessor.formatDate(bodyFat.date))")
                                        .foregroundColor(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                } header: {
                    Text("Last Sync Result")
                }
            }

            // Sync Error Section
            if let error = syncError {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Sync Failed")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                }
            }

            // Sync Now Button Section
            if hasMissingEntries {
                Section {
                    Button(action: syncAllEntries) {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .padding(.trailing, 8)
                                if let progress = syncProgress {
                                    Text("Syncing \(progress.current)/\(progress.total)...")
                                } else {
                                    Text("Syncing...")
                                }
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                let totalCount = missingWeightEntries.count + missingBodyFatEntries.count
                                Text("Sync All (\(totalCount) entries)")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isSyncing)
                } header: {
                    Text("Sync")
                }
            }

            // Weight Section
            if !missingWeightEntries.isEmpty {
                Section {
                    ForEach(missingWeightEntries) { entry in
                        WeightEntryRow(entry: entry)
                    }
                } header: {
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.blue)
                        Text("Weight (\(missingWeightEntries.count) entries)")
                    }
                }
            }

            // Body Fat Section
            if !missingBodyFatEntries.isEmpty {
                Section {
                    ForEach(missingBodyFatEntries) { entry in
                        BodyFatEntryRow(entry: entry)
                    }
                } header: {
                    HStack {
                        Image(systemName: "percent")
                            .foregroundColor(.orange)
                        Text("Body Fat (\(missingBodyFatEntries.count) entries)")
                    }
                }
            }

            // Empty state
            if !hasMissingEntries && syncedWeight == nil && syncedBodyFat == nil {
                Section {
                    VStack(spacing: 15) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        Text("All Synced!")
                            .font(.headline)
                        Text("All your Fitbit entries are already in Apple Health.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                }
            }
        }
        .navigationTitle("Missing Entries")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func syncAllEntries() {
        isSyncing = true
        syncError = nil
        syncedWeight = nil
        syncedBodyFat = nil
        syncedAllCount = nil
        syncProgress = (0, missingWeightEntries.count + missingBodyFatEntries.count)

        Task {
            var weightSyncedCount = 0
            var bodyFatSyncedCount = 0
            var currentProgress = 0
            let totalEntries = missingWeightEntries.count + missingBodyFatEntries.count

            do {
                // Sync all weight entries (oldest first)
                let sortedWeightEntries = missingWeightEntries.sorted { $0.date < $1.date }
                for entry in sortedWeightEntries {
                    try await healthKitService.saveWeightEntry(entry)
                    weightSyncedCount += 1
                    currentProgress += 1
                    await MainActor.run {
                        syncProgress = (currentProgress, totalEntries)
                    }
                }

                // Sync all body fat entries (oldest first)
                let sortedBodyFatEntries = missingBodyFatEntries.sorted { $0.date < $1.date }
                for entry in sortedBodyFatEntries {
                    try await healthKitService.saveBodyFatEntry(entry)
                    bodyFatSyncedCount += 1
                    currentProgress += 1
                    await MainActor.run {
                        syncProgress = (currentProgress, totalEntries)
                    }
                }

                await MainActor.run {
                    syncedAllCount = (weightSyncedCount, bodyFatSyncedCount)
                    syncProgress = nil
                    isSyncing = false
                }
            } catch {
                await MainActor.run {
                    // Show partial success if some entries were synced
                    if weightSyncedCount > 0 || bodyFatSyncedCount > 0 {
                        syncedAllCount = (weightSyncedCount, bodyFatSyncedCount)
                    }
                    syncError = error.localizedDescription
                    syncProgress = nil
                    isSyncing = false
                }
            }
        }
    }
}

// MARK: - Weight Entry Row

struct WeightEntryRow: View {
    let entry: WeightEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(DataProcessor.formatDate(entry.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(DataProcessor.formatWeight(entry.weight)) kg")
                .font(.body)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Body Fat Entry Row

struct BodyFatEntryRow: View {
    let entry: BodyFatEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(DataProcessor.formatDate(entry.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(DataProcessor.formatBodyFat(entry.fat))
                .font(.body)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        MissingEntriesView(
            missingWeightEntries: [
                WeightEntry(date: Date(), weight: 75.5, source: "Fitbit"),
                WeightEntry(date: Date().addingTimeInterval(-86400), weight: 75.3, source: "Fitbit")
            ],
            missingBodyFatEntries: [
                BodyFatEntry(date: Date(), fat: 22.5),
                BodyFatEntry(date: Date().addingTimeInterval(-86400), fat: 22.3)
            ],
            healthKitService: HealthKitService()
        )
    }
}
