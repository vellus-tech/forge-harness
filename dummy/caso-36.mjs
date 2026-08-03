const [lib, fix] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
// Passar diretório E um arquivo dentro dele indexava o mesmo arquivo duas vezes; com a checagem
// de homônimos, todo produtor virava homônimo de SI MESMO e nenhuma invocação resolvia.
const { routes, unresolved } = scanRoutes([`${fix}/dotnet`, `${fix}/dotnet/WidgetEndpoints.cs`], { root: fix });
if (unresolved.some((u) => u.kind === 'producer-ambiguous')) { console.error(`arquivo indexado duas vezes virou ambiguidade: ${JSON.stringify(unresolved.map((u) => u.detail))}`); process.exit(1); }
if (routes.length !== 5) { console.error(`esperava as mesmas 5 rotas com paths sobrepostos, veio ${routes.length}`); process.exit(1); }
