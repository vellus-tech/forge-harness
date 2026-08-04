# LEDGER — roadmap & dívida técnica do projeto

> Arquivo mestre durável do que **não pode se perder**: roadmap planejado, dívida técnica, bugs
> conhecidos, follow-ups e ideias de feature. Sobrevive entre changes. **Gerado** deterministicamente
> de `.forge/ledger/ledger.json` por `/forge:ledger render` — **não edite as seções à mão** (edições
> vivem no `ledger.json` via `/forge:ledger`); só o bloco "Notas" abaixo é preservado entre gerações.
>
> Fontes: captura automática (harvest de deferrals/findings no close/archive) + curadoria manual
> (`/forge:ledger add`). Consultado por `/forge:resume` e ao sugerir o próximo trabalho
> (`rules/conventions/ledger-consultation.md`). **Não-bloqueante**: registrar aqui nunca trava um change.

**15 itens ativos** · roadmap 4 · tech-debt 6 · known-bug 2 · follow-up 3 · (15 encerrados)

## Roadmap

- **LDG-0008** [open] (P2) — Enforcement determinista de TDD-em-feature e de cobertura de propriedades (PBT)
- **LDG-0029** [open] (P2) — Reduzir a cegueira do route-scan: 83 irresolúveis no repositório de referência
  Medido em 2026-08-04 (LDG-0010) contra axis-go-cloud: 38 producer-not-found, 23 group-path-not-literal, 12 producer-never-invoked, 5 mapgroup-unindexed, 5 route-site-unindexed. Concentrados em axis-device-platform/src (37) e packages/dotnet (14). É o que mantém o SUR-01 em 'inconclusive' — com a abstenção global do LDG-0017, qualquer irresolúvel silencia o gate inteiro. Dois recortes prováveis: (a) producer-not-found pode ser produtor definido fora dos caminhos varridos — vale conferir se o wiring de varredura está estreito antes de mexer no scanner; (b) producer-never-invoked não reduz o conjunto de rotas CONHECIDAS (o produtor não é alcançado, logo as rotas dele não existem em runtime), então é candidato à lista NAO_SUPRIME de surContractToCode, que hoje está vazia por decisão do LDG-0017.
- **LDG-0010** [open] (P3) — Promover SRF-01 a bloqueante — bloqueado por insumo (checklist em prosa) e por cegueira do scanner, não pelo oráculo
  SRF-01 hoje sai como WARN porque, sem varredura das rotas reais, não distingue 'a rota não existe' (defeito de código) de 'a task declarou paths: incompleto' (defeito de declaração). MEDIÇÃO REFEITA (2026-08-04) com o scanner corrigido pelos changes route-scan-multifile-mounts e route-scan-dialect-coverage, contra o repositório de referência axis-go-cloud (services, src, apps, axis-device-platform, packages): LADO DO CÓDIGO — 343 rotas resolvidas (o plano original media 41; o 'zero irresolúveis' de então media a estreiteza do reconhecedor) e 83 irresolúveis: 38 producer-not-found, 23 group-path-not-literal, 12 producer-never-invoked, 5 mapgroup-unindexed, 5 route-site-unindexed. Concentrados em axis-device-platform/src (37) e packages/dotnet (14). LADO DECLARADO — 172 endpoints (170 OpenAPI, 9 tabela, 18 checklist; authz-map zero) e 43 irresolúveis, dos quais 41 contract-without-paths. CRUZAMENTO — SUR-01 = inconclusive, 49 abstidos, 5 kinds de blocker. Ou seja: promover hoje resultaria num gate que NÃO dispara neste repositório. SRF-01 EM CHANGES REAIS — 35 changes analisados, 8 com achado, 11 achados no total. Classificados contra o oráculo: 7 (64%) NÃO citam endpoint literal (a célula do checklist é prosa: 'endpoints de publicação no bff + tela admin') e o oráculo não ajuda a decidir; 2 citam endpoint que EXISTE no código (defeito de declaração); 2 citam endpoint AUSENTE (defeito de código OU fora do alcance — e com 83 irresolúveis não dá para afirmar qual). CONCLUSÃO: a premissa do item — 'com o route-scan o SRF-01 passa a distinguir os dois defeitos' — vale para 4 dos 11 achados (36%). O pré-requisito que falta não é o oráculo: é o checklist citar endpoint literal, e a cegueira do scanner cair. Promoção NÃO recomendada nesta medição.
- **LDG-0003** [open] — Maquinaria de capability packs no harness (forge.yaml packs:, installer materializa só packs ativos)

_Encerrados: 1 (resolved 1)_

## Ideias de feature

_(nenhum)_

## Dívida técnica

- **LDG-0013** [open] (P2) — Wave fecha sem gate quando o projeto nao declara runtime.gates (registrado como NO-GATES)
  A Onda B fechou a autocertificacao (wave close agora EXECUTA os gates em vez de aceitar o veredito do chamador), mas deixou uma porta legitima aberta por compatibilidade: projeto sem 'runtime.gates' no FORGE.md fecha a wave sem executar nada. O waves.json registra 'executed:NO-GATES' — auditavel, e o gate w131 assere que esse registro difere do de gate verde, para que 'nao havia gate' nunca se confunda com 'passou'. Fechar de vez exigiria obrigar todo projeto adotante a declarar ao menos um gate, o que e decisao de produto: e a mesma classe do SRF-00 (opt-out por omissao), um nivel acima.
