# Checkpoint e handoff — 2026-07-29

> Estado operacional para retomada em sessão nova, por qualquer agente. Complementa (não substitui) o `.forge/HANDOFF.md`, gerado por change. O plano do próximo trabalho está **versionado** em [`2026-07-29-api-surface-closure.md`](./2026-07-29-api-surface-closure.md) — diferente do checkpoint anterior, que apontava para um plano em `~/.claude/plans/` e portanto ilegível em qualquer outra máquina.

## 1. Onde o repositório está

Branch `develop` em `46e69a3`, **sincronizada com `origin`, árvore limpa**. Versão `0.2.0` — batendo nos três lugares (`package.json`, `plugin/forge/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`). Tag `v0.2.0` cortada e **publicada no remoto**; npm com `dist-tags.latest = 0.2.0`. `tests/snapshot/verify-manifest.sh` → `OK`.

Suíte completa **68/68 verde** em ~7 min. Rode desacoplada (`nohup npm test > /tmp/suite.log 2>&1 &`) e faça poll — esperar em foreground faz o executor matar o processo. 66 gates + 2 suítes bats. 55 comandos `/forge:*` no plugin.

Dezessete commits desde `57f4f4e`, com **dois releases** no intervalo (`v0.1.0-rc24` e `v0.2.0`).

## 2. O que foi entregue nesta sessão

**Liaison completo, Ondas 1 a 5.** Transporte plugável (`t_probe`/`t_push`/`t_pull`) com quatro backends: `manual` (a primitiva, que **nunca** cria o ponto de encontro — se não existe, o probe reprova), `fs` (default do piloto), `git` (branch órfã dedicada, clone descartável em `.forge/cache/`) e `gh` (declarado e não implementável por script — o harness proíbe invocar o CLI do GitHub em `.sh`, e o gate varre o próprio arquivo). Política de merge **única** em `lib/liaison-import.mjs`, compartilhada por `import` e `sync`. Reescrita de história **reprova** isolando o remetente. Integração ao harness com conteúdo de peer tratado como **dado, nunca instrução** (banner `UNTRUSTED`, fence, neutralização de `/comando:` — prefixando, nunca apagando). Enforcement de ack opt-in: cada participante responde pelo **próprio** ack. `ask` consolidado como subcomando. Gates `w110`–`w113`.

**Proibição imposta de assinatura de IA.** 275 commits marcados em 5 repositórios, quase todos com o trailer `Claude-Session:` — forma que a norma escrita não cobria porque enumerava marcas específicas em vez da prática. Decisivo: o setting `attribution` **já estava zerado** e o commit mais recente saiu marcado. Detecção **estrutural**, nunca textual: 183 dos 186 commits deste repo passam limpos, e os 3 reprovados carregam marca real. Hooks `commit-msg` + `pre-push`. Gate `w120`.

**Harness de property-based testing zero-dep** (`lib/pbt.mjs`) com seed fixa, contraexemplo e shrinking. Rule `testing/property-based-testing.md`. Gate `w121`. **Pagou-se na primeira propriedade**: idempotência de `mergeLogs` encontrou defeito real que doze asserções por exemplo não pegaram.

**Política de versionamento** em `docs/release/sync-policy.md`. As 24 tags `v0.1.0-rc*` eram SemVer válido e semanticamente vazio — o mesmo incremento carregava três features ou um typo. Agora: `MINOR` para feature, `PATCH` para correção, `rc` só quando houver release a candidatar, `1.0.0` quando a superfície de `.forge/` for algo que o projeto se compromete a não quebrar.

**Banner** em `docs/assets/banner.png`, gerado por `tools/gen-banner.mjs` (HTML + Chrome headless, PRNG de semente fixa, reprodutível). Não SVG: fontes do sistema não resolvem em CI nem no GitHub.

## 3. Consumidores — estado real

| Repo | versão | branch | sujos | não publicados |
|---|---|---|---|---|
| `axis-go-cloud` | **0.2.0** | `develop` | 53 | 2 |
| `axis-fare-validator` | **0.2.0** | `develop` | 18 | 0 |
| `Axis.PadSimulator` | **0.2.0** | `develop` | 0 | 3 |
| `azim-crm` | 0.1.0-rc24 | `develop` | 0 | 0 |
| `collatra` | 0.1.0-rc24 | **`chore/forge-update-rc24`** | 0 | sem upstream |
| `payments` | 0.1.0-dev → rc24 na branch | `main` | 36 | sem upstream |
| `secret-weapon/Axis.SecretWeapon` | 0.1.0-rc23 → rc24 na branch | `develop` | 3 | 9 |

**Nada foi publicado** — todos os commits de harness são locais, por decisão. O `collatra` está **na branch de update**, não em `develop`; o `payments` e o `Axis.SecretWeapon` têm o update numa branch `chore/forge-update-rc24` não mergeada.

**Piloto do liaison pronto e verificado ponta a ponta**: `axis-go-cloud` em `enforce: warn` (dono do contrato — travar quem origina não protege ninguém), `axis-fare-validator` e `Axis.PadSimulator` em `enforce: block` (consumidores, que sofrem o drift). Verificado nos repos reais: com contract-change pendente o check reprova (`rc=1`) nos consumidores e passa (`rc=0`) no dono; o ack desbloqueia. Falta escolher as threads iniciais e o hub de transporte real.

**Sem harness**: `oversetter` tem 4 repos git, **nenhum** com `.forge/` — instalar ali é decisão de produto, não minha. `secret-weapon` tem 2 repos, ambos já com `.forge/`.

## 4. Próximo trabalho — plano pronto e versionado

[`2026-07-29-api-surface-closure.md`](./2026-07-29-api-surface-closure.md), seis ondas, decidido por agente Opus e verificado contra o repositório real.

