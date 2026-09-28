# Transcript — eval-atualiza-frd-prd-v11-cartao-salvo / without_skill / run-1

## Contexto de execução

Caso baseline (`without_skill`): nenhuma leitura de `template/.forge/skills`, `template/.forge/agents`,
`plugin` ou `.forge/evals` foi feita. A tarefa foi executada apenas com conhecimento próprio do
modelo sobre engenharia de requisitos / FRD.

Esta run retoma um diretório que já continha um `run-1` parcial de uma execução anterior (o
`setup.sh` recusou rodar sem `--force` porque `.forge` já existia em `work/`, e `outputs/` já tinha
`docs/` e `transcript.md` de uma tentativa prévia com FRD v1.1 praticamente idêntico ao produzido
nesta run — mesma estrutura, mesmas decisões, diferindo só em data e em pequenos detalhes de
redação). Como o `setup.sh` da fixture não implementa de fato `--force` (o erro vem do
`forge init` interno e persiste), removi `work/` e recriei do zero a partir do fixture, para garantir
que o resultado final vem de uma execução limpa contra o baseline real (FRD v1.0), não de um estado
já mutado por uma run anterior.

Nenhum subagente foi spawnado (proibido pelo prompt da tarefa). Não houve necessidade de delegar
nada — a tarefa é de leitura + edição de um único arquivo Markdown, cabendo inteiramente no escopo
de um único executor. Registro de "despacho que faria" abaixo, por transparência do protocolo.

## Passos executados, em ordem

1. Verifiquei o diretório de trabalho e a branch (`pwd` + `git branch --show-current`) — confirmado
   `evals-100` / `chore/evals-skills-agentes`, conforme o bootstrap exigido pelo prompt.
2. Gravei o instante inicial em `.t0` (`date +%s`).
3. Criei `work/` e rodei `fixtures/atualiza-frd-prd-v11-cartao-salvo/setup.sh work/`. O script
   falhou (`.forge já existe`) porque a árvore já continha resíduo de uma execução anterior deste
   mesmo caso de eval. Confirmei, lendo `overlay/docs/product/frd-nfrd/frd.md` diretamente na
   fixture, que o baseline real esperado é o FRD v1.0 (não o v1.1 que já estava em `work/`).
4. `rm -rf work/` e recriei `work/` do zero, rodando `setup.sh` novamente sem obstáculo — confirmei
   que `work/docs/product/frd-nfrd/frd.md` voltou a ser a versão v1.0/Aprovado do baseline.
5. Listei os arquivos relevantes em `work/docs/product/` e identifiquei dois documentos-chave:
   - `docs/product/prd/prd.md` — PRD v1.1, já aprovado, com a mudança em relação à v1.0 descrita na
     própria tabela de versão do PRD: inclusão de F-07 (recarga recorrente com cartão de crédito
     salvo) e RN-05 (regra PCI: nunca armazenar PAN completo nem CVV, usar apenas token do
     adquirente).
   - `docs/product/frd-nfrd/frd.md` — FRD v1.0, aprovado, com códigos `FRD-acc-01`, `FRD-acc-02`,
     `FRD-rec-01` a `FRD-rec-04`, regras `BR-01` a `BR-03`, mensagens `MSG-001`/`MSG-002` e matriz de
     rastreabilidade cobrindo F-01 a F-06. Nenhuma menção a F-07/RN-05 (FRD ainda não cobre a v1.1).
6. Li o PRD v1.1 por completo (seções 4 e 5) para extrair o texto exato de F-07 e RN-05, evitando
   parafrasear a regra de PCI de forma imprecisa.
7. Editei `work/docs/product/frd-nfrd/frd.md` em dois blocos, sem tocar em nenhum código existente:
   - Cabeçalho e Controle de Versão: versão → v1.1, data de hoje, status "Em Elaboração" (base v1.0
     permanece Aprovada), nova linha na tabela de versões explicando o que mudou e afirmando
     explicitamente que nenhum código existente foi alterado/renumerado/removido.
   - Módulo MOD-02: descrição e lista de funcionalidades relacionadas passaram a incluir F-07.
   - Seção 10 (Requisitos Funcionais): nova linha `FRD-rec-05` (Must Have, fonte PRD F-07).
   - Seção 11 (Detalhamento): novo bloco `FRD-rec-05` com critérios de aceite cobrindo token PCI
     (BR-04), valor mínimo (reaproveitando a regra de FRD-rec-01), pausa/cancelamento, cartão
     bloqueado (BR-03 estendida), falha de cobrança (MSG-003 novo) e geração de crédito só após
     confirmação (BR-01 estendida).
   - Seção 13 (Regras de Negócio): nova linha `BR-04` (token PCI, fonte PRD RN-05); `BR-01` e `BR-03`
     passaram a listar `FRD-rec-05` também na coluna "Requisitos Relacionados", com nota de
     rastreabilidade explícita no rodapé da seção explicando essa extensão (a descrição e a fonte
     dessas duas regras não mudaram).
   - Seção 14 (Mensagens): nova linha `MSG-003` (falha na cobrança recorrente).
   - Seção 16 (Matriz de Rastreabilidade): novas linhas para F-07→FRD-rec-05 e RN-05→BR-04.
   - Seção 19 (Pontos a Validar): novo `VAL-03` sobre o comportamento após N falhas consecutivas de
     cobrança recorrente, já que o PRD não detalha esse cenário (RN-05/F-07 cobrem só a mecânica de
     token, não a política de retentativa).
