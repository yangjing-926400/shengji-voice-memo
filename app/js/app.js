import {
  addNote,
  addNoteWithAudio,
  deleteNote,
  getAllGroups,
  getAllNotes,
  getAudio,
  seedDefaultGroups
} from "./db.js";
import { classifyNote, createTitle, DEFAULT_GROUPS } from "./classifier.js";
import { searchNotes } from "./search.js";
import {
  convertToWav16k,
  recognizeOnce,
  recordAudioOnce,
  supportsRecording,
  supportsSpeechRecognition,
  VoiceRecorder
} from "./recorder.js";

const dom = {
  homeView: document.getElementById("homeView"),
  recordView: document.getElementById("recordView"),
  searchView: document.getElementById("searchView"),
  todayLabel: document.getElementById("todayLabel"),
  summaryText: document.getElementById("summaryText"),
  installTip: document.getElementById("installTip"),
  dismissInstallTip: document.getElementById("dismissInstallTip"),
  emptyState: document.getElementById("emptyState"),
  groups: document.getElementById("groups"),
  startRecordButton: document.getElementById("startRecordButton"),
  openSearchButton: document.getElementById("openSearchButton"),
  cancelRecordButton: document.getElementById("cancelRecordButton"),
  stopRecordButton: document.getElementById("stopRecordButton"),
  recordTimer: document.getElementById("recordTimer"),
  recordingStatus: document.getElementById("recordingStatus"),
  liveTranscript: document.getElementById("liveTranscript"),
  closeSearchButton: document.getElementById("closeSearchButton"),
  searchForm: document.getElementById("searchForm"),
  searchInput: document.getElementById("searchInput"),
  voiceSearchButton: document.getElementById("voiceSearchButton"),
  askAgainButton: document.getElementById("askAgainButton"),
  searchStatus: document.getElementById("searchStatus"),
  searchAnswer: document.getElementById("searchAnswer"),
  answerLabel: document.getElementById("answerLabel"),
  answerText: document.getElementById("answerText"),
  searchResults: document.getElementById("searchResults"),
  searchEmpty: document.getElementById("searchEmpty"),
  detailSheet: document.getElementById("detailSheet"),
  dictationSheet: document.getElementById("dictationSheet"),
  openRecorderButton: document.getElementById("openRecorderButton"),
  closeDictationButton: document.getElementById("closeDictationButton"),
  saveDictationButton: document.getElementById("saveDictationButton"),
  dictationText: document.getElementById("dictationText"),
  closeDetailButton: document.getElementById("closeDetailButton"),
  deleteNoteButton: document.getElementById("deleteNoteButton"),
  detailGroup: document.getElementById("detailGroup"),
  detailTitle: document.getElementById("detailTitle"),
  detailMeta: document.getElementById("detailMeta"),
  detailAudio: document.getElementById("detailAudio"),
  detailTranscript: document.getElementById("detailTranscript"),
  toast: document.getElementById("toast")
};

const state = {
  notes: [],
  groups: [],
  collapsedGroups: new Set(),
  recorder: null,
  timerId: null,
  startedAt: 0,
  currentNoteId: null,
  detailAudioUrl: null,
  busy: false
};

function uid() {
  if (crypto.randomUUID) return crypto.randomUUID();
  return `note-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function createIcon(name) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  const use = document.createElementNS("http://www.w3.org/2000/svg", "use");
  use.setAttribute("href", `#i-${name}`);
  svg.append(use);
  return svg;
}

function getGroup(groupId) {
  return state.groups.find((group) => group.id === groupId) || DEFAULT_GROUPS.find((group) => group.id === groupId) || DEFAULT_GROUPS.at(-1);
}

function showView(name) {
  dom.homeView.hidden = name !== "home";
  dom.recordView.hidden = name !== "record";
  dom.searchView.hidden = name !== "search";
  if (name !== "home") dom.detailSheet.hidden = true;
}

function showToast(message, duration = 2400) {
  dom.toast.textContent = message;
  dom.toast.classList.add("show");
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => dom.toast.classList.remove("show"), duration);
}

