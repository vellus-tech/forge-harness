#!/usr/bin/env bash
# Gate W132 — contrato ↔ código, nas duas direções.
#
# As Ondas A e B tornaram executáveis os checks que o harness já especificava e fecharam as
# portas de saída por omissão. Faltava o oráculo: nenhum script sabia quais rotas o código de
# fato expõe, então "o contrato promete um endpoint" e "o endpoint existe" eram comparados por
# leitura humana — e a leitura humana falhou exatamente onde o path não cabe numa linha.
#
#   route-scan  duas passadas sobre o código; a rota nasce de três arquivos e dois saltos, e
#               nenhuma linha a contém inteira. Um scanner por linha passa em silêncio ali.
#   SUR-01      contrato→código: endpoint declarado que não existe como rota. BLOQUEIA.
#   SUR-02      código→contrato: rota que ninguém declarou. `warn` por default, agregado por
#               prefixo — bloqueando de saída, o gate morre no dia um contra qualquer legado.
#   unresolved  o que o scanner viu e não resolveu é REPORTADO. Prefixo irresolúvel que some
#               faz o SUR-02 passar por vacuidade, que é a falha que o harness proíbe.
#
#   [0]  CONTROLE: fixture íntegro — rotas resolvem, SUR-01 = 0, SUR-02 = 0
#   [1]  cadeia de DOIS SALTOS resolve com o prefixo do grupo (a razão de existir do módulo)
#   [2]  normalizePath: constraint de rota, parâmetro nomeado, barra final, barra dupla
#   [3]  normalizePath é invariante ao NOME do parâmetro (o nome é do autor, não do contrato)
#   [4]  produtor renomeado no chamador → `producer-not-found`, e a rota órfã NÃO é emitida
#        com path errado (path inventado é pior que ausente — o SUR-01 daria veredito confiante)
#   [5]  produtor que registra rotas e nunca é invocado → `producer-never-invoked`
#   [6]  dialeto .NET por atributos ([Route] + [HttpGet])
#   [7]  dialeto Spring (@RequestMapping + @GetMapping)
#   [8]  dialeto Ktor (route/get aninhados por chaves)
#   [9]  dialeto Express e Nest
#   [10] api-surface é UNIÃO: endpoint que só a tabela declara sobrevive à presença de OpenAPI
#   [11] precedência é só de METADADO: authz-map vence na policy, sem sumir com endpoint
#   [12] SUR-01 reprova nomeando o path que o contrato promete e o código não tem
#   [13] SUR-02 agrega por prefixo de grupo (um legado inteiro não vira N achados)
#   [14] SUR-02 não acusa infra da allowlist (health, métricas, swagger)
#   [15] PBT: normalizePath é idempotente sobre paths gerados
#   [16] path por literal interpolado é RECUSADO — o scanner não inventa rota de runtime
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
FIX="$WS/tests/fixtures/w132"
T="$(mktemp -d /tmp/forge-w132.XXXXXX)"
trap 'rm -rf "$T"' EXIT

[ -d "$FIX/dotnet" ] || { echo "FAIL: fixture $FIX/dotnet ausente (pré-requisito faltando reprova)"; exit 1; }
[ -d "$FIX/contracts" ] || { echo "FAIL: fixture $FIX/contracts ausente"; exit 1; }

run_node() {
  node - "$LIB" "$FIX" "$T" "$@" || return 1
}

echo "[0] CONTROLE: fixture íntegro resolve tudo e não acusa nada"
run_node <<'EOF' || { echo "FAIL [0]: fixture íntegro reprovou — nenhum vermelho adiante prova nada"; exit 1; }
const [lib, fix] = process.argv.slice(2);
const rs = await import(`${lib}/route-scan.mjs`);
const as = await import(`${lib}/api-surface.mjs`);
const { routes, unresolved } = rs.scanRoutes([`${fix}/dotnet`], { root: fix });
if (routes.length !== 5) { console.error(`esperava 5 rotas, veio ${routes.length}`); process.exit(1); }
if (unresolved.length !== 0) { console.error(`esperava 0 unresolved, veio ${unresolved.length}`); process.exit(1); }
const { endpoints } = as.collectDeclaredSurface({ contractPaths: [`${fix}/contracts`], root: fix });
if (endpoints.length !== 4) { console.error(`esperava 4 declarados, veio ${endpoints.length}`); process.exit(1); }
if (as.surContractToCode(endpoints, rs.routeKeys(routes)).length !== 0) { console.error('SUR-01 deveria ser 0'); process.exit(1); }
const dk = new Set(endpoints.map((e) => `${e.method} ${e.path}`));
if (as.surCodeToContract(routes, dk, { allowlist: as.INFRA_ALLOWLIST }).length !== 0) { console.error('SUR-02 deveria ser 0'); process.exit(1); }
EOF
echo "OK [0]"

