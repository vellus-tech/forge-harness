# Medição do corpus e da plataforma — add-unified-knowledge-search

Medido em 2026-10-30 na worktree `feat/harness/unified-knowledge-search` (base `34f9d2c1`), Node 26.0.0, Apple M5 (10 núcleos), macOS. Comandos reproduzíveis no fim do arquivo.

## Tamanho do corpus elegível nesta instância

| Fonte | Arquivos | Bytes |
|---|---|---|
| `.forge/product/current/` (baseline, ADRs, capabilities) | 7 | 302.777 |
| `.forge/specs/archived/` | 160 | 548.390 |
| `docs/plans/` | 48 | 4.039.132 |
| `.forge/ledger/` (`ledger.json` + `LEDGER.md` renderizado) | 2 | 352.367 |
| `.forge/liaison/forge-harness/log/` (5 JSONL, 463 mensagens) | 5 | 346.304 |
| `CHANGELOG.md` | 1 | 465.061 |
| Excluído: `.forge/liaison/forge-harness/blobs/` | 190 | 739.185 |
| Fora do default: `.forge/specs/active/` | 15 | 303.350 |

Do liaison, só 12 das 463 mensagens são `trust: self`; as outras 451 são `untrusted-peer` (dado escrito por outro repositório) e ficam fora do índice. O ledger entra por `ledger.json` (133 entradas estruturadas), não pelo `LEDGER.md`, que é renderização do mesmo dado.

Carregado pelo protótipo de medição: 335 documentos, 5.386.035 caracteres, 5.167 trechos (corte por heading markdown, teto de 1.500 caracteres por trecho).

## Versão mínima de Node e consequência para o índice

`package.json` declara `"engines": { "node": ">=20" }` e todos os scripts checam `node >= 20`. `node:sqlite` só existe a partir do Node 22.5 (atrás de flag até a 22.13, e ainda marcado experimental), então não pode ser a base do default sem elevar o piso do harness. Não é necessário: o protótipo em Node puro, sem índice externo, mediu:

| Operação | Tempo |
|---|---|
| Ler e cortar os 335 documentos | ~0,1 s (cache quente) |
| Construir BM25 + entidades + grafo de links | ~0,7 s |
| Consulta lexical (BM25 + entidades + links, varredura linear dos 5.167 trechos) | 0,2–0,4 ms por consulta |

Conclusão: índice invertido serializado em JSON, construído em Node puro, é rápido o bastante por duas ordens de grandeza. SQLite/FTS5 não compra nada aqui e custaria o piso de versão ou uma dependência nativa.

## Reprodução

```bash
for d in .forge/product/current .forge/specs/archived docs/plans .forge/ledger .forge/liaison/forge-harness/log .forge/liaison/forge-harness/blobs .forge/specs/active; do printf "| %s | %s | %s |\n" "$d" "$(find $d -type f | wc -l | tr -d ' ')" "$(find $d -type f -exec cat {} + | wc -c | tr -d ' ')"; done
node -e 'const fs=require("fs");const d=".forge/liaison/forge-harness/log/";const t={};for(const f of fs.readdirSync(d))for(const l of fs.readFileSync(d+f,"utf8").split("\n").filter(Boolean)){const o=JSON.parse(l);t[o.trust]=(t[o.trust]||0)+1}console.log(t)'
```

O protótipo de medição (`evidence/prototype/measure.mjs`) e o conjunto de consultas (`evidence/prototype/queries.json`) estão versionados junto desta evidência.