O achado que reordena tudo: **o harness já especifica os checks que teriam pegado o defeito, e ambos são instrução para LLM.** `commands/specs/analyze.md:21` manda cruzar o "Checklist de cobertura de superfície" contra tasks e diz que é isso "que impede a lacuna clássica de parâmetro implementado sem superfície de acesso descoberta só depois do marco" — **não existe script `analyze`**. `commands/specs/tasks.md:27` manda auto-verificar ordem topológica — é checklist em markdown, e deixou passar `TASK-89` (Wave 4) dependendo de `TASK-45` (Wave 7).

Quatro defeitos reproduzíveis hoje sem escrever convenção nova, e a Onda A pega dois deles.

## 5. Ledger

**Oito abertos**: `LDG-0001`/`LDG-0002` (runtime e piloto da capability authz/observability), `LDG-0003` (maquinaria de capability packs), `LDG-0004` (replay Red-first em CI), `LDG-0005` (updater não mescla padrões no managed-block do `.gitignore`), `LDG-0007` (275 commits com assinatura de IA no histórico — **mantido por decisão**, limpar exige reescrever histórico publicado), `LDG-0008` (enforcement determinista de TDD-em-feature e cobertura de PBT), `LDG-0009` (managed-block congelado nos consumidores). **Resolvido**: `LDG-0006` (SIGPIPE nos gates).

## 6. Decisões tomadas — não reabrir sem motivo novo

Liaison: store é um JSONL append-only **por remetente** (um escritor por arquivo é o que torna o merge livre de conflito); thread é campo, nunca arquivo; Lamport **por thread**, porque participação parcial não pode exigir ver threads alheias; abertura de thread e entrada de participante são **mensagens**; a thread **roteia**, o canal **confina** — com hub compartilhado quem alcança o transporte lê tudo, então confidencialidade real exige canal separado; transporte é hub único por canal, não par-a-par; o push publica **apenas** o próprio log.

Versionamento: fora do trem de `rc`. Consumidor se instala **da tag**, nunca do checkout de desenvolvimento — foi assim que o `rc23` virou carimbo sem lastro em quatro repositórios.

`ask` é subcomando de `liaison`, não comando de topo: é o padrão da casa e o `ask` **compõe** o liaison (chama `send` duas vezes).

## 7. Aprendizados operacionais — o que custou caro

**Prova de mutação exige CONTROLE.** Sete mutações apareceram "todas vermelhas" e nenhuma havia sido exercitada: faltava `node_modules` no ambiente espelhado em `mktemp`, e o gate morria antes de chegar na mutação. **O espelho tem que ficar verde SEM mutação antes de qualquer resultado valer.**

**Invariância sob permutação passa trivialmente se o embaralhador não embaralha.** A mutação que fazia `shuffle` devolver a lista intacta sobreviveu — a asserção sobre o próprio gerador é parte do teste.

**`echo "$var" | grep -q` derruba gates aleatoriamente.** O `grep -q` sai no primeiro match e fecha o pipe; o produtor recebe SIGPIPE e retorna diferente de zero, reprovando comportamento correto. Quatro execuções da suíte reprovaram gates **diferentes**, todos verdes isolados. 184 asserções em 33 gates convertidas para here-string.

**`[ cond ] && cmd` sob `set -e` mata o gate SEM imprimir nada.** O sintoma é um gate parando no meio de um passo, sem mensagem. Instrumentar com FAIL explícito é o que torna o próximo diagnóstico possível — e foi o que revelou o bug seguinte.

**Em bash o segundo `trap ... EXIT` SUBSTITUI o primeiro.** Ao instrumentar, adicionei um segundo trap e o fixture parou de ser limpo — 125 diretórios vazados em `/tmp`. Um único trap cobrindo os dois caminhos.

**`node -` usa o stdin para o próprio programa.** Alimentar dados por stdin faz o scanner analisar o vazio e **aprovar tudo** — a pior falha possível: silenciosa e sempre verde.

**O overlay do `update` zera `capabilities.active` em silêncio.** Conferir depois de todo update; já desativou o pack Java do `fare-validator` uma vez.

**`git add -A` em workspace com repos aninhados** adiciona gitlinks; e `.forge.bak-N`/`.codegraph` entram no commit se o managed-block do `.gitignore` estiver congelado. Aconteceu no `payments`: 455 arquivos e 205 mil linhas, com um binário de 50 MB. Corrigido para 187/11,5k.

**Relatório de subagente não é prova.** O agente Opus concluiu que "a informação não está lá" para o caso do Secret Weapon; a leitura do arquivo refutou — o Checklist declara a superfície e as tasks que a cobrem. A conclusão errada teria feito a convenção nova virar preço de entrada sem necessidade.

**Passo manual atrelado a bump é passo esquecido.** O `marketplace.json` saiu uma versão atrás no `rc24`, descoberto pelo gate depois da tag cortada. Agora o `build:plugin` sincroniza.

## 8. Convenções obrigatórias

Fonte canônica é `template/.forge/**`; `plugin/` é derivado (`npm run build:plugin`, commitado, senão `plugin-sync-gate` trava). Libs `.mjs` **zero-dep**. Schemas não são validados em runtime — a validação equivalente é reimplementada à mão. Gates entram por glob em `tests/run-all.sh`. Asserção nova **nasce vermelha**. Pré-requisito faltando **reprova**, nunca desliga o gate. Portabilidade morde só no CI Linux (`sed -i.bak`, `mktemp` com X terminais, sem `readlink -f`/`grep -P`). Commits sem marca de coautoria de IA — agora **imposto** por hook. PR mira `develop`, nunca `main`. Subagente sempre com `model` explícito.
