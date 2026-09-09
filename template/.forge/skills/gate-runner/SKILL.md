---
name: gate-runner
description: Executa gates deterministas de uma feature/task — parseabilidade, grep positivo/negativo, anti-empty e smoke com timeout — emitindo UMA linha OK/FAIL por gate, com output bruto em /tmp. Use durante /forge:implement e /forge:verify para validar artefatos gerados sem estourar contexto.
---

# Gate Runner (v0 — §17.5)

Gates deterministas complementam os loops builder→validator (probabilísticos) com checagens objetivas e baratas. Disciplina inegociável (§17.6): **cada gate emite uma linha** `OK <gate>` ou `FAIL <gate> (<pista>)`; output bruto vai para `/tmp/gate-<nome>.log` e você lê **apenas `tail -20`** dele. Nunca cole o log no chat.

## Protocolo

1. Identifique os arquivos-alvo (os que a task tocou/gerou).
2. Selecione os gates aplicáveis (abaixo) e rode-os em sequência.
3. Qualquer `FAIL` → corrija e re-rode **só o gate que falhou** (máx. 2 tentativas; depois trate como falha irrecuperável da task: `[!]` + humano).
4. Reporte o conjunto em uma linha final: `gates: N OK, M FAIL`.

## Receitas

**Parseabilidade** (parser nativo do formato):

```bash
# JSON
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$f" >/tmp/gate-parse.log 2>&1 && echo "OK parse:$f" || echo "FAIL parse:$f"
# YAML (python3 com pyyaml; fallback: o parser da sua stack)
python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' "$f" >/tmp/gate-parse.log 2>&1 && echo "OK parse:$f" || echo "FAIL parse:$f"
# Frontmatter de .md
perl -0ne 'exit(0) if /^---\n.*?\n---/s; exit(1)' "$f" && echo "OK frontmatter:$f" || echo "FAIL frontmatter:$f"
```

**Grep positivo (OR cross-file)** — cada padrão obrigatório aparece em ao menos um arquivo-alvo:

```bash
grep -l "$PATTERN" "${FILES[@]}" >/dev/null && echo "OK grep+:$PATTERN" || echo "FAIL grep+:$PATTERN (ausente em todos os alvos)"
```

**Grep negativo (NOT cross-file)** — nenhum padrão proibido sobra:

```bash
out=$(grep -arnE 'TODO|FIXME|not implemented|console\.log\(|HACK' "${FILES[@]}" 2>/dev/null | head -5)
[ -z "$out" ] && echo "OK grep-:residuos" || { echo "$out" >/tmp/gate-grepneg.log; echo "FAIL grep-:residuos (tail -5 em /tmp/gate-grepneg.log)"; }
```

Padrões proibidos default: `TODO`/`FIXME`/`not implemented`/`HACK` residuais; `console.log(`/`print(` de debug; em-dash e pontos dentro de labels Mermaid.

**Anti-empty** — artefato existe e tem substância:

```bash
[ -s "$f" ] && [ "$(wc -l < "$f")" -ge "${MIN_LINES:-3}" ] && echo "OK anti-empty:$f" || echo "FAIL anti-empty:$f"
```

**Smoke com timeout** (anti auto-mentira — o comando roda de verdade, com exit code esperado):

```bash
perl -e 'alarm '"${TIMEOUT:-120}"'; exec @ARGV' -- bash -c "$CMD" >/tmp/gate-smoke.log 2>&1
[ $? -eq "${EXPECTED_EXIT:-0}" ] && echo "OK smoke:$NAME" || { echo "FAIL smoke:$NAME (tail -20 /tmp/gate-smoke.log)"; }
```

## Classes avançadas (manuais no MVP2; automação chega no MVP5)

- **Import-resolve** (Classe B): todo import/using aponta para arquivo/símbolo existente — verifique com o typecheck da stack quando declarado no `FORGE.md runtime:`.
- **Unused** (Classe C): sem imports/vars não usados — lint da stack.
- **Consistency cross-file** (Classe A): símbolo usado de forma consistente entre arquivos (ex.: factory vs middleware) — grep dirigido pelos contratos do design.

## Regras

- Todo comando externo roda com timeout (receita `perl alarm` acima — portátil em macOS/Linux).
- Gates não substituem os checks do `/forge:verify` — são o filtro barato POR TASK.
- Nunca "passe" um gate editando o gate; ajuste o artefato.
