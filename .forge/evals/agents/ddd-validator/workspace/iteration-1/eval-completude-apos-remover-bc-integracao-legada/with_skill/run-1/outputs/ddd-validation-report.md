# DDD Validation Report - Embarque Fácil

**Produto:** Embarque Fácil
**Versão do Relatório:** v1.1
**Data:** 2026-09-28
**Status:** Final
**Artefatos Validados:** Subdomínios, Bounded Contexts, Context Map, Glossário, Modules, Data Model, C4 — validação focada em completude documental (Passo 13) após remoção do BC-05 Integração Legada.

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Criação inicial do relatório de validação DDD (re-execução pós-remoção de BC-05) |
| v1.1 | 2026-09-28 | Reexecução: acrescenta a Tabela de Completude Documental e a tabela de Estrutura e Visualização exigidas pelo Passo 13.4 do protocolo, ausentes na v1.0; parecer e achados mantidos, sem alteração de fato |

---

## Sumário Executivo

### Parecer Final

**Reprovado**

### Síntese

A segmentação em `ddd-segmentation.md` já reflete corretamente a decisão do comitê de remover o BC-05 (Integração Legada), com a linha riscada e justificativa registrada. Porém a documentação física em `docs/product/ddd/` não foi atualizada para acompanhar essa decisão nem para completar o que a matriz já exigia antes dela: (1) o bounded context BC-04 Notificações está com decisão "Confirmar como Generic" mas não tem README físico; (2) o diretório `bounded-contexts/integracao-legada/` continua existindo com conteúdo tachado, um artefato órfão não removido após a decisão do comitê; (3) falta `docs/product/ddd/diagrams/index.html`, artefato de visualização obrigatório do `ddd-architect`. Pela regra de impacto no parecer (Passo 13.5) do próprio validador, a existência de README com `~~strikethrough~~` não removido e a ausência de qualquer artefato estrutural (aqui, o `index.html`) bloqueiam **Aprovado com Ressalvas** — o caso força **Reprovado**, mesmo sendo pendências pequenas em volume.

### Principais Riscos

- Gerar módulos/backlog a partir de uma segmentação com órfão não limpo pode reintroduzir o bilhete magnético via código ou automação que ainda referencia `integracao-legada`.
- Ausência do README de Notificações deixa o `ddd-architect` (ou quem gerar módulos) sem contrato de linguagem própria e ownership para esse BC, arriscando um módulo "notificacoes" criado sem base documental — o módulo e o deployable já constam em `docs/product/modules/README.md` antes de o BC ter README próprio.
- Falta de `index.html` quebra a visualização C4 esperada como entrega obrigatória — consumidores humanos do C4 não têm o artefato navegável.

### Principais Recomendações

- Remover (ou arquivar formalmente) `docs/product/ddd/bounded-contexts/integracao-legada/`, mediante validação humana explícita da remoção do diretório (o validador não apaga bounded context sem essa validação — ver §4.2 do agente).
- Gerar `docs/product/ddd/bounded-contexts/notificacoes/README.md` na próxima execução do `ddd-architect`, cobrindo objetivo, linguagem, regras, ownership/stateless e fora de escopo.
- Gerar `docs/product/ddd/diagrams/index.html` (visualização C4 navegável) na próxima execução do `ddd-architect`.

---

## 1. Documentos Avaliados

