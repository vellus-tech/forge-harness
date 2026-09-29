# Validação do design.md

Módulo: Carteira (CRT) · `docs/product/modules/carteira/design.md` v0.3.0 contra `requirements.md` v1.2.0 (Aprovado).

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 8
- Total de achados HIGH: 5
- Total de achados MEDIUM: 3
- Total de achados LOW: 1

## Veredito

O design não pode seguir para `tasks.md`. Há um requisito funcional aprovado (REQ-04, bloqueio de carteira) com zero contraparte técnica, o aggregate de domínio referencia Entity Framework Core diretamente (viola ADR-0001 e a rule `clean-architecture.md`), dinheiro é representado em `double`/`float` em domínio, schema e payload de evento (viola ADR-0002 e o glossário do projeto), e a mensageria não implementa nenhum dos mecanismos exigidos pela ADR-0003 (outbox, inbox/idempotência, envelope de evento, DLQ). Há também dado pessoal (CPF) armazenado em claro e presente em log sem máscara, o que viola RNF-03, `pii-pci-classification.md` e `observability.md`. Nenhum desses achados é um ajuste pequeno — todos exigem decisão de design ou reescrita de seção — por isso não apliquei correção direta no arquivo; a lista abaixo é o que o `design-writer` precisa endereçar antes de nova revisão.

## Achados

### [BLOCKER-01] REQ-04 (bloqueio de carteira) sem nenhuma contraparte técnica

**Local:** Application Layer, Modelo de Domínio, API Contracts — ausente em todas.
**Problema:** O `requirements.md` v1.2.0 exige que o passageiro possa bloquear a carteira pelo app, que débitos sejam rejeitados após o bloqueio e que a ação gere trilha de auditoria com autor, data e motivo (REQ-04). O `design.md` não define aggregate method, Command/Handler, endpoint, evento, coluna de estado ou auditoria para isso. O glossário do projeto (`domain-glossary.md`) já trata "Bloqueio" como conceito de domínio de primeira classe, reforçando que não é um detalhe secundário.
**Impacto:** Requisito aprovado fica sem implementação conceitual; `tasks.md` gerado a partir deste design não teria tasks para REQ-04, e a feature ficaria de fora da sprint sem ninguém perceber.
**Correção recomendada:** Adicionar ao aggregate `Carteira` um método `Bloquear(motivo, autor)` que muda um campo de estado (`status`/`bloqueada_em`) e passa a rejeitar `Debitar`; adicionar Command `BloquearCarteira` + Handler + endpoint (`POST /v1/carteiras/{id}/bloqueios`, JWT passageiro); adicionar evento `CarteiraBloqueada`; adicionar registro em tabela de auditoria (`audit_carteira_bloqueio` ou equivalente) com autor, data e motivo, coerente com `domain/audit-immutability.md`.

### [BLOCKER-02] Domain (`CRT.Domain`) referenciando Entity Framework Core diretamente

**Local:** Modelo de Domínio — bloco de código do aggregate `Carteira`.
**Problema:** O aggregate usa `using Microsoft.EntityFrameworkCore;`, `[Table("carteira")]`, `[Key]` e `DbSet<Movimentacao>` dentro do próprio `CRT.Domain`. ADR-0001 é explícita: "o projeto Domain não referencia nenhum pacote de infraestrutura (EF Core, Npgsql, MassTransit, AWS SDK, StackExchange.Redis)". A rule `architecture/clean-architecture.md` lista exatamente este padrão como anti-pattern ("Domain nunca referencia Entity Framework... EF Core DbContext configurado via `IEntityTypeConfiguration<T>` — nunca por atributos no domínio").
**Impacto:** Quebra a regra de dependência que `Architecture.Tests` (NetArchTest) deveria impor no build; acopla o domínio à tecnologia de persistência, indo contra a justificativa central de ADR-0001.
**Correção recomendada:** Remover toda anotação de EF Core do aggregate. Mover o mapeamento para `CRT.Infrastructure` via `IEntityTypeConfiguration<Carteira>` e `IEntityTypeConfiguration<Movimentacao>`. `Carteira` no domínio deve expor apenas a coleção de movimentações como `IReadOnlyCollection<Movimentacao>`, sem `DbSet`.

### [BLOCKER-03] Dinheiro representado em `double`/`float`, contra ADR-0002 e o glossário

