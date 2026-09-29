# PRD Validation Report

- **Documento validado:** `docs/product/prd/prd.md`
- **Insumo de origem:** `docs/product/discovery/discovery-notes.md` (sessões com Carla Mendes e Rodrigo Alves, semana de 08/09/2026)
- **Data:** 2026-09-26
- **Status geral:** Aguardando ajustes

## Problemas Identificados

- **P1** [PENDENTE] [INVENÇÃO / CONFLITO COM DECISÃO DE NEGÓCIO] O PRD inclui recarga por cartão de crédito com parcelamento em até 3x (seções 1.1 e 5.1), mas o discovery registra decisão explícita da Carla de excluir cartão de crédito/débito desta fase, por custo de adquirência e sem data definida.
  - **Evidência:** discovery, "Fora desta fase (decisão explícita de Carla): Recarga com cartão de crédito ou débito: fica para uma fase futura por causa do custo de adquirência, sem data definida." vs. PRD 1.1 "...permite ao passageiro recarregar o cartão de transporte pagando com Pix ou com cartão de crédito..." e 5.1 "Recarga por cartão de crédito com parcelamento em até 3x."
  - **Impacto:** contradiz uma decisão de negócio já tomada pela stakeholder; se seguir para FRD/implementação, gera esforço de escopo incorreto e parcelamento é um detalhe inventado que não existe em nenhum insumo.
  - **Sugestão de correção:** remover cartão de crédito de 1.1 e do 5.1 (Dentro do Escopo); registrar a exclusão em 5.2 (Fora do Escopo) citando a decisão da Carla e a ausência de data definida.
  - **Decisão do usuário:** Aguardando decisão
  - **Status de aplicação:** PENDENTE

- **P2** [PENDENTE] [MÉTRICA INVENTADA / META REAL OMITIDA] O objetivo OBJ-02 define meta de NPS ≥ 70 em 3 meses, sem qualquer respaldo no discovery. A única meta quantitativa citada nominalmente por uma stakeholder (Carla: 60% das recargas digitais — app + totem — em 6 meses) não aparece em nenhum lugar do PRD.
  - **Evidência:** discovery, "Meta citada — Carla: 'Quero que em 6 meses depois do lançamento pelo menos 60% das recargas sejam digitais (app + totem).'" vs. PRD 4, OBJ-02 "Atingir NPS ≥ 70 no app em 3 meses após o lançamento."
  - **Impacto:** a meta de sucesso do produto deixa de ser rastreável ao insumo real; a meta que a stakeholder de negócio efetivamente definiu fica de fora do documento que deveria formalizá-la.
  - **Sugestão de correção:** adicionar um objetivo mensurável com a meta real da Carla (60% de recargas digitais — app + totem — em 6 meses do lançamento); remover o NPS ou, se for meta adicional do time de produto, marcá-la explicitamente como tal e não como algo vindo do discovery.
  - **Decisão do usuário:** Aguardando decisão
  - **Status de aplicação:** PENDENTE

- **P3** [PENDENTE] [PLACEHOLDER NÃO RESOLVIDO] O objetivo OBJ-01 mantém o título de template não preenchido.
  - **Evidência:** PRD, seção 4, "### OBJ-01 — [Nome do Objetivo]".
  - **Impacto:** documento incompleto chega às próximas fases (FRD) com placeholder de template.
  - **Sugestão de correção:** preencher com um nome descritivo coerente com o conteúdo ("Aumentar a participação das recargas digitais"), já que o corpo do objetivo já existe.
  - **Decisão do usuário:** Aguardando decisão
  - **Status de aplicação:** PENDENTE

- **P4** [PENDENTE] [EXCESSO DE DETALHE TÉCNICO / NÍVEL ERRADO] RF-02 especifica decisões de implementação (tópico Kafka `recarga.eventos` com 12 partições e retenção de 7 dias; schema da tabela PostgreSQL `recargas` com colunas nomeadas) que pertencem a um TRD/ADR, não a um PRD, e não têm nenhum respaldo no discovery.
  - **Evidência:** PRD, seção 7, RF-02: "...publica o evento `RecargaConfirmada` no tópico Kafka `recarga.eventos` (12 partições, retenção de 7 dias) e grava o registro na tabela PostgreSQL `recargas` (colunas `id uuid`, `cartao_id`, `valor_centavos`, `status`, `txid`)...".
  - **Impacto:** mistura de camadas de abstração num documento de produto; embute decisões arquiteturais que nunca passaram por um ADR e que o discovery não menciona nem sustenta.
  - **Sugestão de correção:** reduzir RF-02 ao comportamento observável ("após a confirmação do pagamento, o crédito fica disponível no validador do ônibus na próxima sincronização, em até 30 minutos") e mover topologia de eventos/schema de banco para `TRD.md`, com um `ADR.md` se a escolha de Kafka for uma decisão arquitetural relevante.
  - **Decisão do usuário:** Aguardando decisão
  - **Status de aplicação:** PENDENTE

