# Revisão de UI — migração de faturas para o design system (feat/faturas-ds → main)

## Veredito

Não recomendo merge no estado atual. Há um bug funcional de dark mode e uma regressão de acessibilidade que contradizem o objetivo declarado do PR (migrar para o design system), além de um componente do DS criado especificamente para este caso de uso que não foi adotado.

## Escopo revisado

O diff toca apenas `src/features/invoices/InvoiceList.tsx` e `src/features/invoices/InvoiceList.css` (29 linhas, 2 arquivos). Também li `src/styles/tokens.css` e todo `src/components/ds` (`Button`, `FileUpload`, incluindo os respectivos `.css`) para checar consistência com o design system, e `src/features/partners/PartnersTable.tsx`/`.css` como referência de uso de tokens em outro ponto do código já existente.

## Achados bloqueantes

**Token inexistente quebra o dark mode.** `InvoiceList.css` define `.invoice-card { background: var(--surface-1, #fff); ... }`, mas `tokens.css` não declara `--surface-1` em nenhum dos dois blocos (`:root` nem `[data-theme="dark"]`) — o token real chama-se `--surface`. Como a variável nunca resolve, o fallback `#fff` é sempre aplicado, inclusive em `[data-theme="dark"]`, onde `--text-primary` já vira `#f1f5f9` (quase branco). O resultado é texto claro sobre fundo branco fixo, com contraste próximo de zero no card de fatura em tema escuro. Correção: usar `--surface` (ou `--surface-raised`, se a intenção for destacar o card do fundo da página) e remover o fallback literal — um fallback hardcoded aqui mascara silenciosamente qualquer token futuro que também venha a faltar, em vez de quebrar de forma visível/testável.

**Upload de arquivo não usa o componente do DS e perde acessibilidade.** O PR importa `Button` do design system mas mantém um `<input type="file" className="invoice-upload" onChange={...} />` nativo, solto dentro do `<header>`, sem `<label>` associado nem `aria-label`. O próprio `src/components/ds/FileUpload.tsx` foi construído para exatamente este caso — envolve o input em `<label>` com texto visível e o `FileUpload.css` já estiliza `::file-selector-button` com os tokens do DS (`--surface-raised`, `--text-primary`, `--border-subtle`, `--radius-md`). Usar o input nativo aqui: (a) contradiz o objetivo do PR de migrar a tela para o DS, já que o upload continua fora dele; (b) remove o rótulo textual que o `FileUpload` fornece, então leitores de tela não anunciam a finalidade do campo; (c) a regra `.invoice-upload { border: none; }` só afeta a borda do próprio `<input>`, não o `::file-selector-button` (que é o que o navegador de fato renderiza como botão clicável) — ou seja, nem sequer resolve o problema visual que parece tentar resolver, e diverge do restante do arquivo, que usa tokens. Recomendo trocar por `<FileUpload label="Anexar fatura" onChange={onUpload} />` e remover `.invoice-upload` do CSS.

## Achados não bloqueantes

**Status da fatura não é renderizado.** O tipo `Invoice` declara `status: 'paid' | 'open'`, mas o card só mostra `inv.number` e `inv.amount`. Se a distinção visual entre fatura paga e em aberto for esperada pelo usuário final, falta essa indicação (cor, badge etc.); se for proposital para uma etapa futura, vale registrar no PR.

**Formatação de valor monetário.** `inv.amount.toFixed(2)` produz uma string numérica sem símbolo de moeda nem separador de milhar (ex.: `1234.5` vira `"1234.50"`). Não é regressão desta migração, mas já que a tela está sendo tocada, é um bom momento para usar `Intl.NumberFormat` com a moeda correta.

**Sem teste para o componente migrado.** O projeto tem `vitest` e `@testing-library/react` configurados (`package.json`), mas não há teste novo ou atualizado cobrindo `InvoiceList` com as novas props `invoices`/`onUpload` nem o fluxo de upload.

**Débito pré-existente fora do escopo do PR, citado apenas para contexto.** `PartnersTable.css` referencia `var(--color-surface-unread)`, que também não existe em `tokens.css` (mesma classe de problema do primeiro achado bloqueante acima, mas em arquivo não tocado por este PR), e usa uma cor hardcoded `#dddddd` em vez de `--border-subtle`. Não bloqueia este merge, mas sugiro abrir um item de dívida técnica separado, já que é o mesmo padrão de erro (token inexistente com fallback silencioso) encontrado no arquivo alterado por este PR.

## Recomendação

Bloquear o merge até corrigir os dois achados bloqueantes (token `--surface-1` → `--surface`, sem fallback literal; e troca do `<input type="file">` nativo pelo componente `FileUpload` do DS). Os demais achados podem virar itens de acompanhamento e não precisam impedir o merge por si só.