**Local:** Modelo de Domínio (`double Saldo`, `Debitar(double valor)`, `Creditar(double valor)`), Schema (`saldo FLOAT`, `valor FLOAT`), payload do evento `carteira.debitada` (`"valor": 4.4`).
**Problema:** ADR-0002 proíbe `float`, `double` e `decimal` em cálculo de tarifa/saldo e exige o objeto de valor `Money` com `long Centavos`, persistido como `BIGINT`. O glossário do domínio já registra "Saldo | Objeto de valor monetário em centavos (`long`), nunca negativo" — o design contradiz a própria linguagem ubíqua do projeto.
**Impacto:** Reintroduz exatamente a classe de bug que motivou a ADR-0002 (divergência de conciliação com a operadora por erro de arredondamento em ponto flutuante).
**Correção recomendada:** Introduzir `CRT.Domain.ValueObjects.Money` (`long Centavos`, imutável, igualdade por valor). Trocar `Saldo`/`valor` para `Money` no domínio, `BIGINT` no schema (`saldo_centavos`, `valor_centavos`), e `"valor_centavos": 440` no payload do evento.

### [BLOCKER-04] Mensageria sem nenhum mecanismo da ADR-0003 (outbox, inbox, envelope, DLQ)

**Local:** Infrastructure Layer, AsyncAPI / Eventos.
**Problema:** ADR-0003 exige outbox transacional para publicação, inbox para idempotência no consumo, envelope com `event_version`, `correlation_id`, `causation_id`, `tenant_id`, `idempotency_key`, e DLQ com retry exponencial limitado a 5 tentativas. O design apenas descreve `RecargaConfirmadaConsumer` chamando o handler diretamente ao "receber a mensagem", sem outbox na publicação de `carteira.debitada`, sem tabela/registro de inbox, sem nenhum campo do envelope nos payloads mostrados, e sem qualquer menção a DLQ ou retry.
**Impacto:** REQ-02 e PBT-02 exigem crédito exatamente uma vez por `recarga_id` mesmo sob reprocessamento — sem inbox/idempotência isso não é garantido pelo design como descrito. Falha de publicação do evento `carteira.debitada` pode deixar o saldo debitado sem o evento correspondente (sem outbox, não há atomicidade entre a escrita e a publicação).
**Correção recomendada:** Adicionar tabela `outbox` no schema do módulo e descrever o fluxo de publicação transacional; adicionar tabela/registro de inbox chaveado por `recarga_id` para deduplicação em `RecargaConfirmadaConsumer`; incluir os cinco campos de envelope em ambos os payloads (publicado e consumido); descrever fila de DLQ com retry exponencial limitado a 5 tentativas para o consumer.

### [BLOCKER-05] CPF armazenado em claro e presente em log sem máscara

**Local:** Segurança ("CPF armazenado em claro para facilitar suporte"), Observabilidade ("Logs estruturados... com `carteira_id` e `cpf`").
**Problema:** RNF-03 do próprio `requirements.md` exige que "CPF nunca aparece em logs sem mascaramento (LGPD)". A rule `architecture/pii-pci-classification.md` classifica CPF como `pii` e trata PII em log sem mascaramento como violação sempre em modo enforce, independentemente de qualquer modo de adoção do repositório. `observability.md` lista explicitamente "PII em logs (senhas, tokens, CPF, dados de pagamento)" como proibição.
**Impacto:** Violação direta de LGPD e de um requisito não funcional já aprovado; "para facilitar suporte" não é uma justificativa aceita pelas rules do projeto para armazenar dado pessoal em claro.
**Correção recomendada:** Declarar `cpf` em `data-classification.schema.json` como `classification: pii` com `masking: "mask_middle"` (ou equivalente) aplicado na borda de emissão do log; remover `cpf` dos campos logados por padrão (usar `carteira_id`/`tenant_id`); se armazenamento em claro for realmente necessário para suporte, isso precisa virar uma decisão explícita (DD ou ADR) com controle de acesso e trilha de auditoria — não uma frase solta na seção de Segurança.

### [BLOCKER-06] Ausência de C4 Level 2 (Container)

