# Discovery — Recarga de cartão via Pix no app do passageiro

## O que já li no repositório

- `README.md`: `recarga-api` é o serviço de recarga de créditos do cartão de transporte da Viação Norte (bilhetagem eletrônica). Hoje a recarga só acontece em posto de venda ou totem, com pagamento em dinheiro ou débito. O saldo fica no PostgreSQL e é sincronizado com os validadores embarcados a cada 15 minutos.
- `docs/product/adr/0001-saldo-centralizado-no-postgres.md`: decisão de que o saldo oficial do cartão vive na tabela `saldo_cartao` do Postgres, e que os validadores (que operam offline) só recebem a lista de saldos atualizada a cada 15 minutos. Essa é a restrição arquitetural mais relevante para qualquer canal novo de recarga — inclusive Pix.
- `openapi.yaml` (v1.4.0): só existem dois endpoints hoje — `GET /cartoes/{numero}/saldo` e `POST /recargas` (recarga em posto/totem, sem corpo/payload descrito). Nada sobre Pix, pagamento externo, webhook de confirmação ou app do passageiro.
- `src/Recarga.Api/Program.cs` e `.csproj`: API mínima em .NET 8 (Minimal API). `POST /recargas` hoje apenas retorna `201 Created` sem persistir nada — é um esqueleto, não uma implementação real. `GET /saldo` retorna saldo fixo em zero. Ou seja, o código ainda não reflete nem a persistência descrita no README/ADR.
- `docker-compose.yml`: stack local é só Postgres + a API .NET. Nenhum gateway de pagamento, fila de mensageria ou serviço de notificação presente.

## Leitura da situação

A feature pedida — recarga via Pix, iniciada pelo próprio passageiro no app, sem ir ao posto — introduz pelo menos quatro lacunas frente ao que existe hoje:

1. **Canal de pagamento externo com confirmação assíncrona.** Hoje `POST /recargas` presume que o pagamento já foi liquidado no ato (dinheiro/débito no posto, com operador humano). Pix abre uma cobrança (QR Code / copia-e-cola) que é confirmada depois, de forma assíncrona — o fluxo síncrono atual não serve para isso sem virar duas etapas (criar intenção de pagamento → confirmar → creditar).
2. **Cliente novo (app do passageiro).** Não há hoje nenhuma integração descrita para um app de passageiro; os únicos consumidores implícitos são posto/totem.
3. **Expectativa de latência.** A ADR-0001 documenta um teto de até 15 minutos para o crédito aparecer no validador. Um usuário que acabou de pagar via Pix pelo próprio celular tende a esperar "paguei, já posso usar" — essa expectativa colide com a arquitetura de sincronização atual e precisa ser endereçada explicitamente (mesmo que a resposta seja "o produto aceita esse teto, com aviso no app").
4. **Maturidade do próprio serviço.** O código-fonte está com endpoints ainda não implementados de verdade (sem persistência real), o que muda o escopo: não é só "adicionar Pix a um serviço existente", é também terminar a base antes de estender.

## Perguntas para o usuário (registradas agora, resposta virá depois)

1. O Pix é gerado pela própria `recarga-api` (QR Code dinâmico via PSP integrado) ou o app só redireciona para um app de banco externo / checkout de terceiro?
2. Existe algum PSP/adquirente Pix já usado em outro serviço da Viação Norte, ou esta seria a primeira integração de pagamento instantâneo do grupo?
3. A confirmação de pagamento chega por webhook do PSP, por polling do app, ou por outro mecanismo? Isso define se `POST /recargas` precisa virar duas fases (criação da cobrança + confirmação) em vez do POST síncrono atual.
4. O teto de até 15 minutos de sincronização do validador (ADR-0001) é aceitável para esse fluxo, ou a feature exige repensar a sincronização (empurrar saldo mais cedo, ou dar feedback explícito no app sobre o prazo)?
5. Existe limite de valor, KYC ou antifraude a aplicar num pagamento iniciado pelo próprio passageiro (diferente do posto, que tem operador humano supervisionando)?
6. O app do passageiro já existe e consome outra API, ou nasce junto com esta feature? Isso decide se `recarga-api` ganha endpoints de consumo direto do app ou se há um BFF no meio.
7. Estorno/cancelamento: se o Pix for pago mas a recarga falhar (ou vice-versa), qual o comportamento esperado — estorno automático, fila de reconciliação manual, outro?
8. Os endpoints atuais (`GET /saldo`, `POST /recargas`) ainda não têm persistência real no código — isso é dívida técnica conhecida e fora de escopo desta feature, ou faz parte do que precisa ser resolvido junto?

## Próximos passos propostos (assumindo respostas às perguntas acima)

- Desenhar o novo fluxo como duas etapas: criação de intenção de pagamento Pix (QR Code/copia-e-cola) e confirmação assíncrona que efetivamente credita `saldo_cartao`.
- Definir o novo endpoint (ou versão de `POST /recargas`) para "recarga via Pix iniciada pelo app", distinto do fluxo síncrono de posto/totem, e um endpoint/webhook de confirmação de pagamento.
- Revisar com o time se a ADR-0001 precisa de uma ADR complementar tratando latência de sincronização para canais self-service.
- Levantar requisitos não funcionais de segurança/antifraude para pagamento iniciado pelo usuário final (sem operador humano).
- Confirmar com o usuário se a base atual do serviço (endpoints sem persistência) deve ser regularizada antes ou em paralelo à feature nova.
