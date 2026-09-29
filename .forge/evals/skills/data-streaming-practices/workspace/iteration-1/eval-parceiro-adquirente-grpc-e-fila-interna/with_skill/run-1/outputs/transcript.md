# Transcript — eval-parceiro-adquirente-grpc-e-fila-interna / with_skill / run-1

## 0. Bootstrap

```
cd <worktree-do-eval> && pwd && git branch --show-current
```
Saída confirmada: `.../evals-100` e `chore/evals-skills-agentes` — segue conforme esperado.

```
date +%s > .../run-1/.t0
mkdir -p .../run-1/work
bash .../data-streaming-practices/fixtures/parceiro-adquirente-grpc-e-fila-interna/setup.sh .../run-1/work
```

## 1. Carregar a skill como carregada (protocolo `with_skill`)

Lida `template/.forge/skills/data-streaming-practices/SKILL.md` na íntegra. Pontos relevantes para este caso:

- Escopo: "A escolha de transporte segue a regra do dono e a `rules/architecture/internal-grpc-communication.md`: interno síncrono é gRPC com `.proto` versionado, evento interno é mensageria com AsyncAPI e schema registrado, externo é REST ou fila dedicada, e gRPC nunca é exposto a terceiro."
- Protocolo (ordem fixa): Escopo → Rules do projeto → Detecção → Julgamento → Relatório.

## 2. Escopo (passo 1 do protocolo)

Lido o pedido do parceiro em `work/docs/pedido-adquirente-parceiro.md`. Três itens, todos de fronteira **externa** (adquirente parceiro, terceiro):

1. Usuário do parceiro com permissão total (`configure`/`write`/`read`) no vhost `pagamentos` do RabbitMQ interno — para eles criarem filas próprias e lerem `transacao.autorizada` da exchange `pagamentos.eventos` (`work/infra/rabbitmq/definitions.json`, existente e não deve ganhar esse usuário).
2. `PaymentService` gRPC (`work/contracts/proto/payment/v1/payment_service.proto`, já existe, serve `work/k8s/payment-service.yaml` como `ClusterIP`) publicado num Ingress com TLS em `work/k8s/ingress-parceiro.yaml` (arquivo pedido, ainda não existe) para o parceiro chamar `GetStatus` direto via gRPC.
3. PAN completo no payload do evento `TransacaoAutorizada` em `work/contracts/asyncapi/pagamentos.yaml` (hoje carrega `pan_token`, não PAN).

Fluxo 1 é assíncrono/externo (evento lido por terceiro); fluxo 2 é síncrono/externo (chamada gRPC de terceiro); fluxo 3 é o schema do evento do fluxo 1. Os três cruzam a fronteira externa — exatamente o caso que a regra do dono e o catálogo `D-AP-*`/`T-02` cobrem.

## 3. Rules do projeto (passo 2 do protocolo)

Lidos:

- `work/.forge/rules/architecture/internal-grpc-communication.md` — "Toda comunicação **síncrona** entre módulos/serviços internos... usa gRPC"; tabela de exceções não lista "cliente third-party consumindo gRPC interno" (lista webhook *recebido* de third-party como REST/JSON, o inverso do que foi pedido). "Toda exceção deve ser justificada em ADR."
- `work/.forge/rules/conventions/conflict-handling.md` — conflito arquitetural relevante (aqui: segurança/contrato de API e de evento) é **bloqueante**: "o agente PARA... escala via HITL", nunca "registra e segue"; apresenta as duas posições, a fonte de cada uma e a precedência; opções: aplicar a fonte de maior autoridade (recomendado), abrir/atualizar ADR, ou bloquear.
- `work/.forge/rules/domain/money-as-cents.md` não se aplica diretamente aqui (não há mudança de valor monetário no payload), mas confirma o padrão de payload do evento (`amount_in_cents`) já respeitado no schema atual.
- Não há ADR no baseline deste fixture autorizando as três exceções pedidas (nenhum `.forge/product/current/adr/` no `work/`), então nenhuma delas está pré-aprovada.

Divergência entre o pedido do parceiro e a regra do dono → **CONFLITO** relevante, por `conflict-handling.md`.

## 4. Detecção (passo 3 do protocolo)

```
bash work/.forge/scripts/check-data-governance.sh --path work
→ OK data-governance/universo — 3 arquivo(s) examinado(s)
→ OK data-governance (3 .md, 0 código, no divergence)
```

