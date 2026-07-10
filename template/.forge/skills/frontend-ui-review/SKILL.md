---
name: frontend-ui-review
description: |
  Revisa implementação de frontend/UI contra o design system, caçando despadronização: tokens
  fantasma (var(--x) nunca definidos), cores/bordas/espaçamentos hardcoded, controles nativos do
  browser sem estilo, reimplementação de componentes que o DS já provê, e dado cru (GUID/enum)
  vazando na tela. Roda gates determinísticos (scan de token/cor/controle nativo, custo zero, sem
  LLM) ANTES da revisão semântica. Use ao revisar PRs de UI, ao migrar telas para o design system,
  ao investigar quebra de dark mode, ou antes de declarar uma padronização "concluída". Gatilhos:
  "revisar UI", "padronização", "dark mode quebrado", "buraco de cor", "token fantasma", "design
  system", "componente ad-hoc". As convenções de escrita que ela verifica vivem em
  rules/frontend/design-system.md (§ Contrato de tokens); esta skill é o lado de auditoria.
---

# Revisão de implementação de frontend/UI

## Princípio central (leia antes de qualquer checklist)

O design system é um **contrato**. Despadronização quase nunca é preguiça — é acoplamento a um
contrato que não existe, mascarado por um fallback. O caso arquetípico:
`background: var(--surface-1, #fff)` onde `--surface-1` **nunca foi definido**. O browser usa `#fff`
sempre; em light "funciona" por acidente, em dark vira buraco branco. **O fallback é o vilão:
transforma um contrato quebrado em "funciona na minha máquina".**

Regra de ouro: **o CSS/JS deve falhar barulhentamente quando o contrato é violado, não cair
silenciosamente num literal.** A convenção correspondente (não use fallback literal; referencie o
token nu) é `rules/frontend/design-system.md`. Esta skill audita; a rule previne.

Ordem de execução: **gates determinísticos primeiro** (scripts, custo zero, sem LLM), **revisão
semântica depois** (julgamento). O barato e infalível filtra antes do caro e opinativo.

---

## Fase A — Gates determinísticos (bloqueiam o merge)

> Rode sobre a **superfície inteira**, não só o diff (ver Gate A5). Emita **uma linha OK/FAIL por
> gate**. Qualquer FAIL bloqueia. Os scans usam `rg` (ripgrep); onde faltar, `grep -rn` equivalente.

### A0 — Estabeleça a fonte da verdade
Localize o arquivo de tokens (`tokens.css`/`colors-and-type.css` ou equivalente) e o catálogo de
componentes do DS. Sem a lista de tokens **definidos** e de componentes **existentes**, você não
julga nada — o token fantasma é invisível a olho nu (ele "funciona" em light).

### A1 — Scan de token fantasma  ⭐ (o gate mais importante)
Diferença de conjuntos: tokens **referenciados** (`var(--x)`) menos tokens **definidos**. O que sobra
nunca existiu. É como saímos de "achei 4 buracos" para "37 tokens fantasma em 9 features" — caça
visual tela-a-tela só acha os que você navegou, e só no tema que quebra. O scan acha o universo em
segundos e é reproduzível em CI.

```bash
python3 .forge/skills/frontend-ui-review/scripts/scan-phantom-tokens.py <tokens.css> <src_dir> [allowlist_csv]
```

Exit 1 se houver token referenciado e nunca definido. `allowlist` (CSV) só para tokens legitimamente
injetados em runtime via `style` inline (ex.: `--progress` de uma barra). Todo o resto é bug.

### A2 — Scan de cor hardcoded
Cor literal fora da camada de tokens = sem tema, sem dark mode, sem marca (viola
`design-system.md` regras 1-2). Escopo: código de UI (`features/`, `components/`, `pages/`),
excluindo o arquivo de tokens, testes e stories.

```bash
rg -n --glob '!**/tokens*.css' --glob '!**/*.test.*' --glob '!**/*.stories.*' \
   -e '#[0-9a-fA-F]{3,8}\b' -e 'rgb\(' -e 'hsl\(' <src_dir> \
   && echo "FAIL hardcoded-color" || echo "OK hardcoded-color"
```
> Curadoria: hex dentro de `data:`/SVG inline pode ser falso-positivo; mantenha uma allowlist curta
> e justificada, nunca um "ignore geral".

### A3 — Smell de fallback literal
`var(--token, #hex)` com literal é suspeito por definição: ou o token existe (fallback morto e
enganoso) ou não (fallback mascarando o bug do A1). Regra do time: **referencie o token sem
fallback**; se faltar, que quebre em dev e force a correção na origem (definir o token), não o
remendo no ponto de uso.

```bash
rg -n 'var\(\s*--[A-Za-z0-9_-]+\s*,\s*[#0-9rgbahsl]' <src_dir> \
   && echo "WARN fallback-literal (revisar)" || echo "OK fallback-literal"
```

