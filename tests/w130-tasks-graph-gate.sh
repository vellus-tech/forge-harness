#!/usr/bin/env bash
# Gate W130 — grafo de tasks (TSK-01..04) e cobertura de superfície (SRF-01) como SCRIPT.
#
# Por que existe: o harness já ESPECIFICAVA os dois checks, e ambos eram instrução para LLM.
#   - `commands/specs/tasks.md` §2 mandava auto-verificar "nenhuma dependência aponta para TASK
#     inexistente ou posterior (ordem topológica válida)" — checklist em markdown, que deixou
#     passar uma dependência de Wave 4 para Wave 7 num plano de 89 tasks.
#   - `commands/specs/analyze.md` item 6 mandava cruzar o "Checklist de cobertura de superfície"
#     do requirements.md contra design/tasks, dizendo textualmente que é isso "que impede a lacuna
#     clássica de parâmetro implementado sem superfície de acesso" — e não existe script `analyze`.
# Um check que só um modelo executa é um check que às vezes não roda. Aqui ele roda sempre.
#
#   [0] CONTROLE: fixture canônico e íntegro passa em TODOS os checks (sem isso, nenhum vermelho
#       abaixo prova nada — é a lição das mutações que "reprovaram" sem serem exercitadas)
#   [1] o parser extrai id/n/status/wave/título/rastreia/paths/depende da linha canônica
#   [2] `paths:` — brace-expansion de shell, diretório e lista com vírgula (expande o expansível,
#       trata o resto como literal, sem fingir precisão)
#   [3] TSK-01 — dependência pendurada (aponta para TASK inexistente)
#   [4] TSK-02 — ciclo de dependência
#   [5] TSK-03 — dependência para TASK de wave POSTERIOR (o defeito real)
#   [6] TSK-04 — ID duplicado e furo na numeração
#   [7] SRF-01 — linha do Checklist cuja superfície é endpoint/API e cujas tasks não produzem
#       superfície nenhuma; veredito POR REQ, não por task
#   [8] PBT — TSK-03 acusa se e somente se existe aresta para wave posterior (com asserção sobre
#       o próprio gerador: se ele não produz os dois lados, a propriedade é tautologia)
#   [9] PBT — o parser é idempotente e insensível a espaçamento
#   [10] REPRODUÇÃO — fixture congelado do repositório real: a dependência Wave 4 → Wave 7 dá
#       exatamente 1 achado, e a linha REQ-05 do Checklist real reprova sem editar nada
#   [11] FIAÇÃO — `validate-spec` reprova a transição a `tasks-ready` com o grafo quebrado
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
FIX="$WS/tests/fixtures/w130"
T="$(mktemp -d /tmp/forge-w130.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── [0] CONTROLE ─────────────────────────────────────────────────────────────────────────────
echo "[0] CONTROLE: fixture canônico e íntegro passa em todos os checks"
node - "$LIB" "$T" <<'EOF' || { echo "FAIL [0]: fixture íntegro reprovou — nenhum vermelho adiante prova nada"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url'); const fs = require('fs');
(async () => {
  const [lib, tmp] = process.argv.slice(2);
  const G = await import(pathToFileURL(join(lib, 'tasks-graph.mjs')).href);
  const tasks = [
    '# Tasks — exemplo', '',
    '## Wave 1 — base', '',
    '- [ ] TASK-01 — cria o esquema (rastreia: REQ-01; paths: `src/db/schema.sql`; depende: —)',
    '- [X] TASK-02 — grava o registro (rastreia: REQ-01; paths: `src/store.ts`; depende: TASK-01)', '',
    '## Wave 2 — superfície', '',
    '- [ ] TASK-03 — POST /v1/itens no orquestrador (rastreia: REQ-02; paths: `src/api/itens.ts`; depende: TASK-02)',
    '- [ ] TASK-04 — tela de listagem (rastreia: REQ-02; paths: `ui/Lista.tsx`; depende: TASK-03)', '',
    '## Rastreabilidade', '',
    '| REQ | Tasks |', '|---|---|', '| REQ-01 | TASK-01, TASK-02 |',
  ].join('\n');
  const req = [
    '# Requirements', '',
    '## Checklist de cobertura de superfície', '',
    '| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |',
    '|---|---|---|---|',
    '| REQ-01 | sem parâmetro exposto | n/a | TASK-01, TASK-02 |',
    '| REQ-02 | nome do item | endpoint `POST /v1/itens`, tela Lista | TASK-03, TASK-04 |', '',
    '## Outra seção', '',
  ].join('\n');
  fs.writeFileSync(join(tmp, 'tasks-ok.md'), tasks);
  fs.writeFileSync(join(tmp, 'req-ok.md'), req);

  const parsed = G.parseTasks(tasks);
  if (parsed.tasks.length !== 4) { console.error(`parseou ${parsed.tasks.length} tasks, esperado 4`); process.exit(1); }
  if (parsed.waves.length !== 2) { console.error(`parseou ${parsed.waves.length} waves, esperado 2`); process.exit(1); }
  const graph = G.checkTasksGraph(parsed);
  if (graph.length) { console.error('grafo íntegro acusou: ' + JSON.stringify(graph)); process.exit(1); }
  const rows = G.parseSurfaceChecklist(req);
  if (rows.length !== 2) { console.error(`checklist deu ${rows.length} linhas, esperado 2`); process.exit(1); }
  const srf = G.checkSurfaceCoverage(rows, parsed);
  if (srf.length) { console.error('checklist coberto acusou: ' + JSON.stringify(srf)); process.exit(1); }
})();
EOF
echo "OK [0]"

# ── [1] parser: campos da linha canônica ─────────────────────────────────────────────────────
echo "[1] o parser extrai os campos da linha canônica"
node - "$LIB" <<'EOF' || { echo "FAIL [1]: parser não extraiu os campos"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const G = await import(pathToFileURL(join(process.argv[2], 'tasks-graph.mjs')).href);
  const md = [
    '## Wave 3 — terceira', '',
    '- [-] TASK-07 — Liberação após wrap (rastreia: REQ-05, REQ-06; paths: `src/a.cs`, `src/b.cs`; depende: TASK-02, TASK-05)',
    '- [!] TASK-08 — bloqueada (rastreia: REQ-07; paths: `x.ts`; depende: —)',
  ].join('\n');
  const { tasks } = G.parseTasks(md);
  if (tasks.length !== 2) { console.error(`esperado 2 tasks, veio ${tasks.length}`); process.exit(1); }
  const t = tasks[0];
  const want = {
    id: 'TASK-07', n: 7, status: '-', wave: 3, title: 'Liberação após wrap',
    traces: ['REQ-05', 'REQ-06'], paths: ['src/a.cs', 'src/b.cs'], dependsOn: ['TASK-02', 'TASK-05'], line: 3,
  };
  for (const k of Object.keys(want)) {
    const got = JSON.stringify(t[k]); const exp = JSON.stringify(want[k]);
    if (got !== exp) { console.error(`campo ${k}: veio ${got}, esperado ${exp}`); process.exit(1); }
  }
  if (tasks[1].status !== '!') { console.error(`status bloqueado veio "${tasks[1].status}"`); process.exit(1); }
  if (tasks[1].dependsOn.length !== 0) { console.error('travessão em depende: deveria dar lista vazia'); process.exit(1); }

  // `rastreia:` carrega tokens que NÃO são REQ — `design DD-11`, `ADR 0016 decisão 2`,
  // `LDG-0084`, `DEFER-01` aparecem no mesmo campo em planos reais. Descartá-los perderia rastreio.
  const mixed = G.parseTasks('## Wave 1 — w\n\n- [ ] TASK-01 — t (rastreia: REQ-11, ADR 0016 decisão 2, LDG-0084; paths: `a`; depende: —)').tasks[0];
  if (JSON.stringify(mixed.traces) !== JSON.stringify(['REQ-11', 'ADR 0016 decisão 2', 'LDG-0084'])) {
    console.error(`traces mistos perderam token: ${JSON.stringify(mixed.traces)}`); process.exit(1);
  }

  // Task SEM o bloco de metadados existe em planos reais (um change deste próprio repositório tem
  // 30 assim). Tem que parsear como task de título completo e sem arestas — não ser descartada em
  // silêncio, que faria o grafo inteiro escapar da verificação sem ninguém notar.
  const bare = G.parseTasks('## Wave 1 — w\n\n- [X] TASK-01 — W0.1 git init + estrutura do workspace').tasks;
  if (bare.length !== 1) { console.error('task sem metadados foi descartada'); process.exit(1); }
  if (bare[0].title !== 'W0.1 git init + estrutura do workspace') { console.error(`título truncado: "${bare[0].title}"`); process.exit(1); }
  if (bare[0].status !== 'X' || bare[0].dependsOn.length || bare[0].paths.length) {
    console.error(`task sem metadados malformada: ${JSON.stringify(bare[0])}`); process.exit(1);
  }
})();
EOF
echo "OK [1]"

