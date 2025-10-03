import Foundation

enum AppConfig {
    private static func env(_ key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else { return nil }
        return value
    }

    static let apiBaseURL: URL = {
        if let value = env("API_BASE_URL"), let url = URL(string: value) {
            return url
        }
        return URL(string: "https://endoreels-production.up.railway.app")!
    }()

    static let supabaseURL: URL = {
        if let value = env("SUPABASE_URL"), let url = URL(string: value) {
            return url
        }
        return URL(string: "https://tqnhxlwvkkswuckszlee.supabase.co")!
    }()

    static let supabaseAnonKey: String = env("SUPABASE_ANON_KEY") ?? ""
    static let supabasePublishableKey: String = env("SUPABASE_PUBLISHABLE_KEY") ?? ""
    static let supabaseServiceRoleKey: String = env("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    static let supabaseJWTSecret: String = env("SUPABASE_JWT_SECRET") ?? ""
    static let postgresURL: String = env("POSTGRES_URL") ?? ""
}
