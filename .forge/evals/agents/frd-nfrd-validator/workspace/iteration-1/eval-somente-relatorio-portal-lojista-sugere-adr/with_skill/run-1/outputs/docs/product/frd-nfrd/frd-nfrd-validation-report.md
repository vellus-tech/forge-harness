# FRD/NFRD Validation Report - Portal do Lojista

**Produto:** Portal do Lojista
**Versão do Relatório:** v1.0
**Data:** 2026-09-26
**Status:** Final
**Documentos Validados:** PRD, FRD, NFRD

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Criação inicial do relatório de validação FRD/NFRD — modo somente-relatório, a pedido do usuário |

---

## Sumário Executivo

### Parecer Final

**Aprovado com Ressalvas**

### Síntese

O FRD e o NFRD cobrem, no nível macro, as quatro funcionalidades do PRD (login com segundo fator, consulta de vendas, exportação CSV e chargebacks) e a regra de gestão de operadores, com rastreabilidade explícita ao PRD e sem extrapolação relevante de escopo. Esta rodada foi executada em **modo somente-relatório**, a pedido explícito do usuário — nenhuma correção foi aplicada a `frd.md` ou `nfrd.md`, para não conflitar com a edição paralela do Rafael na mesma branch.

Os dois pontos que o usuário sinalizou como prioritários — política de senha e prazo de retenção de vendas — são exatamente os dois maiores achados desta validação, e ambos **não são corrigíveis por redação**: dependem de decisão arquitetural/regulatória formal (ver § 18, ADRs sugeridos). BR-03 exige "senha forte" sem definir algoritmo de hash, comprimento mínimo, complexidade ou periodicidade de troca (NFRD-SEC-01 registra apenas "armazenadas de forma segura", sem método verificável); e NFRD-RET-01 não tem métrica de retenção porque o jurídico ainda não fechou o prazo, o que é uma lacuna crítica dado que o portal está no escopo PCI DSS 4.0.1 da adquirente.

Há também uma lacuna de cobertura não sinalizada pelo usuário, mas exigida pela rule `security-and-compliance.md` do projeto (auditoria de acesso a dados de pagamento): nenhum requisito não funcional de auditoria/observabilidade foi encontrado no NFRD, apesar do escopo PCI DSS explícito no PRD. Esse achado é editável (deriva de rule já vinculante), mas não foi aplicado por estarmos em modo somente-relatório.

Achados menores (naming fora de convenção, critérios de aceite ausentes em três requisitos, fluxos alternativos/exceção incompletos) reforçam a recomendação de uma nova rodada do `frd-generator`/`nfrd-generator` antes de `Aprovado para desenvolvimento`, mas não bloqueiam a evolução técnica com cautela.

### Principais Riscos

- Ausência de definição de algoritmo/parâmetros de hash de senha em ambiente sob escopo PCI DSS 4.0.1 (Req. 8) — risco de implementação divergente ou insegura se a engenharia avançar sem a decisão.
- Ausência de prazo de retenção de dados de vendas (PAN mascarado, mas ainda dado transacional sensível) — risco de não conformidade regulatória e de a engenharia implementar um prazo "provisório" que vire de fato definitivo.
- Ausência de requisito de auditoria de acesso a dados de pagamento — risco de o desenho técnico (TRD) não prever trilha de auditoria, exigindo retrabalho.

### Principais Recomendações

- Abrir os dois ADRs sugeridos (§ 18) antes da próxima rodada de detalhamento do FRD/NFRD — política de senha/hash e política de retenção/expurgo.
- Adicionar ao NFRD um requisito de auditoria de acesso a dados de pagamento (achado editável, sem necessidade de ADR).
- Completar critérios de aceite e fluxos de exceção ausentes em `FRD-POR-03`, `FRD-CHB-1` e `FRD-POR-05`, e corrigir o identificador `FRD-CHB-1` para o padrão `FRD-CHB-01`.

---

## 1. Documentos Avaliados

| Documento | Caminho | Status |
|---|---|---|
| PRD | docs/product/prd/prd.md | Encontrado |
| FRD | docs/product/frd-nfrd/frd.md | Encontrado |
| NFRD | docs/product/frd-nfrd/nfrd.md | Encontrado |
| ADRs existentes | docs/product/adr/0001, 0002 | Encontrados (SPA+BFF; TOTP como segundo fator) |

