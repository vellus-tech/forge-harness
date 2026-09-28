# Tasks — ROT — Estacionamento Rotativo Digital

- Versão: 1.0.0
- Data: 2026-09-26
- Status: Aprovado para desenvolvimento
- Referência base requirements: docs/product/modules/rotativo/requirements.md v1.1.0
- Referência base design: docs/product/modules/rotativo/design.md v1.0.0
- ADRs aplicáveis: ADR-0001, ADR-0002
- Rules aplicáveis: `.forge/rules/architecture/clean-architecture.md`, `.forge/rules/testing/tdd.md`, `.forge/rules/testing/property-based-testing.md`, `.forge/rules/domain/money-as-cents.md`, `.forge/rules/conventions/code-style.md`, `.forge/rules/conventions/conventional-commits.md`

## Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|------------------------|
| 1.0.0 | 2026-09-26 | Aprovado para desenvolvimento | Criação inicial do plano de tasks a partir de requirements v1.1.0 e design v1.0.0, ambos aprovados |

## 1. Convenções de Implementação

### 1.1 TDD-first

Toda implementação com lógica verificável deve seguir o ciclo:

1. Red - escrever teste que falha
2. Green - implementar o mínimo para passar
3. Refactor - melhorar sem alterar comportamento

Nenhuma implementação de regra de domínio, handler, endpoint, persistência, contrato ou integração deve ser considerada concluída sem teste correspondente.

### 1.2 Property-Based Testing

PBT é obrigatório para invariantes matemáticas, idempotência, round-trip, anti-enumeração, atomicidade, state machines, regras de conservação e cálculos monetários relevantes. Cada PBT mapeia para `PBT-NN` do `requirements.md` (PBT-01 idempotência, PBT-02 conservação de saldo, PBT-03 máquina de estados), usando FsCheck (ADR-0001).

### 1.3 Bite-sized Tasks

Cada subtask deve ser estimada para menos de 2 horas. Se exceder, deve ser dividida. Cada TASK deve ser pequena o suficiente para revisão objetiva, mas grande o suficiente para entregar um incremento verificável.

### 1.4 Branch Model

Padrão de branch:

```text
<tipo>/rotativo/<NN>-<slug>
```

Exemplos:

```text
feat/rotativo/01-bootstrap-clean-architecture
test/rotativo/04-ativacao-invariantes
fix/rotativo/09-idempotency-handler
```

### 1.5 Git Worktree

Quando aplicável, cada TASK pode usar worktree dedicado:

```sh
git worktree add ../worktrees/rotativo/<NN>-<slug> -b <branch>
```

### 1.6 Encerramento de TASK

Cada TASK deve encerrar com: testes locais verdes, coverage gate da camada atendido ou justificativa registrada, lint/format executado quando aplicável, documentação atualizada quando aplicável, commit em Conventional Commits e push da branch. PR pode ser aberto por TASK ou por onda, conforme regra do projeto.

### 1.7 Encerramento de Onda

Cada onda deve encerrar com: todas as TASKs da onda concluídas, CI verde, conflitos resolvidos, PR aberto ou atualizado, checklist de revisão preenchido e documentação sincronizada.

### 1.8 Early Exit

Se uma subtask falhar: marcar status como `[-]`, registrar o ponto de falha, registrar comando executado, registrar erro principal, não mascarar falha com implementação especulativa e deixar contexto suficiente para outro agente ou desenvolvedor retomar.

### 1.9 Convenção de Status

- `[ ]` Não iniciado
- `[-]` Em progresso
- `[X]` Concluído
- `[!]` Falhou — exige intervenção humana (interrompe a onda no `task-coder`)

### 1.10 Convenção canônica de IDs

`TASK-NN` é a unidade que o `task-coder` invoca contra um specialist. `ST-MM` são subtasks internas (Red/Green/Refactor/Docs/Encerramento), reiniciando a numeração a cada TASK. Onda é apenas atributo de agrupamento (campo `**Onda**` no header e seção 3), nunca entra no ID da TASK. A unidade de PR é a onda.

### 1.11 Estilo de código

A implementação de cada TASK segue `.forge/rules/conventions/code-style.md` — early return / guard clauses, aninhamento ≤3, uma função uma responsabilidade, sem literais mágicos, assinaturas enxutas, tratamento de erro fail-fast, imutabilidade por padrão e comentar o "porquê". Valores monetários sempre como `long` em centavos (`.forge/rules/domain/money-as-cents.md`), nunca `decimal`/`double`.

## 2. Status Geral