| Documento | Caminho | Status |
|---|---|---|
| PRD | docs/product/prd/prd.md | Encontrado |
| FRD | docs/product/frd-nfrd/frd.md | Encontrado |
| NFRD | docs/product/frd-nfrd/nfrd.md | Encontrado |
| TRD | docs/product/trd/trd.md | Encontrado |
| ADRs | docs/product/adr/ | Encontrado (0001-grpc-comunicacao-interna, 0002-schema-por-contexto) |
| Segmentation | docs/product/ddd/ddd-segmentation.md | Encontrado |
| Subdomínios | docs/product/ddd/subdomains/ | Encontrado (5/5) |
| Bounded Contexts | docs/product/ddd/bounded-contexts/ | Encontrado (4 diretórios; 1 órfão riscado, 1 faltando) |
| Context Map | docs/product/ddd/context-map/README.md | Encontrado |
| Ubiquitous Language | docs/product/glossary/ubiquitous-language.md | Encontrado |
| Domain Glossary | docs/product/glossary/domain-glossary.md | Encontrado |
| Modules | docs/product/modules/README.md | Encontrado |
| Data Model | docs/product/data-model/data-model.md | Encontrado |
| Diagramas C4 | docs/product/ddd/diagrams/ | Encontrado parcial (3 .md; falta index.html) |

---

## 2. Validação Problema x Solução

| Item | Tipo Declarado | Tipo Correto | Status | Observação |
|---|---|---|---|---|
| validacao-embarque, carteira-digital, recarga, conformidade-pci, notificacoes | Subdomínio | Subdomínio | OK | Refletem o que o negócio faz (PRD §Diferencial, §Jornadas), não organização de código. |
| validacao, carteira, recarga, notificacoes (BC) | Bounded Context | Bounded Context | OK | Fronteiras conceituais da solução, cada um com linguagem própria (exceto Notificações, sem README — ver §5). |
| validacao, carteira, recarga, notificacoes, bff-app (Módulo) | Módulo | Módulo | OK | Módulos derivam corretamente de BC/deployable; nenhum caso de tabela ou tela tratada como bounded context. |
| validacao-svc, carteira-svc, recarga-svc, notificacoes-svc, bff-app (Deployable) | Deployable | Deployable | OK | Um deployable por bounded context, coerente com TRD; nenhum microsserviço por tabela. |

---

## 3. Validação de Subdomínios

| Subdomínio | Classificação Atual | Classificação Recomendada | Status | Justificativa |
|---|---|---|---|---|
| Validação de Embarque | Core | Core | OK | Diferenciação estratégica clara (tarifação + integração temporal + operação offline), com evidência em PRD §Diferencial, FR-01, FR-02. |
| Carteira Digital | Supporting | Supporting | OK | Apoia o core (débito de tarifa) sem ser o diferencial (FR-03). |
| Recarga | Supporting | Supporting | OK | Apoia o core via crédito de saldo (FR-04); não é o diferencial. |
| Conformidade PCI | Generic | Generic | OK | Tokenização terceirizada em provedor certificado, commodity regulatória (NFR-03). |
| Notificações | Generic | Generic | OK | Push commodity (FR-05); não exige conhecimento de domínio especializado. |

Nenhuma correção necessária nesta seção; todos os 5 subdomínios da matriz têm README físico correspondente (ver §13 abaixo).

---

## 4. Validação do Event Storming

| Fluxo | Item | Tipo | Problema | Status | Recomendação |
|---|---|---|---|---|---|
| J2 | RegistrarEmbarque | Comando | Nenhum | OK | Imperativo correto. |
| J2 | EmbarqueRegistrado | Evento | Nenhum | OK | Passado correto; produtor canônico (Validação) explícito; consumido por Carteira. |
| J2 | DebitarTarifa | Comando | Nenhum | OK | Imperativo correto. |
| J2 | TarifaDebitada | Evento | Nenhum | OK | Passado correto; produtor canônico (Carteira); consumido por Notificações. |
| J1 | ConfirmarRecarga | Comando | Nenhum | OK | Imperativo correto. |
| J1 | RecargaConfirmada | Evento | Nenhum | OK | Passado correto; produtor canônico (Recarga); consumido por Carteira. |
| J1 | CreditarSaldo | Comando | Nenhum | OK | Imperativo correto. |
| J1 | SaldoCreditado | Evento | Nenhum | OK | Passado correto; produtor canônico (Carteira); consumido por Notificações. |

Todos os comandos estão no imperativo e todos os eventos no passado; nenhum evento compartilhado carece de produtor canônico ou de versionamento (todos marcados v1 no context map).

