const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/spring`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`).sort();
if (!paths.includes('GET /api/users/{}')) { console.error(`Spring GET não resolveu: ${JSON.stringify(paths)}`); process.exit(1); }
if (!paths.includes('POST /api/users')) { console.error(`Spring POST sem path não resolveu: ${JSON.stringify(paths)}`); process.exit(1); }
