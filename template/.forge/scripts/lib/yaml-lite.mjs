// Tiny YAML subset parser shared by the zero-dep forge scripts (validate-spec,
// validate-archive, delta-apply). Accepts the format the forge scripts emit:
// 2-space indentation, `key: value` scalars, nested maps, `key: []` inline empty
// lists, `- scalar` items and `- key: value` object-list items with continuation
// lines. No inline maps, no multiline strings, no anchors.
export function parseScalar(raw) {
  const s = raw.trim();
  if (s === '' || s === 'null' || s === '~') return null;
  if (s === '[]') return [];
  if (s === '{}') return {};
  if (s === 'true') return true;
  if (s === 'false') return false;
  if (/^-?[0-9]+$/.test(s)) return parseInt(s, 10);
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) return s.slice(1, -1);
  return s;
}

export function parseYamlSubset(text) {
  const lines = text.split('\n').map((l) => l.replace(/\t/g, '  '))
    .filter((l) => l.trim() && !l.trim().startsWith('#'));
  const doc = {};
  const frames = [{ indent: -1, obj: doc }];
  let lastKey = null, lastKeyOwner = null, lastKeyIndent = -1;
  let listCtx = null; // { dashIndent, arr }

  for (const rawLine of lines) {
    const indent = rawLine.length - rawLine.trimStart().length;
    const line = rawLine.trim();

    if (line === '-' || line.startsWith('- ')) {
      if (!listCtx || indent !== listCtx.dashIndent) {
        if (lastKey === null || indent <= lastKeyIndent) throw new Error(`stray list item: "${line}"`);
        if (!Array.isArray(lastKeyOwner[lastKey])) lastKeyOwner[lastKey] = [];
        listCtx = { dashIndent: indent, arr: lastKeyOwner[lastKey] };
      }
      const rest = line === '-' ? '' : line.slice(2);
      const m = rest.match(/^([A-Za-z0-9_]+):(.*)$/);
      if (m) {
        const item = {};
        item[m[1]] = parseScalar(m[2]);
        listCtx.arr.push(item);
        while (frames.length > 1 && indent <= frames[frames.length - 1].indent) frames.pop();
        frames.push({ indent, obj: item });
        lastKey = m[1]; lastKeyOwner = item; lastKeyIndent = indent;
      } else {
        listCtx.arr.push(parseScalar(rest));
      }
      continue;
    }

    if (listCtx && indent <= listCtx.dashIndent) listCtx = null;
    while (frames.length > 1 && indent <= frames[frames.length - 1].indent) frames.pop();
    const container = frames[frames.length - 1].obj;

    const m = line.match(/^([A-Za-z0-9_]+):(.*)$/);
    if (!m) throw new Error(`unparseable line: "${line}"`);
    const [, key, rest] = m;

    if (rest.trim() === '') {
      container[key] = {}; // provisional: becomes [] if "- " items follow
      frames.push({ indent, obj: container[key] });
    } else {
      container[key] = parseScalar(rest);
    }
    lastKey = key; lastKeyOwner = container; lastKeyIndent = indent;
  }
  return doc;
}
