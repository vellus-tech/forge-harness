# DDD Validation Report - Embarque Fácil

**Produto:** Embarque Fácil — bilhetagem digital do consórcio metropolitano de ônibus
**Versão do Relatório:** v1.0
**Data:** 2026-09-26
**Status:** Final
**Artefatos Validados:** Subdomínios, Bounded Contexts, Context Map, Glossário, Modules, Data Model, C4

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Criação inicial do relatório de validação DDD |

---

## Sumário Executivo

### Parecer Final

Reprovado

### Síntese

A segmentação estratégica (subdomínios, bounded contexts, context map, linguagem ubíqua) está bem fundamentada e rastreável ao PRD/FRD/NFRD, e a completude documental está 100% cumprida (nenhum README, diretório estrutural ou artefato C4 faltando). Duas correções seguras de nomenclatura foram aplicadas diretamente. Porém o data model contém uma escrita cruzada entre contextos — a tabela `carteira` do schema `carteira` (owned pela Carteira) tinha a Recarga como segundo dono de escrita via UPDATE direto de `saldo` — corrigida nesta validação por já haver fluxo de evento equivalente definido no FRD e no Event Storming. Um segundo problema, estrutural e não corrigível sem decisão de arquitetura, permanece aberto: o relatório de conciliação de recargas faz `JOIN` direto entre os schemas `recarga` e `carteira`, o que contraria explicitamente o ADR-0002 ("joins entre schemas são proibidos"). Por haver um achado Crítico ainda não resolvido, a modelagem não deve seguir para derivação de módulos/backlog sem antes fechar esse ponto.

### Principais Riscos

- Sem uma solução de leitura conforme ADR-0002 para a conciliação, o time de implementação tende a manter (ou recriar) o join direto entre schemas, quebrando o isolamento de dados por contexto.
- A correção aplicada ao data model remove uma otimização de latência mencionada no artefato original; se essa necessidade de latência for real (não documentada no NFRD), pode haver impacto de produto não capturado aqui.

### Principais Recomendações

- Definir, via ADR ou desenho de solução, o mecanismo de leitura para a conciliação diária (read model próprio de Recarga alimentado por eventos, ou consulta via API/gRPC do serviço Carteira) antes de avançar para módulos/backlog.
- Confirmar com produto/arquitetura se há requisito real de latência para o crédito de recarga que justificaria revisitar o desenho de evento (hoje não há NFR para isso).

---

## 1. Documentos Avaliados

| Documento | Caminho | Status |
|---|---|---|
| PRD | docs/product/prd/prd.md | Encontrado |
| FRD | docs/product/frd-nfrd/frd.md | Encontrado |
| NFRD | docs/product/frd-nfrd/nfrd.md | Encontrado |
| TRD | docs/product/trd/trd.md | Encontrado |
| ADRs | docs/product/adr/ | Encontrado (ADR-0001, ADR-0002) |
| Segmentation | docs/product/ddd/ddd-segmentation.md | Encontrado |
| Subdomínios | docs/product/ddd/subdomains/ | Encontrado |
| Bounded Contexts | docs/product/ddd/bounded-contexts/ | Encontrado |
| Context Map | docs/product/ddd/context-map/README.md | Encontrado |
| Ubiquitous Language | docs/product/glossary/ubiquitous-language.md | Encontrado |
| Domain Glossary | docs/product/glossary/domain-glossary.md | Encontrado |
| Modules | docs/product/modules/ | Encontrado |
| Data Model | docs/product/data-model/data-model.md | Encontrado |
| Diagramas C4 | docs/product/ddd/diagrams/ | Encontrado |

---

## 2. Validação Problema x Solução

| Item | Tipo Declarado | Tipo Correto | Status | Observação |
|---|---|---|---|---|
| Validação de Embarque / Carteira Digital / Recarga / Conformidade PCI / Notificações | Subdomínio | Subdomínio | OK | Representam capacidades de negócio, não unidades de deploy. |
| Validação / Carteira / Recarga / Notificações | Bounded Context | Bounded Context | OK | Fronteiras conceituais coerentes com os subdomínios correspondentes. |
| validacao, carteira, recarga, notificacoes, bff-app | Módulo | Módulo | OK | Derivam 1:1 de bounded context, exceto bff-app (cross-cutting de apresentação, aceitável). |
| validacao-svc, carteira-svc, recarga-svc, notificacoes-svc, bff-app | Deployable | Deployable | OK | Um deployable por bounded context é justificado (TRD); não há indício de granularidade artificial. |

