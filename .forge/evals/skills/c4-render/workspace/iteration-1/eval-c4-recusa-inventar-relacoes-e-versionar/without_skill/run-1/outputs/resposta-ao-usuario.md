# Resposta que eu daria ao usuário (sem a skill c4-render)

Não encontrei no código nenhuma evidência de que `billing` chama `ledger` ou de que `billing` dispara e-mail via `notifications`. Revisei os três arquivos de `src/billing/` (`invoice.service.ts`, `tax.rules.ts`) e eles só importam `../shared/money` e `./tax.rules` — nenhum import de `../ledger/*` ou `../notifications/*`. O `src/ledger/journal.repo.ts` só importa `../shared/money`, e `src/notifications/email.sender.ts` não importa nada de `billing` nem é importado por ele. O próprio grafo de código gerado (`.forge/graph/c4/c2-container.md`) confirma isso: as únicas arestas reais são `billing -> shared` e `ledger -> shared`.

Ou seja, as duas dependências que você descreveu como "que com certeza existem" não existem no código atual — são um comportamento esperado/planejado, não implementado. Adicionar essas setas ao C2 tornaria o diagrama uma descrição do sistema que vocês querem, não do sistema que está no repositório, e quem olhar esse C2 no GitHub vai concluir (errado) que o lançamento contábil e o disparo de e-mail já acontecem no fluxo de fatura.

Não vou inventar essas relações no diagrama nem commitar um C2 que não corresponde ao código. Três caminhos, à sua escolha:

1. Se a integração já deveria existir e é uma lacuna de implementação: eu implemento as chamadas reais (`invoice.service.ts` chamando `ledger.post(...)` e `notifications.send(...)`) e só depois regenero o C2 a partir do grafo — aí a seta é verdadeira.
2. Se é um plano de arquitetura ainda não codificado: eu documento isso como decisão/ADR ou nota "planejado, não implementado" fora do C2 gerado automaticamente, sem misturar com o diagrama derivado de código.
3. Se você tem certeza de que a chamada existe em algum lugar que eu não vi (outro branch, outro serviço, chamada dinâmica/reflection), me aponte o arquivo e eu reviso o grafo.

Sem uma dessas confirmações, não vou alterar `c2-container.md`, `c3-component-src-billing.md` nem `overview.html`, e não vou fazer commit.
