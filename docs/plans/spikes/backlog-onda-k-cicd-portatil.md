# Onda K — mecânica de CI/CD portátil, sem depender do GitHub Actions

Especificação implementável. Data: 2026-09-07. Revisão 5, depois do veredito da revisão 4 — que confirmou os dois bloqueadores da revisão 3 como fechados por medição do revisor, sem reincidência de nenhum bloqueador anterior, e achou dois novos, os dois na fronteira entre o caso 4 da seção 4(f) e o recibo de tamanho fixo da seção 5.4. A mudança de método da invariante 19 do plano-mestre continua valendo: a spec declara propriedade e contrafactual, e só prescreve comando exato quando o executou e colou a saída. As respostas à revisão 1 estão na seção 17, as da revisão 2 na seção 18, as da revisão 3 na seção 19, a varredura de comandos prescritos que a invariante 19 obriga está na seção 20, e as respostas à revisão 4 na seção 21. Branch de medição: `fix/strix-achados-medios`. Plano-mestre: `docs/plans/2026-09-07-backlog-zero.md`, seção "Onda K", mais as seções "Invariantes" e "Definição de pronto do plano inteiro", que valem aqui sem exceção.

Fecha `LDG-0160` pelo canal real (execução da fase, não linha de aviso do doctor) e cria a mecânica de deploy que hoje só existe como prosa em markdown.

---

## 1. Sumário executivo

O harness descreve um pipeline de deploy de dez gates em markdown e não tem uma linha de script que o execute. O seletor `run-gates.sh --phase pre-deploy|post-deploy` existe, funciona quando invocado à mão e não tem chamador de produção nenhum — medido e reproduzido abaixo. Esta onda entrega o executor: `lib/deploy-common.sh` (mecânica, vocabulário de quatro estados de estágio, treze estágios com denominador triplo), `deploy.sh` (a porta, que invoca as duas fases pelo canal real), `lib/timeout.sh` (o teto de tempo, casa neutra para código novo), dois adaptadores de provedor mais o `local` (`github-actions`, `cloud-build`, `local`), o manifesto `deploy-run/v1` no molde do `strix-preflight/v1`, o `/forge:deploy-wave` reescrito como interface humana sobre o script, e um gate de vinte e sete blocos que prova tudo isso com stubs, denominador triplo e seis mutações.

A revisão 3 confirmou os cinco bloqueadores da revisão 2 como resolvidos e achou dois novos — o inventário do `README.md` que a onda envelhece e que só o `w200` afirma, e o rc 2 de erro de uso contra as guardas de flag que terminam em `exit 1` —, ambos fechados na seção 19. A revisão 4 confirmou esses dois por medição própria e achou os dois últimos, ambos na fronteira entre o caso 4 da seção 4(f) e o recibo: o motivo da isenção era mandado para um manifesto de tamanho fixo que não tem campo para ele, e a regra de `skipped-declared` do `[15]` contradizia o desfecho verde do mesmo caso 4 — os dois estão fechados na seção 21, o primeiro tirando o motivo do recibo em vez de esticá-lo, o segundo declarando uma fonte de motivo por classe de estágio. A invariante 19 continua governando: a seção 20 varre os 25 primitivos que a spec prescreve, executa 14 com a saída colada, reancora 5 e converte 6 em propriedade mais contrafactual, e remede os comandos de medição — três dos quais mudaram de resultado desde a revisão 3. O mais caro deles é de fiação e não de redação: `run-gates.sh --phase` tem guarda de vacuidade própria, e como zero consumidor declara `phase:` hoje, a chamada de fase que esta onda cria volta FAIL em todo projeto real. A seção 4(f) enumera os sete desfechos observáveis dessa chamada, medidos um a um, e a seção 5.2 mapeia cada um em estado de estágio.

O trabalho não é extração de um padrão existente: medi e não existe padrão a extrair. É criação de padrão, e por isso a onda exige piloto num consumidor real antes de virar contrato do template (seção 13).

---

## 2. O defeito reproduzido — comandos e saída real

### 2.1 O único chamador de produção de `run-gates.sh` nunca passa `--phase`

Reprodução pelo canal real (não por leitura do código): um `FORGE_ROOT` de fixture em `$TMPDIR` com um `run-gates.sh` STUB que registra o `argv` recebido, e o fechamento de wave — o único chamador de produção — invocado de verdade.

```
$ FORGE_ROOT="$T" bash template/.forge/scripts/wave-ops.sh close chg-x W1
  fixture: passed
OK
OK close — W1 fechada (gate: executed:OK (1 gate(s)))

$ cat "$T/argv.log"
chg-x W1

$ grep -c -- '--phase' "$T/argv.log"
0
```

O `argv` observado é `chg-x W1`. Nenhuma `--phase`. Confere com `template/.forge/scripts/wave-ops.sh:161`, que invoca `bash "$FORGE_ROOT/.forge/scripts/run-gates.sh" "$change_id" "$wave_id"` e nada mais.

### 2.2 Gate declarado com fase de deploy não é executado por caminho nenhum — e a wave fecha verde

A revisão 1 reproduziu o cenário e apontou, com razão, que a receita publicada estava incompleta: `wave-ops.sh close` exige `waves.json` (`wave-ops.sh:137`) e opera `progress.json`, e o `FORGE.md` do fixture só é lido por `lib/gate-phase.mjs` se o bloco `runtime:` estiver dentro do frontmatter `---`…`---` (`gate-phase.mjs:43`, `frontmatterOf`). Sem os três detalhes a reprodução devolve `NO-GATES`, não a saída publicada — medi o engano e o corrigi. A receita completa, verificada nesta rodada, é a de baixo.

**Fixture, na íntegra** (executado com `cwd` DENTRO da fixture, nunca a partir da árvore do repositório):

```
T="$(mktemp -d "${TMPDIR:-/tmp}/onda-k-22.XXXXXX")"; T="$(cd "$T" && pwd -P)"
mkdir -p "$T/.forge/specs/active/chg-y"
cp -R template/.forge/scripts "$T/.forge/scripts"
cat > "$T/.forge/FORGE.md" <<'EOF'
---
runtime:
  gates:
    - name: check-src
      phase: source
    - name: check-image-digest
      phase: pre-deploy
    - name: check-rollout-health
      phase: post-deploy
---
# fixture
EOF
for g in check-src check-image-digest check-rollout-health; do
  printf '#!/usr/bin/env bash\necho %s >> "%s/executed.log"\nexit 0\n' "$g" "$T" > "$T/.forge/scripts/$g.sh"
  chmod +x "$T/.forge/scripts/$g.sh"
done
printf '{"change_id":"chg-y","waves":[{"id":"W1","status":"open","stories":[]}]}\n' > "$T/.forge/specs/active/chg-y/waves.json"
printf '{"change_id":"chg-y","current_wave":"W1","stories":{}}\n' > "$T/.forge/specs/active/chg-y/progress.json"
: > "$T/executed.log"; cd "$T"
```

**Saída observada:**

```
$ node "$T/.forge/scripts/lib/gate-phase.mjs" entries "$T"
check-src	source
check-image-digest	pre-deploy
check-rollout-health	post-deploy

$ FORGE_ROOT="$T" bash "$T/.forge/scripts/wave-ops.sh" close chg-y W1
  check-src: passed (log: /tmp/forge-gates.h7DPVY/check-src.log)
OK
OK close — W1 fechada (gate: executed:OK (1 gate(s)))

$ cat "$T/executed.log"
check-src

$ FORGE_ROOT="$T" bash "$T/.forge/scripts/run-gates.sh" chg-y --phase pre-deploy
OK run-gates-phase-pre-deploy/universo — 1 gate(s) examinado(s) (change:chg-y,phase:pre-deploy)
  check-image-digest: passed (log: /tmp/forge-gates.SuQCi9/check-image-digest.log)
OK

$ cat "$T/executed.log"
check-src
check-image-digest
```

Três gates declarados, um executado pelo caminho de produção, dois nunca alcançados — e a wave fecha `executed:OK (1 gate(s))`, verde. O motor de fase funciona: ele executa o gate `pre-deploy` no instante em que alguém o invoca à mão. **O defeito é ausência de executor, não defeito de função** — e é exatamente por isso que um teste unitário sobre `forge_runtime_gates_phase` nasceria verde e não diria nada (invariante 7 do plano).

**Custo de execução da reprodução, três execuções na mesma máquina** (o plano-mestre exige remedir custo, porque número medido sob carga mente): 2508 ms, 1217 ms, 1223 ms — a primeira paga o cache frio do `cp -R` da árvore de scripts. O custo do cenário é de ordem de um segundo, e nenhuma decisão desta spec repousa em custo de execução (seção 17, resposta à regra 5).

Denominador que este cenário fixa para o gate: **3 gates declarados, 1 executado, 2 órfãos de execução**.

### 2.3 Grep de chamadores, para fechar a afirmação negativa

```
$ grep -rn -- "--phase" template/ bin/ installer/ .github/ plugin/ | grep -v 'run-gates.sh:' | grep -v 'forge-runtime.sh:'
$ echo $?
1
```

Zero ocorrências fora da própria definição da flag e do comentário do leitor. Confirma o registro de `LDG-0160`.

---

## 3. Estado medido do template — conferido, não aceito

Cada item do plano-mestre foi remedido nesta sessão.

**(1) Zero abstração de provedor — confirmado.**

```
$ grep -rlEi 'gitlab|jenkins|circleci|azure-pipelines|buildkite|drone' template/ | wc -l
0
```

**(2) `staging.yml` é esqueleto — confirmado.** O único job de `template/github/workflows/staging.yml` roda três `echo`. A mecânica está delegada ao consumidor, para ser escrita dentro do YAML do Actions, uma vez por repositório.

**(3) `red-first.yml` é real e a dependência é de desenho — confirmado.** O cabeçalho do arquivo declara em letra que o valor está em reexecutar o replay "num runner que o autor do PR não controla". Isso é propriedade do ambiente, não do script.

**(4) `/forge:deploy-wave` é prosa — confirmado e quantificado.** `template/.forge/agents/coding/deploy-orchestrator.md` tem 383 linhas, **14 blocos ` ```bash `** e **134 linhas de shell dentro deles**, com `kubectl` em 10 ocorrências, `helm` em 6, `gh` em 4, `docker` em 3, `cosign` em 2, `trivy` em 1, `git tag` e `git push` em 2 cada. O passo 1 de `template/.forge/commands/coding/deploy-wave.md` é literalmente `gh workflow run build-image.yml`.

**(5) O seletor de fase não tem executor — reproduzido na seção 2.**

**Medição adicional, que muda o desenho:** o acoplamento ao `gh` no template inteiro está em **9 arquivos** (`grep -rlE '(^|[^a-z])gh (workflow|run|pr|repo|api|issue) ' template/`), e no `deploy-orchestrator.md` ele toca **uma** das onze fases. O provedor não permeia o pipeline — ele constrói e publica a imagem, e nada mais. Isso é o que torna possível uma interface de adaptador pequena e honesta (seção 5.3), em vez de um adaptador por pipeline.

**Medição adicional 2, que decide a seção 5.1:** `template/.forge/scripts/pentest-ops.sh` **não faz `source` de nada** (`grep -nE '^\s*(\.|source) ' devolve rc 1`) e **não tem `SCRIPT_DIR`** (`grep -n 'SCRIPT_DIR'` devolve rc 1). Ele é, hoje, um arquivo autocontido — e isso não é acidente de estilo, é o que permite ao `w206` executá-lo como cópia nua.

---

## 4. Decisões fechadas

Cada decisão traz a alternativa descartada e a medição que decidiu.

### (a) O segundo provedor é **Google Cloud Build** (`lib/ci/cloud-build.sh`)

**Por quê.** É o único segundo provedor com alvo real medido no ecossistema: `azim-crm` tem `platform/cloudbuild/build-service.yaml`, tem `platform/helm/`, tem o harness instalado (`.forge/forge.yaml: template_version: 0.1.0-rc24`) e **não** tem `scripts/deploy.sh`. E o vocabulário dele estressa a interface em todos os eixos que importam: `gcloud builds submit --async` submete *e já é* o build (contra `gh workflow run`, que só enfileira e exige um segundo comando para descobrir o `databaseId`); o identificador é UUID (contra inteiro); o estado é `SUCCESS`/`FAILURE`/`TIMEOUT`/`CANCELLED` num campo só (contra `status` + `conclusion` em dois); e não existe equivalente de `gh run watch --exit-status` — o wait é polling sobre `gcloud builds describe`. Uma interface que aguente os dois não é o primeiro provedor com nome genérico.

**Descartados.** GitLab CI e Jenkins: nenhum dos 13 repositórios com `.forge` em `~/Documents/projects` os usa, e adaptador sem alvo real é ficção que ninguém do time pode falsear — ele passaria a existir mantido por simetria e apodreceria em silêncio. AWS CodeBuild: existe no `axis-go-cloud` (`deploy/*/buildspec.*.yaml`, medido em `deploy/staging`, `deploy/staging-cielo-lambda` e mais oito diretórios), mas serve o fluxo Lambda/CodePipeline, não o fluxo Helm de imagem que esta onda cobre; adotá-lo misturaria dois fluxos e a comparação não estressaria a interface no eixo certo.

**Fronteira declarada:** o adaptador `cloud-build` é exercitado no gate por **stub de `gcloud`** no `PATH` (mesma técnica que o `w206` usa com `strix` e `docker`). Isso prova que ele fala o dialeto certo; **não** prova que o GCP responde. Quem prova isso é o piloto (seção 13).

### (b) A interface do adaptador tem **seis funções** e nada mais

```
ci_name                                        # stdout: identificador estável do provedor
ci_available                                   # rc 0 disponível | 1 ausente | 2 inconclusivo
ci_build_submit  <modulo> <sha> <registry>     # stdout: run_ref opaco;  rc 0 | 1 | 2
ci_build_wait    <run_ref> <timeout_s>         #                        rc 0 | 1 | 2
ci_build_digest  <modulo> <sha> <registry>     # stdout: sha256:<64hex>; rc 0 | 1 | 2
ci_run_url       <run_ref>                     # stdout: URL ou vazio;   rc 0 sempre
```

`rc 2` é o terceiro estado em todas elas: "não consegui saber" nunca colapsa em "está tudo bem" nem em "falhou".

**Por que exatamente essas.** O que é específico de provedor no pipeline é o que constrói e publica a imagem, mais a identidade do run para o recibo de auditoria. `trivy`, `cosign`, `helm` e `kubectl` são CLIs de ferramenta e são idênticas sob qualquer provedor — a medição da seção 3 mostra que elas somam 19 das 23 invocações do orchestrator, contra 4 do `gh`. Colocá-las atrás do adaptador criaria seis pontos de divergência entre provedores no lugar de um.

**Descartado:** adaptador "gordo" com `ci_deploy`, que entrega o pipeline inteiro por provedor. Isso reintroduz a mecânica duplicada por provedor — o defeito que a onda existe para remover — e não corresponde ao que os provedores de fato fazem: no `axis-go-cloud`, `_template-cd-helm-deploy.yml` roda `helm lint`, `helm upgrade --install`, `kubectl rollout status`, `kubectl get events` e `kubectl port-forward` **dentro** do runner, em 61 linhas de shell embutidas num YAML de 171 linhas. É a mesma mecânica, com outro invólucro. Movê-la para o script é justamente a entrega.

### (c) Provedor indisponível → **recusa**. Duas condições distintas, dois códigos distintos, e a regra de manifesto declarada para cada uma

A revisão 1 reprovou este item por contradição real, e ela procede: a redação anterior dizia rc 4 com manifesto na seção 4(c), rc 2 sem manifesto na seção 5.3, e as duas cobriam a mesma frase — "não encontrei o provedor". São **duas** condições, e colapsá-las é justamente o pecado da invariante 2 aplicado ao próprio texto da spec. A separação normativa:

| Condição | O que aconteceu | rc | Manifesto |
|---|---|---|---|
| `runtime.deploy` ausente e módulo pedido **explicitamente** | o projeto não declarou nada e alguém pediu um deploy nominal | **2** | não gravado |
| `runtime.deploy.ci_provider` ausente ou vazio | configuração incompleta | **2** | não gravado |
| `ci_provider` declarado, **arquivo do adaptador não existe** (ex.: `gitlab`) | erro de configuração — o harness não tem esse adaptador | **2** | não gravado, e a recusa **nomeia os adaptadores disponíveis** |
| adaptador presente, `ci_available` devolve **rc 1** (CLI ausente no PATH) | ambiente de execução sem a ferramenta | **4** | **gravado**, `ci_provider_available: no`, `verdict: inconclusive` |
| adaptador presente, `ci_available` devolve **rc 2** (não consegui saber) | ambiente indeterminado | **4** | **gravado**, `ci_provider_available: unknown`, `verdict: inconclusive` |
| `runtime.deploy` ausente e invocação `--from-config` (o invólucro do CI) | não há nada declarado a implantar | **0** | não gravado, com a linha de pulo declarado (seção 5.3) |
| adaptador resolvido, mas **a fase pedida tem universo vazio** e o projeto não declarou isenção | o `run-gates.sh --phase` recusou por vacuidade — nada foi examinado | **4** | **gravado**, com o estágio de fase em `inconclusive` e a contagem do universo em `gates_pre_deploy`/`gates_post_deploy` (tabela completa na seção 4(f)) |

O corte é entre **erro de configuração do projeto** (rc 2, sem recibo: uma digitação não é uma execução de deploy) e **execução que não pôde ocorrer no ambiente** (rc 4, com recibo: alguém tentou implantar de verdade e o recibo é a prova de sob que condições não deu). Em nenhuma das **sete** linhas `helm` ou `kubectl` é tocado — inclusive na do universo vazio, que é onde a garantia mais importa, porque é o desfecho que todo consumidor real encontra hoje.

**Por quê recusar em vez de degradar.** É a invariante 2 do plano aplicada ao provedor: "não consegui executar" viraria "executei de outro jeito", e o manifesto passaria a atestar um build feito num ambiente que ninguém auditou — a máquina do autor, que é exatamente o vetor que o `red-first.yml` existe para fechar. E é o que a rule `testing/gate-delivery-channel.md` já exige em letra para as fases `pre-deploy`/`post-deploy`: "um gate que não pôde rodar por falta de credencial não pode ser reportado como aprovado, e também não pode bloquear quem não tem credencial na máquina".

**A porta explícita existe e é declarada, nunca inferida:** `runtime.deploy.ci_provider: local` seleciona `lib/ci/local.sh`, que constrói com `docker buildx build --push` na máquina de quem chama e grava `ci_provider: local` no manifesto. Executar local é uma escolha registrada do projeto, não um fallback silencioso.

**Descartado:** fallback automático para `local` quando `gh` não está no `PATH`. Descartado pelo parágrafo acima — e porque a degradação automática é indistinguível, no log, de um deploy normal.

### (d) Consumidores com `.github/workflows` instalado: a onda **não toca em nenhum**

Censo dos 13 repositórios com `.forge` em `~/Documents/projects`:

| Medição | Valor |
|---|---|
| Com `.github/workflows/staging.yml` instalado | **10 de 13** |
| Desses, byte-idênticos ao template (`cmp`) | **8** |
| Divergentes (customizados pelo projeto) | **2** — `Axis.PadSimulator`, `azim-crm` |
| Com `.github/workflows/red-first.yml` | **0 de 13** |
| Declarando `phase:` no `FORGE.md` | **0 de 13** |
| Com tag `deploy-*` no histórico (uso real do `/forge:deploy-wave`) | **0** em todos os repositórios com `platform/helm/` (`axis-go-cloud`, `azim-crm`, `prospera`, `travessias`, `vellus-enterprise-ai-platform`) |

Três consequências, todas fechadas aqui:

1. **`.github/workflows` só é escrito no `install`, nunca no `update`.** `STAGING_YML`/`RED_FIRST_YML` aparecem em `bin/forge.mjs` só nas linhas 41-42 e 835-843, dentro do caminho de instalação, e sempre sob `if (!existsSync(dst))` — reconferido nesta rodada. Consumidor já instalado fica intocado. **Mas instalação nova recebe o arquivo do template**, e é por isso que o invólucro do `staging.yml` não pode ser uma linha de conveniência: ele é o comportamento padrão de todo `forge init` futuro. O desenho que satisfaz as duas pontas está na seção 5.3, e a asserção que o trava é a `[19]`.
2. **Zero adoção de `phase:` instalada.** A retrocompatibilidade do eixo de fase é vacuamente segura: nenhum consumidor declara fase hoje, então o executor novo não pode mudar o comportamento de nenhuma instalação existente. Isso não dispensa o golden do `w171` (seção 9.2) — dispensa o medo.
3. **`.forge/scripts/` é maquinaria sobrescrita por `update`.** `scripts` está em `MACHINERY_DIRS` (`bin/forge.mjs:307`) e fora de `ENRICHABLE_DIRS` (`bin/forge.mjs:352`), então `deploy.sh` e `lib/ci/*.sh` chegam a todo consumidor no próximo `forge update` e sobrescrevem qualquer cópia local de mesmo path. Arquivo **extra** do consumidor sobrevive: a poda é curada por tombstone (`bin/forge.mjs:665-675`), não é "tudo fora do template". Contrato que a doc precisa declarar em voz alta: **`lib/ci/` é diretório reservado do template**; adaptador autoral de projeto mora em `.forge/custom/scripts/lib/ci/<nome>.sh` e é apontado por `runtime.deploy.ci_provider_path`, que aceita caminho relativo à raiz do projeto.

### (e) Como o gate prova que a fase foi **invocada**, sem deploy real

O defeito é de fiação, então o teste tem de exercer o caminho do gatilho ao efeito (invariante 7). O desenho:

- Todos os binários externos (`gh`, `gcloud`, `docker`, `helm`, `kubectl`, `trivy`, `cosign`, `git`) são **stubs** num `PATH` dedicado, montado como espelho de `/usr/bin` e `/bin` por symlink pulando esses nomes — com contador de binários espelhados e prova sintética da regra de exclusão, no molde de `w206[0b]`.
- **O stub de `git` é de passagem, e a lista de subcomandos interceptados é declarada**, porque stubar `git` inteiro é medir o stub: `deploy_preflight` confere branch (`git rev-parse --abbrev-ref HEAD`), o estágio `tag` roda `git tag` e `git push`, e o próprio arnês resolve caminhos com git. O stub intercepta **exatamente dois** subcomandos — `tag` e `push` — e faz `exec` do git real para todo o resto, com o caminho absoluto do git real capturado **antes** de o `PATH` ser reescrito (`REAL_GIT="$(command -v git)"`). O assert `[0]` prova a passagem com controle positivo: dentro do fixture, `git rev-parse --abbrev-ref HEAD` devolve o branch do repositório de fixture, e `git tag` escreve no trace sem criar tag nenhuma. **Montei e executei esse arranjo nesta rodada**, porque a spec o prescrevia sem nunca o ter rodado:

```
$ PATH="$T/bin" git rev-parse --abbrev-ref HEAD      # passagem: exec do git real
fixture-branch

$ PATH="$T/bin" git tag deploy-dev-abc; echo rc=$?   # interceptado
rc=0
$ PATH="$T/bin" git push origin deploy-dev-abc; echo rc=$?
rc=0

$ cat "$T/trace.log"
git:tag tag deploy-dev-abc
git:push push origin deploy-dev-abc

$ PATH="$T/bin" git tag -l | wc -l                   # nada foi criado
0
```

**O espelho pula os oito nomes, não sete, e isso é medição e não simetria.** O `[0]` dizia "os sete por NOME" e tratava o `git` à parte, o que só fecha se o leitor somar o `git` de volta. Montei os dois espelhos na mesma bancada e o de sete não é uma variante estilística — ele é inexequível:

```
# mk_mirror <dir> <nomes a pular...> — symlinka /usr/bin/* e /bin/* em <dir>, pulando por NOME, e
# ecoa quantos symlinks criou. É o espelho que o [0] monta; a bancada define a função no início.
$ mk_mirror bin8 gh gcloud docker helm kubectl trivy cosign git
960
$ mk_mirror bin7 gh gcloud docker helm kubectl trivy cosign
961
$ ls -l bin7/git | sed "s/.* -> / -> /"
 -> /usr/bin/git
$ printf "#!/usr/bin/env bash\necho stub\n" > bin7/git; echo "rc=$?"        # instalar o stub por cima
bash: line 14: bin7/git: Operation not permitted
rc=1
$ echo conteudo-original > alvo.txt; ln -sf alvo.txt bin7/alvo-link; printf "stub-escrito\n" > bin7/alvo-link; cat alvo.txt
stub-escrito
```

O redirecionamento sobre um symlink **escreve no alvo apontado**, não cria arquivo novo no diretório — o controle prova o mecanismo com um alvo gravável. Com o alvo sendo `/usr/bin/git`, o macOS recusa por proteção de sistema (`Operation not permitted`, rc 1) e o fixture fica **sem** o stub de `git` enquanto acredita tê-lo instalado; num alvo gravável a mesma linha atingiria o binário real. Pular os oito é o que torna o `[0]` executável, e por isso a seção 4(e) e o `[0]` dizem oito nos dois lados.

A contagem de binários espelhados que o `[0]` publica é **derivada no momento da execução**, nunca escrita como literal: ela depende da máquina (nesta bancada, 960 com os oito nomes pulados, contra 961 com sete), e o que a asserção cobra é a propriedade — o espelho é não vazio e nenhum dos oito nomes stubados está nele.
- Todo stub e todo gate marcador acrescenta uma linha a um **trace único** (`$FIXTURE/trace.log`). O sinal de execução é **positivo** — uma linha que só aquele participante escreve —, nunca a ausência de erro, como manda `rules/testing/gate-delivery-channel.md`.
- O `run-gates.sh` invocado é o **real**, com um `FORGE.md` de fixture (frontmatter `---`, como a seção 2.2 mediu) declarando `check-predeploy-marker` em `phase: pre-deploy` e `check-postdeploy-marker` em `phase: post-deploy`.

As quatro asserções que juntas fecham o buraco, e por que nenhuma sozinha basta:

| Asserção | O que prova | Por que não basta sozinha |
|---|---|---|
| A marca do `pre-deploy` existe no trace | a fase foi invocada | não diz **quando**: uma invocação depois do `helm` seria inútil e passaria |
| A marca do `pre-deploy` precede a primeira linha de `helm` no trace | a ordem está certa | não diz que o **veredito** importa |
| Gate marcador que sai `1` → `deploy.sh` sai `3` e o trace **não tem nenhuma** linha de `helm`/`kubectl` | o veredito é respeitado | não cobre a fase de saída |
| A marca do `post-deploy` sucede a linha de `kubectl rollout` no trace, e a reprovação dela produz `rollback: performed` | a fase de saída está fiada e tem consequência | — |

### (f) `run-gates.sh --phase` recusa por vacuidade, e é isso que todo consumidor real encontra hoje

A revisão 2 achou o defeito mais caro desta rodada aqui, e ele procede: remedi com fixture própria e reproduz. `run-gates.sh` só chama `forge_universe_check` quando `--phase` é **explícita** (`run-gates.sh:66-72`), e nesse caminho universo vazio **reprova** a menos que exista isenção nomeada em `.forge/empty-universe-allowlist.txt` **com `# motivo:`**. Medido em `$TMPDIR`, com `cwd` dentro da fixture:

```
$ FORGE_ROOT="$T" bash "$T/.forge/scripts/run-gates.sh" mod-x --phase pre-deploy
FAIL run-gates-phase-pre-deploy/universo-vazio — 0 gate(s) examinado(s) (change:mod-x,phase:pre-deploy): o gate não examinou nada.
$ echo $?
1
```

E o campo é pior do que "zero declaram `phase:`": remedi o censo dos treze consumidores e **nove deles não têm `run-gates.sh` nenhum** (`agent-smith`, `Axis.AcqSimulator`, `azim-crm`, `collatra`, `cpf-cnpj-validator`, `docuseal`, `forge-harness` — o dogfood incompleto —, `forge-test`, `payments`), **três** têm bloco `gates:` no `FORGE.md` (`axis-fare-validator`, `Axis.PadSimulator`, `azim-crm`) e **zero** declaram `phase:`. O número era **quatro** na revisão 3 e o revisor mediu três; remedi os treze um a um antes de aceitar e ele está certo — o resto do censo (13 repositórios, os mesmos nove sem `run-gates.sh`, zero com `phase:`) reproduz sem alteração. O `axis-go-cloud`, que é o alvo do piloto obrigatório da seção 13, tem `run-gates.sh` com suporte a `--phase` e **nenhum** bloco `gates:` — o `runtime:` dele vai de `primary_stack` a `integrations:` sem `gates`. Ou seja: a ordem de execução da seção 5.2, escrita como estava, faria a primeira chamada de fase voltar FAIL no próprio piloto que a seção 15 põe na definição de pronto.

**A enumeração dos desfechos, e ela é exaustiva por medição, não por convicção.** Rodei os sete casos abaixo em fixture; a coluna "medido" diz o que observei:

| # | Condição | Última linha | rc | Universo da fase | Estado do estágio de fase |
|---|---|---|---|---|---|
| 1 | ≥1 gate na fase, todos passam | `OK` | 0 | > 0 | `passed` |
| 2 | ≥1 gate na fase, algum reprova **ou está `MISSING`** | `FAIL` | 1 | > 0 | `failed` |
| 3 | 0 gates na fase, **sem** isenção | `FAIL` (stderr `universo-vazio`) | 1 | 0 | `inconclusive` |
| 4 | 0 gates na fase, isenção **com `# motivo:`** | `NO-GATES` | 0 | 0 | `skipped-declared`; o motivo sai na **saída** da chamada, não em campo do recibo (parágrafo abaixo e seção 5.4) |
| 5 | 0 gates na fase, isenção **anônima** (sem `# motivo:`) | `FAIL` (stderr `sem '# motivo:'`) | 1 | 0 | `inconclusive` |
| 6 | `run-gates.sh` **ausente** no consumidor (nove de treze hoje) | nada em stdout | **127** | indefinido | `inconclusive` |
| 7 | `node` ausente do `PATH` com fase declarada em forma mapeada | `FAIL` (stderr `universo-vazio`) | 1 | 0 **por leitura frustrada** | `inconclusive` |

O caso 7 é o que a leitura do código não entrega e a medição entrega: `forge_runtime_gate_entries` delega a forma mapeada a `gate-phase.mjs` e, sem `node`, "a forma mapeada simplesmente não é lida" (`lib/forge-runtime.sh:71-72`) — o projeto **declarou** o gate de fase e o motor conta zero. Rodei com um espelho de `/usr/bin` e `/bin` pulando `node` por nome (961 binários espelhados) e a saída foi a mesma linha de `universo-vazio` do caso 3. `inconclusive` é o desfecho certo: o projeto declarou, o executor não conseguiu ler, e chamar isso de `pass` seria exatamente o rebaixamento que a invariante 2 proíbe.

O caso 6 é o desfecho que a revisão 1 e a revisão 2 não citaram e que o campo entrega com mais frequência: `bash <caminho inexistente>` devolve **127**, medido. Nove de treze consumidores estão nesse estado hoje.

**O discriminador entre os casos 2, 3 e 5 não é a mensagem, é o universo.** Os três terminam em rc 1 com `FAIL` na última linha, e casar a string de stderr acoplaria `deploy.sh` a um texto de outro arquivo — a família de defeito de LDG-0164 com outra fantasia, e uma mudança de redação em `gate-universe.sh` viraria mudança de comportamento em `deploy.sh`. O que `deploy.sh` faz é: **antes** da chamada, contar o universo da fase pelo leitor canônico já disponível (`forge_runtime_gates_phase "<fase>" "$ROOT"`, a mesma função que o `run-gates.sh` usa na linha 58, sem segundo leitor e sem parser novo) e gravar a contagem em `gates_pre_deploy`/`gates_post_deploy`; **sempre** invocar `run-gates.sh --phase` pelo canal real, sem condicional que possa pular a chamada; e **depois** classificar pelo par `(contagem, rc)` da tabela acima. A contagem entra no recibo, então "não examinei nada" fica escrito no manifesto e não só no log.

**O motivo da isenção do caso 4 é lido pelo leitor canônico, nunca pela linha de stderr.** A seção proíbe casar a string de stderr e depois mandava copiar o motivo para o manifesto sem nomear por onde — o que empurra o implementador exatamente para o parse de `justificativa declarada:` que ela acabou de proibir. O caminho já existe e é barato, porque `deploy.sh` carrega `lib/gate-universe.sh` de qualquer forma: `forge_universe_waiver <root> <gate-key>` devolve `OK<TAB><motivo>` quando a isenção tem `# motivo:`, `ERR<TAB><linha>` quando é anônima, e **vazio** quando não há isenção declarada, com rc sempre 0. A chave é `run-gates-phase-<fase>`, que é como `run-gates.sh:67` a compõe. Rodei os três estados na fixture:

```
$ FORGE_ROOT="$T" bash "$T/.forge/scripts/run-gates.sh" mod-x --phase post-deploy      # com '# motivo:'
OK run-gates-phase-post-deploy/universo-vazio — 0 gate(s) examinado(s) (change:mod-x,phase:post-deploy); justificativa declarada: este serviço não tem verificação pós-rollout automatizada
  (nenhum gate declarado para a fase 'post-deploy' em runtime.gates do FORGE.md — nada a executar)
NO-GATES
rc=0

$ bash -c '. "$0/.forge/scripts/lib/gate-universe.sh"; printf "%q\n" "$(forge_universe_waiver "$0" run-gates-phase-post-deploy)"' "$T"
$'OK\teste serviço não tem verificação pós-rollout automatizada'

$ # a mesma chamada com a isenção ANÔNIMA
$'ERR\t1'

$ # e sem isenção nenhuma no arquivo
''
```

Isso muda o discriminador para melhor: com a contagem em zero, o **estado do waiver** separa sozinho os casos 3, 4 e 5 (vazio, `OK`, `ERR`), que são justamente os três que terminam com a mesma última linha e rc's que se repetem. O par `(contagem, rc)` continua sendo o eixo principal — ele separa 1, 2, 6 e 7 —, e o waiver é o desempate dos três de universo vazio, todos lidos por função da casa, nenhum por string de mensagem.

**Onde o motivo do caso 4 é cobrado, e por que ele NÃO entra no recibo.** A redação anterior mandava copiá-lo "para o manifesto", e o manifesto da seção 5.4 é fechado em K linhas nomeadas uma a uma, nenhuma delas o motivo — três saídas eram possíveis e as três reprovavam alguma asserção desta própria spec: gravar uma linha nova estoura o K e dispara o autocontrole do recibo (rc 5, sem manifesto), omitir reprova a metade explícita do `[24]`, e embutir o texto no valor de `stage.gates-pre-deploy:` colide com o enum de veredito do `[9]`. **A decisão é que o motivo não é campo do recibo: ele é observável na saída da execução, e o recibo registra o estado que o motivo produziu** (`stage.gates-pre-deploy: skipped-declared` mais `gates_pre_deploy: 0`). Três medições sustentam a escolha, e nenhuma delas é preferência de estilo:

```
$ FORGE_ROOT="$T" bash "$T/.forge/scripts/run-gates.sh" mod-x --phase post-deploy >out.txt 2>err.txt; echo rc=$?
rc=0
$ cat out.txt
OK run-gates-phase-post-deploy/universo-vazio — 0 gate(s) examinado(s) (change:mod-x,phase:post-deploy); justificativa declarada: este serviço não tem verificação pós-rollout automatizada
  (nenhum gate declarado para a fase 'post-deploy' em runtime.gates do FORGE.md — nada a executar)
NO-GATES
$ wc -c < err.txt
0
```

**(1) O motivo já é impresso pelo canal real, em stdout, sem custo nenhum de campo** — `gate-universe.sh:70` o ecoa sem `>&2`, e o bloco acima mostra o stderr vazio. O que `deploy.sh` tem de fazer é **não engolir** a saída da chamada de fase, e essa é a propriedade que o `[24]` cobra. Medi as duas fiações possíveis, com o mesmo motivo na allowlist:

```
# prop.sh   — a fiação do desenho:  bash run-gates.sh <mod> --phase post-deploy; rc=$?
# engole.sh — a fiação errada:      out="$(bash run-gates.sh <mod> --phase post-deploy)"; rc=$?
# as duas terminam imprimindo a mesma linha de estágio, com o mesmo rc_fase=0.
$ bash prop.sh    | grep -c 'este serviço não tem verificação pós-rollout automatizada'
1
$ bash engole.sh  | grep -c 'este serviço não tem verificação pós-rollout automatizada'
0
```

O contrafactual discrimina e o rc **não** discrimina — as duas fiações devolvem `rc_fase=0` —, o que torna a presença do texto na saída a única evidência observável de que a fiação propaga em vez de engolir.

**(2) Um campo só colapsaria os dois estados que a spec passa a vida separando.** As duas fases têm isenções independentes, com motivos diferentes, na mesma execução — medido:

```
$ bash -c '. "$0/.forge/scripts/lib/gate-universe.sh"; for k in run-gates-phase-pre-deploy run-gates-phase-post-deploy; do printf "%s -> %q\n" "$k" "$(forge_universe_waiver "$0" "$k")"; done' "$T"
run-gates-phase-pre-deploy -> $'OK\timagem assinada no build, sem gate próprio de entrada'
run-gates-phase-post-deploy -> $'OK\teste serviço não tem verificação pós-rollout automatizada'
```

Um `gates_waiver_reason` único teria de escolher um dos dois ou concatenar; honesto seriam **dois** campos, K = 43, mais a extensão da sanitização a valores que passam a vir de arquivo do projeto e não de `argv` — um preço em três contadores e em duas asserções para duplicar um dado que já é versionado.

**(3) O motivo é recuperável sem o recibo, e o recibo é quem ancora a recuperação.** `.forge/empty-universe-allowlist.txt` é arquivo rastreado — `git ls-files` o lista neste repositório, e nenhum padrão do `installer/gitignore.patch` o alcança (o bloco gerido ignora `.forge/cache/`, não a raiz de `.forge/`) —, e o recibo grava `sha` quando ele foi declarado e `generated_at` sempre, que são as duas âncoras pelas quais um auditor volta à árvore daquele momento. Motivo versionado, alcançável pela âncora que o recibo publica, é evidência mais forte que motivo copiado: a cópia pode divergir da fonte em silêncio, que é `LDG-0014` outra vez, e esta spec já paga o assert `[21]` só para impedir esse tipo de divergência entre duas cópias.

**Por que `deploy.sh` NÃO declara isenção ao chamar.** A isenção existe, é versionada, exige `# motivo:` e reprova quando anônima — é a `empty-universe-allowlist.txt`, e ela é operada por arquivo do projeto, nunca por flag de quem invoca. Um `deploy.sh` que passasse a própria isenção seria escape hatch operado pelo chamador, que é literalmente o defeito que a allowlist existe para fechar, e apagaria a diferença entre "este projeto decidiu que não tem gate de pre-deploy" e "este projeto nunca pensou no assunto". O projeto que quiser deploy verde sem gate de fase declara a isenção com motivo e recebe o caso 4: `stage.gates-pre-deploy: skipped-declared`, `gates_pre_deploy: 0` no recibo, o texto do motivo na saída da execução, e rc 0.

**Consequência para a retrocompatibilidade, dita sem maquiagem:** a seção 10 usava a adoção zero de `phase:` como prova de que ninguém quebra, e isso estava certo para `run-gates.sh` e errado para `deploy.sh`. `deploy.sh` é maquinaria **nova**, sem chamador instalado, então continua verdade que nenhum comportamento existente muda; o que muda é a expectativa sobre o **primeiro** uso, e ela agora está escrita: num projeto sem gate de fase e sem isenção, `deploy.sh` termina em rc 4 com `verdict: inconclusive`, e isso é o desfecho **correto**, não uma falha da onda.
---

## 5. As peças

### 5.1 `template/.forge/scripts/lib/deploy-common.sh` — a mecânica

Sem uma linha específica de provedor. Contém:

- **`DEPLOY_STAGES`** — a lista ordenada e canônica dos treze estágios, declarada uma vez. É **um dos três ancoradouros** do contador de controle (seção 8), não o único.
- **`deploy_stage_run <nome> <cmd...>`** — executa um estágio, captura veredito, escreve a linha do trace e do manifesto. Todo estágio termina em exatamente um de quatro estados: `passed`, `failed`, `inconclusive`, `skipped-declared`.
- **`deploy_preflight`** — branch, chart, `values-<env>.yaml`, contexto k8s, aprovador em `prd`. Sem curto-circuito: com quatro pré-condições violadas, nomeia as quatro.
- **`deploy_rollback`** — `helm rollback` explícito quando a falha é posterior ao `--atomic`; registra `rollback: performed|not-needed|failed`.
- **`deploy_manifest_write`** — o recibo (seção 5.4), com sanitização na fronteira de gravação.

**O teto de tempo mora em `lib/timeout.sh`, e `pentest-ops.sh` NÃO é tocado nesta onda.** A revisão 1 mediu que a extração proposta antes quebrava o `w206` e eu confirmei, com dois comandos meus, que ela é ainda pior do que o revisor mediu:

1. `tests/w206-strix-pentest-gate.sh:1069` abre o bloco `[21]` com `grep -q "perl -e 'alarm" "$OPS"`, onde `OPS="$WS/template/.forge/scripts/pentest-ops.sh"` (linha 85). Removi as linhas da definição de `run_to` de uma **cópia** do engine em `$TMPDIR` e `grep -c "perl -e 'alarm"` caiu para **0** — o `[21]` reprova. A afirmação da revisão anterior ("o `w206[21]` é o assert que impede regressão dessa movida") estava **factualmente invertida**: ele não impede, ele reprova.
2. Pior, e isto é medição minha, não do revisor: o `w206` executa **onze cópias nuas** do engine (`MUT6A`, `MUT10`, `MUT15`, `MUT16C`, `MUT16D`, `MUT17`, `MUT18B`, `MUT24`, `MUT27`, `MUT28`, `MUT29`), invocadas como `bash "$MUT"` a partir de um diretório do fixture, com 18 invocações diretas mais as indiretas dos helpers `t27_run`/`t28_run`. Montei o cenário: uma cópia de `pentest-ops.sh` com `SCRIPT_DIR` e `. "$SCRIPT_DIR/lib/timeout.sh"` no topo, executada de um diretório sem a lib irmã ao lado. Saída observada — `.../mutdir/lib/timeout.sh: No such file or directory` — e **`rc=0`**, porque `pentest-ops.sh:24` declara `set -uo pipefail` **sem `-e`**: o `source` falha, o script segue, e `run_to` fica indefinido. Ou seja, a extração não faria o `w206` reprovar barulhentamente nessas onze cópias; faria cada uma delas medir um engine mutilado em silêncio. É a família de defeito que a onda existe para fechar, criada pela própria onda.

**Decisão, mudada em relação à revisão 1.** `lib/timeout.sh` nasce como a casa neutra de `run_to` para código **novo** (`deploy-common.sh` e `deploy.sh` a consomem por `source`), e `pentest-ops.sh` fica exatamente como está. A convergência das duas definições é trabalho próprio, com preço medido (editar o `w206[21]` para apontar o `grep` da definição à lib nova mantendo os dois controles positivos sobre `$OPS`, e dar às onze cópias nuas um espelho de diretório em vez de um arquivo solto), e é aberta como item de ledger no passo 0 da implementação, com o número alocado por `ledger-ops.sh` e nunca escolhido à mão.

**Opções de shell dos sete arquivos novos, e o pré-voo de lib irmã.** A revisão 2 apontou, com razão, que a spec fazia da degradação silenciosa por `source` falho o argumento central da correção do bloqueador 1 e depois criava três libs irmãs novas sem declarar opção de shell nenhuma. Remedi as três pontas em bancada sob `$TMPDIR`, com a lib ausente:

| Arranjo | Observado |
|---|---|
| `set -uo pipefail` (o de `pentest-ops.sh`) | `No such file or directory`, o script **segue**, `run_to: command not found`, **rc 0** |
| `set -euo pipefail` | aborta na linha do `source`, **rc 1** — sem mensagem do harness, e rc 1 não pertence ao vocabulário de saída da seção 5.2 |
| pré-voo explícito antes de qualquer `source` | `deploy: biblioteca irmã ausente: <caminho> — instalação incompleta`, **rc 5** |

A decisão usa os dois últimos, porque o segundo sozinho troca um silêncio por um rc mudo. A regra normativa, e ela segue o estilo da casa medido nos scripts do template (todo ponto de entrada declara `set`; nenhuma das **seis** libs existentes em `lib/*.sh` declara, porque uma lib que impõe `-e` ao chamador muda o comportamento de quem a carrega):

- **Pontos de entrada** — `deploy.sh` e o gate `w<NN>-deploy-portability-gate.sh` — declaram `set -euo pipefail`.
- **Libs** — `lib/deploy-common.sh`, `lib/timeout.sh` e os três `lib/ci/*.sh` — **não** declaram `set` nenhum, como as **seis** que já existem não declaram. A conta anterior dizia cinco e omitia `lib/heavy-mutex.sh`, que entrou depois; remedi o conjunto inteiro nesta rodada e a afirmação de fundo sobrevive à correção:

```
$ ls -1 template/.forge/scripts/lib/*.sh | sed 's|.*/||' | tr '\n' ' '
arg-guards.sh forge-root.sh forge-runtime.sh gate-universe.sh heavy-mutex.sh scan-exclude.sh