| TASK | Título | Onda | Branch | Status |
|------|--------|------|--------|--------|
| TASK-01 | Bootstrap da solution e 5 projetos Clean Architecture | Onda 1 | `feat/rotativo/01-bootstrap-clean-architecture` | [ ] |
| TASK-02 | Teste de arquitetura NetArchTest (Domain isolado) | Onda 1 | `test/rotativo/02-netarchtest-domain-isolation` | [ ] |
| TASK-03 | Value objects Placa, Minutos e Dinheiro | Onda 2 | `feat/rotativo/03-value-objects` | [ ] |
| TASK-04 | Aggregate Ativacao com invariante de tempo máximo e máquina de estados | Onda 2 | `feat/rotativo/04-aggregate-ativacao` | [ ] |
| TASK-05 | Evento de domínio AtivacaoConfirmada | Onda 2 | `feat/rotativo/05-evento-ativacao-confirmada` | [ ] |
| TASK-06 | PBT-02 — conservação de saldo | Onda 2 | `test/rotativo/06-pbt-conservacao-saldo` | [ ] |
| TASK-07 | ComprarAtivacaoCommand + idempotência (DD-001) + PBT-01 | Onda 3 | `feat/rotativo/07-comprar-ativacao-idempotente` | [ ] |
| TASK-08 | EstenderAtivacaoCommand | Onda 3 | `feat/rotativo/08-estender-ativacao` | [ ] |
| TASK-09 | ConsultarAtivacoesPorPlacaQuery + autorização fiscalizacao:read | Onda 3 | `feat/rotativo/09-consultar-ativacoes-placa` | [ ] |
| TASK-10 | Migration V1 — ativacoes, idempotency_keys, outbox | Onda 4 | `feat/rotativo/10-migration-v1-ativacoes` | [ ] |
| TASK-11 | Outbox relay — publicação AtivacaoConfirmada (DD-002) | Onda 4 | `feat/rotativo/11-outbox-relay-eventos` | [ ] |
| TASK-12 | Endpoint POST /v1/ativacoes | Onda 5 | `feat/rotativo/12-endpoint-comprar-ativacao` | [ ] |
| TASK-13 | Endpoint POST /v1/ativacoes/{id}/extensoes | Onda 5 | `feat/rotativo/13-endpoint-estender-ativacao` | [ ] |
| TASK-14 | Endpoint GET /v1/ativacoes?placa= | Onda 5 | `feat/rotativo/14-endpoint-consultar-ativacoes` | [ ] |
| TASK-15 | Observabilidade — placa mascarada, métrica e latência (RNF 1, RNF 2) | Onda 6 | `feat/rotativo/15-observabilidade-rnf` | [ ] |
| TASK-16 | Teste de carga — p95 < 300 ms @ 200 req/s (RNF 1) | Onda 6 | `test/rotativo/16-teste-carga-latencia` | [ ] |
| TASK-17 | Hardening final — NetArchTest de fechamento e DoD do módulo | Onda 6 | `test/rotativo/17-hardening-dod-modulo` | [ ] |

## 3. Ondas de Implementação

| Onda | Foco | TASKs | Critério de fechamento | Risco principal |
|------|------|-------|-------------------------|------------------|
| Onda 1 | Bootstrap | TASK-01, TASK-02 | Solution compila, 5 projetos criados, NetArchTest de isolamento de Domain verde, CI mínimo rodando | Estrutura de camadas errada obrigaria retrabalho nas ondas seguintes |
| Onda 2 | Domain | TASK-03..TASK-06 | Aggregate, value objects, evento e PBTs de domínio verdes, sem dependência de Infrastructure/Api | Máquina de estados (PBT-03) mal modelada permite `Expirada`/`Cancelada` voltarem a `Ativa` |
| Onda 3 | Application | TASK-07..TASK-09 | Os 3 handlers implementados, idempotência (PBT-01) e autorização por escopo testadas | Débito de carteira e criação de ativação fora da mesma transação quebra PBT-02 |
| Onda 4 | Infrastructure | TASK-10, TASK-11 | Migration aplicada, outbox gravado na mesma transação e relay publicando em `rotativo.eventos` | Publicação direta no broker fora do outbox (proibido por ADR-0002) |
| Onda 5 | API + Contracts | TASK-12..TASK-14 | 3 endpoints expostos, contratos e catálogo de erros ROT-001/002/003 cobertos por teste de contrato | Escopo OAuth incorreto expõe consulta de fiscalização (Req 3.2) |
| Onda 6 | Hardening | TASK-15..TASK-17 | RNF 1 e RNF 2 validados, NetArchTest final verde, documentação e DoD do módulo fechados | Placa completa vazando em log/trace (RNF 2) |

## 4. Tarefas

### TASK-01 - Bootstrap da solution e 5 projetos Clean Architecture

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 1 — Bootstrap |
| **Branch** | `feat/rotativo/01-bootstrap-clean-architecture` |
| **Worktree** | `git worktree add ../worktrees/rotativo/01-bootstrap-clean-architecture -b feat/rotativo/01-bootstrap-clean-architecture` |
| **Status** | [ ] |
| **Depende de** | Não aplicável |
| **Entregável** | Solution `Rotativo.sln` com os 5 projetos do design (`Rotativo.Domain`, `Rotativo.Application`, `Rotativo.Infrastructure`, `Rotativo.Api`, `Rotativo.Contracts`) e projetos de teste correspondentes, compilando e com CI mínimo (build + test) configurado |
| **Mapeia** | ADR-0001 |
| **Camada principal** | DevOps |

#### Objetivo

Criar a estrutura base de Clean Architecture exigida pelo design (§1) antes de qualquer código de domínio, para que as ondas seguintes tenham onde escrever.

#### Subtasks

- [ ] **ST-01 - Red:** adicionar teste de smoke (`dotnet build` + 1 teste trivial falho) que só passa com a solution criada
- [ ] **ST-02 - Green:** criar `Rotativo.sln` e os 5 projetos + projetos de teste xUnit, referências de camada conforme Clean Architecture (Api → Application → Domain; Infrastructure → Application/Domain; Contracts referenciado por Api)
- [ ] **ST-03 - Refactor:** ajustar `Directory.Build.props`/`nullable`/`ImplicitUsings` para consistência entre projetos
- [ ] **ST-04 - Docs:** registrar a estrutura de pastas no `README.md` do módulo
- [ ] **ST-05 - Encerramento:** `dotnet build` e `dotnet test` verdes, commit Conventional Commits, push da branch

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (bootstrap sem lógica de negócio, gate não se aplica ainda)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-02 - Teste de arquitetura NetArchTest (Domain isolado)

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 1 — Bootstrap |
| **Branch** | `test/rotativo/02-netarchtest-domain-isolation` |
| **Worktree** | `git worktree add ../worktrees/rotativo/02-netarchtest-domain-isolation -b test/rotativo/02-netarchtest-domain-isolation` |
| **Status** | [ ] |
| **Depende de** | TASK-01 |
| **Entregável** | Projeto `Rotativo.ArchitectureTests` com regra NetArchTest garantindo que `Rotativo.Domain` não referencia `Rotativo.Infrastructure` nem `Rotativo.Api` |
| **Mapeia** | Design §8 (teste de arquitetura NetArchTest), ADR-0001 |
| **Camada principal** | Tests |

