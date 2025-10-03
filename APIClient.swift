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
    var authTokenProvider: () -> String? = { nil }

    init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared, authTokenProvider: @escaping () -> String? = { nil }) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    func send<R: APIRequest>(_ request: R) async throws -> R.Response {
        let url = baseURL.appendingPathComponent(request.path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        request.headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let token = authTokenProvider() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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
        if request is ProcessVideoRequest {
            return ProcessVideoResponse.demo as? R.Response
        }
        if request is DeductCreditsRequest || request is RefundCreditsRequest || request is GrantCreditsRequest {
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

struct DeductCreditsRequest: APIRequest {
    typealias Response = CreditsResponse
    var path: String { "/api/credits/deduct" }
    var method: String { "POST" }
    var payload: DeductCreditsPayload
    var idempotencyKey: String

    init(payload: DeductCreditsPayload, idempotencyKey: String) {
        self.payload = payload
        self.idempotencyKey = idempotencyKey
    }

    var headers: [String : String] {
        ["Content-Type": "application/json", "Idempotency-Key": idempotencyKey]
    }

    var body: Data? { try? JSONEncoder().encode(payload) }
}

struct DeductCreditsPayload: Codable {
    let amount: Int
    let reelID: UUID
    let reason: String
}

struct RefundCreditsRequest: APIRequest {
    typealias Response = CreditsResponse
    var path: String { "/api/credits/refund" }
    var method: String { "POST" }
    var payload: RefundCreditsPayload

    var headers: [String : String] { ["Content-Type": "application/json"] }
    var body: Data? { try? JSONEncoder().encode(payload) }
}

struct RefundCreditsPayload: Codable {
    let amount: Int
    let reelID: UUID
    let reason: String
}

struct GrantCreditsRequest: APIRequest {
    typealias Response = CreditsResponse
    var path: String { "/api/admin/grant-credits" }
    var method: String { "POST" }
    var payload: GrantCreditsPayload

    var headers: [String : String] { ["Content-Type": "application/json"] }
    var body: Data? { try? JSONEncoder().encode(payload) }
}

struct GrantCreditsPayload: Codable {
    let amount: Int
    let reason: String
    let userID: UUID?
}

struct CreditsResponse: Codable {
    var balance: Int
    var transactions: [CreditTransaction]

    static let demo = CreditsResponse(balance: 3, transactions: CreditTransaction.demoTransactions)
}

struct ProcessVideoRequest: APIRequest {
    typealias Response = ProcessVideoResponse
    var path: String { "/api/process-video" }
    var method: String { "POST" }
    var payload: ProcessVideoPayload
    var idempotencyKey: String

    init(payload: ProcessVideoPayload, idempotencyKey: String = UUID().uuidString) {
        self.payload = payload
        self.idempotencyKey = idempotencyKey
    }

    var headers: [String : String] {
        ["Content-Type": "application/json", "Idempotency-Key": idempotencyKey]
    }

    var body: Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }
}

struct ProcessVideoPayload: Codable {
    struct Asset: Codable {
        enum Kind: String, Codable {
            case video
            case image
            case audio
        }

        let id: UUID
        let filename: String
        let kind: Kind
    }

    let title: String
    let abstract: String
    let serviceLine: String
    let assets: [Asset]
}

struct ProcessVideoResponse: Codable {
    struct SuggestedStep: Codable {
        let title: String
        let focus: String
        let captureType: String
        let overlays: [String]
        let confidence: Double
    }

    let steps: [SuggestedStep]

    static let demo = ProcessVideoResponse(steps: [
        SuggestedStep(title: "Clip imported – scene highlight", focus: "AI detected key airway view worth emphasizing.", captureType: "video", overlays: ["AI arrow on obstruction"], confidence: 0.82),
        SuggestedStep(title: "Balloon dilation highlight", focus: "Freeze frame around 00:42 to call out maximum inflation.", captureType: "video", overlays: ["Timer overlay", "Pressure note"], confidence: 0.78),
        SuggestedStep(title: "Outcome confirmation", focus: "Use annotated still showing lumen restored.", captureType: "image", overlays: ["Before/after split"], confidence: 0.74)
    ])
}
