//
//  FitbitConfig.swift
//  FitbitSync
//
//  Configuration file for Fitbit API credentials
//

import Foundation

struct FitbitConfig {
    // MARK: - TODO: Add Your Fitbit App Credentials
    // Get these from: https://dev.fitbit.com/apps

    /// Your Fitbit App Client ID
    /// Example: "23ABC123"
    static let clientId = "23TWTY"

    /// Your Fitbit App Client Secret
    /// Example: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
    static let clientSecret = "d118f3154a2295c127fd4817a2364097"

    /// Redirect URI configured in your Fitbit app
    /// This should match the URL scheme in Info.plist (fitbitsync://callback)
    static let redirectUri = "fitbitsync://callback"

    // MARK: - OAuth URLs
    static let authorizationUrl = "https://www.fitbit.com/oauth2/authorize"
    static let tokenUrl = "https://api.fitbit.com/oauth2/token"

    // MARK: - API Configuration
    static let apiBaseUrl = "https://api.fitbit.com"
    static let requiredScopes = "weight"

    // MARK: - Validation
    static var isConfigured: Bool {
        return !clientId.contains("YOUR_CLIENT_ID") &&
               !clientSecret.contains("YOUR_CLIENT_SECRET")
    }
}
