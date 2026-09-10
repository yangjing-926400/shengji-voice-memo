const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;

function pickMimeType() {
  if (!window.MediaRecorder?.isTypeSupported) return "";
  const candidates = [
    "audio/webm;codecs=opus",
    "audio/webm",
    "audio/mp4",
    "audio/aac"
  ];
  return candidates.find((type) => MediaRecorder.isTypeSupported(type)) || "";
}


function writeAscii(view, offset, text) {
  for (let index = 0; index < text.length; index += 1) {
    view.setUint8(offset + index, text.charCodeAt(index));
  }
}

function encodePcm16Wav(samples, sampleRate) {
  const buffer = new ArrayBuffer(44 + samples.length * 2);
  const view = new DataView(buffer);
  writeAscii(view, 0, "RIFF");
  view.setUint32(4, 36 + samples.length * 2, true);
  writeAscii(view, 8, "WAVE");
  writeAscii(view, 12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  writeAscii(view, 36, "data");
  view.setUint32(40, samples.length * 2, true);

  let offset = 44;
  for (let index = 0; index < samples.length; index += 1) {
    const sample = Math.max(-1, Math.min(1, samples[index]));
    view.setInt16(offset, sample < 0 ? sample * 0x8000 : sample * 0x7fff, true);
    offset += 2;
  }
  return new Blob([buffer], { type: "audio/wav" });
}

function blobToArrayBuffer(blob) {
  if (blob.arrayBuffer) return blob.arrayBuffer();
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(reader.error);
    reader.readAsArrayBuffer(blob);
  });
}

export async function convertToWav16k(blob) {
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  const OfflineAudioContextClass = window.OfflineAudioContext || window.webkitOfflineAudioContext;
  if (!AudioContextClass || !OfflineAudioContextClass) return blob;

  const sourceBuffer = await blobToArrayBuffer(blob);
  const audioContext = new AudioContextClass();
  try {
    if (audioContext.state === "suspended") await audioContext.resume();
    const decoded = await audioContext.decodeAudioData(sourceBuffer.slice(0));
    const targetRate = 16000;
    const frames = Math.max(1, Math.ceil(decoded.duration * targetRate));
    const offline = new OfflineAudioContextClass(1, frames, targetRate);
    const source = offline.createBufferSource();
    source.buffer = decoded;
    source.connect(offline.destination);
    source.start(0);
    const rendered = await offline.startRendering();
    return encodePcm16Wav(rendered.getChannelData(0), targetRate);
  } finally {
    try { await audioContext.close(); } catch { /* ignored */ }
  }
}

export function supportsRecording() {
  return Boolean(navigator.mediaDevices?.getUserMedia && window.MediaRecorder);
}

export function supportsSpeechRecognition() {
  return Boolean(SpeechRecognition);
}

export class VoiceRecorder {
  constructor({ onInterim = () => {}, onFinal = () => {} } = {}) {
    this.onInterim = onInterim;
    this.onFinal = onFinal;
    this.chunks = [];
    this.finalTranscript = "";
    this.interimTranscript = "";
    this.startedAt = 0;
    this.recording = false;
    this.stopping = false;
    this.recognition = null;
    this.mediaRecorder = null;
    this.stream = null;
    this.stopPromise = null;
    this.stopResolve = null;
  }