- **LDG-0016** [open] (P2) — Suite: 11 gates criam repo git em /tmp e o gc em background derruba o rm -rf do fixture
  Corrigido no run-all.sh via GIT_CONFIG_COUNT (gc.auto/maintenance.auto/gc.autoDetach = 0) com assercao no w80, mas a causa raiz merece nota: 'git commit' dispara 'git gc --auto' em background, que continua escrevendo em .git depois do commit retornar. O 'rm -rf' do fixture corre contra esse processo e, quando perde, mata o gate DEPOIS de todas as assercoes passarem. Nao reproduz no macOS (APFS+timing), reproduz no CI Linux (overlayfs). Assinatura identica a do SIGPIPE ja corrigido: gate verde isolado, vermelho na suite, gates DIFERENTES a cada execucao — o que significa que parte das 'falhas fantasma' historicas pode ter sido esta, e nao SIGPIPE. Se voltar a aparecer, checar tambem 'git maintenance' e processos filhos do gate.
- **LDG-0021** [open] (P2) — Prova de mutacao mede as regras que existem, nao a superficie de entrada que elas deixam passar
  Limite estrutural exposto pelas CINCO rodadas de revisao do PR #40, e vale registrar porque e' generalizavel a todo gate deste harness. As provas de mutacao do w132 (15) sao fortes no que fazem: mutar a regra que implementa cada correcao faz o caso reprovar, com controle, recontrole, mutador que falha se o alvo textual sumir e checksum do lib de origem. Mas elas medem apenas as regras JA ESCRITAS. NENHUM dos ~25 defeitos das cinco rodadas foi encontrado por mutacao — todos nasceram de alguem construir uma ENTRADA que o reconhecedor nao previa (produtor homonimo, subgrupo dentro de produtor, interpolacao no meio do path, data class sem corpo, 'where T : class', DSL kotlinx.html com nome de verbo, literal com '//' ou chave, emoji dessincronizando code point x UTF-16, verbatim C# terminado em barra, raw string do Kotlin com DSL de exemplo, @Controller sem flag global). E' a mesma forma do defeito que o proprio modulo descreve para o 'unresolved': o que o regex nao reconhece e' invisivel por construcao. PARCIALMENTE ATACADO nesta entrega: (a) o caso [41] virou propriedade POSICIONAL (code[i] e struct[i] so podem ser o original ou espaco; newline nunca some; struct e' sempre mais mascarada que code) medida sobre corpus de DIALETO (.cs/.kt/.java/.ts com comentario de bloco, verbatim multilinha, raw string, emoji), e nao mais sobre os .mjs do proprio harness — a primeira versao media o harness em vez dos dialetos e com a propriedade mais fraca possivel (comprimento); (b) o caso [43] e' PARAMETRICO: 'duas unidades de roteamento no mesmo arquivo' testado nos seis dialetos de uma vez, porque essa classe unica foi descoberta TRES vezes por tres revisoes diferentes (.NET atributos, Spring, e Nest ainda vivo na 5a rodada). O QUE FALTA: fuzzing guiado por gramatica de cada dialeto, e corpus de arquivos REAIS dos repos adotantes — que e' o que de fato pegaria idiomas como o kotlinx.html. Enquanto nao existir, a cobertura de dialeto e' hipotese, nao fato, o que reforca LDG-0017.