---

## 3. Validação de Subdomínios

| Subdomínio | Classificação Atual | Classificação Recomendada | Status | Justificativa |
|---|---|---|---|---|
| Validação de Embarque | Core | Core | OK | Diferenciação clara (PRD §Diferencial), regra própria e complexa (integração temporal + offline), risco de receita/compliance em caso de falha. |
| Carteira Digital | Supporting | Supporting | OK | Apoia o core mas não é o diferencial; saldo pré-pago é padrão do setor. |
| Recarga | Supporting | Supporting | OK | Crédito via Pix apoia a carteira; não é commodity pura nem core. |
| Conformidade PCI | Generic | Generic | OK | Tokenização comprada de provedor certificado (NFR-03); compliance sozinho não promove a Core, corretamente não promovido. |
| Notificações | Generic | Generic | OK | Push é commodity substituível. |

---

## 4. Validação do Event Storming

| Fluxo | Item | Tipo | Problema | Status | Recomendação |
|---|---|---|---|---|---|
| J2 | RegistrarEmbarque → EmbarqueRegistrado | Comando/Evento | Nenhum | OK | Comando no imperativo, evento no passado, produtor único (Validação). |
| J2 | DebitarTarifa → TarifaDebitada | Comando/Evento | Nenhum | OK | Produtor canônico Carteira. |
| J1 | ConfirmarRecarga → RecargaConfirmada | Comando/Evento | O BC Recarga chamava o evento publicado de `ConfirmarRecarga` (imperativo) em vez de `RecargaConfirmada` (passado) | Corrigido | Ver ADJ-DDD-002. Comando e evento já estavam corretos na matriz de Event Storming; o erro estava só no README do bounded context. |
| J1 | CreditarSaldo → SaldoCreditado | Comando/Evento | Nenhum | OK | Produtor canônico Carteira. |

---

## 5. Validação de Bounded Contexts

| Bounded Context | Linguagem Própria | Regras Próprias | Ciclo de Vida | Ownership | Integrações | Decisão |
|---|---|---|---|---|---|---|
| Validação | Sim | Sim | Sim | Sim (schema `validacao`) | Sim (publica `EmbarqueRegistrado`) | OK |
| Carteira | Sim | Sim | Sim | Parcial — ver FIND-DDD-001 | Sim (consome 2, publica 2 eventos) | Revisar → Corrigido |
| Recarga | Sim | Sim | Sim | Sim (schema `recarga`) | Sim (publica evento; ACL para o PSP) | OK |
| Notificações | Parcial (não descreve linguagem própria no README) | Não detalhado | Stateless (justificado) | Stateless | Sim (consome 2 eventos) | Ponto a Validar |

---

## 6. Validação do Context Map

| Origem | Destino | Padrão Atual | Padrão Recomendado | Status | Justificativa |
|---|---|---|---|---|---|
| Validação | Carteira | Published Language | Published Language | OK | Evento versionado, cruza contexto. |
| Recarga | Carteira | Published Language | Published Language | OK | Consistente com FR-04. |
| Carteira | Notificações | Published Language | Published Language | OK | Dois eventos versionados. |
| Provedor Pix (externo) | Recarga | Anti-Corruption Layer | Anti-Corruption Layer | OK | Modelo externo do PSP isolado do domínio. |
| Recarga | Carteira (dado, fora do context map) | Escrita direta em tabela + Join direto | Published Language (evento) / Read Model próprio | Corrigido (escrita) / Ponto a Validar (leitura) | Ver FIND-DDD-001 e FIND-DDD-002 — essas relações de dado não estavam representadas no context map, apenas no data model, o que permitiu a inconsistência passar despercebida. |

---

## 7. Validação da Linguagem Ubíqua

