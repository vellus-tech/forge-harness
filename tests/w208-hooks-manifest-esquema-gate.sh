#!/usr/bin/env bash
# Gate W208 — o esquema de coluna do `hooks.manifest`, e o leitor canônico do produtor (LDG-0178).
#
# POR QUE ESTE GATE EXISTE.
# Dois consumidores escreveram, cada um por conta própria, um `hooks.manifest` que declara quais ganchos de `PreToolUse` existem e quais estão fiados — e os dois escolheram esquemas de coluna incompatíveis no campo 4. O `axis-fare-validator` põe `universo` no quarto campo e prosa de justificativa no quinto; o `Axis.PadSimulator` põe `estado` (`armado` ou `retido:<razão>`) no quarto e não tem quinto. O produtor chega em terceiro e precisa ler os dois arquivos como eles estão, sem pedir que ninguém reescreva um byte.
#
# O DANO, medido por cruzamento dos DOIS parsers de produção contra os DOIS manifestos reais.
# O parser do `axis-fare-validator`, aplicado ao manifesto do `Axis.PadSimulator`, fia QUATRO ganchos onde o dono fia DOIS, com rc de sucesso e nenhuma linha de saída, e os dois excedentes são exatamente os dois que o dono reteve com razão medida escrita na linha. O caminho inverso lança, nomeando o gancho e o token. Silencioso ao armar demais, barulhento ao recusar: é essa assimetria que decide o fail-closed do campo 4 no formato marcado, e a projeção fora dele.
#
# O QUE ESTE GATE AFIRMA, em vinte e dois cenários com denominador FIXO.
#
#   [0]  CONTROLE DE INSTRUMENTO — as três fixtures de dialeto existem, são legíveis e têm a forma declarada, E o caminho canônico do módulo sob teste é o esperado. Sem este cenário, um caminho digitado errado produziria o mesmo vermelho que a ausência real da funcionalidade.
#   [1]  o leitor canônico existe e é PURO — importá-lo não escreve no disco nem altera a si mesmo.
#   [2]  FORMATO CANÔNICO — manifesto marcado produz o conjunto de ativos esperado; trocar `armado` por `retido:x` numa linha tira AQUELE gancho e não mexe nos demais.
#   [3]  PROJEÇÃO — manifesto SEM marcador, nas DUAS formas de campo, produz conjunto de ativos igual ao conjunto escrito à mão na fixture, que nunca é rederivado pelo módulo sob teste.
#   [4]  O CAMPO 4 ALHEIO NÃO É LIDO — na fixture de cinco campos, trocar o campo 4 por qualquer coisa não muda o conjunto de ativos, e o conjunto observado precisa ser NÃO VAZIO para que a comparação não passe por vacuidade.
#   [5]  TOKEN DESCONHECIDO É FAIL-CLOSED — no formato marcado, `estado` fora do vocabulário recusa, com código próprio e nomeando o gancho e o token.
#   [6]  `retido:` SECO É MALFORMADO — retenção sem razão recusa; `retido:<razão>` passa.
#   [7]  TERCEIRO ESTADO POR FIAÇÃO ILEGÍVEL — manifesto sem marcador e fiação não legível resolve para "não consegui verificar", nomeando a origem, e não para "tudo ativo" nem "nada ativo".
#   [8]  A PONTE NÃO É GANCHO — em comando encadeado só o ÚLTIMO alvo entra no conjunto, e a regra é estrutural e não por nome de arquivo, provada por um terceiro alvo encadeado com nomes fora do vocabulário `dispatch-*`.
#   [9]  MATCHER SEM ÂNCORA NAS DUAS PONTAS RECUSA — no formato marcado, em TRÊS formas (sem âncora, meio-ancorada à esquerda, meio-ancorada à direita); ancorar as duas pontas faz passar. As duas meio-ancoradas são o que discrimina a guarda real de uma que exija só a abertura.
#   [10] CLASSIFICADOR DE DIALETO — sobre as fixtures DESTE repositório, com piso de dois dialetos distintos e a partição nominal, mais o caso não classificável.
#   [11] VACUIDADE — fiação legível e VAZIA não resolve para "nenhum gancho armado" com sucesso, que é o desarme silencioso que este item existe para impedir, e tem código próprio.
#   [12] OS QUATRO DESFECHOS TÊM CÓDIGOS DISTINTOS DOIS A DOIS — a invariante dos três estados aplicada ao próprio instrumento, e é aqui que o código de "não consegui verificar" é afirmado como VALOR DE RETORNO, num cenário que termina verde.
#   [13] PBT — sobre linhas geradas: nenhuma entrada resolve para ativo sem que o campo 4 seja literalmente `armado`, a leitura é idempotente e não altera o texto, e campo vazio no meio da linha não promove a razão a estado.
#   [14] VACUIDADE CANÔNICA — manifesto MARCADO, bem formado e sem nenhuma linha `armado` não resolve para sucesso com conjunto vazio. É a guarda simétrica à de [11], no leitor do próprio produtor, e ela vivia sem cenário: removê-la deixava os quinze cenários anteriores verdes.
#   [15] AS FORMAS DE COMANDO DA FIAÇÃO — caminho entre aspas e dois ganchos encadeados por ';' produzem a MESMA fiação que a forma simples, e um comando sem alvo `.sh` reconhecível sai por "não consegui verificar" nomeando o comando, nunca por silêncio.
#   [16] O CANAL `avisos` É OBSERVÁVEL — despachante nomeado, gancho fiado sem linha declarada nomeado e NUNCA recusado, chave nomeada desconhecida ignorada e NOMEADA. Piso de três canais.
#   [17] GUARDA DE VERSÃO DO MARCADOR — manifesto marcado como formato 2 recusa nomeando a versão observada, em vez de ser lido com a régua da v1; a versão 1 passa.
#   [18] DECLARAÇÃO DUPLICADA — o mesmo gancho declarado duas vezes recusa nos DOIS modos, nomeando o gancho; declarado uma vez passa nos dois.
#   [19] GUARDAS DE FORMA DA LINHA — aridade canônica, aridade da projeção e campo nomeado fora de 'chave=valor' recusam de forma TIPADA e nomeando a aridade observada, e não por exceção não tratada.
#   [20] O VOCABULÁRIO DO CAMPO 3 — `contrato` fora de `argv`/`stdin-json` recusa no formato marcado nomeando gancho e token, e vira aviso nomeado na projeção. A assimetria é a decisão: o produtor é dono do formato marcado, e não é dono do arquivo que projeta.
#   [21] SENTINELA — o gate publica os contadores e reprova se o número de cenários executados divergir do denominador declarado, ou se algum piso for violado.
#
# O QUE ESTE GATE NÃO FAZ.
# Ele não toca a ponte de despacho `stdin` para `argv` nem o gerador `sync-adapters.mjs`, que são fronteira da Onda L1, não escreve em consumidor nenhum e NÃO faz censo das árvores de consumidor no disco. Censo de árvore externa deixaria esta suíte permanentemente vermelha em qualquer máquina que não seja a do especificador: `run-all.sh` tem exatamente dois desfechos por gate e não há canal de skip para gate, então um terceiro estado por ausência das árvores viraria falha da suíte inteira no CI. O censo das doze árvores permanece como medição da especificação, e o que entra na suíte são as fixtures deste repositório.
#
# SEAM DE MUTAÇÃO.
# `HM_MOD` sobrepõe o caminho do módulo sob teste, e existe para que a prova de mutação rode sobre uma CÓPIA em $TMPDIR e nunca sobre o arquivo rastreado — é a lição de LDG-0175, em que um gate usou arquivo rastreado e distribuído como fixture e não restaurou.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }

MOD_CANONICO="template/.forge/scripts/lib/hooks-manifest.mjs"
MOD="${HM_MOD:-$WS/$MOD_CANONICO}"

DENOMINADOR=22
executados=0
fixtures_examinadas=0
dialetos_classificados=0
canais_de_aviso=0
overall_rc=0

T="$(mktemp -d /tmp/forge-w208.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── driver de node ────────────────────────────────────────────────────────────────────────────
# Um único driver, com subcomando, para que a falha de import seja reportada por CENÁRIO — cada cenário imprime a sua própria mensagem nomeando a propriedade ausente, e não uma falha global de sintaxe do gate.
# A saída é UMA CHAVE POR LINHA, deliberadamente: com tudo numa linha só, `ativos=[...]` é sufixo de `inativos=[...]` e a extração gulosa devolveria o conjunto errado — foi exatamente o que aconteceu na primeira versão deste gate, e o cenário [4] passou por vacuidade comparando dois conjuntos vazios.
cat >"$T/drv.mjs" <<'DRVEOF'
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const MOD = process.env.HM_MOD_ABS;
let hm;
try {
  hm = await import(pathToFileURL(MOD).href);
} catch (e) {
  process.stdout.write(`ERRO-IMPORT: ${e && e.message ? e.message : String(e)}\n`);
  process.exit(3);
}

