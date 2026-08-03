const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const { endpoints } = as.collectDeclaredSurface({ contractPaths: [`${tmp}/servers`], root: tmp });
const keys = endpoints.map((e) => `${e.method} ${e.path}`);
if (keys.includes('GET /widgets')) { console.error('basePath de servers[] ignorado — SUR-01 acusaria toda a superfície de um contrato correto'); process.exit(1); }
if (!keys.includes('GET /api/v1/widgets')) { console.error(`basePath não compôs: ${JSON.stringify(keys)}`); process.exit(1); }