**Local:** Diagramas — apenas um `C4Context` (Level 1) e um sequence diagram estão presentes.
**Problema:** O checklist exige C4 Level 1 (System Context) **e** C4 Level 2 (Container); a ausência de qualquer um dos dois é bloqueante.
**Impacto:** Sem o diagrama de containers, não fica claro como API, banco, fila e consumer se relacionam fisicamente — informação necessária para quem for implementar a partir do `tasks.md`.
**Correção recomendada:** Adicionar um `C4Container` mostrando `CRT.Api`, banco PostgreSQL, RabbitMQ (exchange/fila de `recarga.confirmada` e de `carteira.debitada`) e o Validador/app do passageiro como consumidores externos.

### [BLOCKER-07] Ausência de `Architecture.Tests` na estratégia de testes

**Local:** Testes.
**Problema:** A Estrutura da Solução declara `CRT.Architecture.Tests`, e Clean Architecture é exigida (ADR-0001), mas a seção Testes não menciona nenhum teste de arquitetura (NetArchTest) que imponha a regra de dependência descrita em `clean-architecture.md`. Isso é agravado pelo fato de o próprio domínio já violar a regra (BLOCKER-02) sem que nenhum teste tivesse detectado isso.
**Impacto:** Sem teste de arquitetura, novas violações da regra de dependência passam despercebidas no CI.
**Correção recomendada:** Adicionar à seção Testes: "Testes de arquitetura (`CRT.Architecture.Tests`, NetArchTest) garantindo que `CRT.Domain` não referencia EF Core, MassTransit, ASP.NET Core nem outro pacote de infraestrutura." Adicionar também teste de idempotência do consumer (reprocessar o mesmo `recarga_id` N vezes → um único crédito, cobrindo PBT-02 de forma automatizada).

### [BLOCKER-08] `DebitarTarifaHandler` sem idempotência descrita apesar de ser operação financeira sensível

**Local:** Application Layer (`DebitarTarifaHandler`), API Contracts (`POST /v1/carteiras/{id}/debitos`).
**Problema:** O checklist trata "Ausência de idempotência em operação que exige proteção contra repetição" como bloqueio de Application Layer. O endpoint de débito recebe `{ valor, linha_id }` mas o design não diz se reenvio da mesma requisição (retry de rede do validador, por exemplo) gera um segundo débito.
**Impacto:** Duplo débito por retry é um risco financeiro direto para o passageiro, sem qualquer proteção descrita.
**Correção recomendada:** Definir uma chave de idempotência para o débito (ex.: `embarque_id` do Validação, análogo ao `recarga_id` do crédito) e descrever como o handler a usa para deduplicar.

## Achados HIGH

### [HIGH-01] REQ-05 (extrato dos últimos 90 dias) sem o filtro de janela no contrato

**Local:** API Contracts — `GET /v1/carteiras/{id}/extrato`.
**Problema:** REQ-05 exige extrato "dos últimos 90 dias"; o contrato só define `?page&size`, sem parâmetro ou regra de janela temporal.
**Impacto:** Contraparte técnica do requisito está incompleta — implementação pode devolver todo o histórico, ou nenhuma garantia de que o corte de 90 dias existe.
**Correção recomendada:** Adicionar ao contrato o corte de 90 dias (regra de negócio fixa no handler, ou parâmetros `from`/`to` limitados a essa janela) e citar isso na Application Layer.

### [HIGH-02] Observabilidade não cobre traces nem `correlationId`

**Local:** Observabilidade.
**Problema:** `observability.md` exige os três pilares (métricas, logs, traces) e `correlationId` propagado em todos os logs/eventos/respostas de erro. O design só descreve logs estruturados e "métricas de débitos por minuto" — sem traces (OpenTelemetry), sem `correlationId`, sem health checks, sem dashboards/alertas.
**Impacto:** Fluxo crítico (débito de tarifa, RNF-01 com p95 < 150 ms) fica sem correlação ponta a ponta para debugar latência ou perda de evento entre Validação → Carteira.
**Correção recomendada:** Adicionar `correlationId` propagado desde o request do validador até o evento publicado; adicionar instrumentação OTel para spans de handler/chamada de banco; adicionar health checks (`/health/live`, `/health/ready`); referenciar `alerts-as-code` para os golden signals do boundary de débito.

### [HIGH-03] Retry/circuit breaker do `RecargaConfirmadaConsumer` não descritos

