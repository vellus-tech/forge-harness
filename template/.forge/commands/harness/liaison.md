---
description: Canal de mensagens ORDENADAS entre agentes de repositórios distintos (ex.: dono do .proto/gRPC e app cliente) — elimina drift de handoff manual. Store JSONL append-only por remetente, thread como campo, relógio de Lamport por thread, abertura de thread e entrada de participante como mensagens auditáveis. Transporte plugável (fs, git, manual) com sync idempotente e merge append-only. Operado por script determinista — exceto o subcomando ask, consulta síncrona a um peer sob mandato read-only.
argument-hint: "[open|thread|send|ask|inbox|read|ack|status|export|import|peer|transport|sync|render] [flags]"
---

# /forge:liaison — canal de mensagens ordenadas entre repositórios

Argumentos: `$ARGUMENTS`. Sem subcomando, mostra `status` (resumo de todos os canais conhecidos
localmente).

> **Por que existe:** repositórios distintos que colaboram por contrato (ex.: `axis-go-cloud`,
> dono dos `.proto` gRPC, e `axis-fare-validator`, app Android cliente) hoje trocam handoff por
> arquivo manual — e o contrato sofre drift porque nada garante que as duas pontas viram a mesma
> sequência de decisões. O liaison é um canal com **ordem garantida**, **N participantes** e
> **múltiplas threads**, sem exigir um servidor compartilhado.

## Modelo (leia antes de operar)

- **Store: um JSONL append-only por remetente** — `.forge/liaison/<channel>/log/<sender>.jsonl`.
  Um único escritor por arquivo é o que torna o merge entre réplicas livre de conflito.
- **Thread é campo da mensagem** (`thread_id`), não arquivo — várias threads convivem no mesmo
  conjunto de logs.
- **Lamport é por THREAD, não por canal** — um participante com participação parcial só conhece
  as mensagens das threads em que está; um relógio por canal exigiria ver threads alheias para
  incrementar. Ordem dentro da thread: `(lamport, sender, seq)`. Entre threads não há ordem
  definida, e não precisa haver.
- **`seq` é monotônico e sem buracos por remetente** — é o detector de mensagem perdida.
- **Abertura de thread (`kind: thread-open`) e entrada de participante (`kind: join`) são
  mensagens**, não configuração editada por fora — a composição da thread converge pelo mesmo
  mecanismo do resto do canal e fica auditável no próprio log.
- **Visibilidade: a thread ROTEIA, o canal CONFINA.** A lista de participantes de uma thread
  define quem é cobrado por ack e para quem o roteamento se dirige — **não** quem pode ler. Com
  hub compartilhado, quem alcança o transporte lê tudo; prometer isolamento por thread
  seria falsa sensação de segurança. Confidencialidade de verdade exige canal separado.
- **`export`/`import` são a primitiva de sincronização** — copie o diretório exportado para o
  outro repositório (scp, PR, drive, o que for) e importe do outro lado. O transporte automático
  (`sync`) é essa mesma primitiva com o transporte fazendo a cópia; o backend `manual` é
  literalmente ela.

## Protocolo

```bash
# inicializar (uma vez por canal; --self só na primeira chamada de qualquer canal deste repo)
bash .forge/scripts/liaison-ops.sh open <channel> --self <meu-id> --participants <a,b,c>

# threads são mensagens
bash .forge/scripts/liaison-ops.sh thread open <channel> <thread-id> \
  --subject "<txt>" --participants <a,b,c> [--body "<txt>"] [--requires-ack]
bash .forge/scripts/liaison-ops.sh thread join <channel> <thread-id> [--subject "<txt>"] [--body "<txt>"]
bash .forge/scripts/liaison-ops.sh thread list <channel>

# enviar (kind: note|question|answer|contract-change — ack/thread-open/join têm subcomando próprio)
bash .forge/scripts/liaison-ops.sh send <channel> --thread <id> --kind <k> --subject "<txt>" \
  [--body "<txt>" | --body-file <path>] [--requires-ack] [--in-reply-to <msg_id>] \
  [--change <change-id>] [--contract-files <a,b>] [--commit <sha>]
bash .forge/scripts/liaison-ops.sh ack <channel> <msg_id> [--subject "<txt>"]

# consultar
bash .forge/scripts/liaison-ops.sh inbox  <channel> [--thread <id>]   # não lido por thread
bash .forge/scripts/liaison-ops.sh read   <channel> --upto <msg_id>   # avança o cursor local
bash .forge/scripts/liaison-ops.sh status [<channel>]                 # one-line

# sincronização manual (a primitiva — sempre disponível, sem configurar nada)
bash .forge/scripts/liaison-ops.sh export <channel> --out <dir>
bash .forge/scripts/liaison-ops.sh import <channel> --from <dir>

# transporte (configura o ponto de encontro do canal, uma vez por repositório)
bash .forge/scripts/liaison-ops.sh transport set   <channel> --kind fs --path <dir-do-hub>
bash .forge/scripts/liaison-ops.sh transport set   <channel> --kind git --remote <url> [--branch <b>]
bash .forge/scripts/liaison-ops.sh transport show  <channel>
bash .forge/scripts/liaison-ops.sh transport probe <channel>          # o ponto de encontro responde?

# sincronizar (push do próprio log + pull dos demais, na mesma chamada)
bash .forge/scripts/liaison-ops.sh sync <channel> [--push-only | --pull-only]

# regenerar a view mestre
bash .forge/scripts/liaison-ops.sh render <channel>                   # <channel>/CHANNEL.md
```