| Termo | Contexto | Problema | Status | Recomendação |
|---|---|---|---|---|
| VO | Carteira (bounded-contexts/carteira/README.md) | Uso de "VO" em documentação pt-BR em vez de "objeto de valor" | Corrigido | Ver ADJ-DDD-003. |
| Saldo | Carteira | Nenhum | OK | Definido no glossário ubíquo, com unidade explícita (centavos). |
| Embarque / Janela de Integração | Validação | Nenhum | OK | Termos com definição clara e específica do contexto. |
| Recarga | Recarga | Nenhum | OK | Termo simples, sem colisão com outro contexto. |

---

## 8. Validação de Ownership de Dados

| Dado | Dono Atual | Problema | Status | Recomendação |
|---|---|---|---|---|
| tabela `carteira` (schema `carteira`) | Carteira e Recarga (antes da correção) | Múltiplos donos de escrita — Recarga fazia UPDATE direto em `saldo`, contrariando FR-03 ("somente a carteira debita ou credita saldo"), FR-04 e ADR-0002 | Corrigido | Ver FIND-DDD-001 / ADJ-DDD-001. Único dono de escrita agora é Carteira; Recarga só publica evento. |
| `recarga.recarga` × `carteira.movimentacao` (relatório de conciliação) | Leitura via JOIN direto entre schemas por `recarga-svc` | Viola ADR-0002 ("Joins entre schemas são proibidos") | Não corrigido — Ponto a Validar | Ver FIND-DDD-002 / VAL-DDD-01 / CONF-DDD-01. Requer decisão de arquitetura sobre o padrão de leitura (read model, evento, ou API). |
| tabela `movimentacao` | Carteira | Nenhum | OK | Dono único, consistente com o agregado. |
| tabela `embarque`, `janela_integracao` | Validação | Nenhum | OK | Dono único. |
| dado sensível (PAN) | Cofre de Tokenização (fora do domínio, NFR-03) | Nenhum | OK | Isolado do modelo de domínio; nenhum bounded context armazena PAN. |

---

## 9. Validação de Módulos e Deployables

| Item | Tipo Atual | Problema | Status | Recomendação |
|---|---|---|---|---|
| validacao, carteira, recarga, notificacoes | Módulo | Nenhum | OK | 1:1 com bounded context, com deployable próprio. |
| bff-app | Módulo/Frontend | Nenhum | OK | Corretamente classificado como BFF, não como bounded context de domínio. |
| validacao-svc, carteira-svc, recarga-svc, notificacoes-svc | Deployable | Nenhum | OK | Justificados operacionalmente (TRD), um por bounded context. |

---

## 10. Validação DDD Tático

| Item | Tipo | Problema | Status | Recomendação |
|---|---|---|---|---|
| `Saldo` (Carteira) | Objeto de Valor | Descrito como "VO" em pt-BR | Corrigido | Ver ADJ-DDD-003. Sem indício de setter público ou mutabilidade — segue as regras de VO. |
| `Carteira` (agregado) | Agregado | Nenhum evidente nos artefatos disponíveis | OK (informação limitada) | Documentação não detalha invariantes nem tamanho do agregado; não há elementos para bloquear, mas recomenda-se detalhar em próxima iteração do `ddd-architect`. |
| `Movimentacao` | Entidade interna | Nenhum | OK | Ciclo de vida vinculado ao agregado Carteira, sem repositório próprio mencionado (correto, pois não é raiz). |
| Eventos (`EmbarqueRegistrado`, `TarifaDebitada`, `RecargaConfirmada`, `SaldoCreditado`) | Evento de Domínio | Nenhum, exceto o nome trocado no README de Recarga (já corrigido) | OK | Todos no passado, com produtor canônico único. |

---

## 11. Validação de Diagramas C4

| Diagrama | Problema | Status | Recomendação |
|---|---|---|---|
| C4 Level 1 | Nenhum | OK | Mostra sistema, ator e sistemas externos (PSP, cofre de tokenização), sem detalhe interno. |
| C4 Level 2 | Nenhum | OK | Containers coerentes com os deployables do TRD/módulos. |
| C4 Level 3 | Nenhum | OK | Detalha o `validacao-svc`, módulo crítico (Core Domain), de forma coerente com o bounded context. |

---

## 12. Validação de Rastreabilidade