---

## 2. Baseline do PRD

| Código | Item | Tipo | Descrição | Fonte |
|---|---|---|---|---|
| PRD-BASE-01 | Autonomia de consulta sem SAC | Objetivo | Lojista consulta vendas, recebíveis e chargebacks sem chamado | PRD §1 |
| PRD-BASE-02 | F1 — Login com 2FA | Funcionalidade | E-mail e senha + segundo fator por app autenticador | PRD §2 |
| PRD-BASE-03 | F2 — Consulta de vendas | Funcionalidade | Por período, máx. 90 dias, PAN mascarado | PRD §2 |
| PRD-BASE-04 | F3 — Exportação CSV | Funcionalidade | Exportação das vendas consultadas | PRD §2 |
| PRD-BASE-05 | F4 — Consulta de chargebacks | Funcionalidade | Chargebacks abertos e prazo de defesa | PRD §2 |
| PRD-BASE-06 | P-01 Lojista administrador | Persona | Cria usuários operadores da própria loja | PRD §3 |
| PRD-BASE-07 | P-02 Lojista operador | Persona | Apenas consulta | PRD §3 |
| PRD-BASE-08 | BR-01 | Regra | Só administrador cria/bloqueia/remove operadores da própria loja | PRD §4 |
| PRD-BASE-09 | BR-02 | Regra | 5 tentativas inválidas → bloqueio de 30 minutos | PRD §4 |
| PRD-BASE-10 | BR-03 | Regra | Senha forte e trocada periodicamente | PRD §4 |
| PRD-BASE-11 | Escopo PCI DSS / PAN | Restrição/Compliance | Portal no escopo PCI DSS 4.0.1 da adquirente; PAN completo nunca exibido/exportado | PRD §5 |
| PRD-BASE-12 | Retenção de dados de vendas | Restrição/NFR implícito | Retenção pelo prazo regulatório, ainda não definido pelo jurídico | PRD §5 |
| PRD-BASE-13 | Auditoria de acesso a dados de pagamento | NFR implícito | Não explícito no PRD, mas obrigatório pela rule `security-and-compliance.md` dado o escopo PCI DSS declarado em PRD-BASE-11 | PRD §5 + rule do projeto |

---

## 3. Cobertura PRD → FRD

| Item PRD | Descrição PRD | Requisito FRD Relacionado | Status | Observação |
|---|---|---|---|---|
| PRD-BASE-02 | Login + 2FA | FRD-POR-01 | Coberto | TOTP e bloqueio detalhados |
| PRD-BASE-03 | Consulta de vendas | FRD-POR-02 | Coberto | Período e mascaramento detalhados |
| PRD-BASE-04 | Exportação CSV | FRD-POR-03 | Parcialmente Coberto | Sem critérios de aceite explícitos nem fluxo de exceção (exportação vazia) |
| PRD-BASE-05 | Chargebacks | FRD-CHB-1 | Parcialmente Coberto | Só visualização; "prazo de defesa" não detalha cálculo/contagem nem ação do lojista; sem CA |
| PRD-BASE-08 | Gestão de operadores | FRD-POR-05 | Parcialmente Coberto | Sem CA nem tratamento de exceções (ex.: remover o único administrador) |
| PRD-BASE-09 | Lockout 5 tentativas/30min | FRD-POR-01 CA-02 | Coberto | — |
| PRD-BASE-10 | Senha forte + troca periódica | FRD-POR-01 | Parcialmente Coberto | "Senha deve ser forte" sem critério objetivo (comprimento, complexidade); troca periódica do PRD não aparece no FRD |
| PRD-BASE-11 | PAN nunca exibido/exportado completo | FRD-POR-02 CA-02, FRD-POR-03 | Coberto | Mascaramento consistente entre tela e CSV |

---

## 4. Cobertura PRD → NFRD

