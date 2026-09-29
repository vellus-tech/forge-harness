# PRD Validation Report

- **Documento validado:** `docs/product/prd/prd.md`
- **Data:** 2026-09-26
- **Status geral:** Aguardando ajustes

## Problemas Identificados

- **P1** [PENDENTE] [MÉTRICA SEM EVIDÊNCIA] OBJ-02 define NPS ≥ 70 em 3 meses, métrica que não aparece no discovery.
  - **Evidência:** `prd.md` § 4, OBJ-02; `discovery-notes.md` § Meta citada traz apenas 60% de recargas digitais em 6 meses.
  - **Impacto:** meta inventada vira compromisso de produto sem dono nem linha de base.
  - **Sugestão de correção:** remover OBJ-02 ou substituí-lo pela meta de 60% de recargas digitais em 6 meses.
  - **Decisão do usuário:** Rejeitado — o usuário manteve a meta de NPS ≥ 70, citando pedido explícito da diretoria na reunião de véspera (2026-09-25). A divergência com o discovery permanece registrada como ressalva; a meta não tem, por ora, evidência no discovery, mas passa a ter mandato de diretoria como origem.
  - **Status de aplicação:** REJEITADO

- **P2** [APLICADO] [CONFLITO DE ESCOPO] § 5.1 inclui recarga por cartão de crédito em até 3x, que o discovery exclui explicitamente desta fase.
  - **Evidência:** `prd.md` § 5.1 e § 1.1; `discovery-notes.md` § Fora desta fase.
  - **Impacto:** amplia o escopo com custo de adquirência não aprovado.
  - **Sugestão de correção:** mover a recarga por cartão de crédito/débito para § 5.2 Fora do Escopo e retirar a menção de § 1.1.
  - **Decisão do usuário:** Aprovado.
  - **Status de aplicação:** APLICADO — § 1.1 não menciona mais cartão de crédito; § 5.1 lista somente Pix e histórico; § 5.2 agora inclui "Recarga por cartão de crédito ou débito (fica para uma fase futura por causa do custo de adquirência, sem data definida)", alinhado ao discovery.

- **P3** [APLICADO] [EXCESSO TÉCNICO] RF-02 descreve tópico Kafka, partições, retenção e colunas da tabela PostgreSQL.
  - **Evidência:** `prd.md` § 7, RF-02.
  - **Impacto:** antecipa decisão técnica no PRD e engessa o TRD.
  - **Sugestão de correção:** manter no RF-02 apenas o comportamento (crédito disponível no validador em até 30 minutos) e remeter os detalhes técnicos ao `TRD.md`.
  - **Decisão do usuário:** Aprovado.
  - **Status de aplicação:** APLICADO — RF-02 agora descreve apenas o comportamento observável (crédito disponível em até 30 minutos) e remete a mensageria, persistência e modelagem de dados ao `TRD.md`.

- **P4** [PENDENTE] [RISCO INCOMPLETO] RISCO-P01 não tem impacto, probabilidade, mitigação nem responsável.
  - **Evidência:** `prd.md` § 10, RISCO-P01.
  - **Impacto:** risco não gerenciável.
  - **Sugestão de correção:** completar os quatro atributos com o time comercial.
  - **Decisão do usuário:** Aguardando decisão — usuário sinalizou que ainda está pensando; nenhuma alteração feita neste ciclo.
  - **Status de aplicação:** PENDENTE
