//
//  FitbitAPIService.swift
//  FitbitSync
//
//  Service for fetching data from Fitbit API
//

import Foundation

class FitbitAPIService {
    private let authService: FitbitAuthService

    init(authService: FitbitAuthService) {
        self.authService = authService
    }

    // MARK: - Fetch Weight Data

    func fetchWeightData() async throws -> [WeightEntry] {
        guard let accessToken = authService.getAccessToken() else {
            print("API Error: Not authenticated")
            throw APIError.notAuthenticated
        }

        // Use date range to get 2 years of historical data
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: today)!

        let todayString = dateFormatter.string(from: today)
        let startDateString = dateFormatter.string(from: twoYearsAgo)

        // Use time series endpoint which supports date ranges
        let urlString = "\(FitbitConfig.apiBaseUrl)/1/user/-/body/weight/date/\(startDateString)/\(todayString).json"
        print("Fetching weight data from: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw APIError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("Weight API response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Weight API error response: \(responseString)")
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        // Debug: print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("Weight API success response: \(responseString)")
        }

        let weightResponse = try JSONDecoder().decode(WeightTimeSeriesResponse.self, from: data)
        print("Parsed \(weightResponse.bodyWeight.count) raw weight entries from API")

        // Convert API response to WeightEntry models
        // Filter out entries with zero weight (days with no actual recording)
        let allEntries = weightResponse.bodyWeight.compactMap { entry -> WeightEntry? in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: entry.dateTime),
                  let weight = Double(entry.value),
                  weight > 0 else {
                return nil
            }
            return WeightEntry(date: date, weight: weight, source: "Fitbit")
        }

        // Filter out consecutive duplicate values (Fitbit carries forward the last value for days without new data)
        // Round to 1 decimal place to catch interpolated values
        let sortedEntries = allEntries.sorted { $0.date < $1.date }
        var validEntries: [WeightEntry] = []
        var lastValue: Double?
        for entry in sortedEntries {
            let roundedWeight = (entry.weight * 10).rounded() / 10
            let roundedLast = lastValue.map { ($0 * 10).rounded() / 10 }
            if roundedWeight != roundedLast {
                validEntries.append(entry)
                lastValue = entry.weight
            }
        }

        print("After filtering duplicates: \(validEntries.count) valid weight entries")
        return validEntries
    }

    // MARK: - Fetch Body Fat Data

    func fetchBodyFatData() async throws -> [BodyFatEntry] {
        guard let accessToken = authService.getAccessToken() else {
            print("API Error: Not authenticated")
            throw APIError.notAuthenticated
        }

        // Use date range to get 2 years of historical data
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: today)!

        let todayString = dateFormatter.string(from: today)
        let startDateString = dateFormatter.string(from: twoYearsAgo)

        // Use time series endpoint which supports date ranges
        let urlString = "\(FitbitConfig.apiBaseUrl)/1/user/-/body/fat/date/\(startDateString)/\(todayString).json"
        print("Fetching body fat data from: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw APIError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("Body fat API response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Body fat API error response: \(responseString)")
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        // Debug: print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("Body fat API success response: \(responseString)")
        }

        let bodyFatResponse = try JSONDecoder().decode(BodyFatTimeSeriesResponse.self, from: data)
        print("Parsed \(bodyFatResponse.bodyFat.count) raw body fat entries from API")

        // Convert API response to BodyFatEntry models
        // Filter out entries with zero body fat (days with no actual recording)
        let allEntries = bodyFatResponse.bodyFat.compactMap { entry -> BodyFatEntry? in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: entry.dateTime),
                  let fat = Double(entry.value),
                  fat > 0 else {
                return nil
            }
            return BodyFatEntry(date: date, fat: fat)
        }

        // Filter out consecutive duplicate values (Fitbit carries forward/interpolates the last value for days without new data)
        // Round to 1 decimal place because Fitbit applies interpolation that creates tiny variations
        let sortedEntries = allEntries.sorted { $0.date < $1.date }
        var validEntries: [BodyFatEntry] = []
        var lastValue: Double?
        for entry in sortedEntries {
            let roundedFat = (entry.fat * 10).rounded() / 10
            let roundedLast = lastValue.map { ($0 * 10).rounded() / 10 }
            if roundedFat != roundedLast {
                validEntries.append(entry)
                lastValue = entry.fat
            }
        }

        print("After filtering duplicates: \(validEntries.count) valid body fat entries")
        return validEntries
    }

    // MARK: - Fetch All Data

    func fetchAllData() async throws -> (weight: [WeightEntry], bodyFat: [BodyFatEntry]) {
        async let weightData = fetchWeightData()
        async let bodyFatData = fetchBodyFatData()

        return try await (weight: weightData, bodyFat: bodyFatData)
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case notAuthenticated
    case invalidUrl
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please log in to Fitbit."
        case .invalidUrl:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response data"
        }
    }
}
