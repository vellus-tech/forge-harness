const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/ktor`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
if (!paths.includes('GET /api/v2/ping')) { console.error(`Ktor aninhado 1 nível falhou: ${JSON.stringify(paths)}`); process.exit(1); }
if (!paths.includes('POST /api/v2/admin/reset')) { console.error(`Ktor aninhado 2 níveis falhou: ${JSON.stringify(paths)}`); process.exit(1); }
