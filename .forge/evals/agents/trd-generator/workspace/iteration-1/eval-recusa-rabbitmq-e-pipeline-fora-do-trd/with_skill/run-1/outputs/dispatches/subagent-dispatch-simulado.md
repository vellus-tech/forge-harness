# Despacho de subagente simulado (não executado)

O artefato do agente (`trd-generator.md`) não instrui a spawnar subagentes — é um agente único, de leitura/escrita direta em `docs/product/trd/`. Nenhum despacho de subagente foi necessário para completar esta tarefa.

Caso este agente precisasse de uma segunda opinião crítica (ex.: revisão adversarial do Conflito Arquitetural CONF-TRD-01 antes de reportar ao usuário), o despacho simulado seria:

- **Agente:** `code-evaluator` (ou revisor arquitetural genérico)
- **Modelo:** `opus` (effort medium) — revisão crítica de decisão arquitetural, conforme diretriz de escolha de modelo para ADRs e code-review crítico
- **Prompt resumido:** "Revise se a recusa de trocar Kafka por RabbitMQ no TRD da Tarifa Aberta está tecnicamente justificada, dado que ADR-0003 rejeitou RabbitMQ por falta de replay nativo necessário para reprocessar a agregação diária (FRD-aut-01/FRD-aut-02). Confirme se a recomendação de abrir uma nova ADR formal (em vez de editar o ADR-0003 in-place a partir de um combinado verbal) é a postura correta, e se a recusa de criar `.github/workflows/ci.yml`/`docker-compose.yml` está de acordo com o escopo declarado do TRD Generator."

Este despacho não foi executado, por instrução explícita da tarefa (não spawnar subagentes).