# ── [2] paths: brace-expansion, diretório, lista ─────────────────────────────────────────────
echo "[2] paths — brace-expansion, diretório e lista com vírgula"
node - "$LIB" <<'EOF' || { echo "FAIL [2]: paths não normalizados"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const G = await import(pathToFileURL(join(process.argv[2], 'tasks-graph.mjs')).href);
  const md = [
    '## Wave 1 — w', '',
    '- [ ] TASK-01 — a (rastreia: REQ-01; paths: `src/{Api,Core}/Item.cs`; depende: —)',
    '- [ ] TASK-02 — b (rastreia: REQ-01; paths: `src/Orchestrator/`, `docs/x.md`; depende: —)',
    '- [ ] TASK-03 — c (rastreia: REQ-01; paths: `src/**/*.ts`; depende: —)',
  ].join('\n');
  const { tasks } = G.parseTasks(md);
  const p = (n) => JSON.stringify(tasks.find((t) => t.n === n).paths);
  // a vírgula DENTRO das chaves não separa paths; a de fora separa
  if (p(1) !== JSON.stringify(['src/Api/Item.cs', 'src/Core/Item.cs'])) { console.error(`brace: ${p(1)}`); process.exit(1); }
  if (p(2) !== JSON.stringify(['src/Orchestrator/', 'docs/x.md'])) { console.error(`lista: ${p(2)}`); process.exit(1); }
  // glob que não é brace-expansion fica literal — não fingimos precisão que não temos
  if (p(3) !== JSON.stringify(['src/**/*.ts'])) { console.error(`glob: ${p(3)}`); process.exit(1); }
})();
EOF
echo "OK [2]"

# ── [3] TSK-01 dependência pendurada ─────────────────────────────────────────────────────────
echo "[3] TSK-01 — dependência pendurada"
node - "$LIB" <<'EOF' || { echo "FAIL [3]: dependência pendurada passou"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const G = await import(pathToFileURL(join(process.argv[2], 'tasks-graph.mjs')).href);
  const md = [
    '## Wave 1 — w', '',
    '- [ ] TASK-01 — a (rastreia: REQ-01; paths: `a`; depende: —)',
    '- [ ] TASK-02 — b (rastreia: REQ-01; paths: `b`; depende: TASK-99)',
  ].join('\n');
  const f = G.checkTasksGraph(G.parseTasks(md));
  const hits = f.filter((x) => x.code === 'TSK-01');
  if (hits.length !== 1) { console.error(`TSK-01 deu ${hits.length} achados: ${JSON.stringify(f)}`); process.exit(1); }
  if (!hits[0].msg.includes('TASK-99') || !hits[0].msg.includes('TASK-02')) {
    console.error(`mensagem não nomeia as duas tasks: ${hits[0].msg}`); process.exit(1);
  }
  if (hits[0].enforceable !== true) { console.error('TSK-01 deveria bloquear'); process.exit(1); }
})();
EOF
echo "OK [3]"

