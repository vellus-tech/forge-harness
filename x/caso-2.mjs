const [lib] = process.argv.slice(2);
const { normalizePath } = await import(`${lib}/route-scan.mjs`);
const casos = [
  ['/a/{id:long}', '/a/{}'],
  ['/a/{id}', '/a/{}'],
  ['/a/:id', '/a/{}'],
  ['/a/<id>', '/a/{}'],
  ['/a/', '/a'],
  ['/a//b', '/a/b'],
  ['a/b', '/a/b'],
  ['/a/{id:long}/b/{name}', '/a/{}/b/{}'],
  ['/', '/'],
];
for (const [entrada, esperado] of casos) {
  const got = normalizePath(entrada);
  if (got !== esperado) { console.error(`normalizePath('${entrada}') = '${got}', esperava '${esperado}'`); process.exit(1); }
}
