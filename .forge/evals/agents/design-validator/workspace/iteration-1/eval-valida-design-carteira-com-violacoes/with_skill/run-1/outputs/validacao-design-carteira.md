# Validação do design.md

Módulo: CRT — Carteira · Design v0.3.0 (2026-09-18) · Base: requirements.md v1.2.0 (Aprovado)

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 7
- Total de achados HIGH: 6
- Total de achados MEDIUM: 4
- Total de achados LOW: 2

## Veredito

O design não pode seguir para `tasks.md`. Há um requisito aprovado (REQ-04) sem qualquer contraparte técnica, uma violação explícita de Clean Architecture no aggregate de domínio (anotações EF Core, `DbSet` dentro do `Domain`), dinheiro modelado como `double`/`FLOAT` em contradição direta com a ADR-0002 e o glossário do módulo, CPF armazenado e logado em claro em contradição direta com a RNF-03, ausência de RLS em tabela multi-tenant de domínio (anti-padrão bloqueante da rule de governança de dados) e eventos de integração sem envelope/outbox exigidos pela ADR-0003. Nenhum desses pontos é um ajuste de redação — cada um exige decisão de design nova (schema, tipos, contratos, catálogo de erros) e não pode ser corrigido por mim no `design.md` sem extrapolar o papel de auditoria deste agente. Retorno os achados para o `design-writer`.

## Achados

### [BLOCKER-01] REQ-04 (Bloquear carteira) sem contraparte técnica

**Local:** Seção "Requisitos Funcionais" do requirements.md (REQ-04) vs. design.md inteiro — ausente em Modelo de Domínio, Application Layer, API Contracts, Catálogo de Erros e Diagramas.
**Problema:** O requirements.md v1.2.0 exige bloqueio de carteira pelo passageiro, rejeição de qualquer débito após o bloqueio, e trilha de auditoria (autor, data, motivo). O design.md não menciona bloqueio em nenhuma seção: não há comando `BloquearCarteira`, não há campo de estado na aggregate, não há endpoint, não há erro catalogado para débito em carteira bloqueada, não há tabela/evento de auditoria.
**Impacto:** Requisito aprovado ficaria sem implementação; `tasks-writer` não teria base para gerar tasks de um recurso de segurança do usuário (perda/roubo). Termo "Bloqueio" já está no glossário do domínio, reforçando que é conceito de primeira classe ignorado.
**Correção recomendada:** Adicionar ao design: estado `Bloqueada` na aggregate `Carteira` (ou Value Object `StatusCarteira`) com invariante "débito rejeitado quando bloqueada"; endpoint `POST /v1/carteiras/{id}/bloqueios` com autor/motivo; evento de domínio `CarteiraBloqueada`; erro `CRT-ERR-004` (carteira bloqueada); tabela de auditoria conforme `.forge/rules/domain/audit-immutability.md` (append-only, trigger de imutabilidade); sequence diagram do fluxo de bloqueio.

### [BLOCKER-02] Domain aggregate acoplado a EF Core

**Local:** design.md, seção "Modelo de Domínio" (bloco `csharp`, linhas ~41–57) e "Decisões Inline" (DD-001).
**Problema:** O aggregate `Carteira` em `CRT.Domain` importa `Microsoft.EntityFrameworkCore` e usa `[Table("carteira")]`, `[Key]` e `DbSet<Movimentacao>` diretamente. A ADR-0001 é explícita: "o projeto Domain não referencia nenhum pacote de infraestrutura (EF Core, ...)" e a rule `architecture/clean-architecture.md` lista exatamente este padrão (`[Key]` no domínio) como anti-pattern e afirma que a regra de dependência é "inviolável". O DD-001 tenta justificar a escolha como decisão local ("menos código"), mas uma DD não pode contradizer uma ADR aceita (checklist item 18).
**Impacto:** Quebra o build via `Architecture.Tests` (conforme a própria ADR-0001 prevê) assim que implementado; acopla o domínio à tecnologia de persistência, impedindo troca de ORM e testes unitários puros do aggregate.
**Correção recomendada:** Remover anotações de EF Core e `DbSet<Movimentacao>` do `CRT.Domain`. Mapear `Carteira`/`Movimentacao` via `IEntityTypeConfiguration<T>` em `CRT.Infrastructure`, conforme diretriz 12 da rule. `Movimentacao` deve ser referenciada pela aggregate como coleção de domínio pura (`IReadOnlyCollection<Movimentacao>`), não `DbSet`. Remover ou reescrever DD-001 revertendo a decisão, já que ela conflita com ADR-0001.

