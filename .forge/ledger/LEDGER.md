# LEDGER — roadmap & dívida técnica do projeto

> Arquivo mestre durável do que **não pode se perder**: roadmap planejado, dívida técnica, bugs
> conhecidos, follow-ups e ideias de feature. Sobrevive entre changes. **Gerado** deterministicamente
> de `.forge/ledger/ledger.json` por `/forge:ledger render` — **não edite as seções à mão** (edições
> vivem no `ledger.json` via `/forge:ledger`); só o bloco "Notas" abaixo é preservado entre gerações.
>
> Fontes: captura automática (harvest de deferrals/findings no close/archive) + curadoria manual
> (`/forge:ledger add`). Consultado por `/forge:resume` e ao sugerir o próximo trabalho
> (`rules/conventions/ledger-consultation.md`). **Não-bloqueante**: registrar aqui nunca trava um change.

**16 itens ativos** · roadmap 3 · tech-debt 9 · known-bug 1 · follow-up 3 · (12 encerrados)

## Roadmap

- **LDG-0008** [open] (P2) — Enforcement determinista de TDD-em-feature e de cobertura de propriedades (PBT)
- **LDG-0010** [open] (P2) — Promover SRF-01 a bloqueante quando o route-scan (Onda C) existir
  SRF-01 hoje sai como WARN porque, sem varredura das rotas reais, ele nao distingue 'a rota nao existe' (defeito de codigo) de 'a task que entregou a rota declarou paths: incompleto' (defeito de declaracao). ATUALIZACAO (Onda C, gate w132): o pre-requisito existe — lib/route-scan.mjs resolve as rotas reais, inclusive a cadeia de dois saltos. A promocao NAO foi feita, e agora ha um motivo a mais alem da calibracao: a revisao critica do PR #40 encontrou seis classes de defeito no proprio oraculo, todas emitindo path INVENTADO com unresolved vazio (produtor homonimo indexado por nome global, subgrupo aberto dentro de produtor relativo, interpolacao dentro da aspa em JS/Kotlin, duas classes-controller por arquivo, cadeia fluente invisivel, router Express sem mount, contrato OpenAPI em JSON nunca parseado). Todas corrigidas com teste e prova de mutacao no mesmo PR. CONSEQUENCIA PARA A MEDICAO: os numeros que o PR original reportava contra o repositorio de referencia (41 rotas, zero irresolveis, SUR-01 = 0) foram medidos com o scanner defeituoso e NAO valem como calibracao — 'zero irresolveis' media a estreiteza do reconhecedor, nao a cobertura. A medicao tem de ser refeita com o scanner corrigido antes de qualquer promocao, e agora deve reportar tambem o numero de unresolved por escopo, que e' o insumo do LDG-0017.
- **LDG-0003** [open] — Maquinaria de capability packs no harness (forge.yaml packs:, installer materializa só packs ativos)

_Encerrados: 1 (resolved 1)_

## Ideias de feature

_(nenhum)_

## Dívida técnica

- **LDG-0012** [open] (P2) — Assercoes na forma '[ cond ] && cmd' sob set -e reprovam sem imprimir mensagem
  Custou um ciclo de diagnostico nesta sessao: o w32-archive-gate morreu no meio do passo [2] sem uma linha de saida, e a causa real (um check novo reprovando por outro motivo) ficou invisivel. A forma funciona como assercao — set -e mata o gate — mas engole a razao, e o proximo diagnostico comeca do zero. Varredura encontra o padrao em ~15 gates (w14-adapters com 10 ocorrencias, gw1/gw2/gw3, changelog-merge, w33, w50, w80, w102, w112, w32:168). Distinguir os casos de CONTROLE DE FLUXO legitimo (run-all.sh:31/37/38, copia condicional de fixture) dos de ASSERCAO, e converter apenas os segundos para a forma '|| { echo FAIL ...; exit 1; }'. Corrigido nesta sessao apenas w32:138, o que a regressao atingiu.
- **LDG-0013** [open] (P2) — Wave fecha sem gate quando o projeto nao declara runtime.gates (registrado como NO-GATES)
  A Onda B fechou a autocertificacao (wave close agora EXECUTA os gates em vez de aceitar o veredito do chamador), mas deixou uma porta legitima aberta por compatibilidade: projeto sem 'runtime.gates' no FORGE.md fecha a wave sem executar nada. O waves.json registra 'executed:NO-GATES' — auditavel, e o gate w131 assere que esse registro difere do de gate verde, para que 'nao havia gate' nunca se confunda com 'passou'. Fechar de vez exigiria obrigar todo projeto adotante a declarar ao menos um gate, o que e decisao de produto: e a mesma classe do SRF-00 (opt-out por omissao), um nivel acima.
