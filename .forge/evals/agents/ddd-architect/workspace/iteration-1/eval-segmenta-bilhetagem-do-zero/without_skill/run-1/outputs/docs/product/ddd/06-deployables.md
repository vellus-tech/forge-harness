# Deployables — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Segmentação DDD inicial |

## 1. Critério

Um deployable por módulo, exceto o firmware do validador (que não é escrito por nós — é o produto do fornecedor ValidaBus, TEC-03) e o cliente do validador embarcado, que é o software que roda sobre esse firmware e fala com `frota-validadores`. Todos os deployables de backend são serviços containerizados (TEC-01), comunicação interna gRPC, superfície externa REST.

## 2. Lista de deployables

| Deployable | Tipo | Expõe | Consome |
|---|---|---|---|
| `embarque-svc` | Serviço containerizado | gRPC interno (decisão de embarque para o cliente do validador) | gRPC de `carteira-svc`, `cadastro-linhas-svc`; eventos de `frota-validadores-svc` |
| `embarque-edge` | Software embarcado no validador (roda sobre firmware ValidaBus) | — | Protocolo proprietário ValidaBus (local); replica offline de saldo/bloqueio/tarifa |
| `clearing-svc` | Serviço containerizado | REST (backoffice do gestor do consórcio) | Fila (eventos `EmbarqueOcorrido`), gRPC de `cadastro-linhas-svc` |
| `carteira-svc` | Serviço containerizado | gRPC interno, REST (app) | Fila (comandos de `recarga-svc`, eventos de `frota-validadores-svc`) |
| `recarga-svc` | Serviço containerizado | REST (app, PDV) | gRPC de `pagamentos-svc`, `identidade-svc`; fila (comando para `carteira-svc`) |
| `frota-validadores-svc` | Serviço containerizado | gRPC interno | Protocolo proprietário ValidaBus (via lote de sincronização) |
| `cadastro-linhas-svc` | Serviço containerizado | gRPC interno, REST (backoffice) | — |
| `identidade-svc` | Serviço containerizado | REST (app) | — |
| `notificacoes-svc` | Serviço containerizado | — | Fila (evento `SaldoBaixo`); API externa FCM |
| `pagamentos-svc` | Serviço containerizado | gRPC interno | API externa do adquirente e do PSP de Pix |

## 3. Infraestrutura compartilhada

- PostgreSQL (TEC-02): um schema/banco por deployable com estado — nunca compartilhado entre serviços, para preservar a regra de fronteira do módulo 05-modulos.md §4.
- RabbitMQ (TEC-02): barramento de eventos assíncronos entre `embarque-svc` → `clearing-svc`, `recarga-svc`/`frota-validadores-svc` → `carteira-svc`, `carteira-svc` → `notificacoes-svc`.
- `embarque-edge` é o único deployable que roda fora da nossa infraestrutura containerizada — está fisicamente no ônibus, opera offline por padrão e depende de sincronização em lote (FR-02); qualquer decisão de arquitetura sobre ele precisa assumir rede intermitente como caso normal, não exceção.

## 4. Fronteira PCI (NFR-03)

`pagamentos-svc` é o único deployable autorizado a se comunicar com o adquirente de cartão; nenhum outro serviço — nem `recarga-svc`, que o invoca — armazena ou repassa dado de cartão, só o token opaco devolvido pelo adquirente. Essa fronteira reduz o escopo de auditoria PCI DSS a um único deployable, em vez de espalhá-la por toda a superfície de Recarga.
