# Dictava — Complete App Overview

A macOS menu bar dictation app powered by WhisperKit. All speech-to-text processing happens locally on-device — no data ever leaves the Mac.

---

## Table of Contents

- [How the App Works](#how-the-app-works)
- [App Lifecycle](#app-lifecycle)
- [Dictation Flow](#dictation-flow)
- [UI Elements](#ui-elements)
  - [Menu Bar Icon](#menu-bar-icon)
  - [Status Bar Popover](#status-bar-popover)
  - [Floating Indicator](#floating-indicator)
  - [Settings Window](#settings-window)
  - [Onboarding Wizard](#onboarding-wizard)
- [Features](#features)
  - [Speech-to-Text Transcription](#speech-to-text-transcription)
  - [Streaming Live Preview](#streaming-live-preview)
  - [Silence Detection](#silence-detection)
  - [Voice Commands](#voice-commands)
  - [Punctuation by Voice](#punctuation-by-voice)
  - [Filler Word Removal](#filler-word-removal)
  - [Text Snippets](#text-snippets)
  - [Custom Vocabulary](#custom-vocabulary)
  - [AI Text Cleanup (Planned)](#ai-text-cleanup-planned)
  - [Text Injection](#text-injection)
  - [Model Management](#model-management)
  - [Permission Management](#permission-management)
  - [Audio Feedback](#audio-feedback)
- [Text Processing Pipeline](#text-processing-pipeline)
- [Visual Design](#visual-design)
- [Data Storage](#data-storage)
- [Technical Details](#technical-details)

---

## How the App Works

Dictava lives in the macOS menu bar as a microphone icon — there is no dock icon and no main window (`LSUIElement = true`). The user presses a global hotkey (default **Option+Space**), speaks, and the transcribed text is typed at the cursor position in whatever app is currently focused. The entire flow — audio capture, speech recognition, text processing, and injection — happens locally on the Mac using Apple Silicon and WhisperKit CoreML models.

## App Lifecycle

1. App launches → no dock icon appears, only a menu bar icon (mic icon)
2. `AppDelegate` creates all state objects: `SettingsStore`, `ModelManager`, `SnippetStore`, `VocabularyStore`
3. `StatusBarController` is created (menu bar icon + popover)
4. `DictationIndicatorWindow` is created (hidden floating pill)
5. Global hotkey (Option+Space) is registered
6. If first launch → onboarding wizard is shown
7. Selected WhisperKit model is pre-loaded in the background so the first dictation has no delay

---

## Dictation Flow

The dictation session follows a strict state machine:

```
idle → listening → transcribing → processing → injecting → idle
                                              → executingCommand → idle
```

**Step by step:**

1. User presses **Option+Space** (or custom hotkey)
2. State changes to **listening** (set synchronously to prevent race conditions from rapid presses)
3. `AudioCaptureEngine` starts capturing microphone input via `AVAudioEngine` at 16kHz mono PCM
4. `StreamingTranscriber` feeds audio chunks to WhisperKit every 1.5 seconds
5. Live partial transcriptions appear in the popover and floating indicator
6. User stops dictation manually (press hotkey again) or silence detection triggers automatically
7. State changes to **transcribing** → WhisperKit performs final transcription
8. State changes to **processing** → text pipeline applies all transformations
9. If a voice command was detected → **executingCommand** → command runs → idle
10. Otherwise → **injecting** → text is pasted at cursor via CGEvents → idle

---

## UI Elements

### Menu Bar Icon

A system tray icon that changes based on dictation state:

| State | Icon | Meaning |
|-------|------|---------|
| Idle | `mic.fill` | Ready, not listening |
| Listening | `mic.badge.plus` | Actively capturing audio |
| Transcribing / Processing | `text.bubble.fill` | Converting speech or processing text |
| Injecting | `keyboard.fill` | Typing text at cursor |
| Executing Command | `command` | Running a voice command |

Clicking the icon opens the status bar popover.

### Status Bar Popover

A small popover (280×200 pts) attached to the menu bar icon. Behavior: `.transient` (closes when clicking outside).

**Contents from top to bottom:**

- **Header:** "Dictava" title + current state display text (e.g., "Ready", "Listening...", "Transcribing...")
- **Audio level bar:** A green gradient progress bar showing real-time microphone input level (only visible when listening)
- **Live text preview:** Shows partial transcription as it happens, up to 3 lines, in `.rounded` design font (only visible when listening)
- **Error display:** Red text showing any error message
- **Start/Stop button:** Large button to toggle dictation on/off
- **Footer info:**
  - Current model name displayed
  - Hotkey reminder: "⌥Space"
  - Gear icon link to open Settings
  - Quit button

### Floating Indicator

A translucent pill-shaped window that appears during active dictation. Designed to be unobtrusive — it doesn't steal focus from the active app.

**Window properties:**
- Type: `NSPanel` (borderless, non-activating)
- Position: Center-top of main screen, 70pts from the top edge
- Size: 320×48 pts
- Background: `.ultraThinMaterial` (translucent blur)
- Corner radius: 22 pts (pill shape)
- Shadow: 12pt blur radius, 4pt Y offset, 15% black opacity
- Window level: `.floating` (always above normal windows)
- Visible on all Spaces/desktops
- Movable by dragging the background
- Can be disabled in settings

**Animations:**
- Fade in: 0.2s ease-out
- Fade out: 0.15s ease-in

**Content varies by state:**

| State | Left | Center | Right |
|-------|------|--------|-------|
| Listening | Pulsing red dot | *(hidden)* | Audio waveform bars |
| Transcribing | Spinner (progress view) | "Transcribing..." | *(hidden)* |
| Processing | Spinner | "Processing..." | *(hidden)* |
| Injecting | Keyboard icon | "Typing..." | *(hidden)* |
| Executing Command | Command icon | "Executing..." | *(hidden)* |

**Pulsing red dot (listening state):**
- A solid red circle (10pt diameter)
- Overlaid with a red stroke circle (2pt width) that continuously pulses:
  - Scales from 1.0× to 1.8×
  - Opacity fades from 0.6 to 0
  - Animation: 1.0s ease-in-out, repeating forever

**Audio waveform (listening state):**
- 20 vertical bars
- Each bar: 3pt wide, 2pt spacing
- Height: 2–24pt, driven by real-time audio level history
- Bar colors change by audio level:
  - **Blue** (0–50%) — normal speaking
  - **Orange** (50–80%) — louder
  - **Red** (80–100%) — very loud
- Animation: `interpolatingSpring(stiffness: 300, damping: 15)`

### Settings Window

A macOS System Settings-style window (720×480 pts) with a sidebar + detail layout using `NavigationSplitView`.

**Sidebar sections** (sidebar width: 200 pts):

#### 1. General

- **Hotkey:** `KeyboardShortcuts.Recorder` to customize the global dictation hotkey (default: Option+Space)
- **Behavior toggles:**
  - Play start/stop sounds (system "Tink" and "Pop" sounds)
  - Show floating indicator
  - Launch at login
- **Permissions status:**
  - Microphone — shows granted/denied/not determined with colored badge
  - Accessibility — shows granted/denied with colored badge
  - Grant / Request buttons to trigger permission dialogs
  - Green checkmark icon when granted

#### 2. Speech Recognition

- **Whisper Model selection:**
  - Info text: "Models run locally on your Mac using Apple Silicon"
  - List of available models with name, size, speed rating
  - Download button for models not yet downloaded (shows spinner during download)
  - Checkmark on the currently selected model
  - Delete option for downloaded models
- **Silence detection:**
  - Slider: 1.0–10.0 seconds, 0.5s increments
  - Displays value as "X.Xs"
  - Controls how long silence triggers auto-stop

#### 3. Text Processing

- **Automatic Corrections:**
  - Remove filler words (um, uh, etc.) — toggle
  - Auto-capitalize sentences — toggle
  - Smart punctuation — toggle
- **AI Cleanup (planned):**
  - Enable AI text cleanup — toggle
  - Info: "Uses local LLM to clean up transcribed text"
  - When enabled: "Coming in a future update" placeholder
  - Shows planned model options (3 models)
- **Custom Vocabulary:**
  - Two input fields: "Misrecognized word" → "Correct word"
  - Add button (disabled when fields empty)
  - List of vocabulary entries showing misrecognized (with strikethrough) → corrected
  - Swipe to delete entries

#### 4. Snippets

- **Add Snippet button** (top right)
- Info text explaining template variables: `{{date}}`, `{{time}}`, `{{clipboard}}`
- List of snippets showing trigger phrase and preview of replacement text
- Context menu on each snippet: Edit / Delete
- Swipe to delete
- Sheet editor for adding/editing:
  - Trigger phrase text field
  - Replacement text area (min 100pt height)
  - Save / Cancel buttons

#### 5. Voice Commands

- Read-only list of all 10 supported voice commands
- Each entry shows: command name, trigger phrases (in quotes), and action description
- No editing UI — commands are built-in

#### 6. Advanced

- **Text Injection:** Informational text about the clipboard-paste strategy
- **Data:** Button to open the app's data folder in Finder (`~/Library/Application Support/Dictava/`)
- **About:**
  - App name: "Dictava"
  - Version: v0.1.0
  - License: MIT
- **Reset All Settings** button (destructive red styling) — resets all preferences to defaults

### Onboarding Wizard

A 5-step first-launch setup wizard. Shows a progress bar at the top with colored segments for completed steps and gray for remaining ones. Back/Continue navigation buttons at the bottom.

#### Step 1: Welcome
- Large icon: `mic.circle.fill` (64pt, blue)
- Title: "Welcome to Dictava"
- Description: Free, open-source, local, no internet, no subscriptions
- Four feature highlights:
  - "Press a hotkey and speak" — mic.fill icon (blue)
  - "Text appears at your cursor in any app" — text.cursor icon (blue)
  - "100% local, 100% private" — lock.shield icon (blue)
  - "Powered by WhisperKit + Apple Silicon" — bolt.fill icon (blue)

#### Step 2: Microphone Permission
- Icon: `mic.badge.plus` (48pt, orange)
- Title: "Microphone Access"
- Explains that audio never leaves the device
- Shows permission status badge (green/red/orange)
- Grant button if not yet granted

#### Step 3: Accessibility Permission
- Icon: `accessibility` (48pt, purple)
- Title: "Accessibility Access"
- Explains it's needed for the global hotkey and typing text at cursor
- Shows permission status badge
- "Open System Settings" button if not granted

#### Step 4: Model Download
- Icon: `cpu` (48pt, green)
- Title: "Download a Model"
- Recommends Tiny model for fast English dictation
- Shows first 2 models with download buttons
- Each shows: display name, file size, speed rating
- Checkmark on already-downloaded models
- Loading state with spinner: "This may take a moment..."
- Error state with red text

#### Step 5: Ready
- Large icon: `checkmark.circle.fill` (64pt, green)
- Title: "You're All Set!"
- Usage instructions and hotkey reminder
- `KeyboardShortcuts.Recorder` to customize hotkey before starting
- Help text: "You can change settings anytime from the menu bar"
- "Get Started" button → marks onboarding complete and closes

---

## Features

### Speech-to-Text Transcription

- Powered by **WhisperKit** running CoreML Whisper models on Apple Silicon
- Completely local — no network requests, no cloud APIs
- Supports 4 model sizes from Tiny (39 MB, ~275ms) to Large v3 Turbo (809 MB, ~3s)
- Model is pre-loaded at app launch to avoid first-dictation delay
- Model can be switched at runtime (unloads old, loads new in background)

### Streaming Live Preview

- During dictation, partial transcriptions update every 1.5 seconds
- Live text is visible in both the status bar popover and floating indicator
- Uses a per-session Combine subscription that is created on start and cancelled on stop

### Silence Detection

- Monitors real-time audio level (RMS → dB → normalized 0–1)
- Silence threshold: 0.05 (5% amplitude, roughly -26 dB)
- Configurable timeout: 1.0–10.0 seconds (default: 2.0s, step: 0.5s)
- When silence exceeds the timeout, dictation stops automatically

### Voice Commands

Spoken commands detected at the end of dictated text. The command phrase is removed from the final output.

| Command | Trigger Phrases | Action |
|---------|----------------|--------|
| Delete | "delete that", "scratch that" | Simulates Cmd+Z (undo last paste) |
| Undo | "undo that", "undo" | Simulates Cmd+Z |
| Select All | "select all" | Simulates Cmd+A |
| New Line | "new line" | Simulates Return key |
| New Paragraph | "new paragraph" | Simulates Return key twice (50ms delay between) |
| Stop Listening | "stop listening", "stop dictation" | Ends dictation session |
| Make Shorter | "make it shorter" | LLM rewrite — shorter version (planned) |
| Make Formal | "make it formal" | LLM rewrite — formal tone (planned) |
| Make Casual | "make it casual" | LLM rewrite — casual tone (planned) |
| Fix Grammar | "fix grammar", "fix the grammar" | LLM grammar cleanup (planned) |

### Punctuation by Voice

Spoken punctuation words are automatically converted to symbols:

| Say | Get |
|-----|-----|
| "period" or "full stop" | `.` |
| "comma" | `,` |
| "question mark" | `?` |
| "exclamation mark" or "exclamation point" | `!` |
| "colon" | `:` |
| "semicolon" | `;` |
| "dash" | `—` (em dash) |
| "hyphen" | `-` |
| "ellipsis" | `…` |
| "open quote" / "close quote" | `"` / `"` |
| "open paren" / "close paren" | `(` / `)` |
| "open bracket" / "close bracket" | `[` / `]` |

Space cleanup is applied: `"hello ."` becomes `"hello."`.

### Filler Word Removal

When enabled (default: on), automatically removes common filler words from transcription:

- "um", "umm"
- "uh", "uhh"
- "er", "erm"
- "ah", "ahh"

Uses a conservative set to avoid false positives. Cleans up double spaces left after removal and trims whitespace.

### Text Snippets

User-defined trigger phrases that expand into longer text blocks.

- Stored in `~/Library/Application Support/Dictava/snippets.yml` (YAML format)
- Case-insensitive trigger matching
- First match wins

**Default snippets included:**
1. "my email" → `user@example.com`
2. "meeting template" → Multi-line meeting notes template with date placeholder
3. "thanks email" → Professional thank-you response template

**Template variables:**
- `{{date}}` — Current date in medium format (e.g., "Feb 12, 2025")
- `{{time}}` — Current time in short format (e.g., "2:30 PM")
- `{{clipboard}}` — Current clipboard contents

### Custom Vocabulary

Word correction rules for consistently misrecognized words.

- Stored in `~/Library/Application Support/Dictava/vocabulary.json` (JSON format)
- Uses regex word boundary matching (`\bword\b`)
- Case-insensitive replacement
- All entries applied sequentially to final transcription

Example: If Whisper always hears "react" instead of "React", add a vocabulary entry to fix it.

### AI Text Cleanup (Planned)

A placeholder for future LLM-powered text cleanup:
- Toggle to enable AI processing
- Would use a local LLM to clean up grammar, formatting, and style
- Currently shows "Coming in a future update" in settings
- Voice commands for "make it shorter", "make it formal", "make it casual", and "fix grammar" are defined but depend on this feature

### Text Injection

How dictated text gets typed at the cursor position:

1. Current clipboard contents are saved (preserves all pasteboard types)
2. Dictated text is placed on the clipboard
3. CGEvent simulates **Cmd+V** (paste) — posted to `.cghidEventTap`
4. 200ms delay for paste to complete
5. Original clipboard contents are restored

All synthetic keyboard events are marked with a unique identifier (`0x44494354` — "DICT" in hex) to prevent feedback loops if the app is somehow monitoring its own events.

### Model Management

Four WhisperKit CoreML models available:

| Model | Display Name | File Size | Speed | Best For |
|-------|-------------|-----------|-------|----------|
| openai_whisper-tiny.en | Tiny (English) | ~39 MB | ~275ms | Fast dictation, English only |
| openai_whisper-base.en | Base (English) | ~74 MB | ~500ms | Good balance of speed and accuracy |
| openai_whisper-small.en | Small (English) | ~244 MB | ~1.5s | Better accuracy, English only |
| openai_whisper-large-v3_turbo | Large v3 Turbo | ~809 MB | ~3s | Best quality, multilingual |

- Models download to `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`
- Download managed by WhisperKit library
- Models can be downloaded, selected, and deleted from Settings
- Default model: Tiny (English)
- Selected model persisted in UserDefaults

### Permission Management

Two permissions are required:

**Microphone:**
- Checked via `AVCaptureDevice.authorizationStatus()`
- Can request permission programmatically
- Status: granted / denied / not determined

**Accessibility:**
- Checked via `AXIsProcessTrustedWithOptions()`
- Required for global hotkey capture and CGEvent text injection
- Can only open System Settings — user must grant manually
- Polled every 2 seconds (no system notification exists for accessibility changes)
- Status: granted / denied

### Audio Feedback

- **Start sound:** System "Tink" sound when dictation begins
- **Stop sound:** System "Pop" sound when dictation ends
- Can be disabled in General settings

---

## Text Processing Pipeline

Text passes through 6 sequential processors after transcription:

```
Raw transcription
  │
  ├─ 1. VoiceCommandParser    → Detects and extracts voice commands from end of text
  ├─ 2. PunctuationHandler    → Converts spoken punctuation to symbols
  ├─ 3. SnippetExpander       → Replaces trigger phrases with snippet content
  ├─ 4. FillerWordFilter      → Removes "um", "uh", etc.
  ├─ 5. CustomVocabulary      → Applies user-defined word corrections
  └─ 6. LLMProcessor          → AI cleanup (placeholder, currently disabled)
  │
Final text → injected at cursor
```

If a voice command is detected in step 1, the command is extracted and executed after all text processing completes. The command phrase is removed from the text output.

---

## Visual Design

### Colors
- Primary accent: System blue
- Permission states: Green (granted), Red (denied), Orange (not determined)
- Audio waveform bars: Blue (0–50%) → Orange (50–80%) → Red (80–100%)
- Text hierarchy: `.primary`, `.secondary`, `.tertiary`
- Backgrounds: `.quaternary` for surfaces, `.ultraThinMaterial` for floating indicator

### Typography
- Large headings: `.largeTitle`, `.title2`
- Controls and body: `.body`, `.callout`
- Secondary info: `.caption`
- Dictation text: `.rounded` design
- Numeric displays: `.monospacedDigit`

### Spacing and Shapes
- Standard padding: 8–16 pts
- Corner radius: 6–8 pts (standard), 22 pts (floating indicator pill)
- Shadow: 12pt blur, 4pt Y offset, 15% black opacity
- Standard animation duration: 0.2s ease-in-out

---

## Data Storage

| Data | Location | Format |
|------|----------|--------|
| User preferences | UserDefaults (standard) | Key-value pairs |
| Snippets | `~/Library/Application Support/Dictava/snippets.yml` | YAML |
| Custom vocabulary | `~/Library/Application Support/Dictava/vocabulary.json` | JSON |
| WhisperKit models | `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/` | CoreML bundles |

---

## Technical Details

- **Platform:** macOS 13.0+ (Ventura and later)
- **Architecture:** Apple Silicon only (arm64)
- **Build tool:** Xcode 15+
- **UI framework:** SwiftUI with AppKit integration (NSPanel, NSStatusItem, NSPopover)
- **Audio:** AVAudioEngine, 16kHz mono Float32 PCM
- **Speech recognition:** WhisperKit (CoreML)
- **Hotkey:** KeyboardShortcuts package
- **Serialization:** Yams (YAML) + Foundation (JSON)
- **License:** MIT
- **Version:** 0.1.0

### Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| WhisperKit | >= 0.9.0 | Local speech-to-text via CoreML |
| KeyboardShortcuts | >= 2.0.0 | Global hotkey recording and handling |
| Yams | >= 5.0.0 | YAML parsing for snippets |