- **LDG-0016** [open] (P2) — Suite: 11 gates criam repo git em /tmp e o gc em background derruba o rm -rf do fixture
  Corrigido no run-all.sh via GIT_CONFIG_COUNT (gc.auto/maintenance.auto/gc.autoDetach = 0) com assercao no w80, mas a causa raiz merece nota: 'git commit' dispara 'git gc --auto' em background, que continua escrevendo em .git depois do commit retornar. O 'rm -rf' do fixture corre contra esse processo e, quando perde, mata o gate DEPOIS de todas as assercoes passarem. Nao reproduz no macOS (APFS+timing), reproduz no CI Linux (overlayfs). Assinatura identica a do SIGPIPE ja corrigido: gate verde isolado, vermelho na suite, gates DIFERENTES a cada execucao — o que significa que parte das 'falhas fantasma' historicas pode ter sido esta, e nao SIGPIPE. Se voltar a aparecer, checar tambem 'git maintenance' e processos filhos do gate.
- **LDG-0018** [open] (P2) — route-scan: cobertura de dialeto conhecida e incompleta (caixa do [controller], Go, Python, tabela de policy sem ancora)
  Quatro lacunas levantadas na revisao do gate w132 e deliberadamente NAO fechadas na correcao, porque nenhuma delas produz path inventado — todas produzem ausencia ou ruido, que sao visiveis. (1) O token [controller] do .NET vira o nome da classe com a caixa original ('/api/Orders'), e o contrato costuma escrever minusculo; como o roteamento do ASP.NET e case-insensitive, o endpoint existe e o SUR-01 acusaria por diferenca de caixa. Normalizar caixa em normalizePath e' tentador e ERRADO: Spring e Express sao case-sensitive, e o mesmo normalizador serve os dois. A saida provavel e' case-fold por dialeto, no indexador, nao no normalizador. (2) .py e .go estao em ROUTE_EXTS e nao tem indexador nenhum — arquivo lido e ignorado, sem diagnostico. Ou implementa, ou tira da lista. (3) fromPolicyTable varre TODA tabela markdown do spec cuja primeira celula case 'VERB /path', sem ancora de secao: uma tabela de 'APIs de terceiros CONSUMIDAS' entra na superficie declarada e o SUR-01 bloqueia porque o codigo, corretamente, nao expoe aquilo. fromChecklist ancora num heading; fromPolicyTable deveria ancorar tambem. (4) Nest so resolve @Controller literal e um controller por arquivo.
- **LDG-0019** [open] (P2) — route-scan: layouts dominantes (vertical slice .NET, Express multi-arquivo) resolvem zero rotas por conservadorismo correto
  Consequencia deliberada de duas correcoes do PR #40, medida na segunda rodada de revisao. (1) VERTICAL SLICE .NET: o convenio em que cada feature define 'public static void MapEndpoints(this RouteGroupBuilder g)' produz producer-ambiguous em 100% das invocacoes e ZERO rotas, porque com N definicoes homonimas o scanner nao sabe qual delas a invocacao alcanca. Escolher uma (o comportamento anterior) emitia rota cruzada entre modulos e perdia a rota real, entao reportar e' a resposta certa — mas o custo de cobertura e' total nesse layout. Desambiguar de verdade exige resolver namespace/using do C#, que esta fora do alcance de um scanner por regex. (2) EXPRESS MULTI-ARQUIVO: 'mounts' e' local ao indexJsHttp e portanto POR ARQUIVO; o layout canonico (routers em arquivos separados, app.use no app.js) so gera router-mount-unknown. A simetria que falta e' promover mounts ao indice global e resolve-los na passa 2, como ja e' feito com os produtores .NET — isso e' trabalho de tamanho conhecido e fecharia o caso. AMBOS interagem com LDG-0017: enquanto o SUR-01 nao se abstiver na presenca de unresolved, esses layouts reprovariam por inteiro se o gate fosse fiado hoje.
