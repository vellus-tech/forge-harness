# FRD/NFRD Validation Report - RecargaJá

**Produto:** RecargaJá — Recarga de cartão de transporte via Pix
**Versão do Relatório:** v1.0
**Data:** 2026-09-26
**Status:** Final
**Documentos Validados:** PRD, FRD, NFRD

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Criação inicial do relatório de validação FRD/NFRD |

---

## Sumário Executivo

### Parecer Final

Aprovado com Ressalvas

### Síntese

O FRD e o NFRD do RecargaJá cobrem, em conjunto, as três funcionalidades (F1, F2, F3) e os três atributos de qualidade explícitos do PRD (performance, privacidade/LGPD e auditabilidade). A queixa levantada na daily procede em ambos os pontos: a matriz de rastreabilidade do FRD trocava os requisitos de F2 e F3 entre si, e a métrica de NFRD-PERF-01 estava redigida como "Rápida" — sem número, sem unidade e sem alvo mensurável — apesar de o PRD já definir a meta ("95% em até 10 segundos") em sua seção 6. Também foi identificado que o FRD-REC-01 embutia decisões de arquitetura (Kafka, Spring Boot 3.3, Resilience4j, PostgreSQL 16 particionado) que pertencem ao TRD, não ao FRD. Os três achados são editáveis segundo os critérios do validador (correção localizada, sem mudança de escopo de produto, solução inequívoca a partir do próprio PRD ou de convenção de nomenclatura já vigente) e foram aplicados diretamente nesta rodada. Nenhum achado exigiu decisão arquitetural nova (ADR), pois o único ponto de fronteira FRD/TRD identificado foi resolvido por remoção do detalhe técnico do FRD, e não pela escolha de uma tecnologia ainda em aberto.

### Principais Riscos

- Antes da correção, o time de QA e o `ddd-architect` seguinte poderiam derivar casos de teste e agregados a partir do requisito errado (histórico de recargas tratado como F2, saldo tratado como F3), gerando retrabalho de rastreabilidade.
- A métrica vaga de NFRD-PERF-01 ("Rápida") não seria testável por um time de performance/SRE sem retornar ao PRD, quebrando a promessa do NFRD de ser a fonte objetiva para QA.
- Detalhe de stack no FRD-REC-01 antecipava uma decisão de arquitetura (Kafka + Spring Boot 3.3 + Resilience4j + PostgreSQL particionado) sem que houvesse ADR ou TRD registrando essa escolha, criando risco de o `ddd-architect` tratar como decisão já fechada.

### Principais Recomendações

- Manter o FRD livre de nomes de tecnologia; qualquer decisão de stack para a confirmação assíncrona do Pix deve ser registrada no TRD (e, se for uma escolha com custo de reversão alto — broker de mensageria, particionamento de dados —, considerar ADR antes da fase de design).
- Ao evoluir o NFRD, sempre que o PRD já fornecer uma meta numérica em `Requisitos de qualidade esperados`, copiar a meta literalmente para a coluna `Métrica / Critério` do NFRD, nunca parafrasear como qualificativo (“rápido”, “seguro”, “escalável”).

---

## 1. Documentos Avaliados

| Documento | Caminho | Status |
|---|---|---|
| PRD | docs/product/prd/prd.md | Encontrado |
| FRD | docs/product/frd-nfrd/frd.md | Encontrado |
| NFRD | docs/product/frd-nfrd/nfrd.md | Encontrado |

---

## 2. Baseline do PRD