- **P5** [PENDENTE] [LACUNA REAL OMITIDA] A seção 9.3 (Lacunas e Pontos a Validar) registra apenas o valor mínimo/máximo de recarga, mas omite o segundo ponto em aberto do discovery: o PSP do Pix ainda não foi definido.
  - **Evidência:** discovery, "Pontos em aberto: Não foi definido quem será o PSP do Pix; Carla vai trazer na próxima reunião." — ausente do PRD.
  - **Impacto:** lacuna real e crítica (dependência de fornecedor que bloqueia RF-01/RF-02) some do documento que deveria centralizar pendências.
  - **Sugestão de correção:** adicionar em 9.3: "PSP do Pix ainda não definido; Carla trará a definição em reunião futura."
  - **Decisão do usuário:** Aguardando decisão
  - **Status de aplicação:** PENDENTE

- **P6** [PENDENTE] [ESCOPO CONTRADITÓRIO] A seção 5.2 (Fora do Escopo) não registra a exclusão de recarga por cartão de crédito/débito determinada no discovery; o PRD faz o oposto, incluindo esse item em 5.1 (ver P1).
  - **Evidência:** discovery cita a exclusão explicitamente; PRD 5.2 só lista "Venda de novos cartões pelo app."
  - **Impacto:** mesma raiz de P1, vista pelo lado do "fora de escopo" — reforça que a correção de P1 precisa também atualizar 5.2.
  - **Sugestão de correção:** mover o item de cartão de crédito/débito de 5.1 para 5.2, citando a decisão da Carla.
  - **Decisão do usuário:** Aguardando decisão
  - **Status de aplicação:** PENDENTE

- **P7** [PENDENTE] [RISCO INCOMPLETO] RISCO-P01 não traz impacto, probabilidade, mitigação ou responsável — apenas a descrição do risco.
  - **Evidência:** PRD, seção 10, "RISCO-P01 — Baixa adesão ao app: Passageiros podem continuar preferindo o guichê." sem os demais campos.
  - **Impacto:** risco registrado sem plano de ação, reduzindo o valor de governança da seção "Riscos e Mitigações".
  - **Sugestão de correção:** completar com impacto (ex.: meta de 60% digital não atingida), probabilidade, mitigação (ex.: comunicação ativa no guichê, incentivo no app) e responsável.
  - **Decisão do usuário:** Aguardando decisão
  - **Status de aplicação:** PENDENTE

- **P8** [PENDENTE] [ESTRUTURA / RASTREABILIDADE] Numeração de seções descontínua (1.1 → 1.4 sem 1.2/1.3; 2.2 sem 2.1) e ausência de seções esperadas de um PRD (jornada do usuário, requisitos não funcionais, seção dedicada de métricas de sucesso, roadmap evolutivo).
  - **Evidência:** estrutura completa do documento (seções listadas na íntegra acima).
  - **Impacto:** sugere que conteúdo do template foi removido sem registro, dificultando auditoria e rastreabilidade entre o que foi decidido e o que está documentado.
  - **Sugestão de correção:** confirmar com o PRD Generator se as seções puladas foram removidas intencionalmente; no mínimo, incluir a jornada mínima do passageiro (abrir app → escolher valor → pagar via Pix → ver crédito refletido em até 30 min) com base no discovery.
  - **Decisão do usuário:** Aguardando decisão
  - **Status de aplicação:** PENDENTE

## Resumo para o usuário

O PRD reflete corretamente o número de guichês, o percentual de recargas físicas/digitais, a fila de 22 minutos e o prazo de 30 minutos para sincronização do crédito — todos com respaldo direto no discovery. Os problemas graves são: inclusão de cartão de crédito com parcelamento (contraria decisão explícita da Carla, P1/P6), uma meta de NPS sem origem que substitui a meta real de 60% citada pela Carla (P2), e excesso de detalhe técnico de implementação dentro do PRD (P4). Nenhuma edição foi aplicada em `prd.md` — todas as correções propostas aguardam sua aprovação explícita, conforme o processo do PRD Validator.
