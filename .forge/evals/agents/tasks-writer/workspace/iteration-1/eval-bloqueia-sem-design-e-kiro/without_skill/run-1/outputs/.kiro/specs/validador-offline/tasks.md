# Tasks — Validador Offline de Bilhetagem

- Baseado em: `docs/product/modules/validador-offline/requirements.md` (v1.0.0, Aprovado, 2026-09-15)
- Design: **não documentado** — decisão arquitetural ainda na cabeça do @rafael-costa, sem `design.md` disponível nesta base. As tasks abaixo foram derivadas diretamente dos requisitos funcionais e não funcionais; decisões de estrutura interna (camadas, contratos de armazenamento local, formato do lote de sincronização) ficam a critério de quem implementar, e merecem alinhamento rápido com o Rafael antes ou durante o desenvolvimento.
- Status: **Aprovado para desenvolvimento**

## Observação para o time

Como não há design escrito, os pontos mais sensíveis a decisão arquitetural (assinatura do cache local, formato de idempotência do lote, estratégia de fila persistente) estão marcados abaixo com nota `[decisão de design pendente]`. Recomendo um alinhamento de 15-20 min com o @rafael-costa antes de iniciar essas tasks específicas, para não haver retrabalho.

## TASK-01 — Cache local de saldo assinado e validação offline

- Origem: Req 1.1
- Implementar leitura de saldo em cache local (cartão ou QR Code) com verificação de assinatura, permitindo validar embarque sem conectividade.
- `[decisão de design pendente]`: formato de assinatura e mecanismo de armazenamento local (arquivo, banco embarcado, keystore) não estão definidos.
- Critério de aceite: embarque validado offline usando apenas dados do cache, sem chamada de rede.

## TASK-02 — Lista de bloqueio local e rejeição de embarque

- Origem: Req 1.2
- Implementar checagem do cartão/QR contra a lista de bloqueio local antes de aceitar o embarque.
- Critério de aceite: cartão presente na lista de bloqueio é rejeitado mesmo offline.

## TASK-03 — Feedback visual em até 300 ms

- Origem: RNF 1
- Garantir que o caminho crítico (toque → decisão → feedback visual) fique dentro do orçamento de 300 ms no cenário offline.
- Critério de aceite: medição de latência ponta a ponta ≤ 300 ms em teste de carga local.

## TASK-04 — Fila persistente de validações pendentes (até 72 h)

- Origem: RNF 2
- Implementar armazenamento durável das validações pendentes, resistente à queda de energia, com retenção de até 72 h.
- `[decisão de design pendente]`: estrutura da fila (WAL, banco local, arquivo append-only) e política de purga após 72 h.
- Critério de aceite: após queda de energia simulada, nenhuma validação pendente é perdida.

## TASK-05 — Sincronização em lote na reconexão

- Origem: Req 2.1
- Ao detectar conectividade, enviar as validações pendentes ao backend em lote, respeitando a ordem de ocorrência (PBT-02).
- Critério de aceite: teste de propriedade confirma que a ordem no backend é igual à ordem de ocorrência no validador.

## TASK-06 — Idempotência de reenvio de lote

- Origem: Req 2.2, PBT-01
- Garantir que reenviar um lote já aceito não gera cobrança duplicada, mesmo com múltiplas tentativas de reenvio.
- `[decisão de design pendente]`: chave de idempotência do lote (hash do conteúdo, UUID gerado no momento da validação, sequência local) não está definida — isso é a decisão de design com maior risco de retrabalho se feita errado.
- Critério de aceite: teste de propriedade confirma que reenviar um lote N vezes produz o mesmo conjunto de validações no backend (PBT-01).

## TASK-07 — Atualização periódica da lista de bloqueio (delta)

- Origem: Req 3.1
- Implementar download periódico (a cada 15 min, quando houver rede) do delta da lista de bloqueio, aplicando as mudanças ao armazenamento local usado pela TASK-02.
- Critério de aceite: lista de bloqueio local reflete o delta mais recente em até 15 min após reconexão.

## Ordem sugerida

1. TASK-01, TASK-02 (base de validação offline)
2. TASK-04 (fila persistente) — depende de decisão de design da TASK-01
3. TASK-05, TASK-06 (sincronização) — TASK-06 é a de maior risco sem design fechado
4. TASK-07 (atualização de bloqueio)
5. TASK-03 (medição de latência, transversal, validar ao final de cada task funcional)