function formatClock(totalSeconds) {
  const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, "0");
  const seconds = Math.floor(totalSeconds % 60).toString().padStart(2, "0");
  return `${minutes}:${seconds}`;
}

function formatDuration(durationMs = 0) {
  const seconds = Math.max(1, Math.round(durationMs / 1000));
  if (seconds < 60) return `${seconds} 秒`;
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return rest ? `${minutes}分${rest}秒` : `${minutes}分钟`;
}

function isSameDay(left, right) {
  return left.getFullYear() === right.getFullYear()
    && left.getMonth() === right.getMonth()
    && left.getDate() === right.getDate();
}

function formatRelativeTime(value) {
  const date = new Date(value);
  const now = new Date();
  if (isSameDay(date, now)) return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
  const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
  if (isSameDay(date, yesterday)) return "昨天";
  if (date.getFullYear() === now.getFullYear()) return `${date.getMonth() + 1}月${date.getDate()}日`;
  return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`;
}

function formatDetailTime(value, durationMs) {
  const date = new Date(value);
  return `${date.getMonth() + 1}月${date.getDate()}日 ${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")} · ${formatDuration(durationMs)}`;
}

function isStandaloneApp() {
  return window.navigator.standalone === true
    || window.matchMedia("(display-mode: standalone)").matches;
}

function shouldShowInstallTip() {
  const isIos = /iPhone|iPad|iPod/i.test(navigator.userAgent);
  const isSafari = /Safari/i.test(navigator.userAgent) && !/CriOS|FxiOS|EdgiOS/i.test(navigator.userAgent);
  const dismissed = localStorage.getItem("shengji-install-tip-dismissed") === "1";
  return isIos && isSafari && !isStandaloneApp() && !dismissed;
}

function audioExtension(type = "") {
  if (type.includes("mp4")) return "m4a";
  if (type.includes("aac")) return "aac";
  if (type.includes("webm")) return "webm";
  if (type.includes("wav")) return "wav";
  return "audio";
}

async function transcribeAudio(blob) {
  let uploadBlob = blob;
  let extension = audioExtension(blob.type);
  try {
    const converted = await convertToWav16k(blob);
    if (converted !== blob) {
      uploadBlob = converted;
      extension = "wav";
    }
  } catch {
    // The server can still try the original Safari recording format.
  }

  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 75000);
  try {
    const response = await fetch(`/api/transcribe?ext=${encodeURIComponent(extension)}`, {
      method: "POST",
      headers: { "Content-Type": uploadBlob.type || "application/octet-stream" },
      body: uploadBlob,
      signal: controller.signal
    });

    let payload = {};
    try { payload = await response.json(); } catch { /* ignored */ }
    if (!response.ok) throw new Error(payload.error || "本机语音识别失败");
    return String(payload.text || "").trim();
  } finally {
    window.clearTimeout(timeout);
  }
}

function setTodayLabel() {
  const now = new Date();
  const weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
  dom.todayLabel.textContent = `${now.getMonth() + 1}月${now.getDate()}日 ${weekdays[now.getDay()]}`;
}

function createNoteRow(note) {
  const row = document.createElement("button");
  row.type = "button";
  row.className = "note-row";

  const title = document.createElement("span");
  title.className = "note-row-title";
  title.textContent = note.title;

  const time = document.createElement("span");
  time.className = "note-row-time";
  time.textContent = formatRelativeTime(note.createdAt);

  row.append(title, time);
  row.addEventListener("click", () => openDetail(note.id));
  return row;
}