  async start() {
    if (!supportsRecording()) {
      throw new Error("当前浏览器不支持录音，请使用最新版 Safari 或 Chrome。");
    }

    this.stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true
      }
    });

    const mimeType = pickMimeType();
    this.mediaRecorder = mimeType
      ? new MediaRecorder(this.stream, { mimeType })
      : new MediaRecorder(this.stream);

    this.chunks = [];
    this.finalTranscript = "";
    this.interimTranscript = "";
    this.startedAt = Date.now();
    this.recording = true;
    this.stopping = false;
    this.stopPromise = new Promise((resolve, reject) => {
      this.stopResolve = resolve;
      this.stopReject = reject;
    });

    this.mediaRecorder.addEventListener("dataavailable", (event) => {
      if (event.data?.size) this.chunks.push(event.data);
    });

    this.mediaRecorder.addEventListener("error", (event) => {
      this.stopReject?.(event.error || new Error("录音失败"));
    });

    this.mediaRecorder.addEventListener("stop", () => {
      const type = this.mediaRecorder?.mimeType || mimeType || "audio/webm";
      const blob = new Blob(this.chunks, { type });
      this.cleanupTracks();
      this.stopResolve?.({
        blob,
        transcript: this.finalTranscript.trim() || this.interimTranscript.trim(),
        durationMs: Date.now() - this.startedAt,
        recognitionSupported: supportsSpeechRecognition()
      });
    });

    this.mediaRecorder.start(250);
    this.startRecognition();
  }

  startRecognition() {
    if (!supportsSpeechRecognition()) return;

    const recognition = new SpeechRecognition();
    this.recognition = recognition;
    recognition.lang = "zh-CN";
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.maxAlternatives = 1;

    recognition.onresult = (event) => {
      let interim = "";
      for (let index = event.resultIndex; index < event.results.length; index += 1) {
        const text = event.results[index][0]?.transcript || "";
        if (event.results[index].isFinal) {
          this.finalTranscript += text;
        } else {
          interim += text;
        }
      }
      this.interimTranscript = interim;
      this.onInterim(`${this.finalTranscript}${this.interimTranscript}`.trim());
      this.onFinal(this.finalTranscript.trim());
    };

    recognition.onerror = (event) => {
      if (event.error === "not-allowed" || event.error === "service-not-allowed") {
        this.onInterim("语音识别权限未开启，音频仍会保存在本机。");
      }
    };

    recognition.onend = () => {
      if (this.recording && !this.stopping) {
        try {
          recognition.start();
        } catch {
          // Some browsers need a short pause before restarting.
          window.setTimeout(() => {
            if (this.recording && !this.stopping) {
              try { recognition.start(); } catch { /* ignored */ }
            }
          }, 180);
        }
      }
    };

    try {
      recognition.start();
    } catch {
      // Recording still works without live transcription.
    }
  }

  async stop() {
    if (!this.recording || !this.mediaRecorder) {
      return {
        blob: new Blob([], { type: "audio/webm" }),
        transcript: "",
        durationMs: 0,
        recognitionSupported: supportsSpeechRecognition()
      };
    }

    this.stopping = true;
    this.recording = false;
    try { this.recognition?.stop(); } catch { /* ignored */ }

    if (this.mediaRecorder.state !== "inactive") {
      this.mediaRecorder.stop();
    }

    return this.stopPromise;
  }

  cancel() {
    this.stopping = true;
    this.recording = false;
    try { this.recognition?.abort(); } catch { /* ignored */ }
    if (this.mediaRecorder && this.mediaRecorder.state !== "inactive") {
      try { this.mediaRecorder.stop(); } catch { /* ignored */ }
    }
    this.cleanupTracks();
  }

  cleanupTracks() {
    this.stream?.getTracks().forEach((track) => track.stop());
    this.stream = null;
  }
}

export function recognizeOnce({ onInterim = () => {}, timeoutMs = 8000 } = {}) {
  if (!supportsSpeechRecognition()) {
    return Promise.reject(new Error("当前浏览器不支持语音识别，请先输入文字搜索。"));
  }

  return new Promise((resolve, reject) => {
    const recognition = new SpeechRecognition();
    let settled = false;
    let transcript = "";
    const timeout = window.setTimeout(() => finish("没有听清，请再试一次。", true), timeoutMs);

    function finish(message, isError = false) {
      if (settled) return;
      settled = true;
      window.clearTimeout(timeout);
      try { recognition.stop(); } catch { /* ignored */ }
      if (isError) reject(new Error(message));
      else resolve(transcript.trim());
    }

    recognition.lang = "zh-CN";
    recognition.continuous = false;
    recognition.interimResults = true;
    recognition.maxAlternatives = 1;

    recognition.onresult = (event) => {
      transcript = Array.from(event.results).map((result) => result[0]?.transcript || "").join("");
      onInterim(transcript);
      if (event.results[event.results.length - 1]?.isFinal) finish();
    };

    recognition.onerror = (event) => {
      const message = event.error === "not-allowed"
        ? "麦克风权限未开启。"
        : "没有听清，请再试一次。";
      finish(message, true);
    };

    recognition.onend = () => {
      if (!settled) {
        if (transcript.trim()) finish();
        else finish("没有听清，请再试一次。", true);
      }
    };

    try {
      recognition.start();
    } catch {
      finish("语音识别启动失败。", true);
    }
  });
}


export function recordAudioOnce({ durationMs = 6000 } = {}) {
  return new Promise(async (resolve, reject) => {
    if (!supportsRecording()) {
      reject(new Error("当前浏览器不支持录音。"));
      return;
    }

    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mimeType = pickMimeType();
      const recorder = mimeType ? new MediaRecorder(stream, { mimeType }) : new MediaRecorder(stream);
      const chunks = [];

      recorder.addEventListener("dataavailable", (event) => {
        if (event.data?.size) chunks.push(event.data);
      });

      recorder.addEventListener("stop", () => {
        stream.getTracks().forEach((track) => track.stop());
        resolve(new Blob(chunks, { type: recorder.mimeType || mimeType || "audio/webm" }));
      });

      recorder.addEventListener("error", (event) => {
        stream.getTracks().forEach((track) => track.stop());
        reject(event.error || new Error("录音失败"));
      });

      recorder.start(200);
      window.setTimeout(() => {
        if (recorder.state !== "inactive") recorder.stop();
      }, durationMs);
    } catch (error) {
      stream?.getTracks().forEach((track) => track.stop());
      reject(error);
    }
  });
}