| Código | Item | Tipo | Descrição | Fonte |
|---|---|---|---|---|
| PRD-BASE-01 | Objetivo | Objetivo | Permitir recarga do cartão de transporte via Pix pelo app, sem posto físico | PRD §1 |
| PRD-BASE-02 | F1 | Funcionalidade | Recarga de cartão via Pix (QR Code dinâmico gerado no app) | PRD §2 |
| PRD-BASE-03 | F2 | Funcionalidade | Consulta de saldo do cartão | PRD §2 |
| PRD-BASE-04 | F3 | Funcionalidade | Histórico das últimas 90 recargas do passageiro | PRD §2 |
| PRD-BASE-05 | Fora de escopo | Fora de escopo | Recarga por cartão de crédito; venda de cartão novo | PRD §3 |
| PRD-BASE-06 | P-01 | Persona | Passageiro com cartão cadastrado no app | PRD §4 |
| PRD-BASE-07 | P-02 | Persona | Atendente do SAC (consulta histórico para atender reclamação) | PRD §4 |
| PRD-BASE-08 | BR-01 | Regra de negócio | Valor da recarga entre R$ 5,00 e R$ 300,00 por transação | PRD §5 |
| PRD-BASE-09 | BR-02 | Regra de negócio | Crédito só disponível após confirmação do Pix pelo PSP | PRD §5 |
| PRD-BASE-10 | BR-03 | Regra de negócio | QR Code expira em 15 minutos; recarga expirada não gera crédito | PRD §5 |
| PRD-BASE-11 | NFR Performance | NFR Implícito/Explícito | 95% das recargas com crédito disponível em até 10s após confirmação do Pix | PRD §6 |
| PRD-BASE-12 | NFR Privacidade | NFR Implícito/Explícito | CPF do passageiro mascarado em qualquer tela do SAC (LGPD) | PRD §6 |
| PRD-BASE-13 | NFR Auditabilidade | NFR Implícito/Explícito | Toda recarga deixa trilha de auditoria imutável (quem, quando, valor, cartão) | PRD §6 |

---

## 3. Cobertura PRD → FRD

| Item PRD | Descrição PRD | Requisito FRD Relacionado | Status | Observação |
|---|---|---|---|---|
| PRD-BASE-02 (F1) | Recarga via Pix | FRD-REC-01 | Coberto | CA-01/02/03 cobrem BR-01, BR-02, BR-03 |
| PRD-BASE-03 (F2) | Consulta de saldo | FRD-REC-02 | Coberto | Requisito simples, sem critérios de aceite explícitos (ver Passo 4) |
| PRD-BASE-04 (F3) | Histórico de 90 recargas | FRD-REC-03 (era `FRD-XX`) | Coberto | Corrigido nesta rodada — ver FIND-001; matriz do FRD apontava este item para `FRD-REC-02`, invertido com F2 |
| PRD-BASE-08 (BR-01) | Faixa de valor | FRD-REC-01, CA-01, MSG-001 | Coberto | |
| PRD-BASE-09 (BR-02) | Crédito só após confirmação PSP | FRD-REC-01, CA-03 | Coberto | |
| PRD-BASE-10 (BR-03) | Expiração de 15 min | FRD-REC-01, CA-02, MSG-002 | Coberto | |
| PRD-BASE-07 (P-02, SAC) | CPF mascarado para o SAC | FRD-REC-03, CA-02 | Coberto | Formato de máscara definido (`***.456.789-**`) |

---

## 4. Cobertura PRD → NFRD

| Item PRD | Atributo Não Funcional Esperado | Requisito NFRD Relacionado | Status | Observação |
|---|---|---|---|---|
| PRD-BASE-11 | Performance | NFRD-PERF-01 | Coberto (após correção) | Antes da correção, métrica "Rápida" tornava o item Parcialmente Coberto — ver FIND-004 |
| PRD-BASE-12 | Privacidade/LGPD | NFRD-SEC-01 | Coberto | Métrica e método de validação objetivos |
| PRD-BASE-13 | Auditabilidade | NFRD-AUD-01 | Coberto | Métrica e método de validação objetivos |
| PRD-BASE-09 (BR-02, integração PSP) | Disponibilidade/Resiliência da confirmação | — | Ponto a Validar | Ver VAL-01 |

---

## 5. Validação dos Requisitos Funcionais

| Requisito | Clareza | Atomicidade | Testabilidade | Rastreabilidade | Critérios de Aceite | Status | Observação |
|---|---|---|---|---|---|---|---|
| FRD-REC-01 | OK | OK (após correção) | OK | OK | OK | OK | Antes da correção, misturava requisito funcional com decisão de implementação técnica (ver FIND-003, Passo 6) |
| FRD-REC-02 | OK | OK | Parcial | OK | Ausentes | Revisar | Não há critério de aceite explícito (ex.: comportamento quando o saldo não pode ser obtido) — registrado como VAL-02, não é achado editável pois exigiria criar novo conteúdo |
| FRD-REC-03 | OK | OK | OK | OK (após correção) | OK | OK | ID e matriz corrigidos nesta rodada — ver FIND-001/FIND-002 |

---

## 6. Validação dos Requisitos Não Funcionais

| Requisito | Clareza | Mensurabilidade | Testabilidade | Rastreabilidade | Categoria | Status | Observação |
|---|---|---|---|---|---|---|---|
| NFRD-PERF-01 | OK (após correção) | OK (após correção) | OK (após correção) | OK | OK | OK | Métrica "Rápida" substituída pela meta do PRD §6 — ver FIND-004 |
| NFRD-SEC-01 | OK | OK | OK | OK | OK | OK | |
| NFRD-AUD-01 | OK | OK | OK | OK | OK | OK | |