function req(nome) {
  if (typeof hm[nome] !== 'function' && typeof hm[nome] !== 'object') {
    process.stdout.write(`ERRO-API: exportação ausente '${nome}'\n`);
    process.exit(3);
  }
  return hm[nome];
}

const op = process.argv[2];
const csv = (v) => (Array.isArray(v) ? [...v].sort().join(',') : String(v));

function fiacaoDe(arg) {
  if (arg === '-' || arg === undefined) return null;
  const s = JSON.parse(readFileSync(arg, 'utf8'));
  return (s.hooks && s.hooks.PreToolUse) || [];
}

if (op === 'codigos') {
  const CODIGO = req('CODIGO');
  const DESFECHO = req('DESFECHO');
  for (const k of [DESFECHO.OK, DESFECHO.RECUSA, DESFECHO.NAO_VERIFICADO, DESFECHO.VACUIDADE]) {
    process.stdout.write(`codigo-de:${k}=${CODIGO[k]}\n`);
  }
} else if (op === 'ler') {
  const ler = req('lerHooksManifest');
  const texto = readFileSync(process.argv[3], 'utf8');
  const r = ler(texto, { fiacao: fiacaoDe(process.argv[4]), origem: process.argv[5] || 'fixture' });
  process.stdout.write(`desfecho=${r.desfecho}\n`);
  process.stdout.write(`codigo=${r.codigo}\n`);
  process.stdout.write(`modo=${r.modo}\n`);
  process.stdout.write(`ativos=[${csv(r.ativos)}]\n`);
  process.stdout.write(`retidos=[${csv(r.inativos)}]\n`);
  process.stdout.write(`n-avisos=${Array.isArray(r.avisos) ? r.avisos.length : -1}\n`);
  process.stdout.write(`avisos=${JSON.stringify(r.avisos)}\n`);
  process.stdout.write(`mensagem=${r.mensagem}\n`);
} else if (op === 'dialeto') {
  const cl = req('classificarDialeto');
  process.stdout.write(cl(readFileSync(process.argv[3], 'utf8')) + '\n');
} else if (op === 'fiacao') {
  const der = req('derivarFiacao');
  const r = der(fiacaoDe(process.argv[3]));
  process.stdout.write(`ganchos=[${csv(r.ganchos)}]\n`);
  process.stdout.write(`pontes=[${csv(r.despachantes)}]\n`);
  process.stdout.write(`nao-reconhecidos=${JSON.stringify(r.naoReconhecidos || [])}\n`);
} else if (op === 'pureza') {
  await import(pathToFileURL(MOD).href);
  await import(pathToFileURL(MOD).href + '?segunda');
  process.stdout.write('pureza=ok\n');
} else if (op === 'pbt') {
  const ler = req('lerHooksManifest');
  const casos = Number(process.argv[3]);
  let seed = 20260908;
  const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
  const pick = (a) => a[Math.floor(rnd() * a.length)];
  const estados = ['armado', 'retido:x', 'retido:', '', 'ARMADO', ' armado', 'armado ', '*', '.cs,.java', 'comando', 'lixo'];
  const matchers = ['^Bash$', '^(Write|Edit)$', 'Write|Edit', '^Write$'];
  const contratos = ['argv', 'stdin-json'];
  const falhas = [];
  let ativados = 0;
  for (let i = 0; i < casos; i++) {
    const estado = pick(estados);
    const linha = `h${i}.sh\t${pick(matchers)}\t${pick(contratos)}\t${estado}\trazao=prosa de justificativa`;
    const texto = `# forge-manifest-format: 1\n${linha}\n`;
    const r = ler(texto, { fiacao: null, origem: 'pbt' });
    const ativo = Array.isArray(r.ativos) && r.ativos.includes(`h${i}.sh`);
    if (ativo) ativados++;
    if (ativo && estado !== 'armado') falhas.push(`ativo-sem-armado:${JSON.stringify(estado)}`);
    const antes = texto;
    const r2 = ler(texto, { fiacao: null, origem: 'pbt' });
    if (texto !== antes) falhas.push('texto-alterado-pela-leitura');
    if (csv(r.ativos) !== csv(r2.ativos) || r.desfecho !== r2.desfecho) falhas.push('leitura-nao-idempotente');
  }
  let vazias = 0;
  for (const razao of ['armado', 'razao=armado', 'prosa longa', 'retido:x']) {
    vazias++;
    const texto = `# forge-manifest-format: 1\nvazio.sh\t^Bash$\targv\t\t${razao}\n`;
    const r = ler(texto, { fiacao: null, origem: 'pbt' });
    if (Array.isArray(r.ativos) && r.ativos.includes('vazio.sh')) falhas.push(`campo4-vazio-ativou:${JSON.stringify(razao)}`);
  }
  process.stdout.write(`casos=${casos + vazias} ativados=${ativados} falhas=[${falhas.sort().join(',')}]\n`);
} else {
  process.stdout.write(`ERRO-OP: subcomando desconhecido '${op}'\n`);
  process.exit(3);
}
DRVEOF

drv() { HM_MOD_ABS="$MOD" node "$T/drv.mjs" "$@" 2>&1; }

# campo <saida> <chave> — extrai o valor exato de uma chave da saída multi-linha do driver.
campo() { printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1; }

# ── fixtures ──────────────────────────────────────────────────────────────────────────────────
# Escritas com printf e TAB explícito, porque heredoc com tabulação literal é frágil a reindentação e o campo separador é justamente o que este gate mede.
TAB=$'\t'

mk_canonico() {
  {
    printf '# forge-manifest-format: 1\n'
    printf '#hook%smatcher%scontrato%sestado%s[chave=valor ...]\n' "$TAB" "$TAB" "$TAB" "$TAB"
    printf 'prevent-secrets-leak.sh%s^(Write|Edit|MultiEdit|NotebookEdit)$%sstdin-json%sarmado%suniverso=*%srazao=AWS/JWT/PEM antes do byte tocar o disco\n' "$TAB" "$TAB" "$TAB" "$TAB" "$TAB"
    printf 'enforce-worktree-location.sh%s^Bash$%sstdin-json%sarmado%suniverso=comando\n' "$TAB" "$TAB" "$TAB" "$TAB"
    printf 'check-language-policy.sh%s^(Write|Edit|MultiEdit|NotebookEdit)$%sargv%sretido:portao-invertido-le-o-disco-LDG-0387%suniverso=.cs,.java\n' "$TAB" "$TAB" "$TAB" "$TAB"
  } >"$1"
}

# Dialeto de CINCO campos, com `universo` no quarto: cópia estrutural do `axis-fare-validator`, lido em 2026-09-08. Sem marcador de formato, porque é o arquivo como ele está no campo.
mk_cinco() {
  {
    printf '# Colunas, separadas por TAB: hook <TAB> matcher <TAB> contrato <TAB> universo <TAB> razao\n'
    printf 'check-language-policy.sh%s^(Write|Edit|MultiEdit|NotebookEdit)$%sargv%s.cs,.java%sidentificadores PT-BR em codigo\n' "$TAB" "$TAB" "$TAB" "$TAB"
    printf 'enforce-docs-on-publish.sh%s^Bash$%sstdin-json%scomando%sintercepta git push e gh pr create\n' "$TAB" "$TAB" "$TAB" "$TAB"
    printf 'enforce-worktree-location.sh%s^Bash$%sstdin-json%scomando%sbloqueia worktree fora de .forge/worktrees\n' "$TAB" "$TAB" "$TAB" "$TAB"
    printf 'guard-machinery-drift.sh%s^Bash$%sstdin-json%scomando%sbloqueia upgrade com maquinaria local divergente\n' "$TAB" "$TAB" "$TAB" "$TAB"
    printf 'prevent-secrets-leak.sh%s^(Write|Edit|MultiEdit|NotebookEdit)$%sargv%s*%sAWS/JWT/PEM antes do byte tocar o disco\n' "$TAB" "$TAB" "$TAB" "$TAB"
    printf 'validate-naming-conventions.sh%s^(Write|Edit|MultiEdit|NotebookEdit)$%sargv%s*%sduas metades com alcances diferentes\n' "$TAB" "$TAB" "$TAB" "$TAB"
  } >"$1"
}

