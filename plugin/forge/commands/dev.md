---
description: Ambiente de desenvolvimento local — up (sobe stack), sync (migrations + seeds), smoke (validação pré-PR). Lê configuração do FORGE.md runtime. Todos os subcomandos com timeout explícito.
argument-hint: "up|sync|smoke [--env <dev|test>]"
---

# /forge:dev — ambiente local de desenvolvimento

Argumentos: `$ARGUMENTS` (subcomando obrigatório + --env opcional, default: `dev`).

## Subcomandos

### up

Sobe a stack de desenvolvimento declarada em `FORGE.md runtime.dev`.

```bash
# Lê FORGE.md para extrair o compose canônico
COMPOSE_FILE="$(grep -A2 'compose:' .forge/FORGE.md | grep 'file:' | awk '{print $2}')"
perl -e 'alarm 120; exec @ARGV' -- docker compose -f "${COMPOSE_FILE:-docker-compose.yml}" up -d >/tmp/forge-dev-up.log 2>&1
[ $? -eq 0 ] && echo "OK dev:up" || { echo "FAIL dev:up (tail -20 /tmp/forge-dev-up.log)"; exit 1; }
```

### sync

Aplica migrations pendentes e seeds de desenvolvimento.

```bash
# Migrations
perl -e 'alarm 120; exec @ARGV' -- <migration-tool> migrate >/tmp/forge-dev-sync.log 2>&1
[ $? -eq 0 ] && echo "OK sync:migrations" || echo "FAIL sync:migrations"
# Seeds (opcional — só se runtime.seeds declarado)
perl -e 'alarm 60; exec @ARGV' -- <seed-tool> >/tmp/forge-dev-seed.log 2>&1
[ $? -eq 0 ] && echo "OK sync:seeds" || echo "FAIL sync:seeds"
```

As ferramentas de migration/seeds são lidas de `FORGE.md runtime.sync`. Se não declaradas: skip com aviso.

### smoke

Validação rápida pré-PR: build + testes de fumaça + healthcheck da stack.

```bash
# Build
perl -e 'alarm 180; exec @ARGV' -- <build-cmd> >/tmp/forge-dev-smoke.log 2>&1
[ $? -eq 0 ] && echo "OK smoke:build" || echo "FAIL smoke:build"
# Smoke tests (subconjunto rápido: tag @smoke ou equivalente)
perl -e 'alarm 120; exec @ARGV' -- <test-cmd> --filter smoke >/tmp/forge-dev-smoke-test.log 2>&1
[ $? -eq 0 ] && echo "OK smoke:tests" || echo "FAIL smoke:tests"
# Healthcheck
curl -sf http://localhost:${PORT:-8080}/health >/tmp/forge-dev-health.log 2>&1
[ $? -eq 0 ] && echo "OK smoke:health" || echo "FAIL smoke:health"
```

Comandos lidos de `FORGE.md runtime.smoke`. Se não declarados: skip com aviso, não falha.

## Configuração em FORGE.md

```yaml
runtime:
  dev:
    compose:
      file: docker-compose.yml
  sync:
    migrate: dotnet ef database update
    seed: dotnet run --project tools/Seeder
  smoke:
    build: dotnet build
    test: dotnet test --filter Category=Smoke
    port: 8080
```

## Regras

- Todo comando roda com `perl -e 'alarm N; exec @ARGV'` — sem comandos pendurados.
- Output bruto em `/tmp/forge-dev-*.log`; reporte apenas `OK`/`FAIL <gate>` no chat.
- `dev up` não é obrigatório em CI (stack já existe); `smoke` é obrigatório antes de `/forge:wave close`.
