# Transcript — eval `recarga-outbox-cache-com-pan` / with_skill / run-1

Papel assumido: `data-engineer` (orquestrador de dados do Forge), seguindo
`template/.forge/agents/data/data-engineer.md` à risca, em modo `claude --agent` (thread principal
com o usuário), sem a ferramenta `Agent` disponível nesta run — por mandato do harness que orquestra
o eval (nenhum subagente pode ser spawnado; o despacho que seria feito fica registrado, não
executado).

## Passo a passo

1. Bootstrap: `cd .../worktrees/evals-100 && pwd && git branch --show-current` → confirmou
   `.../worktrees/evals-100` e `chore/evals-skills-agentes`, como esperado.
2. `date +%s > .../with_skill/run-1/.t0` — marca o instante inicial.
3. `mkdir -p .../with_skill/run-1/work` e
   `bash .../fixtures/recarga-outbox-cache-com-pan/setup.sh .../with_skill/run-1/work` — a fixture
   roda `node bin/forge.mjs init --target work -y --no-plugin`, sobrepõe o overlay do caso
   (`src/recarga/confirmar-recarga.ts` e `src/recarga/data-classification.json`), remove
   `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents` e `plugin/` (para que o
   baseline do eval não herde os especialistas nem o artefato sob avaliação) e commita o estado
   inicial num repo git novo dentro de `work/`.
4. Li a definição do agente: `template/.forge/agents/data/data-engineer.md` (frontmatter, taxonomia,
   regras de desempate, protocolo, checklist transversal, regra de integração, modo degradado).
5. Explorei a árvore de trabalho:
   - `work/src/recarga/confirmar-recarga.ts` — o código sob revisão.
   - `work/src/recarga/data-classification.json` — mapa de classificação (`numeroCartao`: `pan`,
     `tokenization_boundary: true`; `cpf`: `pii`; `valorCentavos`: `public`).
   - `work/CLAUDE.md` — confirma que os especialistas de dados existem como
     `.forge/agents/data/*` + `.forge/skills/data-*-practices/` (mas ambos foram removidos desta
     instância pela fixture, então li as referências em `template/.forge/`, leitura autorizada pelo
     mandato).
6. Protocolo, item 1 (rules do projeto) — li em `work/.forge/rules/`:
   `data/data-governance.md`, `data/data-cache.md`, `data/data-transactional-nosql.md`,
   `architecture/pii-pci-classification.md`, `conventions/conflict-handling.md`; conferi
   `work/.forge/product/current/adr/` (vazio, só `.gitkeep` — nenhum ADR escolhendo SQL para
   recarga) e `work/.forge/rules/architecture/internal-grpc-communication.md` (não aplicável: não
   há chamada síncrona entre serviços no trecho revisado).
7. Classificação (protocolo item 2): `trabalho assíncrono + lookup de cópia derivada / estruturado /
   MongoDB, RabbitMQ, Redis` — especialistas `data-nosql`, `data-streaming`, `data-cache`; não
   `data-relational` (sem ADR SQL) nem `data-object-storage`/`data-analytical` (fora do escopo do
   pedido).
8. Conflito com rule (protocolo item 3): nenhum bloco `CONFLITO` — não há divergência entre fontes
   normativas (rule vs. ADR); o que existe é o código violando rules já vigentes (antipatterns), o
   que não é uma questão para HITL, é achado de revisão.
9. Decomposição (protocolo item 4): uma pergunta por especialista, registrada em
   `outputs/despacho-simulado.md` junto com o `subagent_type` que seria usado.
10. Delegação (protocolo item 5): sem a ferramenta `Agent`, registrei o despacho que seria feito
    (`outputs/despacho-simulado.md`) e segui pelo "Modo degradado" do próprio agente — que é
    exatamente o comportamento correto quando a ferramenta não está disponível, não um atalho do
    harness. Antes de sintetizar, rodei os comandos de detecção que cada pergunta delegada exige:

    ```
    cd work
    bash .forge/scripts/check-data-governance.sh --path src/recarga
    bash template/.forge/skills/data-nosql-practices/scripts/scan.sh --root src/recarga
    bash template/.forge/skills/data-cache-practices/scripts/scan.sh --root src/recarga
    bash template/.forge/skills/data-streaming-practices/scripts/scan.sh --root src/recarga
    ```

    (os `scan.sh` foram executados a partir de `template/.forge/skills/` — leitura autorizada,
    read-only — porque a fixture removeu `.forge/skills` da árvore `work/` para o eval; `--root`
    apontou para `work/src/recarga`, sem escrever nada ali.)

    Resultado relevante: `check-data-governance.sh` deu `OK`/`universo` (lido como "não
    verificado", nunca aprovação — autoridade real é o `data-classification.json`);
    `data-streaming` achou `RMQ-AP-08` (publish sem confirms) e `RMQ-AP-12` (mensagem não
    persistente) em `confirmar-recarga.ts:29`; `data-nosql` e `data-cache` sem achado estático (os
    problemas de dual-write/outbox, tenant e hash sem chave não têm detector estático — são
    revisão obrigatória, feita por leitura manual do código contra `references/antipatterns.md` de
    cada especialista e contra as rules).
11. Síntese (protocolo item 6): atribuí cada recomendação ao especialista de origem
    (`data-nosql`: outbox na mesma transação + campo/filtro de tenant; `data-streaming`: relay com
    confirms/persistência/idempotência; `data-cache`: invalidação pós-commit no consumidor +
    correção da chave) e apliquei o checklist transversal (T-02: `numeroCartao` é PAN pelo
    `data-classification.json` e vaza no evento; T-04: chave de cache é hash sem chave de CPF;
    multi-tenant: falta em Mongo e em Redis). Escrevi a resposta final em `outputs/resposta.md`.
12. Verifiquei que a árvore `work/` não foi tocada: `git -C work status --porcelain` → vazio.
13. Instante final: `t1=$(date +%s)`; escrevi `timing.json` com `total_tokens: 0` (não medido nesta
    run) e a duração real em segundos/ms a partir de `.t0`.

## Decisões e por que

- **Não criei nenhum subagente real** (ferramenta `Agent` indisponível por mandato do harness do
  eval) — segui o "Modo degradado" descrito no próprio `data-engineer.md`, que é o comportamento
  correto e documentado do agente nesse cenário, não uma improvisação.
- **Não tratei a ausência de tenant/o hash sem chave como bloco `CONFLITO`** — `conflict-handling.md`
  reserva `CONFLITO` para divergência entre fontes normativas (rule vs. ADR, módulo vs. módulo); aqui
  não há duas fontes discordando, há código que ainda não segue as rules vigentes. Isso é achado de
  revisão com correção recomendada, e não HITL bloqueante de decisão arquitetural em aberto.
- **`data-relational` não foi roteado** — não há ADR no baseline escolhendo SQL para o domínio
  recarga; pela matriz do orquestrador e por `data-governance.md` (H-01 (a)), o dono do store
  segue sendo MongoDB.
- **`data-classification.json` como autoridade sobre `numeroCartao`/PAN**, mesmo o scanner T-02 não
  tendo casado o nome do campo — o protocolo do orquestrador (item 5) manda tratar esse arquivo como
  autoridade sobre PAN/PII acima do resultado (limitado) do scanner estático.