# ── [4] TSK-02 ciclo ─────────────────────────────────────────────────────────────────────────
echo "[4] TSK-02 — ciclo de dependência"
node - "$LIB" <<'EOF' || { echo "FAIL [4]: ciclo passou"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const G = await import(pathToFileURL(join(process.argv[2], 'tasks-graph.mjs')).href);
  const md = [
    '## Wave 1 — w', '',
    '- [ ] TASK-01 — a (rastreia: REQ-01; paths: `a`; depende: TASK-03)',
    '- [ ] TASK-02 — b (rastreia: REQ-01; paths: `b`; depende: TASK-01)',
    '- [ ] TASK-03 — c (rastreia: REQ-01; paths: `c`; depende: TASK-02)',
  ].join('\n');
  const f = G.checkTasksGraph(G.parseTasks(md));
  const hits = f.filter((x) => x.code === 'TSK-02');
  if (hits.length < 1) { console.error(`ciclo não detectado: ${JSON.stringify(f)}`); process.exit(1); }
  // a mensagem tem que mostrar o caminho, senão o autor não sabe onde cortar
  if (!/TASK-01.*TASK-0[23]/.test(hits[0].msg)) { console.error(`mensagem sem caminho: ${hits[0].msg}`); process.exit(1); }
  // e o grafo acíclico equivalente NÃO acusa (o teste do teste)
  const ok = md.replace('depende: TASK-03)', 'depende: —)');
  const clean = G.checkTasksGraph(G.parseTasks(ok)).filter((x) => x.code === 'TSK-02');
  if (clean.length) { console.error('acusou ciclo em grafo acíclico'); process.exit(1); }
})();
EOF
echo "OK [4]"

# ── [5] TSK-03 dependência para wave posterior ───────────────────────────────────────────────
echo "[5] TSK-03 — dependência para wave posterior"
node - "$LIB" <<'EOF' || { echo "FAIL [5]: dependência para wave posterior passou"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const G = await import(pathToFileURL(join(process.argv[2], 'tasks-graph.mjs')).href);
  const md = [
    '## Wave 4 — quarta', '',
    '- [ ] TASK-89 — envio com identidade (rastreia: REQ-05; paths: `a`; depende: TASK-45)', '',
    '## Wave 7 — sétima', '',
    '- [ ] TASK-45 — cobertura (rastreia: REQ-05; paths: `b`; depende: —)',
  ].join('\n');
  const f = G.checkTasksGraph(G.parseTasks(md));
  const hits = f.filter((x) => x.code === 'TSK-03');
  if (hits.length !== 1) { console.error(`TSK-03 deu ${hits.length} achados: ${JSON.stringify(f)}`); process.exit(1); }
  for (const needle of ['TASK-89', 'TASK-45', '4', '7']) {
    if (!hits[0].msg.includes(needle)) { console.error(`mensagem sem "${needle}": ${hits[0].msg}`); process.exit(1); }
  }
  if (hits[0].enforceable !== true) { console.error('TSK-03 deveria bloquear'); process.exit(1); }
  // dependência para a MESMA wave, e para wave anterior, são legítimas
  const same = [
    '## Wave 4 — quarta', '',
    '- [ ] TASK-10 — a (rastreia: REQ-01; paths: `a`; depende: TASK-11)',
    '- [ ] TASK-11 — b (rastreia: REQ-01; paths: `b`; depende: —)',
  ].join('\n');
  if (G.checkTasksGraph(G.parseTasks(same)).filter((x) => x.code === 'TSK-03').length) {
    console.error('acusou dependência dentro da mesma wave'); process.exit(1);
  }
})();
EOF
echo "OK [5]"

# ── [6] TSK-04 duplicata e furo ──────────────────────────────────────────────────────────────
echo "[6] TSK-04 — ID duplicado e furo na numeração"
node - "$LIB" <<'EOF' || { echo "FAIL [6]: duplicata/furo passou"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const G = await import(pathToFileURL(join(process.argv[2], 'tasks-graph.mjs')).href);
  const dup = [
    '## Wave 1 — w', '',
    '- [ ] TASK-01 — a (rastreia: REQ-01; paths: `a`; depende: —)',
    '- [ ] TASK-02 — b (rastreia: REQ-01; paths: `b`; depende: —)',
    '- [ ] TASK-02 — c (rastreia: REQ-01; paths: `c`; depende: —)',
  ].join('\n');
  const d = G.checkTasksGraph(G.parseTasks(dup)).filter((x) => x.code === 'TSK-04');
  if (!d.length || !d.some((x) => x.msg.includes('TASK-02'))) {
    console.error(`duplicata não detectada: ${JSON.stringify(d)}`); process.exit(1);
  }
  // A ASSIMETRIA é o ponto, e sem esta asserção ela não estava coberta: duplicata é sempre defeito
  // (duas tasks disputando a mesma aresta) e BLOQUEIA; furo é ambíguo — remover task sem renumerar é
  // a operação segura — e apenas AVISA.
  if (!d.every((x) => x.enforceable === true)) { console.error('duplicata deveria bloquear'); process.exit(1); }
  const gap = [
    '## Wave 1 — w', '',
    '- [ ] TASK-01 — a (rastreia: REQ-01; paths: `a`; depende: —)',
    '- [ ] TASK-04 — b (rastreia: REQ-01; paths: `b`; depende: —)',
  ].join('\n');
  const g = G.checkTasksGraph(G.parseTasks(gap)).filter((x) => x.code === 'TSK-04');
  if (!g.length || !/02|03/.test(g.map((x) => x.msg).join(' '))) {
    console.error(`furo não detectado ou não nomeado: ${JSON.stringify(g)}`); process.exit(1);
  }
  if (!g.every((x) => x.enforceable === false)) { console.error('furo deveria apenas avisar'); process.exit(1); }
})();
EOF
echo "OK [6]"

