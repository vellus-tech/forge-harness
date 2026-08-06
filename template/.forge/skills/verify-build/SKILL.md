---
name: verify-build
description: |
  Skill determinística usada pelo `code-evaluator` antes de gastar tokens com reviewers LLM. Detecta a stack do diff (`.cs` → .NET, `.ts/.tsx` → Node, `.java` → Java, `.py` → Python, `.kt/.kts` → Gradle) e roda compilação + testes. Retorna JSON com `passed: true/false`, lista de erros estruturada e métricas (coverage por camada quando disponível). Falha aqui = `REJECTED` imediato, sem chamar reviewers.
---

# Skill: verify-build

## Quando Usar

Invocada pelo `code-evaluator` na **Fase 1.1** do pipeline de review, antes de qualquer reviewer LLM. Determinística: o resultado é o veredito do compilador/test runner, não opinião de modelo.

## Inputs

```yaml
branch: feat/...
base: main
diff_sha: <sha>
strict_mode: true     # se true, warnings de compilação contam como erro
```

## Comportamento

### 1. Detectar stacks afetadas

```bash
git diff --name-only $base..HEAD | tee /tmp/changed-files.txt
```

Classifica:

| Padrão de arquivo | Stack |
|---|---|
| `*.cs`, `*.csproj`, `*.sln` | dotnet |
| `*.ts`, `*.tsx`, `package.json`, `*.config.ts` | node |
| `*.java`, `pom.xml` | java |
| `*.py`, `pyproject.toml`, `requirements*.txt` | python |
| `*.kt`, `*.kts`, `build.gradle*` | gradle |
| `Dockerfile`, `*.yaml` (K8s), `.github/workflows/*.yml` | infra (build a partir do contexto) |

Para cada stack detectada, executa o pipeline correspondente. Múltiplas stacks → executar em **paralelo** (jobs independentes do shell).

### 2. Pipeline .NET

```bash
# Restaurar
dotnet restore --nologo --verbosity quiet

# Compilar — sem warnings em strict_mode
if [ "$strict_mode" = "true" ]; then
  dotnet build --no-restore --nologo -warnaserror -p:TreatWarningsAsErrors=true 2>&1
else
  dotnet build --no-restore --nologo 2>&1
fi
BUILD_EXIT=$?

# Testar com coverage
dotnet test --no-build --nologo \
  --collect:"XPlat Code Coverage" \
  --results-directory /tmp/coverage-dotnet \
  --logger "trx;LogFileName=test-results.trx" 2>&1
TEST_EXIT=$?

# Extrair coverage por projeto
find /tmp/coverage-dotnet -name "coverage.cobertura.xml" -exec \
  grep -oE "line-rate=\"[0-9.]+\".*branch-rate=\"[0-9.]+\"" {} \;
```

### 3. Pipeline Node/TypeScript

```bash
# Detectar package manager
if [ -f pnpm-lock.yaml ]; then PM=pnpm
elif [ -f yarn.lock ]; then PM=yarn
else PM=npm; fi

# Instalar
$PM install --frozen-lockfile 2>&1 || $PM ci 2>&1
INSTALL_EXIT=$?

# Type check
$PM exec tsc --noEmit 2>&1
TSC_EXIT=$?

# Lint (ESLint)
$PM exec eslint --max-warnings=0 . 2>&1
LINT_EXIT=$?

# Test com coverage
$PM test -- --coverage --coverageReporters=json-summary 2>&1
TEST_EXIT=$?
```

### 4. Pipeline Kotlin/Gradle

```bash
./gradlew --no-daemon assembleDebug 2>&1
BUILD_EXIT=$?

./gradlew --no-daemon testDebugUnitTest jacocoTestReport 2>&1
TEST_EXIT=$?
```

### 5. Pipeline Java

Use o wrapper e o build tool existentes; nunca troque Maven por Gradle (ou vice-versa) durante a verificação.

```bash
if [ -x ./mvnw ]; then ./mvnw -B verify
elif [ -f pom.xml ]; then mvn -B verify
elif [ -x ./gradlew ]; then ./gradlew --no-daemon test
else echo "FAIL: Java sem Maven/Gradle wrapper ou ferramenta disponível"; exit 1
fi
```

