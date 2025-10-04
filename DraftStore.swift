import Foundation

/// Persist drafts under Application Support; journal deltas for crash safety.
public actor DraftStore {
    public enum Location {
        case applicationSupport
    }

    private let baseURL: URL
    private let fileManager = FileManager()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(location: Location = .applicationSupport) throws {
        let appSupport = try fileManager.url(for: .applicationSupportDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil,
                                             create: true)
        baseURL = appSupport.appendingPathComponent("EndoReelsDrafts", isDirectory: true)
        if !fileManager.fileExists(atPath: baseURL.path) {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
    }

    public func saveSnapshot(_ draft: Draft) async throws {
        let draftURL = baseURL.appendingPathComponent("\(draft.id.uuidString).json")
        let data = try await MainActor.run { try encoder.encode(draft) }
        try data.write(to: draftURL, options: [.atomic])
    }

    public func loadDraft(id: UUID) async throws -> Draft? {
        let url = baseURL.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try await MainActor.run { try decoder.decode(Draft.self, from: data) }
    }

    public func deleteDraft(id: UUID) throws {
        let url = baseURL.appendingPathComponent("\(id.uuidString).json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
