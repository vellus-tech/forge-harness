#!/usr/bin/env bash
# lib/scan-exclude.sh — diretórios que NENHUM gate deve varrer (issue #76).
#
# O `update` passou a criar o backup em `.git/forge-backups/`, fora da árvore, o que resolve a
# classe na origem. Esta lista cobre o resíduo: todo consumidor que já rodou uma versão anterior
# tem um `.forge.bak-N` dentro do repositório, e enquanto ele existir os gates que varrem por
# caminho varrem também a CÓPIA — e reprovam por conteúdo que é duplicata deles mesmos.
#
# Medido em consumidor real: `check-data-governance.sh --path .` acusava conflito de RLS; movendo
# só o backup para fora, no mesmo commit, passava. O pior caso é o `check-secrets.sh`, onde um
# segredo já corrigido no original continua presente na cópia e reprova para sempre.
#
# Uso:
#   . "$SCRIPT_DIR/lib/scan-exclude.sh"
#   find "$root" $(forge_find_prune) -type f ...      # bash 3.2: sem arrays associativos
#   forge_scan_skip "$caminho" && continue            # para laços que já têm a lista
FORGE_SCAN_EXCLUDE="${FORGE_SCAN_EXCLUDE:-.git node_modules .forge.bak-* dist build out obj coverage vendor}"

forge_find_prune() {  # ecoa a cláusula -prune para `find`
  local pat out=""
  for pat in $FORGE_SCAN_EXCLUDE; do
    out="$out -name '$pat' -o"
  done
  [ -n "$out" ] && printf '( %s -false ) -prune -o' "${out% -o}"
}

forge_scan_skip() {  # forge_scan_skip <caminho> — 0 quando o caminho deve ser PULADO
  # `case` sobre o caminho INTEIRO, sem mexer em IFS. A versão anterior fatiava o caminho com
  # IFS='/' e, no laço de dentro, a MESMA variável fatiava a lista de padrões — que é separada por
  # espaço. Resultado medido: nada casava, e a função devolvia "varre" para tudo, inclusive para o
  # `.forge.bak-1` que ela existe para excluir. Uma exclusão que nunca exclui é pior que nenhuma,
  # porque parece proteção.
  local p="$1" pat
  for pat in $FORGE_SCAN_EXCLUDE; do
    case "/$p" in
      */"$pat"/*) return 0 ;;
      */"$pat") return 0 ;;
    esac
    # padrões com glob (`.forge.bak-*`) precisam de casamento sem aspas
    case "/$p" in
      */$pat/*) return 0 ;;
      */$pat) return 0 ;;
    esac
  done
  return 1
}