# ── [7] SRF-01 cobertura de superfície ───────────────────────────────────────────────────────
echo "[7] SRF-01 — REQ cuja superfície é endpoint e cujas tasks não produzem superfície"
node - "$LIB" <<'EOF' || { echo "FAIL [7]: SRF-01 não reproduz o defeito"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const G = await import(pathToFileURL(join(process.argv[2], 'tasks-graph.mjs')).href);
  // a forma exata do defeito real: o Checklist declara "endpoint no orquestrador" e as quatro
  // tasks que o cobrem são lógica, contrato e tela — nenhuma produz rota
  const tasks = [
    '## Wave 4 — quarta', '',
    '- [ ] TASK-27 — aplica a política de liberação (rastreia: REQ-05; paths: `src/Core/Policy.cs`; depende: —)',
    '- [ ] TASK-28 — persiste o estado (rastreia: REQ-05; paths: `src/Core/Store.cs`; depende: —)',
    '- [ ] TASK-63 — declara o contrato (rastreia: REQ-05; paths: `contracts/openapi/orchestrator.yaml`; depende: —)',
    '- [ ] TASK-81 — tela de liberação (rastreia: REQ-05; paths: `ui/Release.tsx`; depende: —)',
  ].join('\n');
  const req = [
    '## Checklist de cobertura de superfície', '',
    '| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |',
    '|---|---|---|---|',
    '| REQ-05 | janela de liberação | **endpoint no orquestrador** + tela | TASK-27, TASK-28, TASK-63, TASK-81 |',
  ].join('\n');
  const parsed = G.parseTasks(tasks);
  const rows = G.parseSurfaceChecklist(req);
  if (rows.length !== 1) { console.error(`checklist deu ${rows.length} linhas`); process.exit(1); }
  if (JSON.stringify(rows[0].tasks) !== JSON.stringify(['TASK-27', 'TASK-28', 'TASK-63', 'TASK-81'])) {
    console.error(`tasks da linha: ${JSON.stringify(rows[0].tasks)}`); process.exit(1);
  }
  const f = G.checkSurfaceCoverage(rows, parsed).filter((x) => x.code === 'SRF-01');
  if (f.length !== 1) { console.error(`SRF-01 deu ${f.length} achados: ${JSON.stringify(f)}`); process.exit(1); }
  if (!f[0].msg.includes('REQ-05')) { console.error(`mensagem sem o REQ: ${f[0].msg}`); process.exit(1); }
  // SRF-01 nasce REBAIXÁVEL, e isso é calibração medida, não timidez: no change que motivou o
  // módulo, 4 das 26 linhas disparam sem grafo e 2 com grafo — uma por defeito real (a rota não
  // existe) e outra por `paths:` incompleto numa task que ENTREGOU a rota. Sem oráculo de código
  // (SUR-01, próxima onda) o achado não distingue os dois casos, e bloquear o plano por um erro de
  // declaração é o que faz o adotante desligar o gate. `enforceable: true` é opt-in de quem tiver
  // como confirmar.
  if (f[0].enforceable !== false) { console.error('SRF-01 default deveria ser rebaixável'); process.exit(1); }
  const promoted = G.checkSurfaceCoverage(rows, parsed, { enforceable: true });
  if (promoted[0].enforceable !== true) { console.error('SRF-01 não é promovível a bloqueante'); process.exit(1); }

  // CONTROLE A — basta UMA task com verbo HTTP + path no título para o REQ ficar coberto
  const viaTitle = tasks.replace('TASK-27 — aplica a política de liberação', 'TASK-27 — POST /internal/v1/orchestrator/release');
  if (G.checkSurfaceCoverage(rows, G.parseTasks(viaTitle)).length) {
    console.error('verbo HTTP + path no título não contou como superfície'); process.exit(1);
  }
  // CONTROLE B — ou uma task cujo `paths:` cai num node layer:api do grafo. É o caso da TASK-56
  // do repo real: entregou endpoint declarando paths só no projeto de domínio, com a rota nascendo
  // noutro assembly. O veredito é POR REQ justamente para sobreviver a isso.
  const apiPaths = ['src/Core/Store.cs'];
  if (G.checkSurfaceCoverage(rows, parsed, { apiPaths }).length) {
    console.error('paths em layer:api não contou como superfície'); process.exit(1);
  }
  // CONTROLE C — linha cuja superfície NÃO é endpoint/API não é assunto do SRF-01
  const uiOnly = req.replace('**endpoint no orquestrador** + tela', 'tela Configurações');
  if (G.checkSurfaceCoverage(G.parseSurfaceChecklist(uiOnly), parsed).length) {
    console.error('SRF-01 acusou linha sem superfície de API'); process.exit(1);
  }
  // CONTROLE D — o esqueleto do template (placeholders <...>) não é linha preenchida
  const skeleton = [
    '## Checklist de cobertura de superfície', '',
    '| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |',
    '|---|---|---|---|',
    '| REQ-01 | <nome do parâmetro> | <ex.: `PATCH /settings`, tela Configurações, `--flag`> | TASK-NN |',
  ].join('\n');
  if (G.parseSurfaceChecklist(skeleton).length) { console.error('placeholder do template virou linha'); process.exit(1); }
})();
EOF
echo "OK [7]"