### [BLOCKER-03] Dinheiro representado como `double`/`FLOAT`

**Local:** design.md, aggregate `Carteira` (`public double Saldo`, `Debitar(double valor)`, `Creditar(double valor)`), schema SQL (`saldo FLOAT`, `valor FLOAT`), evento publicado `carteira.debitada` (`"valor": 4.4, "saldo": 10.6`).
**Problema:** A ADR-0002 proíbe `float`/`double`/`decimal` em cálculo de tarifa e saldo, exige `Money` com `long Centavos` e coluna `BIGINT`. A rule `domain/money-as-cents.md` repete a proibição e exige sufixo `InCents`. O glossário do módulo já define `Saldo` como "objeto de valor monetário em centavos (`long`), nunca negativo". O design contradiz as três fontes ao mesmo tempo.
**Impacto:** Risco de erro de arredondamento em produção — a própria ADR-0002 cita divergência de conciliação já ocorrida em 2025 pelo mesmo motivo. Compromete diretamente a PBT-01 (saldo nunca fica negativo): aritmética de ponto flutuante pode produzir saldo negativo por erro de representação mesmo com validação de negócio correta.
**Correção recomendada:** Substituir `Saldo`/`valor` por objeto de valor `Money` com `long Centavos` (ou `SaldoEmCentavos`/`ValorEmCentavos`) em toda a cadeia: aggregate, schema (`BIGINT NOT NULL`), request/response da API (`integer`, `format: int64`, descrição "valor em centavos (BRL)"), payload de eventos. Ajustar exemplos do AsyncAPI.

### [BLOCKER-04] CPF em claro e em log, sem mascaramento (viola RNF-03 e pii-pci)

**Local:** design.md, seção "Segurança" ("CPF armazenado em claro para facilitar suporte") e "Observabilidade" ("Logs estruturados... com `carteira_id` e `cpf`").
**Problema:** RNF-03 do requirements.md exige "CPF nunca aparece em logs sem mascaramento (LGPD)" — o design contradiz isso de forma explícita e deliberada, inclusive justificando o CPF em claro como conveniência de suporte. A rule `architecture/pii-pci-classification.md` classifica CPF como `pii`, exige `masking` obrigatório e trata PII em log como violação sempre em modo enforce, independente de adoção gradual do rule-pack.
**Impacto:** Violação direta de requisito aprovado e de LGPD; dado pessoal exposto em toda a superfície de logs e no armazenamento primário sem controle compensatório.
**Correção recomendada:** Declarar `cpf` no mapa `data-classification.schema.json` como `classification: pii`, `masking` (ex.: `"mask_document"` mostrando só os 3 últimos dígitos). Mascarar na borda de emissão do log antes de qualquer `ILogger`. Se suporte precisa localizar carteira por CPF, expor busca por hash/token, não pelo dado bruto em log; armazenamento pode manter CPF (é identificador do domínio), mas sem a justificativa de "para facilitar suporte" — suporte deve consultar via aplicação com controle de acesso, não via log.

### [BLOCKER-05] Multi-tenancy sem RLS na tabela de domínio multi-tenant

