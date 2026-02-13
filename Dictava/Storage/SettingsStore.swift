import SwiftUI
import Combine

final class SettingsStore: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("selectedModelName") var selectedModelName = "tiny.en"
    @AppStorage("silenceTimeoutSeconds") var silenceTimeoutSeconds = 2.0
    @AppStorage("removeFillerWords") var removeFillerWords = true
    @AppStorage("autoCapitalize") var autoCapitalize = true
    @AppStorage("autoPunctuation") var autoPunctuation = true
    @AppStorage("playStartStopSounds") var playStartStopSounds = true
    @AppStorage("showFloatingIndicator") var showFloatingIndicator = true
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("llmEnabled") var llmEnabled = false
    @AppStorage("selectedLLMModel") var selectedLLMModel = ""
    @AppStorage("showDockIcon") var showDockIcon = false
}
