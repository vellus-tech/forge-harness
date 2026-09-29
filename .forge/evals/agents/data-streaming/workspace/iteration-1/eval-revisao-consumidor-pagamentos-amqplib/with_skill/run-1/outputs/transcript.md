# Transcript — eval `revisao-consumidor-pagamentos-amqplib` (with_skill / run-1)

Executado como o agente `data-streaming` (definição em `template/.forge/agents/data/data-streaming.md`,
lida antes de qualquer passo), seguindo o protocolo da seção `## Protocolo` do agente.

## Bootstrap do run de eval

```
cd <worktree-do-eval> && pwd && git branch --show-current
→ <worktree-do-eval>
→ chore/evals-skills-agentes
```
Conferido contra o esperado no prompt — ok, sem divergência.

```
date +%s > .../with_skill/run-1/.t0
mkdir -p .../with_skill/run-1/work
bash .../fixtures/revisao-consumidor-pagamentos-amqplib/setup.sh .../with_skill/run-1/work
```
`setup.sh` roda `node bin/forge.mjs init --target <work> -y --no-plugin`, copia o overlay
(`src/`, `infra/rabbitmq/`, `package.json`) por cima, remove `.forge/skills`, `.forge/agents`,
`.claude/skills`, `.claude/agents` e `plugin/` (o artefato sob avaliação não entra no baseline),
e faz `git init` + commit inicial dentro de `work/` — repositório efêmero da fixture, isolado da
árvore do harness. Executado exatamente como o passo 2 do prompt manda. Saída: exit 0.

## Instalação do artefato (`with_skill`)

Este é o run `with_skill`: o agente e a skill sob avaliação precisam estar presentes no projeto
para eu seguir o protocolo deles (rule/ADR → governança → `scan.sh` → julgamento). `setup.sh` os
remove de propósito (comentário do próprio script: "a rodada com o artefato os instala por cima").
Copiei do template, sem tocar em nada do overlay revisado:

```
mkdir -p work/.forge/skills work/.forge/agents/data
cp -R template/.forge/skills/data-streaming-practices work/.forge/skills/
cp template/.forge/agents/data/data-streaming.md work/.forge/agents/data/
```

Isso é a única escrita na árvore da fixture neste run — maquinaria do harness (agente + skill),
não os arquivos sob revisão. `git status --porcelain` no fim do run confirma: só `?? .forge/agents/`
e `?? .forge/skills/`, nada em `src/` nem `infra/`.

## Passo 1 do protocolo do agente — rules, ADRs e baseline

Lidos: `.forge/rules/data/*.md` (cache, SQL, governança — nenhum cobre mensageria),
`.forge/rules/domain/*.md` (`money-as-cents.md` não se aplica: o payload já usa `valorCentavos`
como inteiro), `.forge/rules/architecture/internal-grpc-communication.md` (não relevante: fluxo
já é assíncrono interno via fila, não gRPC), `.forge/product/current/adr/` (vazio, só `.gitkeep`).
Nenhuma rule ou ADR do projeto trata RabbitMQ — sem decisão do projeto a conflitar com a skill.

## Passo 2 do protocolo — conflito relevante para

Nenhum. Segue direto para governança e varredura.

## Passo 3 do protocolo — dado sensível

```
$ bash .forge/scripts/check-data-governance.sh --path src
FAIL data-governance/universo-vazio — 0 arquivo(s) examinado(s) (src)
exit 1
```
Interpretação pela linha (não pelo exit code): `universo-vazio`, não `CONFLICT` — "não verificado",
porque o gate só lê `.go/.kt/.ts/.rego/.py/.md` e este projeto é `.js`. Não trato como aprovação
nem como "limpo".

```
$ bash .forge/scripts/check-data-governance.sh --path infra/rabbitmq
OK data-governance/universo — 1 arquivo(s) examinado(s) (infra/rabbitmq)
OK data-governance (1 .md, 0 código, no divergence)
exit 0
```
Só o `README.md` entrou no universo (`.json` também está fora da lista de extensões do gate) —
mesma ressalva: `policy.json` não foi verificado por PAN/PII por este script.

## Passo 4 do protocolo — varredura

