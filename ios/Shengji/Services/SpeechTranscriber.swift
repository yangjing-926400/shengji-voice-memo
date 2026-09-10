import Foundation
import Speech

enum SpeechTranscriberError: LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case noSpeech
    case timedOut

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "语音识别权限未开启。"
        case .recognizerUnavailable: return "当前设备没有可用的中文语音识别器。"
        case .noSpeech: return "没有听清，请再试一次。"
        case .timedOut: return "语音识别超时，请重试。"
        }
    }
}

actor SpeechTranscriber {
    static let shared = SpeechTranscriber()

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(url: URL) async throws -> String {
        guard await requestAuthorization() else {
            throw SpeechTranscriberError.permissionDenied
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) else {
            throw SpeechTranscriberError.recognizerUnavailable
        }

        if !recognizer.isAvailable {
            try? await Task.sleep(nanoseconds: 350_000_000)
        }
        guard recognizer.isAvailable else {
            throw SpeechTranscriberError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.taskHint = .dictation
        request.addsPunctuation = true

        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var finished = false
            var latestText = ""
            var recognitionTask: SFSpeechRecognitionTask?

            func finish(_ result: Result<String, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                recognitionTask?.cancel()
                continuation.resume(with: result)
            }

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    latestText = result.bestTranscription.formattedString
                    if result.isFinal {
                        let text = latestText.trimmingCharacters(in: .whitespacesAndNewlines)
                        finish(text.isEmpty ? .failure(SpeechTranscriberError.noSpeech) : .success(text))
                    }
                }

                if let error {
                    if !latestText.isEmpty {
                        finish(.success(latestText))
                    } else {
                        finish(.failure(error))
                    }
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 60) {
                if latestText.isEmpty {
                    finish(.failure(SpeechTranscriberError.timedOut))
                } else {
                    finish(.success(latestText))
                }
            }
        }
    }
}