#### Objetivo

Blindar a regra de dependência de Clean Architecture antes de qualquer código de domínio existir, para falhar cedo caso uma onda futura viole a regra.

#### Subtasks

- [ ] **ST-01 - Red:** escrever teste NetArchTest que falha por ainda não existir a asserção de isolamento
- [ ] **ST-02 - Green:** implementar a regra `Types().That().ResideInNamespace("Rotativo.Domain").Should().NotHaveDependencyOn("Rotativo.Infrastructure"/"Rotativo.Api")`
- [ ] **ST-03 - Refactor:** extrair helper reutilizável para futuras regras de arquitetura
- [ ] **ST-04 - Docs:** Não aplicável nesta task
- [ ] **ST-05 - Encerramento:** teste rodando no CI, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Architecture: 100% das regras críticas)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-03 - Value objects Placa, Minutos e Dinheiro

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 2 — Domain |
| **Branch** | `feat/rotativo/03-value-objects` |
| **Worktree** | `git worktree add ../worktrees/rotativo/03-value-objects -b feat/rotativo/03-value-objects` |
| **Status** | [ ] |
| **Depende de** | TASK-01 |
| **Entregável** | Value objects `Placa` (validação Mercosul/antigo + `Mascarada()`), `Minutos` e `Dinheiro` (centavos, `long`), imutáveis, em `Rotativo.Domain` |
| **Mapeia** | Design §2, RNF 2, `.forge/rules/domain/money-as-cents.md` |
| **Camada principal** | Domain |

#### Objetivo

Fornecer os blocos de valor que o aggregate `Ativacao` e os handlers de Application vão consumir, incluindo o mascaramento de placa exigido por RNF 2.

#### Subtasks

- [ ] **ST-01 - Red:** testes unitários para `Placa` (formato Mercosul, formato antigo, formato inválido, `Mascarada()` retornando apenas os 3 últimos caracteres), `Minutos` (positivo, zero/negativo rejeitado) e `Dinheiro` (soma, subtração, sempre em centavos `long`)
- [ ] **ST-02 - Green:** implementar os 3 value objects como `record`/`readonly struct` imutáveis com validação no construtor
- [ ] **ST-03 - Refactor:** extrair regex/parsing de placa para um validador dedicado, remover duplicação
- [ ] **ST-04 - Docs:** Não aplicável nesta task
- [ ] **ST-05 - Encerramento:** testes verdes, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Domain 95%+)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-04 - Aggregate Ativacao com invariante de tempo máximo e máquina de estados

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 2 — Domain |
| **Branch** | `feat/rotativo/04-aggregate-ativacao` |
| **Worktree** | `git worktree add ../worktrees/rotativo/04-aggregate-ativacao -b feat/rotativo/04-aggregate-ativacao` |
| **Status** | [ ] |
| **Depende de** | TASK-03 |
| **Entregável** | Aggregate `Ativacao` (Id, Placa, ZonaId, MinutosTotais, Estado, ExpiraEm) com invariante de tempo máximo da zona e transições de estado restritas a `Ativa → Expirada` e `Ativa → Cancelada` |
| **Mapeia** | Req 1.3, Req 2.1, Req 2.2, PBT-03, ROT-002, ROT-003 |
| **Camada principal** | Domain |

#### Objetivo

Modelar o núcleo do domínio garantindo, dentro do próprio aggregate, que nenhuma soma de minutos (ativação + extensões) exceda o tempo máximo da zona e que a máquina de estados nunca regrida a `Ativa`.

#### Subtasks

- [ ] **ST-01 - Red:** teste unitário para criação válida, criação rejeitada acima do tempo máximo (ROT-002), extensão que excede o tempo máximo (ROT-002) e extensão sobre ativação expirada/cancelada (ROT-003)
- [ ] **ST-02 - Green:** implementar `Ativacao.Criar(...)`, `Ativacao.Estender(...)`, `Ativacao.Expirar()`, `Ativacao.Cancelar()` com guard clauses fail-fast
- [ ] **ST-03 - Refactor:** extrair a validação de tempo máximo para um método privado único, reutilizado por criação e extensão
- [ ] **ST-04 - PBT-03:** propriedade FsCheck — para qualquer sequência de transições geradas aleatoriamente, nenhum estado terminal (`Expirada`/`Cancelada`) retorna a `Ativa`
- [ ] **ST-05 - Refactor:** revisar nomes e imutabilidade (setters privados, factory methods)
- [ ] **ST-06 - Docs:** Não aplicável nesta task
- [ ] **ST-07 - Encerramento:** testes e PBT verdes, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Domain 95%+)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-05 - Evento de domínio AtivacaoConfirmada

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 2 — Domain |
| **Branch** | `feat/rotativo/05-evento-ativacao-confirmada` |
| **Worktree** | `git worktree add ../worktrees/rotativo/05-evento-ativacao-confirmada -b feat/rotativo/05-evento-ativacao-confirmada` |
| **Status** | [ ] |
| **Depende de** | TASK-04 |
| **Entregável** | Evento de domínio `AtivacaoConfirmada` levantado por `Ativacao.Criar(...)` e coletado pelo aggregate root |
| **Mapeia** | Design §2 (evento de domínio), DD-002 |
| **Camada principal** | Domain |

