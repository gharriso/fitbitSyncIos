//
//  StatsView.swift
//  FitbitSync
//
//  Displays weight and body fat statistics from Fitbit and Apple Health
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var authService: FitbitAuthService
    let apiService: FitbitAPIService

    @StateObject private var healthKitService = HealthKitService()

    @State private var isLoading = true
    @State private var fitbitWeightStats: WeightStatistics?
    @State private var fitbitBodyFatStats: BodyFatStatistics?
    @State private var healthKitWeightStats: WeightStatistics?
    @State private var healthKitBodyFatStats: BodyFatStatistics?
    @State private var errorMessage: String?

    // Raw data for comparison
    @State private var missingWeightEntries: [WeightEntry] = []
    @State private var missingBodyFatEntries: [BodyFatEntry] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    if isLoading {
                        ProgressView("Loading your data...")
                            .padding()
                    } else if let error = errorMessage {
                        VStack(spacing: 15) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)

                            Text("Error")
                                .font(.headline)

                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Retry") {
                                Task {
                                    await loadData()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    } else {
                        // Weight Statistics
                        ComparisonCardView(
                            title: "Weight",
                            icon: "scalemass.fill",
                            color: .blue,
                            fitbitStats: fitbitWeightStats,
                            healthKitStats: healthKitWeightStats
                        )

                        // Body Fat Statistics
                        ComparisonCardView(
                            title: "Body Fat",
                            icon: "percent",
                            color: .orange,
                            fitbitStats: fitbitBodyFatStats,
                            healthKitStats: healthKitBodyFatStats
                        )

                        // Missing Entries Navigation
                        let totalMissing = missingWeightEntries.count + missingBodyFatEntries.count
                        NavigationLink {
                            MissingEntriesView(
                                missingWeightEntries: missingWeightEntries,
                                missingBodyFatEntries: missingBodyFatEntries
                            )
                        } label: {
                            HStack {
                                Image(systemName: totalMissing > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(totalMissing > 0 ? .orange : .green)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Missing from Apple Health")
                                        .font(.headline)
                                    if totalMissing > 0 {
                                        Text("\(totalMissing) entries to sync")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("All entries synced")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("FitbitSync")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        authService.logout()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await loadData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        // Request HealthKit authorization first
        await healthKitService.requestAuthorization()

        do {
            // Fetch both Fitbit and HealthKit data in parallel
            async let fitbitData = apiService.fetchAllData()
            async let healthKitData = healthKitService.fetchAllData()

            let (fitbit, healthKit) = try await (fitbitData, healthKitData)

            // Calculate statistics for Fitbit
            let fbWeight = DataProcessor.calculateWeightStatistics(from: fitbit.weight)
            let fbBodyFat = DataProcessor.calculateBodyFatStatistics(from: fitbit.bodyFat)

            // Calculate statistics for HealthKit
            let hkWeight = DataProcessor.calculateWeightStatistics(from: healthKit.weight)
            let hkBodyFat = DataProcessor.calculateBodyFatStatistics(from: healthKit.bodyFat)

            // Find missing entries (in Fitbit but not in HealthKit)
            let missingWeight = DataProcessor.findMissingWeightEntries(
                fitbit: fitbit.weight,
                healthKit: healthKit.weight
            )
            let missingBodyFat = DataProcessor.findMissingBodyFatEntries(
                fitbit: fitbit.bodyFat,
                healthKit: healthKit.bodyFat
            )

            await MainActor.run {
                fitbitWeightStats = fbWeight
                fitbitBodyFatStats = fbBodyFat
                healthKitWeightStats = hkWeight
                healthKitBodyFatStats = hkBodyFat
                missingWeightEntries = missingWeight
                missingBodyFatEntries = missingBodyFat
                isLoading = false
            }
        } catch {
            await MainActor.run {
                // Check if it's an authentication error
                if let apiError = error as? APIError {
                    switch apiError {
                    case .httpError(let statusCode) where statusCode == 400 || statusCode == 401 || statusCode == 403:
                        // Invalid/expired token - logout and return to login
                        authService.logout()
                        return
                    default:
                        break
                    }
                }

                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Comparison Card View

struct ComparisonCardView: View {
    let title: String
    let icon: String
    let color: Color
    let fitbitStats: Any?
    let healthKitStats: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Divider()

            HStack(alignment: .top, spacing: 20) {
                // Fitbit column
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fitbit")
                        .font(.headline)
                        .foregroundColor(.blue)

                    if let weightStats = fitbitStats as? WeightStatistics {
                        WeightStatsContent(stats: weightStats)
                    } else if let bodyFatStats = fitbitStats as? BodyFatStatistics {
                        BodyFatStatsContent(stats: bodyFatStats)
                    } else {
                        Text("No data")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Apple Health column
                VStack(alignment: .leading, spacing: 12) {
                    Text("Apple Health")
                        .font(.headline)
                        .foregroundColor(.green)

                    if let weightStats = healthKitStats as? WeightStatistics {
                        WeightStatsContent(stats: weightStats)
                    } else if let bodyFatStats = healthKitStats as? BodyFatStatistics {
                        BodyFatStatsContent(stats: bodyFatStats)
                    } else {
                        Text("No data")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Weight Stats Content

struct WeightStatsContent: View {
    let stats: WeightStatistics

    var body: some View {
        VStack(spacing: 12) {
            if let first = stats.first {
                StatRow(
                    label: "First",
                    value: DataProcessor.formatWeight(first.value),
                    date: DataProcessor.formatDate(first.date)
                )
            }

            if let last = stats.last {
                StatRow(
                    label: "Last",
                    value: DataProcessor.formatWeight(last.value),
                    date: DataProcessor.formatDate(last.date)
                )
            }

            if let average = stats.average {
                StatRow(
                    label: "Average",
                    value: DataProcessor.formatWeight(average),
                    date: nil
                )
            }

            if stats.first == nil && stats.last == nil && stats.average == nil {
                Text("No data")
                    .foregroundColor(.secondary)
                    .italic()
                    .font(.caption)
            }
        }
    }
}

// MARK: - Body Fat Stats Content

struct BodyFatStatsContent: View {
    let stats: BodyFatStatistics

    var body: some View {
        VStack(spacing: 12) {
            if let first = stats.first {
                StatRow(
                    label: "First",
                    value: DataProcessor.formatBodyFat(first.value),
                    date: DataProcessor.formatDate(first.date)
                )
            }

            if let last = stats.last {
                StatRow(
                    label: "Last",
                    value: DataProcessor.formatBodyFat(last.value),
                    date: DataProcessor.formatDate(last.date)
                )
            }

            if let average = stats.average {
                StatRow(
                    label: "Average",
                    value: DataProcessor.formatBodyFat(average),
                    date: nil
                )
            }

            if stats.first == nil && stats.last == nil && stats.average == nil {
                Text("No data")
                    .foregroundColor(.secondary)
                    .italic()
                    .font(.caption)
            }
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    let date: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.semibold)
            if let date = date {
                Text(date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StatsView(
        authService: FitbitAuthService(),
        apiService: FitbitAPIService(authService: FitbitAuthService())
    )
}
