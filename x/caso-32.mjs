const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/idiomas`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
// `get { }` sem path é a forma idiomática do endpoint de coleção no Ktor; some-la faz o SUR-01,
// que bloqueia, reprovar um contrato correto.
if (!paths.includes('GET /v1')) { console.error(`Ktor get sem path sumiu: ${JSON.stringify(paths)}`); process.exit(1); }
if (!paths.includes('GET /v1/ping')) { console.error('Ktor get com path regrediu'); process.exit(1); }
// O mount de `v1` já está no índice; descartar por heurística de NOME joga fora informação que a
// própria passada coletou.
if (!paths.includes('GET /api/users')) { console.error(`router com nome fora da heurística perdeu o mount conhecido: ${JSON.stringify(paths)}`); process.exit(1); }
