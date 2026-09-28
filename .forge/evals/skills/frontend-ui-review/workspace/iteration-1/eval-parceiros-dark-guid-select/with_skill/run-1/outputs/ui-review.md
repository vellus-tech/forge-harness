## Frontend UI Review — crm-web / src/features/partners (PartnersPage)

Gates determinísticos:
```
[FAIL] A1 phantom-tokens   — 1 não definido (--surface-2)
[OK]   A2 hardcoded-color  — 0 ocorrências
[OK]   A3 fallback-literal — 0
[WARN] A4 controles-nativos — <select> sem encapsulamento em PartnersPage.tsx e UsersPage.tsx
[FAIL] A5 cobertura (superfície inteira) — herda o FAIL de A1
```

Comandos executados (a partir de `work/`):
```
python3 .forge/skills/frontend-ui-review/scripts/scan-phantom-tokens.py src/styles/tokens.css src
python3 .forge/skills/frontend-ui-review/scripts/scan-phantom-tokens.py src/styles/tokens.css src '--progress'
rg -n --glob '!**/tokens*.css' --glob '!**/*.test.*' --glob '!**/*.stories.*' -e '#[0-9a-fA-F]{3,8}\b' -e 'rgb\(' -e 'hsl\(' src
rg -n 'var\(\s*--[A-Za-z0-9_-]+\s*,\s*[#0-9rgbahsl]' src
rg -n 'type="(file|color|date|time|range|checkbox|radio)"|<select\b' src
```

### Achados semânticos (severidade · arquivo:linha · recomendação)

**1. HIGH · `src/features/partners/PartnersPage.css:1` · token fantasma `--surface-2` — causa raiz do "tabela clara na tela escura"**
`.partners-table { background: var(--surface-2); ... }` referencia `--surface-2`, que **nunca foi
definido** em `src/styles/tokens.css` (o token existente é `--surface-raised`, ou `--surface` para o
fundo base). Sem fallback e sem definição, a propriedade `background` cai no valor inicial/herdado —
em light isso coincide, por acidente, com um fundo claro plausível; em dark não há nenhuma declaração
que escureça a tabela, então ela renderiza clara sobre o restante da tela escura. É exatamente o
padrão descrito no princípio central da skill: contrato quebrado mascarado até o dark mode revelar.
Correção: trocar para `var(--surface-raised)` (ou `--surface`, a depender da hierarquia visual
desejada) e considerar um teste que compare o valor computado de `background-color` da tabela nos dois
temas, para este bug não voltar silenciosamente.

**2. HIGH · `src/features/partners/PartnersPage.tsx:9` e `:16` · GUID cru na coluna BU — achado de backend, não de CSS**
`<td className="bu-cell">{p.bu_id}</td>` e a opção do filtro `<option value={p.bu_id}>{p.bu_id}</option>`
exibem o UUID bruto (`bbbbbbbb-1111-...`) porque é só isso que o contrato atual devolve — o comentário
em `src/api/partners.ts:1` confirma: *"Não existe endpoint de BU id -> nome"*. Nenhum ajuste de CSS ou
componente resolve isso: falta um endpoint (ou um mapa estático, se a lista de BUs for pequena e
estável) que traduza `bu_id → nome`. Encaminhar como tarefa de backend/API; o front só formata o que
recebe.

**3. MEDIUM · `src/features/partners/PartnersPage.tsx:14` · enum cru no `Badge` de papel**
`<Badge>{p.role}</Badge>` renderiza o valor bruto do enum (`tenant_admin`, `partner_viewer`) em vez de
um rótulo humano ("Admin do tenant", "Visualizador parceiro"). Mesma família do achado 2, mas aqui a
tradução pode ser feita **no front** (é um enum fechado e conhecido, ao contrário do catálogo de BUs) —
um mapa `role → label` local resolve sem depender do backend.

**4. MEDIUM · `src/features/partners/PartnersPage.tsx:8` (e `src/features/users/UsersPage.tsx:4`) · `<select>` nativo sem primitivo do DS — achado de plataforma**
O DS (`src/components/ds/index.ts`) só expõe `Button`, `Input`, `Card`, `Badge` — **não há `Select`**.
As duas telas que precisam de um combo (filtro de BU em Partners, filtro de papel em Users) caem para o
`<select>` nativo do browser, estilizado ad-hoc via `.bu-filter`/`.role-select`. Isso é exatamente o C1
da skill: não é "capriche aqui", é "o DS precisa de um primitivo `Select`" — já são 2 telas reimplementando
o mesmo combo de formas levemente diferentes (bordas/paddings distintos). Encaminhar ao dono do DS como
item de plataforma; enquanto não existe o primitivo, garantir ao menos consistência entre as duas
implementações ad-hoc e cobrir o chrome nativo do `<select>` nos dois temas (a seta do combo e o dropdown
usam skin do SO, que não segue `--surface`/`--text-primary`).

**5. LOW · `--progress` (custom property injetada via `style` inline) · não é bug, mas registrar**
`PartnersPage.tsx:19` injeta `--progress` via `style` inline para alimentar o gradiente da barra de
onboarding em `PartnersPage.css:4`. É o caso legítimo de token "fantasma" citado na skill (injeção em
runtime) — não precisa de definição em `tokens.css`. Mantive fora do FAIL do A1 rodando o scan com
allowlist (`'--progress'`) para isolar o problema real (`--surface-2`).

### Fase B — verificação de tema
Não há ambiente de execução no fixture (sem servidor dev/build configurado para rodar isoladamente);
a inspeção foi estática, por leitura de CSS/tokens. O achado 1 já é suficiente para explicar o sintoma
relatado ("tabela clara no meio da tela escura") sem precisar de captura visual — é uma diferença de
conjuntos entre tokens referenciados e definidos, determinística.

### Fase D — nota sobre testes
Não há testes no fixture para esta tela. Recomendação: ao corrigir o achado 1, adicionar um teste que
leia `getComputedStyle` da tabela nos dois temas (`data-theme="dark"`/ausente) e assine o valor de
`background-color`, não apenas "a classe `partners-table` está presente" — testes estruturais não
pegariam esta regressão.

Veredito: **BLOQUEADO** (A1/A5 FAIL — token fantasma `--surface-2`; achados HIGH 1 e 2 pendentes)
