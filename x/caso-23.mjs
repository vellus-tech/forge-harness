const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/ktordyn`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
if (paths.includes('GET /status')) { console.error('rota sob prefixo irresolúvel emitida sem ele — path inventado'); process.exit(1); }
if (!paths.includes('POST /api/v1/orders')) { console.error('a supressão levou junto a rota do bloco resolvido'); process.exit(1); }
if (!unresolved.some((u) => u.kind === 'route-prefix-unresolved')) { console.error('a rota suprimida não foi reportada — suprimir em silêncio é o mesmo defeito'); process.exit(1); }