function renderHome() {
  const activeGroups = state.groups
    .map((group) => {
      const notes = state.notes.filter((note) => note.groupId === group.id);
      const latest = notes[0]?.createdAt || "";
      return { group, notes, latest };
    })
    .filter((item) => item.notes.length)
    .sort((left, right) => {
      if (left.group.id === "other") return 1;
      if (right.group.id === "other") return -1;
      if (left.latest !== right.latest) return String(right.latest).localeCompare(String(left.latest));
      return left.group.order - right.group.order;
    });

  dom.summaryText.textContent = state.notes.length
    ? `共 ${state.notes.length} 条 · 自动归纳为 ${activeGroups.length} 组`
    : "还没有记录";
  dom.emptyState.hidden = state.notes.length > 0;
  dom.groups.replaceChildren();

  activeGroups.forEach(({ group, notes }) => {
    const block = document.createElement("section");
    block.className = `group-block${state.collapsedGroups.has(group.id) ? " collapsed" : ""}`;

    const header = document.createElement("button");
    header.type = "button";
    header.className = "group-head";
    header.setAttribute("aria-expanded", String(!state.collapsedGroups.has(group.id)));

    const titleWrap = document.createElement("span");
    titleWrap.className = "group-title-wrap";
    const title = document.createElement("span");
    title.className = "group-title";
    title.textContent = group.name;
    const count = document.createElement("span");
    count.className = "group-count";
    count.textContent = `${notes.length} 条`;
    titleWrap.append(title, count);
    header.append(titleWrap, createIcon("chevron"));

    header.addEventListener("click", () => {
      if (state.collapsedGroups.has(group.id)) state.collapsedGroups.delete(group.id);
      else state.collapsedGroups.add(group.id);
      renderHome();
    });

    const items = document.createElement("div");
    items.className = "group-items";
    notes.forEach((note) => items.append(createNoteRow(note)));

    block.append(header, items);
    dom.groups.append(block);
  });
}

function startTimer() {
  stopTimer();
  state.startedAt = Date.now();
  const update = () => {
    const elapsed = Math.floor((Date.now() - state.startedAt) / 1000);
    dom.recordTimer.textContent = formatClock(elapsed);
  };
  update();
  state.timerId = window.setInterval(update, 250);
}

function stopTimer() {
  if (state.timerId) window.clearInterval(state.timerId);
  state.timerId = null;
}

async function startRecording() {
  if (state.busy) return;
  if (!supportsRecording()) {
    showToast("当前浏览器不支持录音，请使用最新版 Safari 或 Chrome。", 3200);
    return;
  }

  state.busy = true;
  dom.liveTranscript.textContent = "";
  dom.recordingStatus.textContent = "正在录音，停止后会自动保存和归纳。";
  dom.stopRecordButton.disabled = false;
  dom.recordTimer.textContent = "00:00";
  showView("record");

  const recorder = new VoiceRecorder({
    onInterim: (text) => {
      dom.liveTranscript.textContent = text;
    }
  });
  state.recorder = recorder;

  try {
    await recorder.start();
    startTimer();
  } catch (error) {
    state.recorder = null;
    state.busy = false;
    showView("home");
    showToast(error.message || "没有获得麦克风权限。", 3200);
  }
}

async function stopRecording() {
  if (!state.recorder || !state.busy) return;
  state.busy = false;
  dom.stopRecordButton.disabled = true;
  dom.recordingStatus.textContent = "正在保存，并整理到合适的组…";

  try {
    const result = await state.recorder.stop();
    stopTimer();
    state.recorder = null;

    if (!result.blob.size) throw new Error("没有录到声音，请再试一次。");

    dom.recordingStatus.textContent = "正在把录音转成文字…";
    let serverTranscript = "";
    let serverError = null;
    try {
      serverTranscript = await transcribeAudio(result.blob);
    } catch (error) {
      serverError = error;
    }

    const browserTranscript = String(result.transcript || "").trim();
    const finalTranscript = (serverTranscript || browserTranscript).trim();
    const hasTranscript = Boolean(finalTranscript);
    const text = finalTranscript || "音频已保存，当前环境未能自动转写。";
    const classification = hasTranscript
      ? classifyNote(text, state.notes, state.groups)
      : { groupId: "other", confidence: 0.2, reason: "等待转写" };

    const note = {
      id: uid(),
      createdAt: new Date().toISOString(),
      title: hasTranscript ? createTitle(text) : "新语音记录",
      transcript: text,
      groupId: classification.groupId,
      tags: [],
      durationMs: result.durationMs,
      status: hasTranscript ? "ready" : "needs_review",
      transcriptionEngine: serverTranscript ? "apple-server" : browserTranscript ? "browser" : "none",
      classificationConfidence: classification.confidence,
      classificationReason: classification.reason
    };

    await addNoteWithAudio(note, result.blob);
    state.notes = await getAllNotes();
    state.collapsedGroups.delete(note.groupId);
    renderHome();
    showView("home");
    const group = getGroup(note.groupId);
    if (hasTranscript) {
      showToast(`已保存，并归入“${group.name}”`);
    } else if (serverError) {
      showToast(`音频已保存，但自动转写失败：${serverError.message}`, 3600);
    } else {
      showToast("音频已保存，当前未能自动转写", 3600);
    }
  } catch (error) {
    stopTimer();
    showView("home");
    showToast(error.message || "保存失败，请再试一次。", 3200);
  } finally {
    dom.stopRecordButton.disabled = false;
  }
}