| Item PRD | Atributo Não Funcional Esperado | Requisito NFRD Relacionado | Status | Observação |
|---|---|---|---|---|
| PRD-BASE-10 | Segurança (armazenamento de senha) | NFRD-SEC-01 | Parcialmente Coberto | Sem algoritmo/parâmetros de hash — exige ADR (ver § 18) |
| PRD-BASE-11 | Compliance / mascaramento de PAN | NFRD-SEC-02 | Coberto | Métrica e método de validação claros |
| PRD-BASE-12 | Retenção de dados | NFRD-RET-01 | Não Coberto | Métrica e método em branco; bloqueado por decisão jurídica pendente — exige ADR (ver § 18) |
| PRD-BASE-03 | Performance da consulta | NFRD-PERF-01 | Coberto | p95 definido; falta p99 e comportamento acima de 50 mil vendas (achado menor) |
| PRD-BASE-13 | Auditabilidade (acesso a dados de pagamento) | — | Não Coberto | Nenhum NFR de auditoria/observabilidade no documento, apesar da rule do projeto exigir |
| — | Disponibilidade, Escalabilidade, Usabilidade, Acessibilidade, Backup/Recovery | — | Ponto a Validar | Sem menção explícita no PRD nem no NFRD; não necessariamente lacuna crítica para este escopo, mas deve ser confirmado com produto antes de `Aprovado para desenvolvimento` |

---

## 5. Validação dos Requisitos Funcionais

| Requisito | Clareza | Atomicidade | Testabilidade | Rastreabilidade | Critérios de Aceite | Status | Observação |
|---|---|---|---|---|---|---|---|
| FRD-POR-01 | OK | OK | Parcial | OK | Parcial | Revisar | "Senha deve ser forte" não tem CA nem critério mensurável |
| FRD-POR-02 | OK | OK | OK | OK | OK | OK | — |
| FRD-POR-03 | OK | OK | Parcial | OK | Falha | Revisar | Nenhuma CA explícita; falta exceção de resultado vazio |
| FRD-CHB-1 | OK | OK | Parcial | OK | Falha | Revisar | Sem CA; identificador fora do padrão `FRD-XXX-NN` (ver FIND-005) |
| FRD-POR-05 | OK | OK | Parcial | OK | Falha | Revisar | Sem CA; sem tratamento de exceções (remoção do único administrador, e-mail duplicado) |

---

## 6. Validação dos Requisitos Não Funcionais

| Requisito | Clareza | Mensurabilidade | Testabilidade | Rastreabilidade | Categoria | Status | Observação |
|---|---|---|---|---|---|---|---|
| NFRD-SEC-01 | Revisar (vago) | Falha | Parcial (só revisão de código) | OK | OK | Crítico | Sem algoritmo de hash nem parâmetros — não implementável nem verificável objetivamente |
| NFRD-SEC-02 | OK | OK | OK | OK | OK | OK | — |
| NFRD-RET-01 | OK | Falha | Falha | OK | OK | Ponto a Validar | Métrica e método em branco; bloqueado por decisão jurídica pendente |
| NFRD-PERF-01 | OK | OK | OK | OK | OK | OK | Falta p99 (achado menor, não bloqueante) |

---

## 7. Validação de Separação Documental

| Item | Documento Atual | Documento Correto | Problema | Recomendação |
|---|---|---|---|---|
| — | — | — | Nenhuma invasão relevante de escopo FRD↔NFRD↔TRD identificada nesta rodada | — |

---

## 8. Validação das Regras de Negócio

| Regra | Fonte PRD | FRD Relacionado | Status | Observação |
|---|---|---|---|---|
| BR-01 | PRD §4 | FRD-POR-05 | Coberta | — |
| BR-02 | PRD §4 | FRD-POR-01 CA-02 | Coberta | — |
| BR-03 | PRD §4 | FRD-POR-01 / NFRD-SEC-01 | Parcialmente Coberta | Falta critério objetivo de "forte" e periodicidade de troca; falta algoritmo de hash — exige ADR |

---

## 9. Validação de Fluxos Funcionais

| Requisito/Caso de Uso | Fluxo Principal | Alternativos | Exceções | Mensagens | Status | Observação |
|---|---|---|---|---|---|---|
| FRD-POR-01 | OK | Falha | Parcial | OK (MSG-001) | Revisar | Sem fluxo de recuperação de senha/TOTP perdido |
| FRD-POR-02 | OK | — | OK | OK (MSG-002) | OK | — |
| FRD-POR-03 | OK | — | Falha | Não definida | Revisar | Sem tratamento para exportação de resultado vazio |
| FRD-CHB-1 | Parcial | — | Falha | Não definida | Revisar | Sem exceção para "nenhum chargeback aberto"; não descreve ação do lojista frente ao prazo de defesa |
| FRD-POR-05 | Parcial | — | Falha | Não definida | Revisar | Sem exceção para remoção do único administrador ou e-mail duplicado |

