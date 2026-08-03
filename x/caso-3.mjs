const [lib] = process.argv.slice(2);
const { normalizePath } = await import(`${lib}/route-scan.mjs`);
const a = normalizePath('/blocks/{terminal}/{sequence:long}/export');
const b = normalizePath('/blocks/{tenantId}/{seq}/export');
if (a !== b) { console.error(`renomear parâmetro mudou o path: '${a}' vs '${b}'`); process.exit(1); }