---

## 7. Validação de Separação Documental

| Item | Documento Atual | Documento Correto | Problema | Recomendação |
|---|---|---|---|---|
| Consumidor Kafka, Spring Boot 3.3, Resilience4j, PostgreSQL 16 particionado por mês (antiga redação de FRD-REC-01) | FRD | TRD | Decisão técnica detalhada (broker de mensageria, framework, versão, particionamento de banco) dentro do FRD | Aplicado nesta rodada: removido do FRD e substituído por nota apontando que a decisão pertence ao TRD (ver FIND-003) |

---

## 8. Validação das Regras de Negócio

| Regra | Fonte PRD | FRD Relacionado | Status | Observação |
|---|---|---|---|---|
| BR-01 | PRD §5 | FRD-REC-01 / CA-01 / MSG-001 | Coberta | |
| BR-02 | PRD §5 | FRD-REC-01 / CA-03 | Coberta | |
| BR-03 | PRD §5 | FRD-REC-01 / CA-02 / MSG-002 | Coberta | |

---

## 9. Validação de Fluxos Funcionais

| Requisito/Caso de Uso | Fluxo Principal | Alternativos | Exceções | Mensagens | Status | Observação |
|---|---|---|---|---|---|---|
| FRD-REC-01 | OK | Não se aplica (fluxo único de recarga) | Parcial | OK (MSG-001, MSG-002) | Revisar | Falta cenário de exceção para falha/timeout do PSP sem expiração do QR Code (ex.: PSP indisponível) — registrado como VAL-03 |
| FRD-REC-02 | OK | — | Ausente | — | Revisar | Falta exceção para indisponibilidade momentânea do saldo — registrado como VAL-02 |
| FRD-REC-03 | OK | — | Ausente | — | Ponto a Validar | Falta exceção para passageiro/cartão sem histórico (lista vazia) — registrado como VAL-04 |

---

## 10. Validação das Mensagens

| Mensagem | Requisito Relacionado | Clareza | Segurança | Ação para Usuário | Status | Observação |
|---|---|---|---|---|---|---|
| MSG-001 | FRD-REC-01 | OK | OK | OK | OK | Informa a faixa de valor esperada |
| MSG-002 | FRD-REC-01 | OK | OK | OK | OK | Orienta a gerar novo QR Code |

---

## 11. Validação de Permissões Funcionais

| Funcionalidade | Perfil/Papel | Permissão | Status | Observação |
|---|---|---|---|---|
| Histórico de recargas | Passageiro (P-01) | Ver o próprio histórico, CPF não mascarado (é o próprio titular) | OK | Coerente com persona |
| Histórico de recargas | Atendente do SAC (P-02) | Ver histórico de qualquer passageiro, CPF mascarado | OK | Coerente com BR de LGPD do PRD §6 |

---

## 12. Validação de Atributos de Qualidade

| Atributo | Esperado pelo Produto? | Coberto no NFRD? | Qualidade da Cobertura | Observação |
|---|---|---|---|---|
| Performance | Sim | Sim | OK (após correção) | Meta agora explícita (p95 ≤ 10s) |
| Availability | Não explícito no PRD | Não | — | Não é achado — PRD não menciona SLA de disponibilidade |
| Scalability | Não explícito no PRD | Não | — | Não é achado |
| Resilience | Implícito (integração com PSP) | Não | Falha | Ver VAL-01 — comportamento em caso de indisponibilidade do PSP não está coberto |
| Security | Implícito (Pix, dados financeiros) | Parcial | Parcial | NFRD cobre privacidade do CPF, mas não cobre segurança da integração Pix/PSP (autenticação, assinatura, replay) — ver VAL-01 |
| Privacy | Sim | Sim | OK | NFRD-SEC-01 |
| Compliance | Sim (LGPD citada no PRD) | Parcial | Parcial | LGPD coberta via NFRD-SEC-01; não há menção a outras exigências regulatórias de meios de pagamento (ex.: Bacen/Pix) — fora do escopo deste PRD |
| Observability | Não explícito no PRD | Não | — | Não é achado — PRD não trata do tema |
| Auditability | Sim | Sim | OK | NFRD-AUD-01 |
| Usability | Não explícito no PRD | Não | — | Não é achado |
| Accessibility | Não explícito no PRD | Não | — | Não é achado |
| Maintainability | Não explícito no PRD | Não | — | Não é achado |
| Testability | Implícito (todo NFR deveria ser testável) | Sim | OK (após correção) | |
| Interoperability | Não explícito no PRD | Não | — | Não é achado |
| Backup and Recovery | Não explícito no PRD | Não | — | Não é achado |
| Data Retention | Implícito (histórico de 90 recargas) | Não | Falha | PRD define retenção de 90 recargas para exibição, mas NFRD não define por quanto tempo os dados de recarga são retidos/arquivados para fins de auditoria — ver VAL-01 |
| Operability | Não explícito no PRD | Não | — | Não é achado |

