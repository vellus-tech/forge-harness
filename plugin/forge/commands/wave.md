---
description: Gerencia o plano de waves do change ativo — plan (deriva waves das stories), open (abre wave respeitando deps), close (fecha com gate), status (one-line). Artefatos operados por script determinista (nunca modelo relendo tudo).
argument-hint: "plan|open|close|status [<change-id>] [<wave-id>]"
---

# /forge:wave — gerenciamento de waves

Argumentos: `$ARGUMENTS` (subcomando + change-id opcional + wave-id onde aplicável).

Todos os subcomandos deleguem ao script determinista — não leia nem reescreva waves.json nem progress.json diretamente:

```bash
bash .forge/scripts/wave-ops.sh <sub> <change-id> [<wave-id>] [--gate OK|FAIL]
```

## Subcomandos

### plan

Deriva `waves.json` a partir das stories em `stories/` do change.

```bash
bash .forge/scripts/wave-ops.sh plan <change-id>
```

- Pré-condição: `dev_loop.sharded: true` no manifest (`/forge:shard` já rodado).
- Resultado: `waves.json` + `progress.json` inicializados; one-line de resposta.

Wave 0 sempre contém stories sem dependências (fundação). Waves subsequentes respeitam topologia.

### open

Abre uma wave — **recusa se alguma dependência (`depends_on`) não estiver `closed`**.

```bash
bash .forge/scripts/wave-ops.sh open <change-id> <wave-id>
```

- Se a wave já estiver `open`: erro (não é idempotente por design — abrir duas vezes indica erro de orquestração).
- Emite one-line de confirmação.

### close

Fecha a wave aberta após verificar gates.

```bash
# Rode o gate-runner da wave (skill gate-runner) e capture o resultado
gate_result="$(bash .forge/scripts/run-gates.sh <change-id> <wave-id> 2>&1 | tail -1)"
# Só feche se OK
bash .forge/scripts/wave-ops.sh close <change-id> <wave-id> --gate "$gate_result"
```

- Recusa se `gate_result` for `FAIL`.
- **Última wave**: antes de fechar, verifique que não há `deferral` `open`:
  ```bash
  bash .forge/scripts/deferral-ops.sh status <change-id>
  ```
  Se houver `OPEN (...)`, não feche — escale via HITL.

### status

Resumo de uma linha do estado atual.

```bash
bash .forge/scripts/wave-ops.sh status <change-id>
```

Exemplo de saída: `OK: waves: 1/3 closed; open: W1; stories: 4/9; deferrals: 0 open`

## Regras

- Dados em waves.json/progress.json são fonte de verdade — nunca use o modelo para reconstruir estado a partir dos artefatos do change.
- `/forge:wave close` na última wave + todos os deferrals `tested` → pré-condição para `/forge:close`.
- Sem `wave close --gate FAIL` — gate com FAIL é bloqueante; corrija e reabra.
