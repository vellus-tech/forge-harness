#!/usr/bin/env bash
# Gate W180 — enforcement mecânico da stack Node/TypeScript: espelha o w155 (.NET) do lado que
# o ESLint em AST pode provar.
#
# Origem do material (ledger LDG-0061/LDG-0130): três regras ESLint vendorizadas de
# soumatheusgomes/vibe-coding-toolkit (MIT) — `forge-quality/max-lines`,
# `forge-quality/no-direct-console`, `forge-quality/no-direct-data-access`. Cópia própria do
# harness, não dependência de upstream (autor único, repositório de três semanas, sem CI,
# regras escritas num único dia). Pegam o que grep não pega: alias de import
# (`db as database`), import default vs namespace.
#
# A decisão que NÃO se herda: `forge-quality/max-lines` nunca é bloqueante ("error") no
# baseline deste harness — só "warn". Conflita com rules/conventions/code-style.md (tamanho de
# arquivo é smell, não portão), e o próprio material de origem documenta o efeito de fatiamento
# cosmético perto do limite sem resolvê-lo no desenho do gate. O cenário [6] prova as duas
# direções: "error" reprova o --check citando a decisão; "warn" passa.
#
#   [0]  guarda de vacuidade: as fixtures têm defeito de verdade para medir
#   [1]  assets do pack existem, sintaxe válida (node --check), MIT preservado, IDs de regra
#   [2]  `--check` num repo Node sem baseline FALHA e nomeia eslint.config.mjs
#   [3]  `--apply` cria e o `--check` seguinte passa (controle e recontrole)
#   [4]  `--apply` não sobrescreve arquivo existente sem `--force`
#   [5]  severidade por modo: brownfield com código → warn; greenfield vazio → error
#   [6]  a armadilha max-lines: "error" é FAIL citando a decisão; "warn" é OK
#   [7]  no-direct-console ausente/off é FAIL (regra load-bearing); presente é OK
#   [8]  o scanner emite UMA LINHA POR REGRA inclusive quando não acha nada
#   [9]  o scanner acha no fixture sujo e NÃO acha no limpo (controle e recontrole), com arquivo:linha
#   [10] o scanner funciona sem ripgrep no PATH (fallback grep) — portabilidade
#   [11] prova de mutação com cmp: planta 1 defeito num arquivo limpo, scanner acha; restaura
#        por cópia (não por reversão de sed) e prova com cmp que a restauração é byte-a-byte
#   [12] verify.mjs (RuleTester real) passa nas regras vendorizadas; mutação em core-rules.cjs
#        (quebra a detecção de alias) faz verify.mjs FALHAR de verdade; restaurado volta a passar
#   [13] fiação: node-reviewer, verify-build, doctor, forge-init e PROFILE citam a maquinaria nova
#   [14] frontmatter válido nos artefatos novos
#   [15] canal de entrega: harness instalado de verdade, doctor instalado de verdade
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$WS/template/.forge"
PACK="$ROOT/capabilities/backend-node-postgres"
RULES="$PACK/assets/eslint-rules"
BASELINE="$ROOT/scripts/node-baseline.sh"
SCAN="$ROOT/skills/node-quality-scan/scripts/scan.sh"

T="$(mktemp -d /tmp/forge-w180.XXXXXX)"
# Precisa ficar DENTRO do worktree: a resolução de módulo ESM do Node sobe diretório a
# diretório procurando node_modules, e só encontra o `eslint` (devDependency deste repo) se o
# ponto de partida estiver na árvore do worktree. /tmp não chega lá.
TN="$(mktemp -d "$WS/.gate-w180-tmp.XXXXXX")"
trap 'rm -rf "$T" "$TN"' EXIT

fail() { echo "FAIL $*"; exit 1; }

# ── fixtures ────────────────────────────────────────────────────────────────────────────────
# `dirty`: brownfield com os defeitos que nem AST de lint com forge-quality/* reporta.
# `clean`: a MESMA forma de código sem os defeitos, inclusive DOIS implementadores da interface
# (prova que single-impl-interface não acusa falso positivo). Sem o par, um scanner que sempre
# acha passaria no gate.
mk_dirty() {
  local d="$1"; mkdir -p "$d/src"
  cat > "$d/package.json" <<'EOF'
{"name":"fixture","version":"1.0.0"}
EOF
  cat > "$d/src/payment-helper.ts" <<'EOF'
export let counter = 0;

interface IFoo { bar(): void }
class FooImpl implements IFoo { bar() {} }

class PaymentHelper {
  load(id: string): any {
    try {
      doStuff();
    } catch {}
    fs.readFileSync('/tmp/x');
    const now = new Date();
    db.query(`SELECT * FROM orders WHERE id = ${id}`);
    process.env.SECRET;
    new Pool();
    fetchThing().then(r => r);
    return now as any;
  }
}
EOF
}