---

## 13. Validação da Rastreabilidade

| Item | Tipo | Origem | Destino | Status | Observação |
|---|---|---|---|---|---|
| F1 | Funcionalidade | PRD | FRD-REC-01 | OK | |
| F2 | Funcionalidade | PRD | FRD-REC-02 | OK (após correção) | Matriz do FRD apontava F2 → `FRD-XX` antes da correção |
| F3 | Funcionalidade | PRD | FRD-REC-03 | OK (após correção) | Matriz do FRD apontava F3 → `FRD-REC-02` antes da correção; ID `FRD-XX` também corrigido |
| NFR Performance (PRD §6) | Requisito Não Funcional | PRD | NFRD-PERF-01 | OK (após correção) | |
| NFR Privacidade (PRD §6) | Requisito Não Funcional | PRD | NFRD-SEC-01 | OK | |
| NFR Auditabilidade (PRD §6) | Requisito Não Funcional | PRD | NFRD-AUD-01 | OK | |

---

## 14. Achados de Validação

| ID | Severidade | Documento | Seção | Problema | Impacto | Recomendação |
|---|---|---|---|---|---|---|
| FIND-001 | Média | FRD | §1, Requisito de Histórico | ID de requisito `FRD-XX` não segue a convenção de nomenclatura do domínio (`FRD-REC-NN`) | Dificulta rastreabilidade automatizada e referência cruzada em backlog/Jira | Aplicado: renomeado para `FRD-REC-03` |
| FIND-002 | Alta | FRD | §3, Matriz de rastreabilidade | Matriz de rastreabilidade invertia F2 e F3: apontava F2 → histórico e F3 → saldo, contrário ao corpo do documento | Um consumidor que leia só a matriz (ex.: QA montando plano de teste, `ddd-architect` mapeando agregados) implementaria/testaria o requisito errado para cada funcionalidade — é exatamente o problema relatado na daily | Aplicado: matriz corrigida (F1→FRD-REC-01, F2→FRD-REC-02, F3→FRD-REC-03) |
| FIND-003 | Média | FRD | §1, FRD-REC-01 | Requisito funcional descrevia mecanismo de implementação (consumidor Kafka, Spring Boot 3.3, Resilience4j, PostgreSQL 16 particionado por mês) — invasão do escopo do TRD | Antecipa decisão de arquitetura sem ADR, mistura responsabilidade do FRD com a do `ddd-architect`/TRD, e pode ser lido como compromisso já fechado de stack | Aplicado: detalhe técnico removido do FRD e substituído por nota indicando que a decisão pertence ao TRD |
| FIND-004 | Alta | NFRD | Tabela de Requisitos Não Funcionais, NFRD-PERF-01 | Métrica do NFR de performance era o qualificativo "Rápida", sem número, unidade ou alvo — exatamente o ponto citado na daily como "vago" | QA e SRE não conseguem escrever um teste de carga objetivo a partir do NFRD; o alvo real (95% em até 10s) já existe no PRD §6 e não foi transportado | Aplicado: métrica substituída por "95% das recargas com crédito disponível em até 10 segundos (p95 ≤ 10s)" e método de validação detalhado |

---

## 15. Métricas da Validação

| Métrica | Quantidade |
|---|---|
| Itens do PRD analisados | 13 |
| Requisitos FRD avaliados | 3 |
| Requisitos NFRD avaliados | 3 |
| Itens cobertos | 12 |
| Itens parcialmente cobertos | 1 (Resiliência/Segurança da integração Pix, ver VAL-01) |
| Itens não cobertos | 0 |
| Requisitos sem rastreabilidade | 0 (após correção) |
| Achados críticos | 0 |
| Achados altos | 2 |
| Achados médios | 2 |
| Achados baixos | 0 |

