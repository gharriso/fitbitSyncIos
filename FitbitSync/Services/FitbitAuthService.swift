//
//  FitbitAuthService.swift
//  FitbitSync
//
//  Handles Fitbit OAuth 2.0 authentication flow
//

import Foundation
import AuthenticationServices
import Security

class FitbitAuthService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var authError: Error?

    private var authSession: ASWebAuthenticationSession?
    private let keychainService = "com.fitbitsync.app"
    private let keychainAccount = "fitbit_token"

    override init() {
        super.init()
        checkAuthenticationStatus()
    }

    // MARK: - Authentication

    func authenticate(presentationContext: ASWebAuthenticationPresentationContextProviding) {
        // Clear any previous errors
        authError = nil

        guard FitbitConfig.isConfigured else {
            authError = AuthError.missingConfiguration
            return
        }

        // Build authorization URL
        var components = URLComponents(string: FitbitConfig.authorizationUrl)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: FitbitConfig.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: FitbitConfig.redirectUri),
            URLQueryItem(name: "scope", value: FitbitConfig.requiredScopes),
            URLQueryItem(name: "expires_in", value: "31536000") // 1 year
        ]

        guard let authUrl = components.url else {
            authError = AuthError.invalidUrl
            return
        }

        // Start authentication session
        authSession = ASWebAuthenticationSession(
            url: authUrl,
            callbackURLScheme: "fitbitsync"
        ) { [weak self] callbackUrl, error in
            guard let self = self else { return }

            if let error = error {
                self.authError = error
                return
            }

            guard let callbackUrl = callbackUrl else {
                self.authError = AuthError.noCallbackUrl
                return
            }

            // Extract authorization code
            guard let code = self.extractCode(from: callbackUrl) else {
                self.authError = AuthError.noAuthCode
                return
            }

            // Exchange code for token
            self.exchangeCodeForToken(code: code)
        }

        authSession?.presentationContextProvider = presentationContext
        authSession?.prefersEphemeralWebBrowserSession = false
        authSession?.start()
    }

    func logout() {
        deleteTokenFromKeychain()
        isAuthenticated = false
    }

    // MARK: - Token Exchange

    private func exchangeCodeForToken(code: String) {
        var request = URLRequest(url: URL(string: FitbitConfig.tokenUrl)!)
        request.httpMethod = "POST"

        // Create authorization header
        let credentials = "\(FitbitConfig.clientId):\(FitbitConfig.clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Create body (don't include client_id when using Basic auth)
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: FitbitConfig.redirectUri),
            URLQueryItem(name: "code", value: code)
        ]
        request.httpBody = components.query?.data(using: .utf8)

        // Debug logging
        print("Token exchange request:")
        print("URL: \(FitbitConfig.tokenUrl)")
        print("Body: \(components.query ?? "none")")
        print("Authorization header: Basic \(base64Credentials)")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.authError = error
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.authError = AuthError.noData
                }
                return
            }

            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                print("Token exchange status code: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    // Print error response for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Error response: \(responseString)")
                    }
                    DispatchQueue.main.async {
                        self.authError = AuthError.tokenExchangeFailed(statusCode: httpResponse.statusCode)
                    }
                    return
                }
            }

            do {
                let token = try JSONDecoder().decode(OAuthToken.self, from: data)
                self.saveTokenToKeychain(token)

                DispatchQueue.main.async {
                    self.isAuthenticated = true
                }
            } catch {
                print("Token decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseString)")
                }
                DispatchQueue.main.async {
                    self.authError = error
                }
            }
        }.resume()
    }

    // MARK: - Token Management

    func getAccessToken() -> String? {
        guard let tokenData = loadTokenFromKeychain() else {
            return nil
        }

        do {
            let token = try JSONDecoder().decode(OAuthToken.self, from: tokenData)
            return token.accessToken
        } catch {
            return nil
        }
    }

    private func checkAuthenticationStatus() {
        isAuthenticated = getAccessToken() != nil
    }

    // MARK: - Keychain Operations

    private func saveTokenToKeychain(_ token: OAuthToken) {
        guard let tokenData = try? JSONEncoder().encode(token) else {
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: tokenData
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadTokenFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Helpers

    private func extractCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }

        return components.queryItems?.first(where: { $0.name == "code" })?.value
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case missingConfiguration
    case invalidUrl
    case noCallbackUrl
    case noAuthCode
    case noData
    case tokenExchangeFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Please configure your Fitbit Client ID and Secret in FitbitConfig.swift"
        case .invalidUrl:
            return "Invalid authorization URL"
        case .noCallbackUrl:
            return "No callback URL received"
        case .noAuthCode:
            return "No authorization code received"
        case .noData:
            return "No data received from token exchange"
        case .tokenExchangeFailed(let statusCode):
            return "Token exchange failed with status \(statusCode). Check Xcode console for details."
        }
    }
}
