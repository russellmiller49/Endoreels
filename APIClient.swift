import Foundation

protocol APIRequest {
    associatedtype Response: Decodable
    var path: String { get }
    var method: String { get }
    var body: Data? { get }
    var headers: [String: String] { get }
}

extension APIRequest {
    var headers: [String: String] { [:] }
    var body: Data? { nil }
}

/// Lightweight API client placeholder. Real implementation should sign requests with Supabase JWT and add Idempotency-Key where required.
struct APIClient {
    var baseURL: URL
    var session: URLSession = .shared

    init(baseURL: URL = AppConfig.apiBaseURL) {
        self.baseURL = baseURL
    }

    func send<R: APIRequest>(_ request: R) async throws -> R.Response {
        let url = baseURL.appendingPathComponent(request.path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        request.headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }

        #if DEBUG
        // Placeholder: inject fake responses while backend is not available.
        if let demo = DemoAPI.stubbedResponse(for: request) {
            return demo
        }
        #endif

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError.server(code: httpResponse.statusCode, data: data)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(R.Response.self, from: data)
    }
}

enum APIError: Error {
    case server(code: Int, data: Data?)
    case decoding(Error)
    case stubNotAvailable
}

#if DEBUG
enum DemoAPI {
    static func stubbedResponse<R: APIRequest>(for request: R) -> R.Response? {
        if request is CreditsRequest {
            return CreditsResponse.demo as? R.Response
        }
        return nil
    }
}
#endif

struct CreditsRequest: APIRequest {
    typealias Response = CreditsResponse
    var path: String { "/api/credits" }
    var method: String { "GET" }
}

struct CreditsResponse: Codable {
    var balance: Int
    var transactions: [CreditTransaction]

    static let demo = CreditsResponse(balance: 3, transactions: CreditTransaction.demoTransactions)
}

