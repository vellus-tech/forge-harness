#!/usr/bin/env bash
# Gate W250 — especialistas de dados: orquestrador data-engineer, seis especialistas consultivos, seis skills
# data-*-practices com scan.sh determinístico, e os dois hooks que restringem o que eles podem acionar e executar
# (change data-engineer-agent, issue #177).
#
# POR QUE ESTE GATE EXISTE. O change entrega conteúdo (agentes e referências) e maquinaria (seis scanners e dois
# scripts de hook). Conteúdo sem verificação apodrece em silêncio: um especialista que perde a seção do protocolo,
# um catálogo com antipattern sem correção, uma recomendação refutada que volta ao texto. Maquinaria sem prova pelo
# canal é pior: um hook de frontmatter cujo script falta deixa passar tudo (no Claude Code só o exit 2 bloqueia). Este
# gate cobre as duas coisas, e cada cenário é uma função `confere_* <raiz>` para que a prova de mutação rode sobre
# cópia em diretório temporário, nunca sobre arquivo rastreado.
#
# ORDINAL. w250 é exceção registrada à regra do `gate-ordinal.sh next` (design D-12 do change): o `next` devolvia
# w239, já disputado por duas frentes, e w240–w248 estão reservados ou ocupados.
#
# CENÁRIOS (design §2.6 do change; [20] é acréscimo da implementação, ver abaixo):
#   [0]  universo — sete agentes em agents/data/ e seis skills data-*-practices, via lib/gate-universe.sh.
#   [1]  frontmatter — validate-frontmatter.sh --strict-xml e parse YAML (pacote `yaml`) com `description`.
#   [2]  roteamento — lista do Agent(...) = seis especialistas; hook PreToolUse Agent|Task com `|| exit 2`; matriz.
#   [3]  especialistas — skills, model, tools sem Write/Edit/Agent, context7 atual, hook de Bash, seções, protocolo.
#   [4]  skills — três arquivos + scan.sh, SKILL.md ≤ 120 linhas, catálogo com cinco rótulos, ids no conjunto fechado.
#   [5]  bijeção — ids `Detecção: scan.sh <ID>` = ids emitidos pelo scanner = tabela de regras estáticas do design.
#   [6]  detecção — suja acha cada regra no próprio diretório, limpa não acha nada, determinismo, códigos de saída,
#        contrato de CLI (--root repetível, --json), isolamento de rede e de dependência (PATH reduzido).
#   [7]  portabilidade — rg × grep byte-idênticos com arquivo oculto, ignorado e com byte de controle; worktrees
#        aninhados fora do universo e do contador.
#   [8]  contador — universo vazio dá NADA-EXAMINADO e exit 3.
#   [9]  RabbitMQ — treze subseções, ids contíguos, oito fatos de plataforma com [J].
#   [10] integração — frase canônica, regra da URL pré-assinada (H-02 a), tabela de transporte, checklist transversal.
#   [11] refutados — nenhuma recomendação refutada ou obsoleta fora do catálogo de antipatterns.
#   [12] fiação — README de agentes, templates/AGENTS.md, PROFILE.md, contrato C5, plugin sem data-*; dispatcher e
#        revisores em modo PENDENTE enquanto a frente evals-100 não estiver mergeada (ver FIACAO_EVALS100).
#   [13] projeção — instalação real com --adapters claude,agents-skills.
#   [14] mutação — sete mutações sobre cópia, com controle, recontrole e restauração conferida por cmp -s.
#   [15] evals — sete evals.json no formato skill-creator adotado pela frente evals-100.
#   [16] hook de allowlist — pelo alvo e pelo canal (sh -c do comando extraído do frontmatter), com e sem o script.
#   [17] conflito com rule — bloco CONFLITO nos sete, sem "registra e segue", money-as-cents, Redis nunca verdade.
#   [18] guarda de Bash — pelo alvo e pelo canal, dois aceitos e ao menos doze negados.
#   [19] forge update — instalação sem os arquivos de dados recebe tudo de volta, byte-idêntico, e projeta.
#   [20] PBT (acréscimo) — guarda de Bash e allowlist contra oráculo independente, semente registrada, 80 casos.
#
# REFINAMENTOS REGISTRADOS em relação ao texto do design, todos na direção de mais rigor e explicados no cenário:
#   - [6] isolamento: a proibição de `node` e de `KAFKA_` no texto do scanner é lida como INVOCAÇÃO de node e
#     LEITURA de variável de conexão (`$KAFKA_...`), porque o filtro de diretório precisa citar `node_modules` e a
#     regra KFK-AP-09 precisa casar o literal `KAFKA_LISTENERS` em compose.
#   - [7] o motor rg recebe também `--no-unicode` e `--no-config`: sem o primeiro, `[^,]` não casa byte UTF-8
#     inválido no rg e casa no grep (medido); sem o segundo, um RIPGREP_CONFIG_PATH do operador muda a saída.
#   - [20] PBT não estava no design (que declarava "não se aplica"); o guarda e a allowlist são decisões binárias
#     sobre texto livre, exatamente onde uma propriedade diferencial contra oráculo independente acha o que exemplo
#     escolhido à mão não acha.
#
# DEPENDÊNCIAS. Sem o pacote `yaml` ([1]-[3]) ou sem `rg` ([7]) o cenário imprime NAO-VERIFICADO e o gate sai 127,
# que o `classificar` do run-all.sh lê como "não verificado (dependência ausente)"; nunca aprova. FAIL domina: com
# qualquer FAIL o gate sai 1.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$WS/template/.forge"
FIX_REL="tests/fixtures/w250"
ESPS="data-relational data-nosql data-cache data-object-storage data-analytical data-streaming"
ORQ="data-engineer"
AGENTES="$ORQ $ESPS"

# Fiação condicionada ao merge da frente evals-100 (design §2.8; TASK-12 e TASK-13 do change). Enquanto `pendente`,
# o [12] exige o CONTRÁRIO da fiação nesses seis arquivos: que ainda não citem data-engineer nem data-*-practices,
# porque editá-los antes do merge invalida a medição da outra frente. Vira `ativa` na mesma PR que aplica a TASK-12/13.
FIACAO_EVALS100="pendente"

# Campos do formato de evals (skill-creator, como a frente evals-100 grava em .forge/evals/agents/*/evals.json,
# observado em 2026-09-26). Reconferir depois do merge da evals-100 (TASK-16) e ajustar AQUI se divergir.
EVALS_CAMPOS_TOPO="skill_name artifact_kind artifact_path evals"
EVALS_CAMPOS_CASO="id eval_name prompt expected_output files assertions"

REGRA_INTEGRACAO_TEXTO='a resposta não expõe gRPC a terceiro; não dá a terceiro credencial, rota de rede ou permissão sobre banco, cache, tópico, fila, vhost ou bucket internos; não entrega dado a terceiro por meio que não seja REST ou fila/tópico dedicado nos termos do §2.4 (reprova GraphQL público, SFTP, CDC ou tópico interno compartilhado, e URL pré-assinada fora das restrições do §2.4: HTTPS, objeto único nomeado, expiração em minutos, emissão por endpoint REST autenticado do produto com log de emissão, bucket privado); não propõe REST síncrono entre serviços internos sem ADR; e não propõe evento interno sem contrato AsyncAPI'

FRASE_CANONICA='Comunicação síncrona interna entre serviços é gRPC por padrão, com contrato `.proto` versionado; evento assíncrono interno vai por mensageria, com contrato AsyncAPI e schema registrado; comunicação externa é REST (síncrona) ou fila/mensageria (assíncrona); gRPC nunca é exposto a terceiros, e nenhum terceiro recebe credencial, rota de rede ou permissão sobre banco, cache, tópico, fila, vhost ou bucket internos; toda exceção exige ADR.'

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/w250.XXXXXX")" || { echo "FAIL (mktemp)"; exit 1; }
trap 'rm -rf "$TMPD"' EXIT

FALHAS=0
NAOVERIF=0
PENDENTES=""

command -v node >/dev/null 2>&1 || { echo "NAO-VERIFICADO node ausente — o gate inteiro depende dele"; exit 127; }

# ── resolução do pacote yaml (devDependency) ────────────────────────────────────────────────────────────────────────
# node_modules do próprio checkout; em worktree sem node_modules, o do checkout principal (pai do git-common-dir).
YAML_MOD=""
for cand in "$WS/node_modules" \
            "$(dirname "$(git -C "$WS" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo /nao-existe/.git)")/node_modules"; do
  if [ -f "$cand/yaml/package.json" ]; then YAML_MOD="$cand/yaml"; break; fi
done

# ── tabelas do design (§2.5) ────────────────────────────────────────────────────────────────────────────────────────
# regras_estaticas <esp> — "ID severidade" de cada regra que o scan.sh da skill executa.
regras_estaticas() {
  case "$1" in
    data-relational) printf '%s\n' "R-03 alto" "R-04 aviso" "R-06 aviso" "R-10 alto" "R-12 aviso" "R-13 alto" "R-14 aviso" \
                       "R-17 aviso" "R-18 aviso" "R-19 aviso" "R-20 aviso" "R-21 aviso" ;;
    data-nosql) printf '%s\n' "N-01 aviso" "N-04 aviso" "N-06 aviso" "N-07 alto" "N-08 aviso" "N-09 aviso" "N-10 aviso" \
                  "N-11 alto" "N-13 alto" "N-15 aviso" "N-17 aviso" "N-18 aviso" "N-19 aviso" ;;
    data-cache) printf '%s\n' "C-02 aviso" "C-08 aviso" "C-09 aviso" "C-10 alto" "C-11 alto" "C-15 aviso" "C-16 aviso" ;;
    data-object-storage) printf '%s\n' "O-01 alto" "O-02 aviso" "O-08 aviso" "O-11 alto" "O-13 aviso" "O-14 aviso" ;;
    data-analytical) printf '%s\n' "A-06 aviso" "A-08 aviso" "A-10 alto" "A-12 aviso" "A-14 alto" ;;
    data-streaming) printf '%s\n' "RMQ-AP-01 alto" "RMQ-AP-03 aviso" "RMQ-AP-04 aviso" "RMQ-AP-06 alto" "RMQ-AP-07 aviso" \
                      "RMQ-AP-08 aviso" "RMQ-AP-09 aviso" "RMQ-AP-10 alto" "RMQ-AP-12 aviso" "RMQ-AP-14 aviso" \
                      "RMQ-AP-15 aviso" "RMQ-AP-17 alto" "RMQ-AP-18 alto" "RMQ-AP-19 aviso" "RMQ-AP-20 aviso" \
                      "KFK-AP-01 alto" "KFK-AP-02 alto" "KFK-AP-03 aviso" "KFK-AP-06 alto" "KFK-AP-09 aviso" \
                      "KFK-AP-10 aviso" "INB-AP-01 aviso" "INB-AP-02 aviso" "D-AP-01 aviso" "D-AP-02 aviso" \
                      "D-AP-04 aviso" "D-AP-05 aviso" "SCH-AP-01 alto" "T-02 aviso" ;;
  esac
}

# ids_obrigatorios <esp> — conjunto fechado de ids do catálogo (design §2.5): faixas fixas exigidas por completo, mais
# famílias abertas (prefixo) aceitas no streaming. Formato: uma linha "ID" ou "FAMILIA:<prefixo>".
ids_catalogo() {
  local i
  case "$1" in
    data-relational) for i in $(seq 1 21); do printf 'R-%02d\n' "$i"; done ;;
    data-nosql) for i in $(seq 1 19); do printf 'N-%02d\n' "$i"; done ;;
    data-cache) for i in $(seq 1 16); do printf 'C-%02d\n' "$i"; done; echo "T-01"; echo "T-04" ;;
    data-object-storage) for i in $(seq 1 14); do printf 'O-%02d\n' "$i"; done; echo "T-03" ;;
    data-analytical) for i in $(seq 1 14); do printf 'A-%02d\n' "$i"; done ;;
    data-streaming)
      for i in $(seq 1 20); do printf 'RMQ-AP-%02d\n' "$i"; done
      for i in $(seq 1 10); do printf 'KFK-AP-%02d\n' "$i"; done
      for i in $(seq 1 5); do printf 'D-AP-%02d\n' "$i"; done
      echo "T-02"; echo "SCH-AP-01"; echo "INB-AP-01"; echo "INB-AP-02"; echo "OBX-AP-01"; echo "CDC-AP-01"
      echo "FAMILIA:SCH-AP-"; echo "FAMILIA:INB-AP-"; echo "FAMILIA:OBX-AP-"; echo "FAMILIA:CDC-AP-" ;;
  esac
}

# secoes_cobertura <esp> — substrings de heading exigidas em best-practices.md (cobertura mínima da issue, REQ-03).
secoes_cobertura() {
  case "$1" in
    data-relational) printf '%s\n' "Modelagem e normalização" "Chaves e índices" "Migrações reversíveis" "Transações e isolamento" "N+1" "Locks" ;;
    data-nosql) printf '%s\n' "Documento" "Chave-valor" "Coluna larga" "Grafo" "Modelagem por padrão de acesso" "Chave de partição" "Consistência" ;;
    data-cache) printf '%s\n' "Cache-aside" "Write-through" "TTL" "Invalidação" "Stampede" "Chave quente" "Cache como fonte da verdade" ;;
    data-object-storage) printf '%s\n' "Layout de chaves" "Ciclo de vida" "Versionamento" "Criptografia" "URL pré-assinada" "Bucket público" ;;
    data-analytical) printf '%s\n' "Modelagem dimensional" "Warehouse e lakehouse" "Particionamento" "Formatos colunares" "SCD" ;;
    data-streaming) printf '%s\n' "Kafka" "RabbitMQ" "CDC" "Outbox" "Schema registry" "AsyncAPI" ;;
  esac
}

