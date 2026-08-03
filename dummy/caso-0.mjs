const [lib, fix] = process.argv.slice(2);
const rs = await import(`${lib}/route-scan.mjs`);
const as = await import(`${lib}/api-surface.mjs`);
const { routes, unresolved } = rs.scanRoutes([`${fix}/dotnet`], { root: fix });
if (routes.length !== 5) { console.error(`esperava 5 rotas, veio ${routes.length}`); process.exit(1); }
if (unresolved.length !== 0) { console.error(`esperava 0 unresolved, veio ${unresolved.length}`); process.exit(1); }
const { endpoints } = as.collectDeclaredSurface({ contractPaths: [`${fix}/contracts`], root: fix });
if (endpoints.length !== 4) { console.error(`esperava 4 declarados, veio ${endpoints.length}`); process.exit(1); }
if (as.surContractToCode(endpoints, rs.routeKeys(routes)).length !== 0) { console.error('SUR-01 deveria ser 0'); process.exit(1); }
const decl = as.collectDeclaredSurface({ contractPaths: [`${fix}/contracts`], root: fix });
if (decl.unresolved.length !== 0) { console.error(`fixture íntegro produziu ${decl.unresolved.length} irresolúvel no lado do contrato: ${JSON.stringify(decl.unresolved.map((u) => u.kind))}`); process.exit(1); }
const dk = new Set(endpoints.map((e) => `${e.method} ${e.path}`));
if (as.surCodeToContract(routes, dk, { allowlist: as.INFRA_ALLOWLIST }).length !== 0) { console.error('SUR-02 deveria ser 0'); process.exit(1); }
