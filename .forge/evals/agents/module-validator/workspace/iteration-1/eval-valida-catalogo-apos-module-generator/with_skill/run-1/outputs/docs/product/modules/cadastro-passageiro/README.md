# Módulo cadastro-passageiro

## Identificação

- Nome: cadastro-passageiro
- Bounded context: cadastro-passageiro
- Tipo de subdomínio: Supporting

## Responsabilidade

Cadastra passageiros, emite cartões de transporte e mantém o saldo do cartão, creditado por comando de recarga.

## Ownership de dados

- passageiros (dono)
- cartoes_transporte (dono)

## Dependências

- Saída: nenhuma.
- Entrada: recarga (ACL, gRPC `CreditarSaldo`), notificacoes (Conformist, gRPC `ObterContato`).

```mermaid
graph LR
  recarga -->|ACL gRPC CreditarSaldo| cadastro-passageiro
  notificacoes -->|Conformist gRPC ObterContato| cadastro-passageiro
```

## Integrações

- Expõe gRPC `Cartao.CreditarSaldo` e `Passageiro.ObterContato`.

## Deployable

- cadastro-passageiro-service (TRD §Deployables).

## Compliance

- Fora de escopo PCI DSS: não toca dado de cartão bancário.
- Escopo LGPD: trata CPF, nome, e-mail e telefone; base legal execução de contrato (art. 7º, V), conforme RNF-02.

## Arquitetura interna

```mermaid
graph TD
  api[gRPC] --> app[Casos de uso] --> dom[Passageiro, Cartão] --> repo[(passageiros, cartoes_transporte)]
```

## Integração

```mermaid
sequenceDiagram
  recarga->>cadastro-passageiro: CreditarSaldo(cartao, valor)
  cadastro-passageiro-->>recarga: saldo atualizado
```

## Compliance (diagrama)

```mermaid
graph LR
  pii[(passageiros: CPF, nome, e-mail, telefone)] -->|criptografia em repouso| db[(PostgreSQL)]
```

---
Cross-refs: BC `ddd/bounded-contexts/cadastro-passageiro`, deployable cadastro-passageiro-service, RF-01, RF-02, RNF-02.