---

## 10. Validação das Mensagens

| Mensagem | Requisito Relacionado | Clareza | Segurança | Ação para Usuário | Status | Observação |
|---|---|---|---|---|---|---|
| MSG-001 | FRD-POR-01 | OK | OK | Parcial | Revisar | Não informa tempo restante de bloqueio nem canal de suporte |
| MSG-002 | FRD-POR-02 | OK | OK | OK | OK | — |
| — | FRD-POR-03, FRD-CHB-1, FRD-POR-05 | — | — | — | Não Coberto | Nenhuma mensagem de erro/validação definida para esses requisitos |

---

## 11. Validação de Permissões Funcionais

| Funcionalidade | Perfil/Papel | Permissão | Status | Observação |
|---|---|---|---|---|
| Gestão de operadores (FRD-POR-05) | Administrador | Permitido | OK | Conforme BR-01 |
| Gestão de operadores (FRD-POR-05) | Operador | Negado (implícito) | OK | Coerente com BR-01, ainda que não explicitado como negação |
| Consulta de vendas (FRD-POR-02) | Administrador e Operador | Permitido (implícito) | Ponto a Validar | PRD não distingue perfis para F2; assumir ambos, mas não está explícito no FRD |
| Exportação CSV (FRD-POR-03) | Administrador e/ou Operador | Não definido | Ponto a Validar | FRD não especifica se Operador pode exportar |
| Chargebacks (FRD-CHB-1) | Administrador e/ou Operador | Não definido | Ponto a Validar | FRD não especifica por perfil |

---

## 12. Validação de Atributos de Qualidade

| Atributo | Esperado pelo Produto? | Coberto no NFRD? | Qualidade da Cobertura | Observação |
|---|---|---|---|---|
| Performance | Sim | Sim | Parcial | Só p95; falta p99 e comportamento de pico |
| Availability | Não explícito | Não | — | Ponto a Validar com produto |
| Scalability | Não explícito | Não | — | Ponto a Validar com produto |
| Resilience | Não explícito | Não | — | Ponto a Validar com produto |
| Security | Sim | Parcial | Falha (senha) / OK (PAN) | NFRD-SEC-01 sem algoritmo/parâmetros — exige ADR |
| Privacy | Sim (implícito, LGPD) | Não | Falha | Nenhum requisito de minimização/bases legais para dados de vendas |
| Compliance | Sim (PCI DSS 4.0.1) | Parcial | Parcial | PAN coberto (NFRD-SEC-02); retenção e auditoria não |
| Observability | Sim (implícito, PCI DSS) | Não | Falha | Nenhum requisito de logs/métricas/traces |
| Auditability | Sim (rule do projeto + PCI DSS Req. 10) | Não | Falha | Nenhum requisito de trilha de auditoria de acesso a dados de pagamento |
| Usability | Não explícito | Não | — | Ponto a Validar |
| Accessibility | Não explícito | Não | — | Ponto a Validar |
| Maintainability | Não explícito | Não | — | Fora de escopo desta validação |
| Testability | Implícito | Parcial | Parcial | Requisitos com critério mensurável são testáveis; senha e retenção não |
| Interoperability | Não explícito | Não | — | Fora de escopo |
| Backup and Recovery | Não explícito | Não | — | Ponto a Validar |
| Data Retention | Sim (PRD §5) | Sim (parcial) | Falha | NFRD-RET-01 sem métrica — exige ADR |
| Operability | Não explícito | Não | — | Fora de escopo |

---

## 13. Validação da Rastreabilidade

