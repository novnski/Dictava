import Foundation
import WhisperKit
import Combine

/// Thread-safe buffer for collecting audio samples from the audio callback
private actor AudioSampleBuffer {
    private var samples: [Float] = []

    func append(_ newSamples: [Float]) {
        samples.append(contentsOf: newSamples)
    }

    func getAll() -> [Float] {
        samples
    }

    func clear() {
        samples.removeAll()
    }
}

@MainActor
final class TranscriptionEngine: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isTranscribing = false
    @Published var partialText = ""
    @Published var confirmedText = ""

    private var whisperKit: WhisperKit?
    private let sampleBuffer = AudioSampleBuffer()

    func loadModel(named modelName: String) async throws {
        whisperKit = try await WhisperKit(
            model: modelName,
            verbose: false,
            logLevel: .none
        )
        isModelLoaded = true
    }

    func unloadModel() {
        whisperKit = nil
        isModelLoaded = false
    }

    nonisolated func appendAudioBuffer(_ samples: [Float]) {
        Task {
            await sampleBuffer.append(samples)
        }
    }

    func transcribe() async -> String {
        guard let whisperKit else { return "" }

        let samples = await sampleBuffer.getAll()
        guard !samples.isEmpty else { return "" }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let results = try await whisperKit.transcribe(audioArray: samples)
            let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            confirmedText = text
            return text
        } catch {
            print("Transcription error: \(error)")
            return ""
        }
    }

    func transcribePartial() async {
        guard let whisperKit else { return }

        let samples = await sampleBuffer.getAll()
        guard !samples.isEmpty else { return }

        do {
            let results = try await whisperKit.transcribe(audioArray: samples)
            let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            partialText = text
        } catch {
            // Partial transcription errors are expected during streaming
        }
    }

    func reset() {
        Task {
            await sampleBuffer.clear()
        }
        partialText = ""
        confirmedText = ""
    }
}
