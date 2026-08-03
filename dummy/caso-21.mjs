const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/fluente`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
if (!paths.includes('GET /internal/v1/keys/rotate')) { console.error(`registro fluente invisível: ${JSON.stringify(paths)}`); process.exit(1); }
if (paths.includes('POST /api/ping')) { console.error('MapGroup encadeado perdeu o segundo segmento — path inventado'); process.exit(1); }
if (!paths.includes('POST /api/v3/ping')) { console.error(`MapGroup encadeado não compôs: ${JSON.stringify(paths)}`); process.exit(1); }