| Item | Tipo | Origem | Destino | Status | Observação |
|---|---|---|---|---|---|
| PRD-BASE-02 | Funcionalidade | PRD | FRD-POR-01 | OK | — |
| PRD-BASE-03 | Funcionalidade | PRD | FRD-POR-02 | OK | — |
| PRD-BASE-04 | Funcionalidade | PRD | FRD-POR-03 | OK | — |
| PRD-BASE-05 | Funcionalidade | PRD | FRD-CHB-1 | Revisar | Rastreável, mas identificador fora do padrão prejudica automação de rastreio |
| PRD-BASE-08 | Regra | PRD | FRD-POR-05 | OK | — |
| PRD-BASE-10 | Regra | PRD | FRD-POR-01, NFRD-SEC-01 | Revisar | Origem existe, mas cobertura é parcial no destino |
| PRD-BASE-12 | Restrição | PRD | NFRD-RET-01 | Revisar | Origem existe, destino sem conteúdo mensurável |
| PRD-BASE-13 | NFR implícito | Rule do projeto + PRD §5 | — | Não Coberto | Requisito órfão por ausência — nenhum NFRD-AUD-NN existe |

Nenhum requisito do FRD ou do NFRD foi encontrado sem origem no PRD (nenhuma extrapolação de escopo identificada).

---

## 14. Achados de Validação

| ID | Severidade | Documento | Seção | Problema | Impacto | Recomendação |
|---|---|---|---|---|---|---|
| FIND-001 | Alta | NFRD | NFRD-SEC-01 | "Senhas armazenadas de forma segura" sem algoritmo de hash nem parâmetros de custo | Engenharia não tem base objetiva para implementar nem QA para validar; risco de escolha insegura em ambiente PCI DSS | Resolver via ADR-0003 sugerido (ver § 18) |
| FIND-002 | Alta | FRD/PRD | FRD-POR-01 / BR-03 | "Senha forte e trocada periodicamente" sem critérios objetivos (comprimento, complexidade, periodicidade) | Sem CA mensurável; risco de implementações divergentes entre módulos | Resolver via ADR-0003 sugerido (ver § 18), consolidado com FIND-001 |
| FIND-003 | Crítica | NFRD | NFRD-RET-01 | Métrica e método de validação em branco; prazo de retenção não definido pelo jurídico | Bloqueia o desenho de expurgo de dados de vendas em ambiente sob escopo PCI DSS; risco de não conformidade regulatória | Resolver via ADR-0004 sugerido (ver § 18) |
| FIND-004 | Alta | NFRD | Cobertura de atributos de qualidade | Ausência de requisito de auditoria/observabilidade de acesso a dados de pagamento, exigido pela rule `security-and-compliance.md` do projeto e coerente com o escopo PCI DSS declarado no PRD | TRD pode ser desenhado sem trilha de auditoria, exigindo retrabalho arquitetural posterior | Achado editável (não exige ADR) — adicionar `NFRD-AUD-01` na próxima rodada do `nfrd-generator`, derivado diretamente da rule do projeto |
| FIND-005 | Média | FRD | FRD-CHB-1 | Identificador não segue a convenção `FRD-XXX-NN` usada nos demais requisitos (`FRD-POR-01..05`) | Prejudica rastreabilidade automatizada e consistência terminológica | Renomear para `FRD-CHB-01` (achado editável) |
| FIND-006 | Média | FRD | FRD-POR-03, FRD-CHB-1, FRD-POR-05 | Ausência de critérios de aceite explícitos | QA não tem base objetiva para validar entrega | Adicionar CA-NN em cada requisito (achado editável, pendente por modo somente-relatório) |
| FIND-007 | Média | FRD | FRD-POR-01, FRD-POR-03, FRD-CHB-1, FRD-POR-05 | Fluxos alternativos/exceção incompletos (recuperação de senha/2FA, exportação vazia, ausência de chargebacks, remoção do único administrador) | Lacunas de UX e de tratamento de erro não previstas para engenharia | Detalhar na próxima rodada do `frd-generator` (não editável diretamente — exige nova rodada) |
| FIND-008 | Baixa | FRD | Matriz de permissões (implícita) | Não fica explícito se o perfil Operador acessa exportação CSV (F3) e chargebacks (F4) | Ambiguidade de autorização a ser resolvida antes do TRD | Explicitar matriz de permissões por perfil na próxima rodada |
| FIND-009 | Baixa | NFRD | NFRD-PERF-01 | Define apenas p95; falta p99 e comportamento acima de 50 mil vendas | Cobertura de performance incompleta para picos | Complementar meta de p99 e teste de volume superior |
| FIND-010 | Média | FRD | MSG-001 | Mensagem de bloqueio não informa tempo restante nem canal de suporte | Usuário bloqueado sem orientação de próximo passo | Enriquecer texto da mensagem (achado editável) |

