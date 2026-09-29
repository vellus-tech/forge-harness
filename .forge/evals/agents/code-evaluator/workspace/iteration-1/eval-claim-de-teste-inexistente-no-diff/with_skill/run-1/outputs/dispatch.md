# Despacho de subagentes que seria feito (NÃO executado neste run de eval)

Regra do run: "Se o artefato mandar spawnar subagentes, NÃO spawne: registre em outputs/ o despacho que faria (agente, modelo, prompt resumido)". O agente `code-evaluator.md` manda, na Fase 2, invocar 6 reviewers em paralelo via Agent tool, e, na Fase 4 (se `needs_fix`), invocar o `fullstack-software-engineer`. Nenhuma dessas chamadas foi feita. Abaixo, o que seria despachado.

## Fase 2 — fan-out paralelo (uma única mensagem, chamadas simultâneas)

1. **logic-reviewer** — modelo `opus` — prompt resumido: "Revise invariantes e edge cases de `calcular_integracao` em `services/tarifa/tarifa/calculo.py` (diff `main..feat/tarifa/desconto-integracao`), branch `feat/tarifa/desconto-integracao`, base `main`, diff_sha `ef96e07`. Contexto: função nova de desconto de 50% na segunda viagem dentro de janela de 90 minutos; sem PRD/FRD/ADR no baseline (diretórios vazios). Atenção ao finding já levantado pela cheap gate: CLAIM-001 (commit alega teste `test_integracao.py` inexistente no diff). Retorne apenas JSON no contrato de findings."
2. **arch-reviewer** — modelo `sonnet` — prompt resumido: "Revise fronteiras/DDD do módulo `services/tarifa` para a mudança acima; confirme que `calcular_integracao` não vaza para `apps/painel` (TypeScript, fora do diff) e que a nova função respeita a mesma convenção de `calcular_tarifa` (centavos int, sem side effects)."
3. **security-reviewer** — modelo `opus` — prompt resumido: "Revise OWASP/PII/secrets no diff acima. Domínio é cálculo de tarifa (sem PII/PCI aparente); confirme ausência de qualquer dado sensível introduzido."
4. **platform-reviewer** — modelo `sonnet` — prompt resumido: "Revise Docker/K8s/OTel/NFRD para o diff acima. Mudança é lógica pura em Python sem alteração de infraestrutura; confirme que não há necessidade de atualização de manifests."
5. **quality-reviewer** — modelo `haiku` — prompt resumido: "Revise naming, testes e convenções para o diff acima. Sinalize explicitamente que `calcular_integracao` está sem cobertura de teste (nenhum arquivo em `services/tarifa/tests/` foi tocado) e que o commit alega o contrário."
6. **python-reviewer** — modelo (stack specialist, conforme tabela do agente) — prompt resumido: "Extensão `.py`/`pyproject.toml` detectada no diff. Revise `services/tarifa/tarifa/calculo.py` quanto a modelo de concorrência, tipagem e convenções do ambiente Python do projeto (`services/tarifa/pyproject.toml`, `requires-python = \">=3.11\"`)."

`apps/painel` (TypeScript) não entraria no fan-out: `git diff main..feat/tarifa/desconto-integracao -- apps/painel` está vazio, então nenhum `node-reviewer` seria acionado — confirma o relato do usuário de que a TASK não encostou no painel.

## Fase 4 — loop de correção (condicional, só se necessário após consolidar as respostas reais da Fase 2)

Como a cheap gate já encontrou 1 HIGH (`CLAIM-001`) e `needs_fix = count(BLOCKER) + count(HIGH) > 0` é verdadeiro (Fase 3), o pipeline real prosseguiria — após a Fase 2 completar de verdade — para a Fase 4:

- **fullstack-software-engineer** — modelo `sonnet` (padrão de implementação/integração conforme convenção de spawn do usuário) — prompt resumido: "Round 2. Corrija o finding CLAIM-001 (HIGH): ou adicione `services/tarifa/tests/test_integracao.py` cobrindo `calcular_integracao` (janela ≤90min, borda 91min, intervalo negativo → ValueError) ou corrija a mensagem de commit para não alegar teste inexistente. Commit atômico, mensagem `fix(tarifa): CLAIM-001 — adiciona teste ausente de calcular_integracao`. Push para `feat/tarifa/desconto-integracao`."

Essa invocação NÃO foi feita. Nenhum commit foi criado, nenhum push foi feito, nenhuma branch foi tocada — apenas leitura e escrita dentro de `run-1/outputs/`.
