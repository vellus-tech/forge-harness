# Validação de completude — DDD pós-remoção do BC Integração Legada

**Escopo revisado:** `docs/product/ddd/` (segmentação, bounded contexts, context map, diagramas C4) cruzado com `docs/product/frd-nfrd`, `docs/product/trd`, `docs/product/modules`, `docs/product/glossary` e `docs/product/adr`.

## Veredicto

**Aprovar com ressalva — dá para seguir com 3 dos 4 módulos agora, mas falta um artefato antes de gerar o módulo de Notificações.** A remoção do BC-05 (Integração Legada) em si foi propagada de forma limpa e completa por todos os artefatos. O gap que encontrei é anterior a essa remoção e não foi introduzido por ela.

## O que está correto (a remoção do BC-05 foi bem propagada)

1. **Matriz de segmentação (`ddd-segmentation.md`)** — BC-05 aparece riscado (`~~BC-05~~`), com nota de decisão do comitê e data (2026-09-10).
2. **Context map** — nenhuma relação upstream/downstream referencia mais o BC removido.
3. **Pasta `bounded-contexts/`** — o README de `integracao-legada/` foi mantido como *tombstone* (texto todo riscado + nota de remoção), não como conteúdo ativo.
4. **Diagramas C4 (níveis 1–3)** — nenhum node ou fluxo referencia o BC removido; `c4-level-2-containers.md` lista exatamente os 4 serviços vivos.
5. **`modules/README.md`** e **`trd.md`** — a lista de deployables já não inclui um serviço de integração legada.
6. **`data-model.md`, FRD/NFRD, PRD, glossário** — nenhuma referência órfã ao bilhete magnético fora do próprio tombstone e da linha riscada da segmentação.

## Gap bloqueante (para o módulo de Notificações, só esse)

**BC-04 (Notificações) não tem README de Bounded Context.** `docs/product/ddd/bounded-contexts/` só tem `carteira/`, `recarga/`, `validacao/` e o tombstone `integracao-legada/` — não existe `bounded-contexts/notificacoes/README.md`. O que existe é `subdomains/generic/notificacoes/README.md`, que é um documento diferente e mais raso: descreve a classificação do subdomínio (Generic), não o Bounded Context (não define ownership de schema, modelo tático nem contrato de eventos consumidos com versão, no padrão dos outros três READMEs de BC).

A seção 4.1 da segmentação já confirma BC-04 como Bounded Context ("Confirmar como Generic"), e o Context Map e o C4 nível 2 já tratam Notificações como serviço real (`notificacoes-svc`, consumidor de `TarifaDebitada` e `SaldoCreditado`) — a decisão está tomada, só falta materializar o artefato de BC. Isso é independente da remoção do BC-05; a lacuna já existia antes.

Isso importa especificamente para o próximo passo do usuário (gerar módulos): sem o README do BC, não há de onde o gerador derivar ownership de schema, modelo tático e contrato de eventos consumidos para o módulo de Notificações — ele teria que inferir, e inferência nesse ponto é decisão de arquitetura sendo tomada pelo gerador de código, não pelo comitê.

## Ressalva não bloqueante

O README de `bounded-contexts/integracao-legada/` continua existindo como arquivo (com conteúdo todo riscado). Aceitável como registro de auditoria da remoção; vale decidir explicitamente se remove do diretório ou mantém como histórico antes de arquivar a mudança — não bloqueia nada, porque nenhum módulo é gerado a partir dele.

## Conclusão para o pedido do usuário

A remoção do BC-05 está completa e consistente em toda a documentação — não é o que falta. O que falta é pontual e não decorre da remoção: complete o README de `bounded-contexts/notificacoes/` (mesmo formato dos outros três: objetivo, linguagem, ownership de schema, eventos consumidos/publicados com versão) antes de gerar o módulo `notificacoes`. Pode seguir agora com a geração dos módulos Validação, Carteira e Recarga.
