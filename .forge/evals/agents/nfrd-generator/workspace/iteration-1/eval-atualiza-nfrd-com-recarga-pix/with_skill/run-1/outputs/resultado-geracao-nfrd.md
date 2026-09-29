# Resultado da Geração do NFRD

## 1. Arquivos Criados ou Atualizados

- `docs/product/frd-nfrd/nfrd.md` — atualizado de v1.0 para v1.1 (histórico de Controle de Versão preservado, nova entrada adicionada).

## 2. Cobertura por Categoria

| Categoria | Aplicável? | NFRs gerados |
|---|---|---|
| PERF | Sim | NFR-PERF-01, NFR-PERF-02 |
| DISP | Sim | NFR-DISP-01 |
| ESC | Sim | NFR-ESC-01 |
| RES | Sim | NFR-RES-01 |
| SEG | Sim | NFR-SEG-01, NFR-SEG-02 |
| PRIV | Sim | NFR-PRIV-01 |
| COMP | Não | — |
| OBS | Sim | NFR-OBS-01 |
| AUD | Sim | NFR-AUD-01 |
| INT | Sim | NFR-INT-01 |
| USA | Não | — |
| MAN | Não | — |
| POR | Não | — |
| OPS | Sim | NFR-OPS-01 |

## 3. Quantidade de Requisitos

Total: 10 NFRs (5 herdados da v1.0 sem alteração de conteúdo + 5 novos da v1.1). Distribuição por prioridade: Alta — 8 (PERF-01, DISP-01, ESC-01, RES-01, SEG-01, SEG-02, PRIV-01, OPS-01); Média — 2 (OBS-01, INT-01).

## 4. Principais Pontos a Validar

- Processo de confiança/rotação do certificado do PSP no mTLS do webhook (fora da CA interna do cluster).
- Política de retry do PSP em caso de falha no recebimento do webhook.
- Enquadramento regulatório do arranjo Pix aplicável ao emissor (categoria COMP hoje não aplicável).
- Meta de disponibilidade específica do fluxo de recarga Pix, distinta da disponibilidade geral do backend.

## 5. Observações

- Categorias ESC, RES, AUD, INT e OPS foram promovidas de "Não aplicável" (v1.0) para "Aplicável" (v1.1) em função da recarga via Pix; as justificativas de não aplicabilidade das demais categorias (USA, MAN, POR) permanecem válidas e não foram alteradas.
- Nenhum NFR da v1.0 foi modificado em conteúdo — apenas o escopo dos §§1, 2, 4, 5, 6 do documento foi ampliado para refletir a v1.1.
- `.forge/rules/architecture/mtls-internal-services.md` cobre apenas mTLS serviço-a-serviço dentro do cluster via `internal-ca` — não é reaproveitável diretamente para a fronteira com o PSP externo, daí a sugestão de ADR-0004 em vez de referenciar a rule como suficiente.

## 6. ADRs Sugeridos (delegação a adr-writer)

| ID sugerido | Título proposto | Origem (NFR) | Severidade | Justificativa breve |
|---|---|---|---|---|
| ADR-0003 | idempotencia-webhook-pagamento-psp | NFR-RES-01 | Alta | Padrão de idempotência para webhook financeiro é mecanismo transversal com custo de reversão alto; bloqueia o design do time de pagamentos que começa quarta-feira. |
| ADR-0004 | mtls-webhook-parceiro-externo | NFR-SEG-02 | Alta | Modelo de confiança mTLS para parceiro externo difere do `internal-ca` já registrado; decisão bloqueante para o mesmo design de quarta-feira. |
