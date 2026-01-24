# FitbitSync iOS App

An iOS app that connects to Fitbit, fetches weight and body fat percentage data, and displays statistics including first, last, and average values.

## Features

- OAuth 2.0 authentication with Fitbit
- Fetches all historical weight and body fat data
- Displays statistics:
  - First recorded value with date
  - Last recorded value with date
  - Average value
- Secure token storage using iOS Keychain
- Clean SwiftUI interface

## Prerequisites

- Xcode 26.2 or later
- iOS 17.0 or later
- Fitbit Developer account with registered app

## Setup Instructions

### 1. Register a Fitbit App

1. Go to https://dev.fitbit.com/apps
2. Click "Register a New App"
3. Fill in the required fields:
   - Application Name: FitbitSync
   - Description: iOS app for syncing Fitbit data
   - Application Website: (your website or localhost)
   - Organization: (your name/company)
   - Organization Website: (your website)
   - **OAuth 2.0 Application Type**: Personal
   - **Callback URL**: `fitbitsync://callback`
   - Default Access Type: Read Only
4. Agree to terms and click Register
5. Note your **Client ID** and **Client Secret**

### 2. Configure the App

1. Open `FitbitSync/FitbitConfig.swift`
2. Replace the placeholder values:
   ```swift
   static let clientId = "YOUR_CLIENT_ID_HERE"  // Replace with your Client ID
   static let clientSecret = "YOUR_CLIENT_SECRET_HERE"  // Replace with your Client Secret
   ```
3. Save the file

### 3. Build and Run

1. Open `FitbitSync.xcodeproj` in Xcode
2. Select a simulator or physical device (iOS 17.0+)
3. Build and run (Cmd+R)

## Project Structure

```
FitbitSync/
├── FitbitSyncApp.swift          # App entry point
├── FitbitConfig.swift           # Configuration (credentials)
├── Models/
│   ├── WeightEntry.swift        # Weight data model
│   ├── BodyFatEntry.swift       # Body fat data model
│   └── OAuthToken.swift         # OAuth token model
├── Services/
│   ├── FitbitAuthService.swift  # OAuth 2.0 authentication
│   ├── FitbitAPIService.swift   # API client
│   └── DataProcessor.swift      # Statistics calculator
└── Views/
    ├── ContentView.swift        # Main coordinator
    ├── LoginView.swift          # Login screen
    └── StatsView.swift          # Statistics display
```

## Usage

1. Launch the app
2. Tap "Connect to Fitbit"
3. Log in with your Fitbit credentials in the browser
4. Authorize the app
5. View your weight and body fat statistics

## How It Works

### Authentication Flow
1. User taps "Connect to Fitbit"
2. App opens Fitbit authorization page in ASWebAuthenticationSession
3. User logs in and authorizes the app
4. Fitbit redirects to `fitbitsync://callback?code=XXXXX`
5. App exchanges authorization code for access token
6. Token is securely stored in iOS Keychain

### Data Fetching
1. App makes authenticated requests to Fitbit API:
   - `GET /1/user/-/body/log/weight/date/{today}/max.json`
   - `GET /1/user/-/body/log/fat/date/{today}/max.json`
2. Fetches all historical data using "max" period
3. Parses JSON responses into Swift models
4. Calculates statistics (first, last, average)
5. Displays results in clean UI

## API Endpoints Used

- **Authorization**: `https://www.fitbit.com/oauth2/authorize`
- **Token Exchange**: `https://api.fitbit.com/oauth2/token`
- **Weight Data**: `https://api.fitbit.com/1/user/-/body/log/weight/date/{date}/{period}.json`
- **Body Fat Data**: `https://api.fitbit.com/1/user/-/body/log/fat/date/{date}/{period}.json`

## Technologies

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Authentication**: ASWebAuthenticationSession
- **Networking**: URLSession with async/await
- **Storage**: Keychain Services
- **Minimum iOS**: 17.0

## Security

- OAuth 2.0 flow for secure authentication
- Access tokens stored securely in iOS Keychain
- No credentials stored in plain text
- HTTPS for all API communication

## Troubleshooting

### "Configuration Required" message
- Make sure you've added your Fitbit Client ID and Client Secret in `FitbitConfig.swift`

### Authentication fails
- Verify your callback URL in Fitbit app settings matches `fitbitsync://callback`
- Check that your Client ID and Secret are correct
- Ensure your Fitbit app is set to "Personal" application type

### No data displayed
- Verify you have weight or body fat data logged in your Fitbit account
- Check that you authorized the "weight" scope during login
- Try logging out and logging back in

### Build errors
- Ensure you're using Xcode 26.2 or later
- Clean build folder (Cmd+Shift+K) and rebuild

## Future Enhancements (Not in Phase 1)

- Data persistence (CoreData)
- Charts and graphs
- Export data functionality
- Health app integration
- Support for additional metrics

## License

This is a personal project for syncing Fitbit data.

## Credits

Built using the Fitbit Web API: https://dev.fitbit.com/build/reference/web-api/
