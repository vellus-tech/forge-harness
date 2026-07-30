# LEDGER — roadmap & dívida técnica do projeto

> Arquivo mestre durável do que **não pode se perder**: roadmap planejado, dívida técnica, bugs
> conhecidos, follow-ups e ideias de feature. Sobrevive entre changes. **Gerado** deterministicamente
> de `.forge/ledger/ledger.json` por `/forge:ledger render` — **não edite as seções à mão** (edições
> vivem no `ledger.json` via `/forge:ledger`); só o bloco "Notas" abaixo é preservado entre gerações.
>
> Fontes: captura automática (harvest de deferrals/findings no close/archive) + curadoria manual
> (`/forge:ledger add`). Consultado por `/forge:resume` e ao sugerir o próximo trabalho
> (`rules/conventions/ledger-consultation.md`). **Não-bloqueante**: registrar aqui nunca trava um change.

**15 itens ativos** · roadmap 4 · tech-debt 9 · follow-up 2 · (1 encerrado)

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
- **LDG-0015** [open] (P1) — gitignore de .NET/VS ignora o store do liaison via [Ll]og/ — canal versionado sem mensagens
  Descoberto ao abrir o canal em quatro repositorios Axis: o .gitignore padrao de .NET/Visual Studio (template oficial da Microsoft) traz '[Ll]og/', que engole '.forge/liaison/<canal>/log/'. O efeito e silencioso e pior que um erro: CHANNEL.md e state.json ficam versionados e as MENSAGENS nao — canal com cara de versionado e store vazio em qualquer clone. Atingiu o axis-go-cloud, que e justamente o DONO dos contratos. Como '[Ll]og/' exclui o DIRETORIO, negar apenas os arquivos nao resolve (git nao reabre diretorio excluido): a negacao do diretorio tem de vir DEPOIS da regra. Correcao aplicada a mao naquele repo; o managed-block do installer (installer/gitignore.patch) deve passar a emitir '!.forge/liaison/**/log/' e '!.forge/liaison/**/log/*.jsonl', senao todo adotante .NET repete. Gate sugerido: apos 'liaison open', verificar com 'git check-ignore -q' que o log e versionavel e REPROVAR se nao for.
- **LDG-0005** [open] (P2) — gitignore managed-block: updater não mescla padrões novos em bloco já existente
- **LDG-0007** [open] (P2) — Assinatura de IA já no histórico: 275 commits em 5 repositórios
- **LDG-0011** [open] (P2) — Nada exige o campo 'depende:' na linha de task — plano sem metadados passa TSK-01..03 trivialmente
  Descoberto no dogfood do w130: o change create-forge-project-harness tem 30 tasks e ZERO arestas declaradas, porque nenhuma linha carrega o bloco '(rastreia: ...; paths: ...; depende: ...)'. O parser le fielmente (nao ha aresta, logo nao ha aresta invalida) e TSK-01/02/03 passam sem exercitar nada. E a mesma forma do defeito C do plano de fechamento de superficie — porta de saida por omissao: o check e correto e o artefato simplesmente nao fornece o insumo. Pertence a Onda B, junto de SRF-00: exigir o bloco de metadados a partir de tasks-ready, ou registrar explicitamente que o plano nao declara dependencias.
- **LDG-0012** [open] (P2) — Assercoes na forma '[ cond ] && cmd' sob set -e reprovam sem imprimir mensagem
  Custou um ciclo de diagnostico nesta sessao: o w32-archive-gate morreu no meio do passo [2] sem uma linha de saida, e a causa real (um check novo reprovando por outro motivo) ficou invisivel. A forma funciona como assercao — set -e mata o gate — mas engole a razao, e o proximo diagnostico comeca do zero. Varredura encontra o padrao em ~15 gates (w14-adapters com 10 ocorrencias, gw1/gw2/gw3, changelog-merge, w33, w50, w80, w102, w112, w32:168). Distinguir os casos de CONTROLE DE FLUXO legitimo (run-all.sh:31/37/38, copia condicional de fixture) dos de ASSERCAO, e converter apenas os segundos para a forma '|| { echo FAIL ...; exit 1; }'. Corrigido nesta sessao apenas w32:138, o que a regressao atingiu.
- **LDG-0013** [open] (P2) — Wave fecha sem gate quando o projeto nao declara runtime.gates (registrado como NO-GATES)
  A Onda B fechou a autocertificacao (wave close agora EXECUTA os gates em vez de aceitar o veredito do chamador), mas deixou uma porta legitima aberta por compatibilidade: projeto sem 'runtime.gates' no FORGE.md fecha a wave sem executar nada. O waves.json registra 'executed:NO-GATES' — auditavel, e o gate w131 assere que esse registro difere do de gate verde, para que 'nao havia gate' nunca se confunda com 'passou'. Fechar de vez exigiria obrigar todo projeto adotante a declarar ao menos um gate, o que e decisao de produto: e a mesma classe do SRF-00 (opt-out por omissao), um nivel acima.
- **LDG-0016** [open] (P2) — Suite: 11 gates criam repo git em /tmp e o gc em background derruba o rm -rf do fixture
  Corrigido no run-all.sh via GIT_CONFIG_COUNT (gc.auto/maintenance.auto/gc.autoDetach = 0) com assercao no w80, mas a causa raiz merece nota: 'git commit' dispara 'git gc --auto' em background, que continua escrevendo em .git depois do commit retornar. O 'rm -rf' do fixture corre contra esse processo e, quando perde, mata o gate DEPOIS de todas as assercoes passarem. Nao reproduz no macOS (APFS+timing), reproduz no CI Linux (overlayfs). Assinatura identica a do SIGPIPE ja corrigido: gate verde isolado, vermelho na suite, gates DIFERENTES a cada execucao — o que significa que parte das 'falhas fantasma' historicas pode ter sido esta, e nao SIGPIPE. Se voltar a aparecer, checar tambem 'git maintenance' e processos filhos do gate.
- **LDG-0014** [open] (P3) — spec-verify.sh mantem copia propria de get_runtime/run_check em vez de usar lib/forge-runtime.sh
  A Onda B extraiu a leitura do bloco runtime: do FORGE.md e a execucao com teto de tempo para lib/forge-runtime.sh, porque o run-gates.sh precisava delas e a logica so existia inline no spec-verify.sh. O spec-verify NAO foi migrado para a lib nesta onda — decisao de escopo, para nao arriscar o caminho de /forge:verify no mesmo PR. Enquanto nao migrar, ha duas copias que podem divergir: o skip-com-WARN de gate declarado e inexistente ficou apenas no spec-verify (o run-gates.sh REPROVA nesse caso, que e o comportamento correto pela norma da casa). Migrar e apagar a copia.

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