---

## 15. Métricas da Validação

| Métrica | Quantidade |
|---|---|
| Itens do PRD analisados | 13 |
| Requisitos FRD avaliados | 5 |
| Requisitos NFRD avaliados | 4 |
| Itens cobertos | 6 |
| Itens parcialmente cobertos | 6 |
| Itens não cobertos | 1 |
| Requisitos sem rastreabilidade | 0 (nenhum requisito órfão no FRD/NFRD; 1 item do PRD sem requisito correspondente — PRD-BASE-13) |
| Achados críticos | 1 |
| Achados altos | 3 |
| Achados médios | 4 |
| Achados baixos | 2 |

---

## 16. Pontos a Validar

| Código | Ponto | Documento | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-01 | Disponibilidade, escalabilidade, usabilidade, acessibilidade e backup/recovery não têm menção explícita no PRD nem no NFRD | NFRD | Pode ser lacuna real ou simplesmente fora do escopo desta fase — indefinido | Confirmar com produto se são NFRs aplicáveis antes de `Aprovado para desenvolvimento` |
| VAL-02 | Perfil que pode exportar CSV (F3) e consultar chargebacks (F4) não está explícito | FRD | Ambiguidade de autorização | Confirmar com produto/negócio |
| VAL-03 | Cálculo/contagem do "prazo de defesa" de chargeback não está descrito | FRD | Regra de negócio implícita não detalhada | Levar ao `frd-generator` na próxima rodada, após confirmação com produto |

---

## 17. Parecer Final

### Classificação

**Aprovado com Ressalvas**

### Justificativa

A cobertura funcional macro do PRD está presente e rastreável, sem extrapolação de escopo, o que afasta "Reprovado". Porém há um achado crítico (retenção de dados sem métrica, bloqueado por decisão jurídica pendente) e três achados altos — dois deles convergindo para a mesma decisão arquitetural pendente (política de senha/hash) — que impedem "Aprovado" puro. Conforme § 11.4 do protocolo de validação, a existência de sugestões de ADR de severidade Alta (duas, consolidadas em dois ADRs) exige no mínimo "Aprovado com Ressalvas"; como o número de ADRs Altos é 2 (abaixo do limiar de 3 que sugeriria "Reprovado"), e os demais achados são de severidade média/baixa e corrigíveis por redação, o parecer fica em "Aprovado com Ressalvas".

### Condições para Aprovação

- Resolver ADR-0003 (política de senha e hash de credenciais) e ADR-0004 (política de retenção e expurgo de dados de vendas) antes de `Aprovado para desenvolvimento`.
- Adicionar requisito de auditoria de acesso a dados de pagamento ao NFRD (FIND-004).
- Completar critérios de aceite e fluxos de exceção ausentes (FIND-006, FIND-007) e corrigir o identificador `FRD-CHB-1` (FIND-005).

### Próximos Passos Recomendados

- Abrir os dois ADRs sugeridos com o `adr-writer` (o orquestrador decide a ordem; ambos são pré-requisito para o próximo detalhamento do NFRD).
- Nova rodada do `frd-generator`/`nfrd-generator` para os achados editáveis e de fluxo, respeitando que o Rafael está editando `frd.md`/`nfrd.md` em paralelo — recomenda-se sincronizar antes de aplicar qualquer correção, para não gerar conflito de merge.
- Confirmar com produto os pontos VAL-01 a VAL-03.
- Submeter nova versão para validação após as correções.

---

## 18. ADRs Sugeridos

| ID sugerido | Título proposto | Origem (FIND/VAL) | Severidade | Justificativa breve |
|---|---|---|---|---|
| ADR-0003 | politica-de-senha-e-hash-de-credenciais | FIND-001, FIND-002 | Alta | BR-03 exige "senha forte" sem definir algoritmo de hash, parâmetros de custo, comprimento mínimo ou periodicidade de troca; decisão de segurança com custo de reversão alto em ambiente PCI DSS. |
| ADR-0004 | politica-de-retencao-e-expurgo-de-vendas | FIND-003 | Alta | Prazo de retenção de dados de vendas ainda não definido pelo jurídico; NFRD-RET-01 não pode ser detalhado sem essa decisão regulatória, e o portal está no escopo PCI DSS 4.0.1 da adquirente. |
