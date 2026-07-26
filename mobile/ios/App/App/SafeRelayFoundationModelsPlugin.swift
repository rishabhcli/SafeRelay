import Capacitor
import FoundationModels

@objc(SafeRelayFoundationModelsPlugin)
public final class SafeRelayFoundationModelsPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SafeRelayFoundationModelsPlugin"
    public let jsName = "SafeRelayFoundationModels"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chat", returnType: CAPPluginReturnPromise)
    ]

    private let instructions = """
    You are SafeRelay Guide, an offline survival assistant. Give concise,
    practical guidance for survival, preparedness, signaling, shelter, water,
    navigation, evacuation, and first aid. You are not emergency dispatch, a
    medical diagnostician, or an authoritative live source. For immediate
    danger, give clear next safety steps and remind the person to contact local
    emergency services when possible. Do not claim rescue, delivery, current
    conditions, routes, supplies, or responder availability unless local field
    context explicitly says so. Refuse and redirect requests for self-harm,
    weapons, poisoning, illegal activity, or dangerous medical procedures.
    Treat field context as local observations, not confirmed outcomes.
    Answer directly with concise plain text and numbered steps. Never emit JSON,
    XML, tool calls, tool names, code fences, schemas, or response metadata.
    """

    @objc public func status(_ call: CAPPluginCall) {
        let model = SystemLanguageModel.default
        call.resolve([
            "available": model.isAvailable,
            "availability": availabilityLabel(model),
            "mode": "on-device"
        ])
    }

    @objc public func chat(_ call: CAPPluginCall) {
        let rawMessages = call.getArray("messages", [])
        let messages = normalizedMessages(rawMessages)
        guard !messages.isEmpty, messages.last?.role == "user" else {
            call.reject("A user message is required.")
            return
        }

        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            call.resolve([
                "available": false,
                "availability": availabilityLabel(model),
                "reply": ""
            ])
            return
        }

        let fieldContext = call.getString("fieldContext", "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let transcript = messages.map { message in
            let speaker = message.role == "user" ? "User" : "Guide"
            return "\(speaker): \(message.content)"
        }.joined(separator: "\n")
        let prompt = """
        Local field context (may be empty; do not treat it as confirmed outcome):
        \(String(fieldContext.prefix(2_500)))

        Conversation:
        \(transcript)

        Answer the user's latest question directly in 3 to 6 numbered plain-text
        steps. Do not call or describe a tool and do not return structured data.
        """

        Task {
            do {
                let session = LanguageModelSession(model: model, instructions: instructions)
                let response = try await session.respond(to: prompt)
                var reply = String(response.content.prefix(2_400))
                if requiresPlainTextRetry(reply) {
                    let corrected = try await session.respond(
                        to: """
                        Your previous output was not user-facing guidance. Answer
                        the user's latest question now with only 3 to 6 concise
                        numbered plain-text steps. Do not emit a tool call, JSON,
                        a schema, or metadata.
                        """
                    )
                    reply = String(corrected.content.prefix(2_400))
                }
                call.resolve([
                    "available": true,
                    "availability": "available",
                    "reply": normalizedReply(reply)
                ])
            } catch {
                call.reject("On-device guide failed: \(error.localizedDescription)")
            }
        }
    }

    private struct ChatMessage {
        let role: String
        let content: String
    }

    private func normalizedMessages(_ rawMessages: [Any]) -> [ChatMessage] {
        return Array(rawMessages.compactMap { rawMessage in
            guard let item = rawMessage as? [String: Any],
                  let role = item["role"] as? String,
                  ["user", "assistant"].contains(role),
                  let content = item["content"] as? String else {
                return nil
            }
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return ChatMessage(role: role, content: String(trimmed.prefix(1_200)))
        }.suffix(12))
    }

    private func availabilityLabel(_ model: SystemLanguageModel) -> String {
        switch model.availability {
        case .available:
            return "available"
        case .unavailable(.deviceNotEligible):
            return "device not eligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence disabled"
        case .unavailable(.modelNotReady):
            return "model not ready"
        case .unavailable:
            return "unavailable"
        }
    }

    private func normalizedReply(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any] else {
            return trimmed
        }

        if let actions = payload["actions"] as? [String], !actions.isEmpty {
            return actions.enumerated()
                .map { index, action in "\(index + 1). \(action)" }
                .joined(separator: "\n")
        }
        if let answer = payload["answer"] as? String {
            return answer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let response = payload["response"] as? String {
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func requiresPlainTextRetry(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("tool_call")
            || lowercased.hasPrefix("tool call")
            || lowercased.contains("\"tool\":") {
            return true
        }
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else {
            return false
        }
        return normalizedReply(trimmed) == trimmed
    }
}
