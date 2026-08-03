const [lib] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const routes = [
  { method: 'GET', path: '/legacy/v1/a' }, { method: 'GET', path: '/legacy/v1/b' },
  { method: 'POST', path: '/legacy/v1/c' }, { method: 'GET', path: '/outro/v1/z' },
];
const grupos = as.surCodeToContract(routes, new Set(), { allowlist: [] });
if (grupos.length !== 2) { console.error(`esperava 2 grupos, veio ${grupos.length}`); process.exit(1); }
if (grupos[0].count !== 3) { console.error(`grupo maior deveria ter 3 rotas, tem ${grupos[0].count}`); process.exit(1); }