### A4 — Scan de controle nativo do browser
`<input type="file|color|date|range">`, `<select>` etc. têm **chrome próprio** que o CSS comum não
alcança (`::file-selector-button`, `::-webkit-color-swatch`, `::-webkit-slider-thumb`). Aplicar
`border:none` no input não toca o pseudo-elemento interno — o botão/borda default do SO permanece.
Todo controle nativo é ponto de fuga do DS até ser explicitamente domado **ou** encapsulado num
componente do DS.

```bash
rg -n 'type="(file|color|date|time|range|checkbox|radio)"|<select\b' <src_dir> \
   | grep -v 'design-system' \
   && echo "WARN controles nativos — verificar estilo/encapsulamento" || echo "OK controles-nativos"
```

### A5 — Gate de cobertura (superfície inteira, não o diff)
A1/A2 têm que dar **zero no app inteiro**, não só nos arquivos alterados. Padronização é propriedade
**global**: uma área não migrada quebra a experiência mesmo com o seu PR limpo (migrar 4/10 áreas
deixou pipeline/partners/inbox quebrados no dark). Consistência não é média, é mínimo — uma tela fora
do padrão contamina a percepção do produto todo. O gate é binário.

---

## Fase B — Verificação de tema (light E dark, nas duas direções)

Alterne o tema e percorra as telas do change; teste **light→dark e dark→light** (o toggle tem que
ganhar nos dois sentidos). Light esconde, dark revela — dark mode é um **forçador de qualidade**:
expõe todo uso de cor que não passou pelo tema. Uma UI perfeita nos dois temas é, por construção, uma
UI que respeitou os tokens. Onde der, automatize: assert sobre **valor computado de estilo**
(`getComputedStyle`) por tema, não sobre "a classe existe".

---

## Fase C — Revisão semântica (julgamento)

### C1 — Primitivo faltante ≠ improviso
Se a tela reimplementa algo que deveria ser do DS (ou improvisa por falta dele — ex.: não há
`Select`, então cada tela faz o seu), o achado **não** é "faça um bonito aqui", é "**o DS precisa
deste primitivo**, e N telas já pediram". Padronização é decisão de **plataforma**, não de tela.
Separe "corrige aqui" de "peça faltante do sistema" e encaminhe a segunda ao dono do DS.

### C2 — Dado cru vazando (dependência de contrato do backend)
GUID (`bbbbbbbb-...`), enum (`tenant_admin`), código na tela geralmente é **dado cru vazando**, não
falha de CSS. Muita "feiura" de UI é o backend não expor um rótulo humano (ex.: BU sem endpoint
id→nome). Pergunte: "esse identificador deveria virar um nome, e existe fonte?". Se não existe, o
achado é de **backend** e vira tarefa lá — nenhum capricho de front conserta.

### C3 — Borda, espaçamento, raio e sombra também são tokens
Consistência não é só paleta (ver `design-system.md` regras 3-8). Linha de 1px consistente, escala de
espaçamento, raio de canto e sombra vêm de tokens. A sensação de "padronizado" nasce tanto de um
`border` uniforme quanto de uma cor uniforme.

### C4 — Estados e acessibilidade
Cheque hover/focus-visible/disabled, vazio/carregando/erro, navegação por teclado e contraste WCAG AA
nos dois temas. Padronização inclui comportamento, não só aparência em repouso.

---

## Fase D — Auditoria da qualidade dos testes

Pergunte de cada teste: **o que ele realmente prova?** O change que originou esta skill tinha **2174
testes verdes** e mesmo assim buracos de dark mode e ordenação quebrada passaram — porque os testes
asseguravam **estrutura** ("renderiza", "classe existe"), não **comportamento real** ("a superfície
resolve a cor certa no tema dark", "clicar no header reordena via a API real"). Exija testes que
exercitem tema renderizado e caminho real de dados. No mínimo, os gates A1/A2 devem virar **CI gate**
— eles *são* o teste que faltava.

---

## Formato de saída

```
## Frontend UI Review — <alvo>

Gates determinísticos:
  [OK|FAIL] A1 phantom-tokens   — <n> não definidos
  [OK|FAIL] A2 hardcoded-color  — <n> ocorrências
  [OK|WARN] A3 fallback-literal — <n>
  [OK|WARN] A4 controles-nativos
  [OK|FAIL] A5 cobertura (superfície inteira)

Achados semânticos (severidade · arquivo:linha · recomendação):
  - ...

Veredito: APROVADO | BLOQUEADO (gates FAIL ou achados HIGH)
```

## Anexo — cada gate ↔ o incidente real que ele previne

- **A1** ← 37 tokens fantasma (`--surface-1`, `--color-surface-unread`, …) → buracos brancos no dark.
- **A3** ← `var(--surface-1, #fff)` "funcionava" em light e escondeu o contrato quebrado.
- **A4** ← botão "Escolher arquivo" cinza do SO e swatch de cor com borda grossa nativa.
- **A5** ← migração parcial (4/10 áreas) deixou pipeline/partners/inbox quebrados.
- **C1** ← ausência de `Select` no DS → campo de BU impossível de padronizar.
- **C2** ← BU exibida como GUID `bbbbbbbb` por falta de endpoint id→nome.
- **C3** ← borda de 1px destoante nos swatches de cor.
- **D**  ← 2174 testes verdes que não pegaram nada disso.