**Local:** Infrastructure Layer.
**Problema:** Só é citado "timeout de 2s nas chamadas ao banco". Não há retry com limite nem circuit breaker para o consumer nem para chamadas ao banco.
**Impacto:** Falha transitória de banco pode causar perda de mensagem (sem retry) ou reprocessamento descontrolado (retry infinito não especificado, o que também é anti-pattern listado).
**Correção recomendada:** Descrever retry com backoff e limite (coerente com o "retry exponencial limitado a 5 tentativas" de ADR-0003) antes de mover a mensagem para DLQ.

### [HIGH-04] DD-001 sem campo "Alternativas" e em conflito direto com ADR-0001

**Local:** Decisões Inline — DD-001.
**Problema:** O template exige Contexto/Decisão/Justificativa/Alternativas/Impacto; DD-001 omite Alternativas. Além disso, a decisão em si ("usar `[Table]` e `[Key]` direto no aggregate", "menos código") contradiz ADR-0001, que é Aceita — uma DD não pode sobrepor uma ADR aceita.
**Impacto:** Documenta formalmente uma violação arquitetural como se fosse decisão válida, mascarando o BLOCKER-02 como algo já deliberado.
**Correção recomendada:** Remover DD-001 (a decisão correta é seguir a ADR-0001, sem exceção) ou, se houver razão técnica real para desviar, abrir uma ADR nova propondo revisão de ADR-0001 — nunca via DD local.

### [HIGH-05] Riscos não cobre nenhum dos riscos óbvios já levantados acima

**Local:** Riscos.
**Problema:** A tabela de Riscos tem uma única linha ("Pico de embarques às 7h"). Não há risco registrado para: duplo crédito de recarga sem inbox, duplo débito sem idempotência, exposição de CPF, ou divergência de conciliação por uso de float.
**Impacto:** Riscos de segurança e de dados financeiros, que são "óbvios" dado o restante do documento, ficam sem mitigação declarada — o checklist trata risco de segurança óbvio ignorado como bloqueio, mas aqui a lacuna é a ausência de registro (não a mitigação em si), por isso mantido como HIGH.
**Correção recomendada:** Adicionar linhas de risco para cada um dos pontos BLOCKER acima, com mitigação apontando para a correção recomendada correspondente.

## Achados MEDIUM

### [MEDIUM-01] Catálogo de erros não cobre bloqueio nem idempotência

**Local:** Catálogo de Erros.
**Problema:** Não há código de erro para "carteira bloqueada, débito rejeitado" (necessário assim que REQ-04 for implementado) nem para conflito de idempotência.
**Correção recomendada:** Adicionar `CRT-ERR-004` (carteira bloqueada) quando REQ-04 for endereçado.

### [MEDIUM-02] Diagrama de sequência não cobre o fluxo de crédito de recarga

**Local:** Diagramas.
**Problema:** Só o fluxo de débito tem sequence diagram; o consumo de `recarga.confirmada` (fluxo assíncrono, mais propenso a bug de duplicação) não tem diagrama.
**Correção recomendada:** Adicionar sequence diagram do consumer, incluindo o passo de checagem de inbox.

### [MEDIUM-03] Definition of Done genérica

**Local:** Definition of Done.
**Problema:** Só tem duas linhas ("Código implementado e testado", "PR aprovado"), sem cobrir testes de arquitetura, observabilidade, segurança, migrations ou revisão de ADR/DD, como o checklist pede.
**Correção recomendada:** Expandir a DoD para citar explicitamente os itens acima, em especial os que decorrem das correções deste relatório.

## Achados LOW

### [LOW-01] `Debitar`/`Creditar` sem guarda de invariante visível no domínio

**Local:** Modelo de Domínio.
**Problema:** `Debitar(double valor) { Saldo -= valor; }` não mostra a checagem de saldo suficiente nem a proteção "saldo nunca negativo" (PBT-01) — a checagem está descrita como vivendo no `DebitarTarifaHandler`, fora do aggregate.
**Correção recomendada:** Mover a invariante para dentro do método `Debitar` do aggregate (lançando exceção de domínio quando insuficiente), coerente com "toda lógica de negócio vive no Domain" da rule de Clean Architecture; o handler apenas traduz a exceção para `CRT-ERR-002`.

## Matriz de Rastreabilidade

