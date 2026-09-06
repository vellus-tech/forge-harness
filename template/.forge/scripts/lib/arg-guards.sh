#!/usr/bin/env bash
# lib/arg-guards.sh — disciplina de parsing de flags para scripts de registro (issue #103).
#
# Duas recusas que todo parser de flags precisa e que quase nenhum tem por default:
#
#   forge_reject_unknown  — argumento que o subcomando não conhece REPROVA, nunca é descartado.
#   forge_require_value   — flag de campo com valor VAZIO REPROVA, nomeando a flag.
#
# Por que a primeira. Um `case` que termina em `*) shift ;;` engole a flag E, na iteração
# seguinte, o VALOR dela: `ledger-ops.sh add --type x --title y --details "texto longo"` (typo em
# `--detail`) descartava as duas palavras e criava a entrada com `detail: ''`, imprimindo `OK`. Os
# seis subcomandos de `ledger-ops.sh` terminavam assim; três entradas abertas do ledger deste
# repositório nasceram sem `detail` no mesmo instante, e não há como provar retroativamente qual
# das duas portas silenciosas as produziu.
#
# Por que a segunda. `update <id> --detail ""` passava por `if (de) e.detail = de;`, que trata
# string vazia como falsa: o campo não mudava, `updated_at` avançava, e o comando respondia `OK`.
# O commit anunciava um conteúdo que o ledger não carregava.
#
# O idioma vem de `liaison-ops.sh::_reject_unknown` (22 usos naquele arquivo, inclusive dentro do
# próprio `ack)`), e a mensagem preserva o formato de lá — nomear o subcomando importa porque o
# conjunto de flags varia por subcomando: sem isso, quem digitou `--body-file` num `ack` conclui
# que a flag não existe em lugar nenhum. Este arquivo NÃO substitui a cópia de `liaison-ops.sh`;
# consolidar os dois é trabalho próprio, fora do escopo desta correção.

# forge_reject_unknown <subcomando> <flags aceitas> <argumento> [dica]
# Sempre encerra o processo com rc 1 — é chamada no ramo `*)` do `case` de parsing.
forge_reject_unknown() {
  local sub="$1" accepted="$2" arg="$3" hint="${4:-}"
  case "$arg" in
    -*) echo "FAIL: flag desconhecida '$arg' para o subcomando '$sub'" >&2 ;;
    *)  echo "FAIL: argumento inesperado '$arg' para o subcomando '$sub'" >&2 ;;
  esac
  echo "  flags aceitas em '$sub': $accepted" >&2
  echo "  argumento desconhecido não é descartado: o descarte engole a flag E o valor dela, e a" >&2
  echo "  operação segue com rc 0 sobre um registro incompleto." >&2
  [ -z "$hint" ] || echo "  $hint" >&2
  exit 1
}

# forge_require_value <subcomando> <flag> <valor>
# Recusa valor vazio numa flag de conteúdo. Encerra o processo com rc 1 quando vazio.
forge_require_value() {
  local sub="$1" flag="$2" value="${3-}"
  [ -n "$value" ] && return 0
  echo "FAIL: '$flag' veio com valor vazio no subcomando '$sub'." >&2
  echo "  Valor vazio não apaga campo nem grava conteúdo: antes desta guarda o comando respondia" >&2
  echo "  'OK' e só avançava 'updated_at', o que faz a entrada parecer recente sem carregar" >&2
  echo "  informação nova. Passe um valor, ou omita a flag." >&2
  exit 1
}