function cancelRecording() {
  state.recorder?.cancel();
  state.recorder = null;
  state.busy = false;
  stopTimer();
  showView("home");
}

function openSearch() {
  showView("search");
  window.setTimeout(() => dom.searchInput.focus(), 60);
}

function renderSearch() {
  dom.searchResults.replaceChildren();
  const result = searchNotes(dom.searchInput.value, state.notes, state.groups);
  const hasQuery = Boolean(dom.searchInput.value.trim());

  if (!hasQuery) {
    dom.searchAnswer.hidden = true;
    dom.searchEmpty.hidden = false;
    return;
  }

  dom.searchEmpty.hidden = true;
  dom.searchAnswer.hidden = false;
  dom.answerLabel.textContent = result.answer?.label || "搜索结果";
  dom.answerText.textContent = result.answer?.text || "没有找到相关记录。";

  const byGroup = new Map();
  result.matches.forEach((note) => {
    if (!byGroup.has(note.groupId)) byGroup.set(note.groupId, []);
    byGroup.get(note.groupId).push(note);
  });

  byGroup.forEach((notes, groupId) => {
    const group = getGroup(groupId);
    const section = document.createElement("section");
    section.className = "result-group";

    const head = document.createElement("header");
    head.className = "result-head";
    const name = document.createElement("strong");
    name.textContent = group.name;
    const count = document.createElement("span");
    count.textContent = `${notes.length} 条`;
    head.append(name, count);

    section.append(head);
    notes.forEach((note) => section.append(createNoteRow(note)));
    dom.searchResults.append(section);
  });
}

async function startVoiceSearch() {
  if (state.busy) return;

  state.busy = true;
  dom.voiceSearchButton.disabled = true;
  dom.askAgainButton.disabled = true;
  let transcript = "";

  try {
    if (supportsSpeechRecognition()) {
      dom.searchStatus.textContent = "正在听，请说出你要找的内容…";
      try {
        transcript = await recognizeOnce({
          onInterim: (text) => { dom.searchInput.value = text; }
        });
      } catch {
        transcript = "";
      }
    }

    if (!transcript && supportsRecording()) {
      dom.searchStatus.textContent = "正在听，6 秒后自动结束…";
      const audioBlob = await recordAudioOnce({ durationMs: 6000 });
      dom.searchStatus.textContent = "正在转写你的问题…";
      transcript = await transcribeAudio(audioBlob);
    }

    if (!transcript) throw new Error("没有听清，请再试一次。");
    dom.searchInput.value = transcript;
    dom.searchStatus.textContent = "搜索说的话不会保存成新记录";
    renderSearch();
  } catch (error) {
    dom.searchStatus.textContent = error.message || "没有听清，请再试一次";
  } finally {
    state.busy = false;
    dom.voiceSearchButton.disabled = false;
    dom.askAgainButton.disabled = false;
  }
}