# Dialeto de QUATRO campos, com `estado` no quarto: cópia estrutural do `Axis.PadSimulator`, lido em 2026-09-08, com as duas linhas retidas e o matcher sem âncora que elas realmente têm.
mk_quatro() {
  {
    printf '#hook%smatcher%scontrato%sestado\n' "$TAB" "$TAB" "$TAB"
    printf 'prevent-secrets-leak.sh%s^(Write|Edit|MultiEdit|NotebookEdit)$%sstdin-json%sarmado\n' "$TAB" "$TAB" "$TAB"
    printf 'enforce-worktree-location.sh%s^Bash$%sstdin-json%sarmado\n' "$TAB" "$TAB" "$TAB"
    printf 'check-language-policy.sh%sWrite|Edit%sargv%sretido:portao-invertido-le-o-disco-alcance-de-conteudo-zero-LDG-0387\n' "$TAB" "$TAB" "$TAB"
    printf 'validate-naming-conventions.sh%sWrite|Edit%sargv%sretido:28-falsos-positivos-estruturais-em-engine-e-sai-por-exit-1-LDG-0387\n' "$TAB" "$TAB" "$TAB"
  } >"$1"
}

FX_CANON="$T/canonico.manifest"
FX_CINCO="$T/cinco.manifest"
FX_QUATRO="$T/quatro.manifest"
mk_canonico "$FX_CANON"
mk_cinco "$FX_CINCO"
mk_quatro "$FX_QUATRO"

# Fiação: cópia estrutural dos `.claude/settings.json` das duas árvores, lida em 2026-09-08. A do dialeto de cinco campos encadeia a ponte antes de cada gancho; a do dialeto de quatro não tem ponte. As duas são escritas à mão aqui, e o conjunto esperado NUNCA é rederivado pelo módulo sob teste, porque comparação circular passa por construção.
P='$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use'
cat >"$T/settings-cinco.json" <<JSONEOF
{ "hooks": { "PreToolUse": [
  { "matcher": "^(Write|Edit|MultiEdit|NotebookEdit)\$", "hooks": [
    { "type": "command", "command": "$P/dispatch-file-hook.sh $P/check-language-policy.sh" },
    { "type": "command", "command": "$P/dispatch-file-hook.sh $P/prevent-secrets-leak.sh" },
    { "type": "command", "command": "$P/dispatch-file-hook.sh $P/validate-naming-conventions.sh" } ] },
  { "matcher": "^Bash\$", "hooks": [
    { "type": "command", "command": "$P/enforce-docs-on-publish.sh" },
    { "type": "command", "command": "$P/enforce-worktree-location.sh" },
    { "type": "command", "command": "$P/guard-machinery-drift.sh" } ] } ] } }
JSONEOF
cat >"$T/settings-quatro.json" <<JSONEOF
{ "hooks": { "PreToolUse": [
  { "matcher": "^Bash\$", "hooks": [ { "type": "command", "command": "$P/enforce-worktree-location.sh" } ] },
  { "matcher": "^(Write|Edit|MultiEdit|NotebookEdit)\$", "hooks": [ { "type": "command", "command": "$P/prevent-secrets-leak.sh" } ] } ] } }
JSONEOF
cat >"$T/settings-ponte3.json" <<JSONEOF
{ "hooks": { "PreToolUse": [
  { "matcher": "^Bash\$", "hooks": [
    { "type": "command", "command": "$P/wrapper-um.sh $P/wrapper-dois.sh $P/enforce-worktree-location.sh" } ] } ] } }
JSONEOF
SET_CINCO="$T/settings-cinco.json"
SET_QUATRO="$T/settings-quatro.json"

# Fiação legível e VAZIA, que é o desarme silencioso do cenário [11].
printf '{ "hooks": { "PreToolUse": [] } }\n' >"$T/settings-vazio.json"

# Conjuntos esperados, escritos à mão a partir da leitura das duas árvores em 2026-09-08, em ordem alfabética porque é assim que o driver os imprime.
ESP_CINCO_ATIVOS='ativos=[check-language-policy.sh,enforce-docs-on-publish.sh,enforce-worktree-location.sh,guard-machinery-drift.sh,prevent-secrets-leak.sh,validate-naming-conventions.sh]'
ESP_CINCO_GANCHOS='ganchos=[check-language-policy.sh,enforce-docs-on-publish.sh,enforce-worktree-location.sh,guard-machinery-drift.sh,prevent-secrets-leak.sh,validate-naming-conventions.sh]'
ESP_QUATRO_ATIVOS='ativos=[enforce-worktree-location.sh,prevent-secrets-leak.sh]'
ESP_QUATRO_RETIDOS='retidos=[check-language-policy.sh,validate-naming-conventions.sh]'
ESP_CANON_ATIVOS='ativos=[enforce-worktree-location.sh,prevent-secrets-leak.sh]'

# ── [0] controle de instrumento ───────────────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[0] controle de instrumento — fixtures legíveis com a forma declarada, e caminho canônico do módulo."
# A fixture canônica tem largura VARIÁVEL por construção, porque os campos 5 em diante são `chave=valor` de conjunto aberto, então dela se exige um PISO de aridade. As duas fixtures de dialeto de campo têm largura fixa, porque é isso que o campo escreveu, e é a largura exata que o classificador de [10] usa para distingui-las.
rc0=0
for par in "$FX_CANON:piso:4" "$FX_CINCO:exata:5" "$FX_QUATRO:exata:4"; do
  f="${par%%:*}"; resto="${par#*:}"; criterio="${resto%%:*}"; larg="${resto##*:}"
  if [ ! -r "$f" ]; then
    echo "FAIL [0]: fixture '$f' não é legível — sem instrumento não há medição"
    rc0=1; continue
  fi
  obs="$(awk -F'\t' '!/^#/ && NF>0 {print NF}' "$f" | sort -u | tr '\n' ',' | sed 's/,$//')"
  min="$(awk -F'\t' '!/^#/ && NF>0 {print NF}' "$f" | sort -n | head -1)"
  if [ "$criterio" = "exata" ] && [ "$obs" != "$larg" ]; then
    echo "FAIL [0]: fixture '$f' tem larguras de campo '$obs', esperada a largura exata '$larg'"
    rc0=1; continue
  fi
  if [ "$criterio" = "piso" ] && { [ -z "$min" ] || [ "$min" -lt "$larg" ]; }; then
    echo "FAIL [0]: fixture '$f' tem largura mínima '$min', esperado piso de '$larg' (larguras observadas: '$obs')"
    rc0=1; continue
  fi
  fixtures_examinadas=$((fixtures_examinadas + 1))
done
if [ "$MOD" = "$WS/$MOD_CANONICO" ] && [ ! -e "$MOD" ]; then
  echo "-- [0] o caminho canônico '$MOD_CANONICO' ainda não existe na árvore: o vermelho dos demais cenários é por AUSÊNCIA REAL da funcionalidade, e não por caminho digitado errado"
fi
if [ "$rc0" -ne 0 ]; then
  echo "FAIL [0]: instrumento não verificável — o gate sai por 'não consegui verificar', nunca por verde"
  echo "-- contadores: cenários $executados/$DENOMINADOR; fixtures $fixtures_examinadas; dialetos $dialetos_classificados"
  exit 4
fi
echo "OK [0] — $fixtures_examinadas fixture(s) de dialeto legíveis com a forma declarada"

# ── [1] o módulo existe e é PURO ──────────────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[1] o leitor canônico existe e importá-lo não escreve no disco."
mkdir -p "$T/cwdpuro"
sha_antes=""
[ -e "$MOD" ] && sha_antes="$(shasum -a 256 "$MOD" | cut -d' ' -f1)"
out1="$(cd "$T/cwdpuro" && HM_MOD_ABS="$MOD" node "$T/drv.mjs" pureza 2>&1)"
sha_depois=""
[ -e "$MOD" ] && sha_depois="$(shasum -a 256 "$MOD" | cut -d' ' -f1)"
n_cwd="$(find "$T/cwdpuro" -type f | wc -l | tr -d ' ')"
if [ "$out1" != "pureza=ok" ]; then
  echo "FAIL [1]: não há leitor canônico de hooks.manifest no produtor — LDG-0178 ('$out1')"
  overall_rc=1
elif [ "$sha_antes" != "$sha_depois" ]; then
  echo "FAIL [1]: importar o módulo alterou o próprio arquivo (sha $sha_antes -> $sha_depois)"
  overall_rc=1
elif [ "$n_cwd" -ne 0 ]; then
  echo "FAIL [1]: importar o módulo escreveu $n_cwd arquivo(s) no diretório corrente — o leitor não é puro"
  overall_rc=1
else
  echo "OK [1] — módulo importável duas vezes, sha inalterado e nenhum arquivo escrito"
fi

# ── [2] formato canônico ──────────────────────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[2] formato canônico — conjunto de ativos, e retenção que tira só a própria linha."
out2="$(drv ler "$FX_CANON" - canonico)"
if [ "$(campo "$out2" desfecho)" != "ok" ] || [ "ativos=$(campo "$out2" ativos)" != "$ESP_CANON_ATIVOS" ]; then
  echo "FAIL [2]: o formato canônico v1 não tem leitor — esperado desfecho=ok com $ESP_CANON_ATIVOS, obtido '$(printf '%s' "$out2" | tr '\n' '|')'"
  overall_rc=1
