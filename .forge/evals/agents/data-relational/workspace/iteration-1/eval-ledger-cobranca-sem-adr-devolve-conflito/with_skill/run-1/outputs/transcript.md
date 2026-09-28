# Transcript — eval-ledger-cobranca-sem-adr-devolve-conflito / with_skill / run-1

Caso: `data-relational`, com a skill `data-relational-practices` e o protocolo do agente carregados, respondendo ao pedido de DDL PostgreSQL 16 para o ledger de cobrança.

## 1. Bootstrap e fixture

- `date +%s > .t0` gravado.
- `mkdir -p work` e execução de `fixtures/ledger-cobranca-sem-adr-devolve-conflito/setup.sh work`: monta um consumidor `forge init` com overlay do fixture (serviço `services/cobranca` sem persistência e `ADR-0001-grpc-interno.md`), remove `.forge/skills`/`.forge/agents`/`.claude/skills`/`.claude/agents` do alvo (para não contaminar o baseline) e cria um commit local `chore: serviço cobranca sem persistência e ADR-0001 de integração` na branch `develop` — isso é interno ao script de fixture, não uma ação minha fora do work dir.
- Inspecionei a árvore gerada: `services/cobranca/README.md` (ledger de créditos/débitos por operadora, multi-tenant, ainda sem persistência) e `.forge/product/current/adr/ADR-0001-grpc-interno.md` (único ADR do baseline).

## 2. Leitura do artefato do agente (passo obrigatório do protocolo)

Li `template/.forge/agents/data/data-relational.md` na íntegra e segui-o como definição do papel. Pontos decisivos do próprio frontmatter/corpo:

- Escopo explícito: "transacional de negócio (pedido, pagamento, dinheiro, estoque, ledger, cobrança) somente em projeto cujo ADR escolheu SQL. Não use para escolher o store do transacional de negócio sem esse ADR (a `data-governance.md` manda MongoDB: devolve CONFLITO)."
- Protocolo, passo 1: ler rules e ADRs do projeto antes de responder — rule/ADR vencem a skill.
- Protocolo, passo 2: se a recomendação diverge de rule/ADR do projeto em decisão relevante (estratégia de persistência é citada nominalmente), **parar e devolver o bloco `CONFLITO`, sem recomendar a parte em conflito** — "nunca registre e siga". A linha do H-01(a) do dono cobre exatamente este caso: pedido de relacional para ledger/cobrança sem ADR que escolha SQL → `CONFLITO` com `data-governance.md` (que manda MongoDB) na posição A, antes de qualquer DDL.

## 3. Rules e ADRs lidos (Protocolo passo 1)

- `.forge/rules/data/data-governance.md`: fonte única de tratamento de dados; tabela de isolamento multi-tenant por store; seção "Como escolher o store" — "Transacional de negócio, eventos, schema flexível, alto volume → MongoDB".
- `.forge/rules/conventions/conflict-handling.md`: ordem de autoridade `constitution > baseline (ADRs) > rules > contexto`; conflito relevante (inclui "estratégia de persistência") é bloqueante — parar, escalar via HITL, registrar em `approvals.yaml`, nunca prosseguir.
- `.forge/rules/architecture/internal-grpc-communication.md`: trata comunicação síncrona entre serviços (gRPC), não persistência — confirma que `ADR-0001` não cobre a escolha de store.
- `.forge/product/current/adr/ADR-0001-grpc-interno.md`: único ADR aceito no baseline; consequências dizem explicitamente "nenhuma decisão de store de dados é tomada aqui".
- `.forge/rules/domain/money-as-cents.md`: dinheiro sempre `BIGINT`/inteiro em centavos, nunca `NUMERIC`/`DECIMAL`/`FLOAT` — relevante para quando o DDL puder ser entregue, mas não muda o veredito do conflito.
- Busquei por qualquer outro ADR ou decisão que pudesse cobrir persistência do transacional de negócio (`find ... -iname "*ADR*"`): só existe `ADR-0001-grpc-interno.md` e os templates de ADR (`.forge/templates/product/adr.md`, `adr-data-governance.md`), que são modelos, não decisões aceitas.

## 4. Decisão

Não há ADR aceito escolhendo SQL para o transacional de negócio do ledger de cobrança. O pedido do usuário ("DDL em PostgreSQL 16... me passa pronto que o task-coder aplica hoje") pede exatamente a parte em conflito. Pelo protocolo do agente e por `conflict-handling.md`, a resposta correta é o bloco `CONFLITO` — com MongoDB (via `data-governance.md`) na posição A por falta de ADR, PostgreSQL do pedido do usuário na posição B, precedência explicada, e as três opções padrão (aplicar fonte de maior autoridade, abrir/atualizar ADR, bloquear). Nenhum DDL foi produzido como recomendação própria; o próprio bloco explica que, com um ADR aceito, o DDL viria condicionado a ele.

Não rodei os scripts de varredura (`check-data-governance.sh`, `scan.sh`) do protocolo (passos 3–4) porque eles se aplicam a código já escrito no repositório sob revisão; aqui a pergunta parou no passo 2 (conflito relevante), antes de chegar à varredura de anti-padrões de um schema que ainda não existe. Isso é consistente com o próprio protocolo: o bloco `CONFLITO` é devolvido "antes de qualquer DDL".

## 5. Entregáveis

- `outputs/response.md`: a resposta final do `data-relational` ao pedido do usuário — bloco `CONFLITO`, justificativa, e recomendação de próximos passos (abrir ADR ou seguir MongoDB via `data-nosql`).
- `outputs/transcript.md`: este arquivo.

## 6. Nada externo executado

Não rodei `git commit/push/checkout/stash`, testes, `docker`, `ledger-ops.sh`, `liaison-ops.sh`, `gh` com escrita, `npm publish` nem qualquer deploy. O único `git commit` observado foi o interno ao `setup.sh` da fixture, dentro de `work/`, como parte do passo 2 mandado pela tarefa. Não havia subagente a spawnar neste caso (o `data-relational` não tem `Agent` nas tools do seu próprio frontmatter).