- **LDG-0021** [open] (P2) — Prova de mutacao mede as regras que existem, nao a superficie de entrada que elas deixam passar
  Limite estrutural exposto pelas CINCO rodadas de revisao do PR #40, e vale registrar porque e' generalizavel a todo gate deste harness. As provas de mutacao do w132 (15) sao fortes no que fazem: mutar a regra que implementa cada correcao faz o caso reprovar, com controle, recontrole, mutador que falha se o alvo textual sumir e checksum do lib de origem. Mas elas medem apenas as regras JA ESCRITAS. NENHUM dos ~25 defeitos das cinco rodadas foi encontrado por mutacao — todos nasceram de alguem construir uma ENTRADA que o reconhecedor nao previa (produtor homonimo, subgrupo dentro de produtor, interpolacao no meio do path, data class sem corpo, 'where T : class', DSL kotlinx.html com nome de verbo, literal com '//' ou chave, emoji dessincronizando code point x UTF-16, verbatim C# terminado em barra, raw string do Kotlin com DSL de exemplo, @Controller sem flag global). E' a mesma forma do defeito que o proprio modulo descreve para o 'unresolved': o que o regex nao reconhece e' invisivel por construcao. PARCIALMENTE ATACADO nesta entrega: (a) o caso [41] virou propriedade POSICIONAL (code[i] e struct[i] so podem ser o original ou espaco; newline nunca some; struct e' sempre mais mascarada que code) medida sobre corpus de DIALETO (.cs/.kt/.java/.ts com comentario de bloco, verbatim multilinha, raw string, emoji), e nao mais sobre os .mjs do proprio harness — a primeira versao media o harness em vez dos dialetos e com a propriedade mais fraca possivel (comprimento); (b) o caso [43] e' PARAMETRICO: 'duas unidades de roteamento no mesmo arquivo' testado nos seis dialetos de uma vez, porque essa classe unica foi descoberta TRES vezes por tres revisoes diferentes (.NET atributos, Spring, e Nest ainda vivo na 5a rodada). O QUE FALTA: fuzzing guiado por gramatica de cada dialeto, e corpus de arquivos REAIS dos repos adotantes — que e' o que de fato pegaria idiomas como o kotlinx.html. Enquanto nao existir, a cobertura de dialeto e' hipotese, nao fato, o que reforca LDG-0017.
- **LDG-0027** [open] (P3/LOW) — Grafo de código é cego no dogfood: o motor do harness vive em bin/ e template/.forge/, ambos pulados
  SKIP_DIRS pula 'bin' e '.forge', e .sh não está no mapa LANG — então /forge:codegraph neste repositório enxerga 19 nós (16 fixtures de tests/fixtures/**, 3 de tools/) e nenhum dos 107 arquivos de template/.forge/scripts/** nem bin/forge.mjs. Pular .forge/ é correto por design (num consumidor é o harness instalado, não o produto); o problema é específico do repo que PRODUZ o template. Consequência: /forge:onboard, /forge:c4 e /forge:impact não têm valor aqui, e a auto-avaliação do harness sobre si mesmo não cobre o próprio motor. Saídas possíveis: raiz de varredura configurável no FORGE.md, ou tratar template/.forge/ como código-fonte quando o package.json declara o pacote forge-harness. Distinto do LDG-0026, que afeta qualquer projeto Node.
- **LDG-0014** [open] (P3) — spec-verify.sh mantem copia propria de get_runtime/run_check em vez de usar lib/forge-runtime.sh
  A Onda B extraiu a leitura do bloco runtime: do FORGE.md e a execucao com teto de tempo para lib/forge-runtime.sh, porque o run-gates.sh precisava delas e a logica so existia inline no spec-verify.sh. O spec-verify NAO foi migrado para a lib nesta onda — decisao de escopo, para nao arriscar o caminho de /forge:verify no mesmo PR. Enquanto nao migrar, ha duas copias que podem divergir: o skip-com-WARN de gate declarado e inexistente ficou apenas no spec-verify (o run-gates.sh REPROVA nesse caso, que e o comportamento correto pela norma da casa). Migrar e apagar a copia.
- **LDG-0020** [open] (P3) — route-scan: composicao e' por CAMINHO, e DAG denso de produtores custa exponencial antes do MAX_DEPTH
  O corte de ciclo (Set no caminho) resolve recursao mutua, e o diagnostico chain-too-deep foi colapsado por owner para nao alocar um objeto por caminho truncado — o que derrubou o consumo de memoria. Mas a travessia continua sendo por caminho, nao memoizada: num DAG acíclico e denso (produtores P0..P29, cada Pi invocando Pi+1..Pi+B) o custo cresce com B^MAX_DEPTH. Medicao da revisao antes do colapso do diagnostico: B=4 dava 420ms/222MB, B=5 dava 12,9s/1,3GB, B=6 estourava a heap. Registrars reais formam arvore, nao DAG denso, entao isto e' robustez e nao defeito de campo — mas a saida existe e e' barata: memoizar por (owner, prefixo) em vez de recompor cada caminho, ja que o resultado so depende desse par.

_Encerrados: 7 (resolved 6 · wont-fix 1)_

## Bugs conhecidos

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