**Local:** design.md, seção "Multi-tenancy" ("`tenant_id` na tabela `carteira`, filtro global do EF Core por tenant.").
**Problema:** `.forge/rules/data/data-governance.md` define isolamento multi-tenant obrigatório para PostgreSQL como `tenant_id` **+ EF Global Query Filter + RLS**, com RLS dispensável "só por exceção formal documentada". O design lista apenas o filtro do EF Core, sem RLS e sem exceção registrada — exatamente o anti-padrão bloqueante citado na rule ("um módulo declarar 'RLS opcional'/'sem RLS' para tabela multi-tenant de domínio em PostgreSQL").
**Impacto:** Um bug de aplicação que esqueça o filtro global (ex.: query raw, migration de dados, job em background) vazaria dados entre operadoras sem defesa em profundidade no banco.
**Correção recomendada:** Adicionar política RLS em `carteira` e `movimentacao` (`USING (tenant_id = current_setting('app.tenant_id')::uuid)`), documentar na seção de Schema, e manter o EF Global Query Filter como camada de aplicação (defesa em profundidade, não substituição).

### [BLOCKER-06] Eventos sem envelope, outbox/inbox (viola ADR-0003)

**Local:** design.md, seção "AsyncAPI / Eventos Publicados e Consumidos" e "Infrastructure Layer" (`RecargaConfirmadaConsumer`).
**Problema:** A ADR-0003 exige que todo evento de integração seja publicado via outbox transacional e consumido com inbox para idempotência, com envelope obrigatório (`event_version`, `correlation_id`, `causation_id`, `tenant_id`, `idempotency_key`) e DLQ com retry exponencial limitado a 5 tentativas. O payload de `carteira.debitada` no design é `{ carteira_id, valor, saldo }` — sem nenhum campo do envelope. O consumidor `RecargaConfirmadaConsumer` é descrito como "lê o evento e chama `CreditarRecargaHandler`", sem outbox na publicação nem inbox/deduplicação no consumo.
**Impacto:** REQ-02 exige creditar "exatamente uma vez por `recarga_id`" e PBT-02 testa reprocessamento do mesmo evento N vezes — sem inbox/idempotency key, reentrega do RabbitMQ (at-least-once) creditaria a recarga múltiplas vezes. Publicar `carteira.debitada` sem outbox pode perder o evento se o processo cair entre o commit da transação e a publicação.
**Correção recomendada:** Envolver a publicação de `carteira.debitada` em outbox transacional na mesma transação do débito. Adicionar envelope completo aos dois eventos. Implementar tabela/mecanismo de inbox no consumidor de `recarga.confirmada`, chaveado por `recarga_id` (ou `idempotency_key`), conforme REQ-02/PBT-02. Descrever DLQ com retry exponencial (máx. 5 tentativas) na Infrastructure Layer.

### [BLOCKER-07] Regra de negócio (saldo suficiente) no Handler, não no Aggregate

**Local:** design.md, "Application Layer" ("`DebitarTarifaHandler` verifica o saldo antes de chamar `Carteira.Debitar`. Se insuficiente, retorna `CRT-ERR-002`.") vs. aggregate `Carteira.Debitar(double valor) { Saldo -= valor; }`.
**Problema:** A rule de Clean Architecture (diretriz 9) exige que "Handlers orquestram — não contêm lógica de negócio. Lógica pertence ao domínio." A verificação de saldo suficiente é a invariante central da PBT-01 ("o saldo nunca fica negativo") e está no handler; `Carteira.Debitar` apenas subtrai sem proteger a invariante — se chamado de qualquer outro lugar (novo caso de uso, teste, migração de dados), o saldo pode ficar negativo sem violar contrato do método.
**Impacto:** A invariante de domínio mais crítica do módulo (saldo nunca negativo) não é protegida pelo Aggregate Root, apenas por disciplina do chamador — exatamente o anti-pattern "domínio anêmico" citado na seção 5 (DDD Tático) e no checklist de anti-patterns gerais.
**Correção recomendada:** Mover a verificação para dentro de `Carteira.Debitar`, lançando exceção de domínio (`SaldoInsuficienteException`) quando `valor > Saldo`; o handler passa a apenas capturar a exceção e traduzir para `CRT-ERR-002`. Combinado com a correção do BLOCKER-03 (Money em centavos), a invariante fica protegida por tipo e por lógica no lugar certo.

