import AVFoundation
import Foundation
import Speech

/// Listens while you say a verse aloud and reports the words heard so far.
/// Recognition stays on the iPhone when the device supports it; nothing is stored.
@MainActor
@Observable
final class Listener {
    enum State: Equatable {
        case idle
        case listening
        case denied
        case unavailable
    }

    private(set) var state: State = .idle
    /// Everything heard in this attempt, lowercased words only.
    private(set) var heard = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() async {
        guard state != .listening else { return }
        guard let recognizer, recognizer.isAvailable else { state = .unavailable; return }

        let speechOK = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        let micOK = await AVAudioApplication.requestRecordPermission()
        guard speechOK, micOK else { state = .denied; return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request.addsPunctuation = false
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()

            heard = ""
            state = .listening
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result { self.heard = result.bestTranscription.formattedString.lowercased() }
                    if error != nil || (result?.isFinal ?? false) { self.stop() }
                }
            }
        } catch {
            stop()
            state = .unavailable
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if state == .listening { state = .idle }
    }

    func reset() {
        stop()
        heard = ""
        state = .idle
    }
}