#### Objetivo

Disponibilizar o evento que a Application vai gravar no outbox (Onda 4), sem acoplar o Domain a mensageria.

#### Subtasks

- [ ] **ST-01 - Red:** teste garantindo que `Ativacao.Criar(...)` acumula exatamente um `AtivacaoConfirmada` com os dados corretos
- [ ] **ST-02 - Green:** implementar coleção de eventos de domínio no aggregate root e o record `AtivacaoConfirmada`
- [ ] **ST-03 - Refactor:** garantir que a coleção de eventos é limpa após publicação, evitando republicação acidental
- [ ] **ST-04 - Docs:** Não aplicável nesta task
- [ ] **ST-05 - Encerramento:** testes verdes, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Domain 95%+)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-06 - PBT-02 — conservação de saldo

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 2 — Domain |
| **Branch** | `test/rotativo/06-pbt-conservacao-saldo` |
| **Worktree** | `git worktree add ../worktrees/rotativo/06-pbt-conservacao-saldo -b test/rotativo/06-pbt-conservacao-saldo` |
| **Status** | [ ] |
| **Depende de** | TASK-04 |
| **Entregável** | Propriedade FsCheck que, para qualquer sequência de ativações e extensões aceitas geradas aleatoriamente, verifica `saldo_inicial − saldo_final = Σ(minutos_debitados × tarifa)` sobre o modelo de domínio |
| **Mapeia** | PBT-02, Req 1.1 |
| **Camada principal** | Domain |

#### Objetivo

Fechar a lacuna de conservação monetária no nível de domínio antes que a Application componha débito de carteira + criação de ativação na mesma transação (TASK-07).

#### Subtasks

- [ ] **ST-01 - Red:** modelar o gerador FsCheck de sequências de comandos (criar, estender) e a propriedade que ainda falha por não haver cálculo de débito acumulado
- [ ] **ST-02 - Green:** implementar o cálculo de débito total a partir de `MinutosTotais × tarifa_por_minuto` da zona, expondo método puro testável
- [ ] **ST-03 - Refactor:** eliminar duplicação entre o cálculo de débito e o usado em `Ativacao.Estender`
- [ ] **ST-04 - Docs:** Não aplicável nesta task
- [ ] **ST-05 - Encerramento:** PBT verde com no mínimo 100 casos gerados, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Domain 95%+, PBT de conservação)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-07 - ComprarAtivacaoCommand + idempotência (DD-001) + PBT-01

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 3 — Application |
| **Branch** | `feat/rotativo/07-comprar-ativacao-idempotente` |
| **Worktree** | `git worktree add ../worktrees/rotativo/07-comprar-ativacao-idempotente -b feat/rotativo/07-comprar-ativacao-idempotente` |
| **Status** | [ ] |
| **Depende de** | TASK-04, TASK-05, TASK-06 |
| **Entregável** | `ComprarAtivacaoCommand` + handler que debita a carteira e cria a ativação na mesma transação, rejeita saldo insuficiente (ROT-001) e minutos acima do máximo (ROT-002), e é idempotente por `Idempotency-Key` |
| **Mapeia** | Req 1.1, Req 1.2, Req 1.3, Req 1.4, DD-001, PBT-01, RNF 1 |
| **Camada principal** | Application |

#### Objetivo

Implementar o caso de uso central do módulo: compra de ativação com débito atômico da carteira e garantia de idempotência via chave de requisição.

#### Subtasks

- [ ] **ST-01 - Red:** testes do handler para débito correto, rejeição ROT-001 (saldo insuficiente), rejeição ROT-002 (minutos acima do máximo) e retorno idêntico em requisição repetida com a mesma `Idempotency-Key`
- [ ] **ST-02 - Green:** implementar o handler consultando/gravando em `idempotency_keys` (request_hash + response_json) e compondo débito de carteira + `Ativacao.Criar(...)` em uma única transação
- [ ] **ST-03 - Refactor:** extrair a checagem de idempotência para um decorator/pipeline behavior reutilizável por outros commands idempotentes
- [ ] **ST-04 - PBT-01:** propriedade FsCheck — para qualquer sequência de N requisições com a mesma `Idempotency-Key`, existe exatamente uma ativação e exatamente um débito
- [ ] **ST-05 - Docs:** Não aplicável nesta task
- [ ] **ST-06 - Encerramento:** testes e PBT verdes, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Application 90%+, idempotência obrigatória)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-08 - EstenderAtivacaoCommand

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 3 — Application |
| **Branch** | `feat/rotativo/08-estender-ativacao` |
| **Worktree** | `git worktree add ../worktrees/rotativo/08-estender-ativacao -b feat/rotativo/08-estender-ativacao` |
| **Status** | [ ] |
| **Depende de** | TASK-07 |
| **Entregável** | `EstenderAtivacaoCommand` + handler, reaproveitando a checagem de idempotência de TASK-07 para `POST /v1/ativacoes/{id}/extensoes` |
| **Mapeia** | Req 2.1, Req 2.2, DD-001, ROT-002, ROT-003 |
| **Camada principal** | Application |

#### Objetivo