# ── [8] PBT: TSK-03 acusa se e somente se ───────────────────────────────────────────────────
echo "[8] PBT — TSK-03 acusa se e somente se existe aresta para wave posterior"
node - "$LIB" <<'EOF' || { echo "FAIL [8]: propriedade do TSK-03 falhou"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const lib = process.argv[2];
  const P = await import(pathToFileURL(join(lib, 'pbt.mjs')).href);
  const G = await import(pathToFileURL(join(lib, 'tasks-graph.mjs')).href);

  // monta markdown de N tasks distribuídas em W waves, com uma aresta por task
  function render(n, w, offsets) {
    const waveOf = (i) => Math.min(w - 1, Math.floor((i * w) / n));
    const lines = [];
    let cur = -1;
    for (let i = 0; i < n; i++) {
      const wv = waveOf(i);
      if (wv !== cur) { cur = wv; lines.push('', `## Wave ${wv + 1} — onda ${wv + 1}`, ''); }
      const target = offsets[i] === 0 ? null : ((i + offsets[i] + n) % n);
      const dep = target === null || target === i ? '—' : `TASK-${String(target + 1).padStart(2, '0')}`;
      lines.push(`- [ ] TASK-${String(i + 1).padStart(2, '0')} — t${i} (rastreia: REQ-01; paths: \`p${i}\`; depende: ${dep})`);
    }
    return { md: lines.join('\n'), waveOf };
  }

  let violating = 0, clean = 0;
  const r = P.forAll([P.gen.int(3, 24), P.gen.int(1, 5), P.gen.array(P.gen.int(-3, 3), 24, 24)], (n, w, offs) => {
    const { md, waveOf } = render(n, w, offs);
    const parsed = G.parseTasks(md);
    if (parsed.tasks.length !== n) return false;   // o gerador tem que produzir o que promete
    // oráculo independente do código sob teste: existe aresta cujo alvo está em wave maior?
    let expected = false;
    for (const t of parsed.tasks) {
      for (const d of t.dependsOn) {
        const idx = Number(d.slice(5)) - 1;
        if (waveOf(idx) > waveOf(t.n - 1)) expected = true;
      }
    }
    if (expected) violating++; else clean++;
    const got = G.checkTasksGraph(parsed).some((x) => x.code === 'TSK-03');
    return got === expected;
  }, { runs: 300, seed: 31 });
  if (!r.ok) { console.error('contraexemplo: ' + JSON.stringify(r.counterexample)); process.exit(1); }
  // asserção sobre o PRÓPRIO GERADOR: se ele só produzisse um dos lados, a propriedade acima
  // passaria trivialmente (é a lição do shuffle que não embaralhava)
  if (violating < 20 || clean < 20) {
    console.error(`gerador degenerado: ${violating} casos violadores, ${clean} limpos`); process.exit(1);
  }
})();
EOF
echo "OK [8]"

# ── [9] PBT: parser idempotente e insensível a espaçamento ──────────────────────────────────
echo "[9] PBT — parser idempotente e insensível a espaçamento"
node - "$LIB" <<'EOF' || { echo "FAIL [9]: parser não é estável"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const lib = process.argv[2];
  const P = await import(pathToFileURL(join(lib, 'pbt.mjs')).href);
  const G = await import(pathToFileURL(join(lib, 'tasks-graph.mjs')).href);
  const pad = P.gen.oneOf(['', ' ', '  ', '\t']);
  const r = P.forAll([P.gen.array(P.gen.record({
    n: P.gen.int(1, 40), sp1: pad, sp2: pad, sp3: pad, dash: P.gen.oneOf(['—', '–', '-']),
  }), 1, 12)], (rows) => {
    const seen = new Set(); const lines = ['## Wave 1 — w', ''];
    const canon = ['## Wave 1 — w', ''];
    for (const row of rows) {
      if (seen.has(row.n)) continue; seen.add(row.n);
      const id = `TASK-${String(row.n).padStart(2, '0')}`;
      lines.push(`${row.sp1}-${row.sp2}[ ]${row.sp3}${id} ${row.dash} título (rastreia: REQ-01; paths: \`p\`; depende: —)`);
      canon.push(`- [ ] ${id} — título (rastreia: REQ-01; paths: \`p\`; depende: —)`);
    }
    const a = G.parseTasks(lines.join('\n')).tasks;
    const b = G.parseTasks(canon.join('\n')).tasks;
    if (a.length !== b.length || a.length !== seen.size) return false;
    // idempotência: reparsear o mesmo texto dá exatamente o mesmo resultado
    const again = G.parseTasks(lines.join('\n')).tasks;
    if (JSON.stringify(a) !== JSON.stringify(again)) return false;
    // insensibilidade a espaçamento: id/n/status/título/deps iguais aos da forma canônica
    return a.every((t, i) => t.id === b[i].id && t.n === b[i].n && t.status === b[i].status
      && t.title === b[i].title && JSON.stringify(t.dependsOn) === JSON.stringify(b[i].dependsOn));
  }, { runs: 300, seed: 37 });
  if (!r.ok) { console.error('contraexemplo: ' + JSON.stringify(r.counterexample)); process.exit(1); }
})();
EOF
echo "OK [9]"

