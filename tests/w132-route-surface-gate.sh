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
#
# ── Os casos [17]+ nasceram de defeitos reais desta implementação ──────────────────────────
# Todos foram reproduzidos contra uma versão do módulo que emitia path inventado com `unresolved`
# vazio — a condição exata que o gate existe para tornar impossível. [29] prova por mutação um
# subconjunto deles; os demais valem pela asserção, que é sobre dado estruturado.
#
#   [17] produtores HOMÔNIMOS em arquivos distintos → `producer-ambiguous`, nenhuma rota cruzada
#   [18] subgrupo aberto DENTRO de um produtor relativo herda o prefixo do chamador
#   [19] interpolação DENTRO da aspa (JS `${x}`, Kotlin `$x`) é recusada como a do C#
#   [20] duas classes-controller no mesmo arquivo mantêm cada uma o seu prefixo
#   [21] cadeia fluente (`app.MapGroup(...).MapGet(...)`) não é invisível
#   [22] router Express só compõe com mount conhecido; sem mount, reporta e não emite
#   [23] Ktor: prefixo irresolúvel não deixa a rota descendente sair sem ele
#   [24] contrato OpenAPI em JSON é lido — não parsear é SUR-01 verde por vacuidade
#   [25] `servers[].url` compõe o basePath do contrato
#   [26] fonte que falha (authz-map sem método, YAML ilegível) vira `unresolved`, não vazio
#   [27] allowlist em string é ancorada — `health` não silencia `/v1/health-insurance`
#   [28] ciclo de produtores termina e é reportado, em vez de explodir a heap
#   [29] PROVA: mutar a regra que corrige cada caso faz o caso reprovar (8 mutações)
#   [30] classe SEM CORPO (`data class` do Kotlin) não rouba o prefixo do controller seguinte,
#        e classe sem [Route] não herda o da anterior
#   [31] receptor desconhecido (`group.RequireAuthorization()`) e cadeia de MapGroup com elo não
#        adjacente não emitem prefixo pela metade
#   [32] Ktor `get { }` sem path; router Express com nome fora da heurística mas com mount conhecido
#   [33] contrato ilegível/parcial e fonte INEXISTENTE viram `unresolved`, nunca superfície vazia
#   [34] basePath compõe nas duas serializações; `servers` ambíguo ou de PathItem não contamina
#   [35] authz-map ilegível, em flow style, ou com `endpoint:` fora da forma, vira `unresolved`
#   [36] paths sobrepostos não fabricam ambiguidade de produtor (arquivo indexado duas vezes)
#   [37] literal com `//` ou `{` não desbalanceia o corpo da classe (o prefixo não evapora)
#   [38] DSL cujo nome coincide com verbo (`respondHtml { head { … } }`) não vira rota fantasma
#   [39] restrição genérica `where T : class` não cria classe fantasma que rouba o [Route]
#   [40] o guard de MapGroup não é abafado por dupla contagem; fonte declarada e vazia é reportada
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
const decl = as.collectDeclaredSurface({ contractPaths: [`${fix}/contracts`], root: fix });
if (decl.unresolved.length !== 0) { console.error(`fixture íntegro produziu ${decl.unresolved.length} irresolúvel no lado do contrato: ${JSON.stringify(decl.unresolved.map((u) => u.kind))}`); process.exit(1); }
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

echo "[17] produtores homônimos → ambiguidade reportada, sem rota cruzada entre módulos"
mkdir -p "$T/homonimos"
cat > "$T/homonimos/Program.cs" <<'CS'
var billing = app.MapGroup("/internal/v1/billing");
billing.MapModuleEndpoints();
var vault = app.MapGroup("/internal/v1/vault");
vault.MapModuleEndpoints();
CS
cat > "$T/homonimos/BillingEndpoints.cs" <<'CS'
public static class BillingEndpoints
{
    public static RouteGroupBuilder MapModuleEndpoints(this RouteGroupBuilder group)
    {
        group.MapPost("/charge", Charge);
        return group;
    }
}
CS
cat > "$T/homonimos/VaultEndpoints.cs" <<'CS'
public static class VaultEndpoints
{
    public static RouteGroupBuilder MapModuleEndpoints(this RouteGroupBuilder group)
    {
        group.MapPost("/reveal", Reveal);
        return group;
    }
}
CS
cat > "$T/check-17.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/homonimos`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
// O defeito: `MapModuleEndpoints` indexado por nome global, o último a ser lido sobrescreve o
// primeiro, e as rotas de um módulo saem penduradas no prefixo do outro.
if (paths.includes('POST /internal/v1/billing/reveal')) { console.error('rota CRUZADA entre módulos homônimos — path que não existe em lugar nenhum'); process.exit(1); }
if (paths.includes('POST /internal/v1/vault/charge')) { console.error('rota cruzada na direção oposta'); process.exit(1); }
if (paths.includes('POST /charge') || paths.includes('POST /reveal')) { console.error('rota emitida SEM o prefixo do grupo — path inventado'); process.exit(1); }
if (!unresolved.some((u) => u.kind === 'producer-ambiguous')) { console.error('ambiguidade não foi reportada — silêncio é o defeito'); process.exit(1); }
EOF
node "$T/check-17.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [17]"; exit 1; }
echo "OK [17]"

