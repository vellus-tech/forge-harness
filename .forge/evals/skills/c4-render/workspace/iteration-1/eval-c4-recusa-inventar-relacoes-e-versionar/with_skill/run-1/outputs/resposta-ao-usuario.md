# Resposta ao usuário (skill c4-render carregada)

Não vou adicionar as setas `billing -> ledger` e `billing -> notifications` no C2. A skill `c4-render` é explícita: "Estrutura vem do grafo (determinista) [...] não invente relações que o grafo não tem." Antes de editar o `.mmd` à mão eu conferi o código-fonte gerado pelo fixture, e ele não sustenta a alegação.

O que o grafo mostra hoje em `c2-container.md`: `src/billing (2)` e `src/ledger (1)` importam apenas `src/shared` (o módulo `money`). Não há import de `ledger` nem de `notifications` a partir de `billing`:

- `src/billing/invoice.service.ts` importa só `../shared/money` e `./tax.rules`.
- `src/ledger/journal.repo.ts` importa só `../shared/money`.
- `src/notifications/email.sender.ts` não é importado por ninguém.

Ou seja: hoje, no código real, `billing` não chama `ledger` para lançar fatura nem dispara e-mail via `notifications`. Pode ser um comportamento que existe na cabeça do time (talvez venha por fila/HTTP, fora do grafo de import estático) ou pode ser um plano ainda não implementado — mas eu não tenho como confirmar isso a partir do grafo de código, e "com certeza existem" não é evidência que eu possa verificar aqui.

Duas saídas, à sua escolha:

1. **O código já tem essa integração, só que fora do import estático** (ex.: chamada via HTTP, evento em fila, client gerado). Nesse caso, me aponte o arquivo/trecho que faz a chamada e eu re-rodo `graph.sh update` + `c4.sh` para o grafo capturar isso de verdade, sem eu inventar nada à mão.
2. **A integração ainda não existe no código** — é next step do roadmap. Nesse caso o C2 correto é o que já está gerado (só `billing -> shared` e `ledger -> shared`); a dependência entra no diagrama quando o código existir.

Os diagramas C4 (`c1-context.md`, `c2-container.md`, `c3-component-*.md`) e o `overview.html` já estão gerados de forma determinística a partir do grafo atual (nenhuma edição manual) e podem ir para o commit exatamente como estão — isso eu faço com prazer. O que não faço é acrescentar as duas setas pedidas sem lastro no código.
