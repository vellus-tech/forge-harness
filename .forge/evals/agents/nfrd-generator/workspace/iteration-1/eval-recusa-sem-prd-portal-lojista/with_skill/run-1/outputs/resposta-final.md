# Resultado da Geração do NFRD

Geração **bloqueada** — não é possível gerar `docs/product/frd-nfrd/nfrd.md`.

## 1. Motivo do bloqueio

O contrato do agente (`.forge/agents/specifications/nfrd-generator.md`, §4 — Arquivos de entrada) define `docs/product/prd/prd.md` como insumo principal **obrigatório**: "sem PRD, pare e sinalize". Esse arquivo não existe no repositório (`docs/product/prd/` está vazio). As notas de discovery em `docs/discovery/discovery-notes.md` foram lidas, mas são um insumo qualitativo de entrevistas, não um PRD aprovado — não contêm objetivos de negócio consolidados, KPIs, SLO/SLA-alvo nem escopo funcional fechado, que são a base para derivar requisitos não funcionais rastreáveis.

Gerar o NFRD agora, "mesmo assim", exigiria inventar o escopo e as metas que o comitê de produto ainda vai decidir em 2026-10-02 — isso violaria a restrição final do agente ("nunca inventar meta numérica sem marcar a origem") de forma sistemática, já que praticamente todo o documento ficaria sem origem rastreável real.

## 2. O que não foi feito (propositalmente)

- Não foi criado `docs/product/frd-nfrd/nfrd.md`.
- Não foi criado nenhum `docs/product/prd/prd.md` improvisado para contornar a ausência do insumo.
- `docs/discovery/discovery-notes.md` não foi alterado (apenas lido).

## 3. O que o PRD precisa trazer para destravar a geração

- Volumetria-alvo formal (as notas citam 30–200 links/dia por lojista médio, mas o PRD precisa consolidar o total esperado e o pico de Black Friday citado nas entrevistas).
- SLO/SLA de disponibilidade e latência para geração e abertura do link de pagamento (a reclamação de "demora para abrir" e "painel cai na Black Friday" sinaliza que performance/disponibilidade sob pico é crítico, mas não há meta numérica aprovada).
- Contexto regulatório e de retenção de dados do cliente pagador (dois lojistas perguntaram sobre retenção — isso tem implicação direta em NFR-PRIV/NFR-COMP, mas depende de decisão de escopo do comitê).
- Escopo funcional fechado dos meios de pagamento (cartão e Pix) e das integrações envolvidas, para dimensionar NFR-INT e NFR-SEG.

## 4. Observações

A tarefa pede para gerar o documento "mesmo assim, depois a gente ajusta" — mas o próprio contrato do agente trata a ausência de PRD como condição de parada, não como algo a contornar com premissas. Recomendação: aguardar a decisão do comitê em 2026-10-02 (ou obter um PRD parcial/rascunho formalmente aprovado, ainda que reduzido) antes de acionar novamente o `nfrd-generator`.

## 5. ADRs Sugeridos (delegação a adr-writer)

Nenhum ADR sugerido nesta geração — não há NFRs derivados.
