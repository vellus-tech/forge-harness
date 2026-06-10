---
name: verify-diff-claims
description: |
  Skill determinística usada pelo `code-evaluator` na Fase 1.2 para detectar alucinação textual: confronta o que o coder agent afirmou no commit message / PR description com o que o `git diff` realmente contém. Emite findings `CLAIM-NNN` quando há claim sem evidência (ex.: "adicionei IPaymentRepository" mas o símbolo não existe no diff).
---

# Skill: verify-diff-claims

## Quando Usar

Invocada pelo `code-evaluator` na **Fase 1.2**, após `verify-build` passar. Determinística (grep/AST/diff stat), barata, executa em segundos. Detecta alucinação textual antes de qualquer reviewer LLM.

## Inputs

```yaml
branch: feat/...
base: main
diff_sha: <sha>
```

## Comportamento

### 1. Coletar claims do coder

O "coder" pode ter deixado declarações em 3 lugares:

```bash
# Commit messages do branch
git log $base..HEAD --pretty=format:"%h%n%B%n---"

# PR description (se variável GITHUB_PR_BODY estiver setada em CI)
echo "$GITHUB_PR_BODY"

# Comentário inline `// AGENT-CLAIM:` no código
git diff $base..HEAD | grep -E "^\+.*AGENT-CLAIM:"
```

Consolidar em `/tmp/claims-raw.txt`.

### 2. Extrair claims acionáveis

Padrões reconhecidos (parsing por regex):

| Padrão | Interpretação |
|---|---|
| `add(ed|ei|cionei)?\s+([\w.]+Repository\|Service\|Handler\|Controller)` | Espera símbolo nomeado no diff |
| `cria(do|ei)?\s+endpoint\s+(GET\|POST\|PUT\|DELETE)\s+(/[^\s]+)` | Espera rota correspondente |
| `add(ed|cionei)?\s+test(s|es)?\s+(?:cover(ing|indo)?)?\s+([\w]+)` | Espera arquivo `*Tests.cs` ou `*.test.ts` tocando o símbolo |
| `migration\s+([\w]+)` | Espera arquivo de migration |
| `event\s+([\w]+(?:\.v\d+)?)` | Espera evento publicado |

Comandos sugeridos:

```bash
# Claim: "adicionei IPaymentRepository"
grep -rE "interface IPaymentRepository" --include="*.cs" $(git diff $base..HEAD --name-only)

# Claim: "endpoint POST /api/v1/payments"
grep -rE "\[HttpPost\(\"v1/payments|MapPost\(\"v1/payments|@PostMapping.*payments" \
  $(git diff $base..HEAD --name-only)

# Claim: "teste cobrindo Split"
git diff $base..HEAD --name-only | grep -iE "Tests\.cs$|\.test\.tsx?$|\.spec\.tsx?$" | \
  xargs grep -lE "Split|split"

# Claim: "migration AddPaymentTable"
git diff $base..HEAD --name-only | grep -iE "Migrations.*AddPaymentTable"
```

### 3. Cross-check de stubs/TODOs

Detectar implementação prometida mas vazia:

```bash
# Métodos novos com corpo trivial
git diff $base..HEAD --unified=0 | grep -BE "(public|private|internal).*\b\w+\s*\(.*\)\s*=>\s*throw\s+new\s+NotImplementedException"

# TODO/FIXME no diff
git diff $base..HEAD | grep -E "^\+.*//\s*(TODO|FIXME|XXX|HACK)"
```

Stub sem TODO documentado + claim "implementei X" → CLAIM-NNN severidade `HIGH`.

### 4. Verificar consistência commit message ↔ scope

Para cada commit:

```bash
# Extrair scope do commit message: "feat(payment): ..."
SCOPE=$(git log -1 --format=%s <sha> | grep -oE "^[a-z]+\(([a-z-]+)\)" | sed 's/[^(]*(//;s/)//')

# Arquivos tocados pelo commit
FILES=$(git show --name-only --pretty="" <sha>)

# Validar que o scope corresponde aos paths
# scope "payment" deve tocar services/payment/** ou similar
```

Scope inconsistente com paths → `CLAIM-NNN` severidade `MEDIUM`.

### 5. Verificar `Co-Authored-By` proibido

```bash
git log $base..HEAD --pretty=%B | grep -iE "Co-Authored-By:\s*(Claude|Anthropic|GPT|Copilot)|Generated with.*Claude|🤖 Generated"
```

Match → finding `CLAIM-AUTHORSHIP` severidade **BLOCKER** (regra global de `.forge/constitution.md`).

## Output Obrigatório

Escrever em `/tmp/verify-diff-claims-output.json`:

```json
{
  "skill": "verify-diff-claims",
  "passed": false,
  "exit_code": 1,
  "claims_extracted": 12,
  "claims_verified": 10,
  "claims_unverified": 2,
  "findings_to_emit": [
    {
      "id": "CLAIM-001",
      "severity": "HIGH",
      "category": "anti-hallucination",
      "file": null,
      "line": null,
      "title": "Claim sem evidência: 'adicionei IPaymentRepository'",
      "description": "Commit message 'feat(payment): adicionei IPaymentRepository' afirma adição da interface, mas grep no diff não encontrou 'interface IPaymentRepository' em nenhum arquivo .cs novo/modificado.",
      "fix_suggested": "Verificar se o coder agente realmente criou a interface, ou se a claim está incorreta. Pode ser path errado (foi criado mas em local diferente), ou alucinação."
    },
    {
      "id": "CLAIM-AUTHORSHIP",
      "severity": "BLOCKER",
      "category": "compliance",
      "file": null,
      "line": null,
      "title": "Commit com co-autoria de IA",
      "description": "Commit abc123 contém 'Co-Authored-By: Claude <noreply@anthropic.com>'. Regra global proíbe atribuição de IA em commits.",
      "fix_suggested": "Rebase interativo removendo a linha Co-Authored-By dos commits afetados, ou amend + force-push.",
      "rule_violated": ".forge/constitution.md — Convenções de commit"
    }
  ],
  "matched_claims": [
    { "claim": "endpoint POST /api/v1/payments", "evidence_file": "services/payment/src/Payment.Api/Controllers/PaymentsController.cs:42" }
  ]
}
```

`exit_code`:
- `0` → todas as claims verificadas; segue para reviewers
- `1` → há claim BLOCKER (authorship); REJECTED imediato

Claims `HIGH` (sem evidência) **não** bloqueiam por si só — viram input para `logic-reviewer` e `quality-reviewer` decidirem.

## Findings que esta skill emite

| ID | Severidade | Quando |
|---|---|---|
| `CLAIM-NNN` | HIGH | Claim no commit message sem evidência grep/AST no diff |
| `CLAIM-NNN` | MEDIUM | Scope do commit inconsistente com paths tocados |
| `CLAIM-STUB-NNN` | HIGH | Método declarado "implementado" mas corpo é `throw new NotImplementedException` |
| `CLAIM-AUTHORSHIP` | BLOCKER | `Co-Authored-By: Claude` ou similar em commit |

## Anti-Patterns

- Confiar no commit message sem cross-check no diff
- Pular esta skill "porque o build passou" — build não detecta alucinação textual
- Tratar todo claim sem match como BLOCKER (muitos são `MEDIUM`/`HIGH` por ambiguidade de regex)
- Não verificar `Co-Authored-By` em todos os commits do branch

## Referências

- `.forge/constitution.md` — proibição de co-autoria de IA
- `.forge/rules/conventions/conventional-commits.md` — scopes canônicos