async function openDetail(noteId) {
  const note = state.notes.find((item) => item.id === noteId);
  if (!note) return;

  state.currentNoteId = noteId;
  dom.detailGroup.textContent = getGroup(note.groupId).name;
  dom.detailTitle.textContent = note.title;
  dom.detailMeta.textContent = formatDetailTime(note.createdAt, note.durationMs);
  dom.detailTranscript.textContent = note.transcript;

  if (state.detailAudioUrl) URL.revokeObjectURL(state.detailAudioUrl);
  state.detailAudioUrl = null;
  dom.detailAudio.hidden = true;

  try {
    const audio = await getAudio(noteId);
    if (audio) {
      state.detailAudioUrl = URL.createObjectURL(audio);
      dom.detailAudio.src = state.detailAudioUrl;
      dom.detailAudio.hidden = false;
    }
  } catch {
    dom.detailAudio.hidden = true;
  }

  dom.detailSheet.hidden = false;
}

function openDictation() {
  dom.dictationText.value = "";
  dom.dictationSheet.hidden = false;
  window.setTimeout(() => dom.dictationText.focus(), 80);
}

function closeDictation() {
  dom.dictationSheet.hidden = true;
  dom.dictationText.blur();
}

async function saveDictation() {
  const text = dom.dictationText.value.trim();
  if (!text) {
    showToast("请先输入或听写内容");
    return;
  }

  dom.saveDictationButton.disabled = true;
  try {
    await saveShortcutNote(text);
    renderHome();
    renderSearch();
    closeDictation();
    showToast("已保存，并自动整理归类");
  } catch (error) {
    showToast(error.message || "保存失败，请重试");
  } finally {
    dom.saveDictationButton.disabled = false;
  }
}

function closeDetail() {
  dom.detailSheet.hidden = true;
  dom.detailAudio.pause();
  if (state.detailAudioUrl) URL.revokeObjectURL(state.detailAudioUrl);
  state.detailAudioUrl = null;
  state.currentNoteId = null;
}

async function removeCurrentNote() {
  const note = state.notes.find((item) => item.id === state.currentNoteId);
  if (!note) return;
  const confirmed = window.confirm(`删除“${note.title}”？`);
  if (!confirmed) return;

  await deleteNote(note.id);
  state.notes = await getAllNotes();
  closeDetail();
  renderHome();
  renderSearch();
  showToast("记录已删除");
}

async function saveShortcutNote(text) {
  const cleanText = String(text || "").trim();
  if (!cleanText) return;

  const classification = classifyNote(cleanText, state.notes, state.groups);
  const note = {
    id: uid(),
    createdAt: new Date().toISOString(),
    title: createTitle(cleanText),
    transcript: cleanText,
    groupId: classification.groupId,
    tags: [],
    durationMs: 0,
    status: "ready",
    transcriptionEngine: "apple-shortcut",
    classificationConfidence: classification.confidence,
    classificationReason: classification.reason
  };

  await addNote(note);
  state.notes = await getAllNotes();
  state.collapsedGroups.delete(note.groupId);
}

