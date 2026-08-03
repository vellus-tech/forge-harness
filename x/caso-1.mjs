const [lib, fix] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${fix}/dotnet`], { root: fix });
const r = routes.find((x) => x.path === '/internal/v1/widgets/events/stream');
if (!r) { console.error('rota de dois saltos não resolveu'); process.exit(1); }
if (r.chain.length !== 3) { console.error(`cadeia deveria ter 3 elos, veio ${r.chain.length}: ${r.chain}`); process.exit(1); }
if (!r.chain.join(' ').includes('MapWidgetStreamEndpoints')) { console.error('cadeia não nomeia o segundo salto'); process.exit(1); }
