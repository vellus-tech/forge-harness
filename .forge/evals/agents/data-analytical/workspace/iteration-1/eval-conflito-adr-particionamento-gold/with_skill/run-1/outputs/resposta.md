# Resposta do agente `data-analytical`

Antes de fechar o DDL de `gold.recargas_diarias`, o layout físico dessa tabela tem um conflito entre o ADR do projeto e a prática da skill — preciso que isso seja decidido antes de eu (ou o `task-coder`) escrever o arquivo.

```text
CONFLITO
decisão: layout físico (particionamento vs. clustering) de gold.recargas_diarias no Databricks
posição A: PARTITIONED BY (dt) obrigatório em toda tabela gold; liquid clustering e ZORDER BY proibidos até nova decisão — fonte: .forge/product/current/adr/0004-layout-fisico-tabelas-gold.md (ADR-0004, Aceito, 2026-03-10)
posição B: não particionar (estilo Hive) tabela abaixo de 1 TB no Databricks; usar liquid clustering — fonte: skill data-analytical-practices, references/antipatterns.md, A-05/A-06 (limiar também documentado na doc do Databricks sobre liquid clustering)
precedência: baseline/ADR acima de rules e de contexto (FORGE.md §2.1: constitution > baseline/ADRs > rules > contexto) — o ADR-0004 venceria a skill se a decisão for aplicada como está
opções: aplicar a fonte de maior autoridade (recomendado: seguir ADR-0004, PARTITIONED BY (dt), mesmo abaixo de 1 TB) | abrir ou atualizar ADR (registrar exceção ou revisão do ADR-0004 para permitir liquid clustering em tabelas gold pequenas) | bloquear
registro: a decisão humana vai para approvals.yaml do change em curso, ou para o próprio ADR-0004 (nova versão/ADR sucessor) — quem registra é a sessão principal ou o pipeline /forge:* em curso; este agente não registra
```

## Por que parei aqui

`gold.recargas_diarias` é um agregado diário (~80 GB projetado em três anos, bem abaixo do limiar de 1 TB que a skill usa para desaconselhar partição manual no Databricks). Isso é exatamente o cenário que o ADR-0004 não previu explicitamente — ele fixa `PARTITIONED BY (dt)` para *toda* tabela gold, sem exceção por tamanho — enquanto a prática padrão da skill (A-05 superparticionamento, A-06 partição Hive manual) recomendaria liquid clustering em vez de partição Hive para uma tabela deste porte. Layout físico de tabela é estratégia de persistência, uma das categorias que `.forge/rules/conventions/conflict-handling.md` classifica como conflito arquitetural relevante — o protocolo do agente manda parar e escalar, não decidir por conta própria nem seguir silenciosamente a skill contrariando o ADR aceito.

## O que preciso de você

Uma decisão entre as três opções acima. Se a resposta for "aplicar o ADR-0004 como está", eu devolvo o DDL completo com `PARTITIONED BY (dt)` (grão diário por operadora, valor em centavos conforme `money-as-cents.md`, colunas de tenant e chaves) na sequência — é rápido, só estava pendente desta escolha. Se preferir abrir uma exceção/atualização de ADR para liquid clustering em tabelas gold pequenas, registre isso primeiro (via `/forge:adr` ou `approvals.yaml` do change em curso) e eu sigo com o DDL já alinhado à nova decisão.

Nenhum arquivo foi criado ou alterado nesta resposta (nem `lakehouse/gold/recargas_diarias.sql`, nem ADR, nem `approvals.yaml`) — este agente não tem `Write`/`Edit`; quem aplica é o `task-coder` depois que o layout estiver decidido.
