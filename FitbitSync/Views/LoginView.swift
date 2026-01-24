//
//  LoginView.swift
//  FitbitSync
//
//  Login screen for Fitbit authentication
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authService: FitbitAuthService

    var body: some View {
        VStack(spacing: 30) {
            // App Title
            VStack(spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)

                Text("FitbitSync")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track your weight and body fat data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 30)

            // Configuration Check
            if !FitbitConfig.isConfigured {
                VStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)

                    Text("Configuration Required")
                        .font(.headline)

                    Text("Please add your Fitbit Client ID and Client Secret in FitbitConfig.swift")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            } else {
                // Login Button
                Button(action: {
                    authService.authenticate(
                        presentationContext: AuthPresentationContext()
                    )
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Connect to Fitbit")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                // Status or Error Message
                if let error = authService.authError {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .padding()
    }
}

// MARK: - Presentation Context Provider

class AuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Preview

#Preview {
    LoginView(authService: FitbitAuthService())
}
