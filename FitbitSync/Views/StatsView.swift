//
//  StatsView.swift
//  FitbitSync
//
//  Displays weight and body fat statistics
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var authService: FitbitAuthService
    let apiService: FitbitAPIService

    @State private var isLoading = true
    @State private var weightStats: WeightStatistics?
    @State private var bodyFatStats: BodyFatStatistics?
    @State private var errorMessage: String?

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
                        StatCardView(
                            title: "Weight",
                            icon: "scalemass.fill",
                            color: .blue,
                            stats: weightStats
                        )

                        // Body Fat Statistics
                        StatCardView(
                            title: "Body Fat",
                            icon: "percent",
                            color: .orange,
                            stats: bodyFatStats
                        )
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

        do {
            let data = try await apiService.fetchAllData()

            // Calculate statistics
            let weight = DataProcessor.calculateWeightStatistics(from: data.weight)
            let bodyFat = DataProcessor.calculateBodyFatStatistics(from: data.bodyFat)

            await MainActor.run {
                weightStats = weight
                bodyFatStats = bodyFat
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

// MARK: - Stat Card View

struct StatCardView: View {
    let title: String
    let icon: String
    let color: Color
    let stats: Any?

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

            if let weightStats = stats as? WeightStatistics {
                WeightStatsContent(stats: weightStats)
            } else if let bodyFatStats = stats as? BodyFatStatistics {
                BodyFatStatsContent(stats: bodyFatStats)
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .italic()
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
                Text("No weight data available")
                    .foregroundColor(.secondary)
                    .italic()
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
                Text("No body fat data available")
                    .foregroundColor(.secondary)
                    .italic()
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
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .fontWeight(.semibold)
                if let date = date {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
