import Foundation
import Security

/// Minimal streaming client for the Claude Messages API (no official Swift SDK, so raw HTTP + SSE).
struct ClaudeClient {
    struct Message: Codable, Equatable {
        let role: String // "user" or "assistant"
        let content: String
    }

    enum ClaudeError: LocalizedError {
        case missingKey
        case http(Int, String)
        case stream(String)
        case refusal

        var errorDescription: String? {
            switch self {
            case .missingKey:
                #if os(macOS)
                return "No API key. Set ANTHROPIC_API_KEY or add a key in Settings (⌘,)."
                #else
                return "No API key. Tap the key button above to add one."
                #endif
            case .http(let code, let message): return "API error \(code): \(message)"
            case .stream(let message): return "Stream error: \(message)"
            case .refusal: return "Claude declined to answer this one."
            }
        }
    }

    static let model = "claude-opus-5-5"

    let apiKey: String

    /// Environment variable first (handy with `swift run`), then the key saved in Settings.
    static func fromEnvironmentOrKeychain() throws -> ClaudeClient {
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
            return ClaudeClient(apiKey: key)
        }
        if let key = KeychainKey.load(), !key.isEmpty {
            return ClaudeClient(apiKey: key)
        }
        throw ClaudeError.missingKey
    }

    /// Streams the assistant's text as it is generated.
    func stream(system: String, messages: [Message]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(system: system, messages: messages) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(system: String, messages: [Message], onText: (String) -> Void) async throws {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // Server-side fallback: if a safety classifier declines, the API retries on a fallback model in the same stream.
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16000,
            "stream": true,
            "output_config": ["effort": "low"],
            "fallbacks": "default",
            "system": system,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            throw ClaudeError.http(status, Self.errorMessage(data) ?? String(decoding: data, as: UTF8.self))
        }

        var stopReason: String?
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let event = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else { continue }
            switch event["type"] as? String {
            case "content_block_delta":
                // Only text deltas are shown; thinking and fallback-marker blocks are ignored.
                if let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    onText(text)
                }
            case "message_delta":
                if let delta = event["delta"] as? [String: Any], let reason = delta["stop_reason"] as? String {
                    stopReason = reason
                }
            case "error":
                let error = event["error"] as? [String: Any]
                throw ClaudeError.stream(error?["message"] as? String ?? "unknown error")
            default:
                break
            }
        }
        if stopReason == "refusal" { throw ClaudeError.refusal }
    }

    private static func errorMessage(_ data: Data) -> String? {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["error"] as? [String: Any])?["message"] as? String
    }
}

/// Stores the API key in the login keychain.
enum KeychainKey {
    private static let service = "Quarksman.anthropic-api-key"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        guard !key.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}