mk_clean() {
  local d="$1"; mkdir -p "$d/src"
  cat > "$d/package.json" <<'EOF'
{"name":"fixture","version":"1.0.0"}
EOF
  cat > "$d/src/payment-gateway.ts" <<'EOF'
export const counter = { value: 0 };

interface OrderGateway { load(id: string): Promise<Order> }
class PgOrderGateway implements OrderGateway {
  async load(id: string): Promise<Order> {
    try {
      return await doStuff(id);
    } catch (err) {
      throw new DomainError('load failed', { cause: err });
    }
  }
}
class SecondGateway implements OrderGateway {
  async load(id: string): Promise<Order> { return doStuff(id); }
}
EOF
}

# ── [0] guarda de vacuidade ─────────────────────────────────────────────────────────────────
mk_dirty "$T/dirty"; mk_clean "$T/clean"
[ "$(find "$T/dirty" -name '*.ts' | wc -l | tr -d ' ')" -ge 1 ] || fail "[0]: fixture dirty sem .ts"
grep -q 'catch {}' "$T/dirty/src/payment-helper.ts" || fail "[0]: fixture dirty perdeu o defeito"
grep -q 'catch {}' "$T/clean/src/payment-gateway.ts" && fail "[0]: fixture clean não é limpa"
echo "OK [0] fixtures"

# ── [1] assets do pack ──────────────────────────────────────────────────────────────────────
for f in utils.cjs core-rules.cjs index.cjs verify.mjs; do
  [ -f "$RULES/$f" ] || fail "[1]: asset ausente: $RULES/$f"
  node --check "$RULES/$f" 2>&1 || fail "[1]: sintaxe inválida em $RULES/$f"
done
[ -f "$PACK/assets/eslint.config.mjs" ] || fail "[1]: asset ausente: $PACK/assets/eslint.config.mjs"
node --check "$PACK/assets/eslint.config.mjs" 2>&1 || fail "[1]: sintaxe inválida em eslint.config.mjs"
for f in utils.cjs core-rules.cjs verify.mjs; do
  grep -q 'MIT License' "$RULES/$f" || fail "[1]: aviso MIT ausente em $RULES/$f"
  grep -q 'vibe-coding-toolkit' "$RULES/$f" || fail "[1]: origem (vibe-coding-toolkit) não registrada em $RULES/$f"
done
grep -q '"max-lines":' "$RULES/index.cjs" || fail "[1]: index.cjs sem a chave max-lines"
grep -q '"no-direct-console":' "$RULES/index.cjs" || fail "[1]: index.cjs sem a chave no-direct-console"
grep -q '"no-direct-data-access":' "$RULES/index.cjs" || fail "[1]: index.cjs sem a chave no-direct-data-access"
grep -q 'eslint-rules/index\.cjs' "$PACK/assets/eslint.config.mjs" || fail "[1]: eslint.config.mjs não importa o plugin vendorizado"
grep -q '"forge-quality"' "$PACK/assets/eslint.config.mjs" || fail "[1]: eslint.config.mjs não registra sob a chave forge-quality (namespace renomeado)"
grep -qE '"forge-quality/max-lines":[[:space:]]*\["error"' "$PACK/assets/eslint.config.mjs" \
  && fail "[1]: asset materializa max-lines como error — decisão do harness é NÃO bloquear por tamanho"
echo "OK [1] assets"

# ── [2] check sem baseline falha e nomeia o que falta ───────────────────────────────────────
[ -x "$BASELINE" ] || fail "[2]: $BASELINE ausente ou não executável"
out="$(bash "$BASELINE" --root "$T/dirty" --check 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "[2]: --check passou num repo sem eslint.config algum (rc=0)"
grep -qF 'eslint.config.mjs' <<<"$out" || fail "[2]: --check não nomeou eslint.config.mjs no relatório"
echo "OK [2] check vermelho"