| Decisão DDD | Evidência | Status | Observação |
|---|---|---|---|
| Validação de Embarque = Core | PRD §Diferencial, FR-01, FR-02 | OK | Evidência direta e explícita. |
| Conformidade PCI = Generic | NFR-03 | OK | Compliance tratado corretamente como não-diferenciador. |
| Schema por bounded context, sem join cruzado | ADR-0002 | Revisar | O próprio data model (antes da correção) e o relatório de conciliação contrariam a decisão registrada em ADR-0002 — ver FIND-DDD-001 e FIND-DDD-002. |
| Comunicação interna via gRPC | ADR-0001, TRD | OK | Sem evidência de violação nos artefatos avaliados. |
| Módulo `bff-app` | TRD, modules/README.md | OK | Coerente entre os dois artefatos. |

---

## 13. Achados de Validação

| ID | Severidade | Artefato | Problema | Impacto | Recomendação |
|---|---|---|---|---|---|
| FIND-DDD-001 | Crítica | docs/product/data-model/data-model.md | Escrita cruzada entre contextos: a tabela `carteira` tinha Recarga como segundo dono de escrita (UPDATE direto em `saldo`), contrariando FR-03, FR-04, o Event Storming e o ADR-0002 | Quebra o isolamento de dados por bounded context; se implementado, cria acoplamento direto e condição de corrida entre Recarga e Carteira | Corrigido nesta validação (ADJ-DDD-001): Carteira volta a ser dona exclusiva; crédito segue via evento `RecargaConfirmada` → `CreditarSaldo` |
| FIND-DDD-002 | Crítica | docs/product/data-model/data-model.md (seção Relatórios) | Join direto entre os schemas `recarga` e `carteira` na consulta de conciliação, violando ADR-0002 ("joins entre schemas são proibidos") | Acopla fisicamente os dois contextos no nível de banco; qualquer migração de schema de um quebra o outro | Não corrigido diretamente — decisão de arquitetura necessária (read model, evento ou API). Ver VAL-DDD-01 e CONF-DDD-01 |
| FIND-DDD-003 | Baixa | docs/product/ddd/bounded-contexts/carteira/README.md | Uso de "VO" em documentação pt-BR | Inconsistência terminológica leve, sem risco funcional | Corrigido (ADJ-DDD-003): substituído por "objeto de valor" |
| FIND-DDD-004 | Baixa | docs/product/ddd/bounded-contexts/recarga/README.md | Evento publicado nomeado como o comando `ConfirmarRecarga` (imperativo) em vez do evento `RecargaConfirmada` (passado), divergindo do Event Storming e do context map | Pode induzir implementação a publicar o nome de evento errado | Corrigido (ADJ-DDD-002): nome alinhado a `docs/product/ddd/ddd-segmentation.md` e ao context map |
| FIND-DDD-005 | Média | docs/product/ddd/bounded-contexts/notificacoes/README.md | README não descreve linguagem própria nem regras próprias do bounded context, apenas objetivo e ownership | Dificulta avaliar se Notificações tem linguagem suficiente para ser um bounded context (risco de ser apenas um adapter técnico) | Não corrigido diretamente — falta insumo suficiente. Ver VAL-DDD-02 |

---

## 14. Ajustes Aplicados

| ID | Artefato | Ajuste | Fonte |
|---|---|---|---|
| ADJ-DDD-001 | docs/product/data-model/data-model.md | Removida Recarga como dono de escrita da tabela `carteira`; adicionada nota explicando que o crédito segue via evento `RecargaConfirmada` → `CreditarSaldo` | FR-03, FR-04, Event Storming (ddd-segmentation.md §3) |
| ADJ-DDD-002 | docs/product/ddd/bounded-contexts/recarga/README.md | Corrigido nome do evento publicado de `ConfirmarRecarga` para `RecargaConfirmada` | ddd-segmentation.md §3, context-map/README.md |
| ADJ-DDD-003 | docs/product/ddd/bounded-contexts/carteira/README.md | Substituído "VO" por "objeto de valor" | Regra de estilo pt-BR do próprio processo de validação (§7) |

---

## 15. Conflitos Arquiteturais