---

## 5. Validação de Bounded Contexts

| Bounded Context | Linguagem Própria | Regras Próprias | Ciclo de Vida | Ownership | Integrações | Decisão |
|---|---|---|---|---|---|---|
| Validação (validacao) | Sim | Sim | Sim | Sim (schema `validacao`) | Sim | OK |
| Carteira (carteira) | Sim | Sim | Sim | Sim (schema `carteira`) | Sim | OK |
| Recarga (recarga) | Sim | Sim | Sim | Sim (schema `recarga`) | Sim | OK |
| Notificações (notificacoes) | Não | Não | Não | Não | Não | **Ponto a Validar — README ausente apesar de decisão "Confirmar como Generic" na matriz (FIND-DDD-COMPL-BC-01)** |
| ~~Integração Legada~~ (integracao-legada) | — | — | — | — | — | **Ponto a Validar — diretório órfão, decisão de remoção não refletida no filesystem (FIND-DDD-COMPL-ORPH-01)** |

Observação: a leitura tática dos READMEs de Validação/Carteira/Recarga não indicou nenhuma inconsistência (linguagem, regras e fora de escopo declarados de forma consistente com o context map e o data model).

---

## 6. Validação do Context Map

| Origem | Destino | Padrão Atual | Padrão Recomendado | Status | Justificativa |
|---|---|---|---|---|---|
| Validação | Carteira | Published Language | Published Language | OK | Evento `EmbarqueRegistrado` versionado (v1). |
| Recarga | Carteira | Published Language | Published Language | OK | Evento `RecargaConfirmada` versionado (v1). |
| Carteira | Notificações | Published Language | Published Language | OK | Eventos `TarifaDebitada`/`SaldoCreditado` versionados (v1); porém Notificações ainda não tem README — ver §5. |
| Provedor Pix (externo) | Recarga | Anti-Corruption Layer | Anti-Corruption Layer | OK | Uso correto de ACL para sistema externo instável (PSP), coerente com FR-04. |

Nenhuma relação residual aponta para Integração Legada — o context map já está limpo dessa dependência, coerente com a segmentação. Todos os 4 bounded contexts confirmados (incluindo Notificações, mesmo sem README) aparecem no context map.

---

## 7. Validação da Linguagem Ubíqua

| Termo | Contexto | Problema | Status | Recomendação |
|---|---|---|---|---|
| Embarque, Janela de Integração | Validação | Nenhum | OK | Definidos em `ubiquitous-language.md`, alinhados a FR-01/FR-02. |
| Saldo, Movimentação | Carteira | Nenhum | OK | Definidos, em centavos, coerente com NFR-02 (imutabilidade). |
| Recarga | Recarga | Nenhum | OK | Definida, alinhada a FR-04. |
| Notificações (seção própria) | Notificações | Ausente | **Revisar** | Não há seção "Notificações" em `ubiquitous-language.md` — consequência direta da ausência do README do BC (§5); adicionar quando o `ddd-architect` gerar o README. |

Não há uso de "VO" em português nem termo com dois significados sem separação por contexto nos artefatos revisados.

---

## 8. Validação de Ownership de Dados

| Dado | Dono Atual | Problema | Status | Recomendação |
|---|---|---|---|---|
| embarque, janela_integracao | Validação (schema `validacao`) | Nenhum | OK | Dono único, coerente com ADR-0002. |
| carteira, movimentacao | Carteira (schema `carteira`) | Nenhum | OK | Dono único; Notificações consome via evento, não lê a tabela diretamente. |
| recarga | Recarga (schema `recarga`) | Nenhum | OK | Dono único. |
| dados de notificação (push) | Não declarado | Ownership implícito, sem tabela no data model nem README do BC | **Revisar** | Registrar em `data-model.md` e no README de Notificações se há estado persistido (ex.: histórico de push) ou se o BC é stateless. |

Nenhum join direto entre schemas nem tabela global compartilhada identificada; ADR-0002 (schema por contexto) está sendo seguida pelos 3 bounded contexts com README.

