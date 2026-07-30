# LEDGER — roadmap & dívida técnica do projeto

> Arquivo mestre durável do que **não pode se perder**: roadmap planejado, dívida técnica, bugs
> conhecidos, follow-ups e ideias de feature. Sobrevive entre changes. **Gerado** deterministicamente
> de `.forge/ledger/ledger.json` por `/forge:ledger render` — **não edite as seções à mão** (edições
> vivem no `ledger.json` via `/forge:ledger`); só o bloco "Notas" abaixo é preservado entre gerações.
>
> Fontes: captura automática (harvest de deferrals/findings no close/archive) + curadoria manual
> (`/forge:ledger add`). Consultado por `/forge:resume` e ao sugerir o próximo trabalho
> (`rules/conventions/ledger-consultation.md`). **Não-bloqueante**: registrar aqui nunca trava um change.

**11 itens ativos** · roadmap 4 · tech-debt 5 · follow-up 2 · (1 encerrado)

## Roadmap

- **LDG-0004** [open] (P2) — Red-first: mover a execução do replay para CI (fecha cache e parte do comando arbitrário)
  A norma testing/regression-red-first.md (ADR 0003) é calibrada para descuido, não para autor adversarial: comando declarado arbitrário, defeito introduzido no próprio PR, e waiver externamente inverificável continuam abertos porque a evidência é produzida inteiramente pela parte sendo verificada, num ambiente que ela controla. Rodar o replay (red-evidence.sh ensure/replay) num runner de CI que o autor não controla fecharia o vetor do comando arbitrário (o CI define o ambiente, não o autor) e eliminaria de vez a tentação de reintroduzir um cache local (o CI não precisa de atalho de custo entre execuções isoladas). Não fecha o vetor de defeito-introduzido-no-próprio-PR nem o de waiver inverificável — esses exigem revisão humana, não infraestrutura.
- **LDG-0008** [open] (P2) — Enforcement determinista de TDD-em-feature e de cobertura de propriedades (PBT)
- **LDG-0010** [open] (P2) — Promover SRF-01 a bloqueante quando o route-scan (Onda C) existir
  SRF-01 hoje sai como WARN porque, sem varredura das rotas reais, ele nao distingue 'a rota nao existe' (defeito de codigo, LDG-0091 no Axis.SecretWeapon) de 'a task que entregou a rota declarou paths: incompleto' (defeito de declaracao). Medido no change real: 4 achados sem grafo, 2 com grafo layer:api — um de cada tipo. Com SUR-01 (contrato->codigo) disponivel, o achado passa a ser confirmavel e SRF-01 pode bloquear via opts.enforceable, que ja existe. Corrige tambem uma premissa errada do plano 2026-07-29-api-surface-closure.md: a TASK-56 do change real declara paths apenas em SecretWeapon.Orchestrator/ (que tem ZERO registro de rota), nao em Transport.Api/ — logo o veredito por REQ, sozinho, nao sobrevive ao caso da TASK-56 como o plano supunha.
- **LDG-0003** [open] — Maquinaria de capability packs no harness (forge.yaml packs:, installer materializa só packs ativos)

## Ideias de feature

_(nenhum)_

## Dívida técnica

- **LDG-0009** [open] (P1) — Consumidores com managed-block do .gitignore congelado nao ignoram .forge.bak-*/ nem .forge/cache/
- **LDG-0005** [open] (P2) — gitignore managed-block: updater não mescla padrões novos em bloco já existente
- **LDG-0007** [open] (P2) — Assinatura de IA já no histórico: 275 commits em 5 repositórios
- **LDG-0011** [open] (P2) — Nada exige o campo 'depende:' na linha de task — plano sem metadados passa TSK-01..03 trivialmente
  Descoberto no dogfood do w130: o change create-forge-project-harness tem 30 tasks e ZERO arestas declaradas, porque nenhuma linha carrega o bloco '(rastreia: ...; paths: ...; depende: ...)'. O parser le fielmente (nao ha aresta, logo nao ha aresta invalida) e TSK-01/02/03 passam sem exercitar nada. E a mesma forma do defeito C do plano de fechamento de superficie — porta de saida por omissao: o check e correto e o artefato simplesmente nao fornece o insumo. Pertence a Onda B, junto de SRF-00: exigir o bloco de metadados a partir de tasks-ready, ou registrar explicitamente que o plano nao declara dependencias.
- **LDG-0012** [open] (P2) — Assercoes na forma '[ cond ] && cmd' sob set -e reprovam sem imprimir mensagem
  Custou um ciclo de diagnostico nesta sessao: o w32-archive-gate morreu no meio do passo [2] sem uma linha de saida, e a causa real (um check novo reprovando por outro motivo) ficou invisivel. A forma funciona como assercao — set -e mata o gate — mas engole a razao, e o proximo diagnostico comeca do zero. Varredura encontra o padrao em ~15 gates (w14-adapters com 10 ocorrencias, gw1/gw2/gw3, changelog-merge, w33, w50, w80, w102, w112, w32:168). Distinguir os casos de CONTROLE DE FLUXO legitimo (run-all.sh:31/37/38, copia condicional de fixture) dos de ASSERCAO, e converter apenas os segundos para a forma '|| { echo FAIL ...; exit 1; }'. Corrigido nesta sessao apenas w32:138, o que a regressao atingiu.

_Encerrados: 1 (resolved 1)_

## Bugs conhecidos

_(nenhum)_

## Follow-ups

- **LDG-0001** [open] — Runtime cross-repo da capability authz/observability (PEP libs Go/Kotlin/TS, repo de política OPA, wrappers OTel, authz-console UI)
- **LDG-0002** [open] — Piloto do gate authz/observability no axis-go-cloud (provar gate quebrando o build ao adicionar rota sem PEP)

## Notas

<!-- FORGE:NARRATIVE:START -->
_(Espaço livre para contexto curado — priorização, sequenciamento, decisões abertas. Preservado
entre gerações do render; a captura automática nunca sobrescreve esta seção.)_
<!-- FORGE:NARRATIVE:END -->