else
  sed "s|^enforce-worktree-location.sh${TAB}\\^Bash\\\$${TAB}stdin-json${TAB}armado|enforce-worktree-location.sh${TAB}^Bash\$${TAB}stdin-json${TAB}retido:x|" "$FX_CANON" >"$T/canon_retido.manifest"
  if ! grep -qF 'retido:x' "$T/canon_retido.manifest"; then
    echo "FAIL [2]: contrafactual não aplicado — o texto da fixture mutada não contém 'retido:x'"
    overall_rc=1
  else
    out2b="$(drv ler "$T/canon_retido.manifest" - canonico)"
    if [ "$(campo "$out2b" ativos)" != "[prevent-secrets-leak.sh]" ]; then
      echo "FAIL [2]: reter uma linha não removeu apenas aquele gancho — esperado ativos=[prevent-secrets-leak.sh], obtido 'ativos=$(campo "$out2b" ativos)'"
      overall_rc=1
    else
      echo "OK [2] — canônico dá $ESP_CANON_ATIVOS; reter uma linha tira só aquela"
    fi
  fi
fi

# ── [3] projeção nas DUAS formas de campo ─────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[3] projeção — manifesto sem marcador, nas duas formas, reproduz a fiação escrita à mão."
out3a="$(drv ler "$FX_CINCO" "$SET_CINCO" cinco-campos)"
out3b="$(drv ler "$FX_QUATRO" "$SET_QUATRO" quatro-campos)"
falhou3=0
if [ "$(campo "$out3a" modo)" != "projecao" ] || [ "ativos=$(campo "$out3a" ativos)" != "$ESP_CINCO_ATIVOS" ]; then
  echo "FAIL [3]: modo de projeção não existe — o produtor não sabe ler manifesto sem marcador (cinco campos: modo=$(campo "$out3a" modo), ativos=$(campo "$out3a" ativos))"
  falhou3=1
fi
if [ "ativos=$(campo "$out3b" ativos)" != "$ESP_QUATRO_ATIVOS" ] || [ "retidos=$(campo "$out3b" retidos)" != "$ESP_QUATRO_RETIDOS" ]; then
  echo "FAIL [3]: modo de projeção não existe — o produtor não sabe ler manifesto sem marcador (quatro campos: ativos=$(campo "$out3b" ativos), retidos=$(campo "$out3b" retidos))"
  falhou3=1