Cobrir a extensão de ativação vigente, respeitando o tempo máximo da zona e rejeitando extensão sobre ativação não vigente.

#### Subtasks

- [ ] **ST-01 - Red:** testes do handler para extensão aceita, rejeição ROT-002 (soma excede tempo máximo) e rejeição ROT-003 (ativação expirada/cancelada)
- [ ] **ST-02 - Green:** implementar o handler chamando `Ativacao.Estender(...)` e debitando a carteira pela diferença de minutos
- [ ] **ST-03 - Refactor:** reutilizar o pipeline behavior de idempotência da TASK-07 sem duplicar lógica
- [ ] **ST-04 - Docs:** Não aplicável nesta task
- [ ] **ST-05 - Encerramento:** testes verdes, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Application 90%+)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-09 - ConsultarAtivacoesPorPlacaQuery + autorização fiscalizacao:read

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 3 — Application |
| **Branch** | `feat/rotativo/09-consultar-ativacoes-placa` |
| **Worktree** | `git worktree add ../worktrees/rotativo/09-consultar-ativacoes-placa -b feat/rotativo/09-consultar-ativacoes-placa` |
| **Status** | [ ] |
| **Depende de** | TASK-04 |
| **Entregável** | `ConsultarAtivacoesPorPlacaQuery` + handler retornando apenas ativações em estado `Ativa` no instante da consulta, exigindo o escopo OAuth `fiscalizacao:read` |
| **Mapeia** | Req 3.1, Req 3.2, `.forge/rules/architecture/jwt-authentication.md` |
| **Camada principal** | Application |

#### Objetivo

Prover ao app de fiscalização a consulta de ativações vigentes por placa, sem vazar ativações expiradas/canceladas e sem permitir acesso sem o escopo correto.

#### Subtasks

- [ ] **ST-01 - Red:** testes do handler para retorno filtrado por estado `Ativa` e para rejeição quando o escopo `fiscalizacao:read` está ausente
- [ ] **ST-02 - Green:** implementar o handler com filtro por estado no instante da consulta e checagem de authorization policy
- [ ] **ST-03 - Refactor:** extrair a policy de escopo para reutilização em outros endpoints de fiscalização, se surgirem
- [ ] **ST-04 - Docs:** Não aplicável nesta task
- [ ] **ST-05 - Encerramento:** testes verdes, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Application 90%+, Security: cobertura por cenário crítico)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-10 - Migration V1 — ativacoes, idempotency_keys, outbox

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 4 — Infrastructure |
| **Branch** | `feat/rotativo/10-migration-v1-ativacoes` |
| **Worktree** | `git worktree add ../worktrees/rotativo/10-migration-v1-ativacoes -b feat/rotativo/10-migration-v1-ativacoes` |
| **Status** | [ ] |
| **Depende de** | TASK-01 |
| **Entregável** | Migration Flyway `V1__ativacoes.sql` com as tabelas `ativacoes`, `idempotency_keys` (retenção de 24h) e `outbox`, incluindo índice `(placa, estado)` |
| **Mapeia** | Design §5, DD-001, DD-002, ADR-0001, ADR-0002 |
| **Camada principal** | Infrastructure |

#### Objetivo

Materializar o schema de persistência que os handlers das Ondas 2/3 já assumem, seguindo a convenção `V<n>__<slug>.sql` do ADR-0001.

#### Subtasks

- [ ] **ST-01 - Red:** teste de integração (banco efêmero) que falha por a tabela ainda não existir
- [ ] **ST-02 - Green:** escrever `V1__ativacoes.sql` com as 3 tabelas e o índice `(placa, estado)`
- [ ] **ST-03 - Refactor:** revisar tipos de coluna (money em centavos `bigint`, timestamps `timestamptz`) contra `.forge/rules/domain/money-as-cents.md`
- [ ] **ST-04 - Docs:** Não aplicável nesta task
- [ ] **ST-05 - Encerramento:** migration aplicada com sucesso em banco efêmero de teste, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Infrastructure 70%+)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-11 - Outbox relay — publicação AtivacaoConfirmada (DD-002)

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 4 — Infrastructure |
| **Branch** | `feat/rotativo/11-outbox-relay-eventos` |
| **Worktree** | `git worktree add ../worktrees/rotativo/11-outbox-relay-eventos -b feat/rotativo/11-outbox-relay-eventos` |
| **Status** | [ ] |
| **Depende de** | TASK-05, TASK-10 |
| **Entregável** | Escrita de `AtivacaoConfirmada` na tabela `outbox` na mesma transação da compra (TASK-07) e relay em background publicando na exchange `rotativo.eventos` |
| **Mapeia** | DD-002, ADR-0002 |
| **Camada principal** | Infrastructure |

#### Objetivo

Garantir entrega confiável do evento de confirmação sem publicação direta no broker a partir do handler, conforme ADR-0002.

#### Subtasks

- [ ] **ST-01 - Red:** teste de integração que falha por o evento ainda não ser gravado no outbox dentro da transação do `ComprarAtivacaoCommand`
- [ ] **ST-02 - Green:** implementar o repositório de outbox e o relay em background que lê pendências e publica em `rotativo.eventos`
- [ ] **ST-03 - Refactor:** aplicar backoff/retry no relay e marcar registros publicados
- [ ] **ST-04 - Docs:** Não aplicável nesta task
- [ ] **ST-05 - Encerramento:** teste de integração verde (evento gravado e publicado), commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Infrastructure 70%+)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-12 - Endpoint POST /v1/ativacoes

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 5 — API + Contracts |
| **Branch** | `feat/rotativo/12-endpoint-comprar-ativacao` |
| **Worktree** | `git worktree add ../worktrees/rotativo/12-endpoint-comprar-ativacao -b feat/rotativo/12-endpoint-comprar-ativacao` |
| **Status** | [ ] |
| **Depende de** | TASK-07 |
| **Entregável** | Endpoint `POST /v1/ativacoes` com escopo `motorista:write`, contrato em `Rotativo.Contracts`, mapeamento de ROT-001/ROT-002 para HTTP 422 |
| **Mapeia** | Design §6, §7, Req 1 |
| **Camada principal** | Api |

