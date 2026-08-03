const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const { endpoints, bySource } = as.collectDeclaredSurface({ contractPaths: [`${tmp}/union/contracts`], specPaths: [`${tmp}/union/specs`], root: tmp });
const keys = endpoints.map((e) => `${e.method} ${e.path}`).sort();
if (!keys.includes('POST /v1/b')) { console.error(`endpoint que só a tabela declara sumiu — isso é fallback, não união: ${JSON.stringify(keys)}`); process.exit(1); }
if (!keys.includes('GET /v1/a')) { console.error('endpoint do OpenAPI sumiu'); process.exit(1); }
const a = endpoints.find((e) => e.path === '/v1/a');
if (a.sources.length !== 2) { console.error(`'/v1/a' deveria ter 2 fontes, tem ${a.sources.length}: ${a.sources}`); process.exit(1); }
if (bySource.openapi === 0 || bySource.table === 0) { console.error('bySource não contou as duas fontes'); process.exit(1); }
