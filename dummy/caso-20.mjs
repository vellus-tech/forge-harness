const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/duasclasses`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`).sort();
const esperado = ['GET /api/widgets/{}', 'POST /api/gadgets/bulk'].sort();
if (JSON.stringify(paths) !== JSON.stringify(esperado)) { console.error(`veio ${JSON.stringify(paths)}, esperava ${JSON.stringify(esperado)} — prefixo por classe, não por arquivo`); process.exit(1); }
