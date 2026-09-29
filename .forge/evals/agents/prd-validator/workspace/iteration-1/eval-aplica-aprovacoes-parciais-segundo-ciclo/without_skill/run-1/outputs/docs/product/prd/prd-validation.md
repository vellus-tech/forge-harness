# PRD Validation Report

- **Documento validado:** `docs/product/prd/prd.md`
- **Data:** 2026-09-22
- **Segundo ciclo:** 2026-09-26
- **Status geral:** Ajustes parciais aplicados — P4 aguardando decisão do usuário

## Problemas Identificados

- **P1** [REJEITADO] [MÉTRICA SEM EVIDÊNCIA] OBJ-02 define NPS ≥ 70 em 3 meses, métrica que não aparece no discovery.
  - **Evidência:** `prd.md` § 4, OBJ-02; `discovery-notes.md` § Meta citada traz apenas 60% de recargas digitais em 6 meses.
  - **Impacto:** meta inventada vira compromisso de produto sem dono nem linha de base.
  - **Sugestão de correção:** remover OBJ-02 ou substituí-lo pela meta de 60% de recargas digitais em 6 meses.
  - **Decisão do usuário:** Rejeitado — a diretoria confirmou a meta de NPS ≥ 70 em reunião (2026-09-25); a meta permanece no PRD apesar de não constar no discovery.
  - **Status de aplicação:** NÃO APLICADO (rejeitado pelo usuário)

- **P2** [APROVADO] [CONFLITO DE ESCOPO] § 5.1 inclui recarga por cartão de crédito em até 3x, que o discovery exclui explicitamente desta fase.
  - **Evidência:** `prd.md` § 5.1 e § 1.1; `discovery-notes.md` § Fora desta fase.
  - **Impacto:** amplia o escopo com custo de adquirência não aprovado.
  - **Sugestão de correção:** mover a recarga por cartão de crédito/débito para § 5.2 Fora do Escopo e retirar a menção de § 1.1.
  - **Decisão do usuário:** Aprovado, conforme a sugestão de correção.
  - **Status de aplicação:** APLICADO — `prd.md` § 1.1 não menciona mais cartão de crédito; § 5.1 remove o item de parcelamento; § 5.2 passa a listar explicitamente a recarga por cartão de crédito/débito como fora do escopo.

- **P3** [APROVADO] [EXCESSO TÉCNICO] RF-02 descreve tópico Kafka, partições, retenção e colunas da tabela PostgreSQL.
  - **Evidência:** `prd.md` § 7, RF-02.
  - **Impacto:** antecipa decisão técnica no PRD e engessa o TRD.
  - **Sugestão de correção:** manter no RF-02 apenas o comportamento (crédito disponível no validador em até 30 minutos) e remeter os detalhes técnicos ao `TRD.md`.
  - **Decisão do usuário:** Aprovado, conforme a sugestão de correção.
  - **Status de aplicação:** APLICADO — `prd.md` § 7, RF-02 agora descreve apenas o comportamento observável e remete os detalhes de mensageria/persistência ao `TRD.md` (arquivo ainda não criado no repositório; ver Lacunas).

- **P4** [PENDENTE] [RISCO INCOMPLETO] RISCO-P01 não tem impacto, probabilidade, mitigação nem responsável.
  - **Evidência:** `prd.md` § 10, RISCO-P01.
  - **Impacto:** risco não gerenciável.
  - **Sugestão de correção:** completar os quatro atributos com o time comercial.
  - **Decisão do usuário:** Aguardando decisão (usuário ainda está avaliando; não mexer).
  - **Status de aplicação:** PENDENTE

## Observações do segundo ciclo

- P1 foi rejeitado pelo usuário; a meta OBJ-02 (NPS ≥ 70) permanece registrada no PRD sem lastro no discovery. Fica como risco de rastreabilidade documentado aqui, não como ação pendente — decisão do usuário prevalece sobre a recomendação original do validador.
- O arquivo `TRD.md` referenciado pela correção do P3 ainda não existe no repositório (há apenas `.forge/product/current/trd/.gitkeep`); a remissão em RF-02 é válida como intenção, mas fica pendente a criação do TRD com o detalhamento técnico retirado do PRD.
- P4 não foi tocado, por instrução explícita do usuário ("ainda estou pensando, não mexe").