fi
if [ "$falhou3" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [3] — projeção reproduz os dois conjuntos escritos à mão; os dois 'retido:' ficam FORA dos ativos"
fi

# ── [4] o campo 4 alheio não é lido ───────────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[4] o campo 4 de manifesto sem marcador não é consultado."
base4="$(campo "$(drv ler "$FX_CINCO" "$SET_CINCO" cinco-campos)" ativos)"
falhou4=0
if [ "$base4" = "[]" ] || [ -z "$base4" ]; then
  echo "FAIL [4]: o conjunto de controle é vazio ('$base4') — comparar conjuntos vazios aprovaria por vacuidade"
  falhou4=1
fi
for troca in armado lixo 'retido:x'; do
  awk -F'\t' -v OFS='\t' -v novo="$troca" '/^#/ {print; next} NF>0 {$4=novo; print; next} {print}' "$FX_CINCO" >"$T/cinco_m.manifest"
  if ! awk -F'\t' '!/^#/ && NF>0 {print $4}' "$T/cinco_m.manifest" | grep -qxF "$troca"; then
    echo "FAIL [4]: a mutação do campo 4 para '$troca' não chegou ao texto da fixture"
    falhou4=1; continue
  fi
  m4="$(campo "$(drv ler "$T/cinco_m.manifest" "$SET_CINCO" cinco-campos)" ativos)"
  if [ "$m4" != "$base4" ]; then
    echo "FAIL [4]: o leitor consultou o campo 4 de um manifesto que não é do produtor — com campo 4 = '$troca' o conjunto mudou de '$base4' para '$m4'"
    falhou4=1
  fi
done
if [ "$falhou4" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [4] — três valores distintos no campo 4 produzem o mesmo conjunto NÃO VAZIO ativos=$base4"
fi

# ── [5] token desconhecido é fail-closed ──────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[5] token desconhecido no formato marcado recusa, com código próprio."
sed "s|${TAB}armado${TAB}universo=comando|${TAB}.cs,.java${TAB}universo=comando|" "$FX_CANON" >"$T/canon_token.manifest"
if ! awk -F'\t' '!/^#/ && NF>0 {print $4}' "$T/canon_token.manifest" | grep -qxF '.cs,.java'; then
  echo "FAIL [5]: a mutação do token não chegou ao texto da fixture"
  overall_rc=1
else
  out5="$(drv ler "$T/canon_token.manifest" - canonico)"
  if [ "$(campo "$out5" desfecho)" != "recusa" ]; then
    echo "FAIL [5]: token desconhecido não é recusado — desfecho=$(campo "$out5" desfecho)"
    overall_rc=1
  elif ! grep -qF -- 'enforce-worktree-location.sh' <<<"$out5" || ! grep -qF -- '.cs,.java' <<<"$out5"; then
    echo "FAIL [5]: recusou sem nomear o gancho e o token — mensagem='$(campo "$out5" mensagem)'"
    overall_rc=1
  elif [ "$(campo "$out5" ativos)" != "[]" ]; then
    echo "FAIL [5]: recusou e ainda assim devolveu um conjunto de ativos — ativos=$(campo "$out5" ativos)"
    overall_rc=1
  else
    echo "OK [5] — recusa nomeando gancho e token; nenhum conjunto é devolvido como se fosse verdade"
  fi
fi

# ── [6] `retido:` seco é malformado ───────────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[6] retenção sem razão é malformada; retenção com razão passa."
sed "s|${TAB}retido:portao-invertido-le-o-disco-LDG-0387|${TAB}retido:|" "$FX_CANON" >"$T/canon_seco.manifest"
if ! awk -F'\t' '!/^#/ && NF>0 {print $4}' "$T/canon_seco.manifest" | grep -qxF 'retido:'; then
  echo "FAIL [6]: a mutação para 'retido:' seco não chegou ao texto da fixture"
  overall_rc=1
else
  out6="$(drv ler "$T/canon_seco.manifest" - canonico)"
  out6ok="$(drv ler "$FX_CANON" - canonico)"
  if [ "$(campo "$out6" desfecho)" != "recusa" ]; then
    echo "FAIL [6]: retenção sem razão é aceita — desfecho=$(campo "$out6" desfecho)"
    overall_rc=1
  elif [ "$(campo "$out6ok" desfecho)" != "ok" ]; then
    echo "FAIL [6]: contrafactual — a fixture com razão escrita deveria passar, desfecho=$(campo "$out6ok" desfecho)"
    overall_rc=1
  else
    echo "OK [6] — 'retido:' seco recusa e 'retido:<razão>' passa"
  fi
fi

# ── [7] terceiro estado por fiação ilegível ───────────────────────────────────────────────────
executados=$((executados + 1))
echo "[7] manifesto sem marcador com fiação não legível sai por 'não consegui verificar'."
out7="$(drv ler "$FX_CINCO" - '.claude/settings.json')"
if [ "$(campo "$out7" desfecho)" != "nao-verificado" ]; then
  echo "FAIL [7]: fiação ilegível resolve para um conjunto em vez de recusar — desfecho=$(campo "$out7" desfecho), ativos=$(campo "$out7" ativos)"
  overall_rc=1
elif ! grep -qF -- '.claude/settings.json' <<<"$out7"; then
  echo "FAIL [7]: saiu pelo terceiro estado sem nomear o arquivo — mensagem='$(campo "$out7" mensagem)'"
  overall_rc=1
elif [ "ativos=$(campo "$out7" ativos)" = "$ESP_CINCO_ATIVOS" ]; then
  echo "FAIL [7]: resolveu para 'tudo ativo' apesar de não conseguir ler a fiação"
  overall_rc=1
elif [ "$(campo "$out7" codigo)" = "$(campo "$(drv ler "$FX_CANON" - canonico)" codigo)" ]; then
  echo "FAIL [7]: o terceiro estado compartilha código com 'não encontrei violação' — é o colapso que a invariante dos três estados proíbe"
  overall_rc=1
else
  echo "OK [7] — terceiro estado (código $(campo "$out7" codigo)) nomeando o arquivo, sem colapsar em 'tudo ativo' nem em 'nada ativo'"
fi

# ── [8] a ponte não é gancho ──────────────────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[8] em comando encadeado, só o último alvo é gancho — regra estrutural, não por nome."
out8="$(drv fiacao "$SET_CINCO")"
out8b="$(drv fiacao "$T/settings-ponte3.json")"
falhou8=0
if [ "ganchos=$(campo "$out8" ganchos)" != "$ESP_CINCO_GANCHOS" ]; then
  echo "FAIL [8]: o alvo anterior do comando foi contado como gancho — esperado $ESP_CINCO_GANCHOS, obtido 'ganchos=$(campo "$out8" ganchos)'"
  falhou8=1
fi
if [ "$(campo "$out8" pontes)" != "[dispatch-file-hook.sh]" ]; then
  echo "FAIL [8]: a ponte não foi reportada como despachante — obtido 'pontes=$(campo "$out8" pontes)'"
  falhou8=1
fi
if [ "$(campo "$out8b" ganchos)" != "[enforce-worktree-location.sh]" ]; then
  echo "FAIL [8]: com TRÊS alvos encadeados e nomes fora do vocabulário 'dispatch-*', o último deixou de ser o único gancho — obtido 'ganchos=$(campo "$out8b" ganchos)'"
  falhou8=1
fi
if [ "$falhou8" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [8] — último alvo é o gancho; anteriores são despachantes, por estrutura e não por nome"
fi

# ── [9] matcher não ancorado em linha armada ──────────────────────────────────────────────────
executados=$((executados + 1))
echo "[9] no formato marcado, armar com matcher sem âncora nas DUAS pontas recusa; ancorar faz passar."
# TRÊS formas de matcher insuficiente, e as duas meio-ancoradas são o que discrimina a guarda real de uma guarda que exija só a abertura.
# O review adversarial mediu: com `ancorado()` enfraquecido para `startsWith('^')`, a versão anterior deste cenário — que só testava `Write|Edit`, sem âncora nenhuma — passava verde, e `^Write` entraria armado. Âncora só à esquerda é casamento por substring à direita, que é exatamente o perigo que o cabeçalho do `Axis.PadSimulator` documenta com medição própria (`TodoWrite` casando e bloqueando a sessão).
falhou9=0
formas9=0
for m9 in 'Write|Edit' '^Write' 'Write$'; do
  awk -F'\t' -v OFS='\t' -v novo="$m9" '/^#/ {print; next} $1=="enforce-worktree-location.sh" {$2=novo} {print}' "$FX_CANON" >"$T/canon_nao_ancorado.manifest"
  if ! awk -F'\t' '$1=="enforce-worktree-location.sh" {print $2}' "$T/canon_nao_ancorado.manifest" | grep -qxF -- "$m9"; then
    echo "FAIL [9]: a mutação do matcher para '$m9' não chegou ao texto da fixture"
    falhou9=1; continue
  fi
  out9="$(drv ler "$T/canon_nao_ancorado.manifest" - canonico)"
  if [ "$(campo "$out9" desfecho)" != "recusa" ]; then
    echo "FAIL [9]: gancho armado com matcher '$m9' é aceito — âncora em uma ponta só ainda casa por substring — desfecho=$(campo "$out9" desfecho)"
    falhou9=1; continue
  fi
  if ! grep -qF -- 'enforce-worktree-location.sh' <<<"$out9"; then
    echo "FAIL [9]: recusou o matcher '$m9' sem nomear o gancho — mensagem='$(campo "$out9" mensagem)'"
    falhou9=1; continue
  fi
  formas9=$((formas9 + 1))
done
# Contrafactual, na MESMA posição de campo: um matcher ancorado nas duas pontas e diferente do original passa.
awk -F'\t' -v OFS='\t' '/^#/ {print; next} $1=="enforce-worktree-location.sh" {$2="^Write$"} {print}' "$FX_CANON" >"$T/canon_ancorado.manifest"
out9ok="$(drv ler "$T/canon_ancorado.manifest" - canonico)"
if [ "$(campo "$out9ok" desfecho)" != "ok" ]; then
  echo "FAIL [9]: contrafactual — a mesma linha com matcher ancorado nas duas pontas deveria passar, desfecho=$(campo "$out9ok" desfecho)"
  falhou9=1
fi
if [ "$formas9" -lt 3 ]; then
  echo "FAIL [9]: piso de formas de matcher violado — $formas9 recusada(s), esperado >= 3 (sem âncora, meio-ancorada à esquerda, meio-ancorada à direita)"
  falhou9=1
fi
if [ "$falhou9" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [9] — $formas9 formas de matcher insuficiente recusam nomeando o gancho; ancorado nas duas pontas passa"
fi

# ── [10] classificador de dialeto ─────────────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[10] classificador de dialeto sobre as fixtures deste repositório."
printf 'isto nao e um manifesto\nnem tem tabulacao alguma\n' >"$T/lixo.manifest"
vistos=""
falhou10=0
for par in "$FX_CANON:canonico" "$FX_CINCO:cinco-campos" "$FX_QUATRO:quatro-campos" "$T/lixo.manifest:nao-classificavel"; do
  f="${par%:*}"; esp="${par##*:}"
  obs="$(drv dialeto "$f")"
  if [ "$obs" != "$esp" ]; then
    echo "FAIL [10]: não há classificador de dialeto — '$f' classificado como '$obs', esperado '$esp'"
    falhou10=1
    continue
  fi
  case " $vistos " in
    *" $obs "*) : ;;
    *) vistos="$vistos $obs"; dialetos_classificados=$((dialetos_classificados + 1)) ;;
  esac
done
if [ "$falhou10" -ne 0 ]; then
  overall_rc=1
elif [ "$dialetos_classificados" -lt 2 ]; then
  echo "FAIL [10]: piso de dialetos violado — $dialetos_classificados distinto(s), esperado >= 2"
  overall_rc=1
else
  echo "OK [10] — $dialetos_classificados classe(s) distinta(s) de dialeto, partição:$vistos"
fi

# ── [11] vacuidade — fiação legível e VAZIA ───────────────────────────────────────────────────
executados=$((executados + 1))
echo "[11] fiação legível e vazia não vira 'nenhum gancho armado' com sucesso."
out11="$(drv ler "$FX_CINCO" "$T/settings-vazio.json" '.claude/settings.json')"
if [ "$(campo "$out11" desfecho)" = "ok" ]; then
  echo "FAIL [11]: fiação vazia resolveu para sucesso com conjunto vazio — é o desarme silencioso que LDG-0178 existe para impedir"
  overall_rc=1
elif [ "$(campo "$out11" desfecho)" != "recusa-por-vacuidade" ]; then
  echo "FAIL [11]: fiação vazia não tem desfecho próprio — desfecho=$(campo "$out11" desfecho)"
  overall_rc=1
elif ! grep -qF -- '.claude/settings.json' <<<"$out11"; then
  echo "FAIL [11]: recusa por vacuidade sem nomear o arquivo — mensagem='$(campo "$out11" mensagem)'"
  overall_rc=1
else
  echo "OK [11] — fiação legível e vazia recusa por vacuidade (código $(campo "$out11" codigo)), nomeando o arquivo"
fi

# ── [12] os quatro desfechos têm códigos distintos dois a dois ────────────────────────────────
executados=$((executados + 1))
echo "[12] os quatro desfechos têm códigos distintos dois a dois."
out12="$(drv codigos)"
n_cod="$(printf '%s\n' "$out12" | grep -c '^codigo-de:')"
n_uni="$(printf '%s\n' "$out12" | sed -n 's/^codigo-de:.*=//p' | sort -u | wc -l | tr -d ' ')"
if [ "$n_cod" -lt 4 ]; then
  echo "FAIL [12]: o módulo não publica os quatro desfechos com código — obtido '$(printf '%s' "$out12" | tr '\n' ' ')'"
  overall_rc=1
elif [ "$n_cod" != "$n_uni" ]; then
  echo "FAIL [12]: dois desfechos compartilham código — $n_cod desfecho(s), $n_uni código(s) distinto(s) ('$(printf '%s' "$out12" | tr '\n' ' ')')"
  overall_rc=1
else
  echo "OK [12] — $n_cod desfechos, $n_uni códigos distintos: $(printf '%s' "$out12" | tr '\n' ' ')"
fi

# ── [13] PBT ──────────────────────────────────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[13] PBT — nenhuma entrada ativa sem 'armado'; leitura idempotente; campo vazio não vira estado."
out13="$(drv pbt 240)"
n13="$(printf '%s\n' "$out13" | sed -n 's/^casos=\([0-9]*\).*/\1/p')"
at13="$(printf '%s\n' "$out13" | sed -n 's/.*ativados=\([0-9]*\).*/\1/p')"
if [ -z "$n13" ] || [ "$n13" -eq 0 ]; then
  echo "FAIL [13]: a PBT não gerou caso algum — universo vazio não aprova ('$out13')"
  overall_rc=1
elif [ -z "$at13" ] || [ "$at13" -eq 0 ]; then
  echo "FAIL [13]: nenhum caso gerado ativou gancho — a propriedade passaria por vacuidade ('$out13')"
  overall_rc=1
elif ! grep -qF -- 'falhas=[]' <<<"$out13"; then
  echo "FAIL [13]: propriedade violada — '$out13'"
  overall_rc=1
else
  echo "OK [13] — $n13 caso(s) gerados, $at13 ativação(ões) legítima(s), nenhuma violação"
fi

# ── settings auxiliares dos cenários [14] a [20] ──────────────────────────────────────────────
# Escritos aqui, junto dos cenários que os consomem, e não no bloco de fixtures do topo, porque cada um existe por causa de um achado nomeado e o leitor precisa ver os dois lado a lado.
cat >"$T/settings-x.json" <<JSONEOF
{ "hooks": { "PreToolUse": [ { "matcher": "^Bash\$", "hooks": [ { "type": "command", "command": "$P/x.sh" } ] } ] } }
JSONEOF

# ── [14] vacuidade no modo CANÔNICO ───────────────────────────────────────────────────────────
# O cenário [11] exercita a vacuidade só no caminho de PROJEÇÃO. O caminho CANÔNICO tem a guarda simétrica, e sem cenário que a observe um manifesto marcado, bem formado, com todas as linhas `retido:` devolvia `desfecho=ok` com `ativos=[]` — o mesmo desarme silencioso, agora dentro do leitor do próprio produtor.
executados=$((executados + 1))
echo "[14] manifesto marcado e bem formado sem nenhuma linha armada não vira sucesso com conjunto vazio."
{
  printf '# forge-manifest-format: 1\n'
  printf 'check-language-policy.sh%s^(Write|Edit)$%sargv%sretido:portao-invertido-le-o-disco-LDG-0387\n' "$TAB" "$TAB" "$TAB"
  printf 'validate-naming-conventions.sh%s^(Write|Edit)$%sargv%sretido:28-falsos-positivos-estruturais-LDG-0387\n' "$TAB" "$TAB" "$TAB"
} >"$T/canon_vacuo.manifest"
awk -F'\t' -v OFS='\t' '/^#/ {print; next} $1=="check-language-policy.sh" {$4="armado"} {print}' "$T/canon_vacuo.manifest" >"$T/canon_vacuo_armado.manifest"
falhou14=0
if ! awk -F'\t' '$1=="check-language-policy.sh" {print $4}' "$T/canon_vacuo_armado.manifest" | grep -qxF 'armado'; then
  echo "FAIL [14]: o contrafactual não chegou ao texto da fixture — a linha não ficou armada"
  falhou14=1
fi
out14="$(drv ler "$T/canon_vacuo.manifest" - '.claude/settings.json')"
out14b="$(drv ler "$T/canon_vacuo_armado.manifest" - '.claude/settings.json')"
if [ "$(campo "$out14" desfecho)" = "ok" ]; then
  echo "FAIL [14]: manifesto marcado com zero linhas armadas resolveu para sucesso — é o desarme silencioso do lado canônico"
  falhou14=1
elif [ "$(campo "$out14" desfecho)" != "recusa-por-vacuidade" ]; then
  echo "FAIL [14]: a vacuidade canônica não tem desfecho próprio — desfecho=$(campo "$out14" desfecho)"
  falhou14=1
elif [ "$(campo "$out14" ativos)" != "[]" ]; then
  echo "FAIL [14]: recusou por vacuidade e ainda devolveu ativos=$(campo "$out14" ativos)"
  falhou14=1
elif [ "$(campo "$out14" codigo)" = "$(campo "$out14b" codigo)" ]; then
  echo "FAIL [14]: a vacuidade canônica compartilha código com 'sem violação' — código $(campo "$out14" codigo) nos dois"
  falhou14=1
fi
if [ "$(campo "$out14b" desfecho)" != "ok" ] || [ "$(campo "$out14b" ativos)" != "[check-language-policy.sh]" ]; then
  echo "FAIL [14]: contrafactual — armar UMA das duas linhas deveria passar, desfecho=$(campo "$out14b" desfecho), ativos=$(campo "$out14b" ativos)"
  falhou14=1
fi
if [ "$falhou14" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [14] — marcado e sem linha armada recusa por vacuidade (código $(campo "$out14" codigo)); armar uma linha passa"
fi

# ── [15] as formas de comando da fiação ───────────────────────────────────────────────────────
# O comando de `PreToolUse` é texto de shell. Ler só o sufixo de token separado por espaço fazia um caminho entre aspas terminar em `.sh"` e o primeiro de dois ganchos encadeados por ';' terminar em `.sh;` — nos dois casos o gancho REALMENTE fiado sumia do conjunto derivado e a projeção o devolvia como INATIVO com desfecho de sucesso e avisos vazios. E um comando sem alvo reconhecível não pode virar silêncio: é o terceiro estado.
executados=$((executados + 1))
echo "[15] aspas e encadeamento por ';' não engolem gancho fiado; comando sem alvo reconhecível é terceiro estado."
{
  printf 'prevent-secrets-leak.sh%s^(Write|Edit)$%sstdin-json\n' "$TAB" "$TAB"
  printf 'enforce-worktree-location.sh%s^Bash$%sstdin-json\n' "$TAB" "$TAB"
} >"$T/proj_dois.manifest"
cat >"$T/settings-simples.json" <<JSONEOF
{ "hooks": { "PreToolUse": [ { "matcher": "^Bash\$", "hooks": [
  { "type": "command", "command": "$P/prevent-secrets-leak.sh" },
  { "type": "command", "command": "$P/enforce-worktree-location.sh" } ] } ] } }
JSONEOF
cat >"$T/settings-aspas.json" <<JSONEOF
{ "hooks": { "PreToolUse": [ { "matcher": "^Bash\$", "hooks": [
  { "type": "command", "command": "\"$P/prevent-secrets-leak.sh\"" },
  { "type": "command", "command": "$P/enforce-worktree-location.sh" } ] } ] } }
JSONEOF
cat >"$T/settings-encadeado.json" <<JSONEOF
{ "hooks": { "PreToolUse": [ { "matcher": "^Bash\$", "hooks": [
  { "type": "command", "command": "$P/prevent-secrets-leak.sh; $P/enforce-worktree-location.sh" } ] } ] } }
JSONEOF
cat >"$T/settings-irreconhecivel.json" <<JSONEOF
{ "hooks": { "PreToolUse": [ { "matcher": "^Bash\$", "hooks": [
  { "type": "command", "command": "node $P/roda-o-gancho.mjs" },
  { "type": "command", "command": "$P/enforce-worktree-location.sh" } ] } ] } }
JSONEOF
# Conjunto esperado escrito à MÃO, nunca rederivado pelo módulo sob teste.
ESP_DOIS_ATIVOS='ativos=[enforce-worktree-location.sh,prevent-secrets-leak.sh]'
falhou15=0
formas15=0
base15="$(drv ler "$T/proj_dois.manifest" "$T/settings-simples.json" '.claude/settings.json')"
if [ "ativos=$(campo "$base15" ativos)" != "$ESP_DOIS_ATIVOS" ]; then
  echo "FAIL [15]: o controle positivo não reproduz a fiação escrita à mão — $ESP_DOIS_ATIVOS esperado, obtido 'ativos=$(campo "$base15" ativos)'"
  falhou15=1
fi
for forma in "aspas:$T/settings-aspas.json" "encadeado-por-ponto-e-virgula:$T/settings-encadeado.json"; do
  rot="${forma%%:*}"; arq="${forma#*:}"
  out15="$(drv ler "$T/proj_dois.manifest" "$arq" '.claude/settings.json')"
  if [ "ativos=$(campo "$out15" ativos)" != "$ESP_DOIS_ATIVOS" ]; then
    echo "FAIL [15]: forma '$rot' engoliu gancho realmente fiado — esperado $ESP_DOIS_ATIVOS, obtido 'ativos=$(campo "$out15" ativos)', desfecho=$(campo "$out15" desfecho), avisos=$(campo "$out15" avisos)"
    falhou15=1; continue
  fi
  formas15=$((formas15 + 1))
done
out15c="$(drv ler "$T/proj_dois.manifest" "$T/settings-irreconhecivel.json" '.claude/settings.json')"
if [ "$(campo "$out15c" desfecho)" != "nao-verificado" ]; then
  echo "FAIL [15]: comando sem alvo '.sh' reconhecível foi engolido em silêncio — desfecho=$(campo "$out15c" desfecho), ativos=$(campo "$out15c" ativos), retidos=$(campo "$out15c" retidos)"
  falhou15=1
elif ! grep -qF -- 'roda-o-gancho.mjs' <<<"$out15c"; then
  echo "FAIL [15]: saiu pelo terceiro estado sem nomear o comando irreconhecível — mensagem='$(campo "$out15c" mensagem)'"
  falhou15=1
fi
if [ "$formas15" -lt 2 ]; then
  echo "FAIL [15]: piso de formas de comando violado — $formas15 reproduzida(s), esperado >= 2 (aspas, encadeamento)"
  falhou15=1
fi
if [ "$falhou15" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [15] — $formas15 forma(s) de comando reproduzem a mesma fiação; comando irreconhecível sai por 'não consegui verificar'"
fi

# ── [16] o canal `avisos` é observável ────────────────────────────────────────────────────────
# Três decisões declaradas viviam num canal que o driver não imprimia, e por isso sobreviviam a mutação em qualquer direção: gancho fiado sem linha declarada vira AVISO e nunca recusa (o caso real do `dispatch-file-hook.sh`), chave nomeada desconhecida é ignorada e NOMEADA, e o despachante é nomeado.
executados=$((executados + 1))
echo "[16] o canal 'avisos' é observável — despachante, gancho fiado sem linha declarada, chave desconhecida."
cat >"$T/settings-extra.json" <<JSONEOF
{ "hooks": { "PreToolUse": [
  { "matcher": "^Bash\$", "hooks": [ { "type": "command", "command": "$P/enforce-worktree-location.sh" } ] },
  { "matcher": "^(Write|Edit|MultiEdit|NotebookEdit)\$", "hooks": [
    { "type": "command", "command": "$P/prevent-secrets-leak.sh" },
    { "type": "command", "command": "$P/extra-nao-declarado.sh" } ] } ] } }
JSONEOF
sed "s|${TAB}universo=comando|${TAB}univero=comando|" "$FX_CANON" >"$T/canon_chave.manifest"
falhou16=0
if ! awk -F'\t' '!/^#/ && NF>0 {print $5}' "$T/canon_chave.manifest" | grep -qxF 'univero=comando'; then
  echo "FAIL [16]: a mutação da chave nomeada não chegou ao texto da fixture"
  falhou16=1
fi
out16a="$(drv ler "$FX_QUATRO" "$T/settings-extra.json" '.claude/settings.json')"
out16b="$(drv ler "$T/canon_chave.manifest" - canonico)"
out16c="$(drv ler "$FX_CINCO" "$SET_CINCO" cinco-campos)"
if [ "$(campo "$out16a" desfecho)" = "recusa" ]; then
  echo "FAIL [16]: gancho fiado sem linha declarada no manifesto virou RECUSA da árvore inteira — a spec declara o caso benigno e ele existe hoje no campo — mensagem='$(campo "$out16a" mensagem)'"
  falhou16=1
elif ! grep -qF -- 'extra-nao-declarado.sh' <<<"$(campo "$out16a" avisos)"; then
  echo "FAIL [16]: gancho fiado sem linha declarada não foi NOMEADO nos avisos — avisos=$(campo "$out16a" avisos)"
  falhou16=1
else
  canais_de_aviso=$((canais_de_aviso + 1))
fi
if [ "$(campo "$out16b" desfecho)" != "ok" ]; then
  echo "FAIL [16]: chave nomeada desconhecida recusou em vez de ser ignorada — desfecho=$(campo "$out16b" desfecho), mensagem='$(campo "$out16b" mensagem)'"
  falhou16=1
elif ! grep -qF -- 'univero' <<<"$(campo "$out16b" avisos)"; then
  echo "FAIL [16]: chave nomeada desconhecida foi engolida em silêncio — ignorada sem ser nomeada, avisos=$(campo "$out16b" avisos)"
  falhou16=1
else
  canais_de_aviso=$((canais_de_aviso + 1))
fi
if ! grep -qF -- 'dispatch-file-hook.sh' <<<"$(campo "$out16c" avisos)"; then
  echo "FAIL [16]: o despachante não foi nomeado nos avisos — avisos=$(campo "$out16c" avisos)"
  falhou16=1
else
  canais_de_aviso=$((canais_de_aviso + 1))
fi
if [ "$falhou16" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [16] — $canais_de_aviso canal(is) de aviso observados, cada um nomeando o seu objeto, e nenhum deles recusa"
fi

# ── [17] a guarda de versão do marcador ───────────────────────────────────────────────────────
# É a razão de ser do marcador: sem ela, um v2 futuro com outra semântica de coluna seria lido com a régua do v1, que é o defeito de LDG-0178 repetido uma geração adiante.
executados=$((executados + 1))
echo "[17] manifesto marcado com versão de formato desconhecida recusa, e não é lido com a régua da v1."
sed 's|^# forge-manifest-format: 1$|# forge-manifest-format: 2|' "$FX_CANON" >"$T/canon_v2.manifest"
falhou17=0
if ! grep -qxF -- '# forge-manifest-format: 2' "$T/canon_v2.manifest"; then
  echo "FAIL [17]: a mutação do marcador não chegou ao texto da fixture"
  falhou17=1
fi
out17="$(drv ler "$T/canon_v2.manifest" - canonico)"
out17ok="$(drv ler "$FX_CANON" - canonico)"
if [ "$(campo "$out17" desfecho)" != "recusa" ]; then
  echo "FAIL [17]: manifesto marcado como formato 2 foi lido com a régua da v1 — desfecho=$(campo "$out17" desfecho), ativos=$(campo "$out17" ativos)"
  falhou17=1
elif [ "$(campo "$out17" ativos)" != "[]" ]; then
  echo "FAIL [17]: recusou a versão desconhecida e ainda armou ativos=$(campo "$out17" ativos)"
  falhou17=1
elif ! grep -qF -- 'formato 2' <<<"$out17"; then
  echo "FAIL [17]: recusou sem nomear a versão observada — mensagem='$(campo "$out17" mensagem)'"
  falhou17=1
elif [ "$(campo "$out17ok" desfecho)" != "ok" ] || [ "ativos=$(campo "$out17ok" ativos)" != "$ESP_CANON_ATIVOS" ]; then
  echo "FAIL [17]: contrafactual — o mesmo manifesto marcado como versão 1 deveria passar, desfecho=$(campo "$out17ok" desfecho)"
  falhou17=1
fi
if [ "$falhou17" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [17] — versão de formato desconhecida recusa nomeando a versão observada; a versão 1 passa"
fi

# ── [18] gancho declarado duas vezes ──────────────────────────────────────────────────────────
# Um manifesto com o mesmo `.sh` declarado `armado` numa linha e `retido:` noutra é ambiguidade sobre a fiação, que é o objeto do item. Sem a guarda o mesmo gancho sai em ativos E em inativos, com sucesso, e quem consome decide por ordem de iteração.
executados=$((executados + 1))
echo "[18] gancho declarado mais de uma vez recusa, nos DOIS modos."
{
  printf '# forge-manifest-format: 1\n'
  printf 'x.sh%s^Bash$%sargv%sarmado\n' "$TAB" "$TAB" "$TAB"
  printf 'x.sh%s^Bash$%sargv%sretido:razao-qualquer\n' "$TAB" "$TAB" "$TAB"
} >"$T/canon_dup.manifest"
{
  printf 'x.sh%s^Bash$%sargv\n' "$TAB" "$TAB"
  printf 'x.sh%s^(Write|Edit)$%sargv\n' "$TAB" "$TAB"
} >"$T/proj_dup.manifest"
{
  printf '# forge-manifest-format: 1\n'
  printf 'x.sh%s^Bash$%sargv%sarmado\n' "$TAB" "$TAB" "$TAB"
} >"$T/canon_uni.manifest"
printf 'x.sh%s^Bash$%sargv\n' "$TAB" "$TAB" >"$T/proj_uni.manifest"
falhou18=0
modos18=0
for par in "canonico:$T/canon_dup.manifest:-" "projecao:$T/proj_dup.manifest:$T/settings-x.json"; do
  rot="${par%%:*}"; resto="${par#*:}"; fx="${resto%%:*}"; fi18="${resto##*:}"
  out18="$(drv ler "$fx" "$fi18" '.claude/settings.json')"
  if [ "$(campo "$out18" desfecho)" != "recusa" ]; then
    echo "FAIL [18]: declaração duplicada aceita no modo '$rot' — desfecho=$(campo "$out18" desfecho), ativos=$(campo "$out18" ativos), retidos=$(campo "$out18" retidos)"
    falhou18=1; continue
  fi
  if ! grep -qF -- 'x.sh' <<<"$out18"; then
    echo "FAIL [18]: recusou a duplicata no modo '$rot' sem nomear o gancho — mensagem='$(campo "$out18" mensagem)'"
    falhou18=1; continue
  fi
  modos18=$((modos18 + 1))
done
for par in "canonico:$T/canon_uni.manifest:-" "projecao:$T/proj_uni.manifest:$T/settings-x.json"; do
  rot="${par%%:*}"; resto="${par#*:}"; fx="${resto%%:*}"; fi18="${resto##*:}"
  out18b="$(drv ler "$fx" "$fi18" '.claude/settings.json')"
  if [ "$(campo "$out18b" desfecho)" != "ok" ] || [ "$(campo "$out18b" ativos)" != "[x.sh]" ]; then
    echo "FAIL [18]: contrafactual do modo '$rot' — a mesma linha declarada UMA vez deveria passar, desfecho=$(campo "$out18b" desfecho), ativos=$(campo "$out18b" ativos)"
    falhou18=1
  fi
done
if [ "$modos18" -lt 2 ]; then
  echo "FAIL [18]: piso de modos violado — $modos18 modo(s) recusaram a duplicata, esperado >= 2"
  falhou18=1
fi
if [ "$falhou18" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [18] — duplicata recusa nos $modos18 modos nomeando o gancho; declaração única passa nos dois"
fi

# ── [19] guardas de forma da linha ────────────────────────────────────────────────────────────
# As três recusas de forma. A da aridade canônica é a que separa uma recusa auditável de uma exceção não tratada: com ela removida, a linha curta chega à desestruturação com `estado` indefinido e o módulo LANÇA em vez de recusar de forma tipada.
executados=$((executados + 1))
echo "[19] aridade canônica, aridade da projeção e campo nomeado fora de 'chave=valor' recusam de forma TIPADA."
{ printf '# forge-manifest-format: 1\n'; printf 'x.sh%s^Bash$\n' "$TAB"; } >"$T/canon_curta.manifest"
printf 'x.sh%s^Bash$\n' "$TAB" >"$T/proj_curta.manifest"
{ printf '# forge-manifest-format: 1\n'; printf 'x.sh%s^Bash$%sargv%sarmado%srazao-sem-chave\n' "$TAB" "$TAB" "$TAB" "$TAB"; } >"$T/canon_nomeado.manifest"
falhou19=0
formas19=0
for par in "aridade-canonica:$T/canon_curta.manifest:-" "aridade-da-projecao:$T/proj_curta.manifest:$T/settings-x.json" "campo-nomeado:$T/canon_nomeado.manifest:-"; do
  rot="${par%%:*}"; resto="${par#*:}"; fx="${resto%%:*}"; fi19="${resto##*:}"
  out19="$(drv ler "$fx" "$fi19" '.claude/settings.json')"
  if [ "$(campo "$out19" desfecho)" != "recusa" ]; then
    echo "FAIL [19]: a guarda de forma '$rot' não recusa de forma tipada — desfecho='$(campo "$out19" desfecho)', saída='$(printf '%s' "$out19" | tr '\n' '|')'"
    falhou19=1; continue
  fi
  formas19=$((formas19 + 1))
done
if ! grep -qF -- '2 campo(s)' <<<"$(drv ler "$T/canon_curta.manifest" - canonico)"; then
  echo "FAIL [19]: a recusa por aridade canônica não nomeia a aridade observada — mensagem='$(campo "$(drv ler "$T/canon_curta.manifest" - canonico)" mensagem)'"
  falhou19=1
fi
out19ok="$(drv ler "$T/canon_uni.manifest" - canonico)"
if [ "$(campo "$out19ok" desfecho)" != "ok" ]; then
  echo "FAIL [19]: contrafactual — a linha canônica bem formada deveria passar, desfecho=$(campo "$out19ok" desfecho)"
  falhou19=1
fi
if [ "$formas19" -lt 3 ]; then
  echo "FAIL [19]: piso de guardas de forma violado — $formas19 recusada(s), esperado >= 3"
  falhou19=1
fi
if [ "$falhou19" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [19] — $formas19 guarda(s) de forma recusam de forma tipada, nomeando a aridade observada; a linha bem formada passa"
fi

# ── [20] o vocabulário do campo 3 ─────────────────────────────────────────────────────────────
# O campo 3 decide por qual canal o gancho recebe o payload, isto é, COMO ele é invocado. Fechar o campo 4 e deixar o 3 aberto seria assimetria de rigor entre dois campos posicionais que ambos governam comportamento. A assimetria que fica é outra e é deliberada: recusa no formato marcado, onde o produtor é dono do formato; aviso nomeado na projeção, onde o leitor está lendo um arquivo que não escreveu.
executados=$((executados + 1))
echo "[20] campo 3 'contrato' — vocabulário fechado no formato marcado, aviso nomeado na projeção."
{ printf '# forge-manifest-format: 1\n'; printf 'x.sh%s^Bash$%sargvv%sarmado\n' "$TAB" "$TAB" "$TAB"; } >"$T/canon_contrato.manifest"
printf 'x.sh%s^Bash$%sargvv\n' "$TAB" "$TAB" >"$T/proj_contrato.manifest"
falhou20=0
out20="$(drv ler "$T/canon_contrato.manifest" - canonico)"
if [ "$(campo "$out20" desfecho)" != "recusa" ]; then
  echo "FAIL [20]: contrato fora do vocabulário é aceito no formato marcado — desfecho=$(campo "$out20" desfecho), ativos=$(campo "$out20" ativos)"
  falhou20=1
elif ! grep -qF -- 'argvv' <<<"$out20" || ! grep -qF -- 'x.sh' <<<"$out20"; then
  echo "FAIL [20]: recusou sem nomear o gancho e o token — mensagem='$(campo "$out20" mensagem)'"
  falhou20=1
fi
contratos20=0
for c20 in argv stdin-json; do
  { printf '# forge-manifest-format: 1\n'; printf 'x.sh%s^Bash$%s%s%sarmado\n' "$TAB" "$TAB" "$c20" "$TAB"; } >"$T/canon_contrato_ok.manifest"
  if ! awk -F'\t' '!/^#/ && NF>0 {print $3}' "$T/canon_contrato_ok.manifest" | grep -qxF -- "$c20"; then
    echo "FAIL [20]: o contrafactual do contrato '$c20' não chegou ao texto da fixture"
    falhou20=1; continue
  fi
  out20b="$(drv ler "$T/canon_contrato_ok.manifest" - canonico)"
  if [ "$(campo "$out20b" desfecho)" != "ok" ] || [ "$(campo "$out20b" ativos)" != "[x.sh]" ]; then
    echo "FAIL [20]: contrafactual — o contrato '$c20' do vocabulário deveria passar, desfecho=$(campo "$out20b" desfecho), ativos=$(campo "$out20b" ativos)"
    falhou20=1; continue
  fi
  contratos20=$((contratos20 + 1))
done
out20c="$(drv ler "$T/proj_contrato.manifest" "$T/settings-x.json" '.claude/settings.json')"
if [ "$(campo "$out20c" desfecho)" = "recusa" ]; then
  echo "FAIL [20]: a projeção recusou por causa do campo 3 — o leitor não é dono do arquivo que projeta, e recusar ali quebra a retrocompatibilidade que é a premissa da onda"
  falhou20=1
elif ! grep -qF -- 'argvv' <<<"$(campo "$out20c" avisos)"; then
  echo "FAIL [20]: a projeção engoliu o contrato desconhecido em silêncio — avisos=$(campo "$out20c" avisos)"
  falhou20=1
fi
if [ "$contratos20" -lt 2 ]; then
  echo "FAIL [20]: piso de contratos do vocabulário violado — $contratos20 aceito(s), esperado >= 2"
  falhou20=1
fi
if [ "$falhou20" -ne 0 ]; then
  overall_rc=1
else
  echo "OK [20] — contrato fora do vocabulário recusa no marcado nomeando gancho e token, e vira aviso nomeado na projeção; $contratos20 contrato(s) do vocabulário passam"
fi

# ── [21] sentinela ────────────────────────────────────────────────────────────────────────────
executados=$((executados + 1))
echo "[21] sentinela — contadores contra o denominador declarado e os pisos."
echo "-- contadores: cenários $executados/$DENOMINADOR; fixtures de dialeto examinadas $fixtures_examinadas (piso 3); classes de dialeto $dialetos_classificados (piso 2); canais de aviso observados $canais_de_aviso (piso 3)"
if [ "$executados" -ne "$DENOMINADOR" ]; then
  echo "FAIL [21]: executei $executados cenário(s) contra o denominador declarado de $DENOMINADOR"
  overall_rc=1
elif [ "$fixtures_examinadas" -lt 3 ]; then
  echo "FAIL [21]: piso de fixtures violado — $fixtures_examinadas examinada(s), esperado >= 3"
  overall_rc=1
elif [ "$dialetos_classificados" -lt 2 ]; then
  echo "FAIL [21]: piso de dialetos violado — $dialetos_classificados distinto(s), esperado >= 2"
  overall_rc=1
elif [ "$canais_de_aviso" -lt 3 ]; then
  echo "FAIL [21]: piso de canais de aviso violado — $canais_de_aviso observado(s), esperado >= 3"
  overall_rc=1
else
  echo "OK [21] — $executados de $DENOMINADOR cenários executados; pisos respeitados"
fi

if [ "$overall_rc" -eq 0 ]; then
  echo "PASS w208-hooks-manifest-esquema-gate"
else
  echo "FAIL w208-hooks-manifest-esquema-gate"
fi
exit "$overall_rc"