---

## 9. Validação de Módulos e Deployables

| Item | Tipo Atual | Problema | Status | Recomendação |
|---|---|---|---|---|
| validacao / validacao-svc | Módulo / Deployable | Nenhum | OK | Deriva de bounded context com README completo. |
| carteira / carteira-svc | Módulo / Deployable | Nenhum | OK | Deriva de bounded context com README completo. |
| recarga / recarga-svc | Módulo / Deployable | Nenhum | OK | Deriva de bounded context com README completo. |
| notificacoes / notificacoes-svc | Módulo / Deployable | Módulo e deployable já projetados a partir de um bounded context sem README próprio | **Ponto a Validar** | Não gerar (ou revalidar) o módulo/deployable de Notificações até o README do bounded context existir — rastreabilidade invertida (ver §12). |
| bff-app | Frontend/BFF | Nenhum | OK | Classificado corretamente como BFF, não como bounded context. |

---

## 10. Validação DDD Tático

Não aplicável nesta execução — os insumos revisados não contêm especificação de entidades, objetos de valor ou agregados (nenhum modelo de domínio tático em `docs/product/ddd/` ou `data-model.md` além do mapeamento tabela → dono).

---

## 11. Validação de Diagramas C4

| Diagrama | Problema | Status | Recomendação |
|---|---|---|---|
| C4 Level 1 | Nenhum | OK | Mostra sistema, atores (Passageiro) e sistemas externos (Provedor Pix, Cofre de Tokenização); Mermaid válido. |
| C4 Level 2 | Nenhum | OK | Mostra os 5 containers/deployables coerentes com o TRD (bff-app, validacao-svc, carteira-svc, recarga-svc, notificacoes-svc). |
| C4 Level 3 | Nenhum | OK | Detalha módulo crítico (validacao-svc: Calculadora de Tarifa, Janela de Integração), coerente com FR-01/FR-02. |

A validação item a item dos 3 diagramas Markdown está coberta acima; a ausência do artefato de visualização (`index.html`) é tratada como achado estrutural obrigatório no Passo 13 (§13.3) e na Tabela de Completude Documental abaixo, não repetida nesta seção para evitar duplicidade de achado.

---

## 12. Validação de Rastreabilidade

| Decisão DDD | Evidência | Status | Observação |
|---|---|---|---|
| Validação de Embarque como Core | PRD §Diferencial, FR-01, FR-02 | OK | Evidência direta e explícita. |
| Carteira e Recarga como Supporting | FR-03, FR-04 | OK | Apoiam o core sem serem o diferencial. |
| Conformidade PCI e Notificações como Generic | NFR-03, FR-05 | OK | Commodity/terceirizável, coerente com os critérios do Passo 3. |
| Remoção do BC-05 Integração Legada | ADR ausente; decisão registrada apenas na segmentação (linha riscada, data 2026-09-10) | **Ponto a Validar** | Decisão de arquitetura relevante (descontinuação de bilhete magnético) sem ADR formal — recomenda-se `adr-writer` para registrar a remoção e a data de corte de outubro. |
| BC-04 Notificações "Confirmar como Generic" | Segmentação §4.1 | **Revisar** | Decisão existe na matriz mas não tem artefato físico correspondente (README) — rastreabilidade incompleta até o README ser criado. |
| Módulo notificacoes / deployable notificacoes-svc | docs/product/modules/README.md, docs/product/trd/trd.md | **Revisar** | Módulo e deployable já foram projetados a partir de um BC que ainda não tem README — ordem de geração invertida (ver §9). |

---

## 13. Validação de Completude Documental

Cruzamento da matriz de `docs/product/ddd/ddd-segmentation.md` com o filesystem em `docs/product/ddd/`, conforme Passo 13 do protocolo.

### 13.1 Completude de READMEs