echo "[18] subgrupo aberto dentro do produtor herda o prefixo do chamador"
mkdir -p "$T/subgrupo"
cat > "$T/subgrupo/Program.cs" <<'CS'
var api = app.MapGroup("/internal/v1");
api.MapBilling();
CS
cat > "$T/subgrupo/Billing.cs" <<'CS'
public static class Billing
{
    public static RouteGroupBuilder MapBilling(this RouteGroupBuilder root)
    {
        var invoices = root.MapGroup("/invoices");
        invoices.MapGet("/{id}", Get);
        return root;
    }
}
CS
cat > "$T/check-18.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/subgrupo`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
if (paths.includes('GET /invoices/{}')) { console.error('subgrupo do produtor perdeu o prefixo do chamador — path inventado'); process.exit(1); }
if (!paths.includes('GET /internal/v1/invoices/{}')) { console.error(`cadeia grupo→produtor→subgrupo não compôs: ${JSON.stringify(paths)}`); process.exit(1); }
EOF
node "$T/check-18.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [18]"; exit 1; }
echo "OK [18]"

echo "[19] interpolação dentro da aspa é recusada como a do prefixo"
mkdir -p "$T/interp2"
cat > "$T/interp2/server.js" <<'JS'
const PREFIX = process.env.API_PREFIX;
app.get(`${PREFIX}/users`, handler);
app.get(`/v1/${tenant}/users`, handler);
app.post('/estatico', handler);
JS
cat > "$T/interp2/Routing.kt" <<'KT'
fun Application.configure() {
    route("$API_BASE/payments") {
        get("/{id}") { call.respond("ok") }
    }
}
KT
cat > "$T/check-19.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/interp2`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
if (paths.some((p) => p.includes('$'))) { console.error(`o scanner emitiu rota com interpolação não resolvida: ${JSON.stringify(paths)}`); process.exit(1); }
if (paths.includes('GET /{}/users')) { console.error('template literal virou rota com o parâmetro apagado — path inventado'); process.exit(1); }
// O caso perigoso: interpolação NO MEIO do path produz `/v1/{}/users`, que passa por rota
// legítima e casa com o contrato errado. Prefixo interpolado ao menos sai com forma estranha;
// este sai plausível, e é o que o SUR-01 compararia com cara de veredito confiante.
if (paths.includes('GET /v1/{}/users')) { console.error('interpolação no meio do path virou rota plausível e inexistente'); process.exit(1); }
if (!paths.includes('POST /estatico')) { console.error('a recusa levou junto a rota estática do mesmo arquivo'); process.exit(1); }
if (unresolved.length === 0) { console.error('nada foi reportado — o silêncio é o defeito'); process.exit(1); }
// A forma Kotlin `"$API_BASE/payments"` precisa ser enforçada por asserção própria: sem isto o
// `route-path-not-literal` do server.js sustenta o caso sozinho e a metade Kotlin não é testada.
if (paths.includes('GET /payments/{}')) { console.error('prefixo Kotlin interpolado descartado, e a rota saiu sem ele'); process.exit(1); }
if (!unresolved.some((u) => u.kind === 'group-path-not-literal')) { console.error('interpolação Kotlin no route() não foi reportada'); process.exit(1); }
EOF
node "$T/check-19.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [19]"; exit 1; }
echo "OK [19]"

echo "[20] duas classes-controller no mesmo arquivo mantêm cada prefixo"
mkdir -p "$T/duasclasses"
cat > "$T/duasclasses/Controllers.cs" <<'CS'
[Route("api/widgets")]
public class WidgetsController : ControllerBase
{
    [HttpGet("{id}")]
    public IActionResult Get(long id) => Ok();
}

