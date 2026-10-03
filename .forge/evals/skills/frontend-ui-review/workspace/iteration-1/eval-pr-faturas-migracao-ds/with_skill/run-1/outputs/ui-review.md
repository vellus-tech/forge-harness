## Frontend UI Review — feat/faturas-ds (migração de src/features/invoices para o DS)

Gates determinísticos (superfície inteira do app, não só o diff — ver A5):

```
[FAIL] A1 phantom-tokens   — 2 não definidos
[FAIL] A2 hardcoded-color  — 2 ocorrências
[WARN] A3 fallback-literal — 1
[WARN] A4 controles-nativos — 2 usos de <input type="file">
[FAIL] A5 cobertura (superfície inteira) — falha porque A1/A2 falharam
```

### Detalhe dos gates

**A1 — token fantasma** (`scripts/scan-phantom-tokens.py`)
- `--surface-1` referenciado em `src/features/invoices/InvoiceList.css:3` — nunca definido em `src/styles/tokens.css`. **Introduzido por este PR.**
- `--color-surface-unread` referenciado em `src/features/partners/PartnersTable.css:2` — nunca definido. Pré-existente, fora do diff do PR (`partners` não foi tocado pelo commit `feat(invoices): migra a tela de faturas para o design system`).

**A2 — cor hardcoded**
- `src/features/invoices/InvoiceList.css:3` — `var(--surface-1, #fff)`. **Introduzido por este PR.**
- `src/features/partners/PartnersTable.css:3` — `border-bottom: 1px solid #dddddd`. Pré-existente, fora do diff.

**A3 — fallback literal**
- `src/features/invoices/InvoiceList.css:3` — `var(--surface-1, #fff)` é exatamente o padrão do incidente arquétipo da skill: em light "funciona" por acidente (mostra branco), em dark vira buraco branco sobre fundo escuro, porque `--surface-1` nunca existiu — o token certo já existe e se chama `--surface` (ou `--surface-raised`), definido em ambos os temas.

**A4 — controle nativo do browser**
- `src/components/ds/FileUpload.tsx:7` — `<input type="file">` encapsulado dentro do componente do DS, com `::file-selector-button` estilizado via `FileUpload.css`. **OK, é o padrão correto** (falso positivo do grep, que só ignora path contendo a string "design-system").
- `src/features/invoices/InvoiceList.tsx:11` — `<input type="file" className="invoice-upload">` **nativo, fora do DS**, mesmo o DS já expondo `FileUpload` em `src/components/ds`. `InvoiceList.css` aplica `border: none` nesse input, mas isso não alcança o chrome interno (`::file-selector-button`) — o botão "Escolher arquivo" do SO permanece, exatamente o incidente do Anexo (A4).

### Achados semânticos (severidade · arquivo:linha · recomendação)

- **HIGH · `src/features/invoices/InvoiceList.css:3`** — Token fantasma + fallback literal (`var(--surface-1, #fff)`). Buraco branco garantido em dark mode. Recomendação: trocar para `var(--surface)` (ou `--surface-raised`, dependendo da elevação desejada), sem fallback — se o token errado for usado de novo, quebrar em dev é o comportamento certo, não mascarar com literal.

- **HIGH · `src/features/invoices/InvoiceList.tsx:11`** — PR reimplementa upload de arquivo com `<input type="file">` cru, apesar do DS já prover `FileUpload` (`src/components/ds/FileUpload.tsx`), que já resolve exatamente esse problema (estiliza `::file-selector-button` com tokens). Isto é o oposto de C1 ("primitivo faltante"): aqui o primitivo **existe** e a tela não o usa. Recomendação: substituir por `<FileUpload label="..." onChange={onUpload} />` e remover a regra morta `.invoice-upload { border: none; }` de `InvoiceList.css` (não resolve nada — o chrome nativo não é tocado por `border`).

- **MEDIUM · `src/features/partners/PartnersTable.css:2-3`** — Fora do diff deste PR, mas aparece no scan de superfície inteira (A5) e por isso bloqueia o veredito de "app padronizado": `--color-surface-unread` é fantasma e a borda da tabela é hardcoded (`#dddddd`, sem tema). Recomendação: **não é bloqueio deste PR de faturas** por si só — mas não pode ser tratado como "resolvido depois" silenciosamente; abrir item de dívida técnica rastreado antes de declarar a padronização do produto concluída, já que é exatamente o padrão do incidente real que motivou a skill (migração parcial 4/10 deixando áreas quebradas no dark).

- **LOW · `src/components/ds/Button.css`** — Só define o estado base (`background`, `color`, `border-radius`, `padding`); não há regra explícita para `:hover`, `:focus-visible` ou `:disabled`. Não é um FAIL de gate, mas cai em C4 (estados/acessibilidade) — vale conferir se o navegador cobre foco visível o suficiente para WCAG AA nos dois temas antes de generalizar este `Button` para mais telas.

### Fase D — qualidade dos testes

Não há testes (`*.test.*`) para `InvoiceList`, `FileUpload` ou `PartnersTable` neste fixture — nenhum teste de estrutura nem de tema. Como a skill lembra (2174 testes verdes não pegaram os buracos de dark mode reais), a ausência de teste aqui não é motivo de alívio: os gates A1/A2 são o teste que falta, e já pegaram o problema. Recomendação: promover `scan-phantom-tokens.py` (A1) e o scan de cor hardcoded (A2) a gate de CI antes do próximo PR de UI.

## Veredito: BLOQUEADO

Motivo formal (gates): A1 e A2 falham na superfície inteira, portanto A5 falha — o gate é binário, não é média.

Recompondo por origem, para a decisão de merge:

- **Bloqueia este PR por si só**, independente de partners: o próprio diff (`InvoiceList.css`) introduz um token fantasma com fallback literal (`var(--surface-1, #fff)`) e reimplementa upload de arquivo fora do DS quando o componente correto (`FileUpload`) já existe. Isso não é nitpick de estilo — é o mesmo padrão que já causou buraco de dark mode e chrome nativo vazando em produção segundo o histórico que motivou esta skill.
- **Não é culpa deste PR, mas contamina o veredito de "app padronizado"**: `PartnersTable` já tinha token fantasma e borda hardcoded antes deste commit. Se o critério for "este PR pode mergear sem piorar o estado atual do app", ele não piora `partners` — mas também não posso assinar "produto padronizado" com esse buraco pré-existente ainda aberto.

Recomendação prática: corrija os dois pontos do diff de `invoices` (token fantasma/fallback e input de arquivo fora do DS) antes do merge — são baratos e no arquivo que você já está mexendo. O item de `partners` pode virar um item de dívida técnica rastreado separadamente, mas não deveria ficar invisível: registre-o explicitamente, não deixe para a próxima pessoa redescobrir via scan.
