import AVFoundation
import Foundation

enum AudioRecorderError: LocalizedError {
    case microphoneDenied
    case speechPermissionDenied
    case couldNotStart
    case noRecording

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: return "请在系统设置中允许“声记”使用麦克风。"
        case .speechPermissionDenied: return "请在系统设置中允许“声记”使用语音识别。"
        case .couldNotStart: return "无法开始录音，请稍后再试。"
        case .noRecording: return "没有录到声音，请再试一次。"
        }
    }
}

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var temporaryURL: URL?

    func requestPermissions() async throws {
        let microphoneGranted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard microphoneGranted else { throw AudioRecorderError.microphoneDenied }

        let speechStatus = await SpeechTranscriber.shared.requestAuthorization()
        guard speechStatus else { throw AudioRecorderError.speechPermissionDenied }
    }

    func start() async throws {
        try await requestPermissions()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: [])

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shengji-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord(), recorder.record() else {
            throw AudioRecorderError.couldNotStart
        }

        self.recorder = recorder
        temporaryURL = url
        elapsed = 0
        isRecording = true

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                self.elapsed = recorder.currentTime
            }
        }
    }

    func stop() throws -> (url: URL, duration: TimeInterval) {
        guard let recorder, let temporaryURL else { throw AudioRecorderError.noRecording }
        let duration = recorder.currentTime

        recorder.stop()
        timer?.invalidate()
        timer = nil
        self.recorder = nil
        self.temporaryURL = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let attributes = try? FileManager.default.attributesOfItem(atPath: temporaryURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        guard fileSize > 0 else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw AudioRecorderError.noRecording
        }

        return (temporaryURL, duration)
    }

    func cancel() {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        if let temporaryURL {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
        recorder = nil
        temporaryURL = nil
        isRecording = false
        elapsed = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
