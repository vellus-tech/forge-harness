# Requirements — fixture-w130

> Fixture CONGELADO: a seção abaixo é a tabela real, com a coluna "Parâmetro/config exposto"
> substituída. As colunas REQ, Superfície e "Coberto por task" são as do artefato original —
> são elas que o SRF-01 cruza, e alterá-las destruiria o valor probatório do fixture.

## Checklist de cobertura de superfície

> Preenchido para todo parâmetro/configuração exposto por este change. A coluna de task fica pendente
> até `/forge:tasks`; `/forge:analyze` cruza esta tabela antes do marco.

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | parametro 01 | `GET/POST/PUT/DELETE /api/v1/configs/partitions`, tela Configurações | TASK-09, TASK-18, TASK-81 |
| REQ-02 | parametro 02 | arquivo de configuração versionado, exibido em somente-leitura na tela Configurações | TASK-10 |
| REQ-03 | parametro 03 | endpoint de alocação em Configs; seletor de partição no compositor; limite na configuração de Configs | TASK-11, TASK-12, TASK-13, TASK-14, TASK-18, TASK-81, TASK-83 |
| REQ-04 | parametro 04 | configuração do processo — sem override por spec, conector ou mensagem | TASK-20, TASK-22, TASK-23, TASK-25, TASK-33, TASK-34 |
| REQ-05 | parametro 05 | endpoint no **orquestrador**, exigindo a afirmação de inalcançabilidade; ação na tela Configurações | TASK-27, TASK-28, TASK-63, TASK-81 |
| REQ-06 | sem parâmetro exposto | — | TASK-45, TASK-46, TASK-47, TASK-48, TASK-62 |
| REQ-07 | parametro 07 | configuração do connector | TASK-53 |
| REQ-08 | parametro 08 | endpoint de envio no orquestrador; compositor de mensagens | TASK-49, TASK-50, TASK-63 |
| REQ-09 | sem parâmetro exposto | — | TASK-51, TASK-52 |
| REQ-10 | sem parâmetro exposto | — | TASK-07, TASK-08 |
| REQ-11 | parametro 11 | configuração de máscara no backend, sem chave para desligar globalmente | TASK-35, TASK-36, TASK-37, TASK-39, TASK-58, TASK-74 |
| REQ-12 | parametro 12 | ação por valor no console e no compositor | TASK-41, TASK-42, TASK-63, TASK-67, TASK-80 |
| REQ-13 | sem parâmetro exposto | compositor de mensagens | TASK-75, TASK-76, TASK-83, TASK-86 |
| REQ-14 | sem parâmetro exposto | home | TASK-55, TASK-63, TASK-77, TASK-78, TASK-86 |
| REQ-15 | sem parâmetro exposto | console, aba PERNAS | TASK-57, TASK-70, TASK-71, TASK-72, TASK-73, TASK-79 |
| REQ-16 | sem parâmetro exposto | stream SSE e interface | TASK-12, TASK-29, TASK-54 |
| REQ-17 | sem parâmetro exposto | ajuda contextual das quatro telas | TASK-85 |
| REQ-18 | sem parâmetro exposto | `contracts/openapi/` e `contracts/asyncapi/` | TASK-18, TASK-57, TASK-63, TASK-64, TASK-65, TASK-66, TASK-73 |
| REQ-19 | sem parâmetro exposto | — | TASK-46, TASK-60, TASK-61, TASK-62 |
| REQ-20 | parametro 20 | `src/main/resources/specs/dialect-a.json`; visíveis na tela de specs | TASK-04, TASK-05, TASK-06 |
| REQ-21 | sem parâmetro exposto | `docs/adr/` | TASK-02, TASK-03 |
| REQ-22 | parametro 22 | `contracts/openapi/acme-configs-api.v1.yaml`; tela Configurações | TASK-15, TASK-16, TASK-17, TASK-18, TASK-37, TASK-40, TASK-71, TASK-82 |
| REQ-23 | sem parâmetro exposto | `docker-compose.yml` (serviço existente, sem porta nova) | TASK-19, TASK-34, TASK-50, TASK-59 |
| REQ-24 | parametro 24 | configuração do orquestrador | TASK-55, TASK-86 |
| REQ-25 | sem parâmetro exposto | endpoint no orquestrador; ação no console e na home | TASK-56, TASK-63, TASK-84, TASK-86 |
| REQ-28 | parametro 26 | configuração do orquestrador | TASK-20, TASK-21, TASK-28, TASK-30, TASK-31, TASK-42 |
| REQ-29 | parametro 27 | configuração do orquestrador | TASK-23, TASK-24, TASK-25, TASK-26, TASK-32, TASK-78 |


## Fora de escopo
