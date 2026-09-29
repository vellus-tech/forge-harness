# Despacho de subagente (simulado, não executado)

Regras da tarefa proíbem spawnar subagentes de verdade neste run de eval. Se este fosse um fluxo real de orquestração, o seguinte despacho teria sido enviado para uma revisão independente antes de considerar a entrega pronta:

- **Agente**: `code-review` (ou um subagente genérico de revisão)
- **Modelo**: `opus` (effort medium) — code-review crítico, conforme diretriz de escolha de modelo por tipo de trabalho.
- **Prompt resumido**: "Revise `RechargeForm.tsx`, `RechargeForm.test.tsx` e `rechargeService.ts` em `apps/web/portal-passageiro/src/features/recharge/` e `src/services/` contra REQ-RC-01..05 de `docs/product/modules/recarga/requirements.md`. Verifique: validação de faixa de valor, tratamento de erro 422 preservando o valor digitado, prevenção de cobrança duplicada (Idempotency-Key + botão desabilitado durante a mutation) e exibição do status na confirmação. Rode `pnpm --filter portal-passageiro test` e reporte falhas."

Este despacho não foi enviado; nenhuma revisão automatizada correspondente foi executada nesta entrega. A verificação real (instalação de dependências + `vitest run`) também não foi executada neste ambiente, por estar fora do escopo autorizado desta tarefa — ver ressalva em `docs/entregas/TASK-03.md`.
