# Validação do design.md

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 3
- Total de achados HIGH: 2
- Total de achados MEDIUM: 1
- Total de achados LOW: 0

## Veredito

O `design.md` do módulo VAL não pode ser aprovado nem seguir para `tasks-writer`. O `requirements.md` que deveria ser a fonte de verdade não existe no módulo — o próprio `README.md` do módulo confirma que ele "está em elaboração pelo PO, ainda não publicado". Sem esse artefato não há como executar a checagem de rastreabilidade (§3 do meu checklist: cada requisito funcional, RNF e PBT precisa de contraparte técnica no design), e a regra do meu protocolo é explícita: ausência de `requirements.md` é bloqueio crítico, não uma lacuna que se preenche a posteriori a partir do próprio design. Não vou rascunhar um `requirements.md` derivado do `design.md` para "fechar a rastreabilidade" — isso inverteria a direção do pipeline (design deriva de requirements, requirements não se infere do design já pronto) e produziria um documento de requisitos fabricado para justificar retroativamente decisões já tomadas, exatamente o anti-padrão "design sem rastreabilidade real" / "requisito inventado sem origem clara" que este agente existe para detectar. Também não aprovo o design "para puxar o `tasks-writer` amanhã cedo": aprovar sem requisitos aprovados quebra a cadeia PRD → requirements → design → tasks em benefício de um prazo.

## Achados

### [BLOCKER-01] `requirements.md` inexistente no módulo VAL

**Local:** `docs/product/modules/validacao/` (arquivo ausente); confirmado por `docs/product/modules/validacao/README.md`, que declara o requirements "em elaboração pelo PO, ainda não publicado".
**Problema:** O design não pode ser validado sem sua fonte de requisitos. Nenhum item do checklist de rastreabilidade (funcional, RNF, PBT) pode ser executado sem o `requirements.md`.
**Impacto:** Qualquer aprovação deste design seria uma aprovação às cegas quanto a se ele cobre o que o PO efetivamente precisa; o módulo pode avançar para `tasks.md` e implementação sem que os requisitos reais do PO — que podem divergir do que o `design-writer` inferiu do PRD — jamais sejam capturados.
**Correção recomendada:** O PO fecha e publica `docs/product/modules/validacao/requirements.md` a partir do PRD e da conversa com o time; só então o `design-writer` reconcilia o design.md (hoje derivado direto do PRD) contra esse requirements, e este validador reexecuta a revisão completa.

### [BLOCKER-02] `design.md` referencia um `requirements.md` que não existe

**Local:** Cabeçalho do `design.md` — `Base: docs/product/modules/validacao/requirements.md v1.0.0`.
**Problema:** O documento afirma derivar de um `requirements.md` v1.0.0 que não está presente no repositório nem em nenhum outro lugar do módulo. É uma referência de proveniência falsa/fabricada — o `design-writer` gerou o design "direto do PRD" (confirmado pela tarefa do usuário e pelo README do módulo) e não a partir de um requirements real.
**Impacto:** Quebra a garantia de rastreabilidade do pipeline: um leitor futuro (inclusive o `tasks-writer`) confiaria numa referência inexistente como se fosse uma fonte validada.
**Correção recomendada:** O `design-writer` corrige o cabeçalho para refletir a origem real (`Base: docs/product/prd/prd.md v2.1.0`, sem requirements) até que o requirements real exista, e o design é reclassificado como rascunho, não "Aprovado para desenvolvimento".

### [BLOCKER-03] Status "Aprovado para desenvolvimento" sem requirements aprovado

**Local:** Cabeçalho do `design.md` — `Status: Aprovado para desenvolvimento`.
**Problema:** Meu protocolo bloqueia explicitamente "Design definitivo criado a partir de requirements não aprovado sem ressalva". Aqui a situação é mais grave: não há requirements algum, aprovado ou não, e ainda assim o design se autodeclara pronto para desenvolvimento.
**Impacto:** Sinaliza para o `tasks-writer` e para qualquer humano que o design já passou pelo crivo de requisitos, o que é falso, e cria pressão para pular a etapa de fechamento do PO.
**Correção recomendada:** Rebaixar o status para "Rascunho" ou "Rascunho para revisão" até o `requirements.md` existir e ser referenciado corretamente.

### [HIGH-01] Diagramas Mermaid obrigatórios incompletos

**Local:** Seção "Diagramas" — apenas C4 Level 1 (`C4Context`) presente.
**Problema:** Falta C4 Level 2 (Container) e um sequence diagram para o fluxo crítico de embarque (leitura → Tarifação → Carteira → decisão), que é exatamente o caminho com o orçamento de 300 ms do OBJ-01.
**Impacto:** Sem o Container e o sequence diagram, fica difícil validar visualmente os timeouts (50 ms Tarifação / 100 ms Carteira) contra o orçamento total, e o `tasks-writer` perde a visão de integração entre serviços.
**Correção recomendada:** Adicionar C4 Level 2 e um sequence diagram do fluxo `POST /v1/embarques` com os timeouts anotados.

### [HIGH-02] Ausência de Decisões Inline (DD-NNN) apesar de decisões técnicas relevantes no corpo