echo "[1] cadeia de dois saltos resolve com o prefixo do grupo"
run_node <<'EOF' || { echo "FAIL [1]"; exit 1; }
const [lib, fix] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${fix}/dotnet`], { root: fix });
const r = routes.find((x) => x.path === '/internal/v1/widgets/events/stream');
if (!r) { console.error('rota de dois saltos não resolveu'); process.exit(1); }
if (r.chain.length !== 3) { console.error(`cadeia deveria ter 3 elos, veio ${r.chain.length}: ${r.chain}`); process.exit(1); }
if (!r.chain.join(' ').includes('MapWidgetStreamEndpoints')) { console.error('cadeia não nomeia o segundo salto'); process.exit(1); }
EOF
echo "OK [1]"

echo "[2] normalizePath: constraint, parâmetro, barra final, barra dupla"
run_node <<'EOF' || { echo "FAIL [2]"; exit 1; }
const [lib] = process.argv.slice(2);
const { normalizePath } = await import(`${lib}/route-scan.mjs`);
const casos = [
  ['/a/{id:long}', '/a/{}'],
  ['/a/{id}', '/a/{}'],
  ['/a/:id', '/a/{}'],
  ['/a/<id>', '/a/{}'],
  ['/a/', '/a'],
  ['/a//b', '/a/b'],
  ['a/b', '/a/b'],
  ['/a/{id:long}/b/{name}', '/a/{}/b/{}'],
  ['/', '/'],
];
for (const [entrada, esperado] of casos) {
  const got = normalizePath(entrada);
  if (got !== esperado) { console.error(`normalizePath('${entrada}') = '${got}', esperava '${esperado}'`); process.exit(1); }
}
EOF
echo "OK [2]"

echo "[3] normalizePath é invariante ao nome do parâmetro"
run_node <<'EOF' || { echo "FAIL [3]"; exit 1; }
const [lib] = process.argv.slice(2);
const { normalizePath } = await import(`${lib}/route-scan.mjs`);
const a = normalizePath('/blocks/{terminal}/{sequence:long}/export');
const b = normalizePath('/blocks/{tenantId}/{seq}/export');
if (a !== b) { console.error(`renomear parâmetro mudou o path: '${a}' vs '${b}'`); process.exit(1); }
EOF
echo "OK [3]"

echo "[4] produtor renomeado → unresolved, e a rota órfã não sai com path errado"
cp -R "$FIX/dotnet" "$T/mut4"
sed -i.bak 's/group.MapWidgetStreamEndpoints();/group.MapWidgetStreamEndpointsRenomeado();/' "$T/mut4/WidgetEndpoints.cs"
rm -f "$T/mut4"/*.bak
run_node <<'EOF' || { echo "FAIL [4]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/mut4`], { root: tmp });
if (!unresolved.some((u) => u.kind === 'producer-not-found')) { console.error('renome não produziu producer-not-found — silêncio é o defeito'); process.exit(1); }
if (routes.some((r) => r.path === '/events/stream')) { console.error('rota órfã emitida SEM o prefixo do grupo — path inventado'); process.exit(1); }
if (routes.some((r) => r.path === '/internal/v1/widgets/events/stream')) { console.error('rota do produtor perdido continua sendo reportada como existente'); process.exit(1); }
EOF
echo "OK [4]"

