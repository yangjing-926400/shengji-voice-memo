import { groupMatchesText, normalizeText, similarity } from "./classifier.js";

const STOP_WORDS = [
  "最近", "上周", "这周", "本周", "今天", "昨天", "关于", "相关", "记录", "哪些", "什么",
  "说了", "说过", "有没有", "我", "的", "了", "吗", "呀", "请", "找一下", "帮我", "查一下"
];

function removeStopWords(value) {
  let output = normalizeText(value);
  STOP_WORDS.forEach((word) => {
    output = output.split(normalizeText(word)).join("");
  });
  return output;
}

function getDateRange(query) {
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  if (query.includes("今天")) {
    return { from: startOfToday.getTime(), to: startOfToday.getTime() + 86400000 };
  }
  if (query.includes("昨天")) {
    return { from: startOfToday.getTime() - 86400000, to: startOfToday.getTime() };
  }
  if (query.includes("上周")) {
    const day = now.getDay() || 7;
    const startThisWeek = new Date(startOfToday.getTime() - (day - 1) * 86400000);
    return { from: startThisWeek.getTime() - 7 * 86400000, to: startThisWeek.getTime() };
  }
  if (query.includes("这周") || query.includes("本周")) {
    const day = now.getDay() || 7;
    const startThisWeek = new Date(startOfToday.getTime() - (day - 1) * 86400000);
    return { from: startThisWeek.getTime(), to: startThisWeek.getTime() + 7 * 86400000 };
  }
  return null;
}

function getRequestedGroup(query, groups) {
  const normalized = normalizeText(query);
  return groups
    .filter((group) => group.id !== "other")
    .map((group) => ({ group, score: groupMatchesText(group, normalized) }))
    .sort((a, b) => b.score - a.score)[0];
}

function scoreNote(note, query, requestedGroup, dateRange) {
  const noteTime = new Date(note.createdAt).getTime();
  if (dateRange && (noteTime < dateRange.from || noteTime >= dateRange.to)) return -1;

  let score = 0;
  if (requestedGroup?.score > 0 && note.groupId === requestedGroup.group.id) score += 8;

  const queryText = removeStopWords(query);
  const noteText = normalizeText(`${note.title} ${note.transcript}`);
  if (queryText.length >= 2 && noteText.includes(queryText)) score += 7;
  if (queryText.length >= 2) score += similarity(queryText, noteText) * 5;

  if (dateRange) score += 1.5;
  return score;
}

function createAnswer(query, matches, groups) {
  if (!matches.length) {
    return { label: "没有找到", text: "没有找到相关记录。可以换一种问法，或者先记录一条。" };
  }

  const requestedGroup = getRequestedGroup(query, groups);
  const titles = matches.slice(0, 4).map((note) => note.title);
  const titleText = titles.join("、");

  if (requestedGroup?.score > 0 && requestedGroup.group.id === matches[0].groupId) {
    return {
      label: `找到 ${matches.length} 条相关记录`,
      text: `${requestedGroup.group.name}里有 ${matches.length} 条：${titleText}。`
    };
  }

  if (query.includes("今天")) {
    return { label: `今天有 ${matches.length} 条`, text: `今天记录了：${titleText}。` };
  }

  if (query.includes("昨天")) {
    return { label: `昨天有 ${matches.length} 条`, text: `昨天记录了：${titleText}。` };
  }

  if (query.includes("上周")) {
    return { label: `上周有 ${matches.length} 条`, text: `上周共找到 ${matches.length} 条相关记录：${titleText}。` };
  }

  return { label: `找到 ${matches.length} 条相关记录`, text: `和你问的内容比较接近的是：${titleText}。` };
}

export function searchNotes(query, notes, groups) {
  const cleanQuery = String(query || "").trim();
  if (!cleanQuery) return { answer: null, matches: [] };

  const dateRange = getDateRange(cleanQuery);
  const requestedGroup = getRequestedGroup(cleanQuery, groups);
  const hasStrongGroupRequest = requestedGroup?.score > 0;
  const hasTextRequest = removeStopWords(cleanQuery).length >= 2;

  const scored = notes
    .map((note) => ({ note, score: scoreNote(note, cleanQuery, requestedGroup, dateRange) }))
    .filter((item) => item.score > 0);

  let matches = scored
    .sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      return String(b.note.createdAt).localeCompare(String(a.note.createdAt));
    })
    .map((item) => item.note);

  if (!matches.length && hasStrongGroupRequest) {
    matches = notes
      .filter((note) => note.groupId === requestedGroup.group.id)
      .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
  }

  if (!matches.length && !dateRange && !hasStrongGroupRequest && !hasTextRequest) {
    matches = notes.slice(0, 8);
  }

  return {
    answer: createAnswer(cleanQuery, matches, groups),
    matches
  };
}
