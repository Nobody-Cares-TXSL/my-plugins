// _match.js — 选项标号匹配逻辑（供 answer_choice.js 与回归测试共用）
// 雨课堂等平台的 input.value 与可见标号错位，必须按可见标号匹配
window.__aa = window.__aa || {};

// 选项文本是否带可见标号（"A"、"A 顺序组合"、"A. xxx" 等）
window.__aa.hasLetter = t => t.length === 1 || /^[A-Za-z][\s.、,，:：)）]/.test(t);

// 返回 true/false；返回 null 表示该选项没有可见标号，调用方应退回 input.value
window.__aa.matchByLetter = (visText, letter) => {
  const t = visText;
  if (!window.__aa.hasLetter(t)) return null;
  if (t === letter) return true;
  return new RegExp('^' + letter + '[\\s.、,，:：)）]').test(t);
};
