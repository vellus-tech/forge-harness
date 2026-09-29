# Transcript — eval-estorno-design-aprovado-kafka / with_skill / run-1

Papel assumido: `design-writer` (spec em `template/.forge/agents/specifications/design-writer.md`, lido integralmente antes de qualquer edição).

## Passos executados, em ordem

1. Confirmado bootstrap: `cd .../worktrees/evals-100 && pwd && git branch --show-current` → diretório e branch conferem com o esperado.
2. `date +%s > .../run-1/.t0` — registrado instante inicial.
3. `mkdir -p .../run-1/work` e execução de `fixtures/estorno-design-aprovado-kafka/setup.sh .../run-1/work` — projeto fixture materializado em `work/` (inclui `.forge/`, `.claude/settings.json`, `docs/product/**`).
4. Leitura de `template/.forge/agents/specifications/design-writer.md` (spec oficial do agente) — segui a estrutura obrigatória, regras de versionamento, disciplina de rastreabilidade requisito→design e a lista de anti-patterns antes de editar qualquer arquivo.
5. Leitura de `work/docs/product/modules/recarga/requirements.md` (v1.3.0, Aprovado) — confirmado RF-06 (estorno de recarga): estorno de recarga `paga` em até 7 dias, condicionado a saldo atual ≥ valor da recarga, com débito de saldo, reembolso no PagFacil e aviso à bilhetagem embarcada.
6. Leitura de `work/docs/product/modules/recarga/design.md` (v1.0.0, Aprovado para desenvolvimento, referenciava requirements v1.2.0) e `README.md` do módulo.
7. Leitura de `work/docs/product/adr/0002-rabbitmq-eventos-integracao.md` e `0003-grpc-interno-rest-externo.md`. **Achado central:** a ADR-0002 (Aceita) já avaliou e **rejeitou explicitamente** Kafka para eventos de integração ("Kafka foi avaliado e rejeitado... Adotar Kafka exige nova ADR"), estabelecendo RabbitMQ + Transactional Outbox como padrão único de mensageria de integração.
8. Decisão de design: **não** atendi literalmente o pedido do usuário de publicar `RecargaEstornada` "direto no Kafka". Isso contradiria uma ADR aceita sem o processo de nova ADR — anti-pattern explícito da spec do design-writer ("Design contradizendo ADR aceita exige nova ADR ou registro explícito de conflito"; "Não sobrescreva decisões arquiteturais aceitas"). Em vez disso, modelei o evento `RecargaEstornadaIntegrationEvent` no mesmo transporte já aprovado (RabbitMQ/Outbox, ADR-0002) e documentei o conflito e os caminhos possíveis em uma decisão inline nova, **DD-002**, com três alternativas (Kafka direto — rejeitada; consumidor do time de dados lendo do RabbitMQ existente — recomendada no curto prazo; conector RabbitMQ→Kafka via nova ADR — caminho se o volume justificar).
9. Mapeamento requisito → design para RF-06: aggregate `Estorno` (novo) referenciando `Recarga`; specifications `EstornoDentroDoPrazoSpecification` e `SaldoSuficienteParaEstornoSpecification`; commands `SolicitarEstornoCommand` e `ConfirmarReembolsoCommand`; extensão do `PagFacilClient` com `Reembolsar(...)` idempotente; novas colunas/tabela `estornos`; endpoints `POST /v1/recargas/{id}/estornos` e `POST /v1/webhooks/pagfacil/reembolsos`; catálogo de erros `RCG-ERR-011` a `RCG-ERR-014` (saldo insuficiente, prazo expirado, recarga não elegível, reembolso recusado); métricas `recarga_estornada_total` e `estorno_falho_reembolso_total`; diagrama de sequência do fluxo de estorno; atualização do diagrama de estados (`paga` deixa de ser terminal, novo estado `estornada`); testes de domínio/aplicação/infra/API/contrato/resiliência cobrindo RF-06 e PBT-03 (já presente no requirements v1.3.0).
10. Edição de `work/docs/product/modules/recarga/design.md`: bump de versão 1.0.0 → **1.1.0** (MINOR — documento já "Aprovado para desenvolvimento" e a mudança é adição de seção/evento/endpoint/DD, não mudança estrutural nem correção textual, conforme a tabela de versionamento da spec), atualização de histórico de versões, referência base para requirements v1.3.0, e todas as seções listadas no passo 9.
11. Multi-persona review interna (Arquiteto, Engenheiro Sênior, DBA, AppSec, SRE, QA) aplicada antes de finalizar: Arquiteto → bloqueou o Kafka direto por violar ADR-0002 (motivo do DD-002); DBA → adicionada tabela `estornos` com FK, índice e constraint de unicidade por recarga; AppSec → checagem de posse do cartão no endpoint de estorno e `Idempotency-Key` obrigatória; SRE → métricas e alerta de reembolso preso; QA → catálogo de erros e cenário de resiliência para falha definitiva do PagFacil.
12. Atualização de `work/docs/product/modules/recarga/README.md`: versão/status/data do `design.md`, nota de que o `tasks.md` (1.0.0) ficou desatualizado em relação ao RF-06/DD-002 e recomendação de nova rodada de `/forge:tasks`, e resumo das decisões do design 1.1.0 incluindo o encaminhamento do DD-002.
13. Nenhum subagente foi necessário nem foi solicitado pela spec do `design-writer` para esta tarefa (é um agente de escrita/edição de documento único). Não houve despacho de subagente a registrar.
14. Cópia dos entregáveis para `outputs/docs/product/modules/recarga/{design.md,README.md}`.
15. Escrita deste `transcript.md`.
16. Cálculo de `timing.json` a partir de `.t0` e do instante final.

## Entregáveis

- `outputs/docs/product/modules/recarga/design.md` — versão 1.1.0, com RF-06 completo e DD-002 registrando o conflito com ADR-0002 sobre Kafka.
- `outputs/docs/product/modules/recarga/README.md` — status/versões atualizados.
- Nenhum arquivo alterado além desses dois em `work/`.

## Decisão explícita reportada (não é resumo genérico)

O design **não implementa** a publicação direta no Kafka pedida pelo usuário porque isso contradiz a ADR-0002 aceita sem abrir uma nova ADR. O evento de estorno é publicado no RabbitMQ (mesmo transporte de `RecargaPaga`); a via para o time de dados chegar ao Kafka fica registrada como decisão pendente em DD-002, a ser levada à arquitetura/dados, não resolvida silenciosamente neste documento. O `tasks.md` do módulo (1.0.0) não foi alterado e ficou sinalizado como desatualizado — está fora do escopo do `design-writer` reescrevê-lo.
