const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/interp`], { root: tmp });
if (routes.some((r) => r.path.includes('tenantId'))) { console.error('o scanner inventou rota a partir de literal interpolado'); process.exit(1); }
if (routes.some((r) => r.path.includes('contaId'))) { console.error('o scanner inventou rota a partir de literal VERBATIM interpolado ($@\"...\")'); process.exit(1); }
const dinamicos = unresolved.filter((u) => u.kind === 'group-path-not-literal');
if (dinamicos.length !== 2) { console.error(`esperava 2 prefixos dinâmicos reportados, veio ${dinamicos.length} — silêncio é o defeito`); process.exit(1); }