#### Objetivo

Expor `ComprarAtivacaoCommand` como endpoint HTTP com o contrato e catálogo de erros definidos no design.

#### Subtasks

- [ ] **ST-01 - Red:** teste de contrato/integração que falha por o endpoint ainda não existir (request/response shape, 422 para ROT-001/ROT-002)
- [ ] **ST-02 - Green:** implementar o endpoint minimal API/controller, DTO de request/response em `Rotativo.Contracts`, exigindo `Idempotency-Key` no header
- [ ] **ST-03 - Refactor:** extrair mapeamento de exceções de domínio → `ProblemDetails` para um middleware reutilizado pelos 3 endpoints
- [ ] **ST-04 - Docs:** atualizar especificação OpenAPI do módulo
- [ ] **ST-05 - Encerramento:** teste de contrato verde, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Api 80%+)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-13 - Endpoint POST /v1/ativacoes/{id}/extensoes

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 5 — API + Contracts |
| **Branch** | `feat/rotativo/13-endpoint-estender-ativacao` |
| **Worktree** | `git worktree add ../worktrees/rotativo/13-endpoint-estender-ativacao -b feat/rotativo/13-endpoint-estender-ativacao` |
| **Status** | [ ] |
| **Depende de** | TASK-08, TASK-12 |
| **Entregável** | Endpoint `POST /v1/ativacoes/{id}/extensoes` com escopo `motorista:write`, mapeando ROT-002/ROT-003 para HTTP 422/409 |
| **Mapeia** | Design §6, §7, Req 2 |
| **Camada principal** | Api |

#### Objetivo

Expor `EstenderAtivacaoCommand` reaproveitando o middleware de erros e o contrato de `Idempotency-Key` da TASK-12.

#### Subtasks

- [ ] **ST-01 - Red:** teste de contrato que falha por o endpoint ainda não existir, cobrindo 422 (ROT-002) e 409 (ROT-003)
- [ ] **ST-02 - Green:** implementar o endpoint reaproveitando o middleware de mapeamento de erros
- [ ] **ST-03 - Refactor:** consolidar DTO de extensão em `Rotativo.Contracts` sem duplicar campos do contrato de compra
- [ ] **ST-04 - Docs:** atualizar especificação OpenAPI do módulo
- [ ] **ST-05 - Encerramento:** teste de contrato verde, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Api 80%+)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-14 - Endpoint GET /v1/ativacoes?placa=

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 5 — API + Contracts |
| **Branch** | `feat/rotativo/14-endpoint-consultar-ativacoes` |
| **Worktree** | `git worktree add ../worktrees/rotativo/14-endpoint-consultar-ativacoes -b feat/rotativo/14-endpoint-consultar-ativacoes` |
| **Status** | [ ] |
| **Depende de** | TASK-09 |
| **Entregável** | Endpoint `GET /v1/ativacoes?placa=` com escopo `fiscalizacao:read`, retornando apenas ativações vigentes |
| **Mapeia** | Design §6, Req 3 |
| **Camada principal** | Api |

#### Objetivo

Expor a consulta de fiscalização com o mesmo rigor de autorização validado em TASK-09.

#### Subtasks

- [ ] **ST-01 - Red:** teste de contrato que falha por o endpoint ainda não existir, incluindo caso 403 sem o escopo `fiscalizacao:read`
- [ ] **ST-02 - Green:** implementar o endpoint com binding de query string e authorization policy
- [ ] **ST-03 - Refactor:** normalizar o DTO de resposta em `Rotativo.Contracts`
- [ ] **ST-04 - Docs:** atualizar especificação OpenAPI do módulo
- [ ] **ST-05 - Encerramento:** teste de contrato verde, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Api 80%+, Security: cobertura por cenário crítico)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-15 - Observabilidade — placa mascarada, métrica e latência (RNF 1, RNF 2)

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 6 — Hardening |
| **Branch** | `feat/rotativo/15-observabilidade-rnf` |
| **Worktree** | `git worktree add ../worktrees/rotativo/15-observabilidade-rnf -b feat/rotativo/15-observabilidade-rnf` |
| **Status** | [ ] |
| **Depende de** | TASK-07, TASK-08, TASK-12, TASK-13 |
| **Entregável** | Log estruturado usando `placa_mascarada` (nunca a placa completa), métrica `rotativo_ativacoes_total{zona}` e histograma de latência de `POST /v1/ativacoes` |
| **Mapeia** | Design §8, RNF 1, RNF 2 |
| **Camada principal** | Api |

#### Objetivo

Fechar a exigência de privacidade (RNF 2) e instrumentar a métrica que vai alimentar o teste de carga da TASK-16 (RNF 1).

#### Subtasks

