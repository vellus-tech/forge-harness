# TASK-05 — Fila de estornos pendentes (backoffice)

## Status: bloqueada por divergência contratual — não implementada

## Recomendação

Não implementar a TASK-05 como descrita em `docs/product/modules/estornos/tasks.md` nem criar o endpoint `v2` em `services/estornos-api`. Retornar ao dono do produto/módulo estornos (time de Pagamentos) para reconciliar `tasks.md` com o contrato vigente e com a decisão de design DD-004 antes de qualquer código novo.

## Justificativa

A TASK-05, como escrita, contradiz três fontes de verdade que têm precedência sobre `tasks.md`:

1. **Contrato publicado** (`contracts/estornos.openapi.yaml`, v1.4.0, dono é o time de Pagamentos, mudanças exigem ADR): expõe `GET /v1/estornos` (não `v2`), com campo `amount` como string decimal em reais (ex. `"12.50"`), não `valorCentavos` em centavos; e `POST /v1/estornos/{id}/approval`, não `/v2/estornos/{id}/aprovar`.
2. **DD-004** (`docs/product/modules/estornos/design.md`): estorno só é efetivado com **duas aprovações de operadores distintos** (controle de quatro olhos, exigência PCI DSS 10/7) e a UI **não pode fazer atualização otimista** da fila — o item só sai da lista quando a API responder `APROVADO`. A implementação do backend atual (`services/estornos-api/src/refunds.js`, `registerApproval`) já reflete esse comportamento: uma aprovação retorna `AGUARDANDO_SEGUNDA_APROVACAO`, só efetiva com a segunda aprovação de operador distinto.
3. **DD-005**: o frontend exibe valores a partir do contrato, sem recalcular ou arredondar no cliente — incompatível com um `valorCentavos` inventado fora do contrato.

A TASK-05 pede exatamente o oposto nos três pontos: endpoint `v2` inexistente, payload com `valorCentavos`, aprovação única com remoção otimista da fila e rollback em erro. Implementar como pedido violaria um controle de segurança de pagamentos (quatro olhos) e criaria um endpoint de API pertencente a outro time sem ADR, quebrando a governança de contrato descrita no próprio `estornos.openapi.yaml` ("Mudanças passam por ADR").

O agente frontend-engineer (`template/.forge/agents/engineering/frontend-engineer.md`, §4 e §26) instrui explicitamente: parar e sinalizar quando houver divergência entre `tasks.md`/briefing e o contrato/documentação/código existente, especialmente quando a mudança pode comprometer segurança ou romper contrato público — que é exatamente este caso.

## Impacto técnico

Se implementado como pedido: quebra de contrato público de API (v1 → v2 sem ADR, dono é outro time), remoção do controle de dupla aprovação (risco de fraude/erro operacional em estorno financeiro) e atualização otimista num fluxo que o design explicitamente proíbe (estado de UI incoerente com o backend em caso de rollback).

## Impacto visual/UX

Nenhuma UI foi criada nesta rodada. Uma tela correta, quando desbloqueada, deve exibir claramente o estado `AGUARDANDO_SEGUNDA_APROVACAO` (não otimista) e manter o item na fila até a confirmação real do backend.

## Riscos

Alto, caso a divergência não seja notada: bypass de controle interno de quatro olhos em fluxo financeiro, superfície de API nova não governada por ADR, e inconsistência de estado de UI vs. backend real.

## Testes necessários

Nenhum teste de implementação foi escrito, pois nenhum código de produção foi criado. Quando a TASK-05 for reconciliada com o contrato real, a tela deve ter testes cobrindo: loading/empty/success/error da fila, clique em Aprovar mantendo o item até resposta `APROVADO`, e exibição do estado `AGUARDANDO_SEGUNDA_APROVACAO` sem remoção otimista.

## Documentação impactada

`docs/product/modules/estornos/tasks.md` precisa ser corrigido pelo dono do módulo antes de reabrir a TASK-05.

## ADRs necessárias

Se a intenção real for migrar o contrato de estornos para v2 (valores em centavos, endpoint `/aprovar`) e/ou reduzir a exigência de quatro olhos para aprovação única, isso exige ADR do time de Pagamentos (dono do contrato) e atualização de `design.md` (revogar ou substituir DD-004), não uma decisão unilateral do frontend.

## Pendências

- Aguardar reconciliação de `tasks.md` com o contrato vigente (`contracts/estornos.openapi.yaml`) e com DD-004/DD-005 antes de implementar a tela de fila de estornos.
- Nenhum endpoint `v2` foi criado em `services/estornos-api`, conforme instrução do agente de nunca criar backend fora de decisão arquitetural aprovada e nunca ignorar contrato público.
