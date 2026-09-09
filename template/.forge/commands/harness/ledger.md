---
description: Ledger durável de projeto (roadmap & dívida técnica). Registra e consulta trabalho conhecido que sobrevive entre changes — roadmap, dívida técnica, bugs conhecidos, follow-ups, ideias de feature. Alimentado por captura automática (harvest no close/archive) + curadoria manual. NÃO-BLOQUEANTE. Operado por script determinista.
argument-hint: "[list|add|update|note|resolve|promote|render|status] [flags]"
---

# /forge:ledger — ledger durável de projeto

Argumentos: `$ARGUMENTS`. Sem subcomando, mostra o ledger (equivale a `list`) e o caminho do
arquivo mestre `.forge/ledger/LEDGER.md`.

> **Por que existe:** o `deferrals.json` é escopado a um change, bloqueante e efêmero (morre no
> archive). O ledger é o oposto: **durável** (sobrevive entre changes, vive em `.forge/ledger/`,
> preservado pelo `forge update`), **não-bloqueante** (registrar aqui nunca trava um change) e
> **de projeto** (nada se perde entre uma spec e outra). Fonte consultada por `/forge:resume` e ao
> sugerir o próximo trabalho — ver `rules/conventions/ledger-consultation.md`.

## Protocolo

Tudo é operado pelo script determinista (IDs `LDG-NNNN`, escrita atômica, re-render do `LEDGER.md`
a cada mutação, `created_at` = data do commit HEAD, sem wall clock):

```bash
# consultar
bash .forge/scripts/ledger-ops.sh list [--status open] [--type <t>] [--top N] [--by-priority]
bash .forge/scripts/ledger-ops.sh status                      # one-line (usado por /forge:status)

# registrar / semear (type: roadmap | tech-debt | known-bug | follow-up | feature-idea)
bash .forge/scripts/ledger-ops.sh add --type <t> --title "<txt>" \
  [--detail "<txt>"] [--severity BLOCKER|HIGH|MEDIUM|LOW] [--priority P0|P1|P2|P3] \
  [--change <change-id>] [--ref <ref>] [--adr <ADR>] [--capability <cap>]

# ciclo de vida de uma entrada
bash .forge/scripts/ledger-ops.sh update  <LDG-NNNN> [--status <s>] [--priority P1] [--severity HIGH] [--title "<txt>"] [--detail "<txt>"] [--replace-detail]
bash .forge/scripts/ledger-ops.sh resolve <LDG-NNNN> --note "<como foi resolvido>"
bash .forge/scripts/ledger-ops.sh promote <LDG-NNNN> --to <change-id>   # virou um change (status: promoted)

# registrar PROGRESSO, medição nova, correção ou decisão SEM apagar o que já está lá
bash .forge/scripts/ledger-ops.sh note <LDG-NNNN> --kind progress|measurement|correction|decision --text "<txt>"

# regenerar a view mestre
bash .forge/scripts/ledger-ops.sh render                      # .forge/ledger/LEDGER.md
```

## O `detail` acumula: `note` acrescenta, `update --detail` não destrói em silêncio

O `detail` de uma entrada é **registro que acumula**, não campo que se substitui. A regra nasceu de
medição na história deste próprio ledger: das 92 mutações de `detail`, 24 não preservaram o texto
anterior, e seis destruíram mais de 25% do campo — 3.497 bytes num único item, 86 de 86 frases
longas ausentes, todas com `rc 0` e `OK` na saída.

- **Progresso se registra com `note`, e quem fecha é o arquivamento.** `note` acrescenta um bloco
  datado ao fim do `detail`, com um marcador gerado pelo script (`PROGRESSO (<data>): `,
  `MEDIÇÃO (<data>): `, `CORREÇÃO DE REGISTRO (<data>): `, `DECISÃO (<data>): `), e **não toca o
  `status` nem o `resolved_at`**. Registrar pagamento parcial mudando o status para `in-progress`
  tiraria o item da contagem de `open` sem que a dívida tivesse sido paga — é fechar por
  reclassificação silenciosa. Anotar item já encerrado é legítimo (avisa e não muda status);
  refechá-lo não é.
