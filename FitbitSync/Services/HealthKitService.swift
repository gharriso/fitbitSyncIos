//
//  HealthKitService.swift
//  FitbitSync
//
//  Service for reading data from Apple Health (HealthKit)
//

import Foundation
import HealthKit

class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authError: Error?

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            await MainActor.run {
                authError = HealthKitError.notAvailable
            }
            return
        }

        // Define the data types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
        ]

        // Define the data types we want to write (for future syncing)
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

            await MainActor.run {
                isAuthorized = true
                print("HealthKit authorization granted")
            }
        } catch let error as NSError {
            await MainActor.run {
                // Check for missing entitlement error
                if error.domain == "com.apple.healthkit" && error.code == 5 {
                    authError = HealthKitError.missingEntitlement
                    print("HealthKit error: Missing entitlement. Enable HealthKit capability in Xcode.")
                } else if error.localizedDescription.contains("entitlement") {
                    authError = HealthKitError.missingEntitlement
                    print("HealthKit error: Missing entitlement. Enable HealthKit capability in Xcode.")
                } else {
                    authError = error
                    print("HealthKit authorization error: \(error)")
                }
            }
        } catch {
            await MainActor.run {
                authError = error
                print("HealthKit authorization error: \(error)")
            }
        }
    }

    // MARK: - Fetch Weight Data

    func fetchWeightData() async throws -> [WeightEntry] {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.invalidType
        }

        // Get data from last 2 years
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .year, value: -2, to: endDate)!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                // Convert HKQuantitySample to WeightEntry
                let entries = samples.map { sample in
                    let weightInKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    return WeightEntry(
                        date: sample.startDate,
                        weight: weightInKg,
                        source: sample.sourceRevision.source.name
                    )
                }

                print("Fetched \(entries.count) weight entries from HealthKit")
                continuation.resume(returning: entries)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Body Fat Data

    func fetchBodyFatData() async throws -> [BodyFatEntry] {
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            throw HealthKitError.invalidType
        }

        // Get data from last 2 years
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .year, value: -2, to: endDate)!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bodyFatType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                // Convert HKQuantitySample to BodyFatEntry
                let entries = samples.map { sample in
                    // Body fat percentage is stored as a fraction (0.0 to 1.0), convert to percentage
                    let fatPercentage = sample.quantity.doubleValue(for: .percent()) * 100
                    return BodyFatEntry(date: sample.startDate, fat: fatPercentage)
                }

                print("Fetched \(entries.count) body fat entries from HealthKit")
                continuation.resume(returning: entries)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Fetch All Data

    func fetchAllData() async throws -> (weight: [WeightEntry], bodyFat: [BodyFatEntry]) {
        async let weightData = fetchWeightData()
        async let bodyFatData = fetchBodyFatData()

        return try await (weight: weightData, bodyFat: bodyFatData)
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case invalidType
    case authorizationDenied
    case missingEntitlement

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .invalidType:
            return "Invalid HealthKit data type"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .missingEntitlement:
            return "HealthKit entitlement is missing. Please enable HealthKit capability in Xcode."
        }
    }
}
