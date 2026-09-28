# Resultado da Geração do NFRD

## 1. Arquivos Criados ou Atualizados

- Criado: `docs/product/frd-nfrd/nfrd.md` (não existia antes; diretório `docs/product/frd-nfrd/` criado).

## 2. Cobertura por Categoria

| Categoria | Aplicável? | NFRs gerados |
|---|---|---|
| Performance (PERF) | Sim | 3 |
| Disponibilidade (DISP) | Sim | 2 |
| Escalabilidade (ESC) | Sim | 1 |
| Resiliência (RES) | Sim | 2 |
| Segurança (SEG) | Sim | 4 |
| Privacidade (PRIV) | Sim | 2 |
| Compliance (COMP) | Sim | 3 |
| Observabilidade (OBS) | Sim | 3 |
| Auditoria (AUD) | Sim | 3 |
| Interoperabilidade (INT) | Sim | 2 |
| Usabilidade e acessibilidade (USA) | Sim | 1 |
| Manutenibilidade (MAN) | Sim | 1 |
| Portabilidade (POR) | Não | 0 |
| Operabilidade (OPS) | Sim | 3 |

## 3. Quantidade de Requisitos

Total: 30 NFRs (contagem verificada por grep no arquivo gerado).

Por prioridade: Alta — 22; Média — 7; Baixa — 1.

## 4. Principais Pontos a Validar

- RTO/RPO do backend de liquidação (crítico dado o incidente de 2025).
- Frequência de backup e teste de restauração.
- Meta numérica de usabilidade do portal/app (premissa do PRD é jargão não verificável).
- Prazos de retenção de auditoria e de dados de transação.
- Antecedência de comunicação de manutenção planejada e critério de aprovação da janela formal de firmware.
- Ausência de FRD nesta base para checagem cruzada funcional ↔ não funcional.

## 5. Observações

- Não existe `docs/product/frd-nfrd/frd.md` nem `docs/product/adr/` nesta fixture — não houve o que referenciar além das rules vinculantes em `.forge/rules/architecture/` e `.forge/rules/testing/`.
- A categoria Portabilidade (POR) foi marcada não aplicável por ausência de evidência no PRD (sem requisito de multi-ambiente/multi-cloud/multi-arch).
- A premissa de usabilidade do PRD (§8, "rápido e fácil de usar") viola a regra de "proibido jargão não verificável" quando tomada literalmente; o NFRD registrou isso como NFR com meta em aberto (Ponto a Validar), em vez de repetir o jargão como se fosse meta.

## 6. ADRs Sugeridos (delegação a adr-writer)

| ID sugerido | Título proposto | Origem (NFR) | Severidade | Justificativa breve |
|---|---|---|---|---|
| ADR-NNNN | `estrategia-dr-backend-liquidacao` | NFR-RES-02 | Alta | Define RTO/RPO e estratégia de DR — decisão durável, motivada por incidente real de 2025. |
| ADR-NNNN | `padrao-idempotencia-envio-lotes` | NFR-INT-01 | Alta | Mecanismo transversal de idempotência — risco de cobrança/crédito duplicado. |
| ADR-NNNN | `padrao-trilha-auditoria-imutavel` | NFR-AUD-01 | Média | Mecanismo transversal de auditoria append-only. |