## Achados HIGH

### [HIGH-01] Ausência de DLQ/retry descritos para a mensageria

**Local:** design.md, "Infrastructure Layer" (só cita timeout de 2s no banco).
**Problema:** ADR-0003 exige DLQ com retry exponencial limitado a 5 tentativas para filas críticas; nada é descrito para `RecargaConfirmadaConsumer`.
**Impacto:** Falha transitória no consumidor (ex.: banco fora do ar) pode causar reentrega infinita ou perda silenciosa da recarga, sem visibilidade operacional.
**Correção recomendada:** Descrever fila + DLQ + política de retry exponencial (5 tentativas) para o consumidor, e alerta quando mensagem cai na DLQ.

### [HIGH-02] `Architecture.Tests` listado na estrutura mas sem verificação descrita

**Local:** design.md, "Estrutura da Solução" (lista `CRT.Architecture.Tests`) vs. "Testes" (não menciona nenhuma regra verificada).
**Problema:** O checklist exige "Ausência de `Architecture.Tests` ou equivalente quando Clean Architecture é exigida" como bloqueante; aqui o projeto existe nominalmente, mas nenhuma regra concreta (ex.: "Domain não referencia EF Core") é descrita como teste, o que é especialmente grave dado o BLOCKER-02.
**Impacto:** Sem teste de arquitetura executável, a violação do BLOCKER-02 não seria pega automaticamente em CI.
**Correção recomendada:** Adicionar à seção Testes um teste `NetArchTest` explícito: "Domain não deve depender de EF Core/MassTransit/AspNetCore", e listar como gate de PR.

### [HIGH-03] RNF-01 (p95 < 150ms) sem mecanismo técnico além de índice de PK

**Local:** design.md, "Performance e Escalabilidade" ("Meta de p95 < 150 ms no débito; índice primário em `carteira.id`.").
**Problema:** Índice primário já existe por definição de PK — não é um mecanismo adicional para atingir a meta. Não há menção a connection pooling, cache de leitura, ou orçamento de latência por chamada externa (mTLS + banco).
**Impacto:** Meta de RNF declarada sem mecanismo concreto que a sustente — checklist trata "requisito de performance sem mecanismo técnico" como bloqueio potencial; mantenho como HIGH porque a meta ao menos existe e o caminho crítico (uma escrita indexada) é plausível.
**Correção recomendada:** Detalhar orçamento de latência (ex.: mTLS handshake reusado via keep-alive, timeout do banco de 2s é folgado demais para p95 de 150ms — revisar), e indicar teste de performance (k6/NBomber) na seção de Testes.

### [HIGH-04] Extrato paginado (REQ-05) sem índice para a consulta

**Local:** design.md, Schema (`movimentacao` só tem PK e FK `carteira_id`) vs. API Contracts (`GET /extrato?page&size`) vs. requirements (paginado, 90 dias).
**Problema:** Consulta por `carteira_id` + janela de 90 dias + paginação não tem índice composto declarado (`carteira_id, criado_em`).
**Impacto:** Consulta crítica de leitura sem índice — checklist de Persistência trata isso como bloqueante em geral; mantenho HIGH porque o volume por carteira é tipicamente baixo, mas deve ser corrigido antes de produção.
**Correção recomendada:** Adicionar índice `(carteira_id, criado_em DESC)` em `movimentacao` e declarar na seção de Schema.

### [HIGH-05] Riscos incompletos

