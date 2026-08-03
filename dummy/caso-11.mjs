const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const { endpoints } = as.collectDeclaredSurface({ authzPaths: [`${tmp}/prec/authz`], specPaths: [`${tmp}/prec/specs`], root: tmp });
const a = endpoints.find((e) => e.path === '/v1/a');
if (!a) { console.error('/v1/a sumiu'); process.exit(1); }
if (a.policy !== 'policy.autoritativa') { console.error(`precedência de metadado falhou: policy = '${a.policy}'`); process.exit(1); }
if (!endpoints.some((e) => e.path === '/v1/c')) { console.error('endpoint que só a tabela declara sumiu por causa da precedência'); process.exit(1); }
