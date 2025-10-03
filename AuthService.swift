import Foundation

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case user
    }
}

struct AuthUser: Codable {
    let id: String
    let email: String?
}

struct AuthService {
    enum AuthError: LocalizedError {
        case invalidCredentials
        case missingAPIKey
        case network(Error)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return "Invalid email or password."
            case .missingAPIKey:
                return "Supabase API key is missing."
            case .network(let error):
                return error.localizedDescription
            case .decoding:
                return "Unable to decode Supabase response."
            }
        }
    }

    func login(email: String, password: String) async throws -> AuthSession {
        let anonKey = AppConfig.supabaseAnonKey
        guard !anonKey.isEmpty else {
            throw AuthError.missingAPIKey
        }

        let url = AppConfig.supabaseURL.appendingPathComponent("/auth/v1/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        guard let requestURL = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue(anonKey, forHTTPHeaderField: "Authorization")

        let payload = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                throw AuthError.invalidCredentials
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                return try decoder.decode(AuthSession.self, from: data)
            } catch {
                throw AuthError.decoding(error)
            }
        } catch {
            throw AuthError.network(error)
        }
    }
}
