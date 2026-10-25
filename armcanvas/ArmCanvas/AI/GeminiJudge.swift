import Foundation
import UIKit

struct JudgeResult: Codable, Equatable {
    let guess: String
    let match: Int
    let feedback: String
}

enum JudgeError: LocalizedError {
    case missingKey
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "No GOOGLE_API_KEY in the app config."
        case .badResponse(let detail): return "AI coach replied unexpectedly: \(detail)"
        }
    }
}

/// Sends three rendered views to Gemini and asks for a guess, a 0–10 match
/// rating against the target, and one coaching sentence.
final class GeminiJudge {
    static let model = "gemini-2.5-flash"
    static let timeout: TimeInterval = 15

    private let apiKey: String

    init?(apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_API_KEY") as? String) {
        guard let apiKey, !apiKey.isEmpty else { return nil }
        self.apiKey = apiKey
    }

    func judge(views: [DrawingSnapshots.View], target: DrawingTemplate) async throws -> JudgeResult {
        var parts: [[String: Any]] = [["text": Self.prompt(for: target, viewNames: views.map(\.name))]]
        for view in views {
            guard let png = view.image.pngData() else { continue }
            parts.append(["inline_data": ["mime_type": "image/png", "data": png.base64EncodedString()]])
        }
        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": ["response_mime_type": "application/json", "temperature": 0.4],
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw JudgeError.badResponse("HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")".prefix(300).description)
        }
        return try Self.parse(data)
    }

    private static var endpoint: URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
    }

    private static func prompt(for target: DrawingTemplate, viewNames: [String]) -> String {
        """
        These images are \(viewNames.joined(separator: ", ")) views of a single 3D line drawing \
        made in the air by someone doing arm rehabilitation. They were asked to draw: \(target.name) \
        (\(target.instruction)). Respond with JSON only: {"guess": "<what the drawing looks like, 2-5 words>", \
        "match": <0-10 integer, how well it matches the requested shape>, \
        "feedback": "<one short encouraging sentence with one concrete tip about shape, size or smoothness>"}
        """
    }

    private static func parse(_ data: Data) throws -> JudgeResult {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = root["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String,
            let textData = text.data(using: .utf8)
        else {
            throw JudgeError.badResponse(String(data: data, encoding: .utf8)?.prefix(200).description ?? "empty")
        }
        return try JSONDecoder().decode(JudgeResult.self, from: textData)
    }
}