- [ ] **ST-01 - Red:** teste garantindo que nenhum log/trace do fluxo de compra/extensão contém a placa completa, apenas `Placa.Mascarada()`
- [ ] **ST-02 - Green:** implementar o enricher de log estruturado e o registro da métrica/histograma
- [ ] **ST-03 - Refactor:** garantir que o mascaramento é aplicado em um único ponto (scope/enricher), não espalhado por handlers
- [ ] **ST-04 - Docs:** documentar as métricas expostas no README do módulo
- [ ] **ST-05 - Encerramento:** teste de não-vazamento de placa verde, métricas visíveis em ambiente local, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (Observability: cobertura por fluxo crítico)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-16 - Teste de carga — p95 < 300 ms @ 200 req/s (RNF 1)

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 6 — Hardening |
| **Branch** | `test/rotativo/16-teste-carga-latencia` |
| **Worktree** | `git worktree add ../worktrees/rotativo/16-teste-carga-latencia -b test/rotativo/16-teste-carga-latencia` |
| **Status** | [ ] |
| **Depende de** | TASK-15 |
| **Entregável** | Script de carga (k6 ou equivalente disponível no projeto) validando p95 de `POST /v1/ativacoes` abaixo de 300 ms sob 200 req/s, com relatório salvo |
| **Mapeia** | RNF 1 |
| **Camada principal** | Tests |

#### Objetivo

Validar objetivamente o requisito de latência antes do encerramento do módulo, usando a métrica instrumentada em TASK-15.

#### Subtasks

- [ ] **ST-01 - Red:** rodar o script de carga contra a baseline atual e confirmar que o gate de aceite (p95 < 300 ms) está formalizado e falha se violado
- [ ] **ST-02 - Green:** ajustar o que for necessário (pool de conexão, índices, timeouts) até o p95 ficar abaixo de 300 ms com 200 req/s
- [ ] **ST-03 - Refactor:** documentar as configurações de performance aplicadas
- [ ] **ST-04 - Docs:** anexar relatório de carga ao README do módulo
- [ ] **ST-05 - Encerramento:** execução do teste de carga registrada como gate de CI ou manual documentado, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (RNF 1 validado com evidência de execução)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

---

### TASK-17 - Hardening final — NetArchTest de fechamento e DoD do módulo

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 6 — Hardening |
| **Branch** | `test/rotativo/17-hardening-dod-modulo` |
| **Worktree** | `git worktree add ../worktrees/rotativo/17-hardening-dod-modulo -b test/rotativo/17-hardening-dod-modulo` |
| **Status** | [ ] |
| **Depende de** | TASK-09, TASK-11, TASK-14, TASK-16 |
| **Entregável** | Suíte completa de NetArchTest revalidada com todo o código implementado, matriz de rastreabilidade fechada e README do módulo sincronizado |
| **Mapeia** | ADR-0001, Design §8, Critérios de Encerramento do Módulo |
| **Camada principal** | Docs |

#### Objetivo

Fechar o módulo confirmando que nenhuma onda introduziu violação de arquitetura e que a documentação reflete o estado final.

#### Subtasks

- [ ] **ST-01 - Red:** Não aplicável (task de fechamento, não de nova lógica)
- [ ] **ST-02 - Green:** rodar toda a suíte (unit, PBT, integração, contrato, arquitetura, carga) e corrigir qualquer regressão encontrada
- [ ] **ST-03 - Refactor:** limpar débitos técnicos pontuais identificados durante a execução das ondas
- [ ] **ST-04 - Docs:** atualizar `docs/product/modules/rotativo/README.md` com status final de `tasks.md`, versão, data e contagem de TASKs
- [ ] **ST-05 - Encerramento:** suíte completa verde, commit, push

#### Critérios de Aceite

- [ ] Testes da camada executados com sucesso
- [ ] Coverage gate aplicável atendido ou justificativa registrada (todos os gates da tabela da seção 6)
- [ ] Nenhum warning novo introduzido
- [ ] Rastreabilidade atualizada na matriz
- [ ] Documentação atualizada quando aplicável

## 5. Matriz de Rastreabilidade

| Origem | Descrição | TASKs | Status |
|--------|-----------|-------|--------|
| Req 1 | Comprar ativação (débito, ROT-001, ROT-002, idempotência) | TASK-04, TASK-07, TASK-12 | [ ] |
| Req 2 | Estender ativação (respeitar tempo máximo, ROT-002/ROT-003) | TASK-04, TASK-08, TASK-13 | [ ] |
| Req 3 | Consultar ativações por placa (apenas `Ativa`, escopo `fiscalizacao:read`) | TASK-09, TASK-14 | [ ] |
| RNF 1 | Latência p95 < 300 ms @ 200 req/s | TASK-15, TASK-16 | [ ] |
| RNF 2 | Privacidade — placa mascarada em logs/traces | TASK-03, TASK-15 | [ ] |
| PBT-01 | Idempotência — uma ativação e um débito por `Idempotency-Key` | TASK-07 | [ ] |
| PBT-02 | Conservação de saldo | TASK-06 | [ ] |
| PBT-03 | Máquina de estados sem regressão a `Ativa` | TASK-04 | [ ] |
| DD-001 | Idempotência via tabela `idempotency_keys` (24h) | TASK-07, TASK-08, TASK-10 | [ ] |
| DD-002 | Evento via outbox + publicação em `rotativo.eventos` | TASK-05, TASK-10, TASK-11 | [ ] |
| ADR-0001 | Stack .NET 8 + Clean Architecture + PostgreSQL + xUnit/FsCheck/NetArchTest | TASK-01, TASK-02, TASK-10, TASK-17 | [ ] |
| ADR-0002 | Transactional outbox para eventos de integração | TASK-11 | [ ] |
| Migration V1 | Tabelas `ativacoes`, `idempotency_keys`, `outbox` + índice | TASK-10 | [ ] |
| Endpoint POST /v1/ativacoes | Contrato e catálogo de erros | TASK-12 | [ ] |
| Endpoint POST /v1/ativacoes/{id}/extensoes | Contrato e catálogo de erros | TASK-13 | [ ] |
| Endpoint GET /v1/ativacoes?placa= | Contrato e autorização | TASK-14 | [ ] |
| Catálogo de erros | ROT-001, ROT-002, ROT-003 | TASK-04, TASK-07, TASK-08, TASK-12, TASK-13 | [ ] |
| Observabilidade | Log `placa_mascarada`, métrica e histograma de latência | TASK-15 | [ ] |
| Teste arquitetural | NetArchTest — Domain isolado de Infrastructure/Api | TASK-02, TASK-17 | [ ] |