# ── [3] apply cria e o check seguinte passa ─────────────────────────────────────────────────
bash "$BASELINE" --root "$T/dirty" --apply >/dev/null 2>&1 || fail "[3]: --apply retornou erro"
[ -f "$T/dirty/eslint.config.mjs" ] || fail "[3]: --apply não criou eslint.config.mjs"
bash "$BASELINE" --root "$T/dirty" --check >/dev/null 2>&1 || fail "[3]: --check ainda falha depois do --apply"
echo "OK [3] apply verde"

# ── [4] apply não sobrescreve sem --force ───────────────────────────────────────────────────
printf '// meu config custom\nexport default [];\n' > "$T/dirty/eslint.config.mjs"
bash "$BASELINE" --root "$T/dirty" --apply >/dev/null 2>&1
grep -q 'meu config custom' "$T/dirty/eslint.config.mjs" || fail "[4]: --apply sobrescreveu arquivo do projeto sem --force"
bash "$BASELINE" --root "$T/dirty" --apply --force >/dev/null 2>&1 || fail "[4]: --apply --force retornou erro"
grep -q 'meu config custom' "$T/dirty/eslint.config.mjs" && fail "[4]: --force não sobrescreveu"
echo "OK [4] não-sobrescrita"

# ── [5] severidade por modo ──────────────────────────────────────────────────────────────────
mkdir -p "$T/green" && printf '{"name":"green"}\n' > "$T/green/package.json"
mk_dirty "$T/brown"
bash "$BASELINE" --root "$T/green" --apply >/dev/null 2>&1 || fail "[5]: apply falhou em greenfield"
bash "$BASELINE" --root "$T/brown" --apply >/dev/null 2>&1 || fail "[5]: apply falhou em brownfield"
grep -qE '"forge-quality/no-direct-console":[[:space:]]*"error"' "$T/green/eslint.config.mjs" \
  || fail "[5]: greenfield não recebeu no-direct-console error"
grep -qE '"forge-quality/no-direct-console":[[:space:]]*"warn"' "$T/brown/eslint.config.mjs" \
  || fail "[5]: brownfield não recebeu no-direct-console warn (adoção inviável)"
echo "OK [5] severidade por modo"

# ── [6] a armadilha max-lines ────────────────────────────────────────────────────────────────
mk_dirty "$T/trap"
bash "$BASELINE" --root "$T/trap" --apply >/dev/null 2>&1
sed 's/"forge-quality\/max-lines": \["warn"/"forge-quality\/max-lines": ["error"/' \
  "$T/trap/eslint.config.mjs" > "$T/trap/eslint.config.mjs.tmp" && mv "$T/trap/eslint.config.mjs.tmp" "$T/trap/eslint.config.mjs"
out="$(bash "$BASELINE" --root "$T/trap" --check 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "[6]: max-lines em error passou no check — a armadilha não é detectada"
grep -qi 'max-lines' <<<"$out" || fail "[6]: relatório não menciona max-lines"
grep -qi 'ledger' <<<"$out" || fail "[6]: relatório não cita a decisão registrada (ledger)"
bash "$BASELINE" --root "$T/dirty" --check >/dev/null 2>&1 || fail "[6]: controle — dirty com max-lines warn devia passar essa checagem"
echo "OK [6] armadilha max-lines"

# ── [7] no-direct-console load-bearing ──────────────────────────────────────────────────────
mk_dirty "$T/console"
bash "$BASELINE" --root "$T/console" --apply >/dev/null 2>&1
sed 's/"forge-quality\/no-direct-console": "warn"/"forge-quality\/no-direct-console": "off"/' \
  "$T/console/eslint.config.mjs" > "$T/console/eslint.config.mjs.tmp" && mv "$T/console/eslint.config.mjs.tmp" "$T/console/eslint.config.mjs"
out="$(bash "$BASELINE" --root "$T/console" --check 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || fail "[7]: no-direct-console off passou no check"
grep -qi 'no-direct-console' <<<"$out" || fail "[7]: relatório não menciona no-direct-console"
echo "OK [7] no-direct-console load-bearing"

