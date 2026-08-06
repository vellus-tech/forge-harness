#!/usr/bin/env bash
# Gate W133 — o managed-block do .gitignore reconcilia, e o store do liaison sobrevive ao .NET.
#
# Três itens P1 do ledger que são o MESMO defeito visto de ângulos diferentes:
#
#   LDG-0005  o updater não mescla padrões novos num bloco que já existe (append-once)
#   LDG-0009  por isso, consumidores antigos não ignoram `.forge.bak-*/` nem `.forge/cache/`
#   LDG-0015  e o `[Ll]og/` do template .NET/VS engole `.forge/liaison/<canal>/log/`
#
# A relação importa para a ordem do conserto: LDG-0005 é a CAUSA. Corrigir o patch sem corrigir a
# reconciliação não resolve nada em quem já instalou — que é exatamente onde os outros dois doem.
#
# Sobre o LDG-0015 e a ordem das regras: `[Ll]og/` exclui o DIRETÓRIO, e o git não reabre
# diretório excluído. Negar só os arquivos (`!.../log/*.jsonl`) não funciona — a negação do
# diretório tem de vir ANTES, e ambas DEPOIS da regra que exclui. Como o bloco forge é acrescido
# ao fim do arquivo, a ordem sai a nosso favor; o que faltava era emitir as duas negações.
#
#   [0]  CONTROLE: instalação limpa aplica o bloco e os padrões valem
#   [1]  RED (LDG-0005): bloco já presente e desatualizado recebe padrão novo no `update`
#   [2]  a reconciliação PRESERVA o que o usuário escreveu fora do bloco
#   [3]  RED (LDG-0009): consumidor antigo passa a ignorar `.forge.bak-*/` e `.forge/cache/`
#   [4]  RED (LDG-0015): com `[Ll]og/` do .NET, o log do liaison continua VERSIONÁVEL
#   [5]  o patch não contém linha de prosa que o git leria como padrão
#   [6]  idempotência: reconciliar duas vezes não duplica nem incha o bloco
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w133.XXXXXX)"
trap 'rm -rf "$T"' EXIT

novo_repo() {  # novo_repo <dir>
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" config user.email "fixture@test"
  git -C "$1" config user.name "fixture"
}

echo "[0] CONTROLE: instalação limpa aplica o bloco e os padrões valem"
novo_repo "$T/limpo"
node "$WS/bin/forge.mjs" init --target "$T/limpo" --slug demo --name Demo --desc t --yes --no-plugin >"$T/init0.log" 2>&1 \
  || { echo "FAIL [0]: init reprovou"; tail -20 "$T/init0.log"; exit 1; }
grep -q '# >>> forge (managed) >>>' "$T/limpo/.gitignore" || { echo "FAIL [0]: marcador ausente após init"; exit 1; }
mkdir -p "$T/limpo/.forge/cache"; : > "$T/limpo/.forge/cache/x.json"
git -C "$T/limpo" check-ignore -q .forge/cache/x.json \
  || { echo "FAIL [0]: instalação limpa não ignora .forge/cache/ — nenhum vermelho adiante prova nada"; exit 1; }
echo "OK [0]"

echo "[1] bloco já presente e desatualizado recebe os padrões novos no update"
novo_repo "$T/antigo"
node "$WS/bin/forge.mjs" init --target "$T/antigo" --slug demo --name Demo --desc t --yes --no-plugin >"$T/init1.log" 2>&1 \
  || { echo "FAIL [1]: init reprovou"; exit 1; }
# Simula o consumidor que instalou quando o bloco era menor: mantém marcadores e alguns padrões,
# e remove os que entraram depois. É exatamente o estado que o LDG-0009 descreve em campo.
cat > "$T/antigo/.gitignore" <<'EOF'
node_modules/
dist/

# >>> forge (managed) >>>
.forge/worktrees/
.claude/settings.local.json
.DS_Store
# <<< forge (managed) <<<
EOF
node "$WS/bin/forge.mjs" update --target "$T/antigo" --no-plugin --no-backup >"$T/up1.log" 2>&1 \
  || { echo "FAIL [1]: update reprovou"; tail -20 "$T/up1.log"; exit 1; }
faltando=""
for pat in '.forge.bak-*/' '.forge/cache/' '.forge/graph/graph.json'; do
  grep -qxF "$pat" "$T/antigo/.gitignore" || faltando="$faltando $pat"
done
[ -z "$faltando" ] || { echo "FAIL [1]: bloco existente não recebeu padrão novo (append-once):$faltando"; exit 1; }
echo "OK [1]"

