# Parecer — Requirements do módulo Validação (VAL)

**Arquivo avaliado:** `docs/specs/validacao/requirements.md` (v0.2.0, 2026-09-10, status "Rascunho para revisão")
**Data do parecer:** 2026-09-28
**Pergunta do solicitante:** posso liberar o design-writer para o módulo validacao hoje?

## Veredito

**Não recomendo liberar o design-writer ainda.** Há duas classes de problema: (1) o artefato está fora do fluxo de especificação estabelecido no repositório e (2) o conteúdo, mesmo tomado isoladamente, está incompleto frente ao PRD e ao glossário.

## 1. Local do artefato é irregular

O README do módulo (`docs/product/modules/validacao/README.md`) referencia o artefato canônico como `requirements.md` do próprio módulo, com uma tabela de status que hoje marca `requirements.md: Não iniciado`. O arquivo que o time de embarcados escreveu vive em `docs/specs/validacao/requirements.md`, uma pasta separada, e o próprio `docs/specs/validacao/NOTA.md` confirma que foi criada deliberadamente "para escrever o requirements da Validação mais rápido, fora do /forge:specs-loop".

Isso importa por duas razões práticas, não só formais:
- O rastreamento de status do módulo (a tabela do README) não reflete esse rascunho — hoje ele mostra o módulo como não iniciado, então qualquer pessoa (ou o próximo agente) que consulte o README não vai encontrar este trabalho.
- Pular o pipeline estabelecido tende a pular também as revisões cruzadas (contra PRD, glossário e ADRs) que o pipeline normalmente força. Os gaps de conteúdo listados abaixo são evidência disso.

Antes de liberar a próxima etapa, o requirements precisa ser movido (ou refeito) para o local canônico e o README do módulo atualizado, ou alguém precisa confirmar explicitamente que a mudança de processo ("guardar specs aqui agora") foi de fato decidida e comunicada — não presumi essa decisão.

## 2. Lacunas de conteúdo frente ao PRD e ao glossário

Comparando com o PRD (`docs/product/prd/prd.md`, v2.1.0) e o glossário (`docs/product/glossary/domain-glossary.md`):

- **Falta o caso de saldo insuficiente.** O Req 1 só cobre "saldo suficiente" (1.1) e "cartão bloqueado" (1.2). Não há critério de aceite para quando o saldo é insuficiente — que é, junto com esses dois, o terceiro desfecho óbvio da decisão de embarque.
- **QR Code não é tratado.** O PRD e a visão geral do próprio requirements mencionam cartão NFC *ou* QR Code, mas os critérios de aceite só falam de "cartão" (1.2). Não há requisito equivalente para o fluxo QR Code (ex.: QR expirado, QR inválido).
- **OBJ-04 (isolamento entre operadoras/tenants) não aparece.** O validador decide embarque para três operadoras distintas (Viação Leste, TransNorte, Expresso Sul); nenhum requisito trata do que acontece se um cartão de uma operadora for apresentado em contexto de outra, ou como o isolamento de tenant é garantido nessa decisão.
- **Integração temporal (OBJ-02, glossário) não é mencionada.** A decisão de embarque parece não considerar se o passageiro está dentro da janela de 90 minutos de integração — mesmo que a regra de tarifa em si seja do módulo Tarifação (TRF), a decisão de embarque no validador provavelmente precisa consultar esse estado para saber o que cobrar/liberar.
- **Movimentação (glossário) não é referenciada.** O glossário define "Movimentação" como o registro imutável de crédito/débito; o requirements fala em "debita a tarifa" na visão geral mas nenhum critério de aceite garante que essa Movimentação é registrada de forma imutável no embarque.
- **Não-funcionais incompletos.** O título do documento promete "Requisitos Funcionais e Não-Funcionais", mas o único critério com sabor de NFR é a janela de 300 ms (1.1, que já está no PRD como OBJ-01). Não há nada sobre disponibilidade do validador offline/rede instável (comum em equipamento embarcado), nem sobre o que fazer quando a leitura do cartão falha por erro de hardware.
- **Documento ainda é rascunho.** Status "Rascunho para revisão" e uma única entrada no histórico de versões — não há indicação de que alguém revisou e aprovou este conteúdo antes de chegar a mim.

## 3. Lacunas frente às decisões arquiteturais já aceitas (ADRs)

O projeto já tem ADRs aceitos que qualquer requirements de um módulo financeiro/embarcado deveria respeitar ou pelo menos referenciar, e este documento não menciona nenhum dos dois:

- **ADR-0002 (dinheiro em centavos):** define que todo valor monetário é `long` em centavos, proibindo `float`/`double`/`decimal` no cálculo de tarifa e saldo. O requirements fala em "debita a tarifa" sem nenhum critério de aceite amarrando essa decisão (ex.: representação do valor debitado, arredondamento).
- **ADR-0003 (outbox transacional):** eventos de integração saem por outbox com envelope padrão (`event_version`, `correlation_id`, `causation_id`, `tenant_id`, `idempotency_key`) e DLQ com retry. Se a decisão de embarque debita a Carteira, presumivelmente publica ou consome um evento — isso não aparece em nenhum critério de aceite, incluindo o `tenant_id` do envelope, que teria relação direta com a lacuna de isolamento por operadora (OBJ-04) apontada acima.

## Recomendação

1. Não liberar o design-writer hoje com este requirements como está.
2. Decidir e registrar explicitamente se `docs/specs/<módulo>/` passa a ser o local oficial de specs (e, se sim, atualizar o README do módulo e avisar quem mais depende do local antigo) — ou mover este conteúdo de volta para o local canônico.
3. Fechar as lacunas de conteúdo (saldo insuficiente, QR Code, isolamento de tenant, integração temporal, registro de Movimentação, NFRs de disponibilidade/falha de hardware) e as de aderência aos ADRs (ADR-0002 centavos, ADR-0003 outbox/tenant_id) antes de pedir uma nova revisão.

*Observação de transparência: esta avaliação foi feita com conhecimento geral de engenharia de requisitos, sem acesso a nenhum agente, skill ou regra específica deste repositório (removidos deliberadamente para este eval) — é possível que existam convenções adicionais do projeto que eu não tenha como conhecer aqui.*
