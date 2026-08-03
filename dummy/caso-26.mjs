const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const { endpoints, unresolved } = as.collectDeclaredSurface({ authzPaths: [`${tmp}/falha/authz`], root: tmp });
const keys = endpoints.map((e) => `${e.method} ${e.path}`);
// Assumir GET faz o SUR-01 bloquear num endpoint que ninguém prometeu, enquanto a rota real
// (POST) ainda aparece no SUR-02 como não declarada. Inventar o verbo é inventar endpoint.
if (keys.includes('GET /v1/vault/reveal')) { console.error('entrada sem método virou GET — verbo inventado'); process.exit(1); }
if (!unresolved.some((u) => u.kind === 'authz-entry-without-method')) { console.error('entrada sem método não foi reportada'); process.exit(1); }