**Local:** design.md, "Riscos" (único risco listado: pico de embarques às 7h).
**Problema:** Riscos de segurança (CPF em claro), de dados (dinheiro em float) e de integração (consumidor sem DLQ/idempotência) são óbvios a partir do próprio design e não estão registrados — checklist trata "risco de segurança óbvio ignorado" como bloqueio potencial da seção 19.
**Impacto:** Riscos que decorrem diretamente dos BLOCKERs acima não têm mitigação nem dono registrado, dificultando priorização.
**Correção recomendada:** Adicionar linhas de risco para exposição de PII, imprecisão monetária e reentrega de evento sem idempotência, com mitigação apontando para as correções acima.

### [HIGH-06] DD-001 sem "Alternativas"

**Local:** design.md, "Decisões Inline" (DD-001).
**Problema:** O template de decisão inline (checklist item 18) exige campo `Alternativas`; DD-001 tem apenas Contexto/Decisão/Justificativa/Impacto.
**Impacto:** Decisão de acoplar domínio a EF Core (já reprovada no BLOCKER-02) não registra o que foi considerado e descartado, dificultando revisão futura.
**Correção recomendada:** Ao reverter DD-001 (ver BLOCKER-02), se uma nova DD for necessária para outra decisão local, seguir o template completo com Alternativas.

## Achados MEDIUM

### [MEDIUM-01] PBT-02 sem mecanismo de teste declarado

**Local:** design.md, "Testes".
**Problema:** A lista de testes não menciona teste de idempotência do consumidor de `recarga.confirmada` (reprocessamento do mesmo `recarga_id`).
**Correção recomendada:** Adicionar teste de integração que publica o mesmo evento duas vezes e verifica crédito único, alinhado à correção do BLOCKER-06.

### [MEDIUM-02] Diagramas cobrem só o fluxo de débito

**Local:** design.md, "Diagramas" (C4 Context + sequence diagram só do débito).
**Problema:** Não há sequence diagram para bloqueio (ausente, ver BLOCKER-01) nem para o fluxo assíncrono de recarga.
**Correção recomendada:** Adicionar sequence diagram do consumo de `recarga.confirmada` e, após BLOCKER-01 ser endereçado, do fluxo de bloqueio.

### [MEDIUM-03] Observabilidade sem métrica de sucesso/falha da integração

**Local:** design.md, "Observabilidade" ("Métricas de débitos por minuto.").
**Problema:** Checklist pede métrica de sucesso/falha/latência para integração externa (consumo de `recarga.confirmada`, chamadas mTLS do validador); só há uma métrica de volume de débito.
**Correção recomendada:** Adicionar métricas de taxa de erro do consumidor e latência de processamento do evento, com `correlation_id` propagado do envelope (ver BLOCKER-06).

### [MEDIUM-04] Catálogo de erros não cobre carteira bloqueada

**Local:** design.md, "Catálogo de Erros".
**Problema:** Decorrência direta do BLOCKER-01 — falta `CRT-ERR-004` para débito rejeitado por bloqueio.
**Correção recomendada:** Incluído na correção do BLOCKER-01.

## Achados LOW

### [LOW-01] Decisões técnicas relevantes fora do formato DD-NNN

**Local:** design.md, "Segurança" (CPF em claro) e Modelo de Domínio (double para saldo).
**Problema:** Duas decisões técnicas de alto impacto estão descritas em prosa solta nas seções, não como Decisão Inline formal — dificulta rastreabilidade e revisão, independente do mérito (ambas já reprovadas acima).
**Correção recomendada:** Ao reformular as seções, registrar como DD (ou remover, já que ambas contradizem ADR/rule e não deveriam virar decisão aceita).

### [LOW-02] Histórico de versões não menciona mudança de tipo monetário

**Local:** design.md, "Histórico de Versões".
**Problema:** Quando a correção do BLOCKER-03 for aplicada, a nova versão deve registrar a mudança de `double` para `Money`/centavos como entrada de histórico, não apenas incrementar a versão.
**Correção recomendada:** Adicionar linha de histórico correspondente na próxima revisão.

## Matriz de Rastreabilidade