# regra_aviso / regra_alto <esp> — uma regra de cada severidade para os cenários de código de saída do [6].
regra_aviso() { case "$1" in data-relational) echo R-04;; data-nosql) echo N-01;; data-cache) echo C-02;; data-object-storage) echo O-02;; data-analytical) echo A-06;; data-streaming) echo RMQ-AP-03;; esac; }
regra_alto() { case "$1" in data-relational) echo R-03;; data-nosql) echo N-07;; data-cache) echo C-10;; data-object-storage) echo O-01;; data-analytical) echo A-14;; data-streaming) echo RMQ-AP-10;; esac; }
# plantio <esp> — "ID|linha" que o [7] planta em arquivo .yml oculto, ignorado, com byte de controle e em worktrees.
plantio() {
  case "$1" in
    data-relational) echo 'R-17|publicly_accessible: true' ;;
    data-nosql) echo 'N-18|bindIp: 0.0.0.0' ;;
    data-cache) echo 'C-10|maxmemory-policy: noeviction' ;;
    data-object-storage) echo 'O-01|acl: public-read' ;;
    data-analytical) echo 'A-14|invalidate_hard_deletes: true' ;;
    data-streaming) echo 'RMQ-AP-06|ha-mode: all' ;;
  esac
}

# ── helpers node (gravados uma vez) ─────────────────────────────────────────────────────────────────────────────────
cat > "$TMPD/fm.cjs" <<'NODE'
// fm.cjs <modo> <raiz> [args] — checagens de frontmatter e de corpo dos agentes e skills (cenários [1]-[4], [9]-[12], [17]).
// Imprime uma linha "FAIL <mensagem>" por problema, "NAOVERIF <msg>" quando falta dependência; nada quando está limpo.
const fs = require("fs"), path = require("path");
const [modo, raiz, ...args] = process.argv.slice(2);
let Y = null;
try { if (process.env.W250_YAML) Y = require(process.env.W250_YAML); } catch (e) { Y = null; }
const out = [];
const fail = (m) => out.push("FAIL " + m);
const ler = (p) => { try { return fs.readFileSync(p, "utf8"); } catch { return null; } };
const fmTexto = (t) => { const m = /^---\r?\n([\s\S]*?)\r?\n---\r?\n/.exec(t || ""); return m ? m[1] : null; };
const corpo = (t) => { const m = /^---\r?\n[\s\S]*?\r?\n---\r?\n([\s\S]*)$/.exec(t || ""); return m ? m[1] : (t || ""); };
const parseFm = (t) => { const s = fmTexto(t); if (s === null) return { erro: "sem frontmatter" }; if (!Y) return { naoverif: true }; try { return { fm: Y.parse(s) }; } catch (e) { return { erro: "YAML inválido: " + e.message }; } };
const secao = (texto, titulo, nivel = "## ") => {
  const linhas = texto.split("\n"); let dentro = false; const acc = [];
  for (const l of linhas) {
    if (l.startsWith(nivel)) { if (dentro) break; if (l.slice(nivel.length).trim() === titulo) { dentro = true; continue; } }
    else if (dentro && nivel === "### " && l.startsWith("## ")) break;
    if (dentro) acc.push(l);
  }
  return dentro ? acc.join("\n") : null;
};
const headings = (texto, nivel = "## ") => texto.split("\n").filter((l) => l.startsWith(nivel) && !l.startsWith(nivel + "#")).map((l) => l.slice(nivel.length).trim());
const ESPS = ["data-relational", "data-nosql", "data-cache", "data-object-storage", "data-analytical", "data-streaming"];
const ORQ = "data-engineer";
const agentePath = (n) => path.join(raiz, "agents", "data", n + ".md");
const hookCmds = (fm, matcherEsperado) => {
  const pre = fm && fm.hooks && fm.hooks.PreToolUse;
  if (!Array.isArray(pre)) return null;
  const cmds = [];
  for (const g of pre) {
    if (!g || typeof g.matcher !== "string") continue;
    let re; try { re = new RegExp("^(?:" + g.matcher + ")$"); } catch { continue; }
    if (!matcherEsperado.every((t) => re.test(t))) continue;
    for (const h of g.hooks || []) if (h && h.type === "command" && typeof h.command === "string") cmds.push(h.command);
  }
  return cmds;
};
const ESP_SECOES = ["Missão", "Escopo", "Protocolo", "Checklist", "Antipatterns bloqueados", "Regra de integração", "Quando devolver ao orquestrador"];
const ORQ_SECOES = ["Missão", "Taxonomia", "Protocolo", "Checklist transversal", "Regra de integração", "Modo degradado", "Fora da cobertura"];

function ordemSecoes(nome, texto, esperadas) {
  const hs = headings(corpo(texto)).filter((h) => esperadas.includes(h));
  const faltam = esperadas.filter((s) => !hs.includes(s));
  if (faltam.length) fail(`${nome}: seção(ões) ausente(s): ${faltam.join(", ")}`);
  else if (hs.join("|") !== esperadas.join("|")) fail(`${nome}: seções fora da ordem do design (${hs.join(" > ")})`);
}

if (modo === "fm") { // [1]
  const alvos = [ORQ, ...ESPS].map((n) => ["agente " + n, agentePath(n)]).concat(ESPS.map((e) => ["skill " + e + "-practices", path.join(raiz, "skills", e + "-practices", "SKILL.md")]));
  let examinados = 0;
  for (const [rot, p] of alvos) {
    const t = ler(p); if (t === null) { fail(`[1] ${rot}: arquivo ausente (${path.relative(raiz, p)})`); continue; }
    const r = parseFm(t);
    if (r.naoverif) { out.push("NAOVERIF [1] pacote yaml ausente — frontmatter não parseado"); break; }
    if (r.erro) { fail(`[1] ${rot}: ${r.erro}`); continue; }
    examinados++;
    if (!r.fm || typeof r.fm.description !== "string" || !r.fm.description.trim()) fail(`[1] ${rot}: frontmatter sem description`);
    if (!r.fm || typeof r.fm.name !== "string") fail(`[1] ${rot}: frontmatter sem name`);
  }
  console.log(out.join("\n")); if (out.length === 0) console.log("EXAMINADOS " + examinados); process.exit(0);
}

