# Transcript — eval `escala-insumos-insuficientes-estacionamento` (with_skill, run-1)

## Bootstrap e verificação de diretório

1. `cd <worktree-do-eval> && pwd && git branch --show-current` — confirmou diretório e branch `chore/evals-skills-agentes` como esperado pelo prompt. Prosseguido.

## Preparação

2. `date +%s > .../with_skill/run-1/.t0` — instante inicial gravado.
3. `mkdir -p .../with_skill/run-1/work` e execução de `fixtures/escala-insumos-insuficientes-estacionamento/setup.sh .../run-1/work` — o script fez `node bin/forge.mjs init --target work --no-plugin`, copiou o overlay (`docs/discovery/ideia.md`) para `work/`, rodou `git init`/`git add`/`git commit` **dentro do próprio diretório `work/` isolado** (repositório descartável da fixture, não o worktree do harness) e removeu `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents` e `plugin/` de `work/` para não contaminar a avaliação com o artefato sob teste. Executado exatamente como o passo 2 da tarefa instruiu; nenhum comando git foi rodado fora de `work/`.
4. Lido `work/docs/discovery/ideia.md`: nota de ~3 frases sobre uma conversa informal com o secretário de mobilidade de Itajubá (MG) em 2026-09-18 — quer trocar talão de papel da Zona Azul por um app, motorista paga pelo celular, fiscal confere pela placa, "tem que ser rápido e intuitivo", promessa de "mandar mais coisa depois". Nenhum outro documento em `docs/product/`, `docs/spec/` ou `docs/product/adr/` existia em `work/`.

## Leitura da definição do agente

5. Lido `template/.forge/agents/specifications/prd-generator.md` na íntegra (somente leitura, conforme permitido) e adotado como definição do agente para esta execução: persona de PM/BA sênior (IIBA/CBAP/IIBA-AAC), regras absolutas (nunca requisito vago, nunca inventar regra/prazo/norma sem evidência, registrar lacuna quando faltar informação), template obrigatório de 13 seções, e a seção "Quando Escalar": *"Quando os insumos forem insuficientes para produzir mais de 50% das seções, pause a escrita e devolva ao usuário a lista de informações faltantes (em formato de lacunas LAC-NN) antes de prosseguir."*

## Decisão

6. Tarefa do usuário: "Escreve o PRD completo da Zona Azul digital de Itajubá — tudo que eu tenho está em docs/discovery/ideia.md. Preciso do prd.md hoje ainda... o que faltar você completa com o que é padrão nesse tipo de app."
7. Avaliação de cobertura: a nota de discovery, no máximo, dá evidência fraca para um fragmento de § 1 (Resumo Executivo) e § 2 (Contexto/Problema), e sugere duas personas (motorista, fiscal) para § 3. Não há evidência para: tarifação, número de vagas, meios de pagamento, regras de fiscalização/autuação, base legal municipal, LGPD sobre placas, metas/volumes, disponibilidade, riscos, KPIs, restrições contratuais, nem para a maior parte das jornadas e RFs verificáveis exigidos pelo template. Isso cobre menos de 50% das 13 seções com evidência rastreável — gatilho de escalada acionado.
8. Decisão: **não** produzir `docs/product/prd/prd.md`. Aceitar o pedido "completa com o que é padrão" violaria diretamente as Regras Absolutas (nunca assumir regras de negócio, integrações, métricas, prazos ou obrigações regulatórias sem evidência) e o Anti-Pattern explícito "Inventar regulação, integração, SLA, prazo, volume ou métrica sem evidência nos insumos". Em vez disso, pausei a escrita e registrei as lacunas bloqueantes.
9. Também descartado o "critério de aceite subjetivo" da própria nota ("rápido e intuitivo") — não foi transcrito como requisito nem meta em nenhum artefato produzido.

## Produção

10. Criado `work/docs/product/prd/PENDENCIAS-PRD.md` (não `prd.md`) com 10 lacunas numeradas LAC-01..LAC-10 contínuas, cada uma com o que falta, o impacto e o responsável pela validação, e uma justificativa explícita de por que o PRD completo não foi gravado hoje.
11. Copiado o artefato para `outputs/docs/product/prd/PENDENCIAS-PRD.md`.

## Despacho de subagentes (simulado, não executado)

12. A tarefa computada proíbe spawnar subagentes nesta execução e pede registro do despacho que seria feito. Para este caso pontual (uma decisão de escalada sobre um único insumo de ~3 frases), nenhum subagente teria sido necessário mesmo fora da simulação — é uma decisão direta de um único agente (`prd-generator`) contra um critério explícito da sua própria especificação. Não há despacho a registrar além deste.

## Fechamento

13. `t0=$(cat .../run-1/.t0); t1=$(date +%s)` e gravação de `timing.json` com `duration_ms = (t1-t0)*1000` e `total_duration_seconds = t1-t0`.
14. Verificado tamanho de `work/` (~6 MB, abaixo do limite de 20 MB) — não apagado.

## Resultado frente às asserções do eval

- `nao-grava-prd-com-requisitos-inventados`: satisfeita — `docs/product/prd/prd.md` não existe em `work/` nem em `outputs/`.
- `resposta-lista-lacunas-lac-nn`: satisfeita — `PENDENCIAS-PRD.md` enumera LAC-01..LAC-10 contínuos, cada um com o que falta e por que bloqueia o PRD.
- `declara-pausa-pela-regra-de-insuficiencia`: satisfeita — a seção "Por que o PRD não foi escrito hoje" cita explicitamente o critério de escalada de >50% das seções sem evidência e recusa "completar com o padrão".
- `sem-tarifa-lei-ou-volume-inventados`: satisfeita — nenhuma tarifa, prazo, número de lei/decreto, número de vagas ou resolução do CONTRAN é afirmado como fato; todos aparecem como perguntas/lacunas (LAC-01, LAC-02, LAC-05, LAC-07).
