# Validação do tasks.md — Módulo Recarga (RCG)

## Resultado

Status: Reprovado

Resumo:
- Total de achados BLOCKER: 1
- Total de achados HIGH: 0
- Total de achados MEDIUM: 1
- Total de achados LOW: 0

## Veredito

`design.md` não existe em `docs/product/modules/recarga/`. Conforme minha missão, quando `requirements.md` ou `design.md` não existem eu registro **bloqueio crítico** — não posso validar rastreabilidade de tasks contra um design que não foi escrito, e não posso substituir essa ausência aprovando o plano só contra `requirements.md`. Isso não é uma recomendação que eu esteja em posição de flexibilizar: é a definição do meu escopo de validação.

Também não vou editar `tasks.md` nem criar `docs/product/modules/recarga/design.md`. Meu conjunto de ferramentas é somente leitura (Read, Glob, Grep) e minha missão explicitamente diz que eu audito e aponto problemas — não reescrevo o documento, não crio design técnico novo, e um dos anti-patterns que devo detectar é exatamente "TASK virando design técnico tardio" / design escrito a partir das tasks para fechar rastreabilidade artificialmente. Um `design.md` derivado do `tasks.md` inverteria a ordem do pipeline (requirements → design → tasks) e produziria um documento que só existe para o meu próprio checklist passar, sem nenhuma decisão de design real por trás — isso é o problema, não a correção dele.

O próprio projeto já reconhece isso: o `README.md` do módulo lista `design.md` como "Em elaboração pelo design-writer (previsão 2026-09-30)", e o próprio `tasks.md` (Histórico de Versões) registra que foi gerado "com design ainda não disponível". O plano foi corretamente versionado como `0.1.0` / `Rascunho para revisão` — ele nunca foi declarado pronto para aprovação definitiva.

Pressão de prazo de sprint não é critério de aprovação técnica. A saída correta aqui é o pipeline correto: aguardar o `design-writer` (ou antecipar sua entrega) e então rodar novamente a validação — não aprovar sem base, nem eu fabricar a base que falta.

## Achados

### [BLOCKER-01] `design.md` inexistente — plano não pode ser validado contra design

**Local:** `docs/product/modules/recarga/` (arquivo ausente); referenciado em `tasks.md` linha 6 ("Base: requirements.md v1.0.0", sem menção a `design.md`) e em `README.md` linha 6.
**Problema:** O módulo não possui `design.md`. Minhas fontes obrigatórias são `requirements.md` **e** `design.md`; sem o segundo, itens de origem que só o design.md carrega — contratos de API detalhados, schema/migrations, catálogo de erros, decisões técnicas (DD-NNN), riscos de design, estratégia de observabilidade — não têm como ser conferidos contra as TASKs. `TASK-02` já materializa decisões de design (`POST /v1/recargas`, forma de tratar `Idempotency-Key`) que não foram aprovadas em nenhum artefato de design.
**Impacto:** Aprovar tasks sem design aprovado permite que decisões técnicas entrem no pipeline de execução sem revisão de design, favorecendo retrabalho quando o design-writer entregar um design divergente do que o tasks-writer já assumiu implicitamente.
**Correção recomendada:** Aguardar a entrega de `docs/product/modules/recarga/design.md` pelo `design-writer` (ou antecipar essa entrega, dado o prazo de sprint) e então reenviar `tasks.md` para nova validação. Não usar `tasks.md` como substituto de `design.md`.

### [MEDIUM-01] TASK-02 antecipa decisões de design sem registro formal

**Local:** TASK-02, campo "Entregável" (linha 64) e subtask 2.3 (linha 70).
**Problema:** A forma de expor `POST /v1/recargas`, o uso de `Idempotency-Key` como header e a existência de "teste de contrato" pressupõem decisões de design (formato de contrato, versionamento de API) que deveriam estar documentadas em `design.md`, não inferidas a partir do requirements.
**Impacto:** Se o design formal divergir (ex.: outro path, outro mecanismo de idempotência), TASK-02 precisará ser reescrita, gerando retrabalho e possível PR já em andamento incompatível com o design aprovado.
**Correção recomendada:** Quando o `design-writer` entregar `design.md`, confirmar que o contrato de `TASK-02` está alinhado; se houver divergência, o `tasks-writer` deve ajustar a TASK antes da execução.

## Matriz de Rastreabilidade

| Origem | TASKs | Status |
|--------|-------|--------|
| Req 1 | TASK-02 | OK (contra requirements; não verificável contra design — ausente) |
| Req 2 | TASK-03 | OK (contra requirements; não verificável contra design — ausente) |
| RNF 1 | TASK-02 | OK (contra requirements; não verificável contra design — ausente) |
| PBT-01 | TASK-02 | OK |
| ADR-0001 | TASK-01 | OK |
| ADR-0002, ADR-0003 (citadas no cabeçalho) | Nenhuma TASK | Falhou — citadas como "ADRs aplicáveis" mas não mapeadas em nenhuma TASK |
| Contratos de API detalhados, schema/migrations, catálogo de erros, DD-NNN (fontes obrigatórias do design.md) | — | Não verificável — `design.md` inexistente |

## Checks Executados

| Check | Resultado |
|-------|-----------|
| Tamanho até 3.000 linhas | OK (123 linhas) |
| Estrutura obrigatória | OK |
| Metadados e versionamento | OK (0.1.0, Rascunho para revisão, coerente com o estágio) |
| Referência a requirements/design | Falhou — `design.md` não referenciado nem existe |
| Rastreabilidade completa | Falhou — não verificável integralmente sem design.md; ADR-0002/0003 sem TASK |
| Status Geral sincronizado | OK |
| Ondas de implementação | OK |
| Formato das TASKs | OK |
| Tamanho das TASKs/subtasks | OK |
| TDD-first | OK (Red/Green presentes em todas as TASKs com lógica) |
| PBTs mapeados | OK (PBT-01 → TASK-02) |
| Branch/worktree/commits | OK |
| Critérios de aceite | OK |
| Coverage gates | OK (Domain 95%+, Api 80%+, Architecture 100%) |
| Dependências | OK (TASK-01 → TASK-02 → TASK-03, sem ciclo) |
| Segurança e observabilidade | Não verificado — depende do design.md para saber o que é crítico neste módulo |
| API/eventos/persistência/erros | Não verificável — catálogo de erros e contrato formal vivem no design.md |
| Critérios de encerramento | OK |
| README sincronizado | OK — README já reflete corretamente a ausência de design.md e a previsão de entrega |

## Recomendações para o tasks-writer

1. Não ressubmeter `tasks.md` para aprovação definitiva antes de `design.md` existir; manter status `Rascunho para revisão` até lá.
2. Ao receber `design.md` do `design-writer`, atualizar o cabeçalho de `tasks.md` com "Base: design.md vX.Y.Z" e revisar TASK-02 (e qualquer TASK futura de API) contra o contrato formal.
3. Mapear ADR-0002 e ADR-0003 (hoje citadas apenas no cabeçalho) a TASKs específicas, ou remover a referência se não se aplicarem a este módulo.

## Decisão para o Pipeline

- Pode seguir para execução: Não
- Requer nova execução do `tasks-writer`: Não (o `tasks.md` atual é consistente com o requirements disponível; o problema é a ausência de `design.md`, não um defeito de decomposição)
- Requer ajuste no `design.md`: Sim — precisa ser criado pelo `design-writer` antes que este `tasks.md` possa ser aprovado
- Requer ajuste no `requirements.md`: Não