async function seedDemoData() {
  if (state.notes.length) return;
  const now = Date.now();
  const demos = [
    {
      id: "demo-shopping-1",
      createdAt: new Date(now - 12 * 60 * 1000).toISOString(),
      title: "买牛奶和鸡蛋",
      transcript: "明天早上买牛奶和鸡蛋，顺便看一下有没有水果。",
      groupId: "shopping",
      durationMs: 6200
    },
    {
      id: "demo-shopping-2",
      createdAt: new Date(now - 22 * 60 * 60 * 1000).toISOString(),
      title: "洗衣液和厨房纸",
      transcript: "洗衣液快用完了，还需要买厨房纸。",
      groupId: "shopping",
      durationMs: 7400
    },
    {
      id: "demo-home-1",
      createdAt: new Date(now - 4 * 60 * 60 * 1000).toISOString(),
      title: "周五记得去取快递",
      transcript: "周五下班以后记得去取快递。",
      groupId: "home",
      durationMs: 5100
    },
    {
      id: "demo-home-2",
      createdAt: new Date(now - 2 * 24 * 60 * 60 * 1000).toISOString(),
      title: "换门锁电池",
      transcript: "门锁提示电量低了，周末换电池。",
      groupId: "home",
      durationMs: 6800
    },
    {
      id: "demo-remember-1",
      createdAt: new Date(now - 7 * 60 * 60 * 1000).toISOString(),
      title: "想起给妈妈打个电话",
      transcript: "想起给妈妈打个电话，问问她周末在不在家。",
      groupId: "remember",
      durationMs: 5700
    },
    {
      id: "demo-idea-1",
      createdAt: new Date(now - 25 * 60 * 60 * 1000).toISOString(),
      title: "做一个语音便签",
      transcript: "如果做一个只负责录音和自动整理的小工具，应该会经常用。",
      groupId: "ideas",
      durationMs: 8300
    }
  ];

  for (const demo of demos) {
    await addNote({
      ...demo,
      tags: [],
      status: "ready",
      classificationConfidence: 0.9,
      classificationReason: "示例数据"
    });
  }
  state.notes = await getAllNotes();
}

async function initialize() {
  await seedDefaultGroups();
  state.groups = await getAllGroups();
  state.notes = await getAllNotes();

  const initialParams = new URLSearchParams(window.location.search);
  const shortcutText = initialParams.get("shortcutText");
  if (shortcutText) {
    await saveShortcutNote(shortcutText);
    const cleanedURL = new URL(window.location.href);
    cleanedURL.searchParams.delete("shortcutText");
    window.history.replaceState({}, "", `${cleanedURL.pathname}${cleanedURL.search}${cleanedURL.hash}`);
  } else if (initialParams.has("demo")) {
    await seedDemoData();
  }

  setTodayLabel();
  renderHome();
  dom.installTip.hidden = !shouldShowInstallTip();

  const params = new URLSearchParams(window.location.search);
  if (params.get("view") === "search") {
    openSearch();
    const query = params.get("q");
    if (query) {
      dom.searchInput.value = query;
      renderSearch();
    }
  }

  if (shortcutText) {
    showToast("快捷指令已保存，并自动整理归类", 3000);
  }

  if ("serviceWorker" in navigator && window.location.protocol !== "file:") {
    navigator.serviceWorker.register("./service-worker.js").catch(() => {});
  }
}

dom.startRecordButton.addEventListener("click", openDictation);
dom.openRecorderButton.addEventListener("click", startRecording);
dom.stopRecordButton.addEventListener("click", stopRecording);
dom.cancelRecordButton.addEventListener("click", cancelRecording);
dom.openSearchButton.addEventListener("click", openSearch);
dom.closeSearchButton.addEventListener("click", () => showView("home"));
dom.searchForm.addEventListener("submit", (event) => {
  event.preventDefault();
  renderSearch();
});
dom.voiceSearchButton.addEventListener("click", startVoiceSearch);
dom.askAgainButton.addEventListener("click", startVoiceSearch);
dom.closeDictationButton.addEventListener("click", closeDictation);
dom.saveDictationButton.addEventListener("click", saveDictation);
dom.closeDetailButton.addEventListener("click", closeDetail);
dom.deleteNoteButton.addEventListener("click", removeCurrentNote);
dom.dismissInstallTip.addEventListener("click", () => {
  localStorage.setItem("shengji-install-tip-dismissed", "1");
  dom.installTip.hidden = true;
});
dom.searchEmpty.querySelectorAll("[data-query]").forEach((button) => {
  button.addEventListener("click", () => {
    dom.searchInput.value = button.dataset.query || "";
    renderSearch();
  });
});

window.addEventListener("pagehide", () => {
  state.recorder?.cancel();
  stopTimer();
});

initialize().catch((error) => {
  showToast(error.message || "应用初始化失败", 4000);
});

window.ShengjiDebug = {
  classifyNote,
  createTitle,
  searchNotes,
  getState: () => ({ notes: state.notes, groups: state.groups }),
  renderHome,
  renderSearch
};