# ── [8] uma linha por regra, inclusive sem achado ───────────────────────────────────────────
[ -x "$SCAN" ] || fail "[8]: $SCAN ausente ou não executável"
dirty_out="$(bash "$SCAN" --root "$T/dirty" 2>&1)"
clean_out="$(bash "$SCAN" --root "$T/clean" 2>&1)"
n_dirty="$(grep -cE '^(OK|FOUND) ' <<<"$dirty_out")"
n_clean="$(grep -cE '^(OK|FOUND) ' <<<"$clean_out")"
[ "$n_dirty" -ge 10 ] || fail "[8]: scanner emitiu só $n_dirty linhas de regra (esperado >= 10)"
[ "$n_dirty" = "$n_clean" ] \
  || fail "[8]: regra omitida quando não há achado ($n_dirty no sujo vs $n_clean no limpo) — omissão invisível"
grep -q '^OK ' <<<"$clean_out" || fail "[8]: fixture limpa não produziu nenhuma linha OK"
echo "OK [8] relatório completo ($n_dirty regras)"

# ── [9] acha no sujo, não acha no limpo ─────────────────────────────────────────────────────
for r in empty-catch floating-promise sync-fs-blocking sql-interpolation new-pg-client \
         process-env-direct date-now explicit-any generic-name mutable-module-state \
         single-impl-interface; do
  grep -q "^FOUND $r" <<<"$dirty_out" || fail "[9]: regra '$r' não achou o defeito plantado"
  grep -q "^FOUND $r" <<<"$clean_out" && fail "[9]: regra '$r' acusou falso positivo na fixture limpa"
done
grep -q 'payment-helper.ts' <<<"$dirty_out" || fail "[9]: achado sem arquivo:linha — não é auditável"
bash "$SCAN" --root "$T/dirty" >/dev/null 2>&1 && fail "[9]: scanner devolveu rc=0 com achados"
bash "$SCAN" --root "$T/clean" >/dev/null 2>&1 || fail "[9]: scanner devolveu rc!=0 sem achado nenhum"
echo "OK [9] controle e recontrole"

# ── [10] sem ripgrep no PATH ────────────────────────────────────────────────────────────────
# `command -v` direto, sem `env -i`: `env -i PATH=... command -v <x>` só funciona onde `command`
# também existe como BINÁRIO externo (macOS tem /usr/bin/command; Debian/Ubuntu não — lá
# `command` é builtin puro, `env` não invoca builtin, e o `command -v` fica mudo para TODAS as
# ferramentas, o stub nasce vazio, e nem o `bash` do stub é resolvido depois). Mesmo idioma do
# w155 (dotnet), já portátil nos dois SOs.
stub="$T/stubbin"; mkdir -p "$stub"
for c in bash grep sed awk find cat printf sort head wc tr; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$stub/$c"
done
norg_out="$(PATH="$stub" bash "$SCAN" --root "$T/dirty" 2>&1)"
grep -q '^FOUND empty-catch' <<<"$norg_out" || fail "[10]: sem rg no PATH o scanner deixa de achar (falso verde)"
[ "$(grep -cE '^(OK|FOUND) ' <<<"$norg_out")" = "$n_dirty" ] || fail "[10]: sem rg o scanner perde regras"
echo "OK [10] portabilidade"

# ── [11] prova de mutação com cmp: controle → mutante → recontrole ─────────────────────────
# Lição já paga por este harness (feedback-mutacao-fantasma-restore): prova de mutação sem
# recontrole não prova nada — um restore() quebrado pode deixar o arquivo mutado e o teste
# "passar" por coincidência. Aqui a restauração é por CÓPIA (nunca por reversão de sed) e o cmp
# prova, byte a byte, que o arquivo pós-restore é idêntico ao controle original.
mkdir -p "$T/mutctl/src"
printf '{"name":"m"}\n' > "$T/mutctl/package.json"
cp "$T/clean/src/payment-gateway.ts" "$T/mutctl/src/target.ts"
cp "$T/mutctl/src/target.ts" "$T/mutctl/src/target.ts.control"

ctl_out="$(bash "$SCAN" --root "$T/mutctl" 2>&1)"
grep -q '^FOUND sync-fs-blocking' <<<"$ctl_out" && fail "[11]: controle já nasce com o defeito — fixture contaminada"

# muta: planta EXATAMENTE um defeito nunca antes presente na fixture
printf "\nfunction touch() { fs.readFileSync('/tmp/mut'); }\n" >> "$T/mutctl/src/target.ts"
mut_out="$(bash "$SCAN" --root "$T/mutctl" 2>&1)"
grep -q '^FOUND sync-fs-blocking' <<<"$mut_out" || fail "[11]: mutante não foi detectado pelo scanner"

