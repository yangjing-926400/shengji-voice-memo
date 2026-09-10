#!/bin/zsh
set -e
cd "$(dirname "$0")"
rm -rf SpeechTranscriber.app
mkdir -p SpeechTranscriber.app/Contents/MacOS
swiftc SpeechTranscriber.swift -o SpeechTranscriber.app/Contents/MacOS/SpeechTranscriber -framework Speech
cat > SpeechTranscriber.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.shengji.speechtranscriber</string>
<key>CFBundleName</key><string>SpeechTranscriber</string>
<key>CFBundleExecutable</key><string>SpeechTranscriber</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>NSSpeechRecognitionUsageDescription</key><string>声记需要把语音录音转换为文字。</string>
<key>NSMicrophoneUsageDescription</key><string>声记需要使用麦克风记录语音。</string>
</dict></plist>
PLIST
codesign --force --deep --sign - SpeechTranscriber.app