echo "[2] a reconciliação preserva o que o usuário escreveu fora do bloco"
grep -qxF 'node_modules/' "$T/antigo/.gitignore" || { echo "FAIL [2]: linha do usuário ANTES do bloco foi perdida"; exit 1; }
grep -qxF 'dist/' "$T/antigo/.gitignore" || { echo "FAIL [2]: linha do usuário foi perdida"; exit 1; }
printf '\n# meu\ncoverage/\n' >> "$T/antigo/.gitignore"
node "$WS/bin/forge.mjs" update --target "$T/antigo" --no-plugin --no-backup >"$T/up2.log" 2>&1 || { echo "FAIL [2]: update reprovou"; exit 1; }
grep -qxF 'coverage/' "$T/antigo/.gitignore" || { echo "FAIL [2]: linha do usuário DEPOIS do bloco foi perdida na reconciliação"; exit 1; }
echo "OK [2]"

echo "[3] consumidor antigo passa a ignorar .forge.bak-*/ e .forge/cache/"
mkdir -p "$T/antigo/.forge.bak-1" "$T/antigo/.forge/cache"
: > "$T/antigo/.forge.bak-1/sujeira.txt"; : > "$T/antigo/.forge/cache/lock.json"
git -C "$T/antigo" check-ignore -q .forge.bak-1/sujeira.txt \
  || { echo "FAIL [3]: backup do próprio update seria commitado — duplica a maquinaria dentro do commit que deveria substituí-la"; exit 1; }
git -C "$T/antigo" check-ignore -q .forge/cache/lock.json \
  || { echo "FAIL [3]: cache local seria commitado"; exit 1; }
echo "OK [3]"

echo "[4] com o .gitignore de .NET/VS, o store do liaison continua versionável"
novo_repo "$T/dotnet"
# Trecho verbatim do template oficial de .NET/Visual Studio. `[Ll]og/` exclui o DIRETÓRIO.
cat > "$T/dotnet/.gitignore" <<'EOF'
[Bb]in/
[Oo]bj/
[Ll]og/
[Ll]ogs/
EOF
node "$WS/bin/forge.mjs" init --target "$T/dotnet" --slug axis --name Axis --desc t --yes --no-plugin >"$T/init4.log" 2>&1 \
  || { echo "FAIL [4]: init reprovou"; tail -20 "$T/init4.log"; exit 1; }
# CONTROLE do próprio caso: sem a regra do .NET o log seria versionável de qualquer jeito, e o
# teste passaria por vacuidade. Confirma que a regra que atrapalha está mesmo em vigor.
mkdir -p "$T/dotnet/Log"; : > "$T/dotnet/Log/app.txt"
git -C "$T/dotnet" check-ignore -q Log/app.txt \
  || { echo "FAIL [4]: a regra [Ll]og/ não está em vigor — o caso passaria por vacuidade"; exit 1; }
mkdir -p "$T/dotnet/.forge/liaison/contratos/log"
: > "$T/dotnet/.forge/liaison/contratos/log/axis-go-cloud.jsonl"
if git -C "$T/dotnet" check-ignore -q .forge/liaison/contratos/log/axis-go-cloud.jsonl; then
  echo "FAIL [4]: [Ll]og/ engoliu o store do liaison — CHANNEL.md e state.json ficam versionados e as MENSAGENS não; canal com cara de versionado e store vazio em qualquer clone"
  exit 1
fi
echo "OK [4]"

echo "[5] o patch não contém prosa que o git leria como padrão"
# Uma linha de comentário que perde o `#` não vira comentário: vira PADRÃO. Não costuma casar
# nada (e por isso passa despercebida), mas é lixo dentro de um bloco que o harness escreve no
# repositório de todo adotante.
suspeitas="$(grep -vE '^[[:space:]]*(#|$)' "$WS/installer/gitignore.patch" | grep -E '[[:space:]]{2,}|[[:space:]]\(|\bde\b|\bpara\b|\bque\b' || true)"
[ -z "$suspeitas" ] || { echo "FAIL [5]: linha de prosa fora de comentário no gitignore.patch:"; printf '%s\n' "$suspeitas"; exit 1; }
echo "OK [5]"

echo "[6] reconciliar duas vezes não duplica nem incha o bloco"
antes="$(wc -l < "$T/antigo/.gitignore")"
node "$WS/bin/forge.mjs" update --target "$T/antigo" --no-plugin --no-backup >"$T/up3.log" 2>&1 || { echo "FAIL [6]: update reprovou"; exit 1; }
depois="$(wc -l < "$T/antigo/.gitignore")"
[ "$antes" = "$depois" ] || { echo "FAIL [6]: bloco cresceu de $antes para $depois linhas numa reconciliação sem mudança"; exit 1; }
dups="$(grep -c '^# >>> forge (managed) >>>$' "$T/antigo/.gitignore")"
[ "$dups" = "1" ] || { echo "FAIL [6]: $dups marcadores de abertura no arquivo"; exit 1; }
echo "OK [6]"

echo "OK"
