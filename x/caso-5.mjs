const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { unresolved } = scanRoutes([`${tmp}/mut4`], { root: tmp });
if (!unresolved.some((u) => u.kind === 'producer-never-invoked')) { console.error('produtor órfão não foi reportado'); process.exit(1); }
