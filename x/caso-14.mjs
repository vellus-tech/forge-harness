const [lib] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const routes = [
  { method: 'GET', path: '/health/live' }, { method: 'GET', path: '/metrics' },
  { method: 'GET', path: '/swagger/index.html' }, { method: 'GET', path: '/v1/negocio' },
];
const grupos = as.surCodeToContract(routes, new Set(), { allowlist: as.INFRA_ALLOWLIST });
const total = grupos.reduce((acc, g) => acc + g.count, 0);
if (total !== 1) { console.error(`allowlist falhou: ${total} achados, esperava 1 (só o de negócio)`); process.exit(1); }
if (grupos[0].routes[0].path !== '/v1/negocio') { console.error('acusou o endpoint errado'); process.exit(1); }