### 6. Pipeline Python

Use o gerenciador e os comandos declarados no projeto. Para `pyproject.toml`, não instale globalmente; crie/consuma o ambiente virtual já definido pela ferramenta do repositório.

```bash
# Exemplos condicionais: o runtime do FORGE.md vence.
python -m pytest
ruff check .
```

Se o projeto declara mypy ou pyright no runtime, execute-o; caso contrário, reporte typecheck como não configurado, não como aprovado.

### 7. Pipeline Infra (validações estáticas)

Sem compilação real, mas valida sintaxe:

```bash
# Dockerfile lint
docker buildx build --check . 2>&1 || hadolint Dockerfile 2>&1

# K8s YAML
find . -path './platform/k8s/*.yaml' -exec kubectl --dry-run=client apply -f {} \; 2>&1

# GitHub Actions
find .github/workflows -name "*.yml" -exec actionlint {} \; 2>&1
```

## Output Obrigatório

Escrever em `/tmp/verify-build-output.json`:

```json
{
  "skill": "verify-build",
  "passed": false,
  "exit_code": 1,
  "stacks_detected": ["dotnet", "node"],
  "results": {
    "dotnet": {
      "build": { "passed": true, "warnings": 2, "errors": 0 },
      "test": {
        "passed": false,
        "total": 142,
        "failed": 3,
        "failures": [
          {
            "test": "PaymentTests.Split_Negative_Throws",
            "file": "services/payment/tests/Payment.Domain.Tests/PaymentTests.cs",
            "line": 87,
            "message": "Expected DomainException but got InvalidOperationException"
          }
        ]
      },
      "coverage": {
        "Payment.Domain": { "line": 0.94, "branch": 0.88 },
        "Payment.Application": { "line": 0.82, "branch": 0.79 }
      }
    },
    "node": {
      "typecheck": { "passed": true },
      "lint": { "passed": true, "warnings": 0 },
      "test": { "passed": true, "total": 87, "failed": 0 },
      "coverage": { "overall": { "lines": 0.81, "branches": 0.76 } }
    }
  },
  "duration_seconds": 142,
  "findings_to_emit": [
    {
      "id": "BUILD-001",
      "severity": "BLOCKER",
      "category": "build",
      "file": "services/payment/tests/Payment.Domain.Tests/PaymentTests.cs",
      "line": 87,
      "title": "Teste falhou: PaymentTests.Split_Negative_Throws",
      "description": "Expected DomainException but got InvalidOperationException",
      "fix_suggested": "Verificar tipo de exceção lançada por Payment.Split() com valor negativo. Provavelmente a guard clause foi removida ou o tipo de exceção mudou."
    }
  ]
}
```

`exit_code`:
- `0` → tudo passou; o `code-evaluator` segue para reviewers
- `1` → algo falhou; `code-evaluator` emite `REJECTED` imediato com os findings desta skill

## Findings que esta skill emite

| ID | Severidade | Quando |
|---|---|---|
| `BUILD-NNN` | BLOCKER | Compilação falhou |
| `TEST-NNN` | BLOCKER | Teste falhou |
| `COVERAGE-NNN` | BLOCKER | Domain < 95% linha ou < 90% branch |
| `COVERAGE-NNN` | HIGH | Application < 85%/80%, Infra < 70%, Frontend < 80%/75% |
| `LINT-NNN` | HIGH | ESLint error (não warning) ou `dotnet format` divergente |
| `TYPECHECK-NNN` | BLOCKER | `tsc --noEmit` falhou |

## Anti-Patterns

- Rodar testes sem compilação prévia
- Aceitar warnings em modo strict
- Ignorar coverage gates
- Continuar fluxo se uma stack falhou (todas as stacks devem passar)
- Mockar comando externo (compilador/runner é a verdade)

## Referências

- `.forge/rules/testing/quality-gates.md` (thresholds de coverage)
- `.forge/rules/testing/tdd.md`