- **LDG-0027** [open] (P3/LOW) — Grafo de código é cego no dogfood: o motor do harness vive em bin/ e template/.forge/, ambos pulados
  SKIP_DIRS pula 'bin' e '.forge', e .sh não está no mapa LANG — então /forge:codegraph neste repositório enxerga 19 nós (16 fixtures de tests/fixtures/**, 3 de tools/) e nenhum dos 107 arquivos de template/.forge/scripts/** nem bin/forge.mjs. Pular .forge/ é correto por design (num consumidor é o harness instalado, não o produto); o problema é específico do repo que PRODUZ o template. Consequência: /forge:onboard, /forge:c4 e /forge:impact não têm valor aqui, e a auto-avaliação do harness sobre si mesmo não cobre o próprio motor. Saídas possíveis: raiz de varredura configurável no FORGE.md, ou tratar template/.forge/ como código-fonte quando o package.json declara o pacote forge-harness. Distinto do LDG-0026, que afeta qualquer projeto Node.
- **LDG-0014** [open] (P3) — spec-verify.sh mantem copia propria de get_runtime/run_check em vez de usar lib/forge-runtime.sh
  A Onda B extraiu a leitura do bloco runtime: do FORGE.md e a execucao com teto de tempo para lib/forge-runtime.sh, porque o run-gates.sh precisava delas e a logica so existia inline no spec-verify.sh. O spec-verify NAO foi migrado para a lib nesta onda — decisao de escopo, para nao arriscar o caminho de /forge:verify no mesmo PR. Enquanto nao migrar, ha duas copias que podem divergir: o skip-com-WARN de gate declarado e inexistente ficou apenas no spec-verify (o run-gates.sh REPROVA nesse caso, que e o comportamento correto pela norma da casa). Migrar e apagar a copia.
- **LDG-0020** [open] (P3) — route-scan: composicao e' por CAMINHO, e DAG denso de produtores custa exponencial antes do MAX_DEPTH
  O corte de ciclo (Set no caminho) resolve recursao mutua, e o diagnostico chain-too-deep foi colapsado por owner para nao alocar um objeto por caminho truncado — o que derrubou o consumo de memoria. Mas a travessia continua sendo por caminho, nao memoizada: num DAG acíclico e denso (produtores P0..P29, cada Pi invocando Pi+1..Pi+B) o custo cresce com B^MAX_DEPTH. Medicao da revisao antes do colapso do diagnostico: B=4 dava 420ms/222MB, B=5 dava 12,9s/1,3GB, B=6 estourava a heap. Registrars reais formam arvore, nao DAG denso, entao isto e' robustez e nao defeito de campo — mas a saida existe e e' barata: memoizar por (owner, prefixo) em vez de recompor cada caminho, ja que o resultado so depende desse par.

_Encerrados: 10 (promoted 1 · resolved 8 · wont-fix 1)_

## Bugs conhecidos

- **LDG-0030** [open] (P2) — Bugfix scale 2 que dispensa design fica deadlocked: design-ready exige design.md sem honrar quick_plan.skipped_phases · via `gate-assert-visibility`
  Achado pelo yolo-gate ao decidir o design_reviewed do change gate-assert-visibility. Um change type:bugfix, scale 2, com quick_plan.enabled:true e skipped_phases:[design] nao consegue avançar: (1) spec-transition.sh monta a cadeia por scale e para scale >= 2 o unico proximo passo depois de requirements-ready e design-ready — o script nao consulta quick_plan em nenhum ponto (zero ocorrencias do termo no arquivo); (2) lib/validate-spec.mjs aplica 'if (man.status === design-ready && !has(design.md))' de forma incondicional, sem a isençao que o proprio validador ja concede logo abaixo no guard de tasks-ready ('scale >= 2 && man.type !== bugfix && !has(design.md)'). Ou seja, a intençao de dispensar design.md para bugfix ja esta codificada no validador, mas so vale de tasks-ready em diante; o waypoint design-ready continua exigindo o artefato, e como a transiçao e linear e obrigatoria, o change fica preso em requirements-ready a menos que se fabrique um design.md vazio so para satisfazer o guard — exatamente a ceremonia que quick_plan existe para evitar. Correçao sugerida: fazer o guard de design-ready honrar quick_plan.skipped_phases contendo 'design' (e/ou a mesma isençao type !== bugfix), ou permitir que spec-transition.sh pule a fase declarada em skipped_phases ao montar a cadeia. Nota lateral: yaml-lite.mjs nao suporta array em flow style — 'skipped_phases: [design]' parseia como a string literal '[design]' e faz o validador reprovar com 'requires non-empty skipped_phases'; o template spec-new.sh grava '[]', o que induz o autor ao formato errado.
- **LDG-0028** [open] (P3/LOW) — forge update: mensagem diz '.forge não encontrado' quando o ausente é o forge.yaml
  bin/forge.mjs:426-427 testa existsSync(.forge/forge.yaml) e, ao falhar, emite '.forge não encontrado em <target> — use npx forge-harness init'. Num projeto com .forge/ presente mas sem forge.yaml (harness parcialmente instalado, forge.yaml apagado, ou o dogfood deste repo), a mensagem manda reinstalar do zero quando o diagnóstico real é outro — e 'init' num .forge/ com specs e baseline é justamente o que o /forge:upgrade proíbe. O exit 3 e o não-escrever estão corretos (REQ-FHT-037); só a mensagem mente sobre a causa. Correção: distinguir os dois casos e, quando .forge/ existe, nomear o arquivo ausente. Achado ao rodar /forge:upgrade neste repo (2026-08-03).

_Encerrados: 1 (resolved 1)_

## Follow-ups

- **LDG-0001** [open] — Runtime cross-repo da capability authz/observability (PEP libs Go/Kotlin/TS, repo de política OPA, wrappers OTel, authz-console UI)
- **LDG-0002** [open] — Piloto do gate authz/observability no axis-go-cloud (provar gate quebrando o build ao adicionar rota sem PEP)
- **LDG-0022** [open] — O contrato C5 não foi estendido para asserir o estado `+2 Session hooks`; essa cobertura vive no · via `add-portable-handoff`#verify-1

_Encerrados: 3 (resolved 3)_

## Notas

<!-- FORGE:NARRATIVE:START -->
_(Espaço livre para contexto curado — priorização, sequenciamento, decisões abertas. Preservado
entre gerações do render; a captura automática nunca sobrescreve esta seção.)_
<!-- FORGE:NARRATIVE:END -->
