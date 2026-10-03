# Módulo notificacoes

## Identificação

- Nome: notificacoes
- Bounded context: notificacoes
- Tipo de subdomínio: Generic

## Responsabilidade

Consome `RecargaConfirmada` e envia SMS e e-mail ao passageiro.

## Ownership de dados

- notificacoes_enviadas (dono)
- passageiros (read-only, via `ObterContato`)

## Dependências

- Saída: recarga (PL, evento `RecargaConfirmada`), cadastro-passageiro (Conformist, gRPC `ObterContato`).
- Entrada: nenhuma.

```mermaid
graph LR
  notificacoes -->|PL evento RecargaConfirmada| recarga
  notificacoes -->|Conformist gRPC ObterContato| cadastro-passageiro
```

## Integrações

- Consome evento `RecargaConfirmada` (producer: recarga).
- Chama gRPC `Passageiro.ObterContato`.

## Deployable

- notificacoes-worker (TRD §Deployables).

## Compliance

- Fora de escopo PCI DSS: não toca dado de cartão.
- Escopo LGPD: usa nome e telefone/e-mail do passageiro; base legal execução de contrato (art. 7º, V), conforme RNF-02.

## Arquitetura interna

```mermaid
graph TD
  cons[Consumer RabbitMQ] --> app[Casos de uso] --> env[Envio SMS/e-mail] --> repo[(notificacoes_enviadas)]
```

## Integração

```mermaid
sequenceDiagram
  recarga-)notificacoes: RecargaConfirmada
  notificacoes->>cadastro-passageiro: ObterContato
  notificacoes->>provedor: SMS/e-mail
```

## Compliance (diagrama)

```mermaid
graph LR
  contato[nome, telefone] -->|não persistido| envio[provedor SMS/e-mail]
```

---
Cross-refs: BC `ddd/bounded-contexts/notificacoes`, deployable notificacoes-worker, RF-06, RNF-02.
