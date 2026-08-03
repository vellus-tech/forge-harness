const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/mut4`], { root: tmp });
if (!unresolved.some((u) => u.kind === 'producer-not-found')) { console.error('renome não produziu producer-not-found — silêncio é o defeito'); process.exit(1); }
if (routes.some((r) => r.path === '/events/stream')) { console.error('rota órfã emitida SEM o prefixo do grupo — path inventado'); process.exit(1); }
if (routes.some((r) => r.path === '/internal/v1/widgets/events/stream')) { console.error('rota do produtor perdido continua sendo reportada como existente'); process.exit(1); }
