const [lib, fix, tmp] = process.argv.slice(2);
const rs = await import(`${lib}/route-scan.mjs`);
const as = await import(`${lib}/api-surface.mjs`);
const { routes } = rs.scanRoutes([`${tmp}/mut12`], { root: tmp });
const { endpoints } = as.collectDeclaredSurface({ contractPaths: [`${fix}/contracts`], root: fix });
const sur01 = as.surContractToCode(endpoints, rs.routeKeys(routes));
if (sur01.length !== 1) { console.error(`esperava 1 achado SUR-01, veio ${sur01.length}`); process.exit(1); }
if (sur01[0].path !== '/internal/v1/widgets/dispatch') { console.error(`achado no path errado: ${sur01[0].path}`); process.exit(1); }
