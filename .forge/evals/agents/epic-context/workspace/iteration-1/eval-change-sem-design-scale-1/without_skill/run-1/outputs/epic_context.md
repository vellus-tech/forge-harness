# Epic Context — aviso-saldo-baixo-push

## Por que este documento existe

O change `aviso-saldo-baixo-push` é scale 1 e não tem `design.md` — normal para esse porte, já que design detalhado só é obrigatório a partir de scale 2. Mesmo assim, o dono do change quer shardar o `tasks.md` em stories paralelizáveis para três desenvolvedores trabalharem ao mesmo tempo. Este documento reúne o contexto mínimo que cada dev precisaria ter em mãos sem reler o change inteiro, e sinaliza o principal risco dessa decisão antes de ela virar três branches.

## Alerta antes de shardar: a cadeia de tasks é sequencial

O `tasks.md` atual tem três tasks com dependência estritamente linear — TASK-01 → TASK-02 (depende de TASK-01) → TASK-03 (depende de TASK-02). Isso significa que, hoje, sombrar em três stories e mandar três devs em paralelo cria trabalho ocioso ou retrabalho: quem pegar TASK-02 ou TASK-03 vai travar esperando a interface de saída da task anterior, ou vai implementar contra uma suposição que pode mudar quando a task anterior fechar. Duas saídas possíveis, a decidir com o dono do change antes de abrir as três branches:

1. Fixar agora os contratos de interface entre as três tasks (assinatura de `deveAvisarSaldoBaixo`, formato do registro de "último aviso por cartão", e o payload que a task de envio consome) e liberar os três devs em paralelo contra esse contrato congelado, aceitando que integração acontece só no fim.
2. Aceitar que só há paralelismo real de fato entre "regra de disparo" (TASK-01+TASK-02, que são intimamente acopladas — mesmo arquivo, mesmo teste) e "envio" (TASK-03), ou seja, duas frentes, não três; a terceira pessoa entra em uma frente de reforço (testes, revisão, ou um item fora deste tasks.md, como observabilidade do aviso).

Este documento assume a rota 1 (contrato congelado), por ser a que atende ao pedido literal de três frentes, mas registra a ressalva acima para quem revisar o plano.

## Decisões já tomadas que restringem a implementação

- **ADR-0018 — Push via FCM com fila dedicada**: todo push sai pela fila `notificacoes.push`, entregue pelo FCM; nenhum módulo chama o FCM diretamente. As três frentes devem publicar na fila, nunca invocar `enviarPushFcm` fora do fluxo do worker que já lê dessa fila.
- **Módulo `src/notificacoes` já existe** com `push.ts`, que expõe `LIMIAR_SALDO_PADRAO_CENTAVOS = 1000` (R$ 10,00, o padrão citado em REQ-01) e `enviarPushFcm(tokenDispositivo, titulo, corpo)`, hoje um stub (`throw new Error("não implementado")`). Nenhuma das três frentes deveria remover esse stub sem coordenar — é o ponto de integração comum.

## Requisitos e como se mapeiam às três frentes

| REQ | Descrição resumida | Frente |
|---|---|---|
| REQ-01 | Disparar aviso quando saldo pós-débito cai abaixo do limiar (padrão R$ 10, configurável R$ 5–R$ 50) | Frente A — Regra de disparo (TASK-01) |
| REQ-02 | No máximo 1 aviso por cartão a cada 24h corridas | Frente B — Janela e opt-out (TASK-02) |
| REQ-03 | Respeitar opt-out de notificações de saldo no app | Frente B — Janela e opt-out (TASK-02) |
| REQ-04 | Texto do push não expõe o número completo do cartão, só os 4 últimos dígitos | Frente C — Envio (TASK-03) |

## Contrato congelado entre as três frentes (para viabilizar paralelismo)

Para que as três pessoas trabalhem sem esperar umas pelas outras, os contratos abaixo devem ser tratados como fixos a partir de agora — qualquer mudança neles depois de distribuídas as frentes exige realinhamento síncrono, não só um PR:

- **Frente A entrega**: `deveAvisarSaldoBaixo(saldoCentavos: number, limiarCentavos: number, ultimoAviso?: Date): boolean` em `src/notificacoes/saldo-baixo.ts`, pura, sem I/O — só a regra do limiar (REQ-01). Recebe `ultimoAviso` como parâmetro em vez de consultar armazenamento, justamente para não travar em uma decisão de persistência que é da Frente B.
- **Frente B entrega**: a função que decide se um aviso pode ser enviado agora, combinando a saída da Frente A com a janela de 24h e o opt-out — por exemplo `podeEnviarAvisoSaldoBaixo(cartaoId: string, saldoCentavos: number, limiarCentavos: number): Promise<boolean>`, que internamente busca `ultimoAviso` e a flag de opt-out do cartão e chama `deveAvisarSaldoBaixo`. Como depende da assinatura da Frente A, a Frente B deve começar implementando essa assinatura como um mock local e só integrar de fato quando a Frente A entregar — ou as duas pessoas alinham a assinatura por mensagem antes de começar, sem esperar o PR.
- **Frente C entrega**: a montagem do payload do push (mascarando o cartão para 4 últimos dígitos, REQ-04) e a publicação na fila `notificacoes.push` conforme ADR-0018, em `src/notificacoes/templates/saldo-baixo.json` e no ponto de chamada que invoca `podeEnviarAvisoSaldoBaixo` antes de publicar. Pode ser desenvolvida em paralelo às outras duas contra um mock de `podeEnviarAvisoSaldoBaixo` que sempre retorna `true`, integrando no fim.

## Fora de escopo (herdado da proposta)

SMS e e-mail; recarga automática. Nenhuma das três frentes deve tocar nesses canais.

## Rastreabilidade

Fonte: `.forge/specs/active/aviso-saldo-baixo-push/proposal.md`, `requirements.md`, `tasks.md`, `spec-manifest.yaml` (scale 1, status `tasks-ready`, `design_reviewed: false` — esperado nesse scale); `.forge/product/current/adr/ADR-0018-push-via-fcm-com-fila-dedicada.md`; `src/notificacoes/push.ts`.
