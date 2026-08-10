import Foundation

struct SyntheticClient: Sendable {
    private let session: URLSession
    private let endpoint = URL(string: "https://api.synthetic.new/v2/quotas")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchQuota(apiKey: String) async throws -> QuotaResponse {
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyntheticError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw SyntheticError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(QuotaResponse.self, from: data)
    }
}

enum SyntheticError: LocalizedError, Equatable {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Synthetic returned an unreadable response."
        case .httpStatus(401), .httpStatus(403):
            "That API key was rejected."
        case .httpStatus(let status):
            "Synthetic returned an error (\(status))."
        }
    }
}

