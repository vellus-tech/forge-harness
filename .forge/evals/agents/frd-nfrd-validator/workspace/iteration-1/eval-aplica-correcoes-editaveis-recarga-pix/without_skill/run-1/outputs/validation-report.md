# Relatório de validação — FRD/NFRD RecargaJá vs. PRD

- **Escopo:** `docs/product/frd-nfrd/frd.md` e `docs/product/frd-nfrd/nfrd.md` contra `docs/product/prd/prd.md`.
- **Gatilho:** revisão pré-`ddd-architect`; comentário de daily sobre a matriz de rastreabilidade do FRD e o NFR de performance vago.
- **Resultado:** 2 achados corrigidos no FRD, 1 achado corrigido no NFRD. Ambos os documentos passam de v1.0.0 para v1.0.1.

## Achados no FRD

1. **Matriz de rastreabilidade invertida (bloqueante).** A tabela da seção 3 mapeava `F2 → FRD-XX` e `F3 → FRD-REC-02`, mas o conteúdo real é o oposto: FRD-REC-02 é "Consulta de saldo" (PRD F2) e FRD-XX é "Histórico de recargas" (PRD F3). Confirma o comentário da daily. Corrigido para `F2 → FRD-REC-02` e `F3 → FRD-REC-03`.
2. **Identificador de requisito não normalizado.** O requisito de histórico usava o placeholder `FRD-XX` em vez de um ID sequencial na família `FRD-REC-*`. Renomeado para `FRD-REC-03` (title do requisito e matriz de rastreabilidade).
3. **Vazamento de decisão de arquitetura no requisito funcional (achado adicional, fora do que a daily citou).** FRD-REC-01 descrevia a confirmação do Pix com stack de implementação (consumidor Kafka no tópico `pix.confirmacoes`, Spring Boot 3.3, Resilience4j, PostgreSQL 16 particionado por mês). Um FRD descreve comportamento observável pelo usuário e regras de negócio, não a solução técnica — essa decisão pertence ao `ddd-architect`/design, que ainda não rodou. Mantive apenas o comportamento (valor, QR Code, expiração, confirmação do PSP, disponibilização do crédito) e removi o trecho de stack; nenhuma informação foi perdida, pois ela deve ser (re)decidida no DDD com contexto de arquitetura completo, não herdada de um rascunho do FRD.

## Achados no NFRD

1. **NFR de performance vago (bloqueante, citado na daily).** `NFRD-PERF-01` tinha como métrica o próprio adjetivo "Rápida", sem número, enquanto o PRD §6 já define um limiar objetivo: "95% das recargas devem ter o crédito disponível em até 10 segundos após a confirmação do Pix". Corrigido para expressar esse limiar como p95 ≤ 10s, com método de validação mensurável (teste de carga + telemetria de produção).

## Não alterado (verificado e consistente)

- `NFRD-SEC-01` (CPF mascarado) e `NFRD-AUD-01` (auditoria imutável) já refletem fielmente o PRD §6 e têm métrica/critério mensurável — sem correção necessária.
- Regras de negócio BR-01/BR-02/BR-03 do PRD estão cobertas pelos critérios de aceite de FRD-REC-01 (CA-01/CA-02/CA-03) — cobertura completa, sem gap.
- Personas P-01 e P-02 do PRD aparecem refletidas no FRD (passageiro em FRD-REC-01/02/03; atendente do SAC em FRD-REC-03) — sem gap.

## Itens fora do escopo desta validação (não decidir aqui)

- A decisão de arquitetura removida do FRD-REC-01 (mensageria, framework, particionamento de banco) deve ser retomada explicitamente pelo `ddd-architect` na próxima fase — registrar como insumo de entrada, não como requisito já fechado.

## Status final

- `frd.md`: v1.0.0 → v1.0.1, com histórico de versões atualizado registrando a correção.
- `nfrd.md`: v1.0.0 → v1.0.1, com histórico de versões atualizado registrando a correção.
- Ambos mantidos com status "Aprovado para desenvolvimento" (a correção não reabre o conteúdo funcional/não-funcional aprovado, apenas resolve inconsistências de forma e precisão de métrica).
