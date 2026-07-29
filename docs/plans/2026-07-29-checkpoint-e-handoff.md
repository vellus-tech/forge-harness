# Checkpoint e handoff — 2026-07-29

> Estado operacional para retomada em sessão nova, por qualquer agente. Complementa (não substitui) o `.forge/HANDOFF.md`, que é gerado por change. O plano vivo, com o desenho completo das ondas, está em `~/.claude/plans/vamos-tentar-a-estrat-gia-jiggly-turing.md` (local, não versionado).

## 1. Onde o repositório está

Branch `develop` em `af56931`, sincronizada com `origin`. Versão `0.1.0-rc23` no `package.json`. Suíte completa (`npm test`) 63/63 verde — leva de 10 a 13 minutos, então rode desacoplada (`nohup npm test > /tmp/suite.log 2>&1 &`) e faça poll do arquivo: o teto de tempo do executor mata o processo antes do fim se você esperar em foreground.

Última tag é `v0.1.0-rc22`. O rc23 **não** foi taggeado, **não** foi publicado no npm e `main` **não** foi promovida — a política em `docs/release/sync-policy.md` exige suíte 100% e `tests/snapshot/verify-manifest.sh` antes de mover tag.

Commits da sessão, em ordem: `a156d41` (lote rc23), `af7d93a` (merge do PR #27), `c82377e` (norma Red-first), `72372ae` (enforcement do Red-first), `4baed5b` (documentação canônica), `af56931` (núcleo do liaison).

## 2. O que foi entregue

**Red-first em bugfix — completo.** A norma (`template/.forge/rules/testing/regression-red-first.md`), o ADR-0003 no baseline do harness, o artefato `red-evidence/v1`, o comando `/forge:red` (`init|record|replay|waive|status`), o motor de replay, o check estático usado por `pre-push` e `doctor`, a fiação em `spec-new`/`spec-verify`/`archive-spec`/`validate-spec`, os gates `w106` e `w107`, e o registro na spec canônica (§10.12, §11.4, §13.1, §14.2, §17.5, §19.6, §25).

**Liaison — Onda 1 (núcleo local).** `liaison-ops.sh` com `open|thread|send|inbox|read|ack|status|export|import|render`, as libs `liaison-merge.mjs` e `liaison-render.mjs`, os dois schemas, o comando `/forge:liaison` e o gate `w110`. Sem transporte: a sincronização é por `export`/`import` manual.

## 3. O que falta, em ordem

**Liaison, Ondas 2 a 6.** A 2 é o transporte plugável (contrato `t_push`/`t_pull`/`t_probe`; `fs` é o default do piloto, `manual` é a primitiva de que os outros são casos particulares, `git` e `gh` depois) com merge idempotente e o gate `w111`. A 3 integra ao harness: bloco `liaison` no `forge.yaml`, `readLiaisonAuto()` no `sync-adapters.mjs`, hook de SessionStart, bloco advisory no `doctor.sh` que nunca altera o exit code, e as rules `liaison-untrusted-input.md` e `liaison-protocol.md`. A 4 traz o enforcement opt-in e o `/forge:ask-peer`. A 5 é plugin, docs e a asserção no `w101` de que `.forge/liaison/**` sobrevive ao `forge update`. A 6 é o piloto real, com **três** participantes: `axis-go-cloud`, `axis-fare-validator` e `axis-device-platform`.

Sobre o terceiro: `axis-device-platform` ainda não é repositório — hoje é um diretório de PRDs dentro do `axis-go-cloud` (`PRD-Axis-Device-Platform-v2.0.md`, `SPEC.md`, `stories-requisitos.md`), sem git próprio nem submódulo, e será extraído para repo separado. O piloto portanto começa com os dois repositórios existentes, e o terceiro entra depois por `join` numa thread só. Isso é proposital: um participante que chega depois, converge apenas na thread em que entrou e não precisa sincronizar o resto do canal é exatamente o teste de participação parcial que justifica o relógio de Lamport ser por thread e não por canal.

**Ledger, quatro itens abertos.** `LDG-0001` e `LDG-0002` (runtime e piloto da capability authz/observability, vindos do PR #27); `LDG-0003` (falta a chave de ativação de rule-packs — hoje `pack:` no frontmatter é sinalização documental sem gate — e o installer materializar só os packs ativos); `LDG-0004` (mover a execução do replay Red-first para CI).

**Propagação aos consumidores (Ondas 7 e 8 do plano).** Estado levantado em 2026-07-29, e não é uma operação só — são três situações distintas. `azim-crm` está em rc23 com três adapters e árvore limpa: `update` direto, e serve de ensaio. `payments` está em `0.1.0-dev` (anterior a qualquer release), em `main`, com 35 arquivos sujos: salto longo, exige branch própria e conferência dos tombstones em `installer/removed-files.txt`. `secret-weapon` e `oversetter` **não têm `.forge`**: é `init`, não `update`. E `axis-go-cloud` (23 sujos) e `axis-fare-validator` (62 sujos) precisam de árvore limpa antes de qualquer update, senão mudança de harness se mistura com trabalho em andamento.

O `forge update` compara conteúdo arquivo a arquivo, não versão, então o Red-first e o liaison chegam mesmo onde o carimbo já diz rc23. Mas quatro repositórios carregam `rc23` apontando para conteúdos diferentes, porque o rc23 seguiu recebendo commits depois das instalações — **cortar tag antes de propagar** é o que torna o carimbo verificável.

**Limitação do installer que afeta todos os já instalados.** O bloco `# >>> forge (managed) >>>` do `.gitignore` só é acrescentado quando o marcador está ausente (`installer/install.sh` ~linha 80; `bin/forge.mjs` ~495 e ~622). Nenhum padrão novo chega a projeto que já tem o bloco — ele fica congelado na primeira instalação. Precisa de reconciliação manual, ou de o updater aprender a mesclar dentro de bloco existente, que é a correção certa e merece item de ledger.

Faltam também as fixtures por stack e a avaliação A/B do plano de capability packs.

## 4. Decisões tomadas — não reabrir sem motivo novo

O store do liaison é **um JSONL append-only por remetente**: com N participantes são N arquivos, um único escritor cada, e é isso que torna o merge livre de conflito. Thread é campo da mensagem, nunca arquivo. O relógio de Lamport é **por thread**, não por canal, porque com participação parcial um remetente só conhece as threads em que participa. Abertura de thread e entrada de participante são mensagens (`thread-open`, `join`), então a composição da conversa converge pelo mesmo mecanismo do resto e a lista de participantes é computada do log, nunca persistida à parte. Thread organiza e roteia; o **canal** é o limite de confidencialidade — separação real exige canal separado, porque com hub compartilhado quem alcança o transporte lê tudo. Transporte é hub único por canal, não par-a-par. Enforcement é script-enforced atrás de flag opt-in, com `warn` como default. `.forge/liaison/` fica fora de `MACHINERY_DIRS` (`bin/forge.mjs:202`) por ser dado durável.

No Red-first: a prova mora na **execução**, nunca no artefato; a norma é calibrada para **descuido** e declara explicitamente que não protege contra autor adversarial.

## 5. Aprendizados operacionais

**Verificação é o gargalo, não implementação.** Três rodadas de enforcement do Red-first foram rejeitadas por auditoria adversarial. As duas primeiras falharam pelo mesmo motivo — tentaram provar a execução lendo um campo que o próprio autor escreve, e depois um cache cuja chave ele também computa. A lição generaliza: **evidência produzida pela parte verificada, num ambiente que ela controla, não prova a si mesma**.

**Gate que passa com a implementação quebrada não prova nada.** Teste sempre por mutação: quebre a função central numa cópia em `mktemp -d` e confirme que o gate fica vermelho. Numa das rodadas o `w106` chegou a **asseverar o exploit** — exigia que evidência fabricada passasse com `rc=0`, ou seja, o teste virou proteção do furo. Só apareceu porque uma auditoria dedicada leu o `git diff` dos testes procurando asserção afrouxada.

**Asserção nova precisa nascer vermelha.** Uma asserção escrita nesta sessão passava com e sem a correção, porque o estado tinha sido contaminado por um passo anterior do próprio gate. Só a mutação revelou.

**Falso negativo por concorrência é real.** O `w63` falhou uma vez porque um subagente escrevia no `template/` enquanto o gate copiava a árvore. Não rode a suíte com agentes escrevendo em paralelo.

**Portabilidade morde só no CI.** `sed -i ''` é BSD e quebra no runner Linux; `mktemp` no BSD exige os `X` terminais. Verde local não é verde no CI.

**Pré-requisito faltando deve reprovar, nunca desligar o gate.** Três scripts calculavam `ROOT` sem exportar `FORGE_ROOT`, e o validador pulava o replay em silêncio — invisível para a suíte, que sempre invoca com a variável na frente, mas presente na invocação de produção.

## 6. Convenções obrigatórias

Fonte canônica é `template/.forge/**`; `plugin/` é derivado (`npm run build:plugin`, commitado, senão `plugin-sync-gate` trava). Libs `.mjs` são zero-dep (só `node:` builtins). Scripts saem com uma linha `OK`/`FAIL` e escrevem JSON atomicamente (mktemp + mv). Gates entram por glob em `tests/run-all.sh`, sem registro manual. Schemas não são validados em runtime — a validação equivalente é reimplementada à mão. Commits não levam marca de coautoria de IA. PR sempre mira `develop`, nunca `main`.