$ grep -ln '^[[:space:]]*set -' template/.forge/scripts/lib/*.sh || echo '(nenhuma)'
(nenhuma)
```
- **`deploy.sh` roda um pré-voo de lib irmã antes do primeiro `source`**, iterando sobre a lista literal das libs de maquinaria que ele vai carregar (`lib/forge-runtime.sh`, `lib/gate-universe.sh`, `lib/arg-guards.sh`, `lib/timeout.sh`, `lib/deploy-common.sh`) e **recusando com rc 5 nomeando o arquivo faltante**. Lib de maquinaria ausente é instalação incompleta — poda por tombstone, `update` interrompido, cópia parcial —, e não erro de configuração do projeto: por isso rc 5 e não rc 2.
- **O adaptador é o caso oposto e continua rc 2**: `lib/ci/<provedor>.sh` ausente é o projeto declarando um provedor que o harness não tem, que é configuração (tabela da seção 4(c)).

O assert `[25]` prova isso pelo canal real: remove **uma** lib irmã da cópia espelhada do fixture, roda `deploy.sh` de dentro dela e exige rc 5, a mensagem nomeando o arquivo faltante, e **zero** linha de `helm`/`kubectl` no trace. Sem esse assert a regra seria prosa, e prosa foi exatamente o que a revisão 2 recusou aqui.

**A duplicação não pode divergir em silêncio enquanto durar**, e é isso que a torna aceitável em vez de dívida cega: a asserção `[21]` do gate novo extrai o corpo da função `run_to` dos dois arquivos, normaliza espaço em branco e **exige igualdade textual**, com não-vacuidade (as duas extrações têm de ser não vazias). Duas cópias que um gate obriga a serem idênticas são um caso diferente de `LDG-0014`, onde as duas cópias divergiram porque nada as comparava.

**Os treze estágios** (`DEPLOY_STAGES`), na ordem, mapeando os dez gates do markdown mais as duas fases:

```
preflight  gates-pre-deploy  build  digest  scan  signature  sbom
release  rollout  smoke  admission  gates-post-deploy  tag
```

Estágio condicional (frota arm64 no `rollout`, Kyverno no `admission`) **não desaparece**: ele termina em `skipped-declared`, e o motivo tem de estar declarado. **A fonte do motivo depende da classe do estágio, e essa distinção é normativa** — a revisão 4 achou que escrever a regra sobre "estágio qualquer" a punha em contradição com o desfecho verde do caso 4 da seção 4(f), e a contradição era real:

| Classe | Quais | Fonte do motivo | Sem motivo, o estágio vira | Assert |
|---|---|---|---|---|
| **estágios de mecânica** — os **onze** de `DEPLOY_STAGES` que não são de fase | `preflight`, `build`, `digest`, `scan`, `signature`, `sbom`, `release`, `rollout`, `smoke`, `admission`, `tag` | `runtime.deploy.skip.<estagio>` no `FORGE.md` | `failed`, e o deploy sai 3 | `[15]` |
| **estágios de fase** — os **dois** que invocam `run-gates.sh --phase` | `gates-pre-deploy`, `gates-post-deploy` | `.forge/empty-universe-allowlist.txt`, lida por `forge_universe_waiver` (seção 4(f)) | `inconclusive`, e o deploy sai 4, nos **dois** modos de falta que a tabela da seção 4(f) enumera: sem isenção nenhuma, com o waiver devolvendo vazio (caso 3), e com isenção anônima, com o waiver devolvendo `ERR<TAB><linha>` (caso 5) | `[24]` |

A disciplina é a mesma nas duas linhas — isenção anônima nunca produz `skipped-declared` —, e só o desfecho da recusa difere, porque na fase quem recusa é `gate-universe.sh` e o que ele devolve é ausência de verificação, não violação observada. **`runtime.deploy.skip` não é fonte de motivo para os dois estágios de fase**, e uma chave `skip.gates-pre-deploy`/`skip.gates-post-deploy` declarada no `FORGE.md` **não** produz `skipped-declared`: admiti-la abriria uma segunda porta para o mesmo estado, sem a rejeição de isenção anônima que a allowlist impõe em `gate-universe.sh:73-76`, e uma segunda porta mais fraca para a mesma isenção é como um gate é esvaziado na prática. **Inerte não é silencioso:** o estágio de fase segue o desfecho da tabela da seção 4(f), e num projeto sem gate de fase e sem isenção na allowlist isso é `inconclusive` e rc 4 — recusa com recibo, que é o oposto de um pulo mudo. O `[24]` prova essa inércia com um cenário pareado.

### 5.2 `template/.forge/scripts/deploy.sh` — a porta

```
deploy.sh <modulo|--from-config> <env> [--sha <sha>] [--strategy rolling|blue-green|canary] [--approved-by <nome>] [--dry-run]
```

`<env>` pertence ao vocabulário **`dev|stg|prd`**, e a nenhum outro. É o vocabulário que `deploy-orchestrator.md:54` (`env: dev | stg | prd`) e `:60` ("`env` não está em `{dev, stg, prd}`") já publicam, e o comando, o script e o invólucro do workflow passam a usar exatamente esse conjunto. `staging` é nome de **branch git**, nunca de ambiente; a tradução mora numa linha do workflow e está declarada na seção 5.3.

Ordem de execução: pré-voo de lib irmã (seção 5.1) → valida argumentos → resolve o módulo → resolve o adaptador → `deploy_preflight` → **conta o universo de `pre-deploy` e invoca `run-gates.sh <change|modulo> --phase pre-deploy`** → estágios `build`..`admission` → **conta o universo de `post-deploy` e invoca `run-gates.sh ... --phase post-deploy`** → `tag` → `deploy_manifest_write`.

**Estágio de fase que não termine em `passed` ou `skipped-declared` interrompe a máquina de estados antes de `build`** — a regra estava fechada e escrita nos lugares errados (dentro do assert `[24]` e na previsão de P1 da seção 13), e o implementador que lesse só a ordem acima escreveria o caminho feliz e descobriria a parada quando `[24]` reprovasse. Vale para `failed` e para `inconclusive`, e é o que faz `gates_pre_deploy: 0` coexistir com zero linha de `helm`/`kubectl` no trace.

As duas chamadas de fase são **incondicionais** — nenhuma condicional pode pular a invocação, porque a invocação é a entrega e a asserção `[5]`/`[7]` prova que ela ocorreu. O que a contagem prévia decide não é *se* chama, é *como classifica o que voltou*: o par `(contagem, rc)` da tabela da seção 4(f) mapeia em `passed`, `failed`, `inconclusive` ou `skipped-declared`, e a contagem vai para o recibo em `gates_pre_deploy`/`gates_post_deploy`.

**Vocabulário de saída**, reusando literalmente o mapa de `pentest-ops.sh` (`strix_cmd_preflight` devolve 0/2/3/4 e `strix_cmd_scan` devolve 0/2/3/4/5) em vez de inventar um segundo dialeto no mesmo harness:

| rc | Significado | Manifesto |
|---|---|---|
| 0 | executou e passou — ou não havia nada declarado a implantar sob `--from-config` | gravado (não gravado no caso `--from-config` sem `runtime.deploy`) |
| 2 | erro de uso ou de configuração (argumento inválido, provedor não declarado, adaptador inexistente) | **não gravado** |
| 3 | executou e **reprovou** — algum estágio ou fase de gate falhou | gravado |
| 4 | **não conseguiu executar** — inconclusivo (CLI do provedor ausente, credencial ausente, cluster inalcançável) | gravado |
| 5 | erro do próprio executor — lib de maquinaria ausente, cache não gravável, ou invariante interna do recibo violada | **não gravado** |

**Precedência entre estados de estágio — a tabela normativa que faltava.** Um estágio `failed` e outro `inconclusive` na mesma execução tinham desfecho indefinido na revisão 1, e isso é justamente a invariante 2 do plano deixada em aberto. A regra, no molde do `w206[29]` ("precedência recusa VENCE inconclusivo no caso MISTO"):

| Estados presentes entre os treze estágios | `verdict` | rc |
|---|---|---|
| todos em `passed` ou `skipped-declared` (com motivo declarado na fonte da classe do estágio, seção 5.1) | `pass` | 0 |
| ao menos um `failed` — **com ou sem** `inconclusive` junto | `fail` | 3 |
| nenhum `failed` e ao menos um `inconclusive` | `inconclusive` | 4 |

**`failed` vence `inconclusive`, e a razão é a mesma do strix:** uma violação observada é evidência definitiva, um inconclusivo é ausência de evidência, e deixar a ausência mascarar a violação transforma "reprovou" em "não sei" — o rebaixamento que a invariante 2 proíbe. O contrário (inconclusivo vencendo) permitiria que qualquer falha fosse apagada por um `trivy` fora do PATH. O enum de `verdict` é fechado em **`pass | fail | inconclusive`** e nada mais.

**O rc 5 não tem linha nesta tabela porque ele não tem `verdict`, e isto é decisão, não omissão.** A revisão 2 achou o buraco: a coluna "Manifesto" dizia que rc 5 gravava recibo e o enum fechado de `verdict` não tinha valor para ele, o que empurrava o implementador a inventar um sexto valor (quebrando o enum e as asserções `[11]` e `[12]`) ou a escrever `fail` (apagando a diferença entre "o deploy reprovou" e "o executor quebrou" — a mesma colapso de estados da invariante 2, um nível acima). **A saída é a outra que o próprio revisor ofereceu: rc 5 não grava manifesto**, e há duas razões medidas, não uma preferência:

1. **Nas causas mais prováveis, o escritor do recibo é justamente o que falta.** `deploy_manifest_write` mora em `lib/deploy-common.sh`; a causa número um de rc 5 é lib de maquinaria ausente (seção 5.1), e a número dois é `.forge/cache/deploy/` não gravável. Uma regra normativa que mandasse gravar seria **impossível de cumprir** exatamente onde ela mais importaria, e regra inaplicável é regra que o implementador aprende a ignorar.
2. **A terceira causa é o recibo que reprova o próprio contador.** Se, na hora de gravar, `stages_examined ≠ stages_declared`, ou `verdict` cair fora do enum, ou o manifesto não tiver K linhas — o K **derivado** de `25 + |DEPLOY_STAGES| + 3`, nunca o literal 41, pela razão escrita na seção 5.4 —, `deploy.sh` **não grava nada** e sai 5 nomeando a invariante violada. Um recibo que falha o próprio contador de controle é pior que a ausência dele, porque parece evidência — é o defeito que esta onda inteira existe para não cometer.

Em rc 5 a saída é uma linha em stderr no formato `deploy: erro do executor: <causa>`, e nenhum arquivo em `.forge/cache/deploy/`. O rc 5 **aborta a máquina de estados**, então nunca coexiste com um `verdict`: onde há `verdict` há manifesto, e o manifesto só existe nos desfechos que a coluna "Manifesto" da tabela acima marca como gravados. O assert `[25]` prova a primeira causa e o `[12]` prova a contrapositiva — **e a contrapositiva tem escopo, não é universal sobre todo rc 0**: nos rc 3 e 4, e no rc 0 **com `runtime.deploy` declarado**, o manifesto existe e tem K linhas; o rc 0 do pulo declarado sob `--from-config` sem `runtime.deploy` (linha própria da tabela acima, cenário obrigatório da seção 5.3 e do `[19]`) não grava recibo nenhum, e um `[12]` escrito como universal nasceria vermelho contra a implementação correta.

O assert `[14]` prova a precedência no caso misto **nas duas ordens de ocorrência** — a reprovação antes do primeiro inconclusivo e depois dele — no `verdict` do manifesto e no rc, exatamente como o `w206[29]` faz.

**Parsing de flags, e a incompatibilidade que a revisão 3 achou entre a reutilização obrigatória e o rc 2.** A regra de reuso continua: `forge_reject_unknown` e `forge_reject_flag_as_value` de `lib/arg-guards.sh` são a correção da issue #103 e **não podem ser reimplementadas aqui**. O que a spec não tinha medido é que as duas encerram o processo com `exit 1` chumbado (`arg-guards.sh:38` e `:78`), e o vocabulário desta seção exige rc 2 para erro de uso — quem as fiar no ramo `*)` do `case`, que é o idioma da casa e o que a spec manda, sai **1** e reprova o próprio assert `[2]`. O revisor mediu certo, remedi antes de aceitar:

```
# as duas últimas linhas da mensagem da guarda (a nota sobre escape de valor literal) foram
# elididas nos três primeiros blocos abaixo para não repetir quatro vezes o mesmo parágrafo;
# a saída completa é a de `arg-guards.sh:70-77`.
$ bash direto.sh                       # chamada direta, idioma dos três consumidores existentes
FAIL: '--approved-by' recebeu '--dry-run' como valor no subcomando 'deploy' — '--dry-run' é uma flag aceita em 'deploy', não conteúdo.
  A flag seguinte foi engolida como valor da anterior. Flags aceitas em 'deploy': --approved-by --dry-run --sha --strategy
rc=1

$ bash traduz.sh                       # ( guarda ) || exit 2
FAIL: '--approved-by' recebeu '--dry-run' como valor no subcomando 'deploy' — '--dry-run' é uma flag aceita em 'deploy', não conteúdo.
  A flag seguinte foi engolida como valor da anterior. Flags aceitas em 'deploy': --approved-by --dry-run --sha --strategy
rc=2

$ bash traduz-ok.sh                    # controle positivo: valor legítimo atravessa a tradução
SOBREVIVEU
rc=0

# a segunda guarda, medida separadamente (primeira linha de stderr e rc de cada execução):
$ bash unk-direto.sh
FAIL: flag desconhecida '--dry-runn' para o subcomando 'deploy'
rc=1
$ bash unk.sh
FAIL: flag desconhecida '--dry-runn' para o subcomando 'deploy'
rc=2
```

**A decisão, e ela é por rc 2, não por admitir rc 1.** Admitir rc 1 para erro de uso resolveria a fiação e custaria três coisas medidas: quebraria a paridade com `strix_cmd_preflight`/`strix_cmd_scan`, que é a única razão pela qual esta seção não inventa um dialeto novo; colidiria com o rc 1 que `set -euo pipefail` produz num abort de `source`, que é exatamente o desfecho mudo que a seção 5.1 descartou; e obrigaria a reescrever a tabela de rc, a frase da 5.1 e o assert `[2]` juntos, para ganhar um vocabulário pior. Então:

- **Propriedade normativa:** erro de uso de `deploy.sh` — flag desconhecida, flag engolida como valor de outra, `<env>` fora de `{dev,stg,prd}`, valor vazio em flag de conteúdo — termina em **rc 2**, com a mensagem da guarda de `arg-guards.sh` **preservada byte a byte em stderr** e **nenhum** manifesto gravado.
- **O primitivo é escolha do implementador**, porque as guardas encerram o processo e não retornam: qualquer arranjo que satisfaça a propriedade serve. Medi acima que o embrulho em subshell com tradução do rc (`( guarda ... ) || exit 2`) satisfaz as três metades, inclusive o caminho de aceite, e é a existência-prova de que a propriedade é cumprível sem reimplementar a guarda — não é uma prescrição de idioma.
- **O contrafactual que `[2]` tem de produzir:** com a guarda fiada em chamada nua no ramo `*)`, `--approved-by --dry-run` sai rc 1 e o assert acusa `FAIL [2]: erro de uso produziu rc=1 (esperado 2)`; com a guarda removida, sai rc 0 gravando `approved_by: --dry-run`, e o assert acusa a gravação. Os dois vermelhos são distintos e nenhum deles é a ausência do arquivo.

### 5.3 Adaptadores e o invólucro do `staging.yml`

Cada adaptador (`lib/ci/github-actions.sh`, `lib/ci/cloud-build.sh`, `lib/ci/local.sh`) define exatamente as seis funções da seção 4(b), nem mais nem menos. `deploy.sh` carrega **um** por execução, resolvido nesta ordem: `runtime.deploy.ci_provider_path` (caminho explícito, para adaptador autoral) → `lib/ci/<runtime.deploy.ci_provider>.sh` → recusa com **rc 2** nomeando os adaptadores disponíveis e **sem gravar manifesto** (tabela da seção 4(c), linha "arquivo do adaptador não existe").

**O invólucro do `staging.yml` — redesenhado, porque ele é o comportamento padrão de todo `forge init` futuro.** A revisão 1 mediu três defeitos na linha proposta antes (`bash .forge/scripts/deploy.sh "${MODULE}" staging --sha "${GITHUB_SHA}"`) e os três procedem: `${MODULE}` não era definido em lugar nenhum do workflow nem da spec; `staging` não pertence ao vocabulário `dev|stg|prd`; e projeto recém-instalado não tem `runtime.deploy`, então o job que hoje sai 0 com três `echo` passaria a sair 2 e o pipeline nasceria vermelho no primeiro push. Confirmei os três: `template/github/workflows/staging.yml` não menciona `MODULE`; `deploy-orchestrator.md:54` publica `env: dev | stg | prd`; e o `runtime:` do `template/.forge/FORGE.md` vai de `primary_stack` a `gates:` sem nenhum bloco `deploy`. O invólucro passa a ser:

```yaml
      - name: Deploy (Forge)
        # branch `staging` (git) → ambiente `stg` (vocabulário dev|stg|prd do /forge:deploy-wave).
        run: |
          if [ ! -f .forge/scripts/deploy.sh ]; then
            echo "forge: .forge/scripts/deploy.sh ausente — nada a fazer"; exit 0
          fi
          bash .forge/scripts/deploy.sh --from-config stg --sha "${GITHUB_SHA}"
```

`--from-config` na posição do módulo significa: resolva o módulo de `runtime.deploy.module` no `FORGE.md`. Com o bloco `runtime.deploy` **ausente ou sem `module`**, `deploy.sh --from-config` sai **0** imprimindo `deploy: runtime.deploy ausente no FORGE.md — nada declarado a implantar (pulado, motivo declarado)`, não grava manifesto e não toca `helm` nem `kubectl`. **Pular com motivo declarado é a única saída compatível com a invariante 2** — e é diferente de aprovar por vacuidade, porque a única coisa que o pulo afirma é que o projeto não declarou nada, o que é verdade verificável na hora. Pedir um módulo **nominal** sem `runtime.deploy` continua sendo rc 2: quem nomeia um módulo está afirmando que ele existe.

**O corpo acima foi executado nesta rodada, e a execução achou o que a leitura não achava.** A regra nova do plano-mestre (invariante 19) manda rodar o que se prescreve; rodei o corpo do invólucro em bancada, fora do runner, nos quatro arranjos que importam:

```
$ ( cd "$W" && GITHUB_SHA=abc bash corpo.sh )            # deploy.sh AUSENTE
forge: .forge/scripts/deploy.sh ausente — nada a fazer
rc=0

$ ( cd "$W" && GITHUB_SHA=abc123 bash corpo.sh )         # deploy.sh presente, SHA definido
deploy.sh argv: --from-config stg --sha abc123
rc=0

$ ( cd "$W" && bash -c 'set -euo pipefail; . ./corpo.sh' )   # SHA indefinido, com set -u
./corpo.sh: line 4: GITHUB_SHA: unbound variable
rc=1

$ ( cd "$W" && bash -e corpo.sh )                        # SHA indefinido, sem set -u
deploy.sh argv: --from-config stg --sha
rc=0
```

Os dois primeiros são o desenho e batem. Os dois últimos são o achado, e ele é do **gate**, não do campo: no runner do Actions `GITHUB_SHA` está sempre definido, mas o assert `[19]` executa este corpo **fora** do runner, e ali um `GITHUB_SHA` indefinido produz ou um rc 1 fora do vocabulário (com `set -u`) ou um `--sha` com valor **vazio** que chega em `deploy.sh` (sem `set -u`). Duas consequências normativas: o `[19]` **define `GITHUB_SHA` explicitamente na sua bancada**, senão mede um invólucro que o campo nunca executa; e `deploy.sh` **recusa `--sha` vazio com rc 2**, pela mesma guarda de valor vazio de `lib/arg-guards.sh` (`forge_require_value`), porque um manifesto com `sha:` em branco atesta uma imagem que ninguém consegue identificar depois.

**A asserção do token de ambiente é ancorada na linha de invocação, nunca no arquivo.** Montei o `staging.yml` pós-reescrita e contei: ele contém `staging` **quatro** vezes de forma legítima — o comentário de cabeçalho, o `name: staging-pipeline`, o `branches: [staging]` e o próprio comentário da tradução branch→ambiente. Um `grep -q staging` solto sobre o arquivo nasceria vermelho contra o desenho publicado. A propriedade correta é sobre a linha que invoca o executor:

```
$ grep -n 'deploy\.sh --from-config' "$T/staging-novo.yml"
23:          bash .forge/scripts/deploy.sh --from-config stg --sha "${GITHUB_SHA}"

$ grep 'deploy\.sh --from-config' "$T/staging-novo.yml" | awk '{for(i=1;i<=NF;i++) if($i=="--from-config") print "env="$(i+1)}'
env=stg

$ grep -c 'staging' "$T/staging-novo.yml"
4
```

O assert `[19]` trava, então, quatro metades: **na linha que invoca `deploy.sh`** o token de ambiente é `stg` e não `staging`, e essa linha existe (não-vacuidade); com `runtime.deploy` ausente o corpo do invólucro sai 0, imprime a linha de pulo declarado e deixa o trace **sem nenhuma** linha de `helm`/`kubectl`; com `runtime.deploy.module` declarado o mesmo corpo invoca `deploy.sh` com o módulo resolvido; e o corpo roda com `GITHUB_SHA` definido pela bancada, com um caso pareado de `--sha` vazio recusando com rc 2.

A mecânica deixa de morar dentro do YAML. Isso é o que torna a portabilidade real e não declarada: o mesmo `deploy.sh` roda no runner do Actions, no Cloud Build, e na máquina de quem opera.

### 5.4 Manifesto `deploy-run/v1`

Texto plano `chave: valor`, uma entrada por linha, mesmo molde de `strix-preflight/v1` (`pentest-ops.sh:924-980`) e pela mesma razão: a saída do deploy por si só não prova sob que condições ele ocorreu. Gravado em `.forge/cache/deploy/<run_id>/deploy.txt`, nos rc **3 e 4** e no rc **0 com `runtime.deploy` declarado**, e **nunca nos rc 2 e 5**, nem no rc 0 do pulo declarado sob `--from-config` sem `runtime.deploy` (tabela da seção 5.2, que é a fonte). A correção do rc 5 veio da revisão 2 e a razão está escrita lá: onde há `verdict` há manifesto, e rc 5 é o desfecho em que o executor não pode responder pelo próprio recibo.

Campos, na ordem: `schema`, `run_id`, `generated_at`, `engine_sha256`, `forge_root`, `module`, `env`, `sha`, `strategy`, `dry_run`, `ci_provider`, `ci_provider_available`, `ci_run_ref`, `ci_run_url`, `image_ref`, `image_digest`, `chart_path`, `values_file`, `namespace`, `kube_context`, `approved_by`, `gates_pre_deploy`, `gates_post_deploy`, `stages_declared`, `stages_examined` — **25 campos fixos** —, depois **13 linhas `stage.<nome>: <veredito>`**, uma por estágio de `DEPLOY_STAGES`, e por fim `rollback`, `duration_s`, `verdict` — **3 finais**. O manifesto íntegro tem, portanto, exatamente **K = 25 + 13 + 3 = 41 linhas**, e esse é o K da propriedade 1 do PBT (seção 9.1). O número é derivado da lista de campos publicada acima, não escolhido: acrescentar um campo é mudar o K, e o gate assere a soma nas três parcelas separadamente (`[12]`), para que um campo a mais e um estágio a menos não se cancelem num total que continua 41.

**O K que o autocontrole do recibo confere é o derivado — `25 + |DEPLOY_STAGES| + 3` —, nunca o literal 41.** A distinção decide o comportamento sob a mutação (e) da seção 7 e precisa estar escrita: com um nome removido da constante, o manifesto sai com 40 linhas, o autocontrole da terceira causa de rc 5 (seção 5.2) **passa**, porque o recibo continua internamente coerente, e quem acusa é o `[9]` do gate, comparando contra o literal `13` que o gate escreve de propósito. Se o executor conferisse contra o 41 chumbado, a mutação (e) sairia em rc 5 sem manifesto, o efeito declarado na matriz ("`stages_declared` e `stages_examined` caem juntos para 12") deixaria de ser observável e o `[9]` acusaria por ausência de arquivo em vez de por divergência de contador — o executor seria, ao mesmo tempo, o medido e a régua, que é o arranjo que o denominador triplo da seção 8 existe para desfazer.

Regras de geração que a revisão 1 apontou como ausentes, agora declaradas:

- **`run_id`** segue a fórmula do strix (`strix_run_id`, `pentest-ops.sh:903-909`): `<UTC compacto>-<8 hex>`, com os 8 hex vindos de `/dev/urandom` e caindo para `00000000` quando a leitura falha. Um único componente de caminho, sem separador — a mesma propriedade que `strix_is_safe_run_id` protege lá.
- **`engine_sha256`** resume os **três** arquivos que compõem o engine daquela execução, na ordem: `deploy.sh`, `lib/deploy-common.sh` e o adaptador efetivamente carregado. É o `sha256` da concatenação dos três, e o manifesto registra também qual adaptador entrou na conta (é o campo `ci_provider`). Resumir só `deploy.sh` deixaria a mecânica e o provedor fora do recibo, que é metade do que o recibo existe para atestar.
- **`verdict`** é fechado em `pass | fail | inconclusive`, coerente com a tabela de precedência da seção 5.2.
- **`ci_provider_available`** é fechado em `yes | no | unknown`, espelhando os rc 0/1/2 de `ci_available`.
- **Estágio que a interrupção não alcançou é gravado como `inconclusive`.** As treze linhas `stage.<nome>:` existem em todo manifesto, inclusive nos desfechos que a seção 5.2 manda interromper antes de `build` — os do `[4]`, `[6]` e `[24]` —, e o veredito de um estágio nunca alcançado é `inconclusive`, porque "não executou" é ausência de evidência e não aprovação. Sem esta regra o `[4]` exigiria `verdict: inconclusive` num cenário em que nenhum estágio chega a rodar sem que nada dissesse de onde esse `inconclusive` vem, e a linha da seção 15 que cobra `literal 13 == stages_declared == linhas stage. == stages_examined` **em todos os desfechos que gravam manifesto** seria impossível de cumprir em três deles.
- **Campo sem valor é gravado como a chave, dois-pontos e nada** — é o estilo da casa, medido no molde que este manifesto copia: `strix_manifest_write` escreve `${R4_IMAGE:-}` e `${R5_MAX_BUDGET:-}` vazios e reserva marcador nomeado (`unknown`, `n/a`) só para campo de vocabulário fechado. Vale a mesma disciplina aqui, e ela carrega uma distinção que importa: `gates_pre_deploy:` **vazio** significa que a contagem nunca foi tomada (o `[4]` aborta na resolução do adaptador, antes da fase), enquanto `gates_pre_deploy: 0` significa que ela foi tomada e deu zero (o `[24]`). Colapsar os dois num mesmo `0` seria a invariante 2 dentro do próprio recibo. `image_ref`, `image_digest` e `ci_run_ref` ficam vazios quando o build não ocorreu; `rollback` tem vocabulário fechado (`performed | not-needed | failed`) e sai `not-needed` quando não houve release.
- **O motivo da isenção de universo vazio NÃO é campo do manifesto** (seção 4(f)): ele é observável na saída da execução, propagada de `run-gates.sh`, e o que o recibo registra é o estado que ele produziu — `stage.gates-pre-deploy: skipped-declared` mais `gates_pre_deploy: 0`. Acrescentá-lo custaria dois campos (as duas fases têm isenções independentes, medido na seção 4(f)), mudaria o K e duplicaria no recibo um dado que já é versionado no commit que o próprio recibo nomeia em `sha`.

`stages_declared` e `stages_examined` são o contador de controle no recibo, não só no log — o mesmo papel de `conditions_examined` no manifesto do strix, que o `w206[15]` assere contra o número de linhas de veredito. **`stages_examined` mede a cobertura do recibo sobre `DEPLOY_STAGES`, e não quantos estágios executaram**: ele é sempre treze, porque as treze linhas existem sempre, e o que ele pega é o recibo que omite um estágio em silêncio. Quem diz o que executou é o veredito de cada linha — e é por isso que a regra do estágio não alcançado, acima, precisa estar escrita.

`gates_pre_deploy` e `gates_post_deploy` gravam a **contagem do universo de cada fase**, medida pelo leitor canônico antes da chamada (seção 4(f)), e não um `ok`/`fail`. É o contador de controle do eixo de fase dentro do recibo: `gates_pre_deploy: 0` diz em letra que a fase não examinou nada, e é a única forma de o auditor distinguir "as duas fases passaram" de "as duas fases não tinham o que examinar" depois que a execução terminou. O veredito de cada fase continua nas linhas `stage.gates-pre-deploy:` e `stage.gates-post-deploy:`.

**Sanitização na fronteira de gravação.** `module`, `env`, `sha` e `approved_by` vêm de `argv`; um `\n` embutido forja uma linha nova no recibo — inclusive um `verdict: pass` fantasma antes do veredito real. É o achado D2 da revisão adversarial do strix (`strix_sanitize`, `pentest-ops.sh:916-921`), e ele se repete aqui por construção. A função análoga vive em `deploy-common.sh` e é a unidade sob PBT (seção 9.1).

### 5.5 `/forge:deploy-wave` reescrito

O markdown deixa de ser a mecânica. Passa a: dizer o que o comando faz, listar os treze estágios **por nome, iguais aos de `DEPLOY_STAGES`**, mostrar a invocação de `deploy.sh`, explicar os cinco códigos de saída e onde fica o manifesto. Os blocos de shell saem do markdown e do `deploy-orchestrator.md`, que passa a ser o agente que **opera** o script (decide quando, confirma em `prd`, sincroniza Jira) em vez de o agente que **é** o script.

Regeneração do plugin obrigatória por `npm run build:plugin` — nunca `build-plugin.sh`, que instala em `$HOME`. `plugin/forge/commands/deploy-wave.md` existe e precisa acompanhar.

**Paridade de conteúdo, não de token.** O caso histórico que motiva o assert está fechado, e a varredura de comandos desta rodada achou que **o comando que a spec publicava para separar os dois estados deixou de separar**: a correção da Fase 0 foi commitada em `c41eead` entre a revisão 3 e esta, e `git show HEAD:…` passou a devolver o mesmo texto da árvore de trabalho. O exemplo agora é ancorado no par de commits, que discrimina e continuará discriminando:

```
$ git show c41eead^:template/.forge/commands/waves/pentest.md | sed -n '146p' | grep -oE '(quatro|seis) raízes de skill'
quatro raízes de skill

$ git show c41eead:template/.forge/commands/waves/pentest.md  | sed -n '146p' | grep -oE '(quatro|seis) raízes de skill'
seis raízes de skill

$ sed -n '146p' template/.forge/commands/waves/pentest.md | grep -oE '(quatro|seis) raízes de skill'
seis raízes de skill
```

Em `c41eead^` a linha dizia "quatro raízes de skill" enquanto o engine varria seis, e o `w206[23]` — que confere paridade de **tokens** `R<n>/<nome>` — ficava verde sobre a divergência. A lição sobrevive ao conserto: paridade de token não é paridade de conteúdo. Por isso o assert `[20]` desta onda confere que **todo estágio de `DEPLOY_STAGES` aparece nomeado no markdown e no plugin, e todo estágio citado no markdown existe na constante** — conjunto contra conjunto, nas duas direções.

---

## 6. O Vermelho, antes do Verde

Todas as asserções abaixo falham **pela ausência real da funcionalidade**, e não por fixture torto. A distinção é verificável: hoje `template/.forge/scripts/deploy.sh` não existe, e `lib/deploy-common.sh` não existe. Um Vermelho por `bash: deploy.sh: No such file or directory` **não conta** — é a forma de vermelho que a rule `regression-red-first.md` reprova, porque não distingue "a proteção falta" de "a proteção falhou".

**Protocolo do Vermelho, em ordem, e é obrigatório nesta sequência:**

1. Escreve-se primeiro um **esqueleto executável** de `deploy.sh` e `deploy-common.sh`: parsing de argumentos válido, `DEPLOY_STAGES` declarada com os treze nomes, e cada estágio como um `deploy_stage_run <nome> true` que **passa sem fazer nada**. O script existe, roda, sai `0` e não invoca fase nenhuma.
2. Escreve-se o gate inteiro (os vinte e sete blocos da seção 8.1) contra esse esqueleto.
3. O Vermelho observado e registrado é o do passo 2 contra o esqueleto do passo 1 — comportamental, contra código real.

Vermelho esperado, asserção a asserção — **treze linhas**, e este número é o denominador que a seção 15 cobra (as que definem a onda; a lista completa das asserções e o total fixo estão na seção 8.1):

| Assert | Mensagem de falha esperada no Vermelho | Por que falha pela ausência real |
|---|---|---|
| `[3]` | `FAIL [3]: ci_provider inexistente ('gitlab') produziu rc=0 (esperado 2) e não nomeou os adaptadores disponíveis` | o esqueleto não resolve adaptador nenhum; sai 0 sempre |
| `[4]` | `FAIL [4]: CLI do provedor ausente produziu rc=0 (esperado 4) e não gravou manifesto com ci_provider_available: no` | o esqueleto não consulta `ci_available`; e sem `deploy_manifest_write` não há recibo |
| `[5]` | `FAIL [5]: fase pre-deploy não foi invocada — marca ausente em trace.log` | o esqueleto não chama `run-gates.sh`; a marca só é escrita pelo gate marcador que a fase executaria |
| `[6]` | `FAIL [6]: pre-deploy reprovou e o deploy prosseguiu (helm no trace, rc=0)` | sem executor não há veredito a respeitar; o esqueleto segue direto e sai 0 |
| `[7]` | `FAIL [7]: fase post-deploy não foi invocada` | idem `[5]`, do outro lado |
| `[9]` | `FAIL [9]: stages_examined=0, stages_declared=13, literal do gate=13` | o esqueleto não grava manifesto; o contador não existe |
| `[10]` | `FAIL [10]: lib/ci/ não existe — 0 adaptador(es) examinado(s)` | nenhum adaptador escrito ainda; e o `forge_universe_check` reprova universo vazio por construção |
| `[11]` | `FAIL [11]: manifesto de github-actions e cloud-build diverge em <campos>, além dos quatro tolerados (ci_provider, ci_run_ref, ci_run_url, engine_sha256)` | não há segundo adaptador; a substituibilidade é a afirmação sob teste |
| `[12]` | `FAIL [12]: manifesto ausente em .forge/cache/deploy/<run_id>/deploy.txt` | `deploy_manifest_write` não existe |
| `[14]` | `FAIL [14]: caso misto (failed + inconclusive) produziu verdict=inconclusive/rc=4, esperado fail/rc=3` | não há mapa de precedência; o esqueleto não classifica estágio nenhum |
| `[19]` | `FAIL [19]: invólucro do staging.yml não invoca deploy.sh` | o `staging.yml` do template ainda é o esqueleto de três `echo` |
| `[24]` | `FAIL [24]: fase pre-deploy com universo vazio produziu verdict=pass/rc=0 (esperado inconclusive/rc=4) e gates_pre_deploy ausente do manifesto` | o esqueleto não conta universo, não chama fase e não grava recibo — os três estados da tabela da seção 4(f) colapsam num `exit 0` |
| `[25]` | `FAIL [25]: lib irmã ausente produziu rc=0 (esperado 5) e o trace tem linha de helm` | o esqueleto não tem pré-voo de lib irmã; ele nem carrega lib nenhuma ainda |

Registrar o Vermelho com `/forge:red record` + `/forge:red replay`, no change desta onda, é o caminho canônico do repositório e fecha o vetor de evidência produzida por quem é verificada.

---

## 7. Prova de mutação — o que mutar, o que o gate diz, como restaurar

Seis mutações. Todas numa **cópia** do arquivo, nunca no arquivo rastreado — `LDG-0175` é literalmente o caso de um gate que usou arquivo rastreado e distribuído como fixture e não restaurou.

**Toda linha desta matriz foi rodada antes de ser escrita.** Montei em `$TMPDIR` uma bancada com o `run-gates.sh` **real**, um `FORGE.md` de fixture declarando os dois gates marcadores nas duas fases, e um modelo mínimo de `deploy.sh` com a ordem de execução da seção 5.2; apliquei cada mutação sobre a cópia e li o trace observado. Duas linhas da matriz da revisão 2 estavam erradas e a medição as corrigiu — a (b) declarava um efeito que não acontece, e a (c) era **no-op** no cenário em que estava escrita. Este parágrafo existe porque a lição de `LDG-0164` e de `feedback-mutacao-fantasma-restore` é exatamente essa: o `cmp` confirma que o arquivo mudou enquanto o comportamento não muda.

Trace observado no engine **íntegro**, que é o controle contra o qual toda linha é lida:

```
stage:preflight
gate:predeploy-marker
helm upgrade --install
kubectl rollout status
gate:postdeploy-marker
stage:tag                          (rc 0)
```

**Como a cópia mutada resolve a lib irmã** (a ressalva da revisão 1, e ela procede). `deploy.sh` resolve os irmãos pelo idioma já usado em `archive-spec.sh:17-18` — `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` e `ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"` —, que é o padrão de `LDG-0171` (34 sítios abertos). Para não acrescentar um 35º sítio de risco **e** para não repetir o defeito que medi na seção 5.1 (cópia nua cujo `source` falha em silêncio sob `set -uo pipefail`), o fixture do gate **espelha o diretório inteiro**: `cp -R template/.forge/scripts "$FIXTURE/.forge/scripts"`, a mutação incide em `$FIXTURE/.forge/scripts/deploy.sh` (ou `lib/deploy-common.sh`), a execução acontece com `cwd` dentro do fixture, e `$ORIG` é a cópia intacta guardada em `$FIXTURE/orig/`. Nenhum arquivo rastreado é lido para mutação e nenhum é escrito. É exatamente o arranjo que a reprodução da seção 2.2 usou e que funcionou.

| # | Mutação (na cópia espelhada) | Cenário obrigatório | Efeito **medido** no trace | O gate tem de dizer | Assert que morde |
|---|---|---|---|---|---|
| a | a chamada `run-gates.sh ... --phase pre-deploy` vira `:` | caminho feliz | `gate:predeploy-marker` **ausente**; `helm` e `kubectl` presentes; rc 0 | `FAIL [5]: fase pre-deploy não foi invocada — marca ausente em trace.log` | `[5]` |
| b | a primeira chamada troca `--phase pre-deploy` por `--phase post-deploy` | caminho feliz | `gate:predeploy-marker` **ausente**; `gate:postdeploy-marker` **duas vezes**, a primeira na linha 2, **antes** do `helm` da linha 3; rc 0 | `FAIL [5]: fase pre-deploy não foi invocada — marca ausente em trace.log` **e** `FAIL [7]: marca de post-deploy aparece 2 vez(es) no trace (esperado 1) e a primeira PRECEDE a linha de kubectl rollout` | `[5]` e `[7]` |
| c | o `rc` da fase pre-deploy é capturado e ignorado (`\|\| true`) | **gate marcador de pre-deploy reprovando** (`rc 1`) — sem isso a mutação é no-op medido | trace idêntico ao do engine íntegro no caminho feliz, com `gate:predeploy-marker` **seguido** de `helm`; rc 0, contra rc 3 do controle | `FAIL [6]: pre-deploy reprovou e o deploy prosseguiu (helm no trace, rc=0)` | `[6]` |
| d | `deploy_digest_validate` passa a ecoar o digest sem validar `sha256:<64hex>` | as **cinco** variantes malformadas da lista abaixo | as cinco são aceitas e gravadas em `image_digest`, inclusive a vazia | `FAIL [13]: digest malformado (<variante>) foi aceito e gravado em image_digest` | `[13]`, e `[12]` no reflexo do manifesto |
| e | um nome é removido de `DEPLOY_STAGES` | qualquer | **medido na bancada mínima da constante:** `stages_declared` e `stages_examined` caem juntos para 12 e só o literal do gate não cai. **Consequência de desenho declarada, não medida** (o executor ainda não existe): o manifesto sai com 40 linhas e o autocontrole do recibo **passa**, porque ele confere o K derivado de `25 + \|DEPLOY_STAGES\| + 3` e não o literal 41 (seção 5.4) — sem isso a mutação sairia em rc 5 sem recibo e o `[9]` acusaria por ausência de arquivo, não por divergência de contador | `FAIL [9]: DEPLOY_STAGES declara 12 estágios e o gate exige 13 (manifesto: stages_examined=12)` | `[9]` |
| f | `deploy_digest_validate` perde a **âncora de fim** do regex (`{64}$` vira `{64}`) | as cinco variantes malformadas | **só a de 65 hex** muda de estado: passa a ser aceita; as outras quatro continuam recusadas | `FAIL [13]: digest malformado (65 hex) foi aceito e gravado em image_digest` | `[13]` |

**A mutação (d) precisa de um stub que devolva digest malformado, senão não morde** — a revisão 1 está certa, e o defeito era real: com o stub devolvendo digest bem formado, remover a validação não muda observável nenhum e a mutação vira a prova fantasma que esta seção existe para evitar.

**A revisão 2 achou que o conjunto declarado não era o conjunto que a spec afirmava copiar, e procede.** Reli `tests/w206-strix-pentest-gate.sh:585-635` e contei: o `w206[8]` roda **cinco** malformadas, não quatro — ausente, sem `@sha256:`, 63 hex (`${DIGEST_HEX%?}`), **65 hex** (`${DIGEST_HEX}0`, linha 616) e hex maiúsculo. A que a spec omitia é a única que importa para a validação, e medi por quê:

```
                                        regex sem `$`      regex com `$`
sha256: + 64 hex minúsculos (controle)     ACEITA             ACEITA
sha256: + 65 hex                           ACEITA             recusa
sha256: + 63 hex                           recusa             recusa
sha256: + 64 hex MAIÚSCULOS                recusa             recusa
64 hex sem prefixo                         recusa             recusa
vazio                                      recusa             recusa
```

A tabela acima foi remedida nesta rodada e reproduz linha a linha. Sem âncora de fim, 65 hex é aceito e `image_digest` passa a gravar um digest inválido num recibo que existe para provar qual imagem foi implantada. **Das cinco malformadas, a de 65 hex é a única que separa um padrão ancorado de um não ancorado** — e é exatamente o erro que uma validação escrita às pressas comete. Por isso a mutação (f) existe: ela é a versão realista da (d), e a (d) sozinha (remover a validação inteira) seria fácil demais.

**A spec declara a propriedade, não o padrão.** `deploy_digest_validate` aceita `sha256:` seguido de exatamente 64 hexadecimais minúsculos, e recusa tudo o mais — o **primitivo** (`grep -E` ancorado, `[[ =~ ]]`, `case` com glob) é escolha do implementador, e a prova de que ele discrimina é a tabela de seis linhas rodada contra a implementação escolhida, mais a mutação (f) removendo a âncora de fim daquele primitivo. Prescrever aqui um regex específico seria escrever para o implementador um comando cujo comportamento varia entre `grep -E`, `[[ =~ ]]` e `case` — e a régua da invariante 19 é exatamente essa. As duas linhas que a spec fixa e que nenhum primitivo pode contrariar são: o controle de 64 minúsculos **passa**, e a variante de 65 hex **muda de estado** quando a âncora de fim sai.

O conjunto, injetado por variável de ambiente lida pelo stub (`STUB_DIGEST`), é **análogo** ao do `w206[8]`, e a diferença está declarada porque o revisor a mediu e ela procede: o `w206[8]` roda ausente, sem `@sha256:`, 63 hex, 65 hex e maiúsculo; aqui o "ausente" (chave que não existe no YAML) não tem correspondente, porque o digest chega de `ci_build_digest` e não de um arquivo de configuração, e no lugar dele entra o **vazio**, que é o que um adaptador devolve quando não consegue resolver. O que importa é que o conjunto seja autossuficiente para a propriedade, e a tabela dos dois regexes acima prova que ele é:

1. `sha256:` + **63** hex;
2. `sha256:` + **65** hex;
3. `sha256:` + 64 hex com **maiúsculas**;
4. 64 hex **sem** o prefixo `sha256:`;
5. valor **vazio**;
6. controle positivo: `sha256:` + 64 hex minúsculos, que tem de **passar** no engine íntegro e continuar passando na cópia mutada (a mutação não pode ser detectada por um caso que já falhava).

**A regra de "ao menos duas variantes" da revisão 1 foi substituída por "todas as cinco", e a razão é medida:** com "ao menos duas", a mutação (f) passaria em silêncio, porque ela muda o estado de **uma só** variante. Exigir as cinco é o que torna `[13]` capaz de morder o defeito realista, e não só o caricato.

**A validação de formato mora num único ponto nomeado, e a mutação incide exatamente nele.** A revisão 2 apontou que "o `ci_build_digest` do adaptador" não identifica arquivo nenhum — há três adaptadores, nada impedia centralizar a validação em `lib/deploy-common.sh`, e nesse caso o passo 2 do protocolo devolveria "a mutação não aconteceu" ou o assert ficaria verde por exercitar outro adaptador. A decisão, em letra: **`deploy_digest_validate` é a única função que valida o formato do digest, vive em `lib/deploy-common.sh` e é chamada por `deploy.sh` sobre o que quer que o adaptador tenha devolvido.** Nenhum `lib/ci/*.sh` valida formato — o adaptador **obtém** o digest e o devolve cru; validar é da mecânica, que é comum aos três. O assert `[10]` já exige que o conjunto de funções `ci_*` definidas seja igual ao chamado, então um adaptador que inventasse validação própria seria código morto detectado ali. As mutações (d) e (f) incidem, as duas, sobre `lib/deploy-common.sh` na cópia espelhada, num único sítio.

**A mutação (e) acusa pela comparação contra o literal, não pela igualdade entre derivados** — e é isto que a revisão 1 pegou e que a redação anterior estragava. A seção anterior mandava o gate "nunca redigitar 13" e ao mesmo tempo assertar `stages_examined == stages_declared == 13`; se o implementador seguisse a primeira instrução, os dois lados passariam a derivar da **mesma** constante, ambos cairiam para 12 juntos, a igualdade se manteria e o `cmp` do passo 2 confirmaria alegremente que o arquivo mudou. É a tautologia de `LDG-0164` com outra fantasia. A decisão mudou: **o literal 13 é escrito no gate, de propósito**, e a seção 8 explica por que isso não é a redigitação que a invariante 3 proíbe.

**As mutações (b) e (c) foram corrigidas pela medição, e as duas correções valem registro separado.**

A **(b)** — trocar a primeira `--phase pre-deploy` por `--phase post-deploy` — não produz "marca de pre-deploy sucede a primeira linha de helm", como a revisão 2 disse com razão: a marca de pre-deploy simplesmente **não existe** nesse cenário, porque o gate marcador daquela fase nunca é executado. Rodei e observei `gate:postdeploy-marker` **duas vezes**, a primeira na linha 2 e o `helm` na linha 3. Isso importa porque, por `[5]` sozinha, a (b) é **indistinguível da (a)**: as duas produzem a mesma acusação de marca ausente. O que as separa é o sinal **positivo** da fiação errada, e ele obriga um reforço de `[7]`: a marca de post-deploy tem de aparecer **exatamente uma vez** no trace e **suceder** a linha de `kubectl rollout`. Com `[7]` escrita só como "sucede", a segunda ocorrência satisfaria a asserção e a mutação passaria — o gate ficaria verde sobre a fiação trocada.

A **(c)** — capturar e ignorar o `rc` da fase — é **no-op medido** no cenário em que a matriz anterior a escrevia. Rodei com o gate marcador **passando** e o trace da cópia mutada saiu byte-idêntico ao do engine íntegro (`diff` vazio), rc 0 nos dois. A mutação só morde com o **gate marcador de pre-deploy reprovando**, e aí o contraste aparece limpo: engine íntegro devolve rc 3 com o trace parando em `recusa: fase pre-deploy reprovou`, sem `helm`; cópia mutada devolve rc 0 com `helm` e `kubectl` no trace. O cenário virou coluna própria da matriz porque uma mutação cujo cenário não está escrito é uma mutação que o próximo implementador roda no cenário errado e declara observada.

**Protocolo de mutação sobre cópia, com controle de mutação e recontrole.** O nome anterior ("restauração por checksum") descrevia errado o que o protocolo faz — ele nunca escreve em `$ORIG`; muta uma cópia e restaura descartando-a. Os quatro passos:

1. `cp "$ORIG" "$MUT"` e muta `$MUT`.
2. **Controle de mutação: antes de rodar, provar que o arquivo mudou** — a mutação que não muda nada mede o engano, e é exatamente `LDG-0164`. Rodei o passo nas duas direções, com a mutação (e) sobre uma bancada mínima de `DEPLOY_STAGES`, para que ele entre aqui como comando executado e não como prescrição:

   ```
   $ awk '{ sub(/ tag"/, "\""); print }' "$ORIG" > "$MUT"
   $ cmp -s "$ORIG" "$MUT" && echo "FAIL: a mutação não aconteceu" || echo "OK: cmp acusa diferença"
   OK: cmp acusa diferença
   $ bash "$ORIG"; bash "$MUT"          # a bancada conta com `wc -w`, daí o alinhamento
        13
        12

   $ awk '{ sub(/ inexistente"/, "\""); print }' "$ORIG" > "$MUT2"     # o caso patológico
   $ cmp -s "$ORIG" "$MUT2" && echo "OK: cmp acusa MUTAÇÃO-FANTASMA"
   OK: cmp acusa MUTAÇÃO-FANTASMA

   $ rm -f "$MUT" "$MUT2"; bash "$ORIG"                                  # passo 4, recontrole
        13
   ```
3. Roda contra `$MUT`, observa a acusação.
4. Descarta `$MUT`, roda de novo contra `$ORIG` e **exige o verde de volta**. Sem esse recontrole a prova não vale — `feedback-mutacao-fantasma-restore` registra o caso do `restore()` quebrado que deixou a mutação eterna e ninguém viu. Onde a mutação exige cenário (a coluna nova da matriz), o recontrole roda **no mesmo cenário**: recontrolar a (c) no caminho feliz provaria que o engine íntegro passa quando nada reprova, que é justamente o que a mutação não estava medindo.

**Restrição sobre `perl -0pi -e`, herdada de `LDG-0164` e obrigatória aqui:** todo `$` no lado **direito** do `s///` é variável do **perl**, e variáveis do perl não definidas são vazias — `s/x/$1cp "$a" "$b"/` vira `cp "" ""`. Nas seis mutações acima, use `\$` para todo cifrão literal, ou prefira substituição por `awk`, que não tem essa armadilha. O passo 2 do protocolo pega isso, mas pegar depois de escrever é caro.

---

## 8. Contador de controle — denominador triplo, e por que o literal fica no gate

O contador de estágios tem **três ancoradouros independentes**, e a asserção `[9]` exige que os três coincidam:

1. **O literal `13`, escrito no gate.** É a única âncora que **não** deriva de `DEPLOY_STAGES` e por isso a única que sobrevive a uma mutação da constante. Escrevê-la não é a redigitação que a invariante 3 proíbe: a invariante proíbe o gate **contar sozinho** o que o código declara, criando um número que ninguém confere; aqui o literal é o valor **contratual** contra o qual os derivados são conferidos, e mudar o número de estágios passa a ser, de propósito, uma mudança que exige editar a lib **e** o gate. O cabeçalho do gate declara isso em letra, para que o próximo leitor não "melhore" a asserção removendo o literal.
2. **`stages_declared`, lido de `DEPLOY_STAGES`** em `deploy-common.sh` pelo próprio gate. A **propriedade** é que o número saia da constante da lib, sem redigitação e sem passar pelo manifesto; o **primitivo** de extração é escolha do implementador, que prova a discriminação com a mutação (e) — removido um nome da constante, este ancoradouro cai para 12 enquanto o literal do gate permanece 13, e é essa divergência que `[9]` acusa. Um extrator que continuasse devolvendo 13 sobre a constante mutilada seria detectado no mesmo passo, porque o controle de mutação exige que o valor **mude**.
3. **A contagem de linhas `stage.<nome>:` do manifesto**, que é `stages_examined`. Mede a **cobertura do recibo** sobre `DEPLOY_STAGES` — sempre as treze, inclusive os estágios que uma interrupção não alcançou, gravados como `inconclusive` (seção 5.4) —, e não quantos estágios executaram. A redação anterior dizia "mede o que a execução de fato percorreu", e isso era falso justamente nos desfechos que a seção 5.2 manda interromper antes de `build`, que são três dos treze vermelhos declarados; quem diz o que executou é o veredito de cada linha.

A asserção é `literal == stages_declared == linhas_stage == stages_examined == 13`, e cada estágio tem veredito em `{passed, failed, inconclusive, skipped-declared}`. Se a lib passar a declarar quatorze e o manifesto continuar com treze, reprova. A regra do `skipped-declared` tem **fonte de motivo por classe de estágio** (a tabela da seção 5.1, que é a fonte): nos **onze** estágios de mecânica, `skipped-declared` sem motivo em `runtime.deploy.skip.<estagio>` é convertido em `failed` e o assert `[15]` o prova; nos **dois** estágios de fase o motivo mora na `empty-universe-allowlist.txt` e é lido por `forge_universe_waiver`, e isenção anônima cai em `inconclusive` — o caso 5 da seção 4(f), provado pelo `[24]`. Escrever a regra sobre "estágio qualquer" era o que a punha em contradição com o desfecho verde do caso 4.

Os outros dois contadores:

- **Adaptadores.** `forge_universe_check "deploy-adapters" <n> "adaptador(es)" "lib/ci"` — universo vazio reprova por construção, e o assert exige `n >= 2`, porque um adaptador só não prova interface nenhuma.
- **Asserções do gate.** O gate publica quantos blocos executou e reprova se o número divergir do total declarado no cabeçalho — a lição da Fase 0 é que o cabeçalho envelhece. O caso que a sustenta é ancorado em commit, pela mesma razão do gêmeo da seção 5.5 — a spec o escrevia contra `HEAD` e a árvore de trabalho, e a Fase 0 foi commitada em `c41eead` entre a revisão 3 e esta, de modo que o par de comandos publicado deixou de discriminar:

```
$ git show c41eead^:docs/plans/spikes/strix-pentest-spec.md | sed -n '22p'
| D8 | Gate novo de pré-voo do perfil strix, **23** asserções, ordinal resolvido no momento da implementação | §7 |

$ git show c41eead:docs/plans/spikes/strix-pentest-spec.md | sed -n '22p'
| D8 | Gate novo de pré-voo do perfil strix, hoje em **30** asserções — 23 nesta decisão original, 27 após a correção de segurança achada no review adversarial, 30 após os três achados médios de 2026-09-07 —, ordinal resolvido no momento da implementação e fixado em `w206` após duas colisões (LDG-0167, LDG-0173) | §7 |

$ grep -cE '^echo "\[[0-9]+' tests/w206-strix-pentest-gate.sh
30
```

Em `c41eead^` a spec fixava **23** asserções enquanto o gate já rodava **30** blocos. Que o exemplo tenha envelhecido duas vezes — uma na revisão 3 por tempo verbal, outra nesta por o commit ter acontecido — é a própria lição em ato: um número no cabeçalho que ninguém confere mecanicamente envelhece dentro da onda que o escreve, e um **comando** que depende do estado móvel da árvore envelhece junto. A lição sobrevive ao conserto — um total no cabeçalho que ninguém confere mecanicamente envelhece dentro da própria onda que o escreve —, e é por isso que o `[26]` confere o contador contra o denominador em vez de confiar no cabeçalho. Esse contador só tem sentido com um denominador, e o denominador é a seção 8.1: **27 blocos, `[0]` a `[26]`**.

O cenário reproduzido na seção 2.2 fixa um quarto denominador, o do fechamento de `LDG-0160`: **3 gates declarados em 3 fases; hoje 1 executado pelo caminho de produção; depois desta onda, 3**. Esse denominador é fixo por construção — ele é o cenário do próprio gate, montado pelo fixture —, e é o único tipo de literal que esta spec aceita numa asserção.

**Regra que vale para todos os números desta spec, e que a varredura desta rodada aplicou linha a linha:** literal numa asserção só é legítimo quando é denominador de cenário do próprio gate (os 3 gates da fixture, os 13 estágios, os 27 blocos, o K = 41 do manifesto, as 6 variantes de digest), porque nesses casos a divergência **é** o achado. Literal que conta a árvore — arquivos rastreados, gates em `tests/`, entradas de lockfile, consumidores instalados — envelhece, muitas vezes na própria onda que o escreve, e por isso a seção 11 passou a expressar esses como **propriedade mais piso**, ou como derivação no momento da execução.

**A varredura desta rodada acrescentou uma terceira classe, que as duas anteriores não tinham nome para tratar: o literal que mora em documentação e é apenas AFIRMADO por um gate.** É o `scripts/ (136)` do `README.md`, conferido pelo `w200`. Ele não aparece em `tests/` — greps de literal em `tests/` passam por cima dele —, e é por isso que a varredura anterior concluiu, e escreveu como medição, que o piso do `npx-pack-gate` era o único literal de contagem do template na suíte. **A regra de varredura passa a ser: procurar o literal e, separadamente, procurar quem afirma o literal**, porque o número pode morar na documentação e o gate ser só o verificador. A forma correta para essa classe não é piso, é **igualdade com os dois lados remedidos no mesmo commit pelo comando do próprio gate** — e ela entrou na tabela da seção 11 e na definição de pronto.

**Números que este documento publica e que NÃO são cobrados em asserção nenhuma** ficam declarados aqui para que ninguém os promova por engano a critério: as 383 linhas e os 14 blocos `bash` do `deploy-orchestrator.md` (seção 3), os 134 arquivos sob `tests/` e os 131 que casam `tests/*-gate.sh` (seção 11), as contagens de binários espelhados das bancadas — 960 com os oito nomes pulados, 961 com sete, 961 no espelho sem `node` (seções 4(e) e 4(f)) —, a **projeção** de 136 para 142 em `template/.forge/scripts/` (seção 11, onde o que se cobra é a igualdade remedida pelos dois lados) e as 65 linhas de comando com saída que a seção 20 contabiliza são **relatórios de medição do dia**, úteis para dimensionar o trabalho e inúteis como asserção. A definição de pronto da seção 15 não cita nenhum deles, e é essa a fronteira.

### 8.1 Inventário das asserções do gate — 27 blocos, `[0]` a `[26]`

A revisão 1 reprovou a ausência desta lista, e com razão: a seção 6 anterior remetia a "a lista completa está na seção 8" e a seção 8 não tinha lista nenhuma, o que deixava o autoteste do contador sem denominador. O total é **27** — eram 25 na revisão 2, mais `[24]` (universo de fase vazio, do bloqueador novo 1 da revisão 2) e `[25]` (lib irmã ausente, do bloqueador novo 2), com o autoteste do contador deslocado para `[26]` —, e é este número que o cabeçalho do gate declara e que o bloco `[26]` confere. O parágrafo anterior atribuía `[25]` ao universo vazio e `[26]` à lib irmã, contradizendo a tabela abaixo e a tabela de vermelhos da seção 6; a **tabela é a fonte**, ela está íntegra (27 linhas, índices `[0]` a `[26]`, sem buraco nem repetição) e o parágrafo é que estava errado.

| # | O que prova |
|---|---|
| `[0]` | Arnês: o `PATH` de fixture não alcança `gh`, `gcloud`, `docker`, `helm`, `kubectl`, `trivy`, `cosign` **nem `git`** — espelho de `/usr/bin` e `/bin` por symlink pulando os **oito** por NOME, com contador de binários espelhados e prova sintética da regra de exclusão contra um diretório de origem que TEM um deles. São oito e não sete porque o stub de `git` mora no mesmo diretório do espelho: pular só sete deixa ali um symlink para o git real e instalar o stub por cima **escreve através do symlink**, medido na seção 4(e). Mais o stub de passagem do `git`: intercepta só `tag` e `push`, faz `exec` do git real (caminho absoluto capturado antes da reescrita do `PATH`) para todo o resto, com controle positivo (`git rev-parse --abbrev-ref HEAD` devolve o branch do fixture) |
| `[1]` | bash 3.2: `bash -n` limpo nos **sete** arquivos novos (`deploy.sh`, `lib/deploy-common.sh`, `lib/timeout.sh`, `lib/ci/github-actions.sh`, `lib/ci/cloud-build.sh`, `lib/ci/local.sh`, e o próprio gate) e nenhuma construção de bash 4+ (`declare -A`, `${v,,}`, `${v^^}`, `mapfile`, `readarray`) fora de comentário |
| `[2]` | Parsing de argumentos: as guardas de `lib/arg-guards.sh` fiadas sem reimplementação, com a mensagem delas preservada em stderr; `--approved-by --dry-run`, `<env>` fora de `{dev,stg,prd}` e `--sha` vazio reprovam com **rc 2** (as guardas saem 1 por construção — a tradução é obrigação de `deploy.sh`, seção 5.2); e **nenhum** manifesto é gravado em nenhum rc 2. Controle positivo pareado: `--approved-by` com valor legítimo atravessa e o deploy segue |
| `[3]` | `ci_provider` declarado cujo arquivo de adaptador não existe (`gitlab`) → rc 2, sem manifesto, e a recusa **nomeia** os adaptadores disponíveis. Mais: `runtime.deploy` ausente com módulo nominal → rc 2, sem manifesto |
| `[4]` | Adaptador presente cujo `ci_available` devolve rc 1 → rc **4**, manifesto **gravado** com `ci_provider_available: no` e `verdict: inconclusive`; `ci_available` rc 2 → rc 4 com `ci_provider_available: unknown`; e em ambos o trace **não tem nenhuma** linha de `helm` ou `kubectl` |
| `[5]` | A fase `pre-deploy` foi invocada (marca positiva no trace) **e** a marca **precede** a primeira linha de `helm` |
| `[6]` | O veredito da fase `pre-deploy` é respeitado: gate marcador com rc 1 → `deploy.sh` rc 3, `verdict: fail`, zero linhas de `helm`/`kubectl` no trace |
| `[7]` | A fase `post-deploy` foi invocada, a marca aparece **exatamente uma vez** no trace e **sucede** a linha de `kubectl rollout`. A contagem exata não é preciosismo: medi que a mutação (b) produz **duas** marcas de post-deploy, a primeira antes do `helm`, e sem a contagem essa fiação trocada satisfaria a asserção |
| `[8]` | Reprovação da fase `post-deploy` → `rollback: performed` no manifesto e rc 3 |
| `[9]` | Denominador triplo dos estágios: literal `13` do gate `==` `stages_declared` lido de `DEPLOY_STAGES` `==` linhas `stage.` do manifesto `==` `stages_examined`; e todo veredito de estágio pertence a `{passed, failed, inconclusive, skipped-declared}` |
| `[10]` | Contrato da interface do adaptador: o conjunto de funções `ci_*` **definidas** em cada adaptador é igual ao conjunto **chamado** por `deploy.sh`, nas duas direções; e `forge_universe_check "deploy-adapters"` com `n >= 2` |
| `[11]` | Substituibilidade dos provedores (detalhe na seção 9.2, item 3) |
| `[12]` | Manifesto: gravado em `.forge/cache/deploy/<run_id>/deploy.txt` nos rc 3, 4 e no rc 0 **com `runtime.deploy` declarado** — o rc 0 do pulo declarado sob `--from-config` não grava e não entra nesta asserção —, com **K = 41 linhas**, os 25 campos fixos na ordem, as 13 linhas `stage.`, os 3 finais. O 41 é o valor **contratual** que o gate escreve, do mesmo jeito e pela mesma razão que o literal `13` do `[9]`; o K que `deploy.sh` confere internamente é o derivado (seção 5.4), e é a divergência entre os dois que o `[12]` existe para pegar; `image_digest` igual ao digest devolvido e validado; `engine_sha256` cobrindo os três arquivos do engine; `run_id` na forma `<UTC compacto>-<8 hex>` |
| `[13]` | Validação de formato do digest em `deploy_digest_validate` (`lib/deploy-common.sh`, o **único** dono da validação): as **cinco** variantes malformadas do `w206[8]` — 63 hex, **65 hex**, hex maiúsculo, sem prefixo, vazio — são **recusadas**, e 64 hex minúsculos passa. É o assert que as mutações (d) e (f) mordem; a de 65 hex é a única que separa um regex com âncora de fim de um sem |
| `[14]` | Precedência: `failed` vence `inconclusive` no caso MISTO, nas **duas** ordens de ocorrência (a reprovação antes e depois do primeiro inconclusivo), no `verdict` do manifesto e no rc — molde do `w206[29]` |
| `[15]` | `skipped-declared` exige motivo, e a fonte é por classe de estágio (tabela da seção 5.1): **nos onze estágios de mecânica** o motivo mora em `runtime.deploy.skip.<estagio>`, e sem motivo o estágio vira `failed` e o deploy sai 3. Os **dois** estágios de fase não são cobertos por este bloco — neles o motivo vem da `empty-universe-allowlist.txt` e a isenção anônima cai em `inconclusive`/rc 4, o que o `[24]` prova. Controle positivo pareado: com o motivo declarado o mesmo estágio sai `skipped-declared` e o deploy segue |
| `[16]` | Sanitização do manifesto: `\n` e `\r` em `module`, `env`, `sha` e `approved_by` não criam linha nova, e um `approved_by` contendo `\nverdict: pass` não produz um `verdict` fantasma antes do real |
| `[17]` | `deploy_preflight` sem curto-circuito: com quatro pré-condições violadas ao mesmo tempo, a saída nomeia as **quatro** |
| `[18]` | `--dry-run`: nenhuma linha de `helm upgrade` ou `kubectl apply` no trace; manifesto com `dry_run: yes` e `verdict` coerente |
| `[19]` | O invólucro do `staging.yml`, **ancorado na linha que invoca `deploy.sh`** e nunca no arquivo (medi que o arquivo pós-reescrita contém `staging` quatro vezes de forma legítima): naquela linha o token de ambiente é `stg`, e a linha existe; com `runtime.deploy` ausente o corpo sai 0, imprime a linha de pulo declarado e não deixa `helm`/`kubectl` no trace; com `runtime.deploy.module` declarado o mesmo corpo invoca `deploy.sh` com o módulo resolvido; o corpo roda com `GITHUB_SHA` definido pela bancada, e o caso pareado de `--sha` vazio recusa com rc 2 |
| `[20]` | Paridade de conteúdo `DEPLOY_STAGES` × `deploy-wave.md` × `plugin/forge/commands/deploy-wave.md`: conjunto contra conjunto, nas duas direções |
| `[21]` | `run_to`: o corpo da função em `lib/timeout.sh` e em `pentest-ops.sh` é textualmente igual depois de normalizar espaço em branco, com não-vacuidade (as duas extrações não vazias) — a duplicação declarada na seção 5.1 não pode divergir em silêncio |
| `[22]` | PBT, propriedade 1 (sanitização preserva K = 41 linhas), com seed fixa registrada no gate |
| `[23]` | PBT, propriedade 2 (conservação do contador sob permutação e atribuição gerada de vereditos), com seed fixa registrada no gate |
| `[24]` | Universo de fase vazio (bloqueador novo 1): fixture **sem nenhum gate de fase declarada** e **sem isenção** → a chamada de fase acontece mesmo assim, o estágio sai `inconclusive`, `deploy.sh` sai **4**, o manifesto grava `gates_pre_deploy: 0` e `verdict: inconclusive`, e o trace **não tem nenhuma** linha de `helm`/`kubectl`. Mais as duas irmãs da tabela da seção 4(f): isenção **com `# motivo:`** → `stage.gates-pre-deploy: skipped-declared`, `gates_pre_deploy: 0` no recibo, rc 0, e **o texto do motivo — o da própria fixture, não o rótulo de `gate-universe.sh` — presente na saída de `deploy.sh`**, com o contrafactual da fiação que engole a saída (`out="$(run-gates.sh …)"`), que devolve o mesmo rc e perde o motivo; isenção **anônima** → `inconclusive` e rc 4. Mais o pareado da inércia do `skip` (seção 5.1): com `runtime.deploy.skip.gates-pre-deploy` declarado e nenhuma isenção na allowlist, o desfecho é idêntico ao do caso 3 — `inconclusive` e rc 4 —, e um `skipped-declared`/rc 0 aqui acusa a segunda porta de isenção |
| `[25]` | Lib irmã ausente (bloqueador novo 2): removida **uma** lib de maquinaria da cópia espelhada, `deploy.sh` sai **5**, a mensagem **nomeia o arquivo faltante**, **nenhum** manifesto é gravado e o trace não tem `helm`/`kubectl`. Controle positivo pareado: com as libs todas presentes o mesmo fixture sai 0 — sem ele o assert ficaria verde sobre um `deploy.sh` que recusa sempre |
| `[26]` | Autoteste do contador: o gate publica quantos blocos executou e reprova se o número divergir de **27** |

`deploy.sh` **não** é declarado como gate em lugar nenhum — nem em `runtime.gates` do template, nem em hook, nem em workflow além do invólucro do `staging.yml`. Isso é conferido dentro de `[19]`, junto com o invólucro, porque as duas afirmações são sobre o mesmo assunto: onde o deploy pode e não pode ser disparado.

---

## 9. Onde entra cada camada de teste

### 9.1 PBT — aplica-se, em dois pontos

**Propriedade 1 — a sanitização do manifesto preserva a estrutura.** Para qualquer valor gerado de `module`, `env`, `sha` e `approved_by` (incluindo `\n`, `\r`, `:`, aspas, e UTF-8 acentuado), o manifesto renderizado tem **exatamente 41 linhas** (K da seção 5.4), e nenhuma linha além das 41 tem a forma `<chave>: <valor>` de um campo conhecido. É a família "invariante estrutural" da tabela de `rules/testing/property-based-testing.md`, e é o caso que exemplo escolhido a dedo não pega — ninguém escreve à mão um `approved_by` com `\nverdict: pass` dentro.

**Propriedade 2 — o contador é conservado.** Para qualquer permutação e qualquer atribuição gerada de vereditos aos treze estágios, `stages_examined == stages_declared == 13`, e o `verdict` resultante obedece à tabela de precedência da seção 5.2. Família "invariante de conservação".

Ferramenta: `lib/pbt.mjs` (zero-dep, seed explícita, shrinking), já usada por `w121`, `w130` e `w132`. Seed fixa registrada no gate — falha de PBT que não reproduz é falha que ninguém depura.

### 9.2 Teste de contrato — aplica-se, em três fronteiras publicadas

1. **`run-gates.sh` não muda.** O golden capturado em `tests/fixtures/w171` continua byte-idêntico (`cmp`) com `deploy.sh` instalado. **Classificação honesta, corrigida depois da revisão 1:** esta onda **consome** o seletor de fase e não o altera, então o golden não pode falhar por nada que a onda faça — ele é **guarda de regressão**, não evidência da entrega, e por isso saiu da definição de pronto da seção 15. Mantê-lo é correto; contá-lo como prova de que a onda funciona não é.
2. **`forge.schema.json` ganha `runtime.deploy`.** O bloco novo (`module`, `ci_provider`, `ci_provider_path`, `registry`, `chart_root`, `skip.<estagio>`) entra no schema com teste que reprova quando o contrato quebra. Nota herdada de `LDG-0159`: o campo `phase` de `runtime.gates` aceita qualquer string de propósito, para não reprovar o que o leitor lê; **agora que existe executor, o enum de fases passa a ser possível**, e a decisão de fechá-lo é registrada como item de ledger próprio desta onda, não executada aqui — fechar o enum é mudança de contrato com adotante instalado e merece o próprio ciclo.
3. **A interface do adaptador é contrato, e a substituibilidade é medida em campos nomeados.** O assert `[10]` extrai o conjunto de funções `ci_*` definidas em cada adaptador e o conjunto chamado por `deploy.sh`, e exige igualdade nas duas direções: adaptador que define função a mais tem código morto, adaptador que define a menos quebra em execução, e `deploy.sh` que chama função fora do conjunto acopla-se a um provedor. O assert `[11]` mede a substituibilidade em duas metades, **com os campos tolerados nomeados** — a revisão 1 reprovou "os três esperados" sem definição, e ela estava certa: sem nomear, o implementador fixaria o conjunto de tolerância depois de ver a divergência observada, e a asserção viraria carimbo do resultado:
   - **(i)** o manifesto das duas execuções é comparado linha a linha e só pode divergir em **exatamente quatro campos, nomeados aqui e em nenhum outro lugar**: `ci_provider`, `ci_run_ref`, `ci_run_url` — os três que nascem do adaptador — e `engine_sha256`, que **tem** de divergir porque o adaptador carregado entra no resumo do engine (seção 5.4). A revisão 2 apontou, com razão, que a redação anterior dizia "exatamente três" e dois períodos depois chamava o `engine_sha256` de "quarta e última exceção", e que o implementador literal escreveria o assert com três: o número é **quatro**, e a mensagem de vermelho de `[11]` na seção 6 nomeia os quatro. Separadamente, e antes da comparação, o gate **normaliza** os três campos não determinísticos **por construção** — `run_id`, `generated_at` e `duration_s`. A propriedade é que o valor desses três seja substituído por um marcador constante antes do `diff`, de modo que a comparação não possa passar nem falhar por causa deles; o **primitivo** de substituição é escolha do implementador, e a prova de que ele funciona é o controle positivo de não-vacuidade descrito abaixo, que precisa acusar mesmo com a normalização ligada. Normalizar não é tolerar, e por isso eles não entram na conta dos quatro. Todo o resto é byte-idêntico.
   - **(ii)** a projeção do trace sobre os participantes **neutros de provedor** (`helm`, `kubectl`, `trivy`, `cosign`, `git`, e as duas marcas de fase) é byte-idêntica entre os dois provedores.
   - **Controle positivo de não-vacuidade:** o gate roda uma terceira execução em que o stub de `gcloud` devolve um `image_ref` com outro registry, e **exige** que `[11]` acuse `FAIL [11]: manifesto diverge em image_ref, além dos quatro tolerados (ci_provider, ci_run_ref, ci_run_url, engine_sha256)`. Sem esse controle, `[11]` seria verde sobre dois adaptadores que produzem manifestos idênticos por acidente de fixture.

### 9.3 Teste de integração — é o coração da onda

`deploy.sh` × `run-gates.sh` **real** (não stub) × `FORGE.md` de fixture × gates marcadores reais. É o único jeito de o teste dizer algo sobre `LDG-0160`: o defeito é de fiação, e teste unitário sobre `forge_runtime_gates_phase` nasce verde (medido na seção 2.2 — o motor funciona).

### 9.4 E2E — aplica-se, com stubs

`deploy.sh <modulo> dev` do `argv` ao manifesto, com todos os binários externos stubbed, **nos dois provedores**, verificando o trace completo e o recibo. É o E2E possível sem cluster, e a fronteira é declarada em letra: ele prova que a mecânica está fiada e ordenada, não que o cluster aceitou o rollout. Quem prova a segunda metade é o piloto.

### 9.5 O que **não** se aplica, com justificativa medida

**Teste contra provedor real no gate.** Zero credencial disponível no runner da suíte, e o próprio `axis-go-cloud` registra em `_template-cd-helm-deploy.yml:27` que o "CI está bloqueado por billing no momento — workflow validado por actionlint/helm lint". Um gate que dependesse de provedor real seria um gate permanentemente inconclusivo, e gate permanentemente inconclusivo é gate desligado. A cobertura real vem do piloto, e a lacuna é nomeada, não escondida.

---

## 10. Retrocompatibilidade

| O que já está instalado | O que esta onda faz com ele |
|---|---|
| `.github/workflows/staging.yml` em 10 de 13 consumidores (8 idênticos, 2 customizados) | **nada** para quem já instalou: `bin/forge.mjs:835` só copia sob `if (!existsSync(dst))` e só no caminho de instalação. Para **instalação nova**, o invólucro da seção 5.3 é o que chega — e ele foi desenhado para sair 0 com motivo declarado quando `runtime.deploy` não existe, que é o estado de todo projeto recém-instalado (o `runtime:` do `template/.forge/FORGE.md` vai de `primary_stack` a `gates:` sem bloco `deploy`). O assert `[19]` trava isso |
| `.github/workflows/red-first.yml` (0 de 13 instalados) | **nada.** Não é removido, não é substituído, não ganha equivalente em shell (seção 12) |
| `runtime.gates` em forma CSV escalar | intocado. `run-gates.sh` não muda; o golden do `w171` é guarda de regressão (seção 9.2, item 1) |
| `runtime.gates` com `phase:` (0 de 13 consumidores, remedido) | passa a ser **executado** — mudança de comportamento com zero adoção instalada, portanto zero quebra medida em `run-gates.sh`. **A revisão 2 mostrou que o argumento parava aqui e precisava continuar:** a mesma adoção zero faz a chamada de fase que `deploy.sh` cria cair na guarda de vacuidade de `run-gates.sh:66-72`. Isso não quebra nada instalado — `deploy.sh` é maquinaria nova, sem chamador —, mas define o desfecho do **primeiro** uso, e ele agora está escrito: rc 4, `verdict: inconclusive`, `gates_pre_deploy: 0` no recibo, `helm` e `kubectl` intocados (seção 4(f)) |
| `.forge/scripts/run-gates.sh` **ausente** em 9 de 13 consumidores | `deploy.sh` chega junto com `run-gates.sh` pelo mesmo `update` de maquinaria, então quem receber um não fica sem o outro. Para o caso residual — instalação parcial, poda interrompida — o desfecho é o caso 6 da seção 4(f): rc 127 da invocação, estágio `inconclusive`, e o pré-voo de lib irmã da seção 5.1 recusa antes com rc 5 quando o que falta é a mecânica |
| `.forge/empty-universe-allowlist.txt` (1 de 13 consumidores) | intocado, e promovido a **única** fonte de motivo dos dois estágios de fase (tabela da seção 5.1). É por onde um projeto declara que não tem gate de fase **com motivo**, e `deploy.sh` nunca escreve nesse arquivo, nunca passa isenção própria e nunca aceita `runtime.deploy.skip` no lugar dela (seção 4(f)) |
| `.forge/scripts/` (maquinaria, sobrescrita por `update`) | recebe `deploy.sh`, `lib/deploy-common.sh`, `lib/timeout.sh` e `lib/ci/*.sh` no próximo `update`. Cópia local de mesmo path é sobrescrita; arquivo extra sobrevive (poda por tombstone curado) |
| `deploy-orchestrator.md` e `deploy-wave.md` | reescritos. Risco de campo medido: **zero tag `deploy-*`** em qualquer repositório com `platform/helm/` — o pipeline de dez gates nunca produziu um deploy registrado |
| `pentest-ops.sh:94` (`run_to`) | **intocado nesta onda.** A extração proposta na revisão 1 reprovava o `w206[21]` (medido: `grep -c "perl -e 'alarm"` cai para 0 numa cópia sem a definição) e degradava em silêncio as onze cópias nuas do engine que o `w206` executa (medido: o `source` falha, `set -uo pipefail` sem `-e` não aborta, `rc=0`). `lib/timeout.sh` é a casa de `run_to` para código novo; a convergência vira item de ledger, e o assert `[21]` impede divergência silenciosa enquanto as duas convivem |

---

## 11. Ordinal, fiação e efeitos colaterais na suíte

**Ordinal.** Máximo publicado remedido em 2026-09-07 com `git ls-tree -r --name-only <ref> -- tests`, sobre todas as refs locais e remotas: **`w207`** em `origin/develop`, `origin/main`, `develop`, `main` e na branch em voo `fix/strix-achados-medios`; as duas outras branches remotas (`wip/deepspec-run-manifest-ldg-0165`, `wip/upgrade-safety-ldg-0131`) estão em `w80` e `w154`. O nome do gate é `tests/w<NN>-deploy-portability-gate.sh`, com `<NN>` **alocado pelo orquestrador no momento de escrever o arquivo** e conferido contra `origin/*` **e** contra as branches em voo desta rodada — é o defeito de `LDG-0167`/`LDG-0173`, e esta rodada tem várias frentes escrevendo gate ao mesmo tempo.

**Fiação.** `tests/run-all.sh` descobre gates por `ls tests/*-gate.sh`; o arquivo entra na suíte pelo nome, sem registro manual. O `deploy.sh` **não** entra em `runtime.gates` do template, nem em hook, nem em nenhum workflow além do invólucro do `staging.yml`: deploy é ferramenta manual operada por humano, como `/forge:dev` e `/forge:pentest`. O assert `[19]` trava isso.

**Efeito colateral, com o "antes" medido — a revisão 1 apontou que ele faltava, e faltava mesmo.** São **sete** arquivos de shell novos, não quatro nem cinco (e a onda commita mais que sete arquivos, ponto que a revisão 2 achou e que a tabela abaixo resolve): `deploy.sh`, `lib/deploy-common.sh`, `lib/timeout.sh`, `lib/ci/github-actions.sh`, `lib/ci/cloud-build.sh`, `lib/ci/local.sh` e o próprio `tests/w<NN>-deploy-portability-gate.sh`. Errar a contagem numa seção cujo assunto é a variação de contadores seria o próprio defeito que a onda combate, então os números de partida ficam registrados aqui, medidos nesta rodada pelo mesmo coletor que os gates usam:

```
$ node -e "(async()=>{const {pathToFileURL}=require('url');
  const L=await import(pathToFileURL('template/.forge/scripts/lib/shell-pipeline-lint.mjs').href);
  console.log('shell-pipeline raiz', L.collectShellFiles(['.']).length,
              '| template/.forge/scripts', L.collectShellFiles(['template/.forge/scripts']).length);})()"
shell-pipeline raiz 226 | template/.forge/scripts 73

$ node -e "(async()=>{const {pathToFileURL}=require('url');
  const H=await import(pathToFileURL('template/.forge/scripts/lib/heredoc-hash-lint.mjs').href);
  console.log('heredoc-hash raiz', H.collectShellFiles(['.']).length);})()"
heredoc-hash raiz 226

$ git ls-files | grep -c .
1168
```

**O último número mudou entre a revisão 3 e esta rodada, e a mudança é a prova de que a forma de propriedade estava certa.** Na revisão 3 este comando devolvia **1167**; hoje devolve **1168**, porque `c41eead` — commit de outra frente, na mesma noite — acrescentou `docs/plans/2026-09-07-backlog-zero.md` ao índice. Conferi que a causa é essa e não outra:

```
$ git ls-tree -r --name-only c41eead^ | grep -c .
1167
$ git ls-tree -r --name-only HEAD | grep -c .
1168
```

Se a definição de pronto ainda cobrasse `1167 → 1174`, ela já estaria falsa antes de a onda começar, por trabalho que a onda não fez. É exatamente o que a invariante 14 descreve, observado dentro da própria rodada.

**A tabela de delta da revisão 2 era aritmeticamente impossível, e a revisão 3 a substitui por propriedade mais piso.** O revisor está certo e remedi as duas pontas: `check-secrets.sh:142` deriva `n_files` de `git ls-files` (`n_files="$(grep -c . "$FILELIST")"`, com `$FILELIST` vindo de `git -C "$ROOT" ls-files`), então o universo dele cresce com **todo arquivo rastreado que a onda commitar**, não só com os sete `.sh`; e a onda commita muito mais que sete arquivos. Medi o que ela commita além da maquinaria:

- **os artefatos do change SDD** que o passo 1 da seção 14 exige: nos cinco changes que amostrei em `.forge/specs/archived/`, cada um carrega de **6 a 19** arquivos rastreados, e o diretório inteiro tem 160;
- **a evidência de red-first** do passo 3, cujos `evidence/runs/<id>/run-manifest.json` também são rastreados — hoje há 14 arquivos sob `evidence/runs/` no `git ls-files`;
- **esta própria spec**, que está **untracked** hoje (`git ls-files --error-unmatch` devolve `Did you forget to 'git add'?`) e vira arquivo rastreado ao commitar.

Com "1167 → 1174" na definição de pronto, a seção 15 mandaria tratar como **achado** uma divergência que é garantida por construção — o que produz achado fantasma na entrega e convida ao ajuste silencioso do número, que é o defeito que esta onda combate. A forma correta:

| Contador | Universo medido em 2026-09-07 | O que a onda exige depois | Por quê esta forma |
|---|---|---|---|
| `check-shell-pipeline` (`forge_universe_check "shell-pipeline"`) | **226** arquivos `.sh`/`.bash` na raiz | `n_depois == n_antes + 7`, com `n_antes` **remedido no mesmo commit** pelo comando publicado acima, e piso `n_depois >= 233` | o coletor caminha o **sistema de arquivos**, não o `git ls-files` — conferi que hoje os 226 são todos rastreados, mas um `.sh` untracked de outra frente em voo entra na conta sem estar no commit |
| `check-heredoc-hash` (`forge_universe_check "heredoc-hash"`) | **226** (mesmo coletor) | idem, `+7` e piso `>= 233` | idem |
| `w200-readme-inventory-gate` (linha `scripts/ (N)` do `README.md`) | **136** arquivos sob `template/.forge/scripts` pelo critério do gate (`find … -type f ! -name 'README.md'`) | igualdade entre o número declarado e o que o comando do gate devolve, os **dois** remedidos no mesmo commit; o 142 é **projeção do dia** (136 remedidos hoje mais os seis da onda), não alvo cobrado — qualquer frente em voo que acrescente arquivo ali antes do commit muda o número sem invalidar a propriedade | é o único contador desta lista cujo lado declarado mora em documentação e não em código; o gate deriva os dois lados na execução, então a forma correta é a igualdade remedida, não um piso |
| subconjunto `template/.forge/scripts` | **73** arquivos `.sh` | `+6` exatos (os sete menos o gate, que mora em `tests/`), piso `>= 79` | é o único recorte que a onda controla inteiramente: nada além da maquinaria entra aí |
| `check-secrets` (`n_files`, modo `path` na raiz) | **1168** arquivos rastreados (era 1167 na revisão 3; `c41eead` acrescentou um) | **`n_antes + 7 de maquinaria + N`**, com **N medido e declarado no PR** — os artefatos do change SDD, a evidência de red-first e esta spec. O que a definição de pronto cobra é a **propriedade**: `n_depois == n_antes + (arquivos que este commit acrescenta ao índice)`, conferida com `git ls-files \| grep -c .` antes e depois, e `n_depois > n_antes` como piso | o denominador é `git ls-files`, e um número fixo aqui envelhece **dentro da própria onda** |

**Toda divergência entre a propriedade e o observado é achado**, não ajuste — é o protocolo da Fase 1 do plano-mestre aplicado a esta onda. O que deixou de ser achado é a divergência de um literal que nunca poderia bater.

Duas notas de medição, ambas correções de literais meus que envelheceram entre a revisão 2 e esta:

1. Os 226 incluem **134** arquivos sob `tests/`, não 135 — conferido por três caminhos independentes que concordam (`collectShellFiles(['.'])` filtrado por prefixo, `find tests -type f \( -name '*.sh' -o -name '*.bash' \)`, e `git ls-files tests | grep -c '\.sh$'`). Dos 134, **131** casam `tests/*-gate.sh`. Errar essa contagem numa seção cujo assunto é a variação de contadores era o próprio defeito que a onda combate, e ele estava lá.
2. O piso `forgeCount < 200` de `tests/npx-pack-gate.sh:40` é **piso**, não igualdade, e a onda só o empurra para cima. É o modelo que a tabela acima copia. **A afirmação anterior — de que ele era "o único literal de contagem de arquivos do template em toda a suíte" — é falsa, e a varredura que a produziu tinha o defeito de método que a lição L2 existe para evitar:** ela grepou `tests/` atrás do literal, e o literal que esta onda envelhece mora no `README.md` e é apenas **afirmado** por um gate. O `tests/w200-readme-inventory-gate.sh` compara cada linha `<dir>/ (N)` do bloco `## 📁 Estrutura` com `find "$root/$dir" -type f ! -name 'README.md' | wc -l`, recursivo, sobre `template/.forge`. Conferi as sete linhas declaradas hoje com o mesmo critério do gate e todas batem:

```
$ for d in agents commands contracts skills rules schemas scripts; do printf '%s %s\n' "$d" "$(find "template/.forge/$d" -type f ! -name 'README.md' | wc -l | tr -d ' ')"; done
agents 47
commands 56
contracts 5
skills 20
rules 50
schemas 27
scripts 136
```

O `w200` está **verde agora** e a onda o derruba: os seis arquivos de maquinaria que ela acrescenta (`deploy.sh`, `lib/deploy-common.sh`, `lib/timeout.sh` e os três `lib/ci/*.sh`) levam `template/.forge/scripts/` de 136 para 142 — projeção do dia, no mesmo espírito dos números que o fim desta seção declara como não cobrados — contra 136 declarados, e o `[1]` do `w200` — o único cenário não hermético daquele gate — passa a acusar `FAIL: inventário do README defasado em 'template/.forge/scripts/'`. Conferi de passagem que a onda não mexe nos outros seis diretórios contados: ela reescreve `commands/coding/deploy-wave.md`, `agents/coding/deploy-orchestrator.md` e `rules/testing/gate-delivery-channel.md`, que já existem, e acrescenta arquivo apenas em `scripts/` e em `tests/`. O `README.md` entra na definição de pronto da seção 15, e o número declarado é **remedido no mesmo commit pelo comando do próprio gate** — `find`, não `git ls-files`, porque é o critério que o `w200` usa e um arquivo não rastreado sob `template/.forge/scripts/` entra na conta dele.

### 11.1 Gates rastreados que esta onda toca ou que afirmam o que ela muda

A revisão 2 não pediu esta subseção; ela é o resultado da varredura que a lição L2 desta rodada manda fazer — **antes de mudar qualquer string ou contrato que a produção publica, grepar `tests/` e nomear todo gate que a afirma**. Uma onda anterior quase deixou quatro gates rastreados vermelhos por trocar vocabulário sem varrer. O que a varredura devolveu, comando por comando:

| O que a onda muda | Gates que o afirmam (`grep -rln` em `tests/`) | Veredito medido |
|---|---|---|
| `template/github/workflows/staging.yml` — os três `echo` viram o invólucro da seção 5.3 | `w13-init-gate.sh:85`, `npx-pack-gate.sh:35` | **seguro sem edição.** Os dois asserem **existência** do arquivo (`[ -f ... ]` e presença no tarball), nunca conteúdo; a string `Pipeline de staging` não aparece em `tests/` nem em `template/` fora do próprio arquivo |
| `deploy-wave.md` e `deploy-orchestrator.md` reescritos | `tests/plugin-sync-gate.sh:[1][3]`; `tests/snapshot/claude-contract.bats` (bloco `C1`, linhas 41-48) | **seguro sob uma condição, e a atribuição anterior estava errada.** A condição real é `plugin-sync-gate[1]`: ele exige `plugin/forge` byte-idêntico ao regenerado, então `npm run build:plugin` **no mesmo commit** — é o gate que transforma "esqueci de regenerar o plugin" em vermelho, e já houve BLOCKER por isso neste repositório; o `[3]` acrescenta a cobertura (todo comando do template vira `/forge:*`, sem colisão). O bloco do `.bats` é o **`C1`**, não `C0`, e ele **não** impõe a restrição que a spec lhe atribuía: no modo `source` ele conta `$CMDS_DIR`, que é o snapshot congelado em `snapshot/project-bootstrap/.claude/commands` (medi: oito arquivos, `deploy-wave.md` entre eles), e no modo `generated` ele faz `skip`. Acrescentar ou renomear comando em `template/.forge/commands` **não** o reprova. Como a onda não acrescenta nem renomeia comando nenhum, nada muda na prática — o que muda é que a spec deixa de publicar cobertura que não existe, que é o defeito que a própria §11.1 recusa no item do `w192` |
| `forge.schema.json` ganha `runtime.deploy` | `w199-schema-reader-parity-gate.sh`, `w192-declared-switch-has-reader-gate.sh`, `w153-upgrade-safety-gate.sh:148`, `w20-spec-gate.sh:194`, `w112-liaison-session-gate.sh:53` | **exige que schema e `FORGE.md` do template mudem no mesmo commit.** Medi que `/runtime` tem `additionalProperties: false` e hoje oito chaves (`primary_stack`, `package_manager`, `run`, `test`, `typecheck`, `lint`, `gates`, `pentest`): um `FORGE.md` com bloco `deploy:` **reprova** contra `forgeFrontmatter` enquanto o schema não o declarar. O `w199` mede `/runtime/gates` e o `w153[75]` mede `heavy_mutex.root` — nenhum dos dois é afetado por uma propriedade irmã nova |
| `rules/testing/gate-delivery-channel.md` ganha o parágrafo da fronteira do `red-first` (seção 12) | sete gates o citam: `w190`, `w152`, `w206`, `w160`, `w155`, `w156`, `w168` | **seguro.** Conferi as sete ocorrências uma a uma: **todas em linha de comentário**, nenhuma assere o conteúdo da rule. E `validate-rules.mjs` só detecta drift de rule com `based_on: [ADR-NNNN]` no frontmatter — o frontmatter desta rule tem `title`, `applies_to`, `priority` e `last_reviewed`, e nenhum `based_on` |
| `README.md`, bloco `## 📁 Estrutura`, linha `scripts/ (136)` | `w200-readme-inventory-gate.sh:[1]` | **exige edição no mesmo commit.** A onda acrescenta seis arquivos a `template/.forge/scripts/` e o real passa a 142 — projeção do dia — contra 136 declarados; o `[1]` é o único cenário não hermético daquele gate e reprova com `inventário do README defasado`. O número declarado é remedido pelo comando do próprio gate (`find … -type f ! -name 'README.md'`), nunca por `git ls-files`. Nenhum dos outros seis diretórios contados muda |
| `.forge/cache/machinery.lock` passa a listar sete arquivos a mais | `w101-update-preserve-gate.sh:37-38` | **seguro.** O lock é gerado pelo `update` a partir do template, mora em `.forge/cache/` (não rastreado) e o gate assere só que ele **existe** |

**Um gate que a onda precisa editar, e a edição entra na definição de pronto.** `w192` afirma a propriedade "interruptor publicado tem leitor que decide algo", e `runtime.deploy` publica interruptores novos. Medi como ele decide: a lista `SWITCHES` é **literal** no gate (hoje duas chaves de `quality.`), e o predicado `_reader_hits` casa apenas a **folha** da chave (`${1##*.}`) contra `template/.forge/scripts/*.sh`, `template/.forge/scripts/lib/*.mjs`, `hooks/git/*`, `hooks/session/*` e `bin/*.mjs` — com as linhas de comentário removidas antes do casamento. Duas consequências, e as duas viram decisão escrita:

1. **A lista ganha `runtime.deploy.ci_provider` e `runtime.deploy.ci_provider_path`, e a regra de entrada passa a ser uma propriedade medida, não uma lista fechada.** Rodei o predicado do gate, tal como ele é hoje e tal como ficaria com `lib/*.sh` acrescentado, sobre as folhas candidatas:

   ```
   folha                              hoje    com lib/*.sh
   module                              24         25
   skip                                14         15
   registry                             0          0
   chart_root                           0          0
   ci_provider                          0          0
   ci_provider_path                     0          0
   require_unicorn_before_archive       0          0
   ```

   A medição corrige a spec em um ponto: só `module` e `skip` são folhas de palavra comum, e a afirmação anterior de que `registry` e `chart_root` também o eram está **errada** — as duas casam zero arquivos hoje. A regra que sobrevive à medição é a **propriedade**: uma chave só entra em `SWITCHES` quando a folha dela casa **zero** arquivos na árvore pré-onda, medido no momento da edição, porque só assim o casamento posterior prova o leitor e não o vocabulário. Por essa regra `ci_provider` e `ci_provider_path` entram com certeza; `registry` e `chart_root` são elegíveis e a decisão de incluí-las é do implementador, que paga a manutenção do gate em troca da cobertura; `module` e `skip` ficam de fora, porque nelas a verificação seria vacua e publicar cobertura inexistente é pior que não publicar.
2. **`_reader_hits` passa a varrer também `template/.forge/scripts/lib/*.sh`.** Hoje ele varre `lib/*.mjs` e não `lib/*.sh`, e metade da maquinaria do harness mora em `lib/*.sh` — é um buraco preexistente que esta onda encontra porque `deploy_digest_validate` e a leitura de `skip.<estagio>` moram lá. A extensão só pode **aumentar** o número de casamentos, então o `[1]` do `w192` não pode ficar vermelho por ela; e conferi por execução que o `[2]` (contrapositiva) também não corre risco: a chave sintética dele é `quality.require_unicorn_before_archive`, cuja folha casa **zero** arquivos com `lib/*.sh` já incluído na varredura, como a tabela acima mostra. O vermelho dessa edição é registrado antes de ela ser feita, como manda o passo 3 da seção 14.

O reforço do predicado do `w192` para casar o **caminho pontuado inteiro** em vez da folha — que é o que tornaria seguro declarar `module` e `skip` — não cabe aqui: é mudança no critério de um gate rastreado que governa chaves de outros blocos, e vira item de ledger próprio (seção 16).

---

## 12. O que a onda explicitamente NÃO faz

**Não remove o `red-first.yml` nem tenta reimplementar em shell a garantia que ele oferece — e isto é uma DIVERGÊNCIA declarada em relação ao plano-mestre, não o que ele pediu.** A revisão 2 apontou, com razão, que a spec escrevia esta decisão como se fosse o plano: o item 3 da seção "Onda K" pede que o `red-first.yml` "ganhe um equivalente para quem não usa Actions", e a linha 199 do plano diz que a onda deve "oferecer, para quem não usa Actions, o mesmo contrato num adaptador equivalente". A onda **não** entrega um segundo arquivo de configuração de CI, e o registro da divergência é este parágrafo.

**O que a onda entrega no lugar, e por quê é mais honesto que o pedido.** Medi que a metade executável do `red-first` **já é portátil**: `template/.forge/scripts/red-evidence.sh` não tem **nenhuma** ocorrência de `GITHUB_`, `GH_`, `actions` ou `gh ` (`grep -nE` devolve rc 1), e o único passo específico do harness dentro de `red-first.yml` é a linha `bash .forge/scripts/red-evidence.sh ci`. O que o arquivo do Actions acrescenta é o **gatilho** e o **runner que o autor não controla** — e essa segunda metade é propriedade do ambiente, que nenhum script pode produzir. Um `deploy.sh` executado pelo próprio autor, na máquina do próprio autor, não a reproduz; reproduzir seria mover a evidência produzida por quem é verificado para outro arquivo, que é o vetor de `project-red-first-limite-verificacao`.

Então a onda documenta o contrato portátil em `rules/testing/gate-delivery-channel.md` e no cabeçalho do `deploy.sh`, em quatro requisitos que qualquer provedor consegue satisfazer — histórico completo (o equivalente de `fetch-depth: 0`, porque o motor deriva a árvore pré-correção do histórico), Node 20, dependências materializadas, e `bash .forge/scripts/red-evidence.sh ci` — mais a condição que não é técnica: o ambiente tem de ser **fora do controle do autor do PR**.

**O que a onda deliberadamente NÃO faz, e a razão é a mesma que descartou GitLab na seção 4(a):** escrever um `cloudbuild-red-first.yaml` no template. Nenhum dos treze consumidores tem `red-first.yml` instalado (**0 de 13**, remedido) e nenhum usa Cloud Build para PR, então esse arquivo nasceria sem alvo real, mantido por simetria, e apodreceria em silêncio — exatamente o adaptador-ficção que a seção 4(a) recusa. Quando houver adotante que peça, o contrato de quatro requisitos é o que ele instancia, e a instanciação é barata porque a mecânica já é uma linha.

**Não move `run_to` de `pentest-ops.sh`.** Medido na seção 5.1: a movida reprova o `w206[21]` e degrada em silêncio onze cópias nuas do engine. A convergência das duas definições é item de ledger próprio, aberto no passo 0 da implementação, e o assert `[21]` impede divergência enquanto elas convivem.

**Não fecha o enum de `phase:` no schema.** Passa a ser possível (seção 9.2, item 2), mas é mudança de contrato com adotante instalado e vira item de ledger próprio, medido, não um adendo ao fim de uma onda grande. É o mesmo julgamento que separou o doctor de gate órfão da Onda 3 do #82.

**Não implementa a resolução automática por `.forge/custom/`.** O `README.md` de `template/.forge/custom/` declara que a resolução ainda não está implementada. `runtime.deploy.ci_provider_path` aceita caminho relativo à raiz do projeto e resolve o caso concreto do adaptador autoral sem depender dessa maquinaria — que é escopo próprio.

**Não toca em `.github/workflows` de consumidor nenhum** (seção 4(d)). O invólucro do `staging.yml` muda o **template**, e portanto só alcança instalação nova.

**Não implementa deploy multi-módulo nem detecção automática de deployables alterados.** `--from-config` resolve **um** módulo, de `runtime.deploy.module` (escalar). A Fase 1 do `deploy-orchestrator.md` faz detecção automática hoje, em `git diff` sobre a última tag `deploy-<env>-*`; zero tags `deploy-*` existem em campo, então a funcionalidade não tem uso medido a preservar, e ela entra depois, se o piloto pedir. Fatiar a onda aqui é o que a mantém entregável.

---

## 13. Piloto num consumidor real — antes de virar contrato do template

O plano-mestre é explícito: não há padrão em produção para extrair, esta onda cria o padrão, e por isso ela precisa de piloto. Conferi e confirmo: `scripts/deploy.sh` e `deploy-common.sh` não existem em `axis-go-cloud` nem em `azim-crm`.

**Piloto obrigatório — `axis-go-cloud`, provedor `github-actions`.** É o consumidor certo por quatro medições: harness na versão corrente (`.forge/forge.yaml: template_version: 0.14.0`), 55 workflows dos quais três são de deploy Helm, `platform/helm/` com `deployables`/`umbrella`/`subcharts`, e — o achado que fecha a escolha — o próprio `audit-trail-deploy.yml` declara em comentário que é a "entrada manual equivalente ao `/deploy-wave audit-trail <env>`". O alvo do piloto está nomeado pelo próprio consumidor.

**Dois níveis, e o segundo é condicionado:**

- **P1, executável hoje:** `deploy.sh audit-trail dev --dry-run` contra o chart real, com `helm lint` e `helm template` de verdade e o adaptador `github-actions` resolvendo o digest de uma imagem já publicada. Prova preflight, resolução de chart/values, as duas fases de gate e o manifesto, sem tocar cluster.

  **O desfecho esperado de P1 é registrado ANTES da execução, e ele não é rc 0.** Medi o estado do alvo: o `runtime:` do `axis-go-cloud/.forge/FORGE.md` vai de `primary_stack` a `integrations:` **sem bloco `gates:`**, e o repositório **não** tem `.forge/empty-universe-allowlist.txt`. Pela tabela da seção 4(f), caso 3, a previsão publicada é: `deploy.sh` invoca `run-gates.sh --phase pre-deploy` pelo canal real, a chamada volta `FAIL .../universo-vazio` com rc 1, o estágio `gates-pre-deploy` sai **`inconclusive`**, o deploy termina em **rc 4** com `verdict: inconclusive`, o manifesto grava `gates_pre_deploy: 0` e `gates_post_deploy: 0`, e **nenhuma** linha de `helm upgrade` ou `kubectl apply` é executada. **Esse é o P1 correto**, não um P1 falhado: ele prova que a fiação alcança o canal real e que o executor recusa com recibo em vez de aprovar por vacuidade — que é a metade do `LDG-0160` que uma linha de aviso do doctor nunca provaria.

  **Toda divergência dessa previsão é achado**, e há duas em particular a vigiar: rc 0 significaria que a chamada de fase foi pulada (a fiação não existe), e rc 3 significaria que "não examinei nada" colapsou em "reprovou" (a confusão de estados da invariante 2). A variante verde — declarar um gate de `pre-deploy` no `FORGE.md` do `axis-go-cloud`, ou uma isenção com `# motivo:` na allowlist — é decisão do dono daquele repositório e **não** é pré-requisito desta onda; se ela ocorrer, o desfecho previsto passa a ser rc 0 com `stage.gates-pre-deploy: passed` (caso 1) ou `skipped-declared` (caso 4), e o piloto registra qual dos três caminhos ocorreu.
- **P2, condicionado a credencial:** execução contra o cluster `dev`. `_template-cd-helm-deploy.yml:27` registra que o CI está bloqueado por billing e que os workflows foram validados por `actionlint`/`helm lint`. **Se P2 não for possível, o desfecho honesto é registrar a fronteira no manifesto e no CHANGELOG — não declarar a onda validada em produção.** É a mesma disciplina que o plano-mestre aplica ao piloto do Strix.

**Piloto secundário, opcional — `azim-crm`, provedor `cloud-build`.** Consumidor com Cloud Build e Helm reais. O harness lá está em `0.1.0-rc24`, muito atrás, então o piloto exige `forge update` antes — o que arrasta o risco da issue #101 (sobrescrita de `scripts/` sem `machinery.lock`) para dentro do piloto. Decisão: **não bloquear a onda nisso**. O adaptador `cloud-build` é validado por stub no gate e pelo piloto secundário quando o `azim-crm` for atualizado; a fronteira fica escrita no cabeçalho do adaptador.

**Regra de entrada do contrato:** o `deploy.sh` só é anunciado como contrato do template no CHANGELOG **depois** de P1 executado no `axis-go-cloud` **com desfecho igual ao previsto acima** — o que inclui o rc 4 por universo vazio, que é o desfecho correto e não uma falha. "P1 verde" seria a redação errada, porque no estado medido do consumidor o verde só viria de um `deploy.sh` que aprovasse por vacuidade. Antes disso ele entra como maquinaria nova com a fronteira declarada.

---

## 14. Ordem de implementação

0. Abrir o item de ledger da convergência de `run_to` (`ledger-ops.sh`, número alocado pelo script), com a medição da seção 5.1 anexada.
1. Change SDD de tipo `feature`, escopo desta onda, com `design.md` (a onda cria maquinaria nova, não conserta existente).
2. Esqueleto executável de `deploy.sh` + `lib/deploy-common.sh` com `DEPLOY_STAGES` e estágios vazios (seção 6, passo 1).
3. Gate `w<NN>-deploy-portability-gate.sh` inteiro, os 27 blocos da seção 8.1, contra o esqueleto. **Vermelho observado e registrado** via `/forge:red record` + `replay`, nas treze linhas da tabela da seção 6.
4. `lib/timeout.sh` com `run_to`, e o assert `[21]` de equivalência com `pentest-ops.sh` verde.
5. `lib/deploy-common.sh` de verdade: estágios, precedência, manifesto, sanitização.
6. `lib/ci/github-actions.sh`, depois `lib/ci/cloud-build.sh`, depois `lib/ci/local.sh`.
7. Fiação das duas fases em `deploy.sh` — o commit que fecha `LDG-0160`.
8. `runtime.deploy` no `FORGE.md` do template e em `forge.schema.json`, **no mesmo commit** — `/runtime` tem `additionalProperties: false` e um sem o outro reprova a validação de frontmatter (seção 11.1); `staging.yml` vira o invólucro da seção 5.3.
8b. `w192`: as duas chaves discriminantes entram em `SWITCHES` e `_reader_hits` passa a varrer `lib/*.sh` (seção 11.1), com o vermelho dessa edição registrado antes dela e a regra de folha-zero remedida no momento da edição.
8c. `README.md`: a linha `scripts/ (N)` do bloco `## 📁 Estrutura` é atualizada com o número que o comando do próprio `w200` devolve, no mesmo commit que acrescenta os seis arquivos de maquinaria.
9. `deploy-wave.md` + `deploy-orchestrator.md` reescritos; `npm run build:plugin`.
10. Seis mutações, cada uma **no cenário declarado na coluna própria da matriz**, com `cmp` de verificação da mutação e recontrole no mesmo cenário, no fixture espelhado da seção 7.
11. Medição dos contadores dos gates existentes contra as **propriedades** da seção 11 — `n_antes` remedido no mesmo commit, `N` do `check-secrets` medido e declarado no PR.
12. Piloto P1 no `axis-go-cloud`.
13. `LDG-0160` para `resolved`, com a evidência da seção 2.2 remedida: 3 de 3 gates executados.

## 15. Definição de pronto desta onda

- Suíte inteira verde, com os contadores dos gates preexistentes conferidos contra as **propriedades** da seção 11 — `n_antes` remedido no mesmo commit pelos comandos publicados; `+7` exatos em `shell-pipeline` e `heredoc-hash` com piso `>= 233`; `+6` exatos no subconjunto `template/.forge/scripts` com piso `>= 79`; e no `check-secrets` a propriedade `n_depois == n_antes + arquivos que este commit acrescenta ao índice`, com o `N` de artefatos de spec e evidência **medido e declarado no PR**. Toda divergência da propriedade é achado; nenhum literal de contagem de árvore entra nesta lista.
- Vermelho registrado e replayado antes de qualquer linha de implementação, nas **treze** asserções da tabela da seção 6.
- **Seis** mutações observadas mordendo, cada uma no cenário declarado na matriz, com controle de mutação e recontrole verde **no mesmo cenário**; a (d) acusando nas **cinco** variantes malformadas e a (f) acusando na de 65 hex.
- **Todo primitivo que a seção 20 deixou para o implementador provado por controle e recontrole antes de a asserção que o usa ser dada por escrita** — a spec declara a propriedade e o contrafactual, e a prova de que o primitivo escolhido discrimina é entregue com o gate, nunca presumida.
- `literal 13 == stages_declared == linhas stage. == stages_examined` no manifesto, em **todos os desfechos que gravam manifesto** (rc 3, rc 4 e rc 0 com `runtime.deploy` declarado) — rc 2, rc 5 e o rc 0 do pulo declarado sob `--from-config` não gravam, e cobrar o contador onde não há recibo seria cobrar o impossível. Isso só é cumprível com a regra da seção 5.4 que grava como `inconclusive` o estágio que a interrupção não alcançou.
- A regra do `skipped-declared` provada nas **duas** fontes de motivo da tabela da seção 5.1: `runtime.deploy.skip.<estagio>` nos **onze** estágios de mecânica (`[15]`, com controle positivo), e a `empty-universe-allowlist.txt` via `forge_universe_waiver` nos **dois** de fase (`[24]`, com a isenção anônima caindo em `inconclusive`/rc 4), mais o pareado de que uma chave `skip` para estágio de fase **não** produz `skipped-declared`.
- O motivo da isenção cobrado onde ele existe — o texto da própria fixture presente na **saída** de `deploy.sh`, propagada de `run-gates.sh` — e **não** como campo do recibo, cujo K permanece 41; com o contrafactual da fiação que engole a saída, que devolve o mesmo rc e perde o motivo (`[24]`).
- Precedência `failed` sobre `inconclusive` provada nas duas ordens de ocorrência; e rc 5 provado **sem** manifesto e sem `verdict`.
- Os **sete desfechos** da chamada `--phase` da seção 4(f) cobertos pelo `[24]` nos três que o fixture alcança sem stub de ambiente (sem isenção, isenção com motivo, isenção anônima), e os outros quatro declarados na tabela com a medição que os produziu.
- Dois adaptadores mais o `local`, com igualdade de conjunto de funções nas duas direções, e `[11]` com o controle positivo do quinto campo divergente acusando contra os **quatro** tolerados.
- `bash -n` limpo e zero construção de bash 4+ nos sete arquivos novos; `set -euo pipefail` nos dois pontos de entrada e `set` nenhum nas **cinco libs novas** (`lib/deploy-common.sh`, `lib/timeout.sh` e os três `lib/ci/*.sh`, seguindo o estilo das seis já existentes); pré-voo de lib irmã recusando com rc 5 (`[25]`).
- O gate publica **27** blocos executados e o bloco `[26]` confere contra o total do cabeçalho.
- Os gates rastreados da seção 11.1 conferidos: `npm run build:plugin` no mesmo commit (`plugin-sync-gate[1]`, mais a cobertura do `[3]`), schema e `FORGE.md` do template no mesmo commit (`/runtime` com `additionalProperties: false`), a linha `scripts/ (N)` do bloco `## 📁 Estrutura` do `README.md` **atualizada no mesmo commit e remedida pelo comando do próprio `w200`** (`find template/.forge/scripts -type f ! -name 'README.md' | wc -l`), e a edição declarada do `w192` com vermelho registrado antes e com a regra de entrada por folha-zero medida no momento da edição.
- Erro de uso reprovando com **rc 2** e a mensagem da guarda de `lib/arg-guards.sh` preservada em stderr, com controle positivo de que valor legítimo atravessa — as guardas saem 1 por construção e a tradução é obrigação de `deploy.sh` (`[2]`, seção 5.2).
- P1 do piloto executado no `axis-go-cloud` **com o desfecho comparado à previsão publicada na seção 13** (rc 4, `verdict: inconclusive`, `gates_pre_deploy: 0`, zero `helm`/`kubectl`), ou a fronteira escrita em letra se ele não for possível.
- `LDG-0160` resolvido com a medição, não com reclassificação; os itens de ledger da seção 16 abertos.

O golden do `w171` continua rodando, mas **não** entra nesta lista: ele não pode falhar por nada que esta onda faça (seção 9.2, item 1), e listar como prova de entrega uma asserção que a entrega não consegue quebrar é inflar a definição de pronto.

---

## 16. Item de ledger que esta onda abre

| Assunto | Por que não cabe aqui | Medição que sustenta |
|---|---|---|
| Convergência de `run_to` entre `pentest-ops.sh` e `lib/timeout.sh` | exige editar **dois** asserts rastreados — `w206[21]` e `w142[9]` — e dar espelho de diretório às onze cópias nuas do engine | `grep -c "perl -e 'alarm"` cai para 0 na cópia sem a definição; cópia com `source` de lib irmã ausente devolve `No such file or directory` e `rc=0` sob `set -uo pipefail`; e `tests/w142-pentest-gate.sh:197` faz o **mesmo** `grep -q "perl -e 'alarm" "$OPS"` do `w206[21]`, com `OPS="$WS/template/.forge/scripts/pentest-ops.sh"` (`w142:24`), mais duas sub-asserções que dependem do nome `run_to` (o padrão de embrulho `run_to <n> (docker\|adb)` na linha 215 e a não-vacuidade na 223). Nada reprova agora, porque a onda não toca `pentest-ops.sh`; o preço do item, porém, é o dobro do que ele registrava |
| Fechar o enum de `phase:` em `forge.schema.json` | mudança de contrato com adotante instalado | `forge.schema.json:139` declara em letra que `phase` é string livre para não reprovar o que o leitor lê (`LDG-0159`) |
| Predicado do `w192` casa a **folha** da chave, não o caminho pontuado | reforçar o critério de um gate rastreado que governa chaves de outros blocos é escopo próprio; sem o reforço, chaves de folha comum (`module`, `registry`, `skip`) não podem ser declaradas load-bearing sem produzir verde vacuo | `_reader_hits` usa `local leaf="${1##*.}"` e casa `grep -q "$leaf"` sobre os arquivos varridos; folhas como `module` e `skip` casam dezenas de arquivos por serem palavras comuns |
| `run-gates.sh --phase` não distingue "fase declarada e ilegível" de "fase não declarada" | os dois estados terminam em `universo-vazio` com a mesma linha, e medi que a ausência de `node` produz o primeiro; `deploy.sh` os trata igual (`inconclusive`), o que é correto para o deploy e insuficiente para quem depura | com `node` fora do `PATH` e `check-pd` declarado em `phase: pre-deploy`, a saída é a mesma `FAIL run-gates-phase-pre-deploy/universo-vazio — 0 gate(s) examinado(s)` do caso sem gate nenhum; `lib/forge-runtime.sh:71-72` documenta o comportamento em letra |

---

## 17. Respostas ao veredito da revisão 1

Um item por bloqueador, mais as três medições que o revisor não conseguiu reproduzir e as cinco ressalvas. Onde o revisor mediu, remedi com comando meu antes de aceitar.

### Bloqueador 1 — a extração do `run_to` quebra o `w206` e a spec afirmava o contrário

**Procede, e a spec estava factualmente invertida.** Remedi as duas pontas. Primeira: `tests/w206-strix-pentest-gate.sh:85` define `OPS="$WS/template/.forge/scripts/pentest-ops.sh"` e a linha 1069 abre o bloco `[21]` com `grep -q "perl -e 'alarm" "$OPS"`; removi a definição de `run_to` de uma cópia em `$TMPDIR` (`perl -0pi -e 's/^run_to\(\) \{\n.*?\n\}\n//ms'`) e `grep -c "perl -e 'alarm"` devolveu **0** — o `[21]` reprova, e a frase da seção 10 anterior ("o `w206[21]` é o assert que impede regressão") dizia o oposto do que o gate faz. Segunda, e esta é medição minha, não do revisor, e amplia o custo: montei uma cópia de `pentest-ops.sh` com `SCRIPT_DIR` e `. "$SCRIPT_DIR/lib/timeout.sh"` no topo e a executei de um diretório sem a lib irmã, que é literalmente o que o `w206` faz onze vezes (`MUT6A`, `MUT10`, `MUT15`, `MUT16C`, `MUT16D`, `MUT17`, `MUT18B`, `MUT24`, `MUT27`, `MUT28`, `MUT29`, com 18 invocações diretas `bash "$MUT"`); a saída foi `.../mutdir/lib/timeout.sh: No such file or directory` seguida de **`rc=0`**, porque `pentest-ops.sh:24` é `set -uo pipefail` **sem `-e`. A extração não faria o `w206` reprovar barulhentamente nessas onze cópias — faria cada uma medir um engine sem `run_to`, em silêncio. **Mudei a decisão, não a redação:** tomei a alternativa que o próprio revisor declarou igualmente aceitável, tirei a extração do escopo (seções 5.1, 10, 12 e 16), criei `lib/timeout.sh` como casa neutra só para código novo, e acrescentei o assert `[21]` que exige igualdade textual entre as duas definições enquanto elas convivem — duas cópias que um gate obriga a serem idênticas não são o caso de `LDG-0014`, onde nada as comparava.

### Bloqueador 2 — duas recusas contraditórias, e a mais provável em campo sem recibo

**Procede.** A seção 4(c) dizia rc 4 com manifesto, a 5.3 dizia rc 2, e a 5.2 dizia que rc 2 não grava manifesto — três frases sobre a mesma condição, e um consumidor com `ci_provider: gitlab` caía no meio. A seção 4(c) agora traz uma **tabela de seis linhas** que separa **erro de configuração do projeto** (rc 2, sem recibo — `runtime.deploy` ausente com módulo nominal, `ci_provider` vazio, adaptador inexistente) de **execução que não pôde ocorrer no ambiente** (rc 4, com recibo — `ci_available` rc 1 e rc 2, com `ci_provider_available: no` e `unknown` respectivamente), mais a sexta linha do `--from-config` sem `runtime.deploy` (rc 0, pulo declarado). A seção 5.2 ganhou a coluna "Manifesto" por rc, e a 5.4 trocou "gravado inclusive quando o veredito recusa ou é inconclusivo" por "nos rc 0, 3, 4 e 5, e nunca no rc 2". (**Registro histórico:** essa redação valeu até a revisão 2. O bloqueador novo 4 daquela rodada mostrou que rc 5 não pode gravar recibo, e a seção 5.4 hoje diz "nos rc 0, 3 e 4, e nunca nos rc 2 e 5" — a correção está na seção 18, e este parágrafo descreve o estado da revisão 2, não o atual.) A asserção antiga `[3]` virou duas: `[3]` (rc 2, sem manifesto, nomeando os adaptadores) e `[4]` (rc 4, com manifesto e `ci_provider_available` correto), com vermelhos próprios na seção 6.

### Bloqueador 3 — a precedência entre os estados de estágio nunca foi declarada

**Procede, e é a invariante 2 deixada em aberto.** A seção 5.2 ganhou a tabela normativa estado-de-estágio → `verdict` → rc: tudo `passed`/`skipped-declared` → `pass`/0; ao menos um `failed`, com ou sem `inconclusive` junto → `fail`/3; nenhum `failed` e ao menos um `inconclusive` → `inconclusive`/4. **`failed` vence `inconclusive`**, pela mesma razão do `w206[29]` ("recusa VENCE inconclusivo no caso MISTO"): uma violação observada é evidência definitiva, um inconclusivo é ausência de evidência, e deixar a ausência mascarar a violação rebaixa "reprovou" a "não sei" — bastaria um `trivy` fora do PATH para apagar qualquer falha. O enum de `verdict` está fechado em `pass | fail | inconclusive`. A asserção `[14]` prova o caso misto **nas duas ordens de ocorrência**, no `verdict` e no rc, no molde do `w206[29]`, e tem vermelho declarado na seção 6.

### Bloqueador 4 — a seção 5.1 matava a mutação (e)

**Procede, e o defeito era exatamente a tautologia de `LDG-0164`.** A 5.1 mandava o gate "nunca redigitar" o 13 e a 8 mandava assertar `== 13`; seguindo a primeira, os dois lados derivariam de `DEPLOY_STAGES`, cairiam juntos para 12 sob a mutação (e), a igualdade sobreviveria e o `cmp` confirmaria alegremente que o arquivo mudou. **Mudei a decisão:** a seção 8 agora declara **denominador triplo** — o literal `13` escrito no gate de propósito, `stages_declared` derivado da constante, e a contagem de linhas `stage.` do manifesto —, com a asserção `literal == stages_declared == linhas_stage == stages_examined == 13`. A seção 8 também explica por que o literal não é a redigitação que a invariante 3 proíbe (a invariante proíbe o gate contar sozinho o que o código declara; aqui o literal é o valor contratual contra o qual os derivados são conferidos) e manda o cabeçalho do gate registrar isso, para que ninguém "melhore" a asserção removendo a única âncora que sobrevive à mutação. A mutação (e) da seção 7 foi reescrita com a acusação vindo da comparação contra o literal: `FAIL [9]: DEPLOY_STAGES declara 12 estágios e o gate exige 13`.

### Bloqueador 5 — a mutação (d) não tinha como morder

**Procede.** Com o stub devolvendo digest bem formado, remover a validação de `sha256:<64hex>` não muda observável nenhum e a mutação vira a prova fantasma que a seção 7 existe para evitar. A mutação (d) agora declara a variante de stub que usa, e é o mesmo conjunto que o `w206[8]` já roda para R4, injetado por `STUB_DIGEST`: 63 hex, 64 hex com maiúsculas, 64 hex sem o prefixo `sha256:`, e vazio — mais o controle positivo dos 64 minúsculos, que tem de passar no engine íntegro **e** continuar passando na cópia mutada, para que a mutação não seja detectada por um caso que já falhava. A acusação tinha de aparecer em ao menos duas das variantes malformadas. (A revisão 2 errou o conjunto: o `w206[8]` roda **cinco** malformadas, não quatro — faltava a de **65 hex** —, e a regra de "ao menos duas" deixaria passar a mutação (f). A seção 7 corrigiu as duas coisas na revisão 3; este parágrafo é o registro histórico.) A asserção mordida deixou de ser `[11]`/`[12]` e passou a ser a `[13]`, criada para isso.

### Bloqueador 6 — o inventário de asserções não existia

**Procede.** A seção 6 remetia a "a lista completa está na seção 8" e a seção 8 tinha três contadores e lista nenhuma; só dez asserções eram nomeadas em 430 linhas, e o autoteste do contador ficava sem denominador. A **seção 8.1** agora enumera as asserções uma a uma, com o que cada uma prova, e fixa o total declarado no cabeçalho do gate e conferido pelo último bloco. (Eram 25, `[0]` a `[24]`, quando esta resposta foi escrita; a revisão 3 acrescentou `[24]` e `[25]` pelos bloqueadores novos 1 e 2 e o total passou a **27**, com o autoteste no `[26]` — a seção 8.1 é a fonte, este parágrafo é o registro histórico da correção.) As asserções que a revisão 1 listou como indefinidas ganharam conteúdo próprio: `[0]` (arnês e stub de passagem do `git`), `[1]` (bash 3.2 e `bash -n`), `[2]` (parsing e ausência de manifesto em rc 2), `[4]` (CLI ausente → rc 4 com recibo), `[8]` (rollback), `[13]` a `[18]` (digest, precedência, `skipped-declared` sem motivo, sanitização, preflight sem curto-circuito, `--dry-run`), `[21]` a `[24]` (equivalência de `run_to`, os dois PBT e o autoteste do contador).

### Bloqueador 7 — "os três esperados" nunca foram nomeados

**Procede, e sem nomear a asserção viraria carimbo do resultado observado.** A seção 9.2, item 3, nomeia os três: **`ci_provider`, `ci_run_ref` e `ci_run_url`** — o candidato que o próprio revisor apontou, e ele é o certo, porque são exatamente os três campos que o desenho da seção 4(b) faz nascer do adaptador. Todo o resto do manifesto tem de ser byte-idêntico entre os dois provedores, com duas ressalvas declaradas em letra: os três campos não determinísticos **por construção** (`run_id`, `generated_at`, `duration_s`) são normalizados antes da comparação, e `engine_sha256` **tem** de divergir, porque o adaptador carregado entra no resumo (seção 5.4) — é a quarta exceção, declarada aqui em vez de descoberta depois. A substituibilidade ganhou uma segunda metade, a projeção do trace sobre os participantes neutros de provedor, e um **controle positivo de não-vacuidade**: uma terceira execução em que o stub de `gcloud` devolve outro `image_ref`, e `[11]` **tem** de acusar.

### Bloqueador 8 — o invólucro do `staging.yml` não foi medido contra `forge init`

**Procede nos três pontos, e remedi os três.** `template/github/workflows/staging.yml` não menciona `MODULE` em lugar nenhum — o `${MODULE}` da linha proposta era uma variável vazia. `deploy-orchestrator.md:54` publica `env: dev | stg | prd` e a linha 60 reprova o que estiver fora de `{dev, stg, prd}` — `staging` não pertence ao vocabulário. E o bloco `runtime:` de `template/.forge/FORGE.md` vai de `primary_stack` a `gates:` sem nenhum `deploy`, então todo projeto recém-instalado cairia na recusa. Confirmei também o que o revisor mediu sobre o caminho: `bin/forge.mjs:835` copia sob `if (!existsSync(dst))` e só dentro do caminho de instalação, então quem já instalou fica intocado **e** instalação nova recebe o arquivo do template — que é justamente por que o invólucro precisava ser medido. A seção 5.3 traz o invólucro novo: o módulo vem de `runtime.deploy.module` via o literal `--from-config` na posição do módulo; o ambiente é **`stg`**, com o comentário do YAML declarando a tradução branch→ambiente; e `deploy.sh --from-config` com `runtime.deploy` ausente **sai 0**, imprime `deploy: runtime.deploy ausente no FORGE.md — nada declarado a implantar (pulado, motivo declarado)`, não grava manifesto e não toca `helm`/`kubectl` — pular com motivo declarado, que é a única saída compatível com a invariante 2. Módulo **nominal** sem `runtime.deploy` continua rc 2, porque quem nomeia um módulo afirma que ele existe. O assert `[19]` trava as três metades.

### Medição que não reproduziu — seção 5.5, o exemplo do `w206[23]`

**O revisor está certo e a spec estava em tempo errado.** Confirmei: `template/.forge/commands/waves/pentest.md:146` na árvore de trabalho já diz "seis raízes de skill", com o arquivo em `M` no `git status`, e `git show HEAD:template/.forge/commands/waves/pentest.md` ainda diz "quatro raízes". O exemplo foi reescrito no passado, com os dois comandos que separam os dois estados citados na seção 5.5, e a lição — paridade de token não é paridade de conteúdo — foi mantida como fundamento do assert `[20]`, que é o que ela sustenta.

### Medição que não reproduziu — seção 11, "quatro arquivos" para cinco, e sem o "antes"

**Procede, e a contagem estava errada nas duas pontas.** Não são quatro nem cinco: são **sete** (`deploy.sh`, `lib/deploy-common.sh`, `lib/timeout.sh`, três adaptadores, e o próprio gate), e a seção 11 agora os enumera. O "antes" que faltava foi medido nesta rodada com o mesmo coletor que os gates usam, e os comandos estão na seção: `collectShellFiles(['.'])` devolve **226** para `shell-pipeline` e **226** para `heredoc-hash`, `collectShellFiles(['template/.forge/scripts'])` devolve **73**, e `git ls-files | grep -c .` devolve **1167** para o `check-secrets` em modo `path` na raiz. A tabela de delta esperado (233/233/1174/79) foi publicada assim na revisão 2 e **estava aritmeticamente errada** na coluna do `check-secrets`, como a revisão 2 do revisor apontou: o universo dele é `git ls-files`, e a onda commita muito mais que sete arquivos. A seção 11 da revisão 3 a substituiu por propriedade mais piso; este parágrafo é o registro histórico da correção.

### Medição que não reproduziu — seção 2.2, fixture incompleto

**Procede.** Refiz a reprodução do zero e encontrei **três** requisitos que a receita publicada omitia, não dois: `waves.json` (`wave-ops.sh:137` recusa com `FAIL: waves.json não encontrado` antes de tocar em gate algum), `progress.json`, e — o que o revisor não mencionou e que sozinho já quebra a repetição — o `FORGE.md` do fixture precisa do frontmatter `---`…`---`, porque `lib/gate-phase.mjs:43` (`frontmatterOf`) devolve string vazia sem ele e a lista de gates sai vazia; com o `runtime:` solto no corpo, a saída observada é `NO-GATES`, não a publicada. A seção 2.2 agora traz o fixture na íntegra, verificado, e a saída real que ele produz.

### Ressalva — "restauração por checksum" é nome errado, e falta dizer como a cópia mutada resolve a lib irmã

**Aceita nas duas metades.** O protocolo foi renomeado para "mutação sobre cópia, com controle de mutação e recontrole", que é o que ele de fato faz — nunca escreve em `$ORIG`. E a seção 7 ganhou o parágrafo que faltava: o fixture **espelha o diretório inteiro** (`cp -R template/.forge/scripts "$FIXTURE/.forge/scripts"`), a mutação incide na cópia espelhada, a execução acontece com `cwd` dentro do fixture, e `$ORIG` é a cópia intacta em `$FIXTURE/orig/`. Isso não acrescenta um 35º sítio a `LDG-0171` e evita, por construção, o mesmo defeito de cópia nua que medi no bloqueador 1 — onde o `source` falha, `set -uo pipefail` não aborta e o gate passa a medir um engine mutilado.

### Ressalva — bash 3.2 e `bash -n` não apareciam

**Aceita.** A invariante 8 do plano-mestre vale sem exceção e a onda cria sete arquivos de shell. Virou a asserção `[1]` — `bash -n` limpo nos sete e zero construção de bash 4+ (`declare -A`, `${v,,}`, `${v^^}`, `mapfile`, `readarray`) fora de comentário — e entrou na definição de pronto da seção 15. O `[20]` continua sendo a paridade de `DEPLOY_STAGES`, que é assunto próprio; o `[1]` tem bloco dedicado em vez de carona.

### Ressalva — stubar `git` é mais arriscado que stubar `docker`

**Aceita, e o desenho está declarado.** A seção 4(e) agora diz que o stub de `git` é **de passagem** e nomeia os subcomandos interceptados: **`tag` e `push`, e mais nenhum**; todo o resto faz `exec` do git real, cujo caminho absoluto é capturado em `REAL_GIT="$(command -v git)"` **antes** de o `PATH` ser reescrito. A asserção `[0]` prova a passagem com controle positivo (`git rev-parse --abbrev-ref HEAD` devolve o branch do repositório de fixture) e prova que `git tag` escreve no trace sem criar tag nenhuma. Sem isso o gate mediria o stub, que é exatamente o risco apontado.

### Ressalva — campos do manifesto sem regra declarada, e o K do PBT sem número

**Aceita, e as quatro regras estão na seção 5.4.** `run_id` segue a fórmula de `strix_run_id` (`pentest-ops.sh:903-909`): `<UTC compacto>-<8 hex>` de `/dev/urandom`, caindo para `00000000`, um único componente de caminho. `engine_sha256` resume os **três** arquivos do engine daquela execução — `deploy.sh`, `lib/deploy-common.sh` e o adaptador carregado —, porque resumir só a porta deixaria a mecânica e o provedor fora do recibo. `verdict` é fechado em `pass | fail | inconclusive` e `ci_provider_available` em `yes | no | unknown`. E o **K é 41**, derivado como o revisor derivou: 25 campos fixos + 13 linhas `stage.` + 3 finais; o número está na seção 5.4, na propriedade 1 do PBT (seção 9.1) e na asserção `[12]`.

### Ressalva — o golden do `w171` não é evidência do que a onda entrega

**Aceita, e ela é justa.** `deploy.sh` consome `run-gates.sh` sem alterá-lo e o golden é capturado num fixture próprio, então nada que esta onda faça pode quebrá-lo; listá-lo na definição de pronto inflava a lista com uma asserção que a entrega não consegue falsear. A seção 9.2, item 1, agora o classifica em letra como **guarda de regressão, não evidência**, e a seção 15 o tirou da lista, com a razão escrita logo abaixo dela para que ninguém o recoloque por simetria.

---

## 18. Respostas ao veredito da revisão 2

Um item por bloqueador novo, mais as três observações menores e a divergência com o plano-mestre. Onde o revisor mediu, remedi com comando meu antes de aceitar — e onde ele acertou, o crédito é dele. Nesta rodada não refutei nenhum dos cinco: os cinco procedem, e em três deles a minha remedição achou mais do que o veredito descreve.

Antes das respostas, o que a varredura própria devolveu, porque foi ela que produziu quatro das correções abaixo e três que ninguém pediu.

**Varredura 1 — todo literal em asserção ou definição de pronto.** Separei em duas classes. **Legítimos** (denominador de cenário do próprio gate, fixo por construção, cuja divergência **é** o achado): os 3 gates em 3 fases da fixture da seção 2.2, os 13 estágios de `DEPLOY_STAGES`, os 27 blocos do gate, o K = 41 do manifesto (agora escrito como `25 + 13 + 3`, para que um campo a mais e um estágio a menos não se cancelem), as 6 variantes de digest, as 6 funções do adaptador, as 13 linhas de vermelho da seção 6. **Dívida** (conta a árvore e envelhece): `226 → 233`, `226 → 233`, `1167 → 1174`, `73 → 79` — convertidos em propriedade mais piso na seção 11, com o `n_antes` remedido no momento da execução. E dois literais meus que **já estavam errados** quando os escrevi: "135 arquivos sob `tests/`" (são **134**, conferido por três caminhos independentes) e o exemplo "`strix-pentest-spec.md:22` diz 23 asserções e são 30", que está corrigido na árvore de trabalho desde a Fase 0 e precisava do mesmo tempo verbal no passado que eu já tinha dado ao gêmeo da seção 5.5 — consertei um e deixei o outro passar.

**Varredura 2 — toda string ou contrato que a onda muda em saída de produção, com `grep -rln` em `tests/`.** O resultado está na seção 11.1, gate a gate. Em resumo: os três `echo` do `staging.yml` **não** são afirmados por gate nenhum (os dois que citam o arquivo asserem existência, não conteúdo), então a troca é segura; a reescrita de `deploy-wave.md` exige `npm run build:plugin` no mesmo commit (`plugin-sync-gate[1]`) e proíbe renomear ou acrescentar comando (`claude-contract.bats` C0, `count -eq 8`); `runtime.deploy` no schema e no `FORGE.md` do template têm de ir juntos, porque `/runtime` tem `additionalProperties: false` com oito chaves hoje; a rule `gate-delivery-channel.md` é citada por sete gates **só em comentário** e não tem `based_on:`, então editá-la é seguro. E a varredura achou um gate que a onda **precisa editar** e que nenhuma revisão tinha nomeado: `w192`, cuja lista de interruptores e cujo predicado por folha entram na definição de pronto (seção 11.1).

**Varredura 3 — toda linha da matriz de mutação, rodada antes de escrita.** Montei bancada em `$TMPDIR` com o `run-gates.sh` real, `FORGE.md` de fixture com os dois gates marcadores e um modelo mínimo de `deploy.sh`. Duas das cinco linhas estavam erradas: a **(b)** declarava um efeito que não acontece (a marca de pre-deploy fica **ausente**, não fora de ordem) e, pior, era indistinguível da (a) por `[5]` — o que obrigou a reforçar `[7]` para exigir **exatamente uma** ocorrência da marca de post-deploy; e a **(c)** era **no-op medido** no cenário em que estava escrita (`diff` vazio contra o engine íntegro), e só morde com o gate marcador reprovando. A matriz ganhou coluna de cenário e coluna de efeito observado. As linhas (a) e (e) reproduziram exatamente como estavam escritas.

**Varredura 4 — toda enumeração de desfechos, procurando o caso não coberto.** A enumeração crítica era a da chamada `run-gates.sh --phase`, e a spec não tinha nenhuma. Construí a da seção 4(f) por medição e achei **dois** casos que nem o veredito citava: `node` ausente do `PATH` com fase declarada em forma mapeada (o motor conta zero e reprova por vacuidade, com a **mesma** linha do caso sem gate nenhum — `lib/forge-runtime.sh:71-72` documenta que sem `node` "a forma mapeada simplesmente não é lida"), e `run-gates.sh` **ausente** no consumidor, que devolve rc **127** e é o estado de **nove dos treze** consumidores hoje. A outra enumeração, a do rc 5, tinha o buraco que o bloqueador novo 4 nomeia, e ela agora tem três causas fechadas.

### Bloqueador novo 1 — a guarda de vacuidade do `--phase` derruba as duas chamadas em todo consumidor real

**Procede, é o mais caro dos cinco, e a minha remedição encontrou o campo pior do que o veredito descreve.** Reproduzi com fixture própria em `$TMPDIR`, `cwd` dentro dela: `FORGE_ROOT="$T" bash "$T/.forge/scripts/run-gates.sh" mod-x --phase pre-deploy` devolve `FAIL run-gates-phase-pre-deploy/universo-vazio — 0 gate(s) examinado(s)` e rc 1, porque `run-gates.sh:66-72` chama `forge_universe_check` sempre que `--phase` é explícita. Conferi as duas afirmações do revisor sobre o campo e as duas batem — zero de treze declaram `phase:`, e o `axis-go-cloud` não tem bloco `gates:` —, e acrescentei uma terceira que ele não mediu e que é pior: **nove dos treze consumidores não têm `run-gates.sh` nenhum**, e nesse estado a invocação devolve rc 127.

**O que mudou.** A seção 4(f) é nova e traz a enumeração dos **sete** desfechos, cada um medido, com o estado de estágio para cada um. A seção 4(c) ganhou a sétima linha. A ordem de execução da seção 5.2 passou a dizer que as duas chamadas são **incondicionais** e que o que a contagem prévia decide é a classificação, nunca se chama. A seção 10 corrigiu a linha de retrocompatibilidade que usava a adoção zero como prova de que ninguém quebra — o argumento estava certo para `run-gates.sh` e parava cedo demais. A seção 13 publica a **previsão** do desfecho de P1 antes da execução: rc 4, `verdict: inconclusive`, `gates_pre_deploy: 0`, zero `helm`/`kubectl`. E a asserção `[24]` é nova, com fixture sem gate de fase.

**Duas decisões de desenho que o veredito deixou em aberto e que fechei com medição.** A primeira: o desfecho é **`inconclusive`/rc 4**, e não isenção declarada por `deploy.sh` ao chamar — porque a isenção existe, é versionada, exige `# motivo:` e reprova quando anônima, e um chamador que passasse a própria isenção seria escape hatch operado pelo chamador, que é literalmente o que a `empty-universe-allowlist.txt` fecha. A segunda: o discriminador entre "reprovou" e "não examinou nada" é a **contagem do universo pelo leitor canônico**, nunca a string de stderr — casar a mensagem acoplaria `deploy.sh` a um texto de `gate-universe.sh`, e uma mudança de redação lá viraria mudança de comportamento aqui.

### Bloqueador novo 2 — as libs irmãs novas sem opção de shell nem asserção de recusa alta

**Procede, e o revisor mediu certo as duas pontas.** Refiz a medição em bancada com três arranjos e a lib ausente: `set -uo pipefail` segue em frente e sai **rc 0** com `run_to: command not found`; `set -euo pipefail` aborta com **rc 1**; pré-voo explícito antes do `source` recusa com **rc 5** nomeando o arquivo. A spec de fato fazia da degradação silenciosa o argumento central da correção do bloqueador 1 e depois criava três libs irmãs sem declarar opção nenhuma — a autoironia é exata.

**O que mudou, e por que a resposta não é só `set -euo pipefail`.** Medi que `-e` sozinho troca um silêncio por um **rc mudo**: rc 1 não pertence ao vocabulário de saída da seção 5.2, e a recusa não nomeia o arquivo faltante. E conferi o estilo da casa: **nenhuma** das cinco libs existentes em `template/.forge/scripts/lib/*.sh` declara `set`, e com razão — uma lib que impõe `-e` muda o comportamento de quem a carrega. Então a seção 5.1 declara os dois: `set -euo pipefail` nos **pontos de entrada** (`deploy.sh` e o gate), `set` nenhum nas cinco libs, e um **pré-voo de lib irmã** em `deploy.sh` que itera sobre a lista literal das libs de maquinaria antes do primeiro `source` e recusa com **rc 5** nomeando o arquivo. Lib de maquinaria ausente é instalação incompleta (rc 5); adaptador ausente é configuração do projeto (rc 2) — o corte é o mesmo da seção 4(c). A asserção `[25]` é nova, remove **uma** lib da cópia espelhada e exige rc 5 com o arquivo nomeado, zero `helm`/`kubectl` no trace, e **controle positivo pareado** para que ela não fique verde sobre um `deploy.sh` que recuse sempre.

### Bloqueador novo 3 — a tabela de delta de contadores é incompatível com a ordem de implementação

**Procede, e remedi cada peça antes de aceitar.** Conferi que `check-secrets.sh:142` deriva `n_files` de `git ls-files`, logo o universo cresce com **todo** arquivo rastreado que a onda commitar. Conferi o que a onda commita além dos sete `.sh`: os changes arquivados deste repositório carregam de **6 a 19** arquivos rastreados cada (amostrei cinco; o diretório inteiro tem 160), há **14** arquivos sob `evidence/runs/` no índice, e **esta própria spec está untracked** hoje e vira arquivo rastreado ao commitar. O "1167 → 1174" nunca poderia bater, e a seção 15 mandava tratar isso como achado — achado fantasma na entrega, que convida ao ajuste silencioso do número.

**O que mudou.** A seção 11 substituiu a tabela por **propriedade mais piso**, com o `n_antes` remedido no mesmo commit: `+7` exatos e piso `>= 233` nos dois coletores de `.sh` da raiz, `+6` exatos e piso `>= 79` no subconjunto da maquinaria, e no `check-secrets` a propriedade `n_depois == n_antes + arquivos que este commit acrescenta ao índice`, com o `N` de artefatos de spec e evidência **medido e declarado no PR**. A definição de pronto da seção 15 deixou de citar literal de contagem de árvore.

**Duas medições próprias que a correção trouxe.** Primeira: o coletor caminha o **sistema de arquivos**, não o `git ls-files` — conferi que hoje os 226 são todos rastreados, mas um `.sh` untracked de outra frente em voo entra na conta sem estar no commit, e é por isso que o piso importa. Segunda: `tests/npx-pack-gate.sh:40` usa `forgeCount < 200`, **piso e não igualdade**, e é o único literal de contagem de arquivos do template em toda a suíte — o modelo que a tabela nova copia estava dentro do próprio repositório.

### Bloqueador novo 4 — o rc 5 grava manifesto e não tem `verdict` declarado

**Procede.** Grepei o documento e confirmo o diagnóstico: a coluna "Manifesto" (nova na revisão 2) dizia que rc 5 gravava recibo, a seção 5.4 fechava o enum em três valores e a tabela de precedência mapeava só rc 0, 3 e 4. O implementador teria de inventar um sexto valor — quebrando o enum e as asserções `[11]` e `[12]` — ou escrever `fail`, apagando a diferença entre "o deploy reprovou" e "o executor quebrou", que é a mesma colapso de estados da invariante 2 um nível acima.

**Tomei a segunda das duas saídas que o revisor ofereceu: rc 5 não grava manifesto**, e a razão não é preferência, é medição. Nas duas causas mais prováveis o **escritor do recibo é justamente o que falta**: `deploy_manifest_write` mora em `lib/deploy-common.sh`, e a causa número um de rc 5 é lib de maquinaria ausente (bloqueador novo 2), a número dois é `.forge/cache/deploy/` não gravável. Uma regra que mandasse gravar seria impossível de cumprir exatamente onde mais importaria, e regra inaplicável é regra que se aprende a ignorar. A terceira causa fecha a enumeração e é decisão minha, não do veredito: se na hora de gravar o recibo reprovar o **próprio contador de controle** — `stages_examined ≠ stages_declared`, `verdict` fora do enum, K diferente de 41 —, `deploy.sh` não grava nada e sai 5 nomeando a invariante violada, porque um recibo que falha o próprio contador é pior que a ausência dele: parece evidência.

**O que mudou.** A coluna "Manifesto" do rc 5 virou "**não gravado**"; a seção 5.2 ganhou o bloco que declara as três causas e explica por que rc 5 **não tem linha** na tabela de precedência (ele aborta a máquina de estados, então nunca coexiste com um `verdict`); a seção 5.4 passou a dizer "nos rc 0, 3 e 4, e nunca nos rc 2 e 5" (**registro histórico:** essa redação valeu até a revisão 4; a ressalva 1 daquela rodada mostrou que o rc 0 do pulo declarado sob `--from-config` é exceção, e a §5.4 e a §5.2 hoje trazem o escopo — a correção está na seção 21); e a definição de pronto trocou "em todos os desfechos" por "em todos os desfechos que gravam manifesto", porque cobrar o contador onde não há recibo seria cobrar o impossível.

### Bloqueador novo 5 — o conjunto de variantes da mutação (d) não é o que a spec afirma copiar

**Procede, e a variante omitida é exatamente a que importa.** Reli `tests/w206-strix-pentest-gate.sh:585-635` e contei: são **cinco** malformadas, não quatro — ausente, sem `@sha256:`, 63 hex (`${DIGEST_HEX%?}`), **65 hex** (`${DIGEST_HEX}0`, linha 616) e hex maiúsculo. Medi por que a de 65 hex é a única que importa: das cinco, **só ela** muda de estado entre `^sha256:[0-9a-f]{64}` e `^sha256:[0-9a-f]{64}$`. Sem âncora de fim, o `image_digest` gravado passa a ser um digest inválido num recibo que existe para provar qual imagem foi implantada.

**Fui além da correção pedida, e a medição obrigou.** O revisor pediu a quinta variante; medindo, achei que a regra de "**ao menos duas** variantes acusando" — que era exigência da revisão 1 — deixaria passar em silêncio a versão realista do defeito, porque um regex sem âncora muda o estado de **uma só** variante. A regra virou "**todas as cinco** malformadas recusadas", e a matriz ganhou a mutação **(f)**: a validação perde a âncora de fim. A (d), que remove a validação inteira, continua sendo a caricatura; a (f) é o erro que se comete de verdade.

**O dono da validação está nomeado, que era a segunda metade do bloqueador.** `deploy_digest_validate` é a **única** função que valida formato de digest, vive em `lib/deploy-common.sh`, e é chamada por `deploy.sh` sobre o que quer que o adaptador tenha devolvido. Nenhum `lib/ci/*.sh` valida formato — o adaptador **obtém** e devolve cru, validar é da mecânica, que é comum aos três —, e o assert `[10]` já detecta como código morto um adaptador que inventasse validação própria. As mutações (d) e (f) incidem, as duas, num único sítio nomeado, então "a mutação não aconteceu" e "o assert exercitou outro adaptador" deixam de ser possíveis.

### Observação menor 1 — "exatamente três campos" contra "a quarta e última exceção"

**Aceita, e a leitura literal do revisor é a correta:** o implementador que lesse a mensagem de vermelho de `[11]` escreveria o assert com três. A seção 9.2(i) agora diz **quatro**, nomeados de uma vez — `ci_provider`, `ci_run_ref`, `ci_run_url` e `engine_sha256` —, e separa em letra tolerância de normalização: `run_id`, `generated_at` e `duration_s` são **normalizados** antes da comparação e por isso **não** entram na conta. A mensagem de vermelho na seção 6 e a do controle positivo em 9.2 nomeiam os quatro.

### Observação menor 2 — a acusação declarada da mutação (b) não é a que o gate emite

**Aceita, e a bancada mostrou que o problema era maior que a redação.** Rodei a (b) e observei: `gate:predeploy-marker` **ausente**, `gate:postdeploy-marker` **duas vezes**, a primeira na linha 2 e o `helm` na linha 3. O revisor está certo de que a acusação escrita não é a que sai. O que a medição acrescenta é que, por `[5]` sozinha, a (b) é **indistinguível da (a)** — as duas acusam marca ausente —, e o que as separa é o sinal **positivo** da fiação trocada. Então `[7]` foi reforçada para exigir que a marca de post-deploy apareça **exatamente uma vez** e suceda o `kubectl rollout`: escrita só como "sucede", a segunda ocorrência a satisfaria e o gate ficaria verde sobre a fiação errada. A matriz da seção 7 traz agora a acusação dupla, `[5]` e `[7]`.

### Observação menor 3 — a divergência com o plano-mestre sobre o equivalente do `red-first`

**Aceita, e ela é justa.** O item 3 da seção "Onda K" pede que o `red-first.yml` "ganhe um equivalente para quem não usa Actions" e a linha 199 do plano manda "oferecer, para quem não usa Actions, o mesmo contrato num adaptador equivalente"; a seção 12 decidia não dar equivalente nenhum e escrevia a decisão como se fosse o que o plano pediu. A seção 12 agora **declara a divergência** em letra.

E a remedição melhorou a resposta. Medi que a metade executável do `red-first` **já é portátil**: `red-evidence.sh` não tem nenhuma ocorrência de `GITHUB_`, `GH_`, `actions` ou `gh ` (o `grep -nE` devolve rc 1), e o único passo específico do harness dentro do workflow é `bash .forge/scripts/red-evidence.sh ci`. O que o arquivo do Actions acrescenta é o gatilho e o runner fora do controle do autor — e essa metade é do ambiente. Então a onda documenta o **contrato portátil** em quatro requisitos instanciáveis por qualquer provedor (histórico completo, Node 20, dependências materializadas, uma linha de comando) mais a condição não técnica, e **não** escreve um `cloudbuild-red-first.yaml` no template: com **0 de 13** consumidores tendo `red-first.yml` instalado e nenhum usando Cloud Build para PR, esse arquivo nasceria sem alvo real e apodreceria por simetria — o mesmo argumento que descartou GitLab e Jenkins na seção 4(a).

### Sobre o único ponto onde o revisor não executou

Ele declara que o veredito do bloqueador 7 da revisão 1 repousa em leitura, não em execução, porque não há nada executável ali. Concordo com a classificação e ela não muda nada: aquele item era definição escrita, a definição está escrita, e a revisão 3 a corrigiu de três para quatro campos pela observação menor 1 — que também é leitura, e também é suficiente, porque o defeito era de aritmética no próprio texto.

---

## 19. Respostas ao veredito da revisão 3

Dois bloqueadores novos, onze ressalvas de redação, e a mudança de método da invariante 19 aplicada à spec inteira (seção 20). Os dois bloqueadores **procedem** e estão fechados; das onze ressalvas, dez foram aceitas inteiras e uma teve o número refutado com medição minha, mantida a substância. Nesta rodada refutei uma contagem e corrigi duas afirmações minhas que o revisor não pegou — as duas achadas pela varredura de comandos.

### Novo 1 — o inventário do README é literal de contagem que esta onda envelhece, e nem a §11.1 nem a definição de pronto o nomeavam

**Procede, e a causa é de método, exatamente como o revisor diagnosticou.** Remedi antes de aceitar: `README.md`, no bloco `## 📁 Estrutura`, declara `scripts/ (136)`, e `tests/w200-readme-inventory-gate.sh` compara cada linha `<dir>/ (N)` com `find "$root/$dir" -type f ! -name 'README.md' | wc -l` sobre `template/.forge`. Rodei o critério do gate à mão nas sete linhas e as sete batem hoje (agents 47, commands 56, contracts 5, skills 20, rules 50, schemas 27, scripts 136); a onda acrescenta seis arquivos àquele diretório, o real vira 142 e o `[1]` — o único cenário não hermético daquele gate — reprova.

A varredura da lição L2 grepou `tests/` atrás do literal, e este literal mora no `README.md` e é apenas **afirmado** por um gate. Foi por isso que a §11 concluiu, e escreveu como medição, que `tests/npx-pack-gate.sh:40` era "o único literal de contagem de arquivos do template em toda a suíte" — afirmação que o `w200` falsifica e que está corrigida. **A regra de varredura muda junto com a correção:** procurar o literal não basta, é preciso procurar **quem afirma o literal**, porque o número pode morar em documentação e o gate ser só o verificador. A §11 traz agora o comando remedido e a explicação, a §11.1 ganhou a linha do `README.md` + `w200`, a §14 ganhou o passo 8c e a §15 cobra a atualização no mesmo commit, remedida pelo comando do próprio gate — `find` sobre a árvore de trabalho, e não `git ls-files`, porque é esse o critério do `w200` e um arquivo não rastreado sob `template/.forge/scripts/` entra na conta dele. Conferi também que a onda não mexe em nenhum dos outros seis diretórios contados.

### Novo 2 — rc 2 para erro de uso é incompatível com a reutilização obrigatória das guardas de flag

**Procede, e o revisor mediu certo as duas pontas.** `lib/arg-guards.sh:38` e `:78` terminam em `exit 1` literal; montei bancada e confirmei que uma chamada nua no ramo `*)` do `case` — o idioma da casa, e o que a §5.2 manda — sai **rc 1**, contra o rc 2 que a mesma seção exige e que o assert `[2]` cobra. A decisão estava em aberto com aparência de fechada.

**Fechei por rc 2, e a razão está medida na §5.2.** Admitir rc 1 custaria três coisas: quebraria a paridade com `strix_cmd_preflight`/`strix_cmd_scan`, que é a única justificativa para esta seção não inventar um dialeto novo; colidiria com o rc 1 do abort de `source` sob `set -euo pipefail`, que é o desfecho mudo que a §5.1 descartou; e obrigaria a mexer na tabela de rc, na frase da §5.1 e no assert `[2]` juntos, para ganhar um vocabulário pior. A §5.2 agora declara a **propriedade** — erro de uso sai rc 2, com a mensagem da guarda preservada byte a byte em stderr e nenhum manifesto gravado — e deixa o **primitivo** com o implementador, tendo medido que ele é cumprível: o embrulho em subshell com tradução do rc satisfaz as três metades, inclusive o caminho de aceite, e a saída dos cinco comandos está colada na seção. O assert `[2]` ganhou o contrafactual explícito nas duas direções (guarda nua → rc 1; guarda removida → rc 0 gravando `approved_by: --dry-run`).

### As onze ressalvas de redação

1. **Regra de parada da máquina de estados fora do lugar.** Aceita. A §5.2 abre a ordem de execução com a frase normativa: estágio de fase que não termine em `passed` ou `skipped-declared` interrompe antes de `build`. Estava fechada dentro do assert `[24]` e na previsão de P1, que são os lugares errados para uma regra que o implementador precisa antes de escrever a ordem.

2. **"Em nenhuma das seis linhas" numa tabela de sete.** Aceita — literal de prosa envelhecido na própria rodada que acrescentou a linha, e a sétima é justamente a do universo vazio, onde a garantia mais importa. Corrigido para sete, com a razão escrita.

3. **O parágrafo de abertura da §8.1 contradiz duas tabelas.** Aceita. Conferi que a tabela está íntegra (27 linhas, `[0]` a `[26]`, sem buraco nem repetição) e que o parágrafo é que trocava `[24]`/`[25]`/`[26]`. Corrigido, com a nota de que a tabela é a fonte.

4. **"Quatro" consumidores com bloco `gates:`.** Aceita, e remedi os treze um a um antes de aceitar: são **três** (`axis-fare-validator`, `Axis.PadSimulator`, `azim-crm`). O resto do censo reproduz sem alteração — 13 repositórios, os mesmos nove sem `run-gates.sh` (a lista nominal bate arquivo a arquivo), zero com `phase:`, um com allowlist.

5. **"As cinco libs existentes" para um conjunto de seis.** Aceita. `lib/heavy-mutex.sh` entrou depois da conta. A afirmação de fundo sobrevive à correção e está colada na §5.1: nenhuma das seis declara `set`.

6. **`claude-contract.bats` "C0, `count -eq 8`" citado como o gate que impede acrescentar ou renomear comando.** Aceita, e o revisor está certo no diagnóstico mais grave: **o gate citado não impõe a restrição escrita**. O bloco é o `C1` (linhas 41-48), ele conta `$CMDS_DIR` no modo `source` — que é o snapshot congelado em `snapshot/project-bootstrap/.claude/commands`, onde medi os oito arquivos com `deploy-wave.md` entre eles — e faz `skip` no modo `generated`. Acrescentar comando em `template/.forge/commands` não o reprova. A §11.1 e a §15 passaram a nomear o que de fato restringe (`plugin-sync-gate[1]` e `[3]`) e a descrever o `C1` pelo que ele é. Publicar cobertura que não existe é o defeito que a própria §11.1 recusa no item do `w192`, e ele estava na linha de cima.

7. **O item de ledger do `run_to` subestima o próprio preço.** Aceita, e remedi: `tests/w142-pentest-gate.sh:197` faz o **mesmo** `grep -q "perl -e 'alarm" "$OPS"` do `w206[21]`, com o mesmo `$OPS`, e o `[9]` tem ainda duas sub-asserções que dependem do nome `run_to` — o padrão de embrulho na linha 215 e a não-vacuidade na 223. São dois asserts rastreados, não um. A §16 registra o preço dobrado.

8. **A §17 afirma "nos rc 0, 3, 4 e 5" sem marca de registro histórico.** Aceita. O parágrafo ganhou a marca, como os vizinhos já tinham.

9. **O assert `[19]` nasce vermelho se for grep solto por `staging`.** Aceita na substância e **refutada no número**, com medição minha: montei o `staging.yml` pós-reescrita e ele contém `staging` **quatro** vezes de forma legítima, não três — o comentário de cabeçalho (`develop -> staging`), o `name: staging-pipeline`, o `branches: [staging]` e o comentário novo da tradução branch→ambiente. A conclusão do revisor não muda com o número corrigido: a asserção tem de ser ancorada na linha que invoca `deploy.sh`, e a §5.3 e o `[19]` agora a escrevem assim, com a saída do `grep`/`awk` ancorado colada.

10. **§7 diz que o conjunto de variantes de digest "é o do `w206[8]`".** Aceita. Reli `w206[8]` e ele roda ausente, sem `@sha256:`, 63 hex, 65 hex e maiúsculo; o conjunto desta spec troca "ausente" por "vazio", porque aqui o digest chega de `ci_build_digest` e não de um arquivo de configuração, e "chave ausente no YAML" não tem correspondente. A §7 passou a dizer **análogo**, com a diferença declarada e a razão dela.

11. **§4(f) manda copiar o motivo da isenção e não nomeia por onde.** Aceita, e a correção melhorou o desenho. `forge_universe_waiver <root> <gate-key>` já está disponível porque `deploy.sh` carrega `lib/gate-universe.sh`, devolve `OK<TAB><motivo>`, `ERR<TAB><linha>` ou vazio com rc sempre 0, e a chave é `run-gates-phase-<fase>` (`run-gates.sh:67`). Rodei os três estados e a saída está na §4(f). O ganho é maior que a ressalva: com a contagem em zero, o estado do waiver **sozinho** separa os casos 3, 4 e 5, que são justamente os três que compartilham a última linha e o rc — o par `(contagem, rc)` continua separando 1, 2, 6 e 7, e nenhuma das duas leituras toca em string de mensagem.

### Duas correções que a varredura desta rodada achou e que o veredito não cita

**O comando publicado na §5.5 e o gêmeo na §8 deixaram de discriminar.** Os dois exemplos históricos eram escritos como `git show HEAD:<arquivo>` contra a árvore de trabalho, e a correção da Fase 0 foi **commitada** em `c41eead` entre a revisão 3 e esta rodada. Hoje os dois lados devolvem o mesmo texto: o comando que a spec publicava para separar os estados não separa mais nada. Ancorei os dois exemplos no par `c41eead^`/`c41eead`, que discrimina e continuará discriminando, com as saídas coladas. É a invariante 19 em ato, e num lugar onde a spec já tinha sido corrigida uma vez por tempo verbal.

**O literal `1167` do `check-secrets` envelheceu antes de a onda começar.** `git ls-files | grep -c .` devolve **1168** hoje, e a causa é o mesmo `c41eead`, que acrescentou `docs/plans/2026-09-07-backlog-zero.md` ao índice — conferido por `git ls-tree -r --name-only c41eead^` (1167) contra `HEAD` (1168). Se a definição de pronto ainda cobrasse `1167 → 1174`, ela já estaria falsa por trabalho que a onda não fez. A forma de propriedade mais piso da §11, adotada na revisão 3, é o que sobrevive a isso, e agora tem a demonstração dentro do próprio documento.

---

## 20. Varredura de comandos prescritos — a invariante 19 aplicada à spec inteira

A invariante 19 do plano-mestre é nova e é o assunto desta rodada: **uma especificação não prescreve mecanismo que ela não executou**. A régua vem de três defeitos medidos em specs desta mesma rodada — `node -e '<código>' <caminho>` põe o caminho em `process.argv[1]` e a mutação prescrita não mutava nada, `git diff-files` não reporta um `touch` do mesmo segundo do commit pela regra racy-clean, e `stat -f %m` tem granularidade de segundo no macOS. Nos três a spec escreveu o comando sem rodar, e nos três a asserção nascia morta ou verde por acidente.

**A divisão de trabalho, e ela é normativa aqui:** a spec declara a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir; o implementador — que executa — escolhe o primitivo e **prova que ele discrimina**, com controle e recontrole, antes de dar a asserção por escrita. Prescrição de comando exato só fica na spec quando veio de uma execução minha, com a saída colada. Isso não é licença para vagueza: a propriedade continua verificável e o contrafactual continua específico ("sob a mutação X o gate acusa a linha Y"); o que muda é quem escolhe o primitivo, e onde a prova de discriminação é paga.

**O que a varredura devolveu.** Contei **25 primitivos prescritos** ao implementador, fora os comandos de medição que a spec usa para afirmar fatos do repositório (esses estão na segunda tabela). Dos 25: **14 executados**, com a saída colada onde ela decide alguma coisa — 13 na revisão 4 e o 25 nesta rodada, pelo bloqueador novo 1; **5 já ancorados em execução ou em código real anterior**, remedidos e mantidos; **6 convertidos em propriedade mais contrafactual**, com o primitivo devolvido ao implementador.

| # | Primitivo prescrito | Onde | Desfecho |
|---|---|---|---|
| 1 | `forge_runtime_gates_phase "<fase>" "$ROOT"` como contador de universo | §4(f), §5.2 | **executado** — devolve `check-pd` e `n=1` na fixture; saída na §4(f) |
| 2 | `forge_universe_waiver <root> "run-gates-phase-<fase>"` como desempate dos casos 3/4/5 | §4(f) | **executado** em duas rodadas, nos três estados (`OK`, `ERR`, vazio) e com **dois** motivos distintos coexistindo nas duas fases; é correção da ressalva 11 da revisão 3 e insumo do bloqueador novo 1 da revisão 4 |
| 3 | Guardas de `lib/arg-guards.sh` fiadas com saída rc 2 | §5.2, `[2]` | **executado** — cinco comandos, direto contra traduzido, com controle positivo |
| 4 | `set -euo pipefail` nos pontos de entrada e `set` nenhum nas libs | §5.1 | **executado** — `ls` das seis libs e `grep -ln '^set -'` devolvendo vazio |
| 5 | Corpo do invólucro do `staging.yml` | §5.3, `[19]` | **executado** nos quatro arranjos; achou o defeito de bancada do `GITHUB_SHA` |
| 6 | Âncora do `[19]` na linha que invoca `deploy.sh` | §5.3, `[19]` | **executado** — `grep` ancorado, `awk` do token, e a contagem de quatro `staging` legítimos |
| 7 | Stub de passagem do `git` (`REAL_GIT="$(command -v git)"` + `exec`) | §4(e), `[0]` | **executado** — passagem, interceptação de `tag`/`push`, e prova de que nenhuma tag é criada |
| 8 | Espelho de `PATH` por symlink pulando os **oito** nomes stubados | §4(e), `[0]` | **executado** em duas rodadas — 960 espelhados nesta máquina contra 961 pulando sete, e nesta rodada a medição de que o espelho de sete é inexequível (o stub escreve através do symlink para o git real, recusado com `Operation not permitted`); o número é derivado na execução, nunca literal |
| 9 | `cp -R template/.forge/scripts "$FIXTURE/.forge/scripts"` com `cwd` dentro da fixture | §2.2, §7 | **executado** em duas rodadas, inclusive nesta |
| 10 | Controle de mutação e recontrole (`cp`, `cmp -s`, descarte, repetição no mesmo cenário) | §7 | **executado** nas duas direções, incluindo o caso patológico da mutação-fantasma |
| 11 | Mutação por `awk` em vez de `perl -0pi -e` | §7 | **executado** o `awk`; o `perl` fica como **perigo declarado**, não como prescrição |
| 12 | Comando do `w200` para remedir `scripts/ (N)` | §11, §14.8c, §15 | **executado** — as sete linhas do inventário conferidas com o critério do gate |
| 13 | Predicado do `w192` com `lib/*.sh` acrescentado à varredura | §11.1 | **executado** — tabela de folhas; corrigiu uma afirmação minha (`registry` e `chart_root` casam zero, não dezenas) |
| 14 | Pré-voo de lib irmã recusando com rc 5 | §5.1, `[25]` | ancorado na medição da revisão 3 (três arranjos de shell, com a lib ausente); mantido |
| 15 | `run_id` na fórmula de `strix_run_id` | §5.4, `[12]` | ancorado no código real, remedido nesta rodada (`pentest-ops.sh:903-909`, `od -An -tx1 -N4 /dev/urandom` com queda para `00000000`) |
| 16 | `npm run build:plugin`, nunca `build-plugin.sh` | §5.5, §11.1, §15 | verificado que existe (`package.json:23`) e **não executado de propósito** — ele escreve arquivo rastreado, e a fronteira está declarada |
| 17 | `lib/pbt.mjs` com seed fixa registrada no gate | §9.1, `[22]`, `[23]` | verificado que existe; a seed é escolha do implementador, registrada no gate |
| 18 | `SCRIPT_DIR`/`ROOT` no idioma de `archive-spec.sh:17-18` | §7 | verificado no arquivo real, remedido nesta rodada |
| 19 | Validação de formato do digest em `deploy_digest_validate` | §7, `[13]` | **convertido em propriedade** — aceita `sha256:` mais 64 hex minúsculos e nada mais; a prova é a tabela de seis variantes rodada contra o primitivo escolhido, e a mutação (f) removendo a âncora de fim dele |
| 20 | Extração de `stages_declared` de `DEPLOY_STAGES` | §8, `[9]` | **convertido em propriedade** — o número sai da constante, sem redigitação e sem passar pelo manifesto; a mutação (e) prova a discriminação |
| 21 | Normalização de `run_id`, `generated_at` e `duration_s` antes do `diff` | §9.2(i), `[11]` | **convertido em propriedade** — valor substituído por marcador constante; o controle positivo do quinto campo divergente prova que a normalização não engoliu a comparação |
| 22 | `engine_sha256` como resumo dos três arquivos do engine | §5.4, `[12]` | **convertido em propriedade** — o resumo cobre `deploy.sh`, `lib/deploy-common.sh` e o adaptador carregado, e muda quando qualquer um dos três muda; o primitivo de resumo é do implementador |
| 23 | `forge_universe_check "deploy-adapters" <n> "adaptador(es)" "lib/ci"` | §8, `[10]` | **convertido em propriedade mais piso** — universo vazio reprova e `n >= 2`; a função é da casa e o comportamento dela está medido na §4(f) |
| 24 | `bash -n` limpo e zero construção de bash 4+ | `[1]` | **convertido em propriedade** — a lista de construções proibidas é a da invariante 8 do plano; o primitivo de varredura é o do `w142[8]`, e o implementador prova com um arquivo sintético que contém cada construção |
| 25 | `deploy.sh` **propaga** a saída da chamada de fase em vez de a capturar | §4(f), §5.4, `[24]` | **executado** nesta rodada nas duas fiações — propagada devolve 1 ocorrência do motivo na saída, `out="$(…)"` devolve 0, e o rc é 0 nas duas, o que torna o texto a única evidência observável; o primitivo continua do implementador, e a saída dos dois arranjos está colada na §4(f) |

**Segunda tabela — os comandos de medição, que afirmam fatos do repositório.** Esses continuam sendo prescrição de comando exato, e legitimamente, porque a saída deles está colada; a obrigação da invariante 19 aqui é **remedir**, e remedi todos na revisão 4 e de novo nesta rodada — os cinco que a revisão 5 tinha razão de reconferir (`git ls-files | grep -c .`, os dois coletores, o subconjunto de `template/.forge/scripts` e as sete linhas do inventário do `README.md`) devolveram exatamente os mesmos números, então nenhuma linha da tabela abaixo mudou entre a revisão 4 e esta. O documento publica **65** linhas de comando com saída, contra 16 na revisão 3, e o número vem com o critério que o produz — `grep -cE '^[[:space:]]*\$ '` sobre este arquivo —, porque contador sem critério é o que esta seção existe para não deixar passar. Três resultados mudaram desde a revisão 3, e os três estão registrados no corpo:

| Afirmação | Estado na revisão 3 | Remedido nesta rodada |
|---|---|---|
| `git ls-files \| grep -c .` | 1167 | **1168** — `c41eead` acrescentou um arquivo ao índice; a forma de propriedade mais piso da §11 é o que sobrevive |
| `git show HEAD:…pentest.md \| sed -n '146p'` contra a árvore | discriminava "quatro" de "seis" | **deixou de discriminar** — a Fase 0 foi commitada; exemplo reancorado em `c41eead^`/`c41eead` |
| `tests/npx-pack-gate.sh:40` é "o único literal de contagem de arquivos do template em toda a suíte" | afirmado como medição | **falso** — o `w200` afirma `scripts/ (136)` do `README.md`; corrigido na §11 e na §11.1 |
| coletores `shell-pipeline` e `heredoc-hash` na raiz | 226 e 226 | 226 e 226, sem alteração |
| subconjunto `template/.forge/scripts` | 73 | 73, sem alteração |
| censo dos 13 consumidores | 9 sem `run-gates.sh`, 4 com `gates:`, 0 com `phase:` | 9 sem `run-gates.sh` (lista nominal idêntica), **3** com `gates:`, 0 com `phase:` |
| `deploy-orchestrator.md` | 383 linhas, 14 blocos `bash` | 383 e 14, sem alteração |
| `grep -rn -- "--phase"` fora da definição da flag | rc 1, zero ocorrências | rc 1, zero ocorrências |
| `grep -rlEi 'gitlab\|jenkins\|…' template/ \| wc -l` | 0 | 0 |
| `red-evidence.sh` sem `GITHUB_`/`GH_`/`actions`/`gh ` | rc 1 | rc 1 |
| tabela dos dois regexes de digest | seis linhas | seis linhas, idênticas |
| sete desfechos da chamada `--phase` | medidos | remedidos: caso 1 rc 0, caso 3 rc 1, caso 4 rc 0 com `NO-GATES`, caso 5 rc 1, caso 6 rc 127 |


---

## 21. Respostas ao veredito da revisão 4

Dois bloqueadores novos e cinco ressalvas de redação, num veredito que confirmou por medição própria os dois bloqueadores da revisão 3 e não achou reincidência de nenhum anterior. **Os dois bloqueadores procedem e estão fechados**, e as cinco ressalvas foram aceitas — uma delas era mais grave do que o veredito diz, e o registro está no fim desta seção. Refutei uma metade do bloqueador novo 1: não a existência do defeito, que é real, mas a forma da correção (i) que o revisor ofereceu, que custa dois campos e não um. Como nas rodadas anteriores, remedi cada afirmação com comando meu antes de aceitá-la.

### Novo 1 — o motivo da isenção do caso 4 não cabe no recibo que a spec fecha

**Procede, e o diagnóstico do revisor está exato nas três saídas.** A §4(f) e o `[24]` exigiam, em letra, `skipped-declared` "com o motivo copiado para o manifesto e rc 0", e a §5.4 fecha o recibo em 25 campos nomeados mais 13 linhas `stage.` mais 3 finais, K = 41, com o `[12]` asserindo as três parcelas separadamente, a propriedade 1 do PBT asserindo as 41 linhas e a §5.2 mandando `deploy.sh` sair 5 sem gravar nada quando o manifesto não tiver K linhas. Gravar uma linha nova estoura o K e dispara o autocontrole (rc 5, sem manifesto, matando o rc 0 que o `[24]` cobra); omitir reprova a metade explícita do `[24]`; embutir no valor de `stage.gates-pre-deploy:` colide com o enum de veredito do `[9]`. Não era redação: era um dado obrigatório sem lugar num recibo de tamanho fixo asserido por três asserções.

**Refutação parcial da correção (i), com medição.** O revisor ofereceu "acrescentar um 26º campo (por exemplo `gates_waiver_reason`) e refazer o K para 42". Medi antes de escolher e o campo único não é suficiente: as duas fases têm isenções independentes na mesma execução, com motivos diferentes, e `forge_universe_waiver` as devolve separadamente por chave — a saída está colada na §4(f). Um campo teria de escolher um dos dois ou concatenar, que é o colapso de estados da invariante 2 dentro do recibo. A correção (i) honesta custa **dois** campos, K = 43, e arrasta a sanitização para valores que passam a vir de arquivo do projeto e não de `argv` — preço em três contadores (§5.4, `[12]`, propriedade 1 do PBT), em duas asserções e na lista de literais legítimos da §8.

**Fechei pela correção (ii), e por três razões medidas, não por ser a mais barata.** Primeira: o motivo já é impresso pelo canal real, em **stdout** — `gate-universe.sh:70` o ecoa sem `>&2`, e medi o stderr vazio no caso 4 —, então o que falta não é campo, é a propriedade de `deploy.sh` **não engolir** a saída da fase. Medi as duas fiações e o contrafactual discrimina onde o rc não discrimina: propagada devolve uma ocorrência do motivo na saída, `out="$(run-gates.sh …)"` devolve zero, e as duas devolvem `rc_fase=0`. Segunda: o motivo é recuperável sem o recibo, e o recibo é quem ancora a recuperação — `.forge/empty-universe-allowlist.txt` é arquivo rastreado (`git ls-files` o lista, e nenhum padrão do `installer/gitignore.patch` o alcança: o bloco gerido ignora `.forge/cache/`, não a raiz de `.forge/`), e o manifesto grava `sha`. Terceira: copiar para o recibo um dado versionado cria duas cópias que nada compara, que é `LDG-0014` de novo — e esta spec já paga um assert (`[21]`) só para impedir que duas cópias divirjam em silêncio.

**O que mudou no documento:** a linha do caso 4 na tabela da §4(f); o parágrafo final da §4(f) ("Por que `deploy.sh` NÃO declara isenção ao chamar"), que agora descreve o desfecho completo — `stage.gates-pre-deploy: skipped-declared`, `gates_pre_deploy: 0`, motivo na saída, rc 0; um bloco normativo novo na §4(f) com as três medições coladas; um marcador na §4(c), cuja coluna "Manifesto" dizia "o motivo declarado" onde o recibo grava a contagem do universo; uma regra nova na §5.4 dizendo que o motivo **não** é campo; a reescrita do `[24]`, que passa a cobrar o texto do motivo **da própria fixture** — nunca o rótulo `justificativa declarada:` de `gate-universe.sh`, porque acoplar o gate à prosa de outro arquivo é a família de defeito que a própria §4(f) proíbe — mais o contrafactual da fiação que engole; e uma linha na §15. **O K continua 41**, e nenhum dos contadores do recibo se move.

### Novo 2 — a regra do `skipped-declared` contradizia o desfecho verde do caso 4

**Procede, e é contradição entre seções sobre o mesmo estado.** A §5.1, a §8 e o `[15]` escreviam a regra sobre estágio qualquer — `skipped-declared` sem motivo em `runtime.deploy.skip.<estagio>` vira `failed` e o deploy sai 3 —, e o único caminho pelo qual `gates-pre-deploy`/`gates-post-deploy` chegam a `skipped-declared` é o caso 4, onde o motivo mora na `empty-universe-allowlist.txt`, nunca em `runtime.deploy.skip`, e onde a §4(f) proíbe expressamente `deploy.sh` de declarar isenção própria. Lida como estava, a regra convertia o estágio em `failed` contra o rc 0 que o `[24]` e a §15 cobram; lida com a exceção que ninguém escreveu, o `[15]` deixava dois dos treze estágios sem cobertura.

**Fechei declarando a fonte do motivo por classe de estágio**, que é o que o revisor propôs, com uma tabela normativa na §5.1: os **onze** estágios de mecânica (`preflight`, `build`, `digest`, `scan`, `signature`, `sbom`, `release`, `rollout`, `smoke`, `admission`, `tag`) leem `runtime.deploy.skip.<estagio>` e caem em `failed`/rc 3 sem motivo; os **dois** de fase leem a allowlist por `forge_universe_waiver` e caem em `inconclusive`/rc 4 quando a isenção é anônima — que é o caso 5 da §4(f), já medido. A disciplina é a mesma nos dois — isenção anônima nunca produz `skipped-declared` —, e o desfecho da recusa difere porque na fase quem recusa é `gate-universe.sh` e o que ele devolve é ausência de verificação, não violação observada.

**Fechei também a porta que a correção abriria se ficasse só nisso.** Com a fonte declarada por classe, nada impediria um projeto de escrever `runtime.deploy.skip.gates-pre-deploy` no `FORGE.md` e obter `skipped-declared` por um canal sem a rejeição de isenção anônima que `gate-universe.sh:73-76` impõe — uma segunda porta, mais fraca, para o mesmo estado. A §5.1 declara que `runtime.deploy.skip` **não** é fonte de motivo para os dois estágios de fase e que uma chave dessas é inerte, e o `[24]` ganhou o cenário pareado que prova a inércia: com a chave declarada e nenhuma isenção na allowlist, o desfecho é idêntico ao do caso 3, `inconclusive` e rc 4. **Os asserts continuam 27** — a inércia entrou como sub-cenário do `[24]`, não como bloco novo — e os sete desfechos da §4(f) continuam sete, porque o pareado é uma variante do caso 3 e não um oitavo desfecho.

### As cinco ressalvas de redação

1. **A contrapositiva do `[12]` afirmada sem a exceção que a tabela da própria §5.2 declara.** Aceita. O parágrafo do rc 5 agora diz o escopo em letra: nos rc 3 e 4, e no rc 0 **com `runtime.deploy` declarado**, o manifesto existe e tem K linhas; o rc 0 do pulo declarado sob `--from-config` não grava recibo. A §5.4 ganhou a mesma oração na frase que diz onde o manifesto é gravado, e a §15 também — eram três lugares dizendo "rc 0, 3 e 4" sem a exceção, não um.

2. **O terceiro ancoradouro descrito como "o que a execução de fato percorreu".** Aceita, e **ela era mais grave do que o veredito diz**: a §15 cobra `literal 13 == stages_declared == linhas stage. == stages_examined` em **todos os desfechos que gravam manifesto**, e sem uma regra que diga o veredito do estágio não alcançado essa linha é **impossível de cumprir** nos três desfechos que interrompem antes de `build` (`[4]`, `[6]`, `[24]`) — o implementador ou gravaria menos de treze linhas, reprovando a §15, ou inventaria um veredito fora do enum do `[9]`. A §5.4 fixa agora que estágio não alcançado é gravado como `inconclusive`, o que torna o `verdict: inconclusive` do `[4]` derivável da tabela de precedência em vez de mágico; a prosa da §8 foi corrigida junto, e a §5.4 diz o que `stages_examined` de fato mede — cobertura do recibo sobre `DEPLOY_STAGES`, com o veredito de cada linha dizendo o que executou.

3. **Oito binários stubados na §4(e) contra "os sete por NOME" no `[0]`.** Aceita, e a medição mostra que não é contagem de prosa: montei os dois espelhos e o de sete deixa em `bin7/git` um symlink para `/usr/bin/git`, de modo que instalar o stub por cima **escreve através do symlink** — no macOS o sistema recusa (`Operation not permitted`, rc 1) e a fixture fica sem o stub acreditando tê-lo instalado, e num alvo gravável a mesma linha atinge o binário apontado, o que o controle positivo com um alvo em `$TMPDIR` demonstra. A §4(e) e o `[0]` dizem **oito** nos dois lados, com a saída colada e a razão escrita.

4. **Valores dos campos fixos nos desfechos de interrupção precoce não declarados.** Aceita. A §5.4 fixa o marcador pelo estilo medido da casa — `strix_manifest_write` grava `${R4_IMAGE:-}` vazio e reserva marcador nomeado só para campo de vocabulário fechado —, e a regra carrega uma distinção que importa: `gates_pre_deploy:` **vazio** é "a contagem nunca foi tomada" (o `[4]`, que aborta na resolução do adaptador) e `gates_pre_deploy: 0` é "foi tomada e deu zero" (o `[24]`). Colapsar os dois seria a invariante 2 dentro do recibo, e é o que uma asserção irmã escrita com `-` ou `n/a` teria feito.

5. **O 142 é literal de árvore no corpo.** Aceita. Remedi hoje as sete linhas do inventário (agents 47, commands 56, contracts 5, skills 20, rules 50, schemas 27, scripts 136) e o 142 continua correto como projeção, mas está marcado como **projeção do dia** na §11, na §11.1 e no parágrafo do `w200` — no mesmo espírito do fim da §8, que lista os números publicados e não cobrados. O que a §15 cobra continua sendo a igualdade remedida pelos dois lados no mesmo commit, pelo comando do próprio `w200`.

### O que a varredura desta rodada achou por conta própria

**A mutação (e) dependia de uma decisão que a spec não tinha tomado, e a correção do bloqueador 1 me levou até ela.** A matriz declara que, com um nome removido de `DEPLOY_STAGES`, o manifesto mostra `stages_examined=12` — mas a terceira causa de rc 5 manda `deploy.sh` recusar quando "o manifesto não tiver K linhas", e a spec nunca dizia se esse K é o derivado da constante ou o literal 41. Com o literal, a mutação (e) sairia em **rc 5 sem manifesto**, o efeito declarado na matriz deixaria de ser observável e o `[9]` acusaria por ausência de arquivo em vez de por divergência de contador — um vermelho que passa pelo motivo errado. A §5.4 e a §5.2 declaram agora que o autocontrole confere o K **derivado**, `25 + |DEPLOY_STAGES| + 3`: o executor confere a coerência interna do próprio recibo, e quem confere o valor contratual é o literal do gate, que é exatamente a divisão de trabalho do denominador triplo da §8. A linha (e) da matriz separa, em letra, o que foi medido na bancada da constante do que é consequência de desenho.

**O contrafactual da propagação não vira uma sétima mutação.** Ele é contrafactual de asserção, como o da guarda nua no `[2]` e o do quinto campo divergente no `[11]`, e mora no `[24]`. As mutações continuam **seis**, a e f, cada uma no cenário declarado na sua coluna.

### O que a varredura desta rodada mudou por conta própria

**A §20 ganhou um primitivo e passou de 24 para 25.** A propagação da saída da chamada de fase é prescrição nova — ela nasce da correção do bloqueador 1 —, e entrou na tabela como executada, com as duas fiações medidas e o contrafactual colado. E a segunda tabela da §20 passou a publicar o **critério** do contador de linhas de comando junto com o número, porque um contador sem critério dentro de uma seção cujo assunto é contador que envelhece era a própria lição não aplicada.
