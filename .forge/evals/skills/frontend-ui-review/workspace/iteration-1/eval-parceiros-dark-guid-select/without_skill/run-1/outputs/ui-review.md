# Revisão de UI — Tela de Parceiros (src/features/partners)

## Resumo

A tabela de parceiros herda uma cor de fundo que não existe no token system — o token `--surface-2` referenciado em `PartnersPage.css` nunca foi definido em `src/styles/tokens.css` (que só define `--surface` e `--surface-raised`). Uma variável CSS inválida no `var()` faz `background-color` cair no valor inicial (`transparent`), então a tabela fica transparente sobre o fundo claro padrão do documento — por isso ela aparece "clara no meio da tela escura" quando o tema dark está ativo em outro nível (body/root). A coluna BU mostra o `bu_id` cru porque o contrato atual do backend (`GET /partners`) só devolve o UUID, sem nome — não existe endpoint de tradução id→nome (confirmado no comentário de `src/api/partners.ts`). O filtro por BU é um `<select>` nativo estilizado com variáveis de tema, mas a lista suspensa (popup) de um `<select>` nativo é renderizada pelo SO/engine do navegador e ignora a maior parte do CSS da página — então o fechado pode parecer certo no dark mode e a lista aberta continuar clara, sem que `color-scheme` tenha sido setado em lugar nenhum.

## Achados

### 1. Fundo da tabela quebrado no dark mode (bug de token) — Crítico
`src/features/partners/PartnersPage.css:1` usa `background: var(--surface-2)`. Esse token não existe em `src/styles/tokens.css` (nem no bloco `:root`, nem em `[data-theme="dark"]`). Uma custom property indefinida referenciada em `var()`, sem fallback, torna a declaração inválida no valor computado — para `background-color` isso equivale a `transparent`. Resultado: a tabela não herda `--surface`/`--surface-raised` de propósito nenhum tema, fica transparente, e mostra o fundo do documento (claro) por trás — exatamente o sintoma relatado ("tabela clara no meio da tela escura").
**Correção:** trocar `var(--surface-2)` por um token existente — `var(--surface-raised)` é o mais coerente com o padrão já usado em `UsersPage.css` (`.role-select` usa `--surface-raised`) para superfícies elevadas dentro de um Card.

### 2. Coluna BU mostra GUID em vez do nome da unidade — Crítico, depende do backend
`src/features/partners/PartnersPage.tsx` renderiza `{p.bu_id}` diretamente em `.bu-cell`, e `src/api/partners.ts` documenta que o backend só devolve `bu_id` (UUID) — "Não existe endpoint de BU id -> nome". Isso não é um bug de CSS/estilo: o front não tem de onde tirar o nome. Duas saídas possíveis, nenhuma resolvível só no front:
- Pedir ao time de backend um campo `bu_name` no payload de `/partners` (mudança de contrato, mais simples e correta).
- Se já existir um endpoint de listagem de BUs em outro lugar do sistema, buscar essa lista uma vez e montar um mapa `bu_id → nome` no front para popular a coluna e as opções do filtro.
Enquanto o nome não existir, pelo menos truncar o UUID visualmente (ex.: primeiros 8 caracteres) e usar `title={p.bu_id}` para o valor completo no tooltip, para não expor uma string de 36 caracteres ilegível na tabela.

### 3. `<select>` nativo não garante lista suspensa no tema correto — Alto
O filtro (`select.bu-filter`) e o de `UsersPage` (`select.role-select`) estilizam o controle fechado com as variáveis de tema, mas nenhum lugar do projeto define `color-scheme` (nem em `:root` de `tokens.css`, nem inline nos componentes). Sem isso, o navegador pode renderizar o *popup* nativo de opções (que não é estilizável via CSS comum) no esquema de cores padrão do SO — tipicamente claro — mesmo com o controle fechado corretamente escuro. Isso é coerente com o padrão de sintomas do ticket (algo "estranho" no dark mode que não é só a tabela).
**Correção:** adicionar `color-scheme: light dark;` no `:root` de `tokens.css` (ou `color-scheme: dark` dentro do bloco `[data-theme="dark"]`), para que o navegador desenhe controles nativos (select, scrollbar, etc.) coerentes com o tema ativo.

### 4. Filtro de BU não existe como componente do design system — Médio
`src/components/ds/index.ts` documenta que o catálogo do DS tem `Button`, `Input`, `Card`, `Badge` — não há `Select`. `PartnersPage.tsx` usa um `<select>` HTML puro com classe própria (`.bu-filter`), enquanto o restante da tela usa componentes do DS (`Card`, `Badge`). Não é exatamente um bug, mas é uma inconsistência de sistema: o valor exibido no filtro também é o `bu_id` cru (mesma raiz do achado 2), então o filtro sofre do mesmo problema de legibilidade.
**Correção recomendada:** registrar a falta de um componente `Select` no design system como item de backlog; enquanto isso, usar a mesma fonte de nomes do achado 2 para popular o texto de cada `<option>`.

### 5. `border-radius` do filtro não usa token — Baixo
`.bu-filter` em `PartnersPage.css:5` usa `border-radius: 4px` fixo, enquanto o token `--radius-md: 8px` existe em `tokens.css` e é o padrão esperado para controles desse tipo (o `.role-select` de Users também não usa o token, mas usa `6px` — os três valores divergem entre si: 4px, 6px, 8px). Padronizar em `var(--radius-md)` nos dois selects evitaria essa deriva visual entre telas.

## Resumo do que corrigir no front

1. `src/features/partners/PartnersPage.css` — trocar `var(--surface-2)` por `var(--surface-raised)` na regra `.partners-table`.
2. `src/styles/tokens.css` — adicionar `color-scheme: light dark;` ao `:root` (ou `dark` ao bloco `[data-theme="dark"]`) para os controles nativos (select, scrollbar) seguirem o tema.
3. `src/features/partners/PartnersPage.tsx` — parar de renderizar `bu_id` cru na coluna e nas opções do filtro; usar um mapa `bu_id → nome` (via novo campo do backend ou endpoint de BUs já existente) — ação que depende de alinhamento com o backend, não é só front.
4. `src/features/partners/PartnersPage.css` e `src/features/users/UsersPage.css` — trocar `border-radius: 4px` / `6px` fixos por `var(--radius-md)` nos selects, para consistência entre telas.
5. Backlog de design system: avaliar um componente `Select` oficial em `src/components/ds`, já que hoje `PartnersPage` e `UsersPage` reimplementam `<select>` estilizado de formas ligeiramente diferentes.