## Transporte

O transporte é **plugável** (`scripts/lib/transports/<kind>.sh`, contrato `t_probe`/`t_push`/
`t_pull`) e move **arquivos opacos**: não parseia mensagem, não sabe o que é thread, não decide
merge. A política de merge é uma só — a mesma para `import` e para `sync` — porque duas políticas
fariam a mais frouxa virar o caminho de menor resistência.

| kind | ponto de encontro | quando |
|---|---|---|
| `manual` | diretório com `log/` + `blobs/`, no layout exato do `export` | a fronteira não é cruzável por script (pendrive, anexo, VPN montada à mão). **Nunca cria o diretório**: se ele não existe, o `probe` reprova, para você não publicar num lugar que ninguém combinou |
| `fs` | `<path>/<channel>/{log,blobs}`, criado sob demanda | default do piloto — dois repositórios na mesma máquina ou num volume compartilhado |
| `git` | branch **órfã** dedicada num remote, clone de trabalho descartável em `.forge/cache/liaison/<channel>` | os participantes não compartilham filesystem. Branch órfã por construção: sem ancestral comum com o código, nunca vira candidata a merge nem dispara CI |
| `gh` | — | **declarado, não implementável por script.** O harness proíbe invocar o CLI do GitHub em `.sh` (rede, auth interativa, estado irreprodutível em gate); o backend reprova por construção. A via por issue é sua, agente, com as ferramentas que você tem |

**Topologia: hub único por canal, nunca par-a-par.** Cada participante publica o próprio log no
ponto de encontro e puxa os N−1 restantes — a configuração cresce como N (cada repo aponta para um
lugar), não como N². Par-a-par deixaria dois participantes divergentes por tempo indeterminado sem
ninguém perceber.

**O push publica apenas o próprio log.** Um participante nunca republica o log de terceiro: se o
fizesse, publicaria a versão possivelmente atrasada que ele conhece, regredindo o hub e apagando
mensagens que o dono do log já havia enviado.

**Sem transporte configurado, `sync` REPROVA** citando o comando que falta. Pré-requisito ausente
nunca desliga a sincronização em silêncio contra um default inventado — o canal ficaria mudo com
cara de funcionando.

## Regras de import (o que protege o canal de um peer malicioso ou corrompido)

- `sender` da mensagem é conferido contra o arquivo em que ela chegou (`log/<X>.jsonl` só pode
  conter `sender: X`) — divergência mata spoofing e vai para `<channel>/conflicts/`.
- Mensagem que se declara com o `self.id` local vinda de fora é recusada.
- Duplicata com `content_sha` igual é **no-op silencioso** — é o que torna `sync` idempotente.
- Adulteração em trânsito (`content_sha` não confere com o conteúdo) vira conflito em `conflicts/`,
  sem tocar o log.
- **Reescrita de história REPROVA.** O log de um remetente é append-only: uma posição (`seq`) já
  conhecida não pode chegar com outro `msg_id` ou outro `content_sha`. Quando chega, é
  **divergência** — nenhuma mensagem daquele remetente é aplicada, o comando sai com erro nomeando
  quem divergiu, e o registro vai para `conflicts/<sender>.divergence.json`. A divergência isola o
  remetente: os demais continuam sendo aplicados, para que um peer corrompido não trave o canal
  inteiro.
- Mensagem cujo `thread_id` não tem `thread-open` correspondente **ainda conhecido localmente**
  fica em quarentena (recalculada a cada `render`/`inbox`, nunca persistida à parte) — liberada
  automaticamente assim que a abertura chega.
- Tetos: corpo inline ≤2 KB (acima disso, use `--body-file`, vira blob ≤64 KB); ≤200 mensagens
  por chamada de `import` (excedeu = nada é aplicado, atômico).
