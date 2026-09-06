# O gate red-first exige um campo que nenhum comando escreve, e mesclar o tronco numa branch pode travar o push dela

Dois defeitos independentes no `check-red-first.mjs`, os dois medidos ao tentar enviar a branch de um PR depois de mesclar `develop` nela.

## 1. `ledgerEntryOf` exige `source.change_id`, e nenhum subcomando o preenche em entrada existente

```js
return data.entries.find((e) => e.id === ledgerId && e.source && e.source.change_id === changeId) || null;
```

A entrada `LDG-0435` **existe** nos dois ledgers, com `status: open` e `type: known-bug`, e o waiver `no-test-infra` do change a declara corretamente pelo id. Mas `source.change_id` é `null`, e não há caminho por script para preenchê-lo depois da criação:

- `ledger-ops.sh update LDG-0435 --change <id>` → `FAIL: flag desconhecida '--change'`
- `ledger-ops.sh promote` → escreve em `links.change`, **não** em `source`, e ainda muda o `status` para `promoted`, que seria semanticamente errado
- só `add --change` preenche `source.change_id`, e criar entrada nova exigiria **reemitir o waiver**, que vive em `evidence/red/red-evidence.json` — artefato de execução imutável

**Não editei o `ledger.json` à mão para passar.** Um gate contornado por edição manual do artefato que ele inspeciona deixa de ser gate. Fica bloqueado e registrado.

Conserto proposto: `update` aceitar `--change` escrevendo `source.change_id`, **ou** `ledgerEntryOf` aceitar também `links.change`, que é o campo que a maquinaria de fato sabe escrever.

## 2. O bloqueio NÃO era da branch — foi o merge do tronco que o acionou, por um change de terceiro

Este é o mais incômodo, e vale para as quatro árvores. O gate dispara por existir commit `fix(...)` no HEAD e então cobra red-first dos changes ativos. O merge de `develop` trouxe **quatro** commits `fix(...)` — todos do mutex, nenhum com qualquer relação com o change cobrado — e foi isso que fez o push da branch passar a reprovar.

```
eea2db0 fix(hooks): o pre-push usa OUTRA implementação do mutex...
95d4835 fix(harness): o ramo de recuperação terminava em `continue`...
320ca17 fix(harness): o ramo de recuperação por idade não avançava o relógio...
3b2f13a fix(harness): a posse do mutex era marcada 54-187ms depois...
```

**Consequência prática: manter uma branch atualizada com o tronco pode travar o push dela por um waiver de um change alheio.** O gate já reporta `1 sem interseção com os fix_files declarados`, então a noção de interseção existe — ela só não está sendo usada para decidir se o change deve ser cobrado.