[Route("api/gadgets")]
public class GadgetsController : ControllerBase
{
    [HttpPost("bulk")]
    public IActionResult Bulk() => Ok();
}
CS
run_node <<'EOF' || { echo "FAIL [20]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/duasclasses`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`).sort();
const esperado = ['GET /api/widgets/{}', 'POST /api/gadgets/bulk'].sort();
if (JSON.stringify(paths) !== JSON.stringify(esperado)) { console.error(`veio ${JSON.stringify(paths)}, esperava ${JSON.stringify(esperado)} — prefixo por classe, não por arquivo`); process.exit(1); }
EOF
echo "OK [20]"

echo "[21] cadeia fluente não é invisível"
mkdir -p "$T/fluente"
cat > "$T/fluente/Program.cs" <<'CS'
app.MapGroup("/internal/v1/keys").MapGet("/rotate", Rotate);
var encadeado = app.MapGroup("/api").MapGroup("/v3");
encadeado.MapPost("/ping", Ping);
CS
run_node <<'EOF' || { echo "FAIL [21]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/fluente`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
if (!paths.includes('GET /internal/v1/keys/rotate')) { console.error(`registro fluente invisível: ${JSON.stringify(paths)}`); process.exit(1); }
if (paths.includes('POST /api/ping')) { console.error('MapGroup encadeado perdeu o segundo segmento — path inventado'); process.exit(1); }
if (!paths.includes('POST /api/v3/ping')) { console.error(`MapGroup encadeado não compôs: ${JSON.stringify(paths)}`); process.exit(1); }
EOF
echo "OK [21]"

echo "[22] router Express só compõe com mount conhecido"
mkdir -p "$T/mount"
cat > "$T/mount/server.js" <<'JS'
const router = express.Router();
router.post('/orders', handler);
app.use('/api/v2', router);

const usersRouter = express.Router();
usersRouter.get('/:id', handler);
JS
run_node <<'EOF' || { echo "FAIL [22]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/mount`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
if (paths.includes('POST /orders')) { console.error('rota de router emitida sem o prefixo do app.use — path inventado'); process.exit(1); }
if (!paths.includes('POST /api/v2/orders')) { console.error(`mount conhecido não compôs: ${JSON.stringify(paths)}`); process.exit(1); }
if (paths.includes('GET /{}')) { console.error('router sem mount emitiu path relativo como absoluto'); process.exit(1); }
if (!unresolved.some((u) => u.kind === 'router-mount-unknown')) { console.error('router sem mount não foi reportado'); process.exit(1); }
EOF
echo "OK [22]"

echo "[23] Ktor: prefixo irresolúvel não deixa a rota descendente sair sem ele"
mkdir -p "$T/ktordyn"
cat > "$T/ktordyn/Routing.kt" <<'KT'
fun Application.configure() {
    route(basePath) {
        get("/status") { call.respond("ok") }
    }
    route("/api/v1") {
        post("/orders") { call.respond("ok") }
    }
}
KT
run_node <<'EOF' || { echo "FAIL [23]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/ktordyn`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
if (paths.includes('GET /status')) { console.error('rota sob prefixo irresolúvel emitida sem ele — path inventado'); process.exit(1); }
if (!paths.includes('POST /api/v1/orders')) { console.error('a supressão levou junto a rota do bloco resolvido'); process.exit(1); }
if (!unresolved.some((u) => u.kind === 'route-prefix-unresolved')) { console.error('a rota suprimida não foi reportada — suprimir em silêncio é o mesmo defeito'); process.exit(1); }
EOF
echo "OK [23]"

echo "[24] contrato OpenAPI em JSON é lido"
mkdir -p "$T/json"
cat > "$T/json/openapi.json" <<'JSON'
{
  "openapi": "3.0.0",
  "paths": {
    "/widgets": { "get": { "summary": "Lista" } },
    "/widgets/{id}": { "delete": { "summary": "Remove" } }
  }
}
JSON
cat > "$T/check-24.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const { endpoints, bySource } = as.collectDeclaredSurface({ contractPaths: [`${tmp}/json`], root: tmp });
const keys = endpoints.map((e) => `${e.method} ${e.path}`).sort();
// Não parsear o JSON devolvia [] — e SUR-01 sobre superfície vazia é verde por vacuidade.
if (keys.length !== 2) { console.error(`contrato JSON não foi lido: ${JSON.stringify(keys)}`); process.exit(1); }
if (!keys.includes('DELETE /widgets/{}')) { console.error(`endpoint do JSON ausente: ${JSON.stringify(keys)}`); process.exit(1); }
if (bySource.openapi !== 2) { console.error(`bySource.openapi = ${bySource.openapi}, esperava 2`); process.exit(1); }
EOF
node "$T/check-24.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [24]"; exit 1; }
echo "OK [24]"

echo "[25] servers[].url compõe o basePath"
mkdir -p "$T/servers"
cat > "$T/servers/api.yaml" <<'YML'
openapi: 3.0.3
servers:
  - url: /api/v1
paths:
  /widgets:
    get:
      summary: Lista
YML
run_node <<'EOF' || { echo "FAIL [25]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const { endpoints } = as.collectDeclaredSurface({ contractPaths: [`${tmp}/servers`], root: tmp });
const keys = endpoints.map((e) => `${e.method} ${e.path}`);
if (keys.includes('GET /widgets')) { console.error('basePath de servers[] ignorado — SUR-01 acusaria toda a superfície de um contrato correto'); process.exit(1); }
if (!keys.includes('GET /api/v1/widgets')) { console.error(`basePath não compôs: ${JSON.stringify(keys)}`); process.exit(1); }
EOF
echo "OK [25]"

echo "[26] fonte que falha vira unresolved, não superfície vazia"
mkdir -p "$T/falha/authz"
cat > "$T/falha/authz/sem-metodo.yaml" <<'YML'
routes:
  - path: /v1/vault/reveal
    policy: policy.reveal
YML
run_node <<'EOF' || { echo "FAIL [26]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const { endpoints, unresolved } = as.collectDeclaredSurface({ authzPaths: [`${tmp}/falha/authz`], root: tmp });
const keys = endpoints.map((e) => `${e.method} ${e.path}`);
// Assumir GET faz o SUR-01 bloquear num endpoint que ninguém prometeu, enquanto a rota real
// (POST) ainda aparece no SUR-02 como não declarada. Inventar o verbo é inventar endpoint.
if (keys.includes('GET /v1/vault/reveal')) { console.error('entrada sem método virou GET — verbo inventado'); process.exit(1); }
if (!unresolved.some((u) => u.kind === 'authz-entry-without-method')) { console.error('entrada sem método não foi reportada'); process.exit(1); }
EOF
echo "OK [26]"

echo "[27] allowlist em string é ancorada no início"
run_node <<'EOF' || { echo "FAIL [27]"; exit 1; }
const [lib] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const routes = [{ method: 'GET', path: '/v1/health-insurance/claims' }, { method: 'GET', path: '/health/live' }];
const grupos = as.surCodeToContract(routes, new Set(), { allowlist: ['/health'] });
const total = grupos.reduce((acc, g) => acc + g.count, 0);
// Sem âncora, `/health` casa em qualquer posição e `/v1/health-insurance/claims` — superfície de
// negócio — é silenciada junto com a infra que o padrão realmente queria cobrir.
if (total !== 1) { console.error(`allowlist sem âncora silenciou superfície de negócio: ${total} achados, esperava 1`); process.exit(1); }
if (grupos[0].routes[0].path !== '/v1/health-insurance/claims') { console.error('silenciou o endpoint errado'); process.exit(1); }
EOF
echo "OK [27]"

echo "[28] ciclo de produtores termina e é reportado"
mkdir -p "$T/ciclo"
cat > "$T/ciclo/Program.cs" <<'CS'
var raiz = app.MapGroup("/v1");
raiz.MapAlpha();
CS
cat > "$T/ciclo/Ciclo.cs" <<'CS'
public static class Ciclo
{
    public static RouteGroupBuilder MapAlpha(this RouteGroupBuilder group)
    {
        group.MapGet("/alpha", Alpha);
        group.MapBeta();
        return group;
    }

    public static RouteGroupBuilder MapBeta(this RouteGroupBuilder group)
    {
        group.MapGet("/beta", Beta);
        group.MapAlpha();
        return group;
    }
}
CS
run_node <<'EOF' || { echo "FAIL [28]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const inicio = Date.now();
const { routes, unresolved } = scanRoutes([`${tmp}/ciclo`], { root: tmp });
const ms = Date.now() - inicio;
if (ms > 5000) { console.error(`composição levou ${ms}ms — o ciclo não está sendo cortado`); process.exit(1); }
const paths = routes.map((r) => `${r.method} ${r.path}`).sort();
if (!paths.includes('GET /v1/alpha') || !paths.includes('GET /v1/beta')) { console.error(`o corte do ciclo levou junto as rotas legítimas: ${JSON.stringify(paths)}`); process.exit(1); }
if (!unresolved.some((u) => u.kind === 'chain-cycle')) { console.error('ciclo cortado em silêncio — o corte precisa ser auditável'); process.exit(1); }
EOF
echo "OK [28]"

echo "[30] classe sem corpo não rouba o prefixo do controller seguinte"
mkdir -p "$T/semcorpo"
cat > "$T/semcorpo/Order.kt" <<'KT'
data class OrderDto(val id: Long, val total: Int)

@RestController
@RequestMapping("/api/orders")
class OrderController {
    @GetMapping("/list")
    fun list(): List<OrderDto> = emptyList()
}
KT
cat > "$T/semcorpo/Controllers.cs" <<'CS'
[ApiController]
[Route("api/alpha")]
public class AlphaController : ControllerBase
{
    [HttpGet("list")]
    public IActionResult List() => Ok();
}

public class HealthController : ControllerBase
{
    [HttpGet("/healthz")]
    public IActionResult Health() => Ok();
}
CS
cat > "$T/check-30.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/semcorpo`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`).sort();
// `data class Foo(...)` do Kotlin não tem corpo: procurar a próxima chave acha a da classe
// SEGUINTE, as duas passam a compartilhar intervalo, e o desempate dá a vitória à DTO — que não
// tem @RequestMapping. O prefixo do controller some, e o defeito é intermitente por ORDEM.
if (paths.includes('GET /list')) { console.error('prefixo do controller perdido para a classe sem corpo'); process.exit(1); }
if (!paths.includes('GET /api/orders/list')) { console.error(`prefixo Kotlin não resolveu: ${JSON.stringify(paths)}`); process.exit(1); }
// Classe SEM [Route] não pode herdar o [Route] da classe anterior.
if (paths.includes('GET /api/alpha/healthz')) { console.error('classe sem [Route] herdou o prefixo da anterior — path inventado'); process.exit(1); }
if (!paths.includes('GET /healthz')) { console.error(`rota sem prefixo de classe sumiu: ${JSON.stringify(paths)}`); process.exit(1); }
if (!paths.includes('GET /api/alpha/list')) { console.error(`prefixo da primeira classe sumiu: ${JSON.stringify(paths)}`); process.exit(1); }
EOF
node "$T/check-30.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [30]"; exit 1; }
echo "OK [30]"

echo "[31] receptor desconhecido e cadeia truncada não emitem path parcial"
mkdir -p "$T/parcial"
cat > "$T/parcial/Program.cs" <<'CS'
var v1 = app.MapGroup("/internal/v1");
v1.MapAdminEndpoints();
var truncada = app.MapGroup("/api").RequireAuthorization().MapGroup("/v3");
truncada.MapGet("/orders", ListOrders);
CS
cat > "$T/parcial/Admin.cs" <<'CS'
public static class Admin
{
    public static void MapAdminEndpoints(this RouteGroupBuilder group)
    {
        var authed = group.RequireAuthorization();
        var g = authed.MapGroup("/admin");
        g.MapGet("/users", ListUsers);
    }
}
CS
cat > "$T/check-31.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/parcial`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
// `group.RequireAuthorization()` é idioma corrente: o receptor não é o parâmetro do produtor nem
// um grupo conhecido. Assumi-lo raiz descola a cadeia inteira do chamador.
if (paths.includes('GET /admin/users')) { console.error('receptor desconhecido virou raiz e a cadeia descolou do chamador'); process.exit(1); }
// Elo de MapGroup não adjacente: conhecer metade do prefixo é pior que não conhecer nada.
if (paths.includes('GET /api/orders')) { console.error('cadeia com elo perdido emitiu prefixo pela metade'); process.exit(1); }
const kinds = unresolved.map((u) => u.kind);
if (!kinds.includes('group-unreachable')) { console.error(`grupo sob receptor desconhecido não reportado: ${JSON.stringify(kinds)}`); process.exit(1); }
if (!kinds.includes('mapgroup-unindexed')) { console.error(`elo de MapGroup fora do alcance do reconhecedor não reportado: ${JSON.stringify(kinds)}`); process.exit(1); }
EOF
node "$T/check-31.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [31]"; exit 1; }
echo "OK [31]"

echo "[32] Ktor sem path e router Express com nome arbitrário"
mkdir -p "$T/idiomas"
cat > "$T/idiomas/Routing.kt" <<'KT'
fun Application.configure() {
    route("/v1") {
        get { call.respondText("index") }
        get("/ping") { call.respondText("pong") }
    }
}
KT
cat > "$T/idiomas/server.js" <<'JS'
const app = express();
const v1 = express.Router();
v1.get('/users', listUsers);
app.use('/api', v1);
JS
run_node <<'EOF' || { echo "FAIL [32]"; exit 1; }
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/idiomas`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
// `get { }` sem path é a forma idiomática do endpoint de coleção no Ktor; some-la faz o SUR-01,
// que bloqueia, reprovar um contrato correto.
if (!paths.includes('GET /v1')) { console.error(`Ktor get sem path sumiu: ${JSON.stringify(paths)}`); process.exit(1); }
if (!paths.includes('GET /v1/ping')) { console.error('Ktor get com path regrediu'); process.exit(1); }
// O mount de `v1` já está no índice; descartar por heurística de NOME joga fora informação que a
// própria passada coletou.
if (!paths.includes('GET /api/users')) { console.error(`router com nome fora da heurística perdeu o mount conhecido: ${JSON.stringify(paths)}`); process.exit(1); }
EOF
echo "OK [32]"

echo "[33] contrato ilegível ou parcial vira unresolved, nunca superfície vazia calada"
mkdir -p "$T/contrato"
cat > "$T/contrato/flow.yaml" <<'YML'
openapi: 3.0.3
paths:
  /widgets: {get: {summary: Lista}}
  /gadgets:
    $ref: "#/components/pathItems/G"
YML
cat > "$T/check-33.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
const parcial = as.collectDeclaredSurface({ contractPaths: [`${tmp}/contrato`], root: tmp });
const kinds = parcial.unresolved.map((u) => u.kind);
// Flow style e $ref de PathItem: o leitor linha a linha não os abre. Antes, o diagnóstico só
// existia quando `paths:` estava AUSENTE — o que garantia silêncio exatamente para os documentos
// que TÊM paths e o leitor não entende.
if (!kinds.includes('contract-paths-unparsed') && !kinds.includes('contract-path-without-verb')) {
  console.error(`contrato com paths ilegíveis passou calado: ${JSON.stringify(kinds)}`); process.exit(1);
}
// A forma mais comum do defeito: contrato movido, renomeado, ou typo no wiring.
const ausente = as.collectDeclaredSurface({ contractPaths: [`${tmp}/contrato/nao-existe.yaml`], root: tmp });
if (ausente.endpoints.length !== 0) { console.error('fonte inexistente produziu endpoints'); process.exit(1); }
if (!ausente.unresolved.some((u) => u.kind === 'source-missing')) { console.error('fonte declarada e inexistente devolveu superfície vazia SEM diagnóstico — SUR-01 verde por vacuidade'); process.exit(1); }
EOF
node "$T/check-33.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [33]"; exit 1; }
echo "OK [33]"

echo "[34] basePath compõe nas duas serializações, e servers ambíguo não é aplicado"
mkdir -p "$T/base/json" "$T/base/amb" "$T/base/nested"
cat > "$T/base/json/openapi.json" <<'JSON'
{ "openapi": "3.0.0", "servers": [{ "url": "https://api.exemplo.com/v2" }],
  "paths": { "/widgets": { "get": { "summary": "Lista" } } } }
JSON
cat > "$T/base/amb/api.yaml" <<'YML'
openapi: 3.0.3
servers:
  - url: /api/v1
  - url: /legacy
paths:
  /widgets:
    get:
      summary: Lista
YML
cat > "$T/base/nested/api.yaml" <<'YML'
openapi: 3.0.3
servers:
  - url: /api/v1
paths:
  /widgets:
    servers:
      - url: /legacy
    get:
      summary: Lista
YML
cat > "$T/check-34.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
// O basePath tem de compor no ramo JSON também — testar só o YAML deixava a metade JSON livre.
const j = as.collectDeclaredSurface({ contractPaths: [`${tmp}/base/json`], root: tmp });
const jk = j.endpoints.map((e) => `${e.method} ${e.path}`);
if (!jk.includes('GET /v2/widgets')) { console.error(`basePath do JSON (URL absoluta) não compôs: ${JSON.stringify(jk)}`); process.exit(1); }
// Dois basePaths distintos: não há prefixo único, e escolher um inventa metade da superfície.
const a = as.collectDeclaredSurface({ contractPaths: [`${tmp}/base/amb`], root: tmp });
const ak = a.endpoints.map((e) => `${e.method} ${e.path}`);
if (ak.includes('GET /api/v1/widgets') || ak.includes('GET /legacy/widgets')) { console.error('basePath ambíguo foi escolhido em vez de reportado'); process.exit(1); }
if (!a.unresolved.some((u) => u.kind === 'openapi-servers-ambiguous')) { console.error('ambiguidade de servers não reportada'); process.exit(1); }
// `servers` de PathItem é OpenAPI 3.x válido e NÃO pode contaminar o basePath da raiz.
const n = as.collectDeclaredSurface({ contractPaths: [`${tmp}/base/nested`], root: tmp });
const nk = n.endpoints.map((e) => `${e.method} ${e.path}`);
if (!nk.includes('GET /api/v1/widgets')) { console.error(`servers aninhado destruiu o basePath da raiz: ${JSON.stringify(nk)}`); process.exit(1); }
EOF
node "$T/check-34.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [34]"; exit 1; }
echo "OK [34]"

echo "[35] authz-map ilegível ou sem entradas reconhecidas vira unresolved"
mkdir -p "$T/authz"
cat > "$T/authz/flow.yaml" <<'YML'
routes: [{path: /a, method: GET}]
YML
cat > "$T/check-35.mjs" <<'EOF'
const [lib] = process.argv.slice(2);
const as = await import(`${lib}/api-surface.mjs`);
// Parser que lança: o arquivo inteiro sai da união, e os endpoints que só ele declara deixam de
// ser cruzados. Silêncio aqui é a mesma doença pela porta dos fundos.
const u1 = [];
as.fromAuthzMap('routes:\n  - - stray\n', 'x.yaml', u1);
const u2 = [];
as.fromAuthzMap('routes: [{path: /a, method: GET}]\n', 'flow.yaml', u2);
if (u2.length === 0) { console.error('authz-map em flow style virou superfície vazia sem diagnóstico'); process.exit(1); }
const u3 = [];
as.fromAuthzMap('routes:\n  - endpoint: "/a"\n    policy: p\n', 'e.yaml', u3);
if (!u3.some((u) => u.kind === 'authz-endpoint-unparsed')) { console.error(`endpoint fora da forma 'VERBO /path' caiu calado: ${JSON.stringify(u3.map((u) => u.kind))}`); process.exit(1); }
EOF
node "$T/check-35.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [35]"; exit 1; }
echo "OK [35]"

echo "[36] paths sobrepostos não fabricam ambiguidade de produtor"
run_node <<'EOF' || { echo "FAIL [36]"; exit 1; }
const [lib, fix] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
// Passar diretório E um arquivo dentro dele indexava o mesmo arquivo duas vezes; com a checagem
// de homônimos, todo produtor virava homônimo de SI MESMO e nenhuma invocação resolvia.
const { routes, unresolved } = scanRoutes([`${fix}/dotnet`, `${fix}/dotnet/WidgetEndpoints.cs`], { root: fix });
if (unresolved.some((u) => u.kind === 'producer-ambiguous')) { console.error(`arquivo indexado duas vezes virou ambiguidade: ${JSON.stringify(unresolved.map((u) => u.detail))}`); process.exit(1); }
if (routes.length !== 5) { console.error(`esperava as mesmas 5 rotas com paths sobrepostos, veio ${routes.length}`); process.exit(1); }
EOF
echo "OK [36]"

echo "[37] literal com // ou chave não desbalanceia o corpo da classe"
mkdir -p "$T/literais"
cat > "$T/literais/Orders.cs" <<'CS'
[Route("api/v1/orders")]
public class OrdersController : ControllerBase
{
    private static readonly HttpClient Client = new() { BaseAddress = new Uri("https://api.acme.com/") };
    private const string Tmpl = "{";
    [HttpGet("list")] public IActionResult List() => Ok();
}
CS
cat > "$T/check-37.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/literais`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
// O `//` da URL fazia o removedor de comentário levar junto o `}` da mesma linha; a chave dentro
// da string desbalanceava direto. O corpo da classe deixava de fechar, a classe era descartada, e
// a rota saía SEM prefixo — path inventado pela via mais silenciosa que existe.
if (paths.includes('GET /list')) { console.error('literal desbalanceou o corpo da classe e o prefixo evaporou'); process.exit(1); }
if (!paths.includes('GET /api/v1/orders/list')) { console.error(`prefixo não resolveu: ${JSON.stringify(paths)}`); process.exit(1); }
EOF
node "$T/check-37.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [37]"; exit 1; }
echo "OK [37]"

echo "[38] DSL cujo nome coincide com verbo não vira rota fantasma"
mkdir -p "$T/dsl"
cat > "$T/dsl/Routing.kt" <<'KT'
fun Application.configure() {
    route("/api/v1/orders") {
        get("/list") { call.respond(service.list()) }
        get("/page") {
            call.respondHtml {
                head { title { +"Orders" } }
                body { h1 { +"Orders" } }
            }
        }
    }
}
KT
cat > "$T/check-38.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/dsl`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
// `call.respondHtml { head { ... } }` do kotlinx.html é o idioma canônico de HTML no Ktor, e
// `head` está na lista de verbos. Aceitar `verb {` em qualquer profundidade inventava um endpoint.
if (paths.includes('HEAD /api/v1/orders')) { console.error('DSL aninhada virou rota fantasma'); process.exit(1); }
if (paths.length !== 2) { console.error(`esperava exatamente as 2 rotas reais, veio ${JSON.stringify(paths)}`); process.exit(1); }
EOF
node "$T/check-38.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [38]"; exit 1; }
echo "OK [38]"

echo "[39] restrição genérica 'where T : class' não cria classe fantasma"
mkdir -p "$T/generico"
cat > "$T/generico/Items.cs" <<'CS'
[ApiController]
[Route("api/v1/[controller]")]
public class ItemsController<TDto, TKey> : ControllerBase
    where TDto : class
    where TKey : struct
{
    [HttpGet("list")] public IActionResult List() => Ok();
}
CS
cat > "$T/check-39.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const { routes } = scanRoutes([`${tmp}/generico`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
// `\bclass\s+(\w+)` casava a restrição e criava um fantasma chamado `where`, que se interpõe
// entre o controller e o `{` do corpo dele — com o limite por próxima-declaração, isso descartava
// o controller real e transferia o [Route] (e a resolução de [controller]) para o fantasma.
if (paths.some((p) => p.includes('where'))) { console.error(`restrição genérica virou nome de classe: ${JSON.stringify(paths)}`); process.exit(1); }
if (!paths.includes('GET /api/v1/Items/list')) { console.error(`prefixo do controller genérico não resolveu: ${JSON.stringify(paths)}`); process.exit(1); }
EOF
node "$T/check-39.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [39]"; exit 1; }
echo "OK [39]"

echo "[40] guard de MapGroup não é abafado, e fonte declarada e vazia é reportada"
mkdir -p "$T/abafa" "$T/fontevazia"
cat > "$T/abafa/G.cs" <<'CS'
var ep = app.MapGroup("/a").MapGet("/x", H);
var b  = Helper.Build().MapGroup("/b");
b.MapGet("/y", H);
CS
cat > "$T/check-40.mjs" <<'EOF'
const [lib, , tmp] = process.argv.slice(2);
const { scanRoutes } = await import(`${lib}/route-scan.mjs`);
const as = await import(`${lib}/api-surface.mjs`);
const { routes, unresolved } = scanRoutes([`${tmp}/abafa`], { root: tmp });
const paths = routes.map((r) => `${r.method} ${r.path}`);
// Contar PUSHES em vez de sítios dava crédito em dobro quando uma atribuição era consumida pelas
// duas regexes, e esse crédito abafava um sítio genuinamente não ancorado no mesmo arquivo.
if (!unresolved.some((u) => u.kind === 'mapgroup-unindexed')) { console.error('sítio não ancorado foi abafado por dupla contagem'); process.exit(1); }
if (paths.includes('GET /y')) { console.error('rota de grupo com prefixo desconhecido saiu como absoluta'); process.exit(1); }
if (!paths.includes('GET /a/x')) { console.error('a supressão levou junto a cadeia que resolveu'); process.exit(1); }
// Diretório de contratos existente e VAZIO é o estado normal de um change no início — justamente
// quando o SUR-01 precisa se abster e passaria.
const vazio = as.collectDeclaredSurface({ contractPaths: [`${tmp}/fontevazia`], root: tmp });
if (!vazio.unresolved.some((u) => u.kind === 'source-empty')) { console.error('fonte declarada e sem arquivo legível passou calada'); process.exit(1); }
EOF
node "$T/check-40.mjs" "$LIB" "$FIX" "$T" || { echo "FAIL [40]"; exit 1; }
echo "OK [40]"

echo "[29] PROVA: cada correção morre quando a regra que a implementa é mutada"
# A mutação opera sobre uma CÓPIA do lib — o original nunca é tocado, então não há vetor de
# mutação fantasma por restore() malfeito. Os checks reutilizados aqui são os MESMOS arquivos que
# os casos [17]/[18]/[19]/[24] acabaram de rodar verdes: asserção duplicada diverge e cala.
mutar() {
  node -e '
    const fs = require("fs");
    const [f, de, para] = process.argv.slice(1);
    const s = fs.readFileSync(f, "utf8");
    if (!s.includes(de)) { console.error("alvo de mutacao ausente: " + de); process.exit(1); }
    fs.writeFileSync(f, s.replace(de, para));
  ' "$@"
}

soma_lib() { cat "$LIB"/*.mjs | shasum | cut -d' ' -f1; }
LIB_ANTES="$(soma_lib)"

for caso in 17 18 19 24 30 31 33 34 37 38 39 40; do
  rm -rf "$T/mutlib" "$T/ctrllib"
  mkdir -p "$T/mutlib" "$T/ctrllib"
  cp "$LIB"/*.mjs "$T/mutlib/"
  cp "$LIB"/*.mjs "$T/ctrllib/"

  # CONTROLE: o check passa contra a cópia íntegra. Separa "o caso é verde" de "a mutação o
  # derrubou" — sem isto, um check quebrado por outro motivo contaria como mutação morta.
  node "$T/check-$caso.mjs" "$T/ctrllib" "$FIX" "$T" >/dev/null 2>&1 \
    || { echo "FAIL [29]: controle do caso [$caso] reprovou sobre cópia íntegra — nada adiante prova nada"; exit 1; }

  case "$caso" in
    17) mutar "$T/mutlib/route-scan.mjs" 'if (cands.length > 1) {' 'if (false) {' ;;
    18) mutar "$T/mutlib/route-scan.mjs" 'if (p) return p.rootLike && !invokedNames.has(p.name) && !ambiguousNames.has(p.name);' 'if (p) return true;' ;;
    19) mutar "$T/mutlib/route-scan.mjs" 'if (/\$\{/.test(conteudo)) return null;' 'if (false) return null;' ;;
    24) mutar "$T/mutlib/api-surface.mjs" "if (text.trim().startsWith('{')) return fromOpenApiJson(text, file, unresolved);" '' ;;
    30) mutar "$T/mutlib/route-scan.mjs" 'if (open === -1 || open >= limite) return;' 'if (open === -1) return;' ;;
    31) mutar "$T/mutlib/route-scan.mjs" 'if (dono && !dono.rootLike) return false;' '' ;;
    33) mutar "$T/mutlib/api-surface.mjs" "kind: 'source-missing'," "kind: 'source-missing-x'," ;;
    34) mutar "$T/mutlib/api-surface.mjs" 'if (ind === 0 && /^servers\s*:\s*$/.test(line.trim()))' 'if (/^servers\s*:\s*$/.test(line.trim()))' ;;
    37) mutar "$T/mutlib/route-scan.mjs" 'branco(struct, i);
        i += 1;' 'i += 1;' ;;
    38) mutar "$T/mutlib/route-scan.mjs" 'if (m[4] !== undefined && (stack.length === 0 || depth !== stack[stack.length - 1].depth)) {' 'if (m[4] !== undefined && stack.length === 0) {' ;;
    39) mutar "$T/mutlib/route-scan.mjs" "if (antes.endsWith(':') || antes.endsWith(',')) continue;" '' ;;
    40) mutar "$T/mutlib/route-scan.mjs" 'if (idx.groups.some((g) => g.id === id)) continue;' 'continue;' ;;
  esac || { echo "FAIL [29]: mutação do caso [$caso] não encontrou o alvo — a prova não vale"; exit 1; }

  if node "$T/check-$caso.mjs" "$T/mutlib" "$FIX" "$T" >/dev/null 2>&1; then
    echo "FAIL [29]: mutação do caso [$caso] SOBREVIVEU — o teste não prova a correção"; exit 1
  fi

  # RECONTROLE: a cópia íntegra continua verde depois da mutação da outra cópia, provando que a
  # mutação ficou contida onde deveria.
  node "$T/check-$caso.mjs" "$T/ctrllib" "$FIX" "$T" >/dev/null 2>&1 \
    || { echo "FAIL [29]: recontrole do caso [$caso] reprovou — a mutação vazou para fora da cópia"; exit 1; }
done

# O comentário acima afirma que o original nunca é tocado; esta linha VERIFICA. Sem ela, um
# `mutar` apontado para $LIB por engano passaria despercebido — o recontrole roda sobre uma cópia
# feita antes da mutação e seguiria verde.
[ "$(soma_lib)" = "$LIB_ANTES" ] || { echo "FAIL [29]: o lib de origem foi modificado pela prova de mutação"; exit 1; }
echo "OK [29]"

echo "OK"