## 6. Coverage Gates

| Camada | Gate | Tipo de teste esperado |
|---|---|---|
| Domain | 95%+ | Unitários + PBT-02 (conservação) + PBT-03 (máquina de estados) |
| Application | 90%+ | Unitários de handlers, idempotência (PBT-01), authorization |
| Infrastructure | 70%+ | Integração com PostgreSQL (migration), outbox e relay |
| Api | 80%+ | Contrato e integração dos 3 endpoints |
| Architecture | 100% das regras críticas | NetArchTest (Domain isolado de Infrastructure/Api) |
| Security | Cobertura por cenário crítico | Autorização por escopo (`motorista:write`, `fiscalizacao:read`), rejeição sem escopo |
| Observability | Cobertura por fluxo crítico | Log sem placa completa, métrica `rotativo_ativacoes_total`, histograma de latência |

Regras: coverage gate não substitui qualidade de teste; PBT existe para as 3 propriedades identificadas no `requirements.md`; testes de arquitetura são obrigatórios (Clean Architecture); testes de contrato são obrigatórios para os 3 endpoints; testes de segurança são obrigatórios para as duas operações sensíveis (débito e consulta de fiscalização); testes de idempotência são obrigatórios para os dois commands idempotentes.

## 7. Critérios de Encerramento

### Encerramento de TASK

Uma TASK só pode ser marcada como `[X]` quando: subtasks concluídas; testes aplicáveis verdes; coverage gate atendido ou justificativa registrada; lint/format executado quando aplicável; nenhum warning novo relevante; commit realizado; push realizado; documentação atualizada quando aplicável.

### Encerramento de Onda

Uma onda só pode ser considerada concluída quando: todas as TASKs da onda estiverem `[X]`; CI estiver verde; PR da onda estiver aberto, aprovado ou mergeado conforme regra do projeto; riscos da onda estiverem tratados ou registrados; README do módulo estiver sincronizado quando aplicável.

### Encerramento do Módulo

O módulo só pode ser considerado pronto quando: todas as 6 ondas estiverem concluídas; a matriz de rastreabilidade da seção 5 estiver completa (todas as linhas `[X]`); `requirements.md` v1.1.0, `design.md` v1.0.0 e este `tasks.md` estiverem consistentes entre si; os testes críticos (PBT-01, PBT-02, PBT-03, contrato dos 3 endpoints) estiverem verdes; a observabilidade mínima (RNF 1, RNF 2) estiver implementada e validada por teste de carga; a autorização por escopo (`motorista:write`, `fiscalizacao:read`) estiver validada; o catálogo de erros ROT-001/ROT-002/ROT-003 estiver coberto ponta a ponta; e o README do módulo estiver atualizado.

## 8. Riscos de Execução

- **Transação de débito + criação de ativação (TASK-07):** se o débito da carteira e a criação da ativação não ocorrerem na mesma transação de banco, PBT-02 (conservação de saldo) pode ser satisfeita em teste isolado e ainda assim quebrar em produção sob concorrência. Mitigação: teste de integração com banco real, não apenas mock de repositório.
- **Outbox fora da transação (TASK-11):** gravar o evento fora da transação da TASK-07 viola ADR-0002 silenciosamente (o teste unitário do handler não pegaria isso). Mitigação: teste de integração dedicado que verifica atomicidade outbox + estado.
- **Vazamento de placa completa (TASK-15):** frameworks de logging costumam serializar objetos inteiros por padrão; um `ToString()` ou serialização automática do aggregate pode expor a placa completa mesmo com `Mascarada()` implementado. Mitigação: teste que varre o output de log/trace por regex de placa completa, não apenas testa o value object isoladamente.
- **Escopo OAuth invertido (TASK-09/TASK-14):** troca acidental entre `motorista:write` e `fiscalizacao:read` nos 3 endpoints é um risco de segurança direto. Mitigação: teste de contrato específico para 403 quando o escopo não corresponde ao endpoint.
- **Teste de carga não representativo (TASK-16):** se o ambiente de teste de carga não tiver a mesma topologia (pool de conexão, réplica de banco) do ambiente alvo, o p95 medido não é confiável. Mitigação: registrar explicitamente a topologia usada no relatório de carga.

## 9. Referências

- `docs/product/modules/rotativo/requirements.md` v1.1.0
- `docs/product/modules/rotativo/design.md` v1.0.0
- `docs/product/adr/0001-stack-dotnet-postgresql.md`
- `docs/product/adr/0002-outbox-para-eventos.md`
- `docs/product/glossary/domain-glossary.md`
- `.forge/rules/architecture/clean-architecture.md`
- `.forge/rules/testing/tdd.md`
- `.forge/rules/testing/property-based-testing.md`
- `.forge/rules/domain/money-as-cents.md`
- `.forge/rules/conventions/code-style.md`
