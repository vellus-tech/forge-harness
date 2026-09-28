# Módulos — Tarifa Viva

Estrutura de módulos derivada do DDD aprovado pelo comitê em 2026-09-10 (`docs/product/ddd/ddd-segmentation.md`, context map e relatório de validação), do FRD/NFRD e do TRD. Cada módulo tem um README próprio com responsabilidade, aggregates, eventos, APIs, dependências e recorte de segurança/compliance. Os diagramas de arquitetura, dependências e integração ficam em `diagrams/`.

## Índice de módulos

| Módulo | Tipo | Bounded Context | Dado sensível | Recorte |
|---|---|---|---|---|
| [validacao-embarque-api](validacao-embarque-api/README.md) | Microservice | Validação | Não | — |
| [recarga-api](recarga-api/README.md) | Microservice | Recarga | Token de cartão (nunca PAN) | PCI DSS |
| [tokenizacao-cartao-adapter](tokenizacao-cartao-adapter/README.md) | Adapter | Recarga | PAN, CVV | PCI DSS |
| [tarifacao-lib](tarifacao-lib/README.md) | Shared Library | Tarifação | Não | — |
| [liquidacao-operadoras-worker](liquidacao-operadoras-worker/README.md) | CronJob | Liquidação | Não | — |
| [cadastro-passageiro-api](cadastro-passageiro-api/README.md) | Microservice | Cadastro | CPF, data de nascimento, comprovante de matrícula | LGPD |

## Diagramas

- [Arquitetura](diagrams/architecture.md) — deployables, tipo de componente e onde ficam os dados sensíveis.
- [Dependências](diagrams/dependencies.md) — Shared Kernel (`tarifacao-lib`), chamadas síncronas e eventos assíncronos entre módulos.
- [Integração](diagrams/integration.md) — sequência ponta a ponta dos três fluxos críticos (embarque, recarga, liquidação) e o ponto externo com a adquirente e as operadoras.

## Recorte de segurança e compliance, por módulo

**PCI DSS 4.0.1** — a recarga no app processa cartão de crédito/débito (NFR-02). O PAN só existe dentro de `tokenizacao-cartao-adapter`; todo o restante do sistema — inclusive `recarga-api` — recebe e propaga apenas o token de cartão. Isso limita o CDE (Cardholder Data Environment) a um único componente e evita que `recarga-api`, `validacao-embarque-api` ou qualquer log do sistema armazene PAN/CVV. O time de segurança deve validar esse isolamento no design de `tokenizacao-cartao-adapter` e no schema de `pedidos_recarga` (campos `token_cartao`, `ultimos4`, nunca PAN).

**LGPD** — `cadastro-passageiro-api` é a única dona dos dados pessoais do passageiro (CPF, data de nascimento, comprovante de matrícula), com retenção de 5 anos após o último uso do cartão e atendimento de direitos do titular em até 15 dias (NFR-03). Os demais módulos não replicam esses campos: `tarifacao-lib` e `validacao-embarque-api` recebem apenas o evento `PassageiroElegivelAtualizado`, que carrega elegibilidade (gratuidade/meia-tarifa), não os dados pessoais brutos.

## Rastreabilidade com FRD/NFRD

| Requisito | Módulo(s) |
|---|---|
| FR-01, NFR-01, NFR-05 | validacao-embarque-api, tarifacao-lib |
| FR-02, FR-03, NFR-02 | recarga-api, tokenizacao-cartao-adapter |
| FR-04 | tarifacao-lib |
| FR-05, NFR-04 | liquidacao-operadoras-worker |
| FR-06, NFR-03 | cadastro-passageiro-api |

## Pontos em aberto herdados do DDD

- VAL-DDD-03 — frequência de sincronização do validador offline (a cada 5 min ou por reconexão), ainda não decidida. Afeta o design de `validacao-embarque-api`.
