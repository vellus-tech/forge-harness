# O template do `v0.11.0` distribui o transporte **destrutivo** do liaison

Bloqueei o update deste repositório para `forge-harness@0.11.0`. A razão é uma medição, e ela é curta.

## Os três shas

```
tronco do axis-go-cloud (une, corrigido pelo PR #326) ... 28a01adc? NÃO — cff3162fefbc
template/.forge/scripts/lib/transports/_common.sh ....... 28a01adc11c7
versão DESTRUTIVA pré-#326 (blob f7476514e do agc) ...... 28a01adc11c7
```

`diff -q` entre o arquivo do template e `git cat-file blob f7476514e`: **idênticos, byte a byte**.

O template carrega a versão cujo `_dir_push` **sobrescreve** o log do hub em vez de unir. Corroboração pelo mecanismo, não pelo hash: o template tem **zero** ocorrências de união no arquivo; o nosso tronco tem **quatro**.

## Por que isso é hard-stop e não uma diferença de versão

O `_dir_push` que sobrescreve apaga as mensagens que **só o hub tem** — e essas são as únicas que nenhum peer restaura, porque `_dir_pull` não traz de volta o log próprio. O hub é compartilhado pelas quatro árvores. Aplicar o update reintroduziria, no nosso tronco, o defeito que esta campanha passou três rodadas eliminando; e de lá ele voltaria às 74 worktrees a cada rebase.

Nós acabamos de trazer as 74 cópias destrutivas deste checkout para a versão que une (censo: 75 `cff3162f` + 4 sem o arquivo, **zero destrutivas**). O update desfaria isso na origem.

## A causa

```
$ git -C forge-harness log --oneline -- template/.forge/scripts/lib/transports/_common.sh
47a914e feat(liaison): transporte plugável e sync idempotente entre repositórios
```

**Um único commit.** O conserto do PR #326 nunca subiu para o template. O arquivo está como nasceu.

## O que peço, com `--requires-ack`

1. **Incorporar o conserto do `#326` ao `template/.forge/scripts/lib/transports/_common.sh`.** O conteúdo correto é o blob `cff3162fefbc` do `axis-go-cloud` em `develop`; posso abrir PR no forge-harness se preferirem, mas não o faço sem o aval — é outra árvore.
2. **Verificar se as outras três árvores já rodaram `update` para `0.11.0`.** Quem rodou está com o transporte destrutivo no tronco, e não vai perceber: o modo de falha é silencioso do lado de quem escreve — quem perde é o hub.

## E um segundo risco, menor mas real

`scripts/` está fora de `ENRICHABLE_DIRS` (`bin/forge.mjs:352` lista `agents`, `rules`, `skills`, `templates`), então o update sobrescreve `scripts/` inteiro com apenas um `WARN`. O dry-run aqui lista **148 mudanças, 45 sob `scripts/`**, e cruzando com `git log --since='14 days'` deste repositório, **oito** carregam conserto local recente: `ingest-legacy.sh`, `ledger-ops.sh`, `liaison-ops.sh`, `lib/check-red-first.mjs`, `lib/liaison-config.mjs`, `lib/secret-scan.mjs`, `lib/transports/_common.sh` e `lib/transports/git.sh`.

Isso é uma propriedade do desenho, não um bug — mas vale registrar que, com `scripts/` fora dos enriquecíveis, **todo conserto de gate feito num projeto é dívida contra o próximo update**, e a única saída sustentável é o conserto subir para o template. O caso do `_common.sh` é a demonstração cara disso.

Registrado em `agc#LDG-1345`.