---

## 16. Pontos a Validar

| Código | Ponto | Documento | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-01 | PRD não define comportamento esperado em caso de indisponibilidade/erro do PSP (resiliência), nem exigências de segurança da integração Pix (autenticação, assinatura, replay), nem prazo de retenção dos dados de recarga além da janela de exibição de 90 registros | FRD/NFRD | Sem essa definição, o `ddd-architect` e o TRD não têm baseline de produto para decidir retry/circuit breaker, controles antifraude e política de retenção/expurgo | Levar ao dono do produto antes ou durante o design técnico; se a resposta implicar escolha de arquitetura irreversível (ex.: retry assíncrono com fila, período de retenção multi-tenant), abrir ADR a partir da decisão de produto |
| VAL-02 | FRD-REC-02 (Consulta de saldo) não define critério de aceite nem exceção para indisponibilidade do saldo (ex.: serviço de saldo fora do ar) | FRD | QA não tem base objetiva para testar o caminho de erro desse requisito | Nova rodada do `frd-generator` para detalhar critérios de aceite e exceção de FRD-REC-02 |
| VAL-03 | FRD-REC-01 não descreve o que o app exibe se a confirmação do PSP nunca chegar dentro dos 15 minutos por falha do PSP (distinto de expiração natural do QR Code) | FRD | Ambiguidade entre "QR Code expirado" (MSG-002, coberto) e "PSP não confirmou por erro" (não coberto) pode gerar comportamento inconsistente na implementação | Nova rodada do `frd-generator` para adicionar fluxo de exceção específico |
| VAL-04 | FRD-REC-03 não define o que é exibido quando o passageiro não tem nenhuma recarga no histórico (lista vazia) | FRD | Tela de histórico vazio é um estado de UI comum e deveria ter comportamento definido para não virar decisão ad hoc do time de implementação | Nova rodada do `frd-generator` |

---

## 17. Parecer Final

### Classificação

Aprovado com Ressalvas

### Justificativa

Não há achados críticos nem ausência de cobertura funcional ou não funcional: as três funcionalidades do PRD e os três atributos de qualidade explícitos estão presentes e, após as correções aplicadas nesta rodada, corretamente rastreáveis e mensuráveis. Os dois achados de severidade Alta (matriz de rastreabilidade invertida e métrica de performance vaga) eram exatamente os dois problemas relatados informalmente na daily, foram confirmados na validação e já foram corrigidos diretamente nos documentos por serem achados editáveis (redação/estrutura, sem mudança de escopo de produto). O que resta como pendência (VAL-01 a VAL-04) são lacunas de detalhamento — resiliência da integração PSP, segurança da integração Pix, retenção de dados, critérios de aceite e exceções ausentes em dois requisitos — que não bloqueiam o encaminhamento ao `ddd-architect`, mas devem ser resolvidas antes de o TRD e o backlog de QA serem fechados.

### Condições para Aprovação

- Antes de o TRD detalhar a integração com o PSP, o dono de produto deve responder VAL-01 (comportamento de indisponibilidade do PSP, exigências de segurança da integração Pix e prazo de retenção dos dados de recarga).
- FRD-REC-01, FRD-REC-02 e FRD-REC-03 devem ganhar os critérios de aceite/exceções apontados em VAL-02, VAL-03 e VAL-04 em uma próxima rodada do `frd-generator`, antes de o QA montar o plano de testes definitivo.

### Próximos Passos Recomendados

- Encaminhar ao `ddd-architect` com a ressalva de que VAL-01 (resiliência/segurança/retenção) ainda está em aberto e pode alterar o desenho do agregado de confirmação de pagamento.
- Agendar nova rodada do `frd-generator` para fechar VAL-02, VAL-03 e VAL-04.
- Comunicar ao time (via daily/ata) que os dois problemas relatados — matriz de rastreabilidade e NFR de performance vago — já foram corrigidos nesta versão (`v1.0.1`) do FRD e do NFRD.

---

## 18. ADRs Sugeridos

Nenhum ADR sugerido nesta validação. O único ponto de fronteira FRD/TRD identificado (FIND-003) foi resolvido por remoção do detalhe técnico do FRD, não por uma decisão de arquitetura ainda em aberto — a escolha de stack para a confirmação assíncrona do Pix (mensageria, particionamento) permanece em aberto para o TRD e, se necessário, poderá gerar ADR na fase de design técnico, mas isso é decisão do `ddd-architect`, não desta validação.