| Requirement | Contraparte no Design | Status |
|-------------|------------------------|--------|
| REQ-01 — Criar carteira | `CriarCarteiraHandler`, `POST /v1/carteiras`, `CRT-ERR-001` | OK |
| REQ-02 — Creditar recarga | `CreditarRecargaHandler`, `RecargaConfirmadaConsumer`, evento `recarga.confirmada` | Falhou (sem inbox/idempotência explícita para "exatamente uma vez") |
| REQ-03 — Debitar tarifa | `DebitarTarifaHandler`, `POST /debitos`, `CRT-ERR-002/003` | Falhou (regra de negócio fora do domínio; dinheiro em `double`) |
| REQ-04 — Bloquear carteira | — | Falhou (ausente) |
| REQ-05 — Consultar extrato | `ConsultarExtratoHandler`, `GET /extrato` | Falhou (sem índice para a consulta paginada) |
| RNF-01 — p95 < 150ms débito | Meta declarada, sem mecanismo suficiente | Falhou |
| RNF-02 — Segregação por tenant | `tenant_id` + EF filter, sem RLS | Falhou |
| RNF-03 — CPF mascarado em log | CPF em claro e em log | Falhou |
| PBT-01 — Saldo nunca negativo | Verificação no handler (não na aggregate); `double` | Falhou |
| PBT-02 — Idempotência da recarga | Não descrita | Falhou |

## Checks Executados

| Check | Resultado |
|-------|-----------|
| Tamanho até 3.000 linhas | OK (199 linhas) |
| Estrutura obrigatória | OK |
| Metadados e versionamento | OK |
| Rastreabilidade requirements → design | Falhou |
| Clean Architecture | Falhou |
| DDD tático | Falhou |
| Application Layer | Falhou |
| Infrastructure Layer | Falhou |
| Persistência e schema | Falhou |
| API Contracts | OK (com ressalva de índice, ver HIGH-04) |
| AsyncAPI / Eventos | Falhou |
| Segurança e LGPD | Falhou |
| Observabilidade | Falhou |
| Catálogo de erros | Falhou |
| Testes | Falhou |
| Multi-tenancy | Falhou |
| Performance e escalabilidade | Falhou |
| Diagramas Mermaid | OK (com ressalva de cobertura, ver MEDIUM-02) |
| Decisões DD-NNN | Falhou |
| Riscos | Falhou |
| Definition of Done | OK |
| README sincronizado | OK |

## Recomendações para o design-writer

1. Adicionar o fluxo completo de REQ-04 (bloqueio): estado na aggregate, endpoint, evento, erro, auditoria e diagrama.
2. Remover EF Core do `CRT.Domain` (anotações e `DbSet`); mover mapeamento para `IEntityTypeConfiguration` na Infrastructure; reverter DD-001.
3. Trocar `double`/`FLOAT` por `Money`/centavos (`long`, `BIGINT`) em aggregate, schema, contratos de API e payloads de evento.
4. Remover CPF em claro de logs e da justificativa de suporte; declarar `cpf` no mapa de classificação de dados com `masking` obrigatório.
5. Adicionar RLS em `carteira`/`movimentacao`, mantendo o filtro do EF Core como defesa em profundidade adicional.
6. Envolver publicação de eventos em outbox, adicionar envelope completo e implementar inbox/idempotência no consumo de `recarga.confirmada`.
7. Mover a checagem de saldo suficiente para dentro de `Carteira.Debitar` como invariante de domínio.
8. Cobrir os HIGH e MEDIUM (DLQ, teste de arquitetura, índice do extrato, riscos, DD completa, métricas de integração) na mesma revisão, já que decorrem em boa parte dos BLOCKERs.

## Decisão para o Pipeline

- Pode seguir para `tasks.md`: Não
- Requer nova execução do `design-writer`: Sim
- Requer nova ADR: Não (as decisões pendentes já têm ADR/rule aplicável — o problema é o design não segui-las, não a ausência de decisão registrada)
- Requer ajuste no `requirements.md`: Não (o requirements v1.2.0 está correto e é o design que diverge dele)
