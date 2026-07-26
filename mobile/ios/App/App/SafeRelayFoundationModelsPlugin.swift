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
    Answer the latest message directly and continue the conversation naturally.
    Do not restate earlier advice unless it is essential to safety; when it is,
    mention it briefly and add useful new information. Use numbered steps only
    when the user needs an ordered procedure. Never emit JSON, XML, tool calls,
    tool names, code fences, schemas, or response metadata.
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
        let latestUserMessage = messages.last?.content ?? ""
        let recentConversation = messages.dropLast().suffix(8).map { message in
            let speaker = message.role == "user" ? "User" : "Guide"
            return "\(speaker): \(String(message.content.prefix(600)))"
        }.joined(separator: "\n")
        let prompt = """
        Recent conversation for continuity:
        \(recentConversation.isEmpty ? "(none)" : recentConversation)

        Latest user message:
        \(latestUserMessage)

        Relevant local field observations (may be empty and are not confirmed
        outcomes):
        \(String(fieldContext.prefix(2_000)))

        Reply only to the latest user message. Build on the conversation without
        repeating the Guide's previous answer. Be concise and conversational.
        Use steps only when an ordered procedure is genuinely useful.
        """

        Task {
            do {
                let session = LanguageModelSession(model: model, instructions: instructions)
                let response = try await session.respond(to: prompt)
                var reply = String(response.content.prefix(2_400))
                let previousReply = messages.dropLast().last(
                    where: { $0.role == "assistant" }
                )?.content
                if requiresPlainTextRetry(reply)
                    || substantiallyRepeats(reply, previousReply) {
                    let revisionSession = LanguageModelSession(
                        model: model,
                        instructions: """
                        Answer only the new detail in the user's latest message.
                        Never provide a general survival checklist or recap prior
                        advice. Use at most three short conversational sentences.
                        Do not use a numbered list, structured data, or tool calls.
                        """
                    )
                    let corrected = try await revisionSession.respond(
                        to: """
                        Latest message:
                        \(latestUserMessage)

                        Prior answer to avoid:
                        \(String((previousReply ?? "").prefix(1_200)))

                        Give only new, specific guidance for the latest message.
                        Do not reuse any sentence, step, or opening phrase from
                        the prior answer.
                        """
                    )
                    reply = String(corrected.content.prefix(2_400))
                }
                if substantiallyRepeats(reply, previousReply) {
                    reply = """
                    I do not want to repeat the earlier checklist. What changed \
                    since your last message, and which single decision do you \
                    need help with right now?
                    """
                }
                call.resolve([
                    "available": true,
                    "availability": "available",
                    "reply": normalizedReply(reply)
                ])
            } catch let error as LanguageModelError {
                switch error {
                case .guardrailViolation, .refusal:
                    call.resolve([
                        "available": true,
                        "availability": "available",
                        "reply": """
                        I can't help with that request. I can still help with \
                        immediate safety, evacuation, shelter, first aid, or \
                        signaling. Tell me what is happening and what you need \
                        right now.
                        """
                    ])
                default:
                    call.reject("On-device guide is temporarily unavailable.")
                }
            } catch {
                call.reject("On-device guide is temporarily unavailable.")
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

    private func substantiallyRepeats(
        _ candidate: String,
        _ previous: String?
    ) -> Bool {
        guard let previous else { return false }
        let candidateWords = significantWords(in: candidate)
        let previousWords = significantWords(in: previous)
        guard candidateWords.count >= 8, previousWords.count >= 8 else {
            return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(
                    previous.trimmingCharacters(in: .whitespacesAndNewlines)
                ) == .orderedSame
        }
        let shared = candidateWords.intersection(previousWords).count
        let smallerCount = min(candidateWords.count, previousWords.count)
        return Double(shared) / Double(smallerCount) >= 0.42
    }

    private func significantWords(in content: String) -> Set<String> {
        Set(
            content.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count > 3 }
        )
    }
}
