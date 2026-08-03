const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/attrs`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`).sort();
const esperado = ['GET /api/v1/Orders', 'GET /api/v1/Orders/{}', 'POST /api/v1/Orders/bulk'].sort();
if (JSON.stringify(paths) !== JSON.stringify(esperado)) { console.error(`veio ${JSON.stringify(paths)}, esperava ${JSON.stringify(esperado)}`); process.exit(1); }