# recontrole: restaura por CÓPIA do controle salvo, nunca por sed/reversão de texto
cp "$T/mutctl/src/target.ts.control" "$T/mutctl/src/target.ts"
cmp -s "$T/mutctl/src/target.ts" "$T/mutctl/src/target.ts.control" \
  || fail "[11]: restauração não é byte-a-byte idêntica ao controle (cmp)"
recon_out="$(bash "$SCAN" --root "$T/mutctl" 2>&1)"
grep -q '^FOUND sync-fs-blocking' <<<"$recon_out" && fail "[11]: recontrole ainda acusa o defeito — restauração fantasma"
[ "$ctl_out" = "$recon_out" ] || fail "[11]: saída do recontrole diverge do controle original — estado não foi realmente restaurado"
echo "OK [11] mutação com controle e recontrole (cmp)"

# ── [12] verify.mjs — RuleTester real, não é bash que decide se a regra está certa ─────────
have_eslint=0
(cd "$WS" && node -e 'require.resolve("eslint")') >/dev/null 2>&1 && have_eslint=1
if [ "$have_eslint" != "1" ]; then
  fail "[12]: pacote 'eslint' não resolvível a partir do worktree — rode 'npm install' (devDependency) antes do gate"
fi
node "$RULES/verify.mjs" >/tmp/w180-verify-ok.log 2>&1
vrc=$?
[ "$vrc" -eq 0 ] || { cat /tmp/w180-verify-ok.log; fail "[12]: verify.mjs falhou nas regras vendorizadas intactas (rc=$vrc)"; }
grep -q 'forge-quality/max-lines: ok' /tmp/w180-verify-ok.log || fail "[12]: verify.mjs não confirmou max-lines"
grep -q 'forge-quality/no-direct-console: ok' /tmp/w180-verify-ok.log || fail "[12]: verify.mjs não confirmou no-direct-console"
grep -q 'forge-quality/no-direct-data-access: ok' /tmp/w180-verify-ok.log || fail "[12]: verify.mjs não confirmou no-direct-data-access"

# mutação: quebra a detecção de alias de import (db as database) — exatamente o que o ledger
# cita como o que grep não pega e o AST pega. cópia vive DENTRO do worktree (TN), porque a
# resolução de módulo ESM do "eslint" sobe a árvore de diretórios a partir daqui.
mkdir -p "$TN/mut-rules"
cp "$RULES/utils.cjs" "$RULES/core-rules.cjs" "$RULES/index.cjs" "$RULES/verify.mjs" "$TN/mut-rules/"
cp "$TN/mut-rules/core-rules.cjs" "$TN/mut-rules/core-rules.cjs.control"
sed 's/specifier\.imported\.name)/"never-matches-anything")/' "$TN/mut-rules/core-rules.cjs.control" > "$TN/mut-rules/core-rules.cjs"
grep -q 'never-matches-anything' "$TN/mut-rules/core-rules.cjs" || fail "[12]: mutação de core-rules.cjs não foi aplicada"

node "$TN/mut-rules/verify.mjs" >/tmp/w180-verify-mut.log 2>&1
mut_vrc=$?
[ "$mut_vrc" -ne 0 ] || fail "[12]: verify.mjs passou com a detecção de alias quebrada — o self-teste não é sensível à mutação"
grep -qi 'forbidden\|AssertionError\|expected' /tmp/w180-verify-mut.log || fail "[12]: falha do verify.mjs mutante sem evidência de asserção (RuleTester real)"

# recontrole: restaura por cópia e prova com cmp
cp "$TN/mut-rules/core-rules.cjs.control" "$TN/mut-rules/core-rules.cjs"
cmp -s "$TN/mut-rules/core-rules.cjs" "$RULES/core-rules.cjs" \
  || fail "[12]: core-rules.cjs restaurado diverge do original do pack (cmp)"
node "$TN/mut-rules/verify.mjs" >/tmp/w180-verify-recon.log 2>&1 \
  || fail "[12]: verify.mjs falhou depois do recontrole (restauração fantasma)"
echo "OK [12] verify.mjs (RuleTester real) com controle e recontrole"

# ── [13] fiação no lifecycle ─────────────────────────────────────────────────────────────────
grep -q 'node-quality-scan' "$ROOT/agents/code-review/node-reviewer.md" \
  || fail "[13]: node-reviewer não invoca a skill determinista"
