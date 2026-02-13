# Dictava

A macOS menu bar dictation app that uses WhisperKit for local, on-device speech-to-text transcription. All processing happens locally — no data leaves the Mac.

## Architecture

**App type:** Menu bar only (`LSUIElement = true`) — no dock icon, no main window. Lives in the system tray with a popover for status and a floating indicator during dictation.

**Entry point:** `DictavaApp.swift` uses `@NSApplicationDelegateAdaptor` → `AppDelegate.swift` owns all state objects and wires up the status bar controller, floating indicator, and global hotkey.

### Core Objects (all created in AppDelegate)

| Object | Role |
|--------|------|
| `DictationSession` | Central orchestrator — manages state machine (idle → listening → transcribing → processing → injecting → idle), audio capture, streaming transcription, text pipeline, and text injection |
| `SettingsStore` | `@AppStorage`-backed preferences |
| `ModelManager` | Downloads, lists, deletes WhisperKit CoreML models |
| `SnippetStore` / `VocabularyStore` | User-defined text snippets and custom vocabulary (YAML-backed) |

### Dictation Flow

1. User presses **Option+Space** (global hotkey via `KeyboardShortcuts` package)
2. `DictationSession.toggle()` → `startDictation()`
3. `AudioCaptureEngine` starts capturing mic input via `AVAudioEngine`
4. `StreamingTranscriber` feeds audio chunks to `TranscriptionEngine` (WhisperKit)
5. Live partial transcripts update `DictationSession.liveText`
6. On stop (manual or silence detection): final transcription → `TextPipeline` processing → `TextInjector` types text at cursor via CGEvents
7. Floating indicator (`DictationIndicatorWindow`) shows state throughout

### Text Pipeline

Sequential processors in `TextPipeline`:
1. `VoiceCommandParser` — detects commands like "select all", "new line", "stop listening"
2. `PunctuationHandler` — converts spoken punctuation ("period", "comma") to symbols
3. `SnippetExpander` — expands user-defined abbreviations
4. `FillerWordFilter` — removes "um", "uh", "like", etc.
5. `CustomVocabulary` — applies user-defined word corrections
6. `LLMProcessor` — optional AI cleanup (currently placeholder)

### UI Layer

- **`StatusBarController`** — NSPopover from menu bar icon, shows dictation status and audio level
- **`DictationIndicatorWindow`** — Floating NSPanel (capsule shape, `.ultraThinMaterial`), shows pulsing red dot + audio waveform during listening, spinner during processing
- **`SettingsView`** — macOS System Settings-style `NavigationSplitView` with sidebar (General, Speech Recognition, Text Processing, Snippets, Commands, Advanced)
- **`OnboardingView`** — First-launch setup wizard

## Project Structure

```
Dictava/
├── AppDelegate.swift              # App lifecycle, state object creation
├── DictavaApp.swift               # SwiftUI App, Settings scene
├── Core/
│   ├── Audio/
│   │   └── AudioCaptureEngine.swift    # AVAudioEngine mic capture
│   ├── Dictation/
│   │   ├── DictationSession.swift      # Main orchestrator
│   │   ├── DictationState.swift        # State enum
│   │   └── VoiceCommandExecutor.swift  # Executes parsed commands
│   ├── TextInjection/
│   │   ├── TextInjector.swift          # CGEvent-based typing
│   │   └── SyntheticEventMarker.swift  # Marks synthetic events
│   ├── TextProcessing/
│   │   ├── TextPipeline.swift          # Sequential processor chain
│   │   ├── VoiceCommandParser.swift
│   │   ├── PunctuationHandler.swift
│   │   ├── SnippetExpander.swift
│   │   ├── FillerWordFilter.swift
│   │   ├── CustomVocabulary.swift
│   │   └── LLMProcessor.swift
│   └── Transcription/
│       ├── ModelManager.swift          # WhisperKit model management
│       ├── StreamingTranscriber.swift  # Chunked streaming transcription
│       └── TranscriptionEngine.swift   # WhisperKit wrapper
├── Services/
│   ├── HotkeyManager.swift            # KeyboardShortcuts names
│   └── PermissionManager.swift        # Mic + Accessibility status polling
├── Storage/
│   ├── SettingsStore.swift             # @AppStorage preferences
│   ├── SnippetStore.swift              # YAML-backed snippets
│   └── VocabularyStore.swift           # YAML-backed vocabulary
├── UI/
│   ├── MenuBar/
│   │   ├── StatusBarController.swift        # Menu bar popover
│   │   └── DictationIndicatorWindow.swift   # Floating pill indicator
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   └── Settings/
│       ├── SettingsView.swift                # NavigationSplitView sidebar
│       ├── GeneralSettingsView.swift         # Hotkey, behavior, permissions
│       ├── SpeechRecognitionSettingsView.swift # Model selection, silence
│       ├── TextProcessingSettingsView.swift  # Corrections, vocabulary, AI
│       ├── SnippetSettingsView.swift
│       ├── VoiceCommandSettingsView.swift
│       └── AdvancedSettingsView.swift
└── Resources/
    ├── Assets.xcassets/                # App icon
    ├── Info.plist
    └── Dictava.entitlements
```

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) | >= 0.9.0 | Local speech-to-text via CoreML |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | >= 2.0.0 | Global hotkey recording & handling |
| [Yams](https://github.com/jpsim/Yams) | >= 5.0.0 | YAML parsing for snippets/vocabulary |

## Build

```bash
# Generate project (if needed)
xcodegen generate

# Build
xcodebuild -project Dictava.xcodeproj -scheme Dictava -destination 'platform=macOS,arch=arm64' build
```

**Requirements:** macOS 13.0+, Apple Silicon (arm64 only), Xcode 15+

## Key Implementation Details

- **WhisperKit model storage:** Models download to `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/` (not `~/Library/Application Support/`)
- **Model preloading:** The selected Whisper model loads at app launch (`AppDelegate.preloadModel()`) to avoid delay on first dictation
- **Model switching:** `DictationSession.switchModel(to:)` unloads current model and loads new one in background
- **Race condition prevention:** `state = .listening` is set synchronously before the async Task in `startDictation()` to prevent re-entry from rapid hotkey presses
- **Live text subscription:** Created per-session in `startDictation()` and cancelled in `stopDictation()` to ensure it works across multiple sessions
- **Permissions polling:** `PermissionManager` polls every 2 seconds for accessibility status changes (no system notification exists for this)
- **Text injection:** Uses `CGEvent` to synthesize keystrokes — requires Accessibility permission
- **LSUIElement focus:** Settings window calls `NSApp.activate(ignoringOtherApps: true)` on appear since menu bar apps don't auto-activate
- **Floating indicator:** `NSPanel` with `.borderless` + `.nonactivatingPanel` — doesn't steal focus from the active app
