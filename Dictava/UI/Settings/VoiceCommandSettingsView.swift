import SwiftUI

struct VoiceCommandSettingsView: View {
    private let commands: [(name: String, triggers: String, action: String)] = [
        ("Delete/Scratch", "\"delete that\", \"scratch that\"", "Undo (Cmd+Z)"),
        ("Undo", "\"undo that\", \"undo\"", "Undo (Cmd+Z)"),
        ("Select All", "\"select all\"", "Select All (Cmd+A)"),
        ("New Line", "\"new line\"", "Insert line break"),
        ("New Paragraph", "\"new paragraph\"", "Insert double line break"),
        ("Stop Listening", "\"stop listening\"", "End dictation session"),
        ("Make Shorter", "\"make it shorter\"", "LLM rewrite (shorter)"),
        ("Make Formal", "\"make it formal\"", "LLM tone shift (formal)"),
        ("Make Casual", "\"make it casual\"", "LLM tone shift (casual)"),
        ("Fix Grammar", "\"fix grammar\"", "LLM grammar cleanup"),
    ]

    var body: some View {
        Form {
            Section {
                Text("Say these phrases at the end of your dictation to trigger actions. Commands are detected after you stop speaking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(commands, id: \.name) { command in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.name)
                                .fontWeight(.medium)
                            Text(command.triggers)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(command.action)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Voice Commands")
            }
        }
        .formStyle(.grouped)
    }
}
