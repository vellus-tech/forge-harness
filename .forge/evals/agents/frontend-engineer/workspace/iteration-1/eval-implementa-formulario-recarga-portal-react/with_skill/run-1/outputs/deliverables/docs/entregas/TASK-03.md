# Entrega — TASK-03: formulário de recarga do cartão

## Resumo do que foi alterado

Implementado o formulário de recarga do cartão de transporte no `portal-passageiro`, cobrindo REQ-RC-01 a REQ-RC-05: botões de valor rápido (R$ 10, R$ 20, R$ 50), campo de outro valor com validação de faixa (R$ 5,00 a R$ 500,00), envio para `POST /v1/recargas` com header `Idempotency-Key`, tratamento de erro de negócio (`LIMITE_DIARIO_EXCEDIDO`, `CARTAO_BLOQUEADO`) preservando o valor digitado, proteção contra duplo envio e tela de confirmação com o `status` retornado pela API.

## Arquivos alterados

- `apps/web/portal-passageiro/src/services/rechargeService.ts` (novo) — client tipado para `POST /v1/recargas`, mapeando 422 de negócio para `RechargeBusinessError`.
- `apps/web/portal-passageiro/src/features/recharge/amount.ts` (novo) — parsing/formatação de moeda pt-BR (string ↔ centavos) e geração de `Idempotency-Key`.
- `apps/web/portal-passageiro/src/features/recharge/RechargeForm.tsx` (novo) — componente do formulário (`react-hook-form` + `zod`, `useMutation` do TanStack Query, `Button` de `@bilhetagem/ui`).
- `apps/web/portal-passageiro/src/features/recharge/RechargeForm.module.css` (novo) — estilos usando os tokens existentes em `packages/ui/src/tokens.css` (sem token fantasma).
- `apps/web/portal-passageiro/src/features/recharge/RechargeForm.test.tsx` (novo) — 4 testes de comportamento (Testing Library + `user-event`).
- `docs/product/modules/recarga/tasks.md` — TASK-03 marcada como `[X]`.

## Decisões de design

- **Amount como string no formulário, centavos no contrato**: o campo aceita `"10,00"`/`"10.00"`, convertido para `amountCents` inteiro antes de chamar a API — evita erro de ponto flutuante em valor monetário e casa com o schema OpenAPI (`amountCents` em centavos, 500–50000).
- **Idempotency-Key por tentativa de clique**: uma chave UUID nova é gerada a cada `mutate()` (um clique = uma tentativa), e o botão fica desabilitado (`loading`/`disabled` do `Button`) enquanto a mutation está pendente, além de um guard em `onSubmit` — cobre REQ-RC-04 (um clique, no máximo uma cobrança) sem depender de retry automático do lado do cliente.
- **Sem novo token de design**: reaproveitados os tokens já existentes (`--surface-card`, `--space-*`, `--text-primary`, `--color-danger-500`, `--color-success-500`, `--radius-md`, `--focus-ring`). Notei que `HistoryPage.module.css` usa `var(--surface-1, #fff)` — `--surface-1` não existe em `packages/ui/src/tokens.css` (token fantasma, mascarado pelo fallback `#fff`). Não toquei nesse arquivo por estar fora do escopo da TASK-03; sinalizo para correção à parte.
- **react-hook-form + zod**: já eram dependências do `package.json` do app (não instalei nada novo), então usei o padrão indicado nas regras do agente (§17) em vez de estado manual com `useState`.

## Testes executados

```
pnpm --filter portal-passageiro test
```

Resultado: 2 arquivos de teste, 6 testes, todos verdes (2 pré-existentes de `HistoryPage` + 4 novos de `RechargeForm`, cobrindo valor rápido + confirmação com status, valor fora da faixa sem chamar a API, erro de negócio preservando o valor digitado, e não duplicação de cobrança em cliques repetidos).

## Testes recomendados

- Teste E2E do fluxo completo de recarga no `portal-passageiro` (Playwright/Cypress), quando o projeto adotar E2E para este app.
- Teste de resposta `409` (Idempotency-Key reaproveitada com payload diferente) — o contrato define esse caso, mas não há requirement explícito (REQ-RC-01..05) cobrindo a UX dessa resposta; hoje ela cai no tratamento de erro técnico genérico.

## Riscos conhecidos

- `pnpm --filter portal-passageiro exec tsc --noEmit` e `pnpm --filter portal-passageiro run lint` já falhavam antes desta mudança, por lacunas do fixture (sem `vite/client` nos tipos — `ImportMeta.env` e `*.module.css` não resolvem —, tipos de `react`/`jest-dom` conflitando, e sem `eslint.config.js`). Os mesmos erros aparecem em arquivos que eu não toquei (`HistoryPage.tsx`, `Button.tsx`), então não são regressão desta TASK; ficou registrado aqui em vez de "corrigido silenciosamente" porque mexer em tooling do projeto está fora do escopo pedido.
- Não medi build de produção (`vite build`) pois depende do mesmo `tsc -b` que já falha na baseline.

## Impacto visual/UX

Formulário com hierarquia visual simples: grupo de botões de valor rápido, campo de outro valor, erro inline associado por `aria-describedby`, mensagem de erro de negócio como alerta, estado de confirmação substituindo o formulário com `role="status"`. Foco visível herdado do `Button` e do input (outline com `--focus-ring`). Não testei visualmente em navegador real (sem Playwright disponível nesta execução) — validação foi via Testing Library (DOM/acessibilidade) e leitura do CSS.

## Pendências

- Token fantasma `--surface-1` em `HistoryPage.module.css` (pré-existente, fora do escopo da TASK-03) — recomendo abrir tarefa própria para trocá-lo por `--surface-card`.
- Lacunas de tooling do fixture (tipos de Vite, eslint flat config) não corrigidas — fora do escopo da TASK-03; sinalizadas na seção de riscos.
