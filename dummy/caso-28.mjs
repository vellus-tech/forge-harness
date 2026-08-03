const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const inicio = Date.now();
const { routes, unresolved } = scanRoutes([`${tmp}/ciclo`], { root: tmp });
const ms = Date.now() - inicio;
if (ms > 5000) { console.error(`composição levou ${ms}ms — o ciclo não está sendo cortado`); process.exit(1); }
const paths = routes.map((r) => `${r.method} ${r.path}`).sort();
if (!paths.includes('GET /v1/alpha') || !paths.includes('GET /v1/beta')) { console.error(`o corte do ciclo levou junto as rotas legítimas: ${JSON.stringify(paths)}`); process.exit(1); }
if (!unresolved.some((u) => u.kind === 'chain-cycle')) { console.error('ciclo cortado em silêncio — o corte precisa ser auditável'); process.exit(1); }