```
$ bash .forge/skills/data-streaming-practices/scripts/scan.sh --root src --root infra/rabbitmq
INFO data-streaming-practices motor=rg raizes=2 universo=codigo iac proto avsc
FOUND RMQ-AP-01 [alto] 1 ocorrência(s) — src/consumidor.js:16: }, { noAck: true });
FOUND RMQ-AP-03 [aviso] 2 ocorrência(s) — src/consumidor.js:5, src/pagamentos.js:9
OK RMQ-AP-04 [aviso] nenhuma ocorrência
FOUND RMQ-AP-06 [alto] 2 ocorrência(s) — infra/rabbitmq/policy.json:6, :7
OK RMQ-AP-07 [aviso] nenhuma ocorrência
FOUND RMQ-AP-08 [aviso] 1 ocorrência(s) — src/pagamentos.js:18
OK RMQ-AP-09 [aviso] nenhuma ocorrência
FOUND RMQ-AP-10 [alto] 1 ocorrência(s) — src/consumidor.js:14: ch.nack(msg);
OK RMQ-AP-12 [aviso] nenhuma ocorrência
OK RMQ-AP-14, RMQ-AP-15, RMQ-AP-17, RMQ-AP-18, RMQ-AP-19, RMQ-AP-20, RMQ-AP-22, RMQ-AP-28 — nenhuma ocorrência
OK KFK-AP-01, KFK-AP-02, KFK-AP-03, KFK-AP-06, KFK-AP-09, KFK-AP-10, KFK-AP-14 — nenhuma ocorrência
OK INB-AP-01, INB-AP-02 — nenhuma ocorrência
OK D-AP-01, D-AP-02, D-AP-04, D-AP-05 — nenhuma ocorrência
OK SCH-AP-01 — nenhuma ocorrência
OK T-02 — nenhuma ocorrência
ARQUIVOS-VARRIDOS 3
exit 1
```
Usei essa saída (não só a leitura do código) para localizar os candidatos.

## Passo 5 do protocolo — julgamento

Para cada `FOUND` alto/aviso relevante, li o arquivo e a linha e decidi com
`.forge/skills/data-streaming-practices/references/antipatterns.md`:

- **RMQ-AP-10** (`src/consumidor.js:14`) — li o trecho: `ch.nack(msg)` sem segundo/terceiro
  argumento. Conferido em `antipatterns.md`: `requeue=true` é o default no amqplib, e em quorum
  `basic.nack` não conta para `delivery-limit`. **Causa raiz do laço** — confirma o sintoma
  relatado (mesma mensagem voltando, CPU a 100%).
- **RMQ-AP-01** (`src/consumidor.js:16`) — `noAck: true` confirmado por leitura direta.
- **RMQ-AP-06** (`infra/rabbitmq/policy.json:6-7`) — `ha-mode`/`ha-sync-mode` confirmados;
  `antipatterns.md` e `best-practices.md` confirmam remoção no 4.0 e a correção (quorum + policy
  com `delivery-limit` sempre junto de `dead-letter-exchange`).
- **RMQ-AP-08** (`src/pagamentos.js:18`) — `ch.publish` sem `confirmSelect`/`createConfirmChannel`
  antes, confirmado por leitura do arquivo inteiro (não há canal de confirm em outro lugar).
- **OBX-AP-01** — não veio do scanner (catálogo já documenta: detecção é só por revisão). Lendo
  `pagamentos.js:15-18`: `UPDATE` no Postgres e `ch.publish` no mesmo handler, sem transação
  comum nem tabela outbox — dual write.
- **RMQ-AP-03** (aviso, conexão fora de bootstrap) — julguei não relevante à causa do laço: cada
  arquivo abre sua própria conexão de processo (não por mensagem); citei como nota lateral, sem
  bloquear a resposta.

## Passo 6 do protocolo — resposta

Escrita em `outputs/diagnostico.md`, com o antipattern e `arquivo:linha` de cada achado, e o
trecho corrigido em `outputs/correcao/*.patch.md` — recomendação e código só na resposta, nenhuma
escrita nos arquivos revisados (regra "uma árvore, um escritor": quem aplicaria é o agente de
engenharia ou o `task-coder`, não este agente).

## Devolução ao orquestrador

Nada a devolver a outro especialista de dados nesta resposta — o schema da tabela outbox
(`data-relational`) foi citado como nota para trabalho futuro, não como parte pendente desta
revisão.

## Verificação final — árvore intacta

```
$ git -C work status --porcelain
?? .forge/agents/
?? .forge/skills/
```
Só a instalação do artefato sob avaliação (agente + skill, necessária para este run `with_skill`
seguir o protocolo). Nenhum arquivo sob revisão (`src/consumidor.js`, `src/pagamentos.js`,
`infra/rabbitmq/policy.json`) foi alterado.