- **`--kind` é enum fechado de quatro valores.** Rótulo livre não é contrato e não é legível por
  gate. Um valor fora do enum reprova nomeando os quatro.
- **`update --detail` recusa a substituição destrutiva.** Se o `detail` corrente é não-vazio e o
  texto novo não o preserva (o corrente precisa ser subcadeia do novo), o comando reprova sem
  gravar nada e aponta os dois caminhos legítimos: `note` para acrescentar, `--replace-detail` para
  substituir de propósito. Com `--replace-detail`, a substituição acontece e o script **anuncia em
  stderr quantos bytes foram descartados** — continua possível, deixou de ser silenciosa. Detail
  vazio e texto que preserva continuam gravando como sempre.

**Disciplina de escrita (issue #103).** As três recusas abaixo são do script, não do agente:

- **Flag desconhecida reprova.** Todos os sete subcomandos (`add`, `update`, `note`, `resolve`,
  `promote`, `harvest`, `list`) recusam argumento que não conhecem, nomeando o subcomando. Antes, o `case`
  terminava em `*) shift ;;`, que engolia a flag **e** o valor dela: um `--details "texto"` (typo
  em `--detail`) desaparecia inteiro, a entrada nascia com `detail` vazio e a saída dizia `OK`.
- **Valor vazio reprova.** `--detail ""`, `--title ""` e afins são erro de uso, não apagamento de
  campo. Antes, `update --detail ""` imprimia `OK`, gravava o arquivo e avançava `updated_at` sem
  alterar o campo — o commit anunciava um conteúdo que o ledger não carregava.
- **`update` que não muda nada reprova.** Se nenhum campo de conteúdo (`title`, `detail`,
  `status`, `priority`, `severity`) mudou, não há `OK`: o único efeito seria fazer a entrada
  parecer recente sem carregar informação nova.

E `add` sem `--detail` **avisa** (não reprova): título sem conteúdo é a forma de item que envelhece
pior. Complete com `update <id> --detail "…"`.

## Captura automática (o ledger se alimenta sozinho)

Você **não** precisa lembrar de registrar findings — o harness colhe por construção:

- `/forge:close` e `/forge:archive` rodam `ledger-ops.sh harvest <id>` **antes de mover a pasta do
  change** (onde o dado morreria): deferrals `open` → `follow-up`, `wont-fix` → `tech-debt`,
  findings `MEDIUM`/`LOW` do `analysis.md` → `tech-debt`, e do `verification.md` os follow-ups
  **explicitamente marcados** → `follow-up`. Idempotente (dedup por `${change_id}:${ref}`).
  A marcação é obrigatória (LDG-0140): bullet prefixado por `PENDENTE:` sob qualquer heading de
  ressalva, ou qualquer bullet sob um heading dedicado `Follow-ups abertos`. Casar a seção inteira
  capturava narrativa de algo já concluído — nasceram quatro entradas 100% duplicadas de itens já
  resolvidos, para o operador do `close` desfazer à mão. Bullet que cita um `LDG-00NN` entre
  crases é descartado: já tem registro próprio.
- Como decidir manualmente vs. deixar automático: use `add` para **semear** roadmap/features/
  arquitetura planejados (ex.: os módulos de um redesign) e para capturar uma descoberta na hora;
  deixe o harvest cuidar do que sai de `analyze`/`verify`/`defer`.

## Quando usar

- **Semear** o roadmap no início de um projeto/redesign (entradas `roadmap`/`feature-idea`).
- **Registrar** na hora uma dívida técnica, bug conhecido ou ideia que surgiu fora do escopo do
  change atual — em vez de abrir um deferral (que bloquearia) ou perder.
- **Consultar** antes de decidir o próximo trabalho ou promover uma entrada a um change
  (`promote` + `/forge:spec new`).

## Regras

- **Não-bloqueante:** o ledger nunca trava um change. Falha bloqueante = deferral/analyze, não ledger.
- **Não edite `LEDGER.md` à mão** (exceto a seção "Notas"): é gerado do `ledger.json`. Edições vão
  via `/forge:ledger`.
- Emita one-line de confirmação com o ID afetado (`LDG-NNNN ...`).
