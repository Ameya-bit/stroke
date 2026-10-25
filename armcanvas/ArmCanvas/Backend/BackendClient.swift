import Foundation
import UIKit

/// Stats the planner needs per drawing. Mirrors `TemplateStats` on the server.
struct TemplateStats: Codable {
    let template_id: String
    let default_target_m: Float
    let recent_avg_score: Float?
    let recent_best_extent_m: Float?
    let attempts: Int
    let days_since_last: Float?
    /// Motions used / motions expected over recent attempts; 1 is ideal.
    let recent_motion_ratio: Float?
}

struct RemoteScore: Codable, Identifiable, Equatable {
    let id: String
    let player: String
    let templateID: String
    let total: Int
    let extentMeters: Float
    let date: String
}

enum BackendError: LocalizedError {
    case http(Int, String)
    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "Server \(code): \(body)"
        }
    }
}

/// Thin client for the FastAPI backend. `nil` when BACKEND_URL is not configured.
final class BackendClient {
    static let timeout: TimeInterval = 15
    let baseURL: URL
    private let session: URLSession

    init?(urlString: String? = Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String) {
        guard let urlString, let url = URL(string: urlString), url.host != nil else { return nil }
        baseURL = url
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Self.timeout
        session = URLSession(configuration: config)
    }

    func plan(stats: [TemplateStats], timeBudgetSeconds: Int, reachCapMeters: Float?) async throws -> SessionPlan {
        struct Request: Codable {
            let templates: [TemplateStats]
            let time_budget_s: Int
            let reach_cap_m: Float?
        }
        return try await post("plan", body: Request(templates: stats, time_budget_s: timeBudgetSeconds, reach_cap_m: reachCapMeters))
    }

    func judge(views: [DrawingSnapshots.View], target: DrawingTemplate) async throws -> JudgeResult {
        struct Request: Codable {
            let template_name: String
            let instruction: String
            let images_png_b64: [String]
        }
        let images = views.compactMap { $0.image.pngData()?.base64EncodedString() }
        return try await post("judge", body: Request(template_name: target.name, instruction: target.instruction, images_png_b64: images))
    }

    func submit(_ entry: ScoreEntry) async throws {
        let remote = RemoteScore(
            id: entry.id.uuidString, player: entry.player, templateID: entry.templateID,
            total: entry.score.total, extentMeters: entry.score.extentMeters,
            date: ISO8601DateFormatter().string(from: entry.date)
        )
        struct Ack: Codable { let ok: Bool }
        let _: Ack = try await post("scores", body: remote)
    }

    func topScores(templateID: String, limit: Int = 10) async throws -> [RemoteScore] {
        var components = URLComponents(url: baseURL.appendingPathComponent("scores"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "template_id", value: templateID), URLQueryItem(name: "limit", value: "\(limit)")]
        let (data, response) = try await session.data(from: components.url!)
        try Self.check(response, data)
        return try JSONDecoder().decode([RemoteScore].self, from: data)
    }

    private func post<Body: Encodable, Result: Decodable>(_ path: String, body: Body) async throws -> Result {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)
        return try JSONDecoder().decode(Result.self, from: data)
    }

    private static func check(_ response: URLResponse, _ data: Data) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw BackendError.http(http.statusCode, String(data: data, encoding: .utf8)?.prefix(200).description ?? "")
        }
    }
}