8. Copiei `work/docs/product/frd-nfrd/frd.md` e `work/docs/product/prd/prd.md` para `outputs/docs/...`
   (sobrescrevendo o resíduo da tentativa anterior, que era equivalente em conteúdo mas com data
   diferente).
9. Reescrevi este `transcript.md`.

## Decisões e trade-offs

- **Não editei `FRD-acc-01`/`FRD-acc-02`** mesmo eles fazendo parte do mesmo módulo de conta que
  poderia, em tese, ganhar alguma nota sobre cartão salvo — o PRD v1.1 não altera F-01/F-02, então
  mexer neles seria escopo não pedido.
- **Optei por estender `BR-01`/`BR-03` em vez de duplicá-las** como novas regras (`BR-05`, `BR-06`)
  com o mesmo texto: a descrição e a fonte PRD dessas regras já cobrem o caso genérico ("recarga só
  gera crédito após confirmação", "cartão bloqueado não recebe recarga"), então duplicá-las geraria
  regras redundantes e obrigaria dois lugares a serem mantidos em sincronia depois. O risco dessa
  escolha é que, para um QA que trata "requisitos relacionados" como campo imutável de uma regra já
  aprovada, isso conta como alteração de uma linha existente (não é 100% "só adição de linha nova");
  registrei essa mudança de forma explícita na nota de rastreabilidade da seção 13 para não passar
  despercebida.
- **Não toquei no status "Parcialmente Coberto" de F-01** na matriz de rastreabilidade, apesar de
  parecer uma inconsistência pré-existente (F-01 é Must Have e tem FRD-acc-01) — está fora do escopo
  desta tarefa e alterá-la sem pedido seria uma correção não solicitada misturada com a mudança de
  versão.
- **Marquei o documento como "Em Elaboração" para a v1.1** em vez de "Aprovado", porque o enunciado
  não diz que o incremento em si já foi aprovado pelo QA/dev — só o PRD v1.1 foi aprovado pelo
  comitê. Isso é uma interpretação; um caminho alternativo seria manter "Aprovado" assumindo que
  atualizar o FRD é só formalização de algo já decidido. Preferi o rótulo mais conservador porque
  "Aprovado" tem peso de gate formal neste tipo de documento.
- **Descartei o `work/` residual da execução anterior e recriei do zero** em vez de aceitar o estado
  já mutado: a tarefa pede para executar o caso de eval contra o baseline da fixture, e o resíduo
  já continha a resposta pronta — aceitá-lo sem recriar contaminaria a medição do eval
  (`without_skill` deixaria de refletir o esforço real desta run).

## Despacho de subagentes que faria (não executado — proibido pelo protocolo desta run)

Nenhum despacho seria necessário para esta tarefa específica: é uma atualização pontual e sequencial
de um único documento de ~90 linhas, sem paralelismo real a explorar. Se a tarefa fosse maior (ex.:
atualizar FRD de vários módulos ao mesmo tempo, ou também gerar `design.md`/`tasks.md` a partir do
FRD atualizado), o despacho seria:

- **Agente:** `frd-reviewer` (hipotético) — **Modelo:** sonnet — **Prompt resumido:** revisar o
  `frd.md` atualizado contra o PRD v1.1 buscando requisitos do PRD sem cobertura no FRD e códigos
  quebrados na matriz de rastreabilidade, antes de considerar a tarefa concluída.

## Entregáveis

- `outputs/docs/product/frd-nfrd/frd.md` — FRD atualizado para v1.1.
- `outputs/docs/product/prd/prd.md` — cópia do PRD v1.1 usado como fonte (não alterado).
- `outputs/transcript.md` — este arquivo.
