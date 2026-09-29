# Design — estorno-parcial-pix

## 1. Contexto e restrições

O agregado `Pagamento` (services/pagamentos/Domain) já guarda `ValorOriginal` como `ValorMonetario` em centavos (ADR-0003, Aceito). A devolução ao pagador usa o adaptador `PspPixClient` existente, assíncrono via fila `pix.devolucoes` (ADR-0006, Aceito). Rule `api-and-contracts.md`: rotas versionadas em `/api/v1`, kebab-case.

## 2. Decisão técnica

Novo agregado filho `Estorno` dentro do agregado `Pagamento` (não agregado raiz próprio), para que o limite acumulado seja invariante de um único agregado e protegido por concorrência otimista (`row_version`). Fluxo: controller → `SolicitarEstornoParcialHandler` → `Pagamento.SolicitarEstorno(valor, chave)` → persiste → publica `EstornoSolicitadoV1` → worker envia ao PSP e aplica `EstornoConfirmado`/`EstornoRejeitado`.

Idempotência: tabela `idempotency_keys (chave, lojista_id, hash_corpo, resposta, expira_em)` com unique `(lojista_id, chave)`; TTL 24 h por job de limpeza.

## 3. Invariantes e propriedades

| ID | Invariante | Onde é garantida | PBT previsto |
|---|---|---|---|
| INV-01 | soma(estornos não rejeitados) ≤ ValorOriginal | `Pagamento.SolicitarEstorno` + row_version | PBT-01: sequência aleatória de pedidos e rejeições nunca viola o limite |
| INV-02 | valor de estorno > 0 e em centavos inteiros | `ValorMonetario.Criar` | PBT-02: gerador de longs, só > 0 aceitos |
| INV-03 | mesma (lojista, chave) → mesma resposta em 24 h | `IdempotencyStore` | PBT-03: repetições intercaladas devolvem resposta idêntica e 1 só estorno |

## 4. Alternativas consideradas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| `Estorno` como agregado raiz | desacopla escrita | limite vira invariante entre agregados, exige saga ou lock distribuído | invariante INV-01 ficaria eventual |
| Lock pessimista (`SELECT FOR UPDATE`) | simples | contenção sob carga, fere NFR-01 | concorrência otimista basta, conflito é raro |

## 5. Contratos e integrações afetados

`POST /api/v1/pagamentos/{id}/estornos` (novo, aditivo). Evento `EstornoSolicitadoV1` (novo). Migration `0012_estornos_e_idempotency_keys` (expand-only, sem alterar colunas existentes).

## 6. Plano de rollout

Feature flag `estorno_parcial_pix` por lojista; ligado primeiro para 3 lojistas piloto.

## 7. Riscos e mitigação

| Risco | Probabilidade | Impacto | Mitigação / detecção |
|---|---|---|---|
| PSP rejeita devolução parcial | baixa | médio | `EstornoRejeitado` libera o saldo (INV-01 conta só não rejeitados); alerta em taxa de rejeição > 2% |
| conflito de row_version sob pico | média | baixo | retry 3x com backoff no handler; métrica `estorno_conflito_total` |

## 8. Rastreabilidade

| REQ / NFR | Seção do design | Invariante / PBT |
|---|---|---|
| REQ-01 | §2, §5 | INV-02 / PBT-02 |
| REQ-02 | §2, §3 | INV-01 / PBT-01 |
| REQ-03 | §2 | INV-03 / PBT-03 |
| NFR-01 | §4 (concorrência otimista), §7 | teste de carga k6 |
