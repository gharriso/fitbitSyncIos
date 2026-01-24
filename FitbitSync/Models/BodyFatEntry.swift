//
//  BodyFatEntry.swift
//  FitbitSync
//
//  Model for body fat percentage data entries
//

import Foundation

struct BodyFatEntry: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let fat: Double

    enum CodingKeys: String, CodingKey {
        case date
        case fat
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

        self.fat = try container.decode(Double.self, forKey: .fat)
    }

    init(date: Date, fat: Double) {
        self.date = date
        self.fat = fat
    }
}

// Response model for Fitbit body fat time series API
struct BodyFatTimeSeriesResponse: Codable {
    let bodyFat: [BodyFatTimeSeriesEntry]

    enum CodingKeys: String, CodingKey {
        case bodyFat = "body-fat"
    }
}

struct BodyFatTimeSeriesEntry: Codable {
    let dateTime: String
    let value: String
}
