# ADRs — Plataforma de Pagamentos

Tabela mestra dos Registros de Decisão Arquitetural (formato MADR, em pt-BR). Arquivo `NNNN-titulo-em-kebab-case.md`.

## Faixas de numeração

| Faixa | Escopo | Situação |
|---|---|---|
| 0001–0099 | Plataforma (infraestrutura, malha, observabilidade) | ativa |
| 0100–0199 | Módulo de pagamentos (autorização, antifraude, conciliação, tokenização) | ativa |
| 0200–0299 | Módulo de bilhetagem | reservada |

Cada decisão usa o próximo número livre **da faixa do seu escopo**.

## Índice

| Nº | Título | Status | Data |
|---|---|---|---|
| [0001](./0001-monorepo-com-workspaces.md) | Monorepo com workspaces | Aceito | 2026-02-11 |
| [0002](./0002-kubernetes-gerenciado-eks.md) | Kubernetes gerenciado (EKS) | Aceito | 2026-03-12 |
| [0003](./0003-postgresql-banco-transacional.md) | PostgreSQL como banco transacional | Aceito | 2026-04-13 |
| [0004](./0004-grpc-malha-interna.md) | gRPC na malha interna | Aceito | 2026-05-14 |
| [0005](./0005-rest-borda-externa.md) | REST na borda externa | Aceito | 2026-06-15 |
| [0006](./0006-segredos-aws-secrets-manager.md) | Segredos no AWS Secrets Manager | Aceito | 2026-01-16 |
| [0007](./0007-opentelemetry-observabilidade.md) | OpenTelemetry para observabilidade | Aceito | 2026-02-17 |
| [0100](./0100-tokenizacao-pan-no-vault.md) | Tokenização do PAN no vault próprio | Aceito | 2026-05-04 |
| [0101](./0101-roteamento-multiadquirente.md) | Roteamento multiadquirente por BIN | Aceito | 2026-05-18 |
| [0102](./0102-antifraude-sincrono-na-autorizacao.md) | Antifraude síncrono no caminho de autorização | Aceito | 2026-06-09 |
| [0103](./0103-conciliacao-diaria-por-arquivo.md) | Conciliação diária por arquivo do adquirente | Aceito | 2026-07-01 |