grep -q 'node-baseline' "$ROOT/agents/code-review/node-reviewer.md" \
  || fail "[13]: node-reviewer não invoca o baseline determinista"
grep -qE '^\s+-\s+Bash\s*$' "$ROOT/agents/code-review/node-reviewer.md" \
  || fail "[13]: node-reviewer sem Bash nas tools (não consegue rodar baseline/scan)"
grep -q 'node-baseline' "$ROOT/skills/verify-build/SKILL.md" \
  || fail "[13]: verify-build não executa node-baseline.sh"
grep -qE '^\s*\$PM exec eslint \.\s*2' "$ROOT/skills/verify-build/SKILL.md" \
  || fail "[13]: verify-build ainda usa eslint com --max-warnings=0 (reprovaria o warn não-bloqueante de max-lines)"
grep -qE '\$PM exec eslint[^|]*--max-warnings' "$ROOT/skills/verify-build/SKILL.md" \
  && fail "[13]: verify-build ainda contém --max-warnings na linha de lint Node"
grep -q 'NODE-BASELINE' "$ROOT/skills/verify-build/SKILL.md" \
  || fail "[13]: verify-build sem o finding NODE-BASELINE na tabela"
grep -q 'node-baseline' "$ROOT/scripts/doctor.sh" \
  || fail "[13]: doctor não confere o baseline de lint Node"
grep -q 'node-baseline' "$WS/installer/forge-init.md" \
  || fail "[13]: /forge:init não materializa o baseline em projeto Node"
grep -q 'forge-quality' "$PACK/PROFILE.md" \
  || fail "[13]: PROFILE.md não documenta as regras forge-quality/*"
grep -qi 'LDG-0061\|LDG-0130' "$PACK/PROFILE.md" \
  || fail "[13]: PROFILE.md não referencia a decisão registrada sobre max-lines"
echo "OK [13] fiação"

# ── [14] frontmatter ────────────────────────────────────────────────────────────────────────
bash "$ROOT/scripts/validate-frontmatter.sh" \
  "$ROOT/skills/node-quality-scan" \
  "$ROOT/agents/code-review/node-reviewer.md" | tail -1 | grep -q '^OK' \
  || fail "[14]: frontmatter inválido nos artefatos novos"
echo "OK [14] frontmatter"

# ── [15] canal de entrega: harness instalado de verdade, doctor de verdade ───────────────────
I="$T/install"; mkdir -p "$I/src"
printf '{"name":"fixture","version":"1.0.0"}\n' > "$I/package.json"
printf 'export function noop(): void {}\n' > "$I/src/noop.ts"
"$WS/installer/install.sh" --target "$I" --slug fixture --name Fixture --desc fixture --adapters claude >/dev/null 2>&1 \
  || fail "[15]: instalação do harness falhou no alvo Node"
[ -x "$I/.forge/scripts/node-baseline.sh" ] || fail "[15]: node-baseline.sh não foi instalado no alvo"
[ -f "$I/.forge/capabilities/backend-node-postgres/assets/eslint.config.mjs" ] \
  || fail "[15]: assets do pack não foram instalados no alvo"
[ -x "$I/.claude/skills/node-quality-scan/scripts/scan.sh" ] \
  || fail "[15]: scan.sh não chegou executável ao adapter (skill projetada sem o motor não roda)"

out="$(cd "$I" && bash .forge/scripts/doctor.sh --report 2>&1)"; status=$?
grep -q 'baseline de qualidade' <<<"$out" || fail "[15]: doctor instalado não reporta o baseline de qualidade Node"
[ "$status" -eq 0 ] || fail "[15]: doctor passou a reprovar por causa do baseline (deve informar, não bloquear: rc=$status)"

bash "$I/.forge/scripts/node-baseline.sh" --root "$I" --apply >/dev/null 2>&1 \
  || fail "[15]: apply falhou a partir do harness instalado"
out2="$(cd "$I" && bash .forge/scripts/doctor.sh --report 2>&1)"
grep -qE '(✓|OK).*baseline de qualidade' <<<"$out2" \
  || fail "[15]: depois do apply o doctor continua acusando baseline incompleto"
grep -q 'baseline de qualidade incompleto' <<<"$out2" \
  && fail "[15]: doctor não reflete o estado novo — a linha de incompleto sobreviveu ao apply"
echo "OK [15] canal de entrega"

echo "PASS w180-node-enforcement-gate"