echo "[5] produtor nunca invocado é reportado"
run_node <<'EOF' || { echo "FAIL [5]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { unresolved } = scanRoutes([`${tmp}/mut4`], { root: tmp });
if (!unresolved.some((u) => u.kind === 'producer-never-invoked')) { console.error('produtor órfão não foi reportado'); process.exit(1); }
EOF
echo "OK [5]"

echo "[6] dialeto .NET por atributos"
mkdir -p "$T/attrs"
cat > "$T/attrs/OrdersController.cs" <<'CS'
[ApiController]
[Route("api/v1/[controller]")]
public class OrdersController : ControllerBase
{
    [HttpGet]
    public IActionResult List() => Ok();

    [HttpGet("{id:guid}")]
    public IActionResult Get(Guid id) => Ok();

    [HttpPost("bulk")]
    public IActionResult Bulk() => Ok();
}
CS
run_node <<'EOF' || { echo "FAIL [6]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/attrs`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`).sort();
const esperado = ['GET /api/v1/Orders', 'GET /api/v1/Orders/{}', 'POST /api/v1/Orders/bulk'].sort();
if (JSON.stringify(paths) !== JSON.stringify(esperado)) { console.error(`veio ${JSON.stringify(paths)}, esperava ${JSON.stringify(esperado)}`); process.exit(1); }
EOF
echo "OK [6]"

echo "[7] dialeto Spring"
mkdir -p "$T/spring"
cat > "$T/spring/UserController.java" <<'JAVA'
@RestController
@RequestMapping("/api/users")
public class UserController {
    @GetMapping("/{id}")
    public User get(@PathVariable Long id) { return null; }

    @PostMapping
    public User create(@RequestBody User u) { return null; }
}
JAVA
run_node <<'EOF' || { echo "FAIL [7]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/spring`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`).sort();
if (!paths.includes('GET /api/users/{}')) { console.error(`Spring GET não resolveu: ${JSON.stringify(paths)}`); process.exit(1); }
if (!paths.includes('POST /api/users')) { console.error(`Spring POST sem path não resolveu: ${JSON.stringify(paths)}`); process.exit(1); }
EOF
echo "OK [7]"

echo "[8] dialeto Ktor"
mkdir -p "$T/ktor"
cat > "$T/ktor/Routing.kt" <<'KT'
fun Application.configureRouting() {
    routing {
        route("/api/v2") {
            get("/ping") { call.respond("pong") }
            route("/admin") {
                post("/reset") { call.respond(HttpStatusCode.NoContent) }
            }
        }
    }
}
KT
run_node <<'EOF' || { echo "FAIL [8]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/ktor`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
if (!paths.includes('GET /api/v2/ping')) { console.error(`Ktor aninhado 1 nível falhou: ${JSON.stringify(paths)}`); process.exit(1); }
if (!paths.includes('POST /api/v2/admin/reset')) { console.error(`Ktor aninhado 2 níveis falhou: ${JSON.stringify(paths)}`); process.exit(1); }
EOF
echo "OK [8]"

echo "[9] dialeto Express e Nest"
mkdir -p "$T/js"
cat > "$T/js/server.js" <<'JS'
const app = express();
app.get('/v1/things', listThings);
app.post('/v1/things/:id/activate', activate);
JS
cat > "$T/js/cats.controller.ts" <<'TS'
@Controller('cats')
export class CatsController {
  @Get(':id')
  findOne() {}

  @Post()
  create() {}
}
TS
run_node <<'EOF' || { echo "FAIL [9]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/js`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
for (const esperado of ['GET /v1/things', 'POST /v1/things/{}/activate', 'GET /cats/{}', 'POST /cats']) {
  if (!paths.includes(esperado)) { console.error(`faltou '${esperado}' em ${JSON.stringify(paths)}`); process.exit(1); }
}
EOF
echo "OK [9]"

echo "[10] api-surface é união — endpoint só da tabela sobrevive ao OpenAPI"
mkdir -p "$T/union/contracts" "$T/union/specs"
cat > "$T/union/contracts/api.yaml" <<'YML'
openapi: 3.0.3
paths:
  /v1/a:
    get:
      summary: a
YML
cat > "$T/union/specs/requirements.md" <<'MD'
| Endpoint | Ação | Recurso | Policy |
|---|---|---|---|
| `GET /v1/a` | ler | a | policy.a |
| `POST /v1/b` | criar | b | policy.b |
MD
run_node <<'EOF' || { echo "FAIL [10]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const { endpoints, bySource } = as.collectDeclaredSurface({ contractPaths: [`${tmp}/union/contracts`], specPaths: [`${tmp}/union/specs`], root: tmp });
const keys = endpoints.map((e) => `${e.method} ${e.path}`).sort();
if (!keys.includes('POST /v1/b')) { console.error(`endpoint que só a tabela declara sumiu — isso é fallback, não união: ${JSON.stringify(keys)}`); process.exit(1); }
if (!keys.includes('GET /v1/a')) { console.error('endpoint do OpenAPI sumiu'); process.exit(1); }
const a = endpoints.find((e) => e.path === '/v1/a');
if (a.sources.length !== 2) { console.error(`'/v1/a' deveria ter 2 fontes, tem ${a.sources.length}: ${a.sources}`); process.exit(1); }
if (bySource.openapi === 0 || bySource.table === 0) { console.error('bySource não contou as duas fontes'); process.exit(1); }
EOF
echo "OK [10]"

echo "[11] precedência é só de metadado — authz-map vence na policy sem sumir com endpoint"
mkdir -p "$T/prec/authz" "$T/prec/specs"
cat > "$T/prec/authz/map.yaml" <<'YML'
routes:
  - endpoint: "GET /v1/a"
    policy: policy.autoritativa
YML
cat > "$T/prec/specs/requirements.md" <<'MD'
| Endpoint | Ação | Recurso | Policy |
|---|---|---|---|
| `GET /v1/a` | ler | a | policy.desatualizada |
| `POST /v1/c` | criar | c | policy.c |
MD
run_node <<'EOF' || { echo "FAIL [11]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const { endpoints } = as.collectDeclaredSurface({ authzPaths: [`${tmp}/prec/authz`], specPaths: [`${tmp}/prec/specs`], root: tmp });
const a = endpoints.find((e) => e.path === '/v1/a');
if (!a) { console.error('/v1/a sumiu'); process.exit(1); }
if (a.policy !== 'policy.autoritativa') { console.error(`precedência de metadado falhou: policy = '${a.policy}'`); process.exit(1); }
if (!endpoints.some((e) => e.path === '/v1/c')) { console.error('endpoint que só a tabela declara sumiu por causa da precedência'); process.exit(1); }
EOF
echo "OK [11]"

echo "[12] SUR-01 reprova nomeando o path prometido e não implementado"
cp -R "$FIX/dotnet" "$T/mut12"
sed -i.bak 's|group.MapPost("/dispatch", Dispatch)|group.MapPost("/dispatch-renomeado", Dispatch)|' "$T/mut12/WidgetEndpoints.cs"
rm -f "$T/mut12"/*.bak
run_node <<'EOF' || { echo "FAIL [12]"; exit 1; }
const [lib, fix, tmp] = process.argv.slice(2);
const rs = await import(`${lib}/route-scan.mjs`);
const as = await import(`${lib}/api-surface.mjs`);
const { routes } = rs.scanRoutes([`${tmp}/mut12`], { root: tmp });
const { endpoints } = as.collectDeclaredSurface({ contractPaths: [`${fix}/contracts`], root: fix });
const sur01 = as.surContractToCode(endpoints, rs.routeKeys(routes));
if (sur01.length !== 1) { console.error(`esperava 1 achado SUR-01, veio ${sur01.length}`); process.exit(1); }
if (sur01[0].path !== '/internal/v1/widgets/dispatch') { console.error(`achado no path errado: ${sur01[0].path}`); process.exit(1); }
EOF
echo "OK [12]"

echo "[13] SUR-02 agrega por prefixo — legado inteiro não vira N achados"
run_node <<'EOF' || { echo "FAIL [13]"; exit 1; }
const [lib] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const routes = [
  { method: 'GET', path: '/legacy/v1/a' }, { method: 'GET', path: '/legacy/v1/b' },
  { method: 'POST', path: '/legacy/v1/c' }, { method: 'GET', path: '/outro/v1/z' },
];
const grupos = as.surCodeToContract(routes, new Set(), { allowlist: [] });
if (grupos.length !== 2) { console.error(`esperava 2 grupos, veio ${grupos.length}`); process.exit(1); }
if (grupos[0].count !== 3) { console.error(`grupo maior deveria ter 3 rotas, tem ${grupos[0].count}`); process.exit(1); }
EOF
echo "OK [13]"

echo "[14] SUR-02 não acusa infra da allowlist"
run_node <<'EOF' || { echo "FAIL [14]"; exit 1; }
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
EOF
echo "OK [14]"

echo "[15] PBT: normalizePath é idempotente"
run_node <<'EOF' || { echo "FAIL [15]"; exit 1; }
const [lib] = process.argv.slice(2);
const { normalizePath } = await import(`${lib}/route-scan.mjs`);
const { forAll, gen } = await import(`${lib}/pbt.mjs`);

// Gera path a partir de segmentos que exercitam as três normalizações, mais o caso vazio (que
// produz barra dupla) e a barra final. Sem esses dois, a propriedade passaria por degeneração.
const SEG = ['a', 'b', 'items', '{id}', '{id:long}', ':name', '<x>', 'v1', '', '*'];
const pathGen = gen.array(gen.oneOf(SEG), 1, 5);

const r = forAll([pathGen, gen.bool()], (segs, barraFinal) => {
  const p = `/${segs.join('/')}${barraFinal ? '/' : ''}`;
  const uma = normalizePath(p);
  return normalizePath(uma) === uma;
}, { runs: 300 });
if (!r.ok) { console.error(`normalizePath não é idempotente: ${JSON.stringify(r.counterexample)}`); process.exit(1); }

// Controle da própria propriedade: o gerador precisa de fato produzir path que MUDA na primeira
// normalização, senão idempotência é trivialmente verdadeira e a asserção não vale nada.
let mudou = 0;
const rnd = (await import(`${lib}/pbt.mjs`)).makeRandom(7);
for (let i = 0; i < 200; i += 1) {
  const segs = pathGen.generate(rnd, i / 199);
  const p = `/${segs.join('/')}`;
  if (normalizePath(p) !== p) mudou += 1;
}
if (mudou < 20) { console.error(`gerador degenerado: só ${mudou}/200 paths mudam na normalização`); process.exit(1); }
EOF
echo "OK [15]"

echo "[16] literal interpolado é recusado — o scanner não inventa rota de runtime"
mkdir -p "$T/interp"
cat > "$T/interp/Dyn.cs" <<'CS'
public static class Dyn
{
    public static WebApplication MapDyn(this WebApplication app)
    {
        var g = app.MapGroup($"/tenant/{tenantId}/v1");
        g.MapGet("/ok", Handler);
        return app;
    }
}
CS
# Verbatim interpolada do C#. O regex de literal aceita o prefixo `@`, e uma prova de mutação
# mostrou que `$@"..."` escapava por essa porta — texto entre aspas virando rota que não existe.
cat > "$T/interp/DynVerbatim.cs" <<'CS'
public static class DynVerbatim
{
    public static WebApplication MapDynVerbatim(this WebApplication app)
    {
        var g = app.MapGroup($@"/conta/{contaId}/v2");
        g.MapGet("/tambem-ok", Handler);
        return app;
    }
}
CS
run_node <<'EOF' || { echo "FAIL [16]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/interp`], { root: tmp });
if (routes.some((r) => r.path.includes('tenantId'))) { console.error('o scanner inventou rota a partir de literal interpolado'); process.exit(1); }
if (routes.some((r) => r.path.includes('contaId'))) { console.error('o scanner inventou rota a partir de literal VERBATIM interpolado ($@\"...\")'); process.exit(1); }
const dinamicos = unresolved.filter((u) => u.kind === 'group-path-not-literal');
if (dinamicos.length !== 2) { console.error(`esperava 2 prefixos dinâmicos reportados, veio ${dinamicos.length} — silêncio é o defeito`); process.exit(1); }
EOF
echo "OK [16]"

echo "OK"
