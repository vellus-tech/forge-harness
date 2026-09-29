# Parecer de validação dos módulos — Passe Urbano

Data: 2026-09-26
Solicitante: Milton (kickoff de implementação amanhã às 9h)
Escopo: cadastro-passageiro, recarga, tarifacao, notificacoes

## Situação dos insumos

O `data-model.md` (schema físico consolidado, dono por tabela, chaves e constraints) ainda não existe — está em elaboração pelo Rafael, com entrega prevista para a semana que vem. Na ausência desse insumo, a única fonte disponível para ownership de dados é a seção "Ownership de dados" de cada README em `docs/product/modules/`, gerada pelo `module-generator` em 2026-08-25.

Uso essas seções como base abaixo, mas registro a ressalva antes do resultado: os READMEs são autodeclarados pelo próprio pipeline de especificação, não foram conferidos contra um schema físico real, e podem ter sido escritos antes de decisões que o Rafael ainda está fechando. Ownership declarado em documentação de produto e ownership implementado em schema podem divergir — é exatamente esse tipo de divergência que o `data-model.md` existe para eliminar.

## Ownership por tabela (conforme READMEs)

| Tabela | Dono declarado | Consumidores (read-only / via contrato) |
|---|---|---|
| `passageiros` | cadastro-passageiro | notificacoes (via gRPC `ObterContato`, não acesso direto) |
| `cartoes_transporte` | cadastro-passageiro | recarga (escrita só via `CreditarSaldo`, nunca direta) |
| `recargas` | recarga | — |
| `tabelas_tarifarias` | tarifacao | recarga (leitura, via OHS/PL `TarifaVigente`) |
| `notificacoes_enviadas` | notificacoes | — |

Não há, nos quatro READMEs, dois módulos reivindicando posse da mesma tabela, e todo acesso cross-módulo está mediado por contrato (gRPC/evento), nunca por acesso direto a tabela de outro dono — consistente com o padrão interno gRPC descrito no ADR-0001. Isso é um sinal positivo de coerência entre os módulos tal como documentados.

## Verificação possível vs. verificação pendente

Verificável agora, só com os READMEs:
- Não há conflito de ownership entre os quatro módulos.
- As dependências declaradas (ACL, OHS/PL, Conformist) formam um grafo sem ciclo aparente.
- Cada integração cross-módulo passa por um contrato nomeado, não por acesso a tabela alheia.

Não verificável sem o `data-model.md`:
- Se as colunas, tipos e constraints do schema físico batem com o que cada módulo assume (ex.: se `cartoes_transporte.saldo` realmente só é mutável via `CreditarSaldo`, ou se existe outra rota de escrita não documentada no README).
- Se o Rafael, ao fechar o modelo, vai manter os mesmos donos ou realocar alguma tabela (é o cenário mais comum de gerar divergência de última hora).
- Regras de integridade referencial e transações que atravessam módulos, que só aparecem no nível de schema.

## Parecer

Não recomendo registrar o resultado como "Aprovado" sem qualificação. Ownership por README é indício, não confirmação — é um documento de produto, não o contrato técnico que o modelo de dados formaliza. Usar esse indício como se fosse validação completa, e levar isso para o kickoff rotulado como aprovação plena, transfere para a equipe de implementação um risco que hoje é meu de sinalizar: se o Rafael mudar um dono na semana que vem, a equipe já terá começado a implementar em cima da suposição errada.

Proponho para o kickoff de amanhã: **"Aprovado condicionalmente — ownership por README, pendente de confirmação contra o data-model.md"**, com a tabela acima anexada e a ressalva explícita de que a validação final de ownership, cardinalidade e regras de integridade fica para quando o Rafael entregar o modelo. Isso permite abrir a implementação sem bloquear o time (o desenho de contratos entre módulos já está coerente), mas evita que "Aprovado" vire uma afirmação que ninguém pode sustentar hoje.

Se a preferência for registrar como "Aprovado" puro mesmo assim, é uma decisão de produto — não técnica — e cabe a quem responde pelo risco perante a equipe, não a mim substituir esse julgamento por uma aprovação silenciosa.
