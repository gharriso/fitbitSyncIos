//
//  DataProcessor.swift
//  FitbitSync
//
//  Utility for calculating statistics on weight and body fat data
//

import Foundation

struct DataStatistics<T> {
    let first: T?
    let last: T?
    let average: Double?
}

struct WeightStatistics {
    let first: (value: Double, date: Date)?
    let last: (value: Double, date: Date)?
    let average: Double?
}

struct BodyFatStatistics {
    let first: (value: Double, date: Date)?
    let last: (value: Double, date: Date)?
    let average: Double?
}

class DataProcessor {

    // MARK: - Weight Statistics

    static func calculateWeightStatistics(from entries: [WeightEntry]) -> WeightStatistics {
        guard !entries.isEmpty else {
            return WeightStatistics(first: nil, last: nil, average: nil)
        }

        // Sort by date
        let sortedEntries = entries.sorted { $0.date < $1.date }

        // First entry (earliest date)
        let first = sortedEntries.first.map { (value: $0.weight, date: $0.date) }

        // Last entry (most recent date)
        let last = sortedEntries.last.map { (value: $0.weight, date: $0.date) }

        // Average
        let sum = entries.reduce(0.0) { $0 + $1.weight }
        let average = sum / Double(entries.count)

        return WeightStatistics(
            first: first,
            last: last,
            average: average
        )
    }

    // MARK: - Body Fat Statistics

    static func calculateBodyFatStatistics(from entries: [BodyFatEntry]) -> BodyFatStatistics {
        guard !entries.isEmpty else {
            return BodyFatStatistics(first: nil, last: nil, average: nil)
        }

        // Sort by date
        let sortedEntries = entries.sorted { $0.date < $1.date }

        // First entry (earliest date)
        let first = sortedEntries.first.map { (value: $0.fat, date: $0.date) }

        // Last entry (most recent date)
        let last = sortedEntries.last.map { (value: $0.fat, date: $0.date) }

        // Average
        let sum = entries.reduce(0.0) { $0 + $1.fat }
        let average = sum / Double(entries.count)

        return BodyFatStatistics(
            first: first,
            last: last,
            average: average
        )
    }

    // MARK: - Formatting Helpers

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func formatWeight(_ weight: Double) -> String {
        return String(format: "%.1f", weight)
    }

    static func formatBodyFat(_ fat: Double) -> String {
        return String(format: "%.1f%%", fat)
    }

    // MARK: - Comparison (Find Missing Entries)

    /// Finds weight entries from Fitbit that don't exist in HealthKit (fuzzy match by calendar day)
    static func findMissingWeightEntries(fitbit: [WeightEntry], healthKit: [WeightEntry]) -> [WeightEntry] {
        let calendar = Calendar.current

        // Create a set of calendar days that exist in HealthKit
        let healthKitDays = Set(healthKit.map { calendar.startOfDay(for: $0.date) })

        // Filter Fitbit entries to only those not in HealthKit
        let missing = fitbit.filter { entry in
            let entryDay = calendar.startOfDay(for: entry.date)
            return !healthKitDays.contains(entryDay)
        }

        // Sort by date descending (most recent first)
        return missing.sorted { $0.date > $1.date }
    }

    /// Finds body fat entries from Fitbit that don't exist in HealthKit (fuzzy match by calendar day)
    static func findMissingBodyFatEntries(fitbit: [BodyFatEntry], healthKit: [BodyFatEntry]) -> [BodyFatEntry] {
        let calendar = Calendar.current

        // Create a set of calendar days that exist in HealthKit
        let healthKitDays = Set(healthKit.map { calendar.startOfDay(for: $0.date) })

        // Filter Fitbit entries to only those not in HealthKit
        let missing = fitbit.filter { entry in
            let entryDay = calendar.startOfDay(for: entry.date)
            return !healthKitDays.contains(entryDay)
        }

        // Sort by date descending (most recent first)
        return missing.sorted { $0.date > $1.date }
    }
}