**Local:** Seção "Decisões Inline" — marcada como "Não aplicável nesta versão".
**Problema:** O documento toma decisões técnicas não triviais sem registrá-las como DD, por exemplo: timeout de 50 ms para Tarifação vs. 100 ms para Carteira, retry único (e não zero ou mais de um) no cliente da Carteira, e a escolha de `cartao_hash` (SHA-256) em vez de armazenar identificador do cartão. Nenhuma dessas é transversal o bastante para exigir ADR, mas todas mereciam uma DD com alternativas e trade-offs.
**Impacto:** Decisões de latência e resiliência ficam sem justificativa registrada, dificultando revisão futura e reabertura de discussão se o orçamento de 300 ms for estourado em produção.
**Correção recomendada:** Registrar ao menos DD-001 (partição de timeout entre Tarifação e Carteira) e DD-002 (retry único na Carteira, sem retry na Tarifação) com contexto, alternativas e impacto.

### [MEDIUM-01] Catálogo de erros não cobre falha de dependência externa

**Local:** Seção "Catálogo de Erros" — apenas `VAL-ERR-001` (negado) e `VAL-ERR-002` (linha desconhecida).
**Problema:** Não há código de erro para timeout/indisponibilidade da Carteira ou da Tarifação (cenário citado na própria seção de Riscos: "Carteira indisponível no pico"), nem para falha do circuit breaker aberto.
**Impacto:** O comportamento do validador nesse cenário fica implícito; sem código de erro dedicado, é difícil distinguir no monitoramento "negado por saldo" de "negado por indisponibilidade downstream".
**Correção recomendada:** Adicionar `VAL-ERR-003` (dependência indisponível / circuit breaker aberto) com status HTTP e ação recomendada (ex.: modo offline do validador).

## Matriz de Rastreabilidade

| Requirement | Contraparte no Design | Status |
|-------------|------------------------|--------|
| — | — | Não verificável — `requirements.md` inexistente |

Não é possível preencher esta matriz. A rastreabilidade só pode ser avaliada requisito a requisito contra um `requirements.md` real; contra o PRD (que é intencionalmente de alto nível) qualquer mapeamento seria especulativo.

## Checks Executados

| Check | Resultado |
|-------|-----------|
| Tamanho até 3.000 linhas | OK (128 linhas) |
| Estrutura obrigatória | OK — todas as seções presentes, com "Não aplicável" onde cabível |
| Metadados e versionamento | Falhou — status "Aprovado para desenvolvimento" sem requirements; referência a requirements inexistente |
| Rastreabilidade requirements → design | Falhou — `requirements.md` ausente, checagem impossível |
| Clean Architecture | OK — camadas nomeadas corretamente, sem violação aparente |
| DDD tático | OK — aggregate `Embarque`, VO `Money`, state machine e evento no passado (`EmbarqueLiberado`) |
| Application Layer | OK — command/query separados, idempotência por `leitura_id` |
| Infrastructure Layer | OK — timeouts e circuit breaker no cliente da Tarifação; retry limitado na Carteira; outbox |
| Persistência e schema | OK — `tenant_id`, índice para consulta por cartão, dinheiro em centavos (ADR-0002) |
| API Contracts | OK — único endpoint com auth, request/response e erros associados |
| AsyncAPI / Eventos | OK — envelope com versão, correlação, causação, idempotency key, DLQ |
| Segurança e LGPD | OK — mTLS, cartão só por hash, sem PII declarado |
| Observabilidade | OK — logs estruturados, correlação, métrica de latência e alerta de p95 |
| Catálogo de erros | Falhou — não cobre indisponibilidade de dependência (ver HIGH/MEDIUM) |
| Testes | OK — domínio, aplicação, contrato, arquitetura e carga cobertos |
| Multi-tenancy | OK — `tenant_id` em tabela e envelope de evento |
| Performance e escalabilidade | OK — meta de 300 ms, cache de tarifa na borda |
| Diagramas Mermaid | Falhou — falta C4 Level 2 e sequence diagram do fluxo crítico |
| Decisões DD-NNN | Falhou — decisões técnicas relevantes sem DD registrada |
| Riscos | OK — risco de indisponibilidade da Carteira com mitigação |
| Definition of Done | OK — cobre requisitos, testes, contratos, observabilidade (mas "requisitos implementados" não tem o que referenciar sem requirements.md) |
| README sincronizado | OK — README do módulo já sinaliza corretamente que o requirements não existe |

## Recomendações para o design-writer

1. Não gerar `design.md` com status "Aprovado para desenvolvimento" quando não há `requirements.md`; use "Rascunho" e referencie explicitamente o PRD como base, nunca um requirements que não existe.
2. Depois que o PO publicar `requirements.md`, reconciliar cada requisito funcional/RNF/PBT com o design já escrito, preenchendo a matriz de rastreabilidade — muito provavelmente sem reescrever o design do zero, já que a arquitetura proposta é sólida.
3. Adicionar C4 Level 2, sequence diagram do fluxo de embarque, DDs para as decisões de timeout/retry, e um código de erro para indisponibilidade de dependência.

## Decisão para o Pipeline

- Pode seguir para `tasks.md`: Não
- Requer nova execução do `design-writer`: Sim (após o requirements existir; correções de cabeçalho podem ser feitas antes)
- Requer nova ADR: Não
- Requer ajuste no `requirements.md`: Não aplicável — o requirements ainda precisa ser criado pelo PO, não ajustado
