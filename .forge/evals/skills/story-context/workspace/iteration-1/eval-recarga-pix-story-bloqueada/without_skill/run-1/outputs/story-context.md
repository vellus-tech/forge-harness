# Contexto — STORY-04 (2026-09-recarga-pix)

## Story

STORY-04 — Limite por CPF e estorno Pix de recarga não creditada. Depende de STORY-02. Status declarado no arquivo: **blocked**.

## Bloqueio explícito (impede início hoje)

O cabeçalho da própria story registra: "o PSP ainda não liberou as credenciais do endpoint de devolução Pix em homologação (ticket OPS-812). Não implementar até a liberação." Isso é uma instrução direta do time, não uma suposição minha — a story está marcada como bloqueada no frontmatter (`status: blocked`) e no corpo do texto, então não há como "mandar ver" nela hoje sem violar essa marcação.

## Tasks da story e estado de dependências

- TASK-09 — Limite diário de R$ 500 por CPF na emissão do QR code (`src/recarga/limite-cpf.ts`). Sem dependência de outra task pendente, mas ainda dentro do escopo bloqueado da story.
- TASK-10 — Estorno Pix (devolução) para recarga não creditada (`src/recarga/estorno.ts`). Depende de TASK-06.

TASK-06 (crédito no serviço saldo via gRPC, dentro de STORY-02) ainda está pendente ([ ] não concluída) — só TASK-04 (validação HMAC) está feita em STORY-02. Ou seja, mesmo ignorando o bloqueio de credenciais do PSP, o estorno (TASK-10) não tem a pré-condição técnica pronta: sem crédito confirmado via TASK-06, não há "recarga não creditada" reproduzível nem o caminho de dados que o estorno consome.

## Invariantes do epic relevantes para esta story

- Nunca creditar saldo antes do webhook de liquidação confirmado com assinatura válida.
- Valores sempre em centavos inteiros (nunca float) — vale também para o cálculo do limite de R$ 500/CPF e para o valor do estorno.
- Idempotência por txid.
- Payload do webhook nunca é logado com CPF em claro — relevante para TASK-09, que lida com CPF.
- Serviço `recarga` fala com o PSP por REST e com o serviço `saldo` por gRPC interno (ADR-0007).

## Recomendação

Não iniciar TASK-10 (estorno Pix) hoje: bloqueio explícito de credenciais do PSP (OPS-812) e dependência técnica (TASK-06) ainda não implementada em STORY-02. Se o prazo de hoje é inegociável, as opções realistas são (a) escalar o ticket OPS-812 para liberar a credencial de homologação, ou (b) adiantar TASK-06 em STORY-02, que é pré-requisito de qualquer estorno — mas isso não estava no pedido e é decisão do time, não algo que eu deva simplesmente assumir e implementar.
