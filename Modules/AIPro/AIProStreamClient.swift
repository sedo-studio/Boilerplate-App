//
//  AIProStreamClient.swift
//
//  PRO feature — streaming chat. Talks to the backend's `/v1/chat/stream` SSE
//  endpoint (works with both the OpenAI and Gemini providers). Includes an
//  offline mock streamer so the chat demos without a running backend.
//
//  Self-contained: delete `Modules/AIPro` + flip `featureFlags.aiPro` off.
//

import Foundation

struct AIProStreamClient {
    var baseURL: URL = Secrets.aiBackendBaseURL

    /// Streams assistant text deltas from the backend via Server-Sent Events.
    func stream(messages: [[String: String]], model: String = "gpt-4o-mini",
                temperature: Double = 0.7) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var req = URLRequest(url: baseURL.appendingPathComponent("/v1/chat/stream"))
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.timeoutInterval = 60
                    req.httpBody = try JSONSerialization.data(withJSONObject: [
                        "messages": messages, "model": model, "temperature": temperature, "stream": true
                    ])

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        throw NSError(domain: "AIPro", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Streaming endpoint unavailable"])
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        if let data = payload.data(using: .utf8),
                           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let delta = obj["delta"] as? String { continuation.yield(delta) }
                            else if let err = obj["error"] as? String {
                                throw NSError(domain: "AIPro", code: -2, userInfo: [NSLocalizedDescriptionKey: err])
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Offline canned streamer — used as a fallback so the demo always streams.
    static func mockStream(for prompt: String) -> AsyncStream<String> {
        let reply = "Here's a streamed reply to “\(prompt)”. AI PRO streams tokens one chunk at a time, persists your conversation, and works with OpenAI or Gemini. Point AIProStreamClient at your backend's /v1/chat/stream endpoint to go live."
        let chunks = reply.split(separator: " ").map { String($0) + " " }
        return AsyncStream { continuation in
            Task {
                for chunk in chunks {
                    try? await Task.sleep(nanoseconds: 45_000_000)
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}