**Subdomínios (§1.2 da matriz):** as 5 linhas (`validacao-embarque` Core, `carteira-digital` Supporting, `recarga` Supporting, `conformidade-pci` Generic, `notificacoes` Generic) têm README físico correspondente em `subdomains/<tipo>/<slug>/README.md`. Nenhuma ausência.

**Bounded Contexts (§4.1 da matriz):** das 5 linhas, 4 têm decisão `Confirmar`/`Confirmar como Generic` (`validacao`, `carteira`, `recarga`, `notificacoes`) e 1 está riscada (`~~BC-05~~ integracao-legada`, ignorada por regra explícita do Passo 13.1). Dos 4 esperados, 3 têm README (`validacao`, `carteira`, `recarga`) e 1 não tem (`notificacoes`) → achado **Alto** `FIND-DDD-COMPL-BC-01`.

**Excedente/Órfãos:** o diretório `bounded-contexts/integracao-legada/` existe no filesystem com README fisicamente presente (conteúdo `~~riscado~~`), sem linha ativa correspondente na matriz (a linha existe, mas riscada/removida) → achado **Médio** `FIND-DDD-COMPL-ORPH-01`, recomendando remoção ou arquivamento formal do diretório.

### 13.2 Estrutura mínima de diretórios

Todos presentes: `subdomains/core/`, `subdomains/supporting/`, `subdomains/generic/`, `bounded-contexts/`, `context-map/`, `diagrams/`. Nenhum achado.

### 13.3 Artefatos de visualização

Os 3 arquivos C4 Markdown (`c4-level-1-system-context.md`, `c4-level-2-containers.md`, `c4-level-3-components.md`) estão presentes. O arquivo `diagrams/index.html` está ausente → achado **Alto** `FIND-DDD-COMPL-VIZ-01`.

### Tabela de Completude Documental

| Tipo | Esperado (matriz) | Encontrado (filesystem) | Faltando | Excedente |
|---|---|---|---|---|
| Subdomínios Core | 1 | 1 | `[]` | `[]` |
| Subdomínios Supporting | 2 | 2 | `[]` | `[]` |
| Subdomínios Generic | 2 | 2 | `[]` | `[]` |
| Bounded Contexts (`Confirmar`) | 4 | 3 | `[notificacoes]` | `[]` (integracao-legada é órfão riscado, tratado em §13.1, não como excedente de linha ativa) |

### Estrutura e Visualização

| Artefato | Esperado | Presente? |
|---|---|---|
| `subdomains/{core,supporting,generic}/` (dirs) | Sim | Sim |
| `bounded-contexts/` (dir) | Sim | Sim |
| `context-map/README.md` | Sim | Sim |
| `diagrams/c4-level-1-system-context.md` | Sim | Sim |
| `diagrams/c4-level-2-containers.md` | Sim | Sim |
| `diagrams/c4-level-3-components.md` | Sim | Sim |
| `diagrams/index.html` | Sim | **Não** |

### 13.5 Impacto no parecer (aplicação da regra)

- `Faltando > 0` está restrito a Bounded Contexts (`notificacoes`) — não há subdomínio faltando — condição necessária, mas não suficiente, para "Aprovado com Ressalvas".
- Um artefato estrutural obrigatório está ausente (`diagrams/index.html`) — isso por si só bloqueia "Aprovado com Ressalvas" (Passo 13.5 exige todos os artefatos estruturais presentes).
- Existe README físico com `~~strikethrough~~` não removido (`integracao-legada`) — isso também, isoladamente, força **Reprovado** por regra explícita do Passo 13.5.

Conclusão desta seção: **Reprovado**, por duas causas independentes e suficientes cada uma isoladamente (artefato estrutural ausente + órfão riscado não removido), não apenas pela ausência de um README de bounded context.

---

## 14. Ajustes Aplicados

Nenhum. Todos os achados desta execução exigem decisão humana (remoção de bounded context, geração de novo README, registro de ADR) e, por regra do agente (§4.2), não podem ser corrigidos diretamente pelo validador.

| ID | Artefato | Ajuste | Fonte |
|---|---|---|---|
| — | — | Nenhuma correção direta aplicável nesta execução | — |

