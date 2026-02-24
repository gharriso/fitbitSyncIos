# FitbitSync

An iOS app that syncs health data between Fitbit and Apple Health. View comparative statistics from both sources and sync missing Fitbit entries to Apple Health.

## Features

- **Fitbit OAuth 2.0 Authentication** - Secure login with token storage in iOS Keychain
- **Historical Data Fetching** - Retrieves up to 2 years of weight and body fat data from Fitbit
- **Apple Health Integration** - Reads existing HealthKit data and writes synced entries
- **Side-by-Side Comparison** - View statistics (first, last, average) from both data sources
- **Missing Entry Detection** - Identifies Fitbit entries not present in Apple Health
- **Batch Sync** - Sync missing entries to Apple Health with progress tracking
- **Smart Filtering** - Removes Fitbit's interpolated and duplicate values

## Requirements

- iOS 17.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)
- Fitbit Developer Account (for API credentials)

## Setup

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Register a Fitbit App

1. Go to [dev.fitbit.com/apps](https://dev.fitbit.com/apps)
2. Click "Register a New App"
3. Fill in the required fields:
   - **OAuth 2.0 Application Type**: Personal
   - **Callback URL**: `fitbitsync://callback`
   - **Default Access Type**: Read Only
4. Note your **Client ID** and **Client Secret**

### 3. Configure Credentials

Update `FitbitSync/FitbitConfig.swift` with your Fitbit API credentials:

```swift
enum FitbitConfig {
    static let clientId = "YOUR_CLIENT_ID"
    static let clientSecret = "YOUR_CLIENT_SECRET"
    static let redirectURI = "fitbitsync://callback"
}
```

### 4. Generate Xcode Project

```bash
xcodegen generate
```

### 5. Build and Run

```bash
open FitbitSync.xcodeproj
```

Build and run on a physical device (HealthKit requires a real device for full functionality).

## Project Structure

```
FitbitSync/
├── FitbitSyncApp.swift           # App entry point
├── FitbitConfig.swift            # API configuration
├── Models/
│   ├── WeightEntry.swift         # Weight data model
│   ├── BodyFatEntry.swift        # Body fat data model
│   └── OAuthToken.swift          # OAuth token model
├── Services/
│   ├── FitbitAuthService.swift   # OAuth authentication
│   ├── FitbitAPIService.swift    # Fitbit API client
│   ├── HealthKitService.swift    # Apple Health integration
│   └── DataProcessor.swift       # Statistics and comparison
└── Views/
    ├── ContentView.swift         # Main coordinator
    ├── LoginView.swift           # OAuth login screen
    ├── StatsView.swift           # Statistics dashboard
    └── MissingEntriesView.swift  # Sync missing entries
```

## Usage

1. Launch the app
2. Tap "Connect to Fitbit" and authorize the app
3. Grant HealthKit permissions when prompted
4. View comparative statistics from Fitbit and Apple Health
5. Navigate to missing entries to sync Fitbit data to Apple Health

## How It Works

### Authentication Flow
1. User taps "Connect to Fitbit"
2. App opens Fitbit authorization page via `ASWebAuthenticationSession`
3. User logs in and authorizes the app
4. Fitbit redirects to `fitbitsync://callback?code=XXXXX`
5. App exchanges authorization code for access token
6. Token is securely stored in iOS Keychain

### Data Sync Flow
1. App fetches weight and body fat history from Fitbit API (up to 2 years)
2. App reads existing data from Apple Health
3. Smart filtering removes Fitbit's interpolated/duplicate values
4. Statistics are calculated and displayed side-by-side
5. Missing entries are identified and can be synced to Apple Health

## API Endpoints

- **Authorization**: `https://www.fitbit.com/oauth2/authorize`
- **Token Exchange**: `https://api.fitbit.com/oauth2/token`
- **Weight Data**: `https://api.fitbit.com/1/user/-/body/log/weight/date/{date}/{period}.json`
- **Body Fat Data**: `https://api.fitbit.com/1/user/-/body/log/fat/date/{date}/{period}.json`

## Privacy & Security

- OAuth tokens stored securely in iOS Keychain
- Health data remains on-device
- No data sent to third-party servers
- HTTPS for all API communication

## Troubleshooting

### "Configuration Required" message
Make sure you've added your Fitbit Client ID and Client Secret in `FitbitConfig.swift`

### Authentication fails
- Verify callback URL in Fitbit app settings matches `fitbitsync://callback`
- Check that Client ID and Secret are correct
- Ensure Fitbit app is set to "Personal" application type

### HealthKit permissions denied
- Go to Settings > Health > Data Access & Devices > FitbitSync
- Enable read/write access for weight and body fat percentage

### No data displayed
- Verify you have weight/body fat data logged in Fitbit
- Check that you authorized the "weight" scope during login

## License

MIT