| ID | Fonte A | Fonte B | Conflito | Impacto | Recomendação |
|---|---|---|---|---|---|
| CONF-DDD-01 | ADR-0002 ("joins entre schemas são proibidos") | data-model.md, seção Relatórios (join `recarga.recarga` × `carteira.movimentacao`) | O relatório de conciliação, como desenhado hoje, contraria diretamente a decisão registrada no ADR | Bloqueia a aprovação sem ressalvas; não deve ser implementado como está | Decidir entre: (a) read model próprio de Recarga alimentado pelos eventos já existentes (`TarifaDebitada`, `SaldoCreditado`, `RecargaConfirmada`); (b) endpoint gRPC de consulta exposto pela Carteira; registrar a escolha em novo ADR |

---

## 16. Pontos a Validar

| Código | Ponto | Impacto | Recomendação |
|---|---|---|---|
| VAL-DDD-01 | Padrão de leitura para a conciliação diária de recargas (hoje um join direto entre schemas, proibido pelo ADR-0002) | Alto — afeta desenho de dados de dois contextos | Arquitetura decide entre read model, evento ou API antes de codificar o `recarga-svc` |
| VAL-DDD-02 | Bounded Context Notificações tem README mínimo, sem linguagem nem regras próprias descritas | Médio — dificulta confirmar se é um bounded context legítimo ou um adapter técnico | `ddd-architect` detalha linguagem própria e regras (ex.: regras de throttling/dedupe de push) na próxima iteração |
| VAL-DDD-03 | O NFRD não menciona nenhum requisito de latência para o crédito de recarga; a nota removida do data model mencionava "evitar latência do evento" sem base documental | Baixo — pode indicar um requisito de produto não capturado | Confirmar com produto se existe SLA de latência para crédito pós-Pix; se sim, formalizar como NFR e tratar na arquitetura de evento (ex.: processamento assíncrono mais rápido), nunca como escrita cruzada |

---

## 17. Métricas da Validação

| Métrica | Quantidade |
|---|---|
| Subdomínios avaliados | 5 |
| Bounded contexts avaliados | 4 |
| Relações de context map avaliadas | 4 (mais 1 relação de dado identificada fora do context map) |
| Módulos avaliados | 5 |
| Eventos avaliados | 4 |
| Achados críticos | 2 |
| Achados altos | 0 |
| Achados médios | 1 |
| Achados baixos | 2 |
| Ajustes aplicados | 3 |
| Pontos a validar | 3 |

---

## 18. Parecer Final

### Classificação

Reprovado

### Justificativa

Um dos dois achados críticos (escrita cruzada na tabela `carteira`) foi corrigido diretamente nesta validação, por ser uma inconsistência objetiva e derivável dos próprios insumos (FRD + Event Storming já definiam o fluxo correto via evento). O segundo achado crítico — join direto entre os schemas `recarga` e `carteira` na consulta de conciliação, em conflito explícito com o ADR-0002 — não pôde ser corrigido diretamente porque a solução correta depende de uma decisão de arquitetura (qual padrão de leitura substitui o join) que não está definida em nenhum dos insumos. Pela regra de severidade e de parecer final do processo (§9–10), a presença de um achado Crítico não resolvido impede o parecer "Aprovado" ou "Aprovado com Ressalvas" — mesmo com completude documental 100% e segmentação estratégica sólida.

### Condições para Aprovação

- Resolver CONF-DDD-01 / VAL-DDD-01: decidir e documentar (ADR) o padrão de leitura para a conciliação de recargas, eliminando o join direto entre schemas.
- Reexecutar a validação sobre o data model atualizado após a decisão acima, para confirmar que nenhum join ou escrita cruzada remanescente foi introduzido na correção.

### Próximos Passos

- Levar CONF-DDD-01 para decisão de arquitetura (proposta: ADR novo cobrindo o padrão de leitura entre contextos para relatórios/conciliação).
- Detalhar o bounded context Notificações (VAL-DDD-02) na próxima iteração do `ddd-architect`.
- Confirmar com produto o ponto VAL-DDD-03 sobre eventual requisito de latência não documentado.
- Após o ADR de leitura ser aprovado e o data model atualizado, reexecutar esta validação antes de seguir para derivação de módulos e backlog.
