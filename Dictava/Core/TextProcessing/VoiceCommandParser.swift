import Foundation

enum VoiceCommand: Equatable {
    case deleteThat
    case undoThat
    case selectAll
    case newLine
    case newParagraph
    case stopListening
    case llmRewrite(style: LLMRewriteStyle)

    enum LLMRewriteStyle: String, Equatable {
        case shorter = "make it shorter"
        case formal = "make it formal"
        case casual = "make it casual"
        case fixGrammar = "fix grammar"
    }

    var logName: String {
        switch self {
        case .deleteThat: return "deleteThat"
        case .undoThat: return "undoThat"
        case .selectAll: return "selectAll"
        case .newLine: return "newLine"
        case .newParagraph: return "newParagraph"
        case .stopListening: return "stopListening"
        case .llmRewrite(let style): return "llmRewrite.\(style.rawValue)"
        }
    }
}

struct VoiceCommandDefinition {
    let triggers: [String]
    let command: VoiceCommand
}

final class VoiceCommandParser: TextProcessor {
    let name = "Voice Command Parser"
    var isEnabled = true

    private var commandDefinitions: [VoiceCommandDefinition] = [
        VoiceCommandDefinition(triggers: ["delete that", "scratch that"], command: .deleteThat),
        VoiceCommandDefinition(triggers: ["undo that", "undo"], command: .undoThat),
        VoiceCommandDefinition(triggers: ["select all"], command: .selectAll),
        VoiceCommandDefinition(triggers: ["new line"], command: .newLine),
        VoiceCommandDefinition(triggers: ["new paragraph"], command: .newParagraph),
        VoiceCommandDefinition(triggers: ["stop listening", "stop dictation"], command: .stopListening),
        VoiceCommandDefinition(triggers: ["make it shorter"], command: .llmRewrite(style: .shorter)),
        VoiceCommandDefinition(triggers: ["make it formal"], command: .llmRewrite(style: .formal)),
        VoiceCommandDefinition(triggers: ["make it casual"], command: .llmRewrite(style: .casual)),
        VoiceCommandDefinition(triggers: ["fix grammar", "fix the grammar"], command: .llmRewrite(style: .fixGrammar)),
    ]

    func process(_ text: String) async -> TextProcessingResult {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for definition in commandDefinitions {
            for trigger in definition.triggers {
                if lowered.hasSuffix(trigger) {
                    // Remove the command from the text
                    let commandRange = lowered.range(of: trigger, options: .backwards)!
                    let startIndex = text.index(text.startIndex, offsetBy: lowered.distance(from: lowered.startIndex, to: commandRange.lowerBound))
                    let remainingText = String(text[text.startIndex..<startIndex])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return TextProcessingResult(text: remainingText, command: definition.command)
                }

                if lowered == trigger {
                    return TextProcessingResult(text: "", command: definition.command)
                }
            }
        }

        return TextProcessingResult(text: text)
    }
}