# ── [10] REPRODUÇÃO contra evidência congelada do repositório real ───────────────────────────
echo "[10] REPRODUÇÃO — fixture congelado do repositório real"
[ -f "$FIX/tasks-real.md" ] || { echo "FAIL [10]: fixture $FIX/tasks-real.md ausente (pré-requisito faltando reprova)"; exit 1; }
[ -f "$FIX/requirements-real.md" ] || { echo "FAIL [10]: fixture $FIX/requirements-real.md ausente"; exit 1; }
node - "$LIB" "$FIX" <<'EOF' || { echo "FAIL [10]: não reproduziu os defeitos reais"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url'); const fs = require('fs');
(async () => {
  const [lib, fix] = process.argv.slice(2);
  const G = await import(pathToFileURL(join(lib, 'tasks-graph.mjs')).href);
  const tasks = fs.readFileSync(join(fix, 'tasks-real.md'), 'utf8');
  const req = fs.readFileSync(join(fix, 'requirements-real.md'), 'utf8');
  const parsed = G.parseTasks(tasks);
  if (parsed.tasks.length !== 89) { console.error(`parseou ${parsed.tasks.length} tasks, esperado 89`); process.exit(1); }
  const f = G.checkTasksGraph(parsed);
  // exatamente 1 achado, e é a dependência de Wave 4 para Wave 7
  const t3 = f.filter((x) => x.code === 'TSK-03');
  if (t3.length !== 1) { console.error(`TSK-03 deu ${t3.length}: ${JSON.stringify(t3)}`); process.exit(1); }
  if (!t3[0].msg.includes('TASK-89') || !t3[0].msg.includes('TASK-45')) {
    console.error(`achado errado: ${t3[0].msg}`); process.exit(1);
  }
  // e nada de pendurada/ciclo/furo/duplicata no plano real
  const others = f.filter((x) => x.code !== 'TSK-03');
  if (others.length) { console.error(`achados espúrios no plano real: ${JSON.stringify(others)}`); process.exit(1); }
  // SRF-01: a linha REQ-05 do Checklist real reprova sem editar nada — é a prova do defeito.
  const rows = G.parseSurfaceChecklist(req);
  // 27 linhas: REQ-01..REQ-25 mais REQ-28 e REQ-29 (a tabela real salta REQ-26 e REQ-27)
  if (rows.length !== 27) { console.error(`checklist real deu ${rows.length} linhas, esperado 27`); process.exit(1); }
  const srf = G.checkSurfaceCoverage(rows, parsed).filter((x) => x.code === 'SRF-01');
  if (!srf.some((x) => x.msg.includes('REQ-05'))) {
    console.error(`SRF-01 não pegou o REQ-05: ${JSON.stringify(srf)}`); process.exit(1);
  }
  // CALIBRAÇÃO, congelada como número: sem grafo, 5 linhas nomeiam endpoint e 4 disparam (a do
  // REQ-08 fica verde porque uma das tasks declara `paths:` num projeto `.Api`). Se um refinamento
  // futuro do oráculo mudar esses números, é aqui que se descobre — em vez de o gate virar ruído
  // silenciosamente.
  if (srf.length !== 4) { console.error(`SRF-01 deu ${srf.length} achados, calibração esperava 4: ${srf.map((x) => x.msg).join(' | ')}`); process.exit(1); }
  // Com o grafo de código informando os nodes layer:api, cai para 2: o REQ-05 (rota que não existe)
  // e o REQ-25 (rota que existe, declarada em task cujo `paths:` aponta só o projeto de domínio).
  const apiPaths = [
    'backend/Acme.Configs/src/Acme.Configs.Api/Endpoints/PartitionsEndpoints.cs',
    'backend/Acme.Transport/src/Acme.Transport.Api/Orchestrator/OrchestratorEndpoints.cs',
  ];
  const withGraph = G.checkSurfaceCoverage(rows, parsed, { apiPaths });
  if (withGraph.length !== 2 || !withGraph.every((x) => /REQ-05|REQ-25/.test(x.msg))) {
    console.error(`com grafo esperava 2 achados (REQ-05, REQ-25), veio: ${withGraph.map((x) => x.msg).join(' | ')}`); process.exit(1);
  }
})();
EOF
echo "OK [10]"

# ── [11] FIAÇÃO no lifecycle: validate-spec reprova ─────────────────────────────────────────
echo "[11] FIAÇÃO — validate-spec reprova a transição a tasks-ready com grafo quebrado"
CH="$T/change"
mkdir -p "$CH"
cat > "$CH/manifest.yaml" <<'MANIFEST'
id: change
type: feature
mode: feature-only
rigor: spec-first
scale: 2
status: tasks-ready
created_at: 2026-07-29
updated_at: 2026-07-29
owner: milton
gates:
  requirements_reviewed: true
  design_reviewed: true
  tasks_reviewed: false
  implementation_verified: false
  human_archive_approval: false
MANIFEST
printf '# Proposal\n\n## 1. Por quê\n\ntexto\n\n## 2. O que muda\n\ntexto\n' > "$CH/proposal.md"
printf '# Design\n\ntexto\n' > "$CH/design.md"
cat > "$CH/requirements.md" <<'EOF'
# Requirements

## REQ-01 — algo

Critérios de aceite: dado x, quando y, então z.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | janela | endpoint no orquestrador | TASK-01 |
EOF
cat > "$CH/tasks.md" <<'TASKS'
# Tasks

## Wave 1 — base

- [ ] TASK-01 — aplica a política (rastreia: REQ-01; paths: `src/Core/Policy.cs`; depende: TASK-02)

## Wave 2 — depois

- [ ] TASK-02 — persiste (rastreia: REQ-01; paths: `src/Core/Store.cs`; depende: —)
TASKS
out="$(node "$LIB/validate-spec.mjs" "$CH" 2>&1 || true)"
case "$out" in
  *FAIL*) : ;;
  *) echo "FAIL [11]: validate-spec passou com dependência para wave posterior: $out"; exit 1 ;;
esac
grep -q 'TSK-03' <<< "$out" || { echo "FAIL [11]: validate-spec não reportou TSK-03: $out"; exit 1; }
# SRF-01 é rebaixável: aparece como WARN e NÃO entra no FAIL — se entrasse, o achado de calibração
# do REQ-25 (task que entregou a rota com `paths:` incompleto) travaria o plano de quem o corrigiu.
grep -q 'WARN.*SRF-01' <<< "$out" || { echo "FAIL [11]: SRF-01 não saiu como WARN: $out"; exit 1; }

# CONTROLE: corrigida SÓ a dependência (o SRF-01 continua apontando), validate-spec volta a passar.
# Sem este controle, o vermelho acima poderia vir de qualquer outra regra do validador.
cat > "$CH/tasks.md" <<'TASKS'
# Tasks

## Wave 1 — base

- [ ] TASK-01 — aplica a política (rastreia: REQ-01; paths: `src/Core/Policy.cs`; depende: —)

## Wave 2 — depois

- [ ] TASK-02 — persiste (rastreia: REQ-01; paths: `src/Core/Store.cs`; depende: TASK-01)
TASKS
out2="$(node "$LIB/validate-spec.mjs" "$CH" 2>&1 || true)"
grep -q '^OK change' <<< "$out2" || { echo "FAIL [11] CONTROLE: validate-spec reprovou o change com grafo válido: $out2"; exit 1; }
grep -q 'WARN.*SRF-01' <<< "$out2" || { echo "FAIL [11] CONTROLE: o WARN de SRF-01 desapareceu junto: $out2"; exit 1; }
echo "OK [11]"

