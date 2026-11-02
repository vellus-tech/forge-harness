# Proposal — add-ledger-evidence-aging

> Change `add-ledger-evidence-aging` (type: `feature`, scale 2) — criado em 2026-10-30 por milton. Gates humanos delegados pelo dono a revisores adversariais independentes (aceite formal registrado em `approvals.yaml`).

## 1. Por quê (problema / motivação)

O ledger durável (`.forge/ledger/ledger.json`, operado por `ledger-ops.sh`) registra roadmap e dívida técnica que sobrevivem entre changes, e é a fonte que `/forge:resume`, `/forge:status` e a rule `ledger-consultation.md` mandam consultar antes de escolher o próximo trabalho. Um item do ledger é uma afirmação sobre o código feita numa data; o código muda depois e ninguém reconfere a afirmação. Já houve casos registrados neste projeto de item que envelheceu e passou a descrever o defeito maior, menor ou diferente do que ele era (norma "medir antes de implementar"), e o ledger não tem hoje nenhum campo que diga quando a afirmação foi conferida pela última vez, contra o quê, nem nenhum sinal que avise que ela está velha.

Medição sobre o ledger do próprio repositório (HEAD de 2026-10-30): 38 itens ativos (`open`/`planned`/`in-progress`), todos com mais de 30 dias desde o registro (idade mínima 32 dias, mediana 52, máxima 92); 23 dos 38 nunca receberam nenhuma atualização depois de criados. O único rastro de reverificação que existe é textual: 17 entradas carregam blocos `MEDIÇÃO`/`CORREÇÃO DE REGISTRO` acrescentados por `note`, que nenhum leitor do ledger consegue distinguir de progresso nem datar como conferência. Item envelhecendo em silêncio é o estado padrão, não a exceção.

O projeto externo `akitaonrails/ai-memory` (estudado por suas ideias, não adotado) resolve um problema parecido registrando quais sessões produziram ou reafirmaram cada memória, uma confiança calculada sem LLM a partir de recência, e links tipados de supersessão. A parte transferível para cá, aprovada pelo dono, é: data da última reverificação, evidência estruturada do que foi conferido e elo explícito de supersessão, mais um sinal determinístico de idade.

## 2. O que muda

1. **Schema do ledger (aditivo):** cada entrada passa a aceitar, de forma opcional, `last_verified` (data da última reverificação contra o código/estado real), `evidence` (lista acumulativa de registros estruturados do que foi conferido e como) e `supersedes` (id da entrada anterior que esta substitui), mais `links.superseded_by` (o elo inverso) e o novo status terminal `superseded`. Entradas existentes, sem esses campos, continuam válidas sem migração.
2. **Porta de escrita `verify`:** `ledger-ops.sh verify <LDG-NNNN>` registra uma reverificação com evidência de conteúdo mínimo verificável por script (referência que existe de fato: arquivo e linha existentes, commit resolvível, teste existente, ou comando com saída observada), carimba `last_verified` e, quando o veredito é "mudou", acrescenta a correção ao `detail` pelo mesmo mecanismo acumulativo do `note`.
3. **Supersessão:** `ledger-ops.sh add --supersedes <LDG-NNNN>` cria a entrada nova já ligada à anterior e encerra a anterior como `superseded`, com elo bidirecional. A cadeia (A substitui B, que substitui C) fica visível na consulta.
4. **Sinal de idade determinístico:** `ledger-ops.sh stale` lista os itens ativos não reverificados há mais de N dias (N de `forge.yaml > ledger.stale_days`, default 30, sobreponível por flag), com relógio do commit HEAD (a mesma noção de tempo do resto do ledger), saída não bloqueante por padrão e modo `--strict` com código de saída para quem quiser travar em CI.
5. **Fiação no ciclo de vida:** o one-line de `ledger-ops.sh status` (usado por `/forge:status`) passa a contar os itens envelhecidos; o `list` (usado por `/forge:resume` e pelo hook `SessionStart`, onde o próximo trabalho é escolhido) marca cada item envelhecido; `spec new --from-ledger` não liga um change a item já substituído e aponta o sucessor; o `/forge:doctor` ganha a linha advisory correspondente; `list`, a nova consulta `show` e o `LEDGER.md` exibem `last_verified` e a supersessão; o comando `/forge:ledger`, a rule `ledger-consultation.md`, o `forge.yaml`/`forge.schema.json` e o `CHANGELOG.md` documentam o mecanismo.
6. **Gate de teste hermético** em `tests/` cobrindo as portas novas, a compatibilidade retroativa e provas de mutação.

## 3. O que NÃO muda (fora de escopo)

- O ledger continua **não-bloqueante por design**: nenhum item envelhecido trava change, gate, archive ou a suíte do projeto por padrão; só o `--strict`, invocado explicitamente, devolve código de saída de falha.
- O sistema de memória de sessão do Claude Code (diretório pessoal `~/.claude/projects/.../memory/`) não é produto distribuído por este repositório e não é tocado. O desenho deixa o formato de evidência reaproveitável, mas aplicá-lo à memória é outro change.
- Nenhuma confiança numérica, pontuação ou cálculo por LLM: o sinal é idade em dias contra limiar declarado.
- Não há migração nem reescrita retroativa do `ledger.json` de nenhum consumidor; itens antigos envelhecem a partir do `created_at`.
- Nenhum carimbo automático de `last_verified` por `/forge:close`, `/forge:archive`, `note` ou `update`: reverificação é ato explícito com evidência (ver requirements).
- Semântica atual de `open`/`planned`/`in-progress`/`resolved`/`wont-fix`/`promoted`, `harvest`, `promote`, `resolve`, `note` e da guarda de `detail` acumulativo permanece como está.

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template` (maquinaria distribuída do ledger).
- **Paths afetados:** `template/.forge/schemas/ledger.schema.json`, `template/.forge/scripts/ledger-ops.sh`, `template/.forge/scripts/lib/ledger-render.mjs`, `template/.forge/scripts/doctor.sh`, `template/.forge/schemas/forge.schema.json`, `template/.forge/forge.yaml`, `template/.forge/scripts/spec-new.sh`, `template/.forge/commands/harness/ledger.md` e `template/.forge/commands/harness/resume.md` (e as cópias geradas em `plugin/forge/`), `template/.forge/rules/conventions/ledger-consultation.md`, `tests/` (gate novo), `CHANGELOG.md`, `README.md` (inventário).
- **Dependências:** nenhuma spec ativa; reaproveita `lib/arg-guards.sh`, `lib/forge-root.sh` e o idioma de data do commit HEAD já existentes em `ledger-ops.sh`.
- **Riscos:** (a) consumidores com ledger estendido (enum próprio) — mitigado por mudanças só aditivas no schema; (b) evidência virar campo de preenchimento vazio — mitigado por validação por script do conteúdo mínimo; (c) novo status terminal esquecido por algum leitor do ledger, que passaria a contar `superseded` como ativo — mitigado por inventário dos leitores no design e asserção no gate; (d) sinal de idade virar ruído ignorado — mitigado por ser advisory e limiar configurável.

## 5. Próximos passos

`/forge:requirements` → `/forge:design` → `/forge:tasks` → `/forge:implement` (TDD) → `/forge:verify` → `/forge:archive`, com cada gate humano decidido por revisor adversarial delegado.