if (modo === "rota") { // [2]
  const t = ler(agentePath(ORQ)); if (t === null) { console.log("FAIL [2] agents/data/data-engineer.md ausente"); process.exit(0); }
  const r = parseFm(t);
  if (r.naoverif) { console.log("NAOVERIF [2] pacote yaml ausente"); process.exit(0); }
  if (r.erro) { console.log("FAIL [2] data-engineer: " + r.erro); process.exit(0); }
  const fm = r.fm || {};
  if (fm.name !== ORQ) fail(`[2] data-engineer: name '${fm.name}' diferente do arquivo`);
  if (typeof fm.model !== "string" || !fm.model) fail("[2] data-engineer: model ausente (herança implícita de modelo é proibida)");
  const tools = Array.isArray(fm.tools) ? fm.tools : [];
  const ag = tools.filter((x) => typeof x === "string" && /^Agent\s*\(/.test(x));
  if (ag.length !== 1) fail("[2] data-engineer: tools precisa de exatamente uma entrada Agent(...)");
  else {
    const lista = ag[0].replace(/^Agent\s*\(/, "").replace(/\)\s*$/, "").split(",").map((s) => s.trim()).filter(Boolean);
    for (const e of ESPS) if (!lista.includes(e)) fail(`[2] data-engineer: Agent(...) sem o especialista ${e}`);
    for (const x of lista) if (!ESPS.includes(x)) fail(`[2] data-engineer: Agent(...) com tipo fora dos seis: ${x}`);
  }
  for (const proib of ["Write", "Edit", "Bash"]) if (tools.includes(proib)) fail(`[2] data-engineer: tools não pode ter ${proib}`);
  const cmds = hookCmds(fm, ["Agent", "Task"]);
  if (!cmds || cmds.length === 0) fail("[2] data-engineer: sem hooks.PreToolUse com matcher que case Agent e Task");
  else if (!cmds.some((c) => c.includes(".forge/scripts/data-agent-allowlist.sh") && /\|\|\s*exit 2\s*$/.test(c))) fail("[2] data-engineer: comando do hook não aponta .forge/scripts/data-agent-allowlist.sh terminando em '|| exit 2'");
  const tax = secao(corpo(t), "Taxonomia");
  if (tax === null) fail("[2] data-engineer: seção Taxonomia ausente");
  else {
    const linhas = tax.split("\n").filter((l) => /^\|/.test(l) && !/^\|\s*-/.test(l));
    const nomes = new Set();
    for (const l of linhas.slice(1)) {
      const cel = l.split("|").map((c) => c.trim()).filter(Boolean); const ult = cel[cel.length - 1] || "";
      for (const m of ult.matchAll(/`(data-[a-z-]+)`/g)) nomes.add(m[1]);
    }
    for (const n of nomes) if (!fs.existsSync(agentePath(n))) fail(`[2] data-engineer: matriz cita '${n}' sem arquivo em agents/data (nome fantasma)`);
    for (const e of ESPS) if (!nomes.has(e)) fail(`[2] data-engineer: especialista ${e} não aparece na matriz sinal → especialista`);
    const nosqlLinha = linhas.find((l) => /`data-nosql`\s*\|?\s*$/.test(l.trim()) && /majority/.test(l));
    if (!nosqlLinha) fail("[2] data-engineer: a linha do data-nosql na matriz não carrega o transacional de negócio com write concern majority (H-01 a)");
    const relLinha = linhas.find((l) => /`data-relational`\s*\|?\s*$/.test(l.trim()) && /ADR/.test(l));
    if (!relLinha) fail("[2] data-engineer: a linha do data-relational na matriz não condiciona o transacional ao ADR que escolheu SQL (H-01 a)");
    const des = secao(tax, "Regras de desempate", "### ");
    const n = des === null ? 0 : des.split("\n").filter((l) => /^\d+\.\s/.test(l)).length;
    if (n !== 8) fail(`[2] data-engineer: esperadas 8 regras de desempate numeradas em '### Regras de desempate', achadas ${n}`);
  }
  console.log(out.join("\n")); process.exit(0);
}

if (modo === "esp") { // [3]
  let naov = false;
  for (const e of ESPS) {
    const t = ler(agentePath(e)); if (t === null) { fail(`[3] agents/data/${e}.md ausente`); continue; }
    const r = parseFm(t);
    if (r.naoverif) { naov = true; } else if (r.erro) { fail(`[3] ${e}: ${r.erro}`); } else {
      const fm = r.fm || {};
      if (fm.name !== e) fail(`[3] ${e}: name '${fm.name}' diferente do arquivo`);
      if (typeof fm.model !== "string" || !fm.model) fail(`[3] ${e}: model ausente`);
      const sk = Array.isArray(fm.skills) ? fm.skills : [];
      if (sk.length !== 1 || sk[0] !== e + "-practices") fail(`[3] ${e}: skills precisa ser [${e}-practices]`);
      else if (!fs.existsSync(path.join(raiz, "skills", sk[0], "SKILL.md"))) fail(`[3] ${e}: skill ${sk[0]} não existe`);
      const tools = Array.isArray(fm.tools) ? fm.tools : [];
      for (const x of tools) if (x === "Write" || x === "Edit" || /^Agent/.test(String(x))) fail(`[3] ${e}: tools não pode ter ${x} (especialista consultivo)`);
      for (const x of ["mcp__context7__query-docs", "mcp__context7__resolve-library-id", "Bash", "Read"]) if (!tools.includes(x)) fail(`[3] ${e}: tools sem ${x}`);
      if (tools.some((x) => /get-library-docs/.test(String(x)))) fail(`[3] ${e}: get-library-docs não resolve mais; use query-docs`);
      const cmds = hookCmds(fm, ["Bash"]);
      if (!cmds || !cmds.some((c) => c.includes(".forge/scripts/data-agent-bash-guard.sh") && /\|\|\s*exit 2\s*$/.test(c))) fail(`[3] ${e}: sem hook PreToolUse de Bash chamando .forge/scripts/data-agent-bash-guard.sh com '|| exit 2'`);
    }
    ordemSecoes(`[3] ${e}`, t, ESP_SECOES);
    const prot = secao(corpo(t), "Protocolo") || "";
    for (const m of [".forge/rules/data/", "conflict-handling", "CONFLITO", "check-data-governance", "data-classification.json", "universo-vazio", "node >= 20", "scan.sh"]) if (!prot.includes(m)) fail(`[3] ${e}: Protocolo sem '${m}'`);
  }
  if (naov) out.push("NAOVERIF [3] pacote yaml ausente — frontmatter dos especialistas não parseado");
  const t = ler(agentePath(ORQ));
  if (t === null) fail("[3] agents/data/data-engineer.md ausente");
  else {
    ordemSecoes("[3] data-engineer", t, ORQ_SECOES);
    const prot = secao(corpo(t), "Protocolo") || "";
    for (const m of [".forge/rules/data/", "conflict-handling", "CONFLITO", "check-data-governance", "data-classification.json", "universo-vazio", "scan.sh", "PLANO DE ROTEAMENTO", "--agent", "registro:"]) if (!prot.includes(m)) fail(`[3] data-engineer: Protocolo sem '${m}'`);
  }
  const rel = ler(agentePath("data-relational")) || "";
  if (!(secao(corpo(rel), "Protocolo") || "").includes("sem ADR do projeto que escolha SQL")) fail("[3] data-relational: Protocolo sem a linha do H-01 (a) ('sem ADR do projeto que escolha SQL')");
  const nos = ler(agentePath("data-nosql")) || "";
  const pn = secao(corpo(nos), "Protocolo") || "";
  if (!(pn.includes("write concern `majority`") && pn.includes("P-S-S"))) fail("[3] data-nosql: Protocolo sem a linha do H-01 (a) (write concern `majority` e P-S-S)");
  console.log(out.join("\n")); process.exit(0);
}

if (modo === "skill") { // [4] <esp> <ids-catalogo-arquivo> <secoes-arquivo>
  const [esp, idsArq, secArq] = args;
  const dir = path.join(raiz, "skills", esp + "-practices");
  const sk = ler(path.join(dir, "SKILL.md")), bp = ler(path.join(dir, "references", "best-practices.md")), ap = ler(path.join(dir, "references", "antipatterns.md"));
  if (sk === null) fail(`[4] ${esp}-practices: SKILL.md ausente`);
  if (bp === null) fail(`[4] ${esp}-practices: references/best-practices.md ausente`);
  if (ap === null) fail(`[4] ${esp}-practices: references/antipatterns.md ausente`);
  if (!fs.existsSync(path.join(dir, "scripts", "scan.sh"))) fail(`[4] ${esp}-practices: scripts/scan.sh ausente`);
  if (sk !== null) { const n = corpo(sk).replace(/\n$/, "").split("\n").length; if (n > 120) fail(`[4] ${esp}-practices: corpo do SKILL.md com ${n} linhas (máximo 120)`); }
  if (bp !== null) {
    const hs = bp.split("\n").filter((l) => /^#{2,4}\s/.test(l));
    for (const s of fs.readFileSync(secArq, "utf8").split("\n").filter(Boolean)) if (!hs.some((h) => h.includes(s))) fail(`[4] ${esp}-practices: best-practices.md sem seção de cobertura '${s}'`);
  }
  if (ap !== null) {
    const linhasIds = fs.readFileSync(idsArq, "utf8").split("\n").filter(Boolean);
    const fixos = linhasIds.filter((l) => !l.startsWith("FAMILIA:"));
    const familias = linhasIds.filter((l) => l.startsWith("FAMILIA:")).map((l) => l.slice(8));
    const entradas = [...ap.matchAll(/^### ([A-Z]+(?:-[A-Z]+)*-\d{2}) — (.+)$/gm)];
    const vistos = new Set();
    const blocos = ap.split(/^(?=### )/m).filter((b) => b.startsWith("### "));
    for (const b of blocos) {
      const m = /^### ([A-Z]+(?:-[A-Z]+)*-\d{2}) — (.+)$/m.exec(b);
      if (!m) { fail(`[4] ${esp}-practices: entrada fora do formato '### <ID> — <nome>': ${b.split("\n")[0]}`); continue; }
      const id = m[1];
      if (vistos.has(id)) fail(`[4] ${esp}-practices: id duplicado ${id}`);
      vistos.add(id);
      if (!fixos.includes(id) && !familias.some((f) => id.startsWith(f))) fail(`[4] ${esp}-practices: id ${id} fora do conjunto fechado do design §2.5`);
      for (const rot of ["Sintoma", "Por quê", "Correção", "Detecção", "Evidência"]) if (!new RegExp("^- \\*\\*" + rot + ":\\*\\*\\s*\\S", "m").test(b)) fail(`[4] ${esp}-practices: ${id} sem o campo '${rot}'`);
      const det = (/^- \*\*Detecção:\*\*\s*(.+)$/m.exec(b) || [])[1] || "";
      const dm = /^(`scan\.sh ([A-Z0-9-]+)`|ferramenta|runtime|revisão)/.exec(det);
      if (det && !dm) fail(`[4] ${esp}-practices: ${id} com Detecção fora dos quatro rótulos (scan.sh <ID>, ferramenta, runtime, revisão)`);
      if (dm && dm[2] && dm[2] !== id) fail(`[4] ${esp}-practices: ${id} declara Detecção de outro id (${dm[2]})`);
      const ev = (/^- \*\*Evidência:\*\*\s*(.+)$/m.exec(b) || [])[1] || "";
      if (ev && !/\[(J|2F|1F|Interp\.|Heurística)\]/.test(ev)) fail(`[4] ${esp}-practices: ${id} com Evidência sem marca da base ([J], [2F], [1F], [Interp.] ou [Heurística])`);
    }
    for (const id of fixos) if (!vistos.has(id)) fail(`[4] ${esp}-practices: catálogo sem o id ${id}`);
    if (vistos.size === 0) fail(`[4] ${esp}-practices: catálogo sem nenhuma entrada`);
  }
  console.log(out.join("\n")); process.exit(0);
}

if (modo === "scanids") { // [5] <esp> — ids do catálogo com Detecção `scan.sh <ID>`
  const ap = ler(path.join(raiz, "skills", args[0] + "-practices", "references", "antipatterns.md")) || "";
  const ids = [];
  for (const b of ap.split(/^(?=### )/m)) {
    const m = /^### ([A-Z]+(?:-[A-Z]+)*-\d{2}) — /m.exec(b); if (!m) continue;
    const det = (/^- \*\*Detecção:\*\*\s*(.+)$/m.exec(b) || [])[1] || "";
    if (/^`scan\.sh [A-Z0-9-]+`/.test(det)) ids.push(m[1]);
  }
  console.log(ids.sort().join("\n")); process.exit(0);
}

if (modo === "rmq") { // [9]
  const bp = ler(path.join(raiz, "skills", "data-streaming-practices", "references", "best-practices.md"));
  const ap = ler(path.join(raiz, "skills", "data-streaming-practices", "references", "antipatterns.md"));
  if (bp === null || ap === null) { console.log("FAIL [9] data-streaming-practices: best-practices.md ou antipatterns.md ausente"); process.exit(0); }
  const sec = secao(bp, "RabbitMQ");
  if (sec === null) fail("[9] best-practices.md sem '## RabbitMQ'");
  else {
    const esperadas = ["Plataforma 4.x", "Exchanges e roteamento", "Filas quorum", "DLX e poison message", "Ack e prefetch", "Publisher confirms", "Retry", "Idempotência e inbox", "Ordem", "Streams", "Operação e segurança", "Receita de referência", "Migrações"];
    const hs = sec.split("\n").filter((l) => l.startsWith("### ")).map((l) => l.slice(4).trim());
    if (hs.join("|") !== esperadas.join("|")) fail(`[9] subseções de '## RabbitMQ' diferentes das treze do REQ-04, na ordem (achadas: ${hs.join(" > ")})`);
    const plat = secao(sec, "Plataforma 4.x", "### ") || "";
    const pares = [["espelhad", "4.0"], ["Mnesia", "4.3"], ["delayed", "arquivad"], ["delayed-retry", "4.3"], ["lazy", "3.12"], ["delivery-limit", "20"], ["nack", "delivery-limit"], ["at-least-once", "dead-letter"]];
    for (const [a, b] of pares) if (!plat.split("\n").some((l) => l.includes(a) && l.includes(b) && l.includes("[J]"))) fail(`[9] fato de plataforma ausente em 'Plataforma 4.x': par (${a}, ${b}) com [J] na mesma linha`);
  }
  const bpIds = new Set([...bp.matchAll(/RMQ-BP-(\d{2})/g)].map((m) => +m[1]));
  for (let i = 1; i <= 17; i++) if (!bpIds.has(i)) fail(`[9] best-practices.md sem RMQ-BP-${String(i).padStart(2, "0")}`);
  for (const i of bpIds) if (i < 1 || i > 17) fail(`[9] best-practices.md com RMQ-BP-${i} fora de 01..17`);
  const apIds = new Set([...ap.matchAll(/^### RMQ-AP-(\d{2}) — /gm)].map((m) => +m[1]));
  for (let i = 1; i <= 20; i++) if (!apIds.has(i)) fail(`[9] antipatterns.md sem RMQ-AP-${String(i).padStart(2, "0")}`);
  for (const i of apIds) if (i < 1 || i > 20) fail(`[9] antipatterns.md com RMQ-AP-${i} fora de 01..20`);
  console.log(out.join("\n")); process.exit(0);
}

if (modo === "integ") { // [10]
  const frase = process.env.W250_FRASE;
  for (const n of [ORQ, ...ESPS]) {
    const t = ler(agentePath(n)); if (t === null) { fail(`[10] agents/data/${n}.md ausente`); continue; }
    const s = secao(corpo(t), "Regra de integração");
    if (s === null) { fail(`[10] ${n}: sem seção 'Regra de integração'`); continue; }
    if (!s.includes(frase)) fail(`[10] ${n}: seção 'Regra de integração' sem a frase canônica do design §2.4`);
    for (const m of ["URL pré-assinada", "HTTPS", "expiração em minutos", "endpoint REST autenticado", "log de emissão", "bucket privado"]) if (!s.includes(m)) fail(`[10] ${n}: regra da URL pré-assinada (H-02 a) sem '${m}'`);
  }
  const bp = ler(path.join(raiz, "skills", "data-streaming-practices", "references", "best-practices.md")) || "";
  const tr = secao(bp, "Escolha de transporte");
  if (tr === null) fail("[10] data-streaming-practices: best-practices.md sem '## Escolha de transporte'");
  else {
    const tab = tr.split("\n").filter((l) => /^\|/.test(l)).join("\n");
    for (const m of ["AsyncAPI", ".proto", "OpenAPI", "gRPC", "REST"]) if (!tab.includes(m)) fail(`[10] tabela de transporte sem '${m}' (coluna de contrato)`);
  }
  const ap = ler(path.join(raiz, "skills", "data-streaming-practices", "references", "antipatterns.md")) || "";
  for (let i = 1; i <= 5; i++) if (!new RegExp("^### D-AP-0" + i + " — ", "m").test(ap)) fail(`[10] antipatterns.md sem D-AP-0${i}`);
  const orq = ler(agentePath(ORQ)) || "";
  const ck = secao(corpo(orq), "Checklist transversal");
  if (ck === null) fail("[10] data-engineer: sem 'Checklist transversal'");
  else {
    for (const m of ["PCI DSS", "LGPD", "multi-tenant", "RLS", "custo", "reversibilidade", "check-data-governance", "data-classification.json"]) if (!ck.includes(m)) fail(`[10] data-engineer: Checklist transversal sem '${m}'`);
    for (const m of ["T-02", "T-03", "T-04", "crypto-shredding", "pseudonimização"]) {
      const ls = ck.split("\n").filter((l) => l.includes(m));
      if (ls.length === 0) fail(`[10] data-engineer: Checklist transversal sem o item [Interp.] '${m}'`);
      for (const l of ls) if (!l.includes("[Interp.]")) fail(`[10] data-engineer: item '${m}' do checklist é [Interp.] na base e a linha não carrega a marca`);
    }
  }
  console.log(out.join("\n")); process.exit(0);
}

if (modo === "refut") { // [11]
  const arqs = [ORQ, ...ESPS].map((n) => agentePath(n));
  for (const e of ESPS) { arqs.push(path.join(raiz, "skills", e + "-practices", "SKILL.md")); arqs.push(path.join(raiz, "skills", e + "-practices", "references", "best-practices.md")); }
  const proib = [
    [/ha-mode|ha-params|ha-sync-mode/, "filas espelhadas (ha-mode)"],
    [/x-queue-mode|queue-mode:\s*lazy/, "lazy queue como recomendação"],
    [/x-delayed-message|x-delayed-type/, "plugin delayed exchange"],
    [/3[–-]4x|4[x×] o WAL/, "'3–4x o WAL' (a fonte diz ≥ 3×)"],
    [/max\.in\.flight[^.]*desativa/, "'max.in.flight desativa a idempotência' (refutado)"],
  ];
  const hive = /[Hh]ive[^.;]*(\bem\b|\bpara\b|\bnas?\b)\s+(tabelas?\s+)?(silver|gold)/;
  let vistos = 0;
  for (const p of arqs) {
    const t = ler(p); if (t === null) { fail(`[11] ${path.relative(raiz, p)} ausente`); continue; }
    vistos++;
    t.split("\n").forEach((l, i) => {
      if (/Refutado/.test(l)) return;
      for (const [re, rot] of proib) if (re.test(l)) fail(`[11] ${path.relative(raiz, p)}:${i + 1}: recomendação refutada ou obsoleta fora do catálogo — ${rot}`);
      if (hive.test(l) && !/\b(nunca|não|Nunca|Não)\b/.test(l)) fail(`[11] ${path.relative(raiz, p)}:${i + 1}: partição Hive recomendada para silver/gold (refutado, base §8.1 item 4)`);
    });
  }
  console.log(out.join("\n")); if (out.length === 0) console.log("EXAMINADOS " + vistos); process.exit(0);
}

if (modo === "conflito") { // [17]
  for (const n of [ORQ, ...ESPS]) {
    const t = ler(agentePath(n)); if (t === null) { fail(`[17] agents/data/${n}.md ausente`); continue; }
    if (!t.includes("rules/conventions/conflict-handling.md")) fail(`[17] ${n}: não cita rules/conventions/conflict-handling.md`);
    for (const c of ["CONFLITO", "decisão:", "posição A:", "posição B:", "precedência:", "opções:", "registro:"]) if (!t.includes(c)) fail(`[17] ${n}: bloco CONFLITO sem '${c}'`);
  }
  const todos = [ORQ, ...ESPS].map((n) => agentePath(n));
  for (const e of ESPS) { for (const f of ["SKILL.md", "references/best-practices.md", "references/antipatterns.md"]) todos.push(path.join(raiz, "skills", e + "-practices", f)); }
  const segue = /(registr|cit)[a-zçãõáéí]*\s+(a\s+)?(diverg[a-zê]*\s+)?e\s+(sig|segu)/i;
  for (const p of todos) {
    const t = ler(p); if (t === null) continue;
    t.split("\n").forEach((l, i) => { if (segue.test(l) && !/(nunca|não|sem|proíb|Nunca|Não|Sem)/.test(l)) fail(`[17] ${path.relative(raiz, p)}:${i + 1}: 'registra e segue' diante de conflito (conflict-handling §2 proíbe)`); });
  }
  const relDir = path.join(raiz, "skills", "data-relational-practices");
  for (const f of ["SKILL.md", "references/best-practices.md"]) {
    const t = ler(path.join(relDir, f)); if (t === null) { fail(`[17] data-relational-practices/${f} ausente`); continue; }
    t.split("\n").forEach((l, i) => {
      if (/\b(numeric|decimal|NUMERIC|DECIMAL)\b/.test(l) && /(monet|dinheiro|money|valor)/i.test(l) && !/(nunca|não|Nunca|Não|BIGINT)/.test(l)) fail(`[17] data-relational-practices/${f}:${i + 1}: numeric/DECIMAL recomendado para valor monetário (money-as-cents.md manda BIGINT na menor unidade, H-03 a)`);
    });
    if (f === "references/best-practices.md" && !t.includes("money-as-cents.md")) fail("[17] data-relational-practices: best-practices.md não cita money-as-cents.md como regra da casa");
  }
  for (const p of todos) {
    const t = ler(p); if (t === null) continue;
    t.split("\n").forEach((l, i) => { if (/Redis/.test(l) && /fonte d[ae] verdade/i.test(l) && !/(nunca|não|jamais|Nunca|Não|CONFLITO|antipattern|C-07)/.test(l)) fail(`[17] ${path.relative(raiz, p)}:${i + 1}: Redis como fonte de verdade sem negação (data-governance.md e data-cache.md: nunca)`); });
  }
  console.log(out.join("\n")); process.exit(0);
}

if (modo === "hookcmd") { // extrai o comando do hook (matcher Agent|Task ou Bash) de um agente — [16] e [18] pelo canal
  const [arq, alvo] = args;
  const t = ler(arq); const r = parseFm(t);
  if (r.naoverif || r.erro || !r.fm) { process.exit(3); }
  const cmds = hookCmds(r.fm, alvo === "Bash" ? ["Bash"] : ["Agent", "Task"]) || [];
  if (cmds.length === 0) process.exit(4);
  process.stdout.write(cmds[0]); process.exit(0);
}

console.error("modo desconhecido: " + modo); process.exit(9);
NODE

cat > "$TMPD/scanjson.cjs" <<'NODE'
// scanjson.cjs <texto> <json> — confere que o --json carrega o mesmo conteúdo da saída de texto ([6]).
const fs = require("fs");
const [txt, js] = process.argv.slice(2);
let j; try { j = JSON.parse(fs.readFileSync(js, "utf8")); } catch (e) { console.log("FAIL JSON inválido: " + e.message); process.exit(0); }
const linhas = fs.readFileSync(txt, "utf8").split("\n");
const regras = []; let cur = null; let varridos = null;
for (const l of linhas) {
  let m;
  if ((m = /^(OK|FOUND) (\S+) \[(alto|aviso)\] (?:nenhuma ocorrência|(\d+) ocorrência\(s\))/.exec(l))) { cur = { id: m[2], severidade: m[3], status: m[1], ocorrencias: m[1] === "OK" ? 0 : +m[4], localizacoes: [] }; regras.push(cur); }
  else if ((m = /^  (.+?):(\d+): (.*)$/.exec(l)) && cur) cur.localizacoes.push({ arquivo: m[1], linha: +m[2], trecho: m[3] });
  else if ((m = /^ARQUIVOS-VARRIDOS (\d+)$/.exec(l))) varridos = +m[1];
}
const erros = [];
if (!Array.isArray(j.regras)) erros.push("json sem regras[]");
else {
  if (j.regras.length !== regras.length) erros.push(`regras: texto ${regras.length}, json ${j.regras.length}`);
  regras.forEach((r, i) => {
    const o = j.regras[i] || {};
    for (const k of ["id", "severidade", "status", "ocorrencias"]) if (o[k] !== r[k]) erros.push(`${r.id}: ${k} texto=${r[k]} json=${o[k]}`);
    const lj = (o.localizacoes || []).map((x) => `${x.arquivo}:${x.linha}: ${x.trecho}`).join("\n");
    const lt = r.localizacoes.map((x) => `${x.arquivo}:${x.linha}: ${x.trecho}`).join("\n");
    if (lj !== lt) erros.push(`${r.id}: localizações divergem entre texto e json`);
  });
}
if (j.arquivos_varridos !== varridos) erros.push(`arquivos_varridos texto=${varridos} json=${j.arquivos_varridos}`);
console.log(erros.map((e) => "FAIL " + e).join("\n"));
NODE

cat > "$TMPD/evals.cjs" <<'NODE'
// evals.cjs <ws> — [15] sete evals.json no formato skill-creator.
const fs = require("fs"), path = require("path");
const ws = process.argv[2];
const TOPO = process.env.W250_TOPO.split(" "), CASO = process.env.W250_CASO.split(" ");
const TXT = process.env.W250_REGRA_TXT;
const ESPS = ["data-relational", "data-nosql", "data-cache", "data-object-storage", "data-analytical", "data-streaming"];
const out = []; const fail = (m) => out.push("FAIL [15] " + m);
for (const nome of ["data-engineer", ...ESPS]) {
  const p = path.join(ws, ".forge", "evals", "agents", nome, "evals.json");
  let j; try { j = JSON.parse(fs.readFileSync(p, "utf8")); } catch (e) { fail(`${nome}: evals.json ausente ou inválido (${e.code || e.message})`); continue; }
  for (const k of TOPO) if (!(k in j)) fail(`${nome}: campo de topo ausente: ${k}`);
  if (j.skill_name !== nome) fail(`${nome}: skill_name '${j.skill_name}'`);
  if (j.artifact_kind !== "agent") fail(`${nome}: artifact_kind '${j.artifact_kind}' (esperado agent)`);
  if (j.artifact_path !== `template/.forge/agents/data/${nome}.md` || !fs.existsSync(path.join(ws, j.artifact_path || "-"))) fail(`${nome}: artifact_path não resolve para template/.forge/agents/data/${nome}.md`);
  const ev = Array.isArray(j.evals) ? j.evals : []; const ids = new Set(), nomes = new Set();
  for (const c of ev) {
    for (const k of CASO) if (!(k in c)) fail(`${nome}: caso ${c.eval_name || c.id} sem ${k}`);
    if (!Number.isInteger(c.id) || ids.has(c.id)) fail(`${nome}: id inválido ou repetido (${c.id})`); ids.add(c.id);
    if (typeof c.eval_name !== "string" || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(c.eval_name) || nomes.has(c.eval_name)) fail(`${nome}: eval_name inválido ou repetido (${c.eval_name})`); nomes.add(c.eval_name);
    if (typeof c.prompt !== "string" || !c.prompt.trim()) fail(`${nome}: ${c.eval_name}: prompt vazio`);
    if (typeof c.expected_output !== "string" || !c.expected_output.trim()) fail(`${nome}: ${c.eval_name}: expected_output vazio`);
    if (!Array.isArray(c.files)) fail(`${nome}: ${c.eval_name}: files não é array`);
    const as = Array.isArray(c.assertions) ? c.assertions : [];
    if (as.length < 2 || !as.every((a) => a && typeof a.name === "string" && typeof a.text === "string" && a.text.trim())) fail(`${nome}: ${c.eval_name}: precisa de ao menos duas assertions {name, text}`);
    const ri = as.filter((a) => a && a.name === "regra-de-integracao-respeitada");
    if (ri.length !== 1 || ri[0].text !== TXT) fail(`${nome}: ${c.eval_name}: assertion regra-de-integracao-respeitada ausente ou com texto diferente do design §2.7`);
    if (/^(revisao-|holdout-revisao-)/.test(c.eval_name || "") && !as.some((a) => a && a.name === "cita-id-e-localizacao")) fail(`${nome}: ${c.eval_name}: caso de revisão sem cita-id-e-localizacao`);
  }
  const n = (re) => ev.filter((c) => re.test(c.eval_name || "")).length;
  if (nome === "data-engineer") {
    if (ev.length !== 22) fail(`data-engineer: ${ev.length} casos (esperados 22)`);
    if (n(/^dominio-/) !== 6) fail(`data-engineer: ${n(/^dominio-/)} casos dominio-* (esperados 6)`);
    if (n(/^critico-/) !== 6) fail(`data-engineer: ${n(/^critico-/)} casos critico-* (esperados 6)`);
    if (n(/^critico-degradado-/) !== 2) fail("data-engineer: esperados 2 critico-degradado-*");
    if (n(/^critico-multi-/) !== 2) fail("data-engineer: esperados 2 critico-multi-*");
    if (n(/^critico-fora-cobertura/) !== 1 || n(/^critico-conflito-rule/) !== 1) fail("data-engineer: esperados critico-fora-cobertura e critico-conflito-rule");
    if (n(/^disparo-(?!negativo-)/) !== 6) fail(`data-engineer: ${n(/^disparo-(?!negativo-)/)} disparo-* positivos (esperados 6)`);
    if (n(/^disparo-negativo-/) !== 2) fail("data-engineer: esperados 2 disparo-negativo-*");
    if (n(/^holdout-/) !== 2) fail("data-engineer: esperados 2 holdout-*");
  } else {
    if (ev.length !== 4) fail(`${nome}: ${ev.length} casos (esperados 4: desenho, revisão, fronteira e holdout)`);
    for (const re of [/^desenho-/, /^revisao-/, /^fronteira-/, /^holdout-/]) if (n(re) !== 1) fail(`${nome}: esperado exatamente um caso ${re.source.slice(1)}*`);
  }
}
console.log(out.join("\n"));
NODE

cat > "$TMPD/pbt.mjs" <<'NODE'
// pbt.mjs <pbt-lib> <dir-saida> <semente> — gera os casos do [20] e o veredito do oráculo independente.
import { pathToFileURL } from "node:url";
import fs from "node:fs";
const [lib, dir, sementeTxt] = process.argv.slice(2);
const { makeRandom } = await import(pathToFileURL(lib).href);
const rnd = makeRandom(Number(sementeTxt));
const pick = (a) => a[rnd.int(0, a.length - 1)];
const ESPS = ["data-relational", "data-nosql", "data-cache", "data-object-storage", "data-analytical", "data-streaming"];
const SCANS = ESPS.map((e) => `.forge/skills/${e}-practices/scripts/scan.sh`);
const GOV = ".forge/scripts/check-data-governance.sh";
const ALFA = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/=-";
const palavra = (min = 1, max = 8) => { let s = ""; const n = rnd.int(min, max); for (let i = 0; i < n; i++) s += ALFA[rnd.int(0, ALFA.length - 1)]; return s; };
const caminho = () => { let s = palavra(); if (s.startsWith("-")) s = "x" + s; return s; };
// oráculo: implementação independente da gramática aceita (design §2.3).
function aceita(cmd) {
  if (!/^[ A-Za-z0-9._\/=-]+$/.test(cmd)) return false;
  const t = cmd.trim().split(/ +/);
  if (t[0] !== "bash") return false;
  if (SCANS.includes(t[1])) {
    for (let i = 2; i < t.length; i += 2) {
      const f = t[i], v = t[i + 1];
      if (v === undefined) return false;
      if (f === "--root") { if (v.startsWith("-")) return false; }
      else if (f === "--max") { if (!/^[0-9]+$/.test(v)) return false; }
      else return false;
    }
    return true;
  }
  if (t[1] === GOV) {
    if (t[2] !== "--path" || t.length < 4) return false;
    return t.slice(3).every((a) => !a.startsWith("-"));
  }
  return false;
}
function valido() {
  if (rnd.next() < 0.6) {
    const partes = ["bash", pick(SCANS)];
    const n = rnd.int(0, 3);
    for (let i = 0; i < n; i++) { if (rnd.next() < 0.7) partes.push("--root", caminho()); else partes.push("--max", String(rnd.int(1, 999))); }
    return partes.join(" ");
  }
  const partes = ["bash", GOV, "--path"]; const n = rnd.int(1, 3);
  for (let i = 0; i < n; i++) partes.push(caminho());
  return partes.join(" ");
}
const METAS = [">", ">>", ";", "&&", "||", "|", "$(", "`", "\n", "'", "\"", "*", "~", "\t", "&", "<"];
function mutante() {
  const base = valido();
  const r = rnd.next();
  if (r < 0.4) { const i = rnd.int(0, base.length); return base.slice(0, i) + pick(METAS) + base.slice(i); }
  if (r < 0.55) return base + " --json " + caminho();
  if (r < 0.7) return base.replace(/^bash /, pick(["sh ", "zsh ", "bash  -c ", "node ", "sudo bash "]));
  if (r < 0.8) return base.replace(/\.forge\/(skills|scripts)\//, pick([".forge/skills/data-x-practices/", "./.forge/scripts/", ".forge/scripts/lib/", "../"]));
  if (r < 0.9) return base + " --root -" + palavra();
  return pick(["git add .", "git commit -m x", "sed -i s/a/b/ x", "rm -rf x", "touch y", "bash", "bash .forge/scripts/doctor.sh", base + " --max x" + palavra()]);
}
const casos = [];
for (let i = 0; i < 60; i++) { const cmd = rnd.next() < 0.45 ? valido() : mutante(); casos.push({ tipo: "guard", entrada: { tool_name: "Bash", tool_input: { command: cmd } }, esperado: aceita(cmd) ? 0 : 2, rotulo: cmd }); }
const TIPOS = [...ESPS, "general-purpose", "task-coder", "Explore", "data-engineer", "data-cache ", " data-cache", "DATA-CACHE", "data-cachex", "data_cache", ""];
for (let i = 0; i < 20; i++) {
  const t = rnd.next() < 0.5 ? pick(TIPOS) : (rnd.next() < 0.5 ? "data-" + palavra(3, 12) : palavra(1, 16));
  casos.push({ tipo: "allow", entrada: { tool_name: "Agent", tool_input: { subagent_type: t, prompt: "x" } }, esperado: ESPS.includes(t) ? 0 : 2, rotulo: JSON.stringify(t) });
}
casos.forEach((c, i) => fs.writeFileSync(`${dir}/caso-${String(i).padStart(3, "0")}.json`, JSON.stringify(c.entrada)));
fs.writeFileSync(`${dir}/esperado.tsv`, casos.map((c, i) => `${String(i).padStart(3, "0")}\t${c.tipo}\t${c.esperado}\t${JSON.stringify(c.rotulo)}`).join("\n") + "\n");
console.log(`casos=${casos.length} aceitos-esperados=${casos.filter((c) => c.esperado === 0).length}`);
NODE

fm() { W250_YAML="$YAML_MOD" W250_FRASE="$FRASE_CANONICA" node "$TMPD/fm.cjs" "$@"; }

# relata <saida-de-checagem> — imprime as linhas e devolve 1 se houver FAIL; conta NAOVERIF no global.
relata() {
  local saida="$1" rc=0
  [ -n "$saida" ] && printf '%s\n' "$saida" | grep -v '^EXAMINADOS ' | sed '/^$/d'
  if printf '%s\n' "$saida" | grep -q '^FAIL '; then rc=1; fi
  if printf '%s\n' "$saida" | grep -q '^NAOVERIF '; then NAOVERIF=$((NAOVERIF + 1)); fi
  return $rc
}

# executa o scanner da skill <esp> na raiz <raiz>, a partir do diretório <cwd>; argumentos extras depois.
scan() { # scan <raiz> <esp> <cwd> [args...]
  local raiz="$1" esp="$2" cwd="$3"; shift 3
  (cd "$cwd" && bash "$raiz/skills/$esp-practices/scripts/scan.sh" "$@")
}

# ── [0] universo ────────────────────────────────────────────────────────────────────────────────────────────────────
confere_0() {
  local raiz="$1" n=0 a e rc=0
  for a in $AGENTES; do if [ -f "$raiz/agents/data/$a.md" ]; then n=$((n + 1)); else echo "FAIL [0] agents/data/$a.md ausente"; rc=1; fi; done
  for e in $ESPS; do if [ -f "$raiz/skills/$e-practices/SKILL.md" ]; then n=$((n + 1)); else echo "FAIL [0] skills/$e-practices ausente"; rc=1; fi; done
  # shellcheck disable=SC1091
  . "$TEMPLATE/scripts/lib/gate-universe.sh"
  forge_universe_check w250 "$n" "artefato(s) de dados" "agents/data (7 agentes) e skills/data-*-practices (6 skills)" "$WS" || rc=1
  [ "$n" -eq 13 ] || { echo "FAIL [0] universo incompleto: $n de 13 artefatos (agents/data + skills data-*-practices)"; rc=1; }
  return $rc
}

# ── [1] frontmatter ─────────────────────────────────────────────────────────────────────────────────────────────────
confere_1() {
  local raiz="$1" rc=0 saida alvos=() e
  [ -d "$raiz/agents/data" ] && alvos+=("$raiz/agents/data")
  for e in $ESPS; do [ -d "$raiz/skills/$e-practices" ] && alvos+=("$raiz/skills/$e-practices"); done
  if [ "${#alvos[@]}" -eq 0 ]; then echo "FAIL [1] nenhum diretório de agentes/skills de dados para validar"; rc=1
  else
    saida="$(bash "$TEMPLATE/scripts/validate-frontmatter.sh" --strict-xml "${alvos[@]}" 2>&1)"
    ultima="$(printf '%s\n' "$saida" | tail -1)"
    if ! grep -qE '^OK( |$)' <<<"$ultima"; then echo "FAIL [1] validate-frontmatter.sh --strict-xml:"; printf '%s\n' "$saida" | sed 's/^/      /'; rc=1; fi
  fi
  if [ -z "$YAML_MOD" ]; then echo "NAO-VERIFICADO [1] pacote yaml ausente (node_modules do checkout e do checkout principal)"; NAOVERIF=$((NAOVERIF + 1)); return $rc; fi
  relata "$(fm fm "$raiz")" || rc=1
  return $rc
}

confere_2() { relata "$(fm rota "$1")"; }
confere_3() { relata "$(fm esp "$1")"; }

# ── [4] skills ──────────────────────────────────────────────────────────────────────────────────────────────────────
confere_4() {
  local raiz="$1" rc=0 e
  for e in $ESPS; do
    ids_catalogo "$e" > "$TMPD/ids-$e.txt"; secoes_cobertura "$e" > "$TMPD/sec-$e.txt"
    relata "$(fm skill "$raiz" "$e" "$TMPD/ids-$e.txt" "$TMPD/sec-$e.txt")" || rc=1
  done
  return $rc
}

# ── [5] bijeção ─────────────────────────────────────────────────────────────────────────────────────────────────────
confere_5() {
  local raiz="$1" rc=0 e emitidos catalogo design s linha id sev esperado
  for e in $ESPS; do
    if [ ! -f "$raiz/skills/$e-practices/scripts/scan.sh" ]; then echo "FAIL [5] $e-practices: scripts/scan.sh ausente"; rc=1; continue; fi
    s="$(scan "$raiz" "$e" "$WS" --root "$FIX_REL/$e/limpo" 2>/dev/null)"
    emitidos="$(printf '%s\n' "$s" | sed -nE 's/^(OK|FOUND) ([A-Z0-9-]+) \[(alto|aviso)\].*/\2/p' | LC_ALL=C sort)"
    catalogo="$(fm scanids "$raiz" "$e" | sed '/^$/d' | LC_ALL=C sort)"
    design="$(regras_estaticas "$e" | cut -d' ' -f1 | LC_ALL=C sort)"
    for id in $design; do
      printf '%s\n' "$emitidos" | grep -qx "$id" || { echo "FAIL [5] $e-practices: regra $id do design não é emitida pelo scan.sh"; rc=1; }
      printf '%s\n' "$catalogo" | grep -qx "$id" || { echo "FAIL [5] $e-practices: $id não tem 'Detecção: scan.sh $id' no catálogo"; rc=1; }
    done
    for id in $emitidos; do
      printf '%s\n' "$catalogo" | grep -qx "$id" || { echo "FAIL [5] $e-practices: scan.sh emite $id, que o catálogo não declara como 'scan.sh $id'"; rc=1; }
      printf '%s\n' "$design" | grep -qx "$id" || { echo "FAIL [5] $e-practices: scan.sh emite $id, fora da tabela de regras estáticas do design"; rc=1; }
    done
    for id in $catalogo; do printf '%s\n' "$emitidos" | grep -qx "$id" || { echo "FAIL [5] $e-practices: catálogo declara 'scan.sh $id' e o scanner não emite $id"; rc=1; }; done
    while read -r id esperado; do
      [ -n "$id" ] || continue
      linha="$(printf '%s\n' "$s" | grep -E "^(OK|FOUND) $id \[" | head -1)"
      sev="$(printf '%s\n' "$linha" | sed -nE 's/^(OK|FOUND) [A-Z0-9-]+ \[(alto|aviso)\].*/\2/p')"
      [ -z "$linha" ] || [ "$sev" = "$esperado" ] || { echo "FAIL [5] $e-practices: $id com severidade '$sev' (design: $esperado)"; rc=1; }
    done <<EOF
$(regras_estaticas "$e")
EOF
  done
  return $rc
}

# ── [6] detecção, contrato de CLI e isolamento ──────────────────────────────────────────────────────────────────────
montar_path_reduzido() { # montar_path_reduzido <dir> [com-rg] — só os utilitários que o scanner pode usar
  local d="$1" u p
  mkdir -p "$d"
  for u in bash sh cat find grep sort sed awk tr head tail wc xargs mktemp rm mkdir cut uniq comm; do
    p="$(command -v "$u" 2>/dev/null)" && ln -sf "$p" "$d/$u"
  done
  if [ "${2:-}" = "com-rg" ]; then p="$(command -v rg 2>/dev/null)" && ln -sf "$p" "$d/rg"; fi
}

confere_6() {
  local raiz="$1" rc=0 e sujo limpo out1 out2 r1 r2 id sev d a al arq pr semrg
  pr="$TMPD/path-reduzido"; montar_path_reduzido "$pr"
  for e in $ESPS; do
    [ -f "$raiz/skills/$e-practices/scripts/scan.sh" ] || { echo "FAIL [6] $e-practices: scripts/scan.sh ausente"; rc=1; continue; }
    sujo="$FIX_REL/$e/sujo"; limpo="$FIX_REL/$e/limpo"
    out1="$TMPD/6-$e-1.txt"; out2="$TMPD/6-$e-2.txt"
    scan "$raiz" "$e" "$WS" --root "$sujo" --max 1000 > "$out1" 2>/dev/null; r1=$?
    scan "$raiz" "$e" "$WS" --root "$sujo" --max 1000 > "$out2" 2>/dev/null; r2=$?
    [ "$r1" -eq 1 ] || { echo "FAIL [6] $e-practices: fixture suja com achado alto saiu $r1 (esperado 1)"; rc=1; }
    cmp -s "$out1" "$out2" || { echo "FAIL [6] $e-practices: duas execuções sobre a mesma árvore divergem (não determinístico)"; rc=1; }
    while read -r id sev; do
      [ -n "$id" ] || continue
      grep -qE "^FOUND $id \[$sev\] [0-9]+ ocorrência" "$out1" || { echo "FAIL [6] $e-practices: fixture suja não fez $id emitir FOUND"; rc=1; continue; }
      awk -v id="$id" -v pre="  $sujo/$id/" '
        /^(OK|FOUND) / { dentro = ($2 == id) ; next }
        dentro && index($0, pre) == 1 && $0 ~ /:[0-9]+: / { achou = 1 }
        END { exit achou ? 0 : 1 }' "$out1" \
        || { echo "FAIL [6] $e-practices: $id não localizou arquivo:linha dentro de $sujo/$id/ (a ocorrência plantada para a regra)"; rc=1; }
    done <<EOF
$(regras_estaticas "$e")
EOF
    ultima="$(tail -1 "$out1")"
    grep -qE '^ARQUIVOS-VARRIDOS [1-9][0-9]*$' <<<"$ultima" || { echo "FAIL [6] $e-practices: a última linha não é 'ARQUIVOS-VARRIDOS <n>' com n > 0"; rc=1; }
    scan "$raiz" "$e" "$WS" --root "$limpo" > "$TMPD/6-$e-limpo.txt" 2>/dev/null; r1=$?
    [ "$r1" -eq 0 ] || { echo "FAIL [6] $e-practices: fixture limpa saiu $r1 (esperado 0)"; rc=1; }
    if grep -q '^FOUND ' "$TMPD/6-$e-limpo.txt"; then echo "FAIL [6] $e-practices: fixture limpa (com os sósias) produziu achado:"; grep -A2 '^FOUND ' "$TMPD/6-$e-limpo.txt" | sed 's/^/      /'; rc=1; fi
    [ "$(grep -c '^OK ' "$TMPD/6-$e-limpo.txt")" -eq "$(regras_estaticas "$e" | wc -l | tr -d ' ')" ] || { echo "FAIL [6] $e-practices: fixture limpa não emitiu uma linha OK por regra"; rc=1; }
    a="$(regra_aviso "$e")"; al="$(regra_alto "$e")"
    scan "$raiz" "$e" "$WS" --root "$sujo/$a" > "$TMPD/6-av.txt" 2>/dev/null; r1=$?
    { [ "$r1" -eq 0 ] && grep -q "^FOUND $a \[aviso\]" "$TMPD/6-av.txt"; } || { echo "FAIL [6] $e-practices: só com aviso ($a) o scanner saiu $r1 (esperado 0 com FOUND $a)"; rc=1; }
    scan "$raiz" "$e" "$WS" --root "$sujo/$al" > "$TMPD/6-al.txt" 2>/dev/null; r1=$?
    [ "$r1" -eq 1 ] || { echo "FAIL [6] $e-practices: com achado alto ($al) o scanner saiu $r1 (esperado 1)"; rc=1; }
    arq="$(cd "$WS" && find "$sujo/$al" -type f | LC_ALL=C sort | head -1)"
    scan "$raiz" "$e" "$WS" --root "$sujo/$al" --root "$arq" > "$TMPD/6-uniao.txt" 2>/dev/null
    cmp -s "$TMPD/6-al.txt" "$TMPD/6-uniao.txt" || { echo "FAIL [6] $e-practices: --root diretório + --root arquivo dentro dele não deu a união sem duplicata"; rc=1; }
    scan "$raiz" "$e" "$WS" --root "$FIX_REL/nao-existe-$$" >/dev/null 2>&1; r1=$?
    [ "$r1" -eq 2 ] || { echo "FAIL [6] $e-practices: --root inexistente saiu $r1 (esperado 2)"; rc=1; }
    scan "$raiz" "$e" "$WS" --root "$sujo" --max 3 --json "$TMPD/6-$e.json" > "$TMPD/6-$e-json.txt" 2>/dev/null
    d="$(node "$TMPD/scanjson.cjs" "$TMPD/6-$e-json.txt" "$TMPD/6-$e.json")"
    [ -z "$d" ] || { printf '%s\n' "$d" | sed "s/^FAIL /FAIL [6] $e-practices: --json: /"; rc=1; }
    # isolamento: nada de rede, de invocação de node/python nem de leitura de variável de conexão.
    if grep -nE 'curl|wget|nc |/dev/tcp|(^|[^A-Za-z0-9_-])(node|python3?)([[:space:]]|$)|\$\{?(DATABASE_URL|REDIS_URL|AMQP_URL|KAFKA_[A-Z_]*)' \
         "$raiz/skills/$e-practices/scripts/scan.sh" > "$TMPD/6-iso.txt"; then
      echo "FAIL [6] $e-practices: scan.sh com rede, interpretador ou variável de conexão:"; sed 's/^/      /' "$TMPD/6-iso.txt"; rc=1
    fi
    # PATH reduzido a bash, coreutils e grep (sem rg): saída byte-idêntica à execução normal.
    semrg="$TMPD/6-$e-semrg.txt"
    (cd "$WS" && env PATH="$pr" bash "$raiz/skills/$e-practices/scripts/scan.sh" --root "$sujo" --max 1000 > "$semrg" 2>/dev/null)
    cmp -s "$out1" "$semrg" || { echo "FAIL [6] $e-practices: com PATH reduzido (bash, coreutils, grep; sem rg) a saída difere da execução normal"; diff "$out1" "$semrg" | head -5 | sed 's/^/      /'; rc=1; }
  done
  return $rc
}

# ── [7] portabilidade ───────────────────────────────────────────────────────────────────────────────────────────────
confere_7() {
  local raiz="$1" rc=0 e p id linha c base n1 n2 comrg semrg
  if ! command -v rg >/dev/null 2>&1; then echo "NAO-VERIFICADO [7] rg ausente — a equivalência dos dois motores não pode ser provada"; NAOVERIF=$((NAOVERIF + 1)); return 0; fi
  comrg="$TMPD/7-comrg"; semrg="$TMPD/7-semrg"; montar_path_reduzido "$comrg" com-rg; montar_path_reduzido "$semrg"
  for e in $ESPS; do
    [ -f "$raiz/skills/$e-practices/scripts/scan.sh" ] || { echo "FAIL [7] $e-practices: scripts/scan.sh ausente"; rc=1; continue; }
    p="$(plantio "$e")"; id="${p%%|*}"; linha="${p#*|}"
    c="$TMPD/7-$e"; rm -rf "$c"; mkdir -p "$c/base"; cp -R "$WS/$FIX_REL/$e/sujo/." "$c/base/"
    (cd "$c" && env PATH="$semrg" bash "$raiz/skills/$e-practices/scripts/scan.sh" --root base --max 1000 > antes.txt 2>/dev/null)
    n1="$(sed -nE 's/^ARQUIVOS-VARRIDOS ([0-9]+)$/\1/p' "$c/antes.txt")"
    mkdir -p "$c/base/.github" "$c/base/.forge/worktrees/x" "$c/base/.claude/worktrees/y"
    printf '%s\n' "$linha" > "$c/base/.github/x.yml"
    printf 'ignorado.yml\n' > "$c/base/.gitignore"
    printf '%s\n' "$linha" > "$c/base/ignorado.yml"
    printf '%s # \001 byte de controle\n' "$linha" > "$c/base/controle.yml"
    printf '%s\n' "$linha" > "$c/base/.forge/worktrees/x/plantado.yml"
    printf '%s\n' "$linha" > "$c/base/.claude/worktrees/y/plantado.yml"
    (cd "$c" && env PATH="$comrg" bash "$raiz/skills/$e-practices/scripts/scan.sh" --root base --max 1000 > rg.txt 2>/dev/null)
    (cd "$c" && env PATH="$semrg" bash "$raiz/skills/$e-practices/scripts/scan.sh" --root base --max 1000 > grep.txt 2>/dev/null)
    cmp -s "$c/rg.txt" "$c/grep.txt" || { echo "FAIL [7] $e-practices: saída com rg difere da saída sem rg:"; diff "$c/rg.txt" "$c/grep.txt" | head -6 | sed 's/^/      /'; rc=1; }
    for f in "base/.github/x.yml" "base/ignorado.yml" "base/controle.yml"; do
      grep -qF "  $f:1: " "$c/grep.txt" || { echo "FAIL [7] $e-practices: $id não achou a ocorrência plantada em $f"; rc=1; }
    done
    if grep -qE '^  base/\.(forge|claude)/worktrees/' "$c/grep.txt" "$c/rg.txt"; then echo "FAIL [7] $e-practices: ocorrência dentro de worktree aninhado entrou no relatório"; rc=1; fi
    if LC_ALL=C grep -q "$(printf '\001')" "$c/grep.txt"; then echo "FAIL [7] $e-practices: byte de controle vazou para o relatório"; rc=1; fi
    n2="$(sed -nE 's/^ARQUIVOS-VARRIDOS ([0-9]+)$/\1/p' "$c/grep.txt")"
    [ -n "$n1" ] && [ "$n2" = "$((n1 + 3))" ] || { echo "FAIL [7] $e-practices: ARQUIVOS-VARRIDOS $n2 (esperado $n1 + 3: oculto, ignorado e com byte de controle; worktrees fora)"; rc=1; }
  done
  return $rc
}

# ── [8] contador ────────────────────────────────────────────────────────────────────────────────────────────────────
confere_8() {
  local raiz="$1" rc=0 e r d
  d="$TMPD/8-vazio"; mkdir -p "$d"; printf 'nada do universo aqui\n' > "$d/LEIA.txt"
  for e in $ESPS; do
    [ -f "$raiz/skills/$e-practices/scripts/scan.sh" ] || { echo "FAIL [8] $e-practices: scripts/scan.sh ausente"; rc=1; continue; }
    scan "$raiz" "$e" "$d" --root . > "$TMPD/8.txt" 2>/dev/null; r=$?
    [ "$r" -eq 3 ] || { echo "FAIL [8] $e-practices: universo vazio saiu $r (esperado 3)"; rc=1; }
    grep -q '^NADA-EXAMINADO' "$TMPD/8.txt" || { echo "FAIL [8] $e-practices: universo vazio sem a linha NADA-EXAMINADO"; rc=1; }
    if grep -q '^OK ' "$TMPD/8.txt"; then echo "FAIL [8] $e-practices: universo vazio emitiu OK (verde por não ter olhado nada)"; rc=1; fi
    [ "$(tail -1 "$TMPD/8.txt")" = "ARQUIVOS-VARRIDOS 0" ] || { echo "FAIL [8] $e-practices: última linha não é 'ARQUIVOS-VARRIDOS 0'"; rc=1; }
  done
  return $rc
}

confere_9() { relata "$(fm rmq "$1")"; }
confere_10() { relata "$(fm integ "$1")"; }
confere_11() { relata "$(fm refut "$1")"; }
confere_17() { relata "$(fm conflito "$1")"; }

# ── [12] fiação ─────────────────────────────────────────────────────────────────────────────────────────────────────
confere_12() {
  local raiz="$1" rc=0 a e f readme sec agt
  readme="$raiz/agents/README.md"
  sec="$(awk '/^### Dados \(`?data\/`?\)/{s=1; next} s && /^##/{exit} s' "$readme" 2>/dev/null)"
  if [ -z "$sec" ]; then echo "FAIL [12] agents/README.md sem a seção '### Dados (\`data/\`)'"; rc=1
  else
    for a in $AGENTES; do
      printf '%s\n' "$sec" | grep -qF "(./data/$a.md)" || { echo "FAIL [12] agents/README.md: seção Dados sem link para ./data/$a.md"; rc=1; }
      [ -f "$raiz/agents/data/$a.md" ] || { echo "FAIL [12] agents/README.md: link ./data/$a.md não resolve"; rc=1; }
    done
    for f in agents-skills forge-cli; do printf '%s\n' "$sec" | grep -q "$f" || { echo "FAIL [12] agents/README.md: seção Dados sem a nota de projeção fora do Claude Code ($f)"; rc=1; }; done
  fi
  agt="$(awk '/<!-- forge:especialistas-de-dados:inicio -->/{s=1} s{print} /<!-- forge:especialistas-de-dados:fim -->/{exit}' "$raiz/templates/AGENTS.md" 2>/dev/null)"
  if [ -z "$agt" ]; then echo "FAIL [12] templates/AGENTS.md sem o bloco forge:especialistas-de-dados"; rc=1
  else for f in ".forge/agents/data/data-engineer.md" ".forge/skills/data-" "PLANO DE ROTEAMENTO"; do printf '%s\n' "$agt" | grep -qF "$f" || { echo "FAIL [12] templates/AGENTS.md: bloco de dados sem '$f'"; rc=1; }; done
  fi
  for p in backend-java-relational backend-python-relational backend-dotnet-relational backend-node-postgres; do
    grep -q 'data-relational-practices' "$raiz/capabilities/$p/PROFILE.md" 2>/dev/null || { echo "FAIL [12] capabilities/$p/PROFILE.md não aponta data-relational-practices"; rc=1; }
  done
  grep -q 'Hooks de frontmatter de agente' "$WS/contracts/claude-adapter-contract.md" && grep -qF '|| exit 2' "$WS/contracts/claude-adapter-contract.md" \
    || { echo "FAIL [12] contracts/claude-adapter-contract.md sem a cláusula aditiva do C5 (hooks de frontmatter de agente com '|| exit 2')"; rc=1; }
  if [ ! -d "$WS/plugin/forge" ]; then echo "FAIL [12] plugin/forge ausente — o espelho do plugin não pode ser conferido"; rc=1
  elif [ -n "$(cd "$WS/plugin/forge" && find . \( -path '*data-engineer*' -o -path '*data-*-practices*' \) -print 2>/dev/null | head -1)" ]; then
    echo "FAIL [12] plugin/forge carrega agente ou skill de dados (o plugin só carrega commands)"; rc=1
  fi
  # Mesmo critério do check de vazamento do doctor.sh: arquivos sob /scripts/ ficam fora (o scan.sh cita
  # .claude/worktrees para excluí-lo do universo, que é uso funcional, não vazamento de adapter).
  for f in $( { find "$raiz/agents/data" "$raiz"/skills/data-*-practices -type f 2>/dev/null; [ -f "$raiz/agents/README.md" ] && echo "$raiz/agents/README.md"; } | grep -v '/scripts/'); do
    grep -aq '\.claude/' "$f" && { echo "FAIL [12] ${f#"$raiz"/} contém '.claude/' (check de vazamento do doctor)"; rc=1; }
  done
  local disp="$raiz/skills/capability-dispatcher/SKILL.md"
  local revs="$raiz/agents/code-review/node-reviewer.md $raiz/agents/code-review/java-reviewer.md $raiz/agents/code-review/python-reviewer.md $raiz/agents/code-review/dotnet-reviewer.md $raiz/agents/review/platform-reviewer.md"
  if [ "$FIACAO_EVALS100" = "pendente" ]; then
    for f in $disp $revs; do
      [ -f "$f" ] || continue
      if grep -qE 'data-engineer|data-[a-z-]+-practices' "$f"; then echo "FAIL [12] ${f#"$raiz"/} já cita os especialistas de dados com FIACAO_EVALS100=pendente — edite só depois do merge da evals-100 (design §2.8) e vire a chave para 'ativa'"; rc=1; fi
    done
    PENDENTES="$PENDENTES [12]capability-dispatcher+revisores(TASK-12,TASK-13:aguardam-merge-da-evals-100)"
    echo "PENDENTE [12] capability-dispatcher e os cinco revisores: fiação aguarda o merge da frente evals-100 (TASK-12 e TASK-13); conferido que continuam intocados"
  else
    for e in $ESPS; do grep -q "$e-practices" "$disp" || { echo "FAIL [12] capability-dispatcher sem $e-practices"; rc=1; }; done
    grep -q 'data-engineer' "$disp" || { echo "FAIL [12] capability-dispatcher sem data-engineer"; rc=1; }
    local d_tronco d_agora
    d_tronco="$(git -C "$WS" show origin/develop:template/.forge/skills/capability-dispatcher/SKILL.md 2>/dev/null | awk 'NR==1{next} /^---/{exit} {print}' | awk '/^description:/{s=1} s&&/^[a-z_]+:/&&!/^description:/{exit} s')"
    d_agora="$(awk 'NR==1{next} /^---/{exit} {print}' "$disp" | awk '/^description:/{s=1} s&&/^[a-z_]+:/&&!/^description:/{exit} s')"
    if [ -z "$d_tronco" ]; then echo "NAO-VERIFICADO [12] origin/develop indisponível — description do dispatcher não comparada"; NAOVERIF=$((NAOVERIF + 1))
    elif [ "$d_tronco" != "$d_agora" ]; then echo "FAIL [12] capability-dispatcher: description mudou em relação ao tronco (design §3.2 item 4)"; rc=1; fi
    for f in $revs; do
      grep -q 'data-engineer' "$f" && grep -qE 'data-[a-z-]+-practices/scripts/scan\.sh' "$f" || { echo "FAIL [12] ${f#"$raiz"/} não cita data-engineer e um data-*-practices/scripts/scan.sh"; rc=1; }
    done
  fi
  return $rc
}

# ── [13] projeção numa instalação real ──────────────────────────────────────────────────────────────────────────────
INST=""
instalar() { # instalar <dir> — installer/install.sh com os adapters claude e agents-skills
  local t="$1"
  mkdir -p "$t"; git -C "$t" init -q 2>/dev/null
  git -C "$t" config user.email "fixture@w250.test"; git -C "$t" config user.name "fixture w250"
  bash "$WS/installer/install.sh" --target "$t" --source "$TEMPLATE" --adapters claude,agents-skills --slug w250 --name W250 --desc "fixture do w250" > "$t.log" 2>&1
}
confere_13() {
  local rc=0 t a e n
  t="$TMPD/13-inst"; instalar "$t" || { echo "FAIL [13] installer/install.sh falhou:"; tail -5 "$t.log" | sed 's/^/      /'; return 1; }
  INST="$t"
  n=0; for a in $AGENTES; do if [ -f "$t/.claude/agents/data/$a.md" ]; then n=$((n + 1)); else echo "FAIL [13] .claude/agents/data/$a.md não projetado"; rc=1; fi; done
  for e in $ESPS; do
    for d in .claude/skills .agents/skills; do
      [ -f "$t/$d/$e-practices/SKILL.md" ] || { echo "FAIL [13] $d/$e-practices/SKILL.md não projetado"; rc=1; }
      [ -f "$t/$d/$e-practices/scripts/scan.sh" ] || { echo "FAIL [13] $d/$e-practices/scripts/scan.sh não projetado"; rc=1; }
    done
  done
  for s in data-agent-allowlist.sh data-agent-bash-guard.sh; do
    [ -x "$t/.forge/scripts/$s" ] || { echo "FAIL [13] .forge/scripts/$s ausente ou não executável na instalação"; rc=1; }
    cmp -s "$t/.forge/scripts/$s" "$TEMPLATE/scripts/$s" || { echo "FAIL [13] .forge/scripts/$s instalado difere do template"; rc=1; }
  done
  grep -qF '.forge/agents/data/data-engineer.md' "$t/AGENTS.md" 2>/dev/null || { echo "FAIL [13] AGENTS.md gerado sem a seção de especialistas de dados"; rc=1; }
  [ "$n" -eq 7 ] || rc=1
  return $rc
}

# ── [16] hook de allowlist — alvo e canal ───────────────────────────────────────────────────────────────────────────
json_agent() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"%s","prompt":"x","description":"x"}}' "$1"; }
roda_hook() { # roda_hook <script> <entrada-json> [PATH] — imprime "rc<TAB>stderr"
  local s="$1" j="$2" p="${3:-$PATH}" r err
  err="$(printf '%s' "$j" | env PATH="$p" bash "$s" 2>&1 >/dev/null)"; r=$?
  printf '%s\t%s' "$r" "$err"
}
roda_canal() { # roda_canal <projeto> <comando> <entrada-json> — como o Claude Code executa hook de comando
  local proj="$1" cmd="$2" j="$3" r
  printf '%s' "$j" | CLAUDE_PROJECT_DIR="$proj" sh -c "$cmd" >/dev/null 2>"$TMPD/canal.err"; r=$?
  echo "$r"
}
PATH_SEM_NODE=""
montar_sem_node() { PATH_SEM_NODE="$TMPD/sem-node"; mkdir -p "$PATH_SEM_NODE"; local u p; for u in bash sh cat grep sed tr; do p="$(command -v "$u")" && ln -sf "$p" "$PATH_SEM_NODE/$u"; done; }
confere_16() {
  local raiz="$1" rc=0 s res r err e aceitos=0 negados=0 cmd proj
  s="$raiz/scripts/data-agent-allowlist.sh"
  [ -f "$s" ] || { echo "FAIL [16] scripts/data-agent-allowlist.sh ausente"; return 1; }
  for e in $ESPS; do
    res="$(roda_hook "$s" "$(json_agent "$e")")"; r="${res%%	*}"; err="${res#*	}"
    if [ "$r" -eq 0 ]; then aceitos=$((aceitos + 1)); else echo "FAIL [16] allowlist negou o especialista $e (rc $r)"; rc=1; fi
    printf '%s' "$err" | grep -qF "data-agent-allowlist: $e" || { echo "FAIL [16] allowlist não gravou o sinal positivo 'data-agent-allowlist: $e' na saída de erro"; rc=1; }
  done
  for e in general-purpose task-coder data-inventado; do
    res="$(roda_hook "$s" "$(json_agent "$e")")"; r="${res%%	*}"; err="${res#*	}"
    if [ "$r" -eq 2 ] && printf '%s' "$err" | grep -qF "$e"; then negados=$((negados + 1)); else echo "FAIL [16] allowlist aceitou ou não nomeou o tipo fora dos seis: $e (rc $r)"; rc=1; fi
  done
  montar_sem_node
  for caso in malformado sem-campo sem-node; do
    case "$caso" in
      malformado) res="$(roda_hook "$s" '{"tool_input": {"subagent_type": ')" ;;
      sem-campo) res="$(roda_hook "$s" '{"tool_name":"Agent","tool_input":{"prompt":"x"}}')" ;;
      sem-node) res="$(roda_hook "$s" "$(json_agent data-cache)" "$PATH_SEM_NODE")" ;;
    esac
    r="${res%%	*}"
    if [ "$r" -eq 2 ]; then negados=$((negados + 1)); else echo "FAIL [16] allowlist não é fail-closed com $caso (rc $r, esperado 2)"; rc=1; fi
  done
  # canal: o comando real do frontmatter, por sh -c, com CLAUDE_PROJECT_DIR numa instalação com e sem o script.
  cmd="$(W250_YAML="$YAML_MOD" node "$TMPD/fm.cjs" hookcmd "$raiz" "$raiz/agents/data/data-engineer.md" Agent 2>/dev/null)"
  if [ -z "$cmd" ]; then
    if [ -z "$YAML_MOD" ]; then echo "NAO-VERIFICADO [16] canal: pacote yaml ausente"; NAOVERIF=$((NAOVERIF + 1)); else echo "FAIL [16] canal: data-engineer.md sem comando de hook Agent|Task"; rc=1; fi
  else
    proj="$TMPD/16-proj"; rm -rf "$proj"; mkdir -p "$proj/.forge/scripts"; cp "$s" "$proj/.forge/scripts/"
    r="$(roda_canal "$proj" "$cmd" "$(json_agent general-purpose)")"; [ "$r" -eq 2 ] || { echo "FAIL [16] canal com o script presente: general-purpose saiu $r (esperado 2)"; rc=1; }
    r="$(roda_canal "$proj" "$cmd" "$(json_agent data-streaming)")"; [ "$r" -eq 0 ] || { echo "FAIL [16] canal com o script presente: data-streaming saiu $r (esperado 0)"; rc=1; }
    grep -qF 'data-agent-allowlist: data-streaming' "$TMPD/canal.err" || { echo "FAIL [16] canal: sem o sinal positivo de execução do script instalado"; rc=1; }
    rm -f "$proj/.forge/scripts/data-agent-allowlist.sh"
    r="$(roda_canal "$proj" "$cmd" "$(json_agent general-purpose)")"; [ "$r" -eq 2 ] || { echo "FAIL [16] canal com o script removido: general-purpose saiu $r (esperado 2) — o hook precisa terminar em '|| exit 2'"; rc=1; }
    r="$(roda_canal "$proj" "$cmd" "$(json_agent data-streaming)")"; [ "$r" -eq 2 ] || { echo "FAIL [16] canal com o script removido: especialista saiu $r (esperado 2) — sem o script o canal precisa fechar"; rc=1; }
  fi
  [ "$aceitos" -eq 6 ] && [ "$negados" -ge 5 ] || { echo "FAIL [16] contador de controle: $aceitos aceito(s) e $negados negado(s) examinados (esperados 6 e >= 5)"; rc=1; }
  return $rc
}

# ── [18] guarda de Bash — alvo e canal ──────────────────────────────────────────────────────────────────────────────
json_bash() { node -e 'process.stdout.write(JSON.stringify({tool_name:"Bash",tool_input:{command:process.argv[1]}}))' "$1"; }
confere_18() {
  local raiz="$1" rc=0 s res r err aceitos=0 negados=0 c cmd proj
  s="$raiz/scripts/data-agent-bash-guard.sh"
  [ -f "$s" ] || { echo "FAIL [18] scripts/data-agent-bash-guard.sh ausente"; return 1; }
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    res="$(roda_hook "$s" "$(json_bash "$c")")"; r="${res%%	*}"
    if [ "$r" -eq 0 ]; then aceitos=$((aceitos + 1)); else echo "FAIL [18] guarda negou comando do protocolo: $c (rc $r)"; rc=1; fi
  done <<'EOF'
bash .forge/skills/data-cache-practices/scripts/scan.sh --root src --max 5
bash .forge/scripts/check-data-governance.sh --path src/a.ts
EOF
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    res="$(roda_hook "$s" "$(json_bash "$c")")"; r="${res%%	*}"; err="${res#*	}"
    if [ "$r" -eq 2 ]; then negados=$((negados + 1)); else echo "FAIL [18] guarda aceitou comando fora do protocolo: $c (rc $r)"; rc=1; fi
  done <<'EOF'
bash .forge/skills/data-cache-practices/scripts/scan.sh --root src --json out.json
bash .forge/skills/data-cache-practices/scripts/scan.sh --root src > x
bash .forge/skills/data-cache-practices/scripts/scan.sh --root src>x
bash .forge/skills/data-cache-practices/scripts/scan.sh --root src >> x
bash .forge/skills/data-cache-practices/scripts/scan.sh --root src>>x
bash .forge/skills/data-cache-practices/scripts/scan.sh --root src; rm -rf x
bash .forge/skills/data-cache-practices/scripts/scan.sh --root src && git commit -m x
bash .forge/skills/data-cache-practices/scripts/scan.sh --root src | tee x
bash .forge/skills/data-cache-practices/scripts/scan.sh --root $(touch x)
bash .forge/skills/data-cache-practices/scripts/scan.sh --root `touch x`
sed -i s/a/b/ src/a.ts
git add .
bash .forge/scripts/doctor.sh
bash .forge/skills/data-cache-practices/scripts/scan.sh --root 'src dir'
EOF
  montar_sem_node
  for caso in malformado sem-campo sem-node; do
    case "$caso" in
      malformado) res="$(roda_hook "$s" '{"tool_input": {"command": ')" ;;
      sem-campo) res="$(roda_hook "$s" '{"tool_name":"Bash","tool_input":{}}')" ;;
      sem-node) res="$(roda_hook "$s" "$(json_bash 'bash .forge/scripts/check-data-governance.sh --path src')" "$PATH_SEM_NODE")" ;;
    esac
    r="${res%%	*}"
    if [ "$r" -eq 2 ]; then negados=$((negados + 1)); else echo "FAIL [18] guarda não é fail-closed com $caso (rc $r)"; rc=1; fi
  done
  cmd="$(W250_YAML="$YAML_MOD" node "$TMPD/fm.cjs" hookcmd "$raiz" "$raiz/agents/data/data-cache.md" Bash 2>/dev/null)"
  if [ -z "$cmd" ]; then
    if [ -z "$YAML_MOD" ]; then echo "NAO-VERIFICADO [18] canal: pacote yaml ausente"; NAOVERIF=$((NAOVERIF + 1)); else echo "FAIL [18] canal: data-cache.md sem comando de hook Bash"; rc=1; fi
  else
    proj="$TMPD/18-proj"; rm -rf "$proj"; mkdir -p "$proj/.forge/scripts"; cp "$s" "$proj/.forge/scripts/"
    r="$(roda_canal "$proj" "$cmd" "$(json_bash 'git add .')")"; [ "$r" -eq 2 ] || { echo "FAIL [18] canal com o script presente: 'git add .' saiu $r (esperado 2)"; rc=1; }
    r="$(roda_canal "$proj" "$cmd" "$(json_bash 'bash .forge/scripts/check-data-governance.sh --path src')")"; [ "$r" -eq 0 ] || { echo "FAIL [18] canal com o script presente: comando do protocolo saiu $r (esperado 0)"; rc=1; }
    grep -qF 'data-agent-bash-guard:' "$TMPD/canal.err" || { echo "FAIL [18] canal: sem o sinal positivo de execução do guarda instalado"; rc=1; }
    rm -f "$proj/.forge/scripts/data-agent-bash-guard.sh"
    r="$(roda_canal "$proj" "$cmd" "$(json_bash 'bash .forge/scripts/check-data-governance.sh --path src')")"; [ "$r" -eq 2 ] || { echo "FAIL [18] canal com o script removido saiu $r (esperado 2)"; rc=1; }
  fi
  [ "$aceitos" -eq 2 ] && [ "$negados" -ge 12 ] || { echo "FAIL [18] contador de controle: $aceitos aceito(s) e $negados negado(s) (esperados 2 e >= 12)"; rc=1; }
  return $rc
}

# ── [19] forge update ───────────────────────────────────────────────────────────────────────────────────────────────
confere_19() {
  local rc=0 t antes a e rel h
  t="$TMPD/19-inst"; instalar "$t" || { echo "FAIL [19] installer/install.sh falhou"; return 1; }
  rm -rf "$t/.forge/agents/data" "$t"/.forge/skills/data-*-practices "$t/.claude/agents/data" "$t"/.claude/skills/data-*-practices "$t"/.agents/skills/data-*-practices
  rm -f "$t/.forge/scripts/data-agent-allowlist.sh" "$t/.forge/scripts/data-agent-bash-guard.sh"
  awk '/<!-- forge:especialistas-de-dados:inicio -->/{s=1} !s{print} /<!-- forge:especialistas-de-dados:fim -->/{s=0}' "$t/.forge/templates/AGENTS.md" > "$t/agents.tmp" && mv "$t/agents.tmp" "$t/.forge/templates/AGENTS.md"
  # simula a versão anterior: lock com o hash do templates/AGENTS.md sem a seção (o que a versão anterior instalou).
  mkdir -p "$t/.forge/cache"; h="$(node -e 'process.stdout.write(require("crypto").createHash("sha256").update(require("fs").readFileSync(process.argv[1])).digest("hex"))' "$t/.forge/templates/AGENTS.md")"
  printf '# lock sintético do w250\n%s  templates/AGENTS.md\n' "$h" > "$t/.forge/cache/machinery.lock"
  perl -0pi -e 's/template_version: "[^"]*"/template_version: "0.0.1-old"/' "$t/.forge/forge.yaml"
  antes="$( { find "$t/.forge/agents/data" "$t"/.forge/skills/data-*-practices "$t/.forge/scripts/data-agent-allowlist.sh" "$t/.forge/scripts/data-agent-bash-guard.sh" -type f 2>/dev/null; grep -l 'forge:especialistas-de-dados' "$t/.forge/templates/AGENTS.md" 2>/dev/null; } | wc -l | tr -d ' ')"
  [ "$antes" -eq 0 ] || { echo "FAIL [19] controle: a instalação simulada ainda tem $antes arquivo(s) de dados antes do update"; return 1; }
  node "$WS/bin/forge.mjs" update --target "$t" --no-plugin --source "$TEMPLATE" > "$t.update.log" 2>&1 || { echo "FAIL [19] forge update falhou:"; tail -8 "$t.update.log" | sed 's/^/      /'; return 1; }
  for rel in $(cd "$TEMPLATE" && find agents/data skills/data-*-practices scripts/data-agent-allowlist.sh scripts/data-agent-bash-guard.sh templates/AGENTS.md -type f 2>/dev/null | LC_ALL=C sort); do
    cmp -s "$TEMPLATE/$rel" "$t/.forge/$rel" || { echo "FAIL [19] depois do update .forge/$rel não é byte-idêntico ao template"; rc=1; }
  done
  for a in $AGENTES; do [ -f "$t/.claude/agents/data/$a.md" ] || { echo "FAIL [19] depois do update o sync não projetou .claude/agents/data/$a.md"; rc=1; }; done
  for e in $ESPS; do [ -f "$t/.claude/skills/$e-practices/SKILL.md" ] || { echo "FAIL [19] depois do update o sync não projetou .claude/skills/$e-practices"; rc=1; }; done
  grep -qF '.forge/agents/data/data-engineer.md' "$t/AGENTS.md" || { echo "FAIL [19] AGENTS.md regenerado sem a seção de especialistas de dados"; rc=1; }
  return $rc
}

# ── [15] evals ──────────────────────────────────────────────────────────────────────────────────────────────────────
confere_15() {
  relata "$(W250_TOPO="$EVALS_CAMPOS_TOPO" W250_CASO="$EVALS_CAMPOS_CASO" W250_REGRA_TXT="$REGRA_INTEGRACAO_TEXTO" node "$TMPD/evals.cjs" "$WS")"
}

# ── [20] PBT diferencial do guarda e da allowlist ───────────────────────────────────────────────────────────────────
confere_20() {
  local raiz="$1" rc=0 d semente idx tipo esp rot r script n=0 falhou=0
  semente="${W250_SEED:-250926}"
  d="$TMPD/20"; mkdir -p "$d"
  node "$TMPD/pbt.mjs" "$TEMPLATE/scripts/lib/pbt.mjs" "$d" "$semente" > "$d/geracao.txt" || { echo "FAIL [20] gerador de casos falhou"; return 1; }
  [ -f "$raiz/scripts/data-agent-bash-guard.sh" ] && [ -f "$raiz/scripts/data-agent-allowlist.sh" ] || { echo "FAIL [20] scripts de hook ausentes"; return 1; }
  while IFS='	' read -r idx tipo esp rot; do
    [ -n "$idx" ] || continue
    if [ "$tipo" = "guard" ]; then script="$raiz/scripts/data-agent-bash-guard.sh"; else script="$raiz/scripts/data-agent-allowlist.sh"; fi
    bash "$script" < "$d/caso-$idx.json" >/dev/null 2>&1; r=$?
    n=$((n + 1))
    if [ "$r" != "$esp" ]; then
      echo "FAIL [20] contraexemplo (semente $semente, caso $idx, $tipo): entrada $rot → rc $r, oráculo esperava $esp"; falhou=1; rc=1
    fi
  done < "$d/esperado.tsv"
  [ "$n" -ge 50 ] || { echo "FAIL [20] só $n caso(s) examinado(s) (mínimo 50)"; rc=1; }
  [ "$falhou" -eq 1 ] || echo "OK [20] PBT: $n casos, semente $semente ($(cat "$d/geracao.txt")), guarda e allowlist concordam com o oráculo"
  return $rc
}

# ── [14] mutação sobre cópia ────────────────────────────────────────────────────────────────────────────────────────
montar_copia() { # montar_copia <dir> — agents/data, skills/data-*, os dois scripts de hook
  local c="$1"
  rm -rf "$c"; mkdir -p "$c/agents" "$c/skills" "$c/scripts"
  [ -d "$TEMPLATE/agents/data" ] && cp -R "$TEMPLATE/agents/data" "$c/agents/"
  for e in $ESPS; do [ -d "$TEMPLATE/skills/$e-practices" ] && cp -R "$TEMPLATE/skills/$e-practices" "$c/skills/"; done
  cp "$TEMPLATE"/scripts/data-agent-*.sh "$c/scripts/" 2>/dev/null
  return 0
}
mutacao() { # mutacao <letra> <arquivo-rel> <perl-subst> <funcao> <alvo-esperado>
  local L="$1" rel="$2" sub="$3" fn="$4" alvo="$5" c="$TMPD/14-copia" out r
  [ -f "$TEMPLATE/$rel" ] || { echo "FAIL [14]($L) alvo da mutação ausente: $rel"; return 1; }
  $fn "$c" > "$TMPD/14-controle.txt" 2>&1 || { echo "FAIL [14]($L) controle: a cópia íntegra já reprova em $fn"; sed 's/^/      /' "$TMPD/14-controle.txt" | head -5; return 1; }
  perl -0pi -e "$sub" "$c/$rel"
  cmp -s "$TEMPLATE/$rel" "$c/$rel" && { echo "FAIL [14]($L) a mutação não alterou $rel (padrão não casou)"; return 1; }
  out="$($fn "$c" 2>&1)"; r=$?
  cp "$TEMPLATE/$rel" "$c/$rel"
  cmp -s "$TEMPLATE/$rel" "$c/$rel" || { echo "FAIL [14]($L) restauração de $rel não é byte-idêntica"; return 1; }
  if [ "$r" -eq 0 ] || ! printf '%s\n' "$out" | grep -q '^FAIL' || ! printf '%s\n' "$out" | grep '^FAIL' | grep -qF -- "$alvo"; then
    echo "FAIL [14]($L) mutação em $rel não fez $fn reprovar nomeando '$alvo' (rc $r)"; printf '%s\n' "$out" | grep '^FAIL' | head -3 | sed 's/^/      /'; return 1
  fi
  $fn "$c" > "$TMPD/14-recontrole.txt" 2>&1 || { echo "FAIL [14]($L) recontrole: a cópia restaurada ainda reprova"; return 1; }
  echo "OK [14]($L) $rel — controle aprova, mutado reprova nomeando '$alvo', restaurado (cmp -s) aprova"
  return 0
}
confere_14() {
  local rc=0 c="$TMPD/14-copia"
  montar_copia "$c"
  mutacao a agents/data/data-engineer.md 's/(Agent\([^)\n]*?),\s*data-cache/$1/' confere_2 data-cache || rc=1
  mutacao b skills/data-streaming-practices/references/antipatterns.md 's/(### RMQ-AP-10 — [^\n]*\n(?:(?!### )[^\n]*\n)*?)- \*\*Correção:\*\*[^\n]*\n/$1/' confere_4 RMQ-AP-10 || rc=1
  mutacao c skills/data-streaming-practices/scripts/scan.sh 's/# >>> RMQ-AP-10\n.*?# <<< RMQ-AP-10\n//s' confere_5 RMQ-AP-10 || rc=1
  mutacao d skills/data-streaming-practices/references/best-practices.md 's/\z/\n- Use `ha-mode: all` para alta disponibilidade.\n/' confere_11 ha-mode || rc=1
  mutacao e scripts/data-agent-allowlist.sh 's/^ACEITOS="/ACEITOS="general-purpose /m' confere_16 general-purpose || rc=1
  mutacao f agents/data/data-engineer.md 's/(data-agent-allowlist\.sh"?)\s*\|\|\s*exit 2/$1/' confere_16 'script removido' || rc=1
  mutacao g scripts/data-agent-bash-guard.sh "s/^ALFABETO='([^']*)-'/ALFABETO='\$1>-'/m" confere_18 'src>x' || rc=1
  return $rc
}

# ── execução ────────────────────────────────────────────────────────────────────────────────────────────────────────
cenario() { # cenario <n> <descrição> <funcao> [args]
  local n="$1" desc="$2" fn="$3" saida r
  shift 3
  echo "[$n] $desc"
  saida="$($fn "$@" 2>&1)"; r=$?
  [ -n "$saida" ] && printf '%s\n' "$saida"
  if printf '%s\n' "$saida" | grep -q '^NAO-VERIFICADO\|^NAOVERIF'; then NAOVERIF=$((NAOVERIF + 1)); fi
  if printf '%s\n' "$saida" | grep -q '^PENDENTE'; then PENDENTES="$PENDENTES [$n]"; fi
  if [ "$r" -ne 0 ]; then FALHAS=$((FALHAS + 1)); echo "FAIL [$n] reprovado"; else echo "OK [$n]"; fi
}

echo "w250 — especialistas de dados (template: $TEMPLATE; yaml: ${YAML_MOD:-ausente}; rg: $(command -v rg >/dev/null 2>&1 && echo presente || echo ausente))"
cenario 0 "universo: sete agentes e seis skills de dados" confere_0 "$TEMPLATE"
cenario 1 "frontmatter válido (--strict-xml e YAML com description)" confere_1 "$TEMPLATE"
cenario 2 "roteamento: Agent(...) com os seis, hook fail-closed, matriz sem nome fantasma" confere_2 "$TEMPLATE"
cenario 3 "especialistas: consultivos, context7 atual, hook de Bash, seções e protocolo" confere_3 "$TEMPLATE"
cenario 4 "skills: três referências, SKILL.md <= 120 linhas, catálogo fechado com cinco rótulos" confere_4 "$TEMPLATE"
cenario 5 "bijeção catálogo × scanner × design" confere_5 "$TEMPLATE"
cenario 6 "detecção, determinismo, contrato de CLI e isolamento" confere_6 "$TEMPLATE"
cenario 7 "portabilidade rg × grep e worktrees aninhados fora" confere_7 "$TEMPLATE"
cenario 8 "contador de controle: universo vazio sai 3" confere_8 "$TEMPLATE"
cenario 9 "RabbitMQ 4.x: subseções, ids contíguos, fatos de plataforma" confere_9 "$TEMPLATE"
cenario 10 "regra de integração, H-02 (a), transporte e checklist transversal" confere_10 "$TEMPLATE"
cenario 11 "nenhuma recomendação refutada fora do catálogo" confere_11 "$TEMPLATE"
cenario 12 "fiação no harness e espelho do plugin" confere_12 "$TEMPLATE"
cenario 13 "projeção numa instalação real" confere_13
cenario 15 "casos de eval no formato skill-creator" confere_15
cenario 16 "hook de allowlist: alvo e canal, fail-closed" confere_16 "$TEMPLATE"
cenario 17 "conflito com rule: bloco CONFLITO e rules da casa" confere_17 "$TEMPLATE"
cenario 18 "guarda de Bash: alvo e canal, fail-closed" confere_18 "$TEMPLATE"
cenario 19 "forge update entrega e projeta os arquivos de dados" confere_19
cenario 20 "PBT diferencial do guarda e da allowlist" confere_20 "$TEMPLATE"
cenario 14 "mutação sobre cópia (sete alvos), com controle e recontrole" confere_14

echo
if [ "$FALHAS" -gt 0 ]; then echo "FAIL w250 — $FALHAS cenário(s) reprovado(s)"; exit 1; fi
if [ "$NAOVERIF" -gt 0 ]; then echo "NAO-VERIFICADO w250 — $NAOVERIF cenário(s) sem dependência; nada reprovou, mas nada disso é aprovação"; exit 127; fi
if [ -n "$PENDENTES" ]; then echo "OK w250 — todos os cenários verdes; pendentes declarados:$PENDENTES"; else echo "OK w250 — todos os cenários verdes"; fi
exit 0
