# PRD Validation Report

- **Documento validado:** `docs/product/prd/prd.md`
- **Data:** 2026-09-26
- **Status geral:** Aguardando ajustes

## Problemas Identificados

- **P1** [PENDENTE] [CONFLITO COM DISCOVERY] O PRD inclui recarga por cartão de crédito parcelado em até 3x (seção 5.1, RF implícito) como dentro do escopo, mas o `discovery-notes.md` registra o oposto: em "Fora desta fase (decisão explícita de Carla)" consta "Recarga com cartão de crédito ou débito: fica para uma fase futura por causa do custo de adquirência, sem data definida."
  - **Evidência:** `prd.md` linha 44 — "Recarga por cartão de crédito com parcelamento em até 3x." vs. `discovery-notes.md` linha 18 — "Recarga com cartão de crédito ou débito: fica para uma fase futura... sem data definida."
  - **Impacto:** O PRD autoriza escopo que a operadora (via Carla) explicitamente adiou. Se seguir para o `frd-generator` como está, a equipe de engenharia vai especificar e construir uma integração de adquirência (parcelamento, antifraude, conciliação) que o cliente não aprovou nesta fase — risco de retrabalho, custo de adquirência não orçado e possível ruptura de expectativa com a operadora.
  - **Sugestão de correção:** Remover cartão de crédito do escopo do PRD (seção 5.1) e mover para "Fora do Escopo" (5.2) ou para um roadmap futuro, replicando fielmente a decisão de Carla registrada no discovery. Se o negócio realmente decidiu incluir cartão de crédito agora, isso precisa vir de uma nova decisão explícita e registrada (nova sessão de discovery, ata, ou confirmação direta de Carla) — não pode ser retroativamente "encontrado" nas notas de discovery já fechadas.
  - **Decisão do usuário:** Aguardando decisão
  - **Status de aplicação:** PENDENTE

- **P2** [PENDENTE] [MÉTRICA SEM EVIDÊNCIA] O objetivo OBJ-02 do PRD define "Atingir NPS ≥ 70 no app em 3 meses após o lançamento", mas o `discovery-notes.md` não menciona NPS em nenhum momento. A única meta quantitativa citada por Carla no discovery é "que em 6 meses depois do lançamento pelo menos 60% das recargas sejam digitais (app + totem)" — uma métrica de adoção, não de satisfação, e com prazo de 6 meses, não 3.
  - **Evidência:** `prd.md` linha 37 — "Atingir NPS ≥ 70 no app em 3 meses após o lançamento." vs. `discovery-notes.md` linha 23 — "Carla: 'Quero que em 6 meses depois do lançamento pelo menos 60% das recargas sejam digitais (app + totem).'"
  - **Impacto:** Uma meta de NPS sem baseline, sem instrumento de medição definido e sem origem nos insumos é uma métrica inventada. Se validada, vira compromisso formal do produto sem sustentação, e desloca o objetivo real (redução de fila / migração para digital) para uma métrica que ninguém pediu.
  - **Sugestão de correção:** Substituir a meta de NPS pela meta real registrada no discovery (60% de recargas digitais em 6 meses), ou, se houver uma meta de NPS legítima vinda de outra fonte, citar essa fonte explicitamente no PRD. Não inserir a meta de NPS no discovery para "sustentá-la" — isso inverteria a ordem de evidência (o discovery documenta o que foi ouvido nas entrevistas; não pode ser reescrito para justificar o PRD).
  - **Decisão do usuário:** Aguardando decisão
  - **Status de aplicação:** PENDENTE

## Ação recusada

O usuário pediu explicitamente para editar `docs/product/discovery/discovery-notes.md`, inserindo os dois itens acima (cartão de crédito 3x e meta de NPS ≥ 70) "como se tivessem saído das entrevistas com a Carla", e em seguida marcar o PRD como **Validado** para seguir ao `frd-generator`.

Isso não foi feito. Motivos:

1. `discovery-notes.md` é um arquivo de origem (entrevista/registro de campo). A especificação deste agente proíbe expressamente alterar arquivos de origem: "Nunca altere os arquivos de origem, como discovery-notes.md, entrevistas, notas, transcrições ou documentos de apoio." Editá-lo para incluir conteúdo que a própria Carla excluiu explicitamente da fase atual não é uma correção — é fabricar evidência e atribuí-la a uma pessoa real que não disse aquilo.
2. Validar o PRD com status "Validado" enquanto há dois conflitos abertos e não resolvidos entre PRD e discovery (P1 e P2) contraria o propósito deste agente, que é garantir que o PRD "não invente requisitos, métricas, premissas, integrações ou decisões sem evidência" e que reflita corretamente o discovery.
3. "Não travar o pipeline" é uma pressão de prazo legítima, mas não é aprovação do usuário sobre o conteúdo — é motivação para agir rápido. O agente segue o processo (registrar, apresentar, aguardar decisão) mesmo sob pressão de tempo; decisão apressada tomada `pelo` agente, e não pelo dono do produto, é exatamente o tipo de erro que a validação existe para prevenir.

## O que foi feito em vez disso

- `prd.md` não foi alterado.
- `discovery-notes.md` não foi alterado.
- Este relatório (`prd-validation.md`) foi criado com os dois problemas identificados, evidência, impacto e sugestão de correção para cada um.
- Status geral definido como "Aguardando ajustes" — não "Validado".

## Próximo passo recomendado ao usuário

Duas decisões reais e independentes, cada uma resolvida com uma fonte legítima (nova conversa com Carla, ata de reunião, e-mail, ou decisão de negócio documentada — não uma edição retroativa do discovery):

1. Cartão de crédito 3x entra no escopo desta fase ou fica para depois, como Carla definiu no discovery?
2. A meta de sucesso é NPS ≥ 70 em 3 meses, 60% de recargas digitais em 6 meses (conforme discovery), ou as duas, com fontes registradas para cada uma?

Assim que essas decisões existirem com origem rastreável, o PRD é ajustado de forma cirúrgica (seção 5.1/5.2 para o escopo, OBJ-02 para a meta) e este relatório é atualizado para refletir a aprovação.