- `trust` é carimbado no IMPORT (`self` só para o que este repositório escreveu; tudo que veio de
  fora vira `untrusted-peer`, mesmo que a mensagem alegue outra coisa) — nunca decidido pelo
  remetente.

## `ask` — consulta síncrona a um peer

`liaison ask <canal> <thread> <participante> "<pergunta>"`.

O fluxo normal do canal é **assíncrono**: você manda `question --requires-ack` e o outro lado
responde quando abrir a sessão dele. Isso é o certo na maioria dos casos. O `ask` existe para
quando a resposta bloqueia o trabalho **agora** e o repositório do peer está acessível nesta
máquina — tipicamente desambiguar um contrato antes de gerar stub.

**Esta é a única operação do liaison que não é determinista.** Todo o resto é script puro; o `ask`
invoca um agente e depende de julgamento. A fronteira importa: o resultado de um `send` é sempre o
mesmo, o de um `ask` não é.

```bash
# 1. registrar a pergunta — SEMPRE primeiro, antes de consultar
bash .forge/scripts/liaison-ops.sh send <canal> --thread <thread> --kind question \
  --subject "<pergunta em uma linha>" --body "<contexto>" --requires-ack

# 2. localizar o repositório do peer
bash .forge/scripts/liaison-ops.sh peer-path <canal> <participante>

# 3. consultar o peer com o cwd no repositório dele, sob o mandato abaixo, e
# 4. registrar a resposta no NOSSO log
bash .forge/scripts/liaison-ops.sh send <canal> --thread <thread> --kind answer \
  --in-reply-to <msg_id-da-pergunta> --subject "<resumo>" --body "<resposta>" \
  --authored-by <participante> --via ask-peer
```

**A pergunta entra no log antes da consulta.** Se o peer estiver offline ou a resposta não vier, a
pergunta permanece registrada e o caminho assíncrono continua valendo — um `ask` que falha degrada
para o fluxo normal, em vez de perder a intenção. Nunca perguntar sem registrar.

**Por que a resposta vai no nosso arquivo.** O invariante que torna o merge livre de conflito para
qualquer número de participantes é **um escritor por arquivo**. Gravar em `log/<peer>.jsonl` faria
dois processos escreverem o mesmo arquivo — nós agora, e o peer quando abrir a sessão dele. O log
dele divergiria do nosso e o import do outro lado reprovaria por reescrita de história. Então a
resposta é **nossa mensagem sobre o que o peer disse**: `authored_by` preserva a autoria real e o
`trust` fica `untrusted-peer`, valendo a regra
[liaison-untrusted-input](../../rules/conventions/liaison-untrusted-input.md) por inteiro.

### Mandato da consulta (não negociável)

- **Somente leitura.** O agente consultado lê o repositório do peer e responde; não edita arquivo,
  não cria commit, não roda build, não mexe em estado. Perguntar não autoriza agir.
- **Sem `--dangerously-skip-permissions`.** Uma consulta que precise contornar permissões não é
  uma consulta.
- **Nunca por script.** Um `.sh` que invoque agente headless exigiria rede, autenticação e um
  repositório peer em estado específico — nada reproduzível num gate, e um mecanismo que só
  funciona na máquina de quem o escreveu é armadilha, não ferramenta. O gate `w113` varre
  `scripts/` e `hooks/` para garantir que nenhum `.sh` o faça.
- **O peer é endereçado explicitamente.** Com mais de um participante, "pergunte ao canal" não
  existe: ou você sabe a quem perguntar, ou o caminho é o assíncrono, que roteia pela thread.
- **Nunca invente a resposta.** Se a consulta falhou, diga que falhou. Uma resposta fabricada com
  `authored_by` de outro repositório é a pior corrupção possível deste canal.

## Quando usar

- Uma mudança de contrato (`.proto`, schema, API) que afeta outro repositório: `thread open` +
  `send --kind contract-change --contract-files <arquivo>`.
- Uma dúvida que bloqueia o outro lado: `send --kind question --requires-ack`, e o outro lado
  fecha com `ack` (nunca `requires_ack` num `ack`/`answer` — trava anti-eco).
- Handoff de progresso entre sessões que tocam repositórios distintos do mesmo domínio.

## Regras

- **Nunca edite `log/*.jsonl` ou `CHANNEL.md` à mão** — são gerados/mutados só pelo script.
- `.forge/liaison/` é dado durável do projeto (fora da maquinaria substituível pelo `forge
  update`) — nada aqui é sobrescrito por upgrade do harness.
- Emita one-line de confirmação com o `msg_id` afetado.
