//
//  WeightEntry.swift
//  FitbitSync
//
//  Model for weight data entries
//

import Foundation

struct WeightEntry: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let source: String?

    enum CodingKeys: String, CodingKey {
        case date
        case weight
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Parse date string to Date
        let dateString = try container.decode(String.self, forKey: .date)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let parsedDate = formatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Date string does not match expected format"
            )
        }
        self.date = parsedDate

        self.weight = try container.decode(Double.self, forKey: .weight)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
    }

    init(date: Date, weight: Double, source: String? = nil) {
        self.date = date
        self.weight = weight
        self.source = source
    }
}

// Response model for Fitbit weight time series API
struct WeightTimeSeriesResponse: Codable {
    let bodyWeight: [WeightTimeSeriesEntry]

    enum CodingKeys: String, CodingKey {
        case bodyWeight = "body-weight"
    }
}

struct WeightTimeSeriesEntry: Codable {
    let dateTime: String
    let value: String
}
