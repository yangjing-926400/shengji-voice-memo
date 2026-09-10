export const DEFAULT_GROUPS = [
  {
    id: "shopping",
    name: "日常采购",
    order: 1,
    keywords: ["买", "采购", "超市", "购物", "牛奶", "鸡蛋", "牙膏", "洗衣液", "厨房纸", "菜", "水果", "药"]
  },
  {
    id: "home",
    name: "家里的事",
    order: 2,
    keywords: ["快递", "门锁", "修", "打扫", "洗", "充电", "水电", "家具", "物业", "搬", "收拾", "换"]
  },
  {
    id: "remember",
    name: "要记得",
    order: 3,
    keywords: ["记得", "提醒", "预约", "电话", "妈妈", "爸爸", "家人", "医生", "缴费", "交费", "别忘了", "要"]
  },
  {
    id: "ideas",
    name: "想法",
    order: 4,
    keywords: ["想法", "想到", "计划", "觉得", "点子", "以后", "可以", "如果", "灵感"]
  },
  {
    id: "other",
    name: "其他",
    order: 99,
    keywords: []
  }
];

const NORMALIZE_PATTERN = /[\s，。！？、；：“”‘’（）()【】《》,.!?;:'"\-_/\\]/g;

export function normalizeText(value = "") {
  return String(value).toLowerCase().replace(NORMALIZE_PATTERN, "");
}

function bigrams(value) {
  const text = normalizeText(value);
  const result = new Set();
  if (text.length < 2) {
    if (text) result.add(text);
    return result;
  }
  for (let index = 0; index < text.length - 1; index += 1) {
    result.add(text.slice(index, index + 2));
  }
  return result;
}

export function similarity(left, right) {
  const a = bigrams(left);
  const b = bigrams(right);
  if (!a.size || !b.size) return 0;
  let intersection = 0;
  a.forEach((item) => {
    if (b.has(item)) intersection += 1;
  });
  return (2 * intersection) / (a.size + b.size);
}

function keywordScore(text, keywords) {
  return keywords.reduce((score, keyword) => {
    if (!text.includes(keyword)) return score;
    return score + Math.max(1, Math.min(3, keyword.length));
  }, 0);
}

export function createTitle(text = "") {
  const cleaned = String(text)
    .trim()
    .replace(/^(嗯|那个|就是|我想说|我说一下|记一下|帮我记一下)[，,\s]*/g, "");
  if (!cleaned) return "新语音记录";
  const firstSentence = cleaned.split(/[。！？!?；;\n]/)[0].trim() || cleaned;
  if (firstSentence.length <= 20) return firstSentence;
  return `${firstSentence.slice(0, 19)}…`;
}

export function classifyNote(text, notes = [], groups = DEFAULT_GROUPS) {
  const normalized = normalizeText(text);
  if (!normalized || normalized.length < 2) {
    return { groupId: "other", confidence: 0.2, reason: "内容过短" };
  }

  const scored = groups
    .filter((group) => group.id !== "other")
    .map((group) => ({
      group,
      score: keywordScore(normalized, group.keywords || [])
    }))
    .sort((a, b) => b.score - a.score);

  const top = scored[0];
  const second = scored[1];
  const bestSimilarNote = notes.reduce((best, note) => {
    const score = similarity(normalized, note.transcript || note.title || "");
    if (!best || score > best.score) return { note, score };
    return best;
  }, null);

  if (bestSimilarNote && bestSimilarNote.score >= 0.34 && bestSimilarNote.note.groupId !== "other") {
    return {
      groupId: bestSimilarNote.note.groupId,
      confidence: Math.min(0.95, 0.55 + bestSimilarNote.score),
      reason: "和已有记录相似"
    };
  }

  if (top && top.score >= 2 && (!second || top.score - second.score >= 0.5)) {
    return {
      groupId: top.group.id,
      confidence: Math.min(0.96, 0.58 + top.score * 0.06),
      reason: "关键词匹配"
    };
  }

  if (bestSimilarNote && bestSimilarNote.score >= 0.24 && bestSimilarNote.note.groupId) {
    return {
      groupId: bestSimilarNote.note.groupId,
      confidence: Math.min(0.88, 0.48 + bestSimilarNote.score),
      reason: "可能和已有记录相似"
    };
  }

  return { groupId: "other", confidence: 0.35, reason: "暂未确定类型" };
}

export function groupMatchesText(group, text) {
  const normalized = normalizeText(text);
  if (!normalized) return 0;
  return keywordScore(normalized, group.keywords || []);
}