| Requirement | Contraparte no Design | Status |
|-------------|------------------------|--------|
| REQ-01 Criar carteira | Command `CriarCarteira`, Handler, `POST /v1/carteiras`, erro `CRT-ERR-001` | OK |
| REQ-02 Creditar recarga confirmada | Command `CreditarRecarga`, `RecargaConfirmadaConsumer` — sem inbox/idempotência | Falhou (BLOCKER-04) |
| REQ-03 Debitar tarifa | Command `DebitarTarifa`, `POST /v1/carteiras/{id}/debitos`, erro `CRT-ERR-002` — sem idempotência | Falhou (BLOCKER-08) |
| REQ-04 Bloquear carteira | Nenhuma | Falhou (BLOCKER-01) |
| REQ-05 Consultar extrato | Query `ConsultarExtrato`, `GET .../extrato` — sem corte de 90 dias | Falhou (HIGH-01) |
| RNF-01 Latência p95 < 150 ms débito | Timeout de 2s no banco; sem SLO/métrica de latência do endpoint | Falhou (HIGH-02) |
| RNF-02 Segregação por tenant | `tenant_id` no schema + filtro global EF Core | OK |
| RNF-03 CPF nunca em log sem máscara | CPF em log sem máscara; CPF em claro no banco | Falhou (BLOCKER-05) |
| PBT-01 Saldo nunca negativo | Checagem no handler, não no aggregate | Falhou parcialmente (LOW-01) |
| PBT-02 Reprocessar recarga → 1 crédito | Nenhum mecanismo de inbox/dedup descrito | Falhou (BLOCKER-04) |

## Checks Executados

| Check | Resultado |
|-------|-----------|
| Tamanho até 3.000 linhas | OK (198 linhas) |
| Estrutura obrigatória | OK (todas as seções presentes) |
| Metadados e versionamento | OK |
| Rastreabilidade requirements → design | Falhou |
| Clean Architecture | Falhou |
| DDD tático | Falhou (Money ausente; invariante fora do aggregate) |
| Application Layer | Falhou (idempotência ausente) |
| Infrastructure Layer | Falhou (outbox/inbox/DLQ/retry ausentes) |
| Persistência e schema | Falhou (dinheiro em FLOAT; CPF em claro) |
| API Contracts | Falhou (extrato sem janela de 90 dias) |
| AsyncAPI / Eventos | Falhou (sem envelope, sem outbox/inbox) |
| Segurança e LGPD | Falhou (CPF em claro e em log) |
| Observabilidade | Falhou (sem traces/correlationId/alertas) |
| Catálogo de erros | Aprovado com ressalvas |
| Testes | Falhou (sem Architecture.Tests, sem teste de idempotência) |
| Multi-tenancy | OK |
| Performance e escalabilidade | Aprovado com ressalvas (falta SLO explícito além do RNF) |
| Diagramas Mermaid | Falhou (sem C4 Level 2) |
| Decisões DD-NNN | Falhou (DD-001 contradiz ADR-0001, sem Alternativas) |
| Riscos | Aprovado com ressalvas (cobertura incompleta) |
| Definition of Done | Falhou (genérica) |
| README sincronizado | OK |

## Recomendações para o design-writer

1. Adicionar REQ-04 (bloqueio de carteira) por completo: aggregate method, Command/Handler, endpoint, evento, auditoria.
2. Remover EF Core do domínio (BLOCKER-02) e introduzir `Money` em centavos no domínio/schema/eventos (BLOCKER-03), eliminando a DD-001 atual.
3. Implementar outbox + inbox + envelope de evento (`event_version`, `correlation_id`, `causation_id`, `tenant_id`, `idempotency_key`) e DLQ com retry limitado, conforme ADR-0003 (BLOCKER-04).
4. Remover CPF em claro do storage e dos logs; declarar CPF como PII mascarado conforme `pii-pci-classification.md` (BLOCKER-05).
5. Adicionar C4 Container, teste de arquitetura e idempotência no débito de tarifa (BLOCKER-06, 07, 08), e endereçar os achados HIGH de observabilidade, corte de 90 dias no extrato, retry/circuit breaker e riscos.

## Decisão para o Pipeline

- Pode seguir para `tasks.md`: Não
- Requer nova execução do `design-writer`: Sim
- Requer nova ADR: Não (as três ADRs existentes já cobrem os pontos violados; o problema é aderência, não lacuna normativa)
- Requer ajuste no `requirements.md`: Não
