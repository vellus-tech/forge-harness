const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/mount`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
if (paths.includes('POST /orders')) { console.error('rota de router emitida sem o prefixo do app.use — path inventado'); process.exit(1); }
if (!paths.includes('POST /api/v2/orders')) { console.error(`mount conhecido não compôs: ${JSON.stringify(paths)}`); process.exit(1); }
if (paths.includes('GET /{}')) { console.error('router sem mount emitiu path relativo como absoluto'); process.exit(1); }
if (!unresolved.some((u) => u.kind === 'router-mount-unknown')) { console.error('router sem mount não foi reportado'); process.exit(1); }
