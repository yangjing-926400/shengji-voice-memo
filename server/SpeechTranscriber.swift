import Foundation
import Speech

func writeResult(_ result: [String: Any], to path: String) {
  let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
  try? data?.write(to: URL(fileURLWithPath: path), options: .atomic)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
  writeResult(["error": "missing input or output path"], to: "/tmp/shengji-transcriber-error.json")
  exit(2)
}

let inputPath = arguments[1]
let outputPath = arguments[2]
let inputURL = URL(fileURLWithPath: inputPath)
var latestText = ""
var finished = false

func complete(_ payload: [String: Any], code: Int32 = 0) {
  guard !finished else { return }
  finished = true
  writeResult(payload, to: outputPath)
  exit(code)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 45) {
  let payload: [String: Any] = latestText.isEmpty
    ? ["error": "语音识别超时"]
    : ["text": latestText, "partial": true]
  complete(payload, code: latestText.isEmpty ? 124 : 0)
}

SFSpeechRecognizer.requestAuthorization { authorization in
  guard authorization == .authorized else {
    complete(["error": "语音识别权限未授权"], code: 3)
    return
  }

  guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) else {
    complete(["error": "当前系统没有中文语音识别器"], code: 4)
    return
  }

  let request = SFSpeechURLRecognitionRequest(url: inputURL)
  request.shouldReportPartialResults = true
  request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
  request.taskHint = .dictation

  recognizer.recognitionTask(with: request) { result, error in
    if let result = result {
      latestText = result.bestTranscription.formattedString
      if result.isFinal {
        complete([
          "text": latestText,
          "engine": recognizer.supportsOnDeviceRecognition ? "apple-on-device" : "apple-speech",
          "confidence": 1.0
        ])
      }
    }

    if let error = error {
      if !latestText.isEmpty {
        complete(["text": latestText, "partial": true])
      } else {
        complete(["error": error.localizedDescription], code: 5)
      }
    }
  }
}

dispatchMain()