# ── [12] ROBUSTEZ: o parser não desliga em silêncio ─────────────────────────────────────────
# A pior falha possível num gate é o falso negativo silencioso — e um parser que exige uma forma
# exata produz exatamente isso: muda a ordem dos campos e o grafo fica sem arestas, logo sem
# defeitos. Cada caso abaixo é uma forma de escrever a MESMA linha, e todas têm que dar o mesmo
# grafo. É a regra da casa aplicada ao parser: pré-requisito ausente reprova, nunca silencia.
echo "[12] ROBUSTEZ — variações de escrita não desligam a verificação"
node - "$LIB" <<'EOF' || { echo "FAIL [12]: variação de escrita desligou a verificação"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const G = await import(pathToFileURL(join(process.argv[2], 'tasks-graph.mjs')).href);
  const W = '## Wave 1 — a\n';
  const variants = {
    'canônica':            '- [ ] TASK-01 — t (rastreia: REQ-01; paths: `a`; depende: TASK-02)',
    'ordem trocada':       '- [ ] TASK-01 — t (depende: TASK-02; rastreia: REQ-01; paths: `a`)',
    'sem rastreia':        '- [ ] TASK-01 — t (paths: `a`; depende: TASK-02)',
    'espaço após (':       '- [ ] TASK-01 — t ( rastreia: REQ-01; depende: TASK-02)',
    'sufixo após )':       '- [ ] TASK-01 — t (rastreia: REQ-01; depende: TASK-02) <!-- nota -->',
    'chave acentuada':     '- [ ] TASK-01 — t (rastreia: REQ-01; dependências: TASK-02)',
    'sem parênteses':      '- [ ] TASK-01 — t · rastreia: REQ-01; depende: TASK-02',
    'bullet asterisco':    '* [ ] TASK-01 — t (rastreia: REQ-01; depende: TASK-02)',
  };
  for (const [nome, linha] of Object.entries(variants)) {
    const t = G.parseTasks(W + linha).tasks;
    if (t.length !== 1) { console.error(`[${nome}] parseou ${t.length} tasks`); process.exit(1); }
    if (JSON.stringify(t[0].dependsOn) !== JSON.stringify(['TASK-02'])) {
      console.error(`[${nome}] dependsOn = ${JSON.stringify(t[0].dependsOn)} — a aresta desapareceu, e com ela TSK-01/02/03`);
      process.exit(1);
    }
    if (t[0].title !== 't') { console.error(`[${nome}] título = "${t[0].title}"`); process.exit(1); }
  }
  // cabeçalho de wave em h1 e com negrito — formas que aparecem em markdown escrito à mão
  for (const head of ['# Wave 1 — a', '## **Wave 1** — a', '### Wave 1: a']) {
    const p = G.parseTasks(`${head}\n- [ ] TASK-01 — t (rastreia: R; depende: —)`);
    if (p.waves.length !== 1 || p.tasks[0].wave !== 1) {
      console.error(`cabeçalho "${head}" não reconhecido: waves=${p.waves.length} wave=${p.tasks[0].wave}`); process.exit(1);
    }
  }
  // TSK-05: sem NENHUMA wave reconhecível, a ordem topológica não é verificável — e isso tem que
  // ser DITO, não silenciado. Um gate que não rodou é indistinguível de um gate que passou.
  const noWave = G.parseTasks('- [ ] TASK-01 — t (rastreia: R; depende: TASK-02)\n- [ ] TASK-02 — u (rastreia: R; depende: —)');
  const f5 = G.checkTasksGraph(noWave).filter((x) => x.code === 'TSK-05');
  if (f5.length !== 1) { console.error(`TSK-05 não avisou que não conseguiu verificar: ${JSON.stringify(G.checkTasksGraph(noWave))}`); process.exit(1); }
  // e com waves presentes, TSK-05 fica calado
  if (G.checkTasksGraph(G.parseTasks('## Wave 1 — a\n- [ ] TASK-01 — t (rastreia: R; depende: —)')).some((x) => x.code === 'TSK-05')) {
    console.error('TSK-05 disparou com wave presente'); process.exit(1);
  }
})();
EOF
echo "OK [12]"

# ── [13] CALIBRAÇÃO de producesSurface e namesApiSurface ────────────────────────────────────
echo "[13] CALIBRAÇÃO — o oráculo de superfície não é largo nem cego"
node - "$LIB" <<'EOF' || { echo "FAIL [13]: oráculo de superfície mal calibrado"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const G = await import(pathToFileURL(join(process.argv[2], 'tasks-graph.mjs')).href);
  const ps = (p, title = '') => G.producesSurface({ paths: [p], title });
  // NÃO produzem rota HTTP. `frontend/web/` era o caso decisivo: aceitá-lo mascara justamente o
  // defeito que o SRF-01 existe para achar — um REQ que promete endpoint coberto só por tela.
  for (const p of ['frontend/web/src/Lista.tsx', 'docs/http/notas.md', 'src/Core/Store.api.test.cs',
    'tests/api/Contract.cs', 'contracts/api/v1.yaml', 'ui/views/Home.tsx']) {
    if (ps(p)) { console.error(`"${p}" contado como produtor de rota HTTP`); process.exit(1); }
  }
  // produzem
  for (const p of ['backend/Acme.Transport.Api/Endpoints/X.cs', 'src/api/routes.ts',
    'app/controllers/users_controller.rb', 'srv/Acme.Web/Program.cs']) {
    if (!ps(p)) { console.error(`"${p}" NÃO contado como produtor de rota HTTP`); process.exit(1); }
  }
  if (!ps('src/Core/Policy.cs', 'POST /v1/itens')) { console.error('verbo+path no título ignorado'); process.exit(1); }

  // polaridade: o template de requirements INSTRUI a escrever a negação explícita em vez de omitir
  // a linha, então "sem endpoint" é a forma que o próprio harness pede — e não pode gerar achado.
  for (const s of ['sem endpoint; apenas `--flag` de CLI', 'n/a — não expõe rota nem tela',
    'sem parâmetro exposto', 'tela Configurações', '`contracts/openapi/` e `contracts/asyncapi/`',
    '`acme-configs-api.v1.yaml`; tela Configurações']) {
    if (G.namesApiSurface(s)) { console.error(`"${s}" tratado como superfície de endpoint`); process.exit(1); }
  }
  for (const s of ['endpoint no **orquestrador**', '`GET/POST /api/v1/x`, tela', 'rota de export no orquestrador']) {
    if (!G.namesApiSurface(s)) { console.error(`"${s}" NÃO tratado como superfície de endpoint`); process.exit(1); }
  }
})();
EOF
echo "OK [13]"