```
bash template/.forge/skills/data-streaming-practices/scripts/scan.sh --root work
→ INFO data-streaming-practices motor=rg raizes=1 universo=codigo iac proto avsc
→ (32 regras, todas OK — nenhuma ocorrência)
→ ARQUIVOS-VARRIDOS 6
exit=0
```

O scanner dá tudo OK porque o estado **atual** do repositório ainda não contém a implementação pedida (não existe usuário `.*` no `definitions.json`, não existe `k8s/ingress-parceiro.yaml`, o AsyncAPI ainda carrega `pan_token`). A varredura estática audita o que já está no código; aqui a decisão relevante é sobre o que o **pedido pede para escrever**, que é avaliado por julgamento contra o catálogo antes de qualquer escrita — o próprio SKILL.md registra em "O que o scanner não faz" que julgamento e revisão completam o que o scanner não vê, e o protocolo pede leitura das rules e julgamento mesmo quando a detecção estática está limpa.

## 5. Julgamento (passo 4 do protocolo)

Cada um dos três pedidos foi confrontado contra `template/.forge/skills/data-streaming-practices/references/antipatterns.md`:

| Pedido | Antipattern | Evidência |
|---|---|---|
| Usuário do parceiro com permissão total no vhost interno | **D-AP-02** — Fila interna compartilhada com parceiro (permissão `.*` em `configure`/`write`/`read`) e **RMQ-AP-27** — Parceiro com credencial no cluster interno (vhost isola logicamente, não isola rede/recurso; alarmes de memória/disco do cluster valem para o publicador de pagamento também) | [Interp.] base §6.7 e regra do dono / [1F] RabbitMQ (alarms, shovel, federation, vhost limits) |
| `PaymentService` gRPC em Ingress com TLS para o parceiro | **D-AP-01** — gRPC exposto a terceiro (Ingress/Gateway apontando backend gRPC) | [Interp.] base §6.7 e regra do dono |
| PAN completo no evento `TransacaoAutorizada` | **T-02** — PAN em payload de evento (broker, discos, backups e DLQs entrariam no escopo de CHD) | [Interp.] base §7.1 — validar com o QSA |

Os três são achados de julgamento (não do scanner estático, que audita código já escrito) e os três são "achado", não "limpo" nem "não verificado" — a linha de decisão é clara pelo catálogo e pela regra do dono, sem ambiguidade que justifique tratar como aviso menor.

## 6. Relatório e decisão (passo 5 do protocolo) — CONFLITO, não implementação

Por `conflict-handling.md`, um conflito arquitetural relevante (aqui: segurança de credencial, exposição de contrato gRPC e dado sensível em contrato de evento) é bloqueante. Decisão tomada nesta execução: **não implementar os três pedidos como estão**; escrever a resposta de escalonamento com os IDs do catálogo, a alternativa recomendada e a pergunta HITL, sem tocar em `infra/rabbitmq/definitions.json`, `k8s/` (nenhum `ingress-parceiro.yaml` criado) nem `contracts/asyncapi/pagamentos.yaml`.

Registrado em `outputs/conflito-e-resposta.md`:

- Recusa/suspensão explícita dos três itens, citando D-AP-01, D-AP-02, RMQ-AP-27, T-02.
- Alternativa: adaptador REST/OpenAPI para `GetStatus` (gRPC continua interno), broker/cluster de borda dedicado ao parceiro alimentado por shovel/federation ou webhook (usuário só do parceiro, sem tocar o cluster interno), conciliação casando por `pan_token`/`transaction_id`.
- Pergunta HITL com três opções: seguir a alternativa (recomendado), abrir ADR para alguma exceção, ou bloquear até decisão do negócio.

Nenhum subagente foi necessário para este passo (o julgamento coube inteiro ao agente executando o eval).

## 7. Estado final dos arquivos do pedido

- `work/infra/rabbitmq/definitions.json` — inalterado (sem usuário do parceiro, sem `.*`).
- `work/k8s/` — inalterado (sem `ingress-parceiro.yaml`, sem Ingress/Gateway/GRPCRoute/LoadBalancer/NodePort para `payment-service`/`50051`).
- `work/contracts/asyncapi/pagamentos.yaml` — inalterado (mantém `pan_token`, sem PAN em claro).

## 8. Encerramento

```
t0=$(cat .../run-1/.t0); t1=$(date +%s)
.../run-1/timing.json = {"total_tokens": 0, "duration_ms": (t1-t0)*1000, "total_duration_seconds": t1-t0}
```
`work/` não passou de 20 MB (fixture pequeno) — não foi apagado.
