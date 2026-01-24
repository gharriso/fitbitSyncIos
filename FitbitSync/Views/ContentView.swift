//
//  ContentView.swift
//  FitbitSync
//
//  Main coordinator view
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = FitbitAuthService()
    @State private var apiService: FitbitAPIService?

    var body: some View {
        Group {
            if authService.isAuthenticated {
                if let apiService = apiService {
                    StatsView(authService: authService, apiService: apiService)
                } else {
                    ProgressView("Initializing...")
                        .onAppear {
                            initializeAPIService()
                        }
                }
            } else {
                LoginView(authService: authService)
            }
        }
        .onChange(of: authService.isAuthenticated) { oldValue, newValue in
            if newValue {
                initializeAPIService()
            } else {
                apiService = nil
            }
        }
    }

    private func initializeAPIService() {
        apiService = FitbitAPIService(authService: authService)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