---

## 15. Conflitos Arquiteturais

Nenhum conflito entre PRD/FRD/NFRD/TRD/ADR identificado nesta execução.

---

## 16. Pontos a Validar

| Código | Ponto | Impacto | Recomendação |
|---|---|---|---|
| VAL-DDD-01 | Remoção física do diretório `bounded-contexts/integracao-legada/` | Bloqueia Aprovado/Aprovado com Ressalvas por regra explícita (Passo 13.5) | Validação humana da remoção; após aprovada, apagar o diretório e reexecutar validação |
| VAL-DDD-02 | Geração do README de `bounded-contexts/notificacoes/` | Bloqueia rastreabilidade do módulo já projetado (§9, §12) | Executar `ddd-architect` para esse BC antes de prosseguir com geração de módulos |
| VAL-DDD-03 | Geração de `diagrams/index.html` | Falta artefato de visualização obrigatório | Executar `ddd-architect` (etapa de visualização C4) |
| VAL-DDD-04 | ADR para remoção do BC-05 | Decisão relevante (descontinuação do bilhete magnético) sem registro formal | Acionar `adr-writer` |
| VAL-DDD-05 | Ownership de dados de Notificações | Sem tabela no data model nem declaração de stateless | Esclarecer no README do BC quando ele for gerado |

---

## 17. Métricas da Validação

| Métrica | Quantidade |
|---|---|
| Subdomínios avaliados | 5 |
| Bounded contexts avaliados | 5 (4 confirmados + 1 removido/órfão) |
| Relações de context map avaliadas | 4 |
| Módulos avaliados | 5 |
| Eventos avaliados | 4 |
| Achados críticos | 0 |
| Achados altos | 2 |
| Achados médios | 1 |
| Achados baixos | 0 |
| Ajustes aplicados | 0 |
| Pontos a validar | 5 |

---

## 18. Parecer Final

### Classificação

**Reprovado**

### Justificativa

A pendência não é grande em volume, mas duas condições batem diretamente nos critérios de bloqueio do Passo 13.5 do próprio protocolo do `ddd-validator`, cada uma suficiente isoladamente: (1) existe um README físico com `~~strikethrough~~` não removido após a decisão do comitê (`integracao-legada`), o que por regra força Reprovado independentemente do restante; e (2) falta um artefato estrutural obrigatório (`diagrams/index.html`), o que também força Reprovado por regra, já que "Aprovado com Ressalvas" exige todos os artefatos estruturais presentes. Adicionalmente, falta o README de um bounded context confirmado na matriz (Notificações), e um módulo/deployable já foi projetado a partir desse BC antes de ele existir como documento — uma inversão de ordem que a rastreabilidade não sustenta. Não há, porém, nenhum achado crítico, confusão estratégica entre problema/solução, ou ownership de dados inseguro: a arquitetura em si está sólida — validada nas seções 2 a 12 sem nenhum achado Alto ou Crítico fora dos três já citados — e o gap é de higiene documental.

Recomendo **não aprovar com ressalvas** apesar da pressa relatada, porque a combinação órfão-não-removido + artefato estrutural ausente é exatamente o caso que o protocolo qualifica como bloqueante, não como ressalva. A boa notícia é que o esforço de correção é pequeno e mecânico (um `ddd-architect` para dois READMEs e um HTML, mais um ADR), não uma redefinição de arquitetura.

### Condições para Aprovação

- Remover (com validação humana) ou mover para arquivo o diretório `bounded-contexts/integracao-legada/`
- Gerar `bounded-contexts/notificacoes/README.md`
- Gerar `diagrams/index.html`
- Registrar ADR para a remoção do BC-05

### Próximos Passos

- Corrigir os 2 achados Altos e 1 Médio listados em §13
- Validar os 5 pontos pendentes em §16 com produto/arquitetura
- Registrar ADR da remoção do BC-05
- Reexecutar o `ddd-validator` após os ajustes
