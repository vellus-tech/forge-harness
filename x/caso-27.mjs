const [lib] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const routes = [{ method: 'GET', path: '/v1/health-insurance/claims' }, { method: 'GET', path: '/health/live' }];
const grupos = as.surCodeToContract(routes, new Set(), { allowlist: ['/health'] });
const total = grupos.reduce((acc, g) => acc + g.count, 0);
// Sem âncora, `/health` casa em qualquer posição e `/v1/health-insurance/claims` — superfície de
// negócio — é silenciada junto com a infra que o padrão realmente queria cobrir.
if (total !== 1) { console.error(`allowlist sem âncora silenciou superfície de negócio: ${total} achados, esperava 1`); process.exit(1); }
if (grupos[0].routes[0].path !== '/v1/health-insurance/claims') { console.error('silenciou o endpoint errado'); process.exit(1); }
