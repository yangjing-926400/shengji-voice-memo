import { DEFAULT_GROUPS } from "./classifier.js";

const DB_NAME = "shengji-local";
const DB_VERSION = 1;
const FALLBACK_KEY = "shengji-local-fallback-v1";
const OPEN_TIMEOUT_MS = 1800;

let dbPromise;
let storageMode = "unknown";
const memoryAudio = new Map();

function requestToPromise(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function transactionDone(transaction) {
  return new Promise((resolve, reject) => {
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
    transaction.onabort = () => reject(transaction.error || new Error("Transaction aborted"));
  });
}

function withTimeout(promise, timeoutMs) {
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      window.setTimeout(() => reject(new Error("Storage timeout")), timeoutMs);
    })
  ]);
}

function openIndexedDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains("groups")) db.createObjectStore("groups", { keyPath: "id" });
      if (!db.objectStoreNames.contains("notes")) {
        const notes = db.createObjectStore("notes", { keyPath: "id" });
        notes.createIndex("createdAt", "createdAt");
        notes.createIndex("groupId", "groupId");
      }
      if (!db.objectStoreNames.contains("audio")) db.createObjectStore("audio", { keyPath: "noteId" });
      if (!db.objectStoreNames.contains("settings")) db.createObjectStore("settings", { keyPath: "key" });
    };

    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error("IndexedDB blocked"));
  });
}

async function ensureStorageMode() {
  if (storageMode !== "unknown") return storageMode;
  if (!window.indexedDB) {
    storageMode = "fallback";
    return storageMode;
  }
  try {
    dbPromise = await withTimeout(openIndexedDatabase(), OPEN_TIMEOUT_MS);
    storageMode = "indexeddb";
  } catch {
    storageMode = "fallback";
    dbPromise = null;
  }
  return storageMode;
}

function readFallback() {
  try {
    const value = JSON.parse(localStorage.getItem(FALLBACK_KEY) || "{}");
    return {
      groups: Array.isArray(value.groups) ? value.groups : [],
      notes: Array.isArray(value.notes) ? value.notes : []
    };
  } catch {
    return { groups: [], notes: [] };
  }
}

function writeFallback(data) {
  try {
    localStorage.setItem(FALLBACK_KEY, JSON.stringify(data));
  } catch {
    // The in-memory path still works for the current session.
  }
}

async function blobToDataUrl(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
}

function dataUrlToBlob(dataUrl) {
  const [header, content] = String(dataUrl).split(",");
  const mime = header.match(/data:([^;]+)/)?.[1] || "audio/webm";
  const binary = atob(content);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return new Blob([bytes], { type: mime });
}

async function getAllFrom(storeName) {
  const mode = await ensureStorageMode();
  if (mode === "fallback") {
    const data = readFallback();
    return storeName === "groups" ? data.groups : data.notes;
  }
  const transaction = dbPromise.transaction(storeName, "readonly");
  return requestToPromise(transaction.objectStore(storeName).getAll());
}

export function openDatabase() {
  return ensureStorageMode();
}

export async function getAllGroups() {
  return getAllFrom("groups");
}

export async function getAllNotes() {
  const notes = await getAllFrom("notes");
  return notes.sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
}

export async function seedDefaultGroups() {
  const existing = await getAllGroups();
  const byId = new Map(existing.map((group) => [group.id, group]));
  const missing = DEFAULT_GROUPS.filter((group) => !byId.has(group.id));
  if (!missing.length) return existing;

  const mode = await ensureStorageMode();
  const additions = missing.map((group) => ({ ...group, createdAt: new Date().toISOString() }));

  if (mode === "fallback") {
    const data = readFallback();
    data.groups.push(...additions);
    writeFallback(data);
  } else {
    const transaction = dbPromise.transaction("groups", "readwrite");
    const store = transaction.objectStore("groups");
    additions.forEach((group) => store.put(group));
    await transactionDone(transaction);
  }

  return getAllGroups();
}

export async function addNoteWithAudio(note, audioBlob) {
  const mode = await ensureStorageMode();
  if (mode === "fallback") {
    const data = readFallback();
    data.notes = data.notes.filter((item) => item.id !== note.id);
    data.notes.push(note);
    writeFallback(data);
    memoryAudio.set(note.id, audioBlob);
    if (audioBlob?.size && audioBlob.size < 2_000_000) {
      try {
        localStorage.setItem(`shengji-audio-${note.id}`, await blobToDataUrl(audioBlob));
      } catch {
        // The in-memory copy is enough for the current session.
      }
    }
    return;
  }

  const transaction = dbPromise.transaction(["notes", "audio"], "readwrite");
  transaction.objectStore("notes").put(note);
  transaction.objectStore("audio").put({
    noteId: note.id,
    blob: audioBlob,
    mimeType: audioBlob.type || "audio/webm",
    createdAt: note.createdAt
  });
  await transactionDone(transaction);
}

export async function addNote(note) {
  const mode = await ensureStorageMode();
  if (mode === "fallback") {
    const data = readFallback();
    data.notes = data.notes.filter((item) => item.id !== note.id);
    data.notes.push(note);
    writeFallback(data);
    return;
  }

  const transaction = dbPromise.transaction("notes", "readwrite");
  transaction.objectStore("notes").put(note);
  await transactionDone(transaction);
}

export async function deleteNote(noteId) {
  const mode = await ensureStorageMode();
  memoryAudio.delete(noteId);
  if (mode === "fallback") {
    const data = readFallback();
    data.notes = data.notes.filter((note) => note.id !== noteId);
    writeFallback(data);
    localStorage.removeItem(`shengji-audio-${noteId}`);
    return;
  }

  const transaction = dbPromise.transaction(["notes", "audio"], "readwrite");
  transaction.objectStore("notes").delete(noteId);
  transaction.objectStore("audio").delete(noteId);
  await transactionDone(transaction);
}

export async function getAudio(noteId) {
  const mode = await ensureStorageMode();
  if (mode === "fallback") {
    if (memoryAudio.has(noteId)) return memoryAudio.get(noteId);
    const dataUrl = localStorage.getItem(`shengji-audio-${noteId}`);
    return dataUrl ? dataUrlToBlob(dataUrl) : null;
  }

  const transaction = dbPromise.transaction("audio", "readonly");
  const record = await requestToPromise(transaction.objectStore("audio").get(noteId));
  return record?.blob || null;
}
