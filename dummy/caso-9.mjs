const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/js`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
for (const esperado of ['GET /v1/things', 'POST /v1/things/{}/activate', 'GET /cats/{}', 'POST /cats']) {
  if (!paths.includes(esperado)) { console.error(`faltou '${esperado}' em ${JSON.stringify(paths)}`); process.exit(1); }
}