# ── [14] Checklist: conteúdo legítimo não vira esqueleto, e o não-verificável é dito ─────────
echo "[14] Checklist — rota parametrizada, título com sufixo, segunda tabela, seção ausente"
node - "$LIB" <<'EOF' || { echo "FAIL [14]: parser do Checklist descarta conteúdo legítimo"; exit 1; }
const { join } = require('path'); const { pathToFileURL } = require('url');
(async () => {
  const G = await import(pathToFileURL(join(process.argv[2], 'tasks-graph.mjs')).href);
  const HEAD = '| REQ | Parâmetro | Superfície | Coberto por task |\n|---|---|---|---|\n';
  // rota parametrizada com <id> é conteúdo LEGÍTIMO — descartá-la como placeholder de template
  // desliga o SRF-01 inteiro numa tabela cujas linhas todas citem rota parametrizada
  let rows = G.parseSurfaceChecklist(`## Checklist de cobertura de superfície\n\n${HEAD}| REQ-01 | j | endpoint \`GET /v1/x/<id>\` | TASK-01 |`);
  if (rows.length !== 1) { console.error(`rota com <id> descartada: ${rows.length} linhas`); process.exit(1); }
  // título de seção com sufixo continua sendo a seção
  rows = G.parseSurfaceChecklist(`## Checklist de cobertura de superfície (obrigatório)\n\n${HEAD}| REQ-01 | j | endpoint | TASK-01 |`);
  if (rows.length !== 1) { console.error('título com sufixo desligou o parser'); process.exit(1); }
  // o esqueleto do template continua sendo descartado — é o `TASK-NN` literal que o denuncia
  rows = G.parseSurfaceChecklist(`## Checklist de cobertura de superfície\n\n${HEAD}| REQ-01 | <nome do parâmetro> | <ex.: \`PATCH /settings\`> | TASK-NN |`);
  if (rows.length) { console.error('esqueleto do template virou linha de dados'); process.exit(1); }
  // segunda tabela na mesma seção: o cabeçalho dela não pode virar linha de dados
  rows = G.parseSurfaceChecklist([`## Checklist de cobertura de superfície`, '',
    HEAD.trimEnd(), '| REQ-01 | j | endpoint | TASK-01 |', '', 'prosa entre tabelas', '',
    '| REQ | Parâmetro | Superfície (tela/endpoint/CLI) | Coberto por task |', '|---|---|---|---|',
    '| REQ-02 | k | tela | TASK-02 |'].join('\n'));
  if (rows.length !== 2 || rows.some((r) => !/^REQ-[0-9]+$/.test(r.req))) {
    console.error(`segunda tabela mal parseada: ${JSON.stringify(rows.map((r) => r.req))}`); process.exit(1);
  }
  // seção AUSENTE num requirements com REQs: não verificável, e tem que ser dito (SRF-02)
  const parsed = G.parseTasks('## Wave 1 — a\n- [ ] TASK-01 — t (rastreia: REQ-01; depende: —)');
  const f = G.checkSurfaceChecklistPresence('# Requirements\n\n## REQ-01 — algo\n');
  if (!f.some((x) => x.code === 'SRF-02')) { console.error(`seção ausente não foi reportada: ${JSON.stringify(f)}`); process.exit(1); }
  if (G.checkSurfaceChecklistPresence(`## Checklist de cobertura de superfície\n\n${HEAD}| REQ-01 | j | endpoint | TASK-01 |`).length) {
    console.error('SRF-02 disparou com a seção presente'); process.exit(1);
  }
})();
EOF
echo "OK [14]"

# ── [15] apiPaths vem do graph.json de verdade ──────────────────────────────────────────────
# A única fonte de `apiPaths` em produção é `apiLayerPaths()` no validate-spec, lendo
# `.forge/graph/graph.json`. Sem esta asserção, essa linha nunca roda em teste — e é ela que
# transforma dois falsos positivos em silêncio no change real.
echo "[15] FIAÇÃO — o grafo de código alimenta o SRF-01 em produção"
G="$T/graphed"
mkdir -p "$G/.forge/graph" "$G/.forge/specs/active/graphed"
CG="$G/.forge/specs/active/graphed"
cat > "$G/.forge/graph/graph.json" <<'GRAPH'
{"nodes":[{"id":"backend/Acme.Configs/src/Acme.Configs.Api/Endpoints/P.cs","layer":"api"},
          {"id":"backend/Acme.Core/Store.cs","layer":"domain"}],"edges":[]}
GRAPH
sed 's/^id: change$/id: graphed/' "$CH/manifest.yaml" > "$CG/manifest.yaml"
cp "$CH/proposal.md" "$CH/design.md" "$CG/"
cat > "$CG/requirements.md" <<'REQ'
# Requirements

## REQ-01 — algo

Critérios de aceite: dado x, quando y, então z.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | janela | endpoint no orquestrador | TASK-01 |
REQ
# a task declara o DIRETÓRIO do projeto; é o grafo que sabe que dentro dele nasce rota
cat > "$CG/tasks.md" <<'TASKS'
# Tasks

## Wave 1 — base

- [ ] TASK-01 — registro de partições (rastreia: REQ-01; paths: `backend/Acme.Configs/`; depende: —)
TASKS
out3="$(FORGE_ROOT="$G" node "$LIB/validate-spec.mjs" "$CG" 2>&1 || true)"
grep -q '^OK graphed' <<< "$out3" || { echo "FAIL [15]: validate-spec reprovou o change: $out3"; exit 1; }
grep -q 'SRF-01' <<< "$out3" && { echo "FAIL [15]: o grafo layer:api não silenciou o SRF-01: $out3"; exit 1; }
# CONTROLE: sem o graph.json, o mesmo change gera o WARN — prova que foi o grafo que decidiu, e
# não a heurística de nome de path aceitando `Acme.Configs/` por conta própria
rm "$G/.forge/graph/graph.json"
out4="$(FORGE_ROOT="$G" node "$LIB/validate-spec.mjs" "$CG" 2>&1 || true)"
grep -q 'WARN.*SRF-01' <<< "$out4" || { echo "FAIL [15] CONTROLE: sem grafo o SRF-01 deveria avisar: $out4"; exit 1; }
echo "OK [15]"

echo "PASS w130-tasks-graph-gate"
