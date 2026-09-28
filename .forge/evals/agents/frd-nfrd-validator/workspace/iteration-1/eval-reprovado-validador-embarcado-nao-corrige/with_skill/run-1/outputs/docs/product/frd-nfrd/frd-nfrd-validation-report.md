# FRD/NFRD Validation Report - Validador Embarcado

**Produto:** Validador de tarifa embarcado nos ônibus
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

Reprovado

### Síntese

O FRD cobre apenas 2 das 6 funcionalidades do PRD (F1 e F2, parcialmente) e introduz uma funcionalidade — RF-3, programa de fidelidade — sem qualquer evidência no PRD. As funcionalidades F3 (cartão bancário EMV), F4 (operação offline com lista de bloqueio) e F6 (sincronização) não aparecem no FRD; a regra BR-03 (bloqueio do validador após 72h sem sincronizar) também não é tratada. O NFRD reduz os três atributos de qualidade a frases genéricas ("deve ser rápido", "deve ser seguro", "deve estar sempre disponível"), sem métrica, meta ou método de validação — inclusive o único NFR que o PRD explicita com número (500 ms em 99% dos casos) não foi transposto. O requisito de PCI DSS, também explícito no PRD, não tem cobertura alguma no NFRD. Além disso, RF-1 e NFR-4 descrevem decisões técnicas de implementação (biblioteca, linguagem, versão de SO, stack de orquestração) que pertencem ao TRD, não ao FRD/NFRD. A combinação de ausência de cobertura relevante, extrapolação de escopo e mistura grave entre FRD/NFRD/TRD caracteriza reprovação conforme os critérios da Seção 14 do processo deste agente; por isso nenhuma correção foi aplicada diretamente nos documentos nesta rodada — ver Seção 17.

### Principais Riscos

- Embarque por cartão bancário (F3) e operação offline com lista de bloqueio (F4) — funcionalidades centrais do PRD, incluindo controle de fraude (BR-02, BR-03) — podem ser implementadas de forma incompleta ou não implementadas, pois não existe requisito funcional que as descreva.
- A meta de 500 ms em 99% dos casos, crítica para o produto (validação embarcada em ônibus), não tem requisito não funcional correspondente e pode não ser considerada no desenho técnico nem em testes de aceite.
- Ausência de requisito de PCI DSS no NFRD expõe risco de compliance em um fluxo que processa dados de cartão bancário.
- RF-3 (fidelidade) consome esforço de engenharia em algo que o PRD não pediu, desviando recursos das funcionalidades reprovadas por falta de cobertura.
- RF-1 e NFR-4 fixam decisões técnicas (libnfc/Kotlin/Android 13/Room/WorkManager; Kubernetes/HPA/Istio) antes de existir TRD ou ADR — qualquer mudança de stack decidida depois exige reabrir o FRD/NFRD.

### Principais Recomendações

- Devolver FRD e NFRD para nova rodada do `frd-generator`/`nfrd-generator` cobrindo F3, F4, F5 (correto: integração temporal, não fidelidade), F6, BR-02 e BR-03.
- Adicionar ao NFRD métricas mensuráveis para performance (herdando o alvo do PRD), confiabilidade/durabilidade de transação e segurança/PCI DSS, cada uma com método de validação.
- Mover para o TRD (ou para um ADR, quando a escolha for irreversível) o conteúdo técnico hoje embutido em RF-1 e NFR-4.
- Remover RF-3 do FRD ou, se o programa de fidelidade for uma decisão de produto real, tratá-lo como novo item de PRD antes de virar requisito.
- Abrir ADR para a política de segurança de dados de cartão (tokenização/criptografia conforme PCI DSS) antes da próxima rodada de geração.

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
| PRD-BASE-01 | Objetivo | Objetivo | Validar embarque por cartão de transporte, QR Code e cartão bancário por aproximação (EMV), inclusive sem conexão | PRD §1 |
| PRD-BASE-02 | F1 — Cartão de transporte (MIFARE) | Funcionalidade | Validação de cartão de transporte MIFARE com débito da tarifa no cartão | PRD §2 |
| PRD-BASE-03 | F2 — QR Code | Funcionalidade | Validação de QR Code emitido pelo app da operadora | PRD §2 |
| PRD-BASE-04 | F3 — Cartão bancário EMV | Funcionalidade | Validação de cartão bancário por aproximação (EMV contactless), com cobrança agregada no fim do dia | PRD §2 |
| PRD-BASE-05 | F4 — Operação offline | Funcionalidade | Validar por até 72h sem conexão, com lista de bloqueio local | PRD §2 |
| PRD-BASE-06 | F5 — Integração temporal | Funcionalidade | Segunda viagem em até 60 minutos com desconto de 50% | PRD §2 |
| PRD-BASE-07 | F6 — Sincronização | Funcionalidade | Sincronizar transações com o backend quando houver conexão | PRD §2 |
| PRD-BASE-08 | BR-01 — Tarifas | Regra de negócio | Tarifa cheia R$ 5,00; segunda viagem em até 60 min custa R$ 2,50 | PRD §3 |
| PRD-BASE-09 | BR-02 — Lista de bloqueio | Regra de negócio | Cartão bloqueado é recusado com aviso sonoro e visual | PRD §3 |
| PRD-BASE-10 | BR-03 — Bloqueio por falta de sincronização | Regra de negócio | Transação offline não sincronizada em 72h bloqueia o validador para novas validações EMV | PRD §3 |
| PRD-BASE-11 | Performance | NFR Implícito (explícito no PRD) | Validação concluída em até 500 ms do toque ao sinal verde, em 99% dos casos | PRD §4 |
| PRD-BASE-12 | Confiabilidade/durabilidade | NFR Implícito (explícito no PRD) | Nenhuma transação pode ser perdida entre validação e sincronização | PRD §4 |
| PRD-BASE-13 | Segurança/Compliance | NFR Implícito (explícito no PRD) | Dados de cartão bancário tratados conforme PCI DSS | PRD §4 |

---

## 3. Cobertura PRD → FRD

| Item PRD | Descrição PRD | Requisito FRD Relacionado | Status | Observação |
|---|---|---|---|---|
| PRD-BASE-02 | F1 — validação MIFARE | RF-1 | Parcialmente Coberto | Cobre o fluxo funcional, mas mistura decisão técnica (libnfc, Kotlin, Android 13, Room, WorkManager) que pertence ao TRD |
| PRD-BASE-03 | F2 — validação QR Code | RF-2 | Parcialmente Coberto | Falta débito/verificação de tarifa, fluxos alternativos e de exceção, mensagens de erro |
| PRD-BASE-04 | F3 — cartão bancário EMV | — | Não Coberto | Nenhum requisito funcional trata validação por aproximação EMV nem cobrança agregada fim do dia |
| PRD-BASE-05 | F4 — operação offline (72h + lista de bloqueio) | — | Não Coberto | Nenhum requisito funcional trata modo offline, janela de 72h ou lista de bloqueio local |
| PRD-BASE-06 | F5 — integração temporal (60 min, 50%) | — | Não Coberto | RF-3 não corresponde a este item (ver linha seguinte); F5 permanece sem requisito |
| PRD-BASE-07 | F6 — sincronização com backend | — | Não Coberto | Nenhum requisito funcional trata sincronização |
| — | — | RF-3 — Programa de fidelidade | Extrapolado | Sem evidência no PRD; PRD não menciona pontos, fidelidade ou trocas por viagens grátis |

---

## 4. Cobertura PRD → NFRD

| Item PRD | Atributo Não Funcional Esperado | Requisito NFRD Relacionado | Status | Observação |
|---|---|---|---|---|
| PRD-BASE-11 | Performance (500 ms, p99) | NFR-1 | Não Coberto | "Deve ser rápido" não transpõe a meta numérica nem o percentil do PRD |
| PRD-BASE-13 | Segurança/Compliance (PCI DSS) | NFR-2 | Não Coberto | "Deve ser seguro" não menciona PCI DSS, tokenização, criptografia ou qualquer controle verificável |
| PRD-BASE-09 / disponibilidade operacional | Disponibilidade | NFR-3 | Não Coberto | "Deve estar sempre disponível" sem SLA, sem tratar o cenário offline de 72h descrito no PRD |
| PRD-BASE-12 | Confiabilidade/Durabilidade de transação | — | Não Coberto | Nenhum NFR trata perda zero de transação entre validação e sincronização |
| — | — | NFR-4 — Kubernetes/HPA/Istio no backend | Extrapolado | Decisão de infraestrutura sem origem no PRD; também invade o TRD (ver Seção 7) |

---

## 5. Validação dos Requisitos Funcionais

| Requisito | Clareza | Atomicidade | Testabilidade | Rastreabilidade | Critérios de Aceite | Status | Observação |
|---|---|---|---|---|---|---|---|
| RF-1 | Parcial | Falha | Parcial | OK (F1) | Ausentes | Crítico | Mistura fluxo funcional com stack técnica (TRD); sem critério de aceite mensurável nem tratamento de BR-01/BR-02 |
| RF-2 | Parcial | OK | Falha | OK (F2) | Ausentes | Revisar | Não descreve débito de tarifa, fluxo alternativo/exceção nem mensagem para QR inválido/expirado |
| RF-3 | OK | OK | Parcial | Sem fonte | Ausentes | Remover | Extrapola escopo do PRD (programa de fidelidade não solicitado) |

---

## 6. Validação dos Requisitos Não Funcionais

| Requisito | Clareza | Mensurabilidade | Testabilidade | Rastreabilidade | Categoria | Status | Observação |
|---|---|---|---|---|---|---|---|
| NFR-1 | Falha | Falha | Falha | Implícito (PRD §4) | Performance | Crítico | Sem meta numérica; PRD já define 500 ms / p99 e não foi herdado |
| NFR-2 | Falha | Falha | Falha | Implícito (PRD §4) | Security | Crítico | Sem referência a PCI DSS, apesar de o PRD exigir explicitamente |
| NFR-3 | Falha | Falha | Falha | Sem fonte direta | Availability | Crítico | Sem SLA, sem relação com a janela de operação offline de 72h |
| NFR-4 | OK (redação) | Falha | Parcial | Sem fonte | — (indevido) | Remover | Conteúdo é decisão técnica de infraestrutura (TRD), não requisito não funcional; sem origem no PRD |

---

## 7. Validação de Separação Documental

| Item | Documento Atual | Documento Correto | Problema | Recomendação |
|---|---|---|---|---|
| Biblioteca libnfc 1.8, Kotlin, Android 13, Room 2.6, WorkManager, foreground service | FRD (RF-1) | TRD | Decisão de implementação detalhada dentro do FRD | Mover para TRD; manter em RF-1 apenas o comportamento funcional (ler cartão MIFARE, debitar tarifa, sinalizar embarque) |
| Kubernetes, HPA, Istio no backend de sincronização | NFRD (NFR-4) | TRD | Decisão de infraestrutura/topologia dentro do NFRD | Mover para TRD; se a meta for escalabilidade/resiliência do backend de sincronização, reescrever como atributo de qualidade mensurável (ex.: capacidade de picos, RTO/RPO) sem prescrever a tecnologia |

---

## 8. Validação das Regras de Negócio

| Regra | Fonte PRD | FRD Relacionado | Status | Observação |
|---|---|---|---|---|
| BR-01 — Tarifas (R$ 5,00 / R$ 2,50) | PRD §3 | — | Não Coberta | Nenhum RF menciona valores de tarifa nem a integração temporal de 60 min |
| BR-02 — Lista de bloqueio | PRD §3 | — | Não Coberta | Nenhum RF trata verificação contra lista de bloqueio nem aviso sonoro/visual |
| BR-03 — Bloqueio por falta de sincronização em 72h | PRD §3 | — | Não Coberta | Nenhum RF trata o bloqueio do validador para EMV após 72h sem sincronizar |

---

## 9. Validação de Fluxos Funcionais

| Requisito/Caso de Uso | Fluxo Principal | Alternativos | Exceções | Mensagens | Status | Observação |
|---|---|---|---|---|---|---|
| RF-1 | Parcial | Falha | Falha | Falha | Crítico | Não trata cartão sem saldo, cartão na lista de bloqueio (BR-02) nem falha de leitura |
| RF-2 | Parcial | Falha | Falha | Falha | Revisar | Não trata QR inválido, expirado ou já utilizado |
| RF-3 | — | — | — | — | Ponto a Validar | Fluxo não avaliado por extrapolar escopo (ver Seção 5) |
| F3 (EMV) | Ausente | Ausente | Ausente | Ausente | Crítico | Nenhum requisito funcional existe para este fluxo |
| F4 (offline) | Ausente | Ausente | Ausente | Ausente | Crítico | Nenhum requisito funcional existe para este fluxo |
| F6 (sincronização) | Ausente | Ausente | Ausente | Ausente | Crítico | Nenhum requisito funcional existe para este fluxo |

---

## 10. Validação das Mensagens

| Mensagem | Requisito Relacionado | Clareza | Segurança | Ação para Usuário | Status | Observação |
|---|---|---|---|---|---|---|
| — | RF-1/RF-2 | — | — | — | Crítico | Nenhuma mensagem de erro ou validação está definida no FRD (ex.: cartão bloqueado, QR inválido, saldo insuficiente) |

---

## 11. Validação de Permissões Funcionais

Não aplicável nesta rodada — o PRD não descreve perfis/papéis de usuário além do passageiro embarcando; não há matriz de permissões a validar.

---

## 12. Validação de Atributos de Qualidade

| Atributo | Esperado pelo Produto? | Coberto no NFRD? | Qualidade da Cobertura | Observação |
|---|---|---|---|---|
| Performance | Sim (PRD §4) | Sim | Falha | NFR-1 sem meta numérica; PRD já define 500 ms / p99 |
| Availability | Sim (operação embarcada, offline) | Sim | Falha | NFR-3 sem SLA nem relação com a janela offline de 72h |
| Scalability | Parcial (backend de sincronização) | Sim (indevido) | Falha | NFR-4 prescreve tecnologia (Kubernetes/HPA/Istio) sem meta de qualidade mensurável |
| Resilience | Sim (operação offline até 72h) | Não | Falha | Nenhum requisito trata resiliência do validador embarcado em si |
| Security | Sim (PCI DSS, cartão bancário) | Sim | Falha | NFR-2 genérico, sem PCI DSS |
| Privacy | Parcial (dados de cartão) | Não | Falha | Nenhum requisito de privacidade/minimização de dados |
| Compliance | Sim (PCI DSS) | Não | Falha | PCI DSS citado no PRD e ausente no NFRD |
| Observability | Não explícito, mas relevante para SLA de 99% | Não | — | Ponto a Validar — sem métricas de logs/observação do validador |
| Auditability | Sim (rastreio de transações offline/sync) | Não | Falha | Nenhum requisito de trilha de auditoria para transações offline |
| Usability | Não explícito | Não | — | Ponto a Validar |
| Accessibility | Não explícito | Não | — | Ponto a Validar |
| Maintainability | Não explícito | Não | — | Ponto a Validar |
| Testability | Implícito (produto de segurança/pagamento) | Não | Falha | Nenhum método de validação definido para os três NFR existentes |
| Interoperability | Não explícito | Não | — | Ponto a Validar |
| Backup and Recovery | Parcial (não perder transação) | Não | Falha | PRD-BASE-12 sem cobertura |
| Data Retention | Não explícito | Não | — | Ponto a Validar |
| Operability | Não explícito | Não | — | Ponto a Validar |

---

## 13. Validação da Rastreabilidade

| Item | Tipo | Origem | Destino | Status | Observação |
|---|---|---|---|---|---|
| PRD-BASE-02 | Funcionalidade | PRD | RF-1 | Revisar | Rastreável, mas requisito contaminado por TRD |
| PRD-BASE-03 | Funcionalidade | PRD | RF-2 | Revisar | Rastreável, cobertura parcial |
| PRD-BASE-04 | Funcionalidade | PRD | — | Revisar | Sem destino no FRD |
| PRD-BASE-05 | Funcionalidade | PRD | — | Revisar | Sem destino no FRD |
| PRD-BASE-06 | Funcionalidade | PRD | — | Revisar | Sem destino no FRD |
| PRD-BASE-07 | Funcionalidade | PRD | — | Revisar | Sem destino no FRD |
| RF-3 | Requisito Funcional | Sem fonte | — | Revisar | Requisito órfão/extrapolado |
| PRD-BASE-11 | NFR | PRD | — | Revisar | Sem destino mensurável no NFRD |
| PRD-BASE-12 | NFR | PRD | — | Revisar | Sem destino no NFRD |
| PRD-BASE-13 | NFR | PRD | — | Revisar | Sem destino no NFRD |
| NFR-4 | Requisito Não Funcional | Sem fonte | — | Revisar | Requisito órfão/extrapolado, além de invadir o TRD |

---

## 14. Achados de Validação

| ID | Severidade | Documento | Seção | Problema | Impacto | Recomendação |
|---|---|---|---|---|---|---|
| FIND-001 | Crítica | FRD | RF-1 | Requisito descreve implementação técnica (libnfc 1.8, Kotlin, Android 13, Room 2.6, WorkManager, foreground service) em vez de comportamento funcional | Acopla o FRD a uma escolha de stack ainda não decidida formalmente (sem TRD/ADR); qualquer mudança técnica exige reabrir o FRD | Mover o conteúdo técnico para o TRD; reescrever RF-1 em termos de comportamento (ler cartão MIFARE, validar saldo/bloqueio, debitar tarifa, sinalizar embarque) |
| FIND-002 | Crítica | FRD | Requisitos Funcionais | F3 (cartão bancário EMV) não possui requisito funcional | QA e arquitetura não têm base para implementar ou testar o fluxo de maior sensibilidade (dados de cartão bancário) | Nova rodada do `frd-generator` cobrindo F3, incluindo cobrança agregada no fim do dia |
| FIND-003 | Crítica | FRD | Requisitos Funcionais | F4 (operação offline 72h + lista de bloqueio) não possui requisito funcional | Comportamento crítico de continuidade operacional (72h sem conexão) e antifraude (BR-02) fica sem especificação | Nova rodada do `frd-generator` cobrindo F4, referenciando BR-02 e BR-03 |
| FIND-004 | Crítica | FRD | Requisitos Funcionais | F6 (sincronização com backend) não possui requisito funcional | Sem esse requisito, o fechamento do ciclo offline→online (necessário para BR-03 e para não perder transação) fica indefinido | Nova rodada do `frd-generator` cobrindo F6 |
| FIND-005 | Alta | FRD | Requisitos Funcionais | RF-3 (programa de fidelidade) não tem evidência no PRD; F5 (integração temporal, 60 min, 50%) permanece sem requisito | Esforço de engenharia desviado para funcionalidade não solicitada; regra de negócio real (BR-01, parte da integração temporal) fica sem requisito | Remover RF-3 do FRD; se fidelidade for uma decisão de produto válida, tratar como novo item de PRD antes de gerar requisito; criar requisito para F5/BR-01 |
| FIND-006 | Crítica | NFRD | Requisitos Não Funcionais | NFR-1, NFR-2 e NFR-3 são frases genéricas sem métrica, meta ou método de validação | Impossibilita QA e SRE de aceitar/testar os atributos de qualidade; a meta explícita do PRD (500 ms, p99) se perde | Reescrever os três NFR com métrica, meta numérica (herdando os valores do PRD onde existirem) e método de validação |
| FIND-007 | Crítica | NFRD | Requisitos Não Funcionais | Ausência total de requisito de PCI DSS, apesar de explícito no PRD (§4) | Risco de compliance em fluxo que processa dados de cartão bancário; achado de auditoria PCI DSS previsível | Adicionar NFR de segurança/compliance referenciando PCI DSS; se envolver decisão de algoritmo/tokenização, abrir ADR (ver Seção 18) |
| FIND-008 | Alta | NFRD | Requisitos Não Funcionais | Ausência de requisito de confiabilidade/durabilidade cobrindo "nenhuma transação pode ser perdida" (PRD §4) | Sem esse NFR, o desenho técnico pode não garantir persistência local até a sincronização, violando expectativa explícita do PRD | Adicionar NFR de durabilidade de transação com método de validação (ex.: teste de corte de energia/perda de conexão) |
| FIND-009 | Alta | NFRD | NFR-4 | Requisito prescreve tecnologia de infraestrutura (Kubernetes, HPA, Istio) sem origem no PRD e sem meta de qualidade mensurável | Invade o TRD e fixa decisão técnica sem ADR; mistura decisão de implementação com atributo de qualidade | Mover para o TRD; se necessário, reescrever como atributo de escalabilidade/resiliência mensurável, sem prescrever a tecnologia |
| FIND-010 | Média | FRD | RF-1, RF-2 | Ausência de critérios de aceite objetivos e de fluxos alternativos/de exceção (cartão sem saldo, cartão bloqueado, QR inválido) | QA não consegue derivar casos de teste a partir do requisito | Adicionar critérios de aceite mensuráveis e cobrir os fluxos de exceção associados a BR-02 |

---

## 15. Métricas da Validação

| Métrica | Quantidade |
|---|---|
| Itens do PRD analisados | 13 |
| Requisitos FRD avaliados | 3 |
| Requisitos NFRD avaliados | 4 |
| Itens cobertos | 0 |
| Itens parcialmente cobertos | 2 |
| Itens não cobertos | 9 |
| Requisitos sem rastreabilidade | 2 (RF-3, NFR-4) |
| Achados críticos | 6 |
| Achados altos | 3 |
| Achados médios | 1 |
| Achados baixos | 0 |

---

## 16. Pontos a Validar

| Código | Ponto | Documento | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-01 | RF-3 (fidelidade) é uma funcionalidade real de produto que falta registrar no PRD, ou é extrapolação a remover? | FRD | Define se o item vira novo escopo de PRD ou é descartado | Confirmar com produto antes da próxima rodada de geração |
| VAL-02 | Qual algoritmo/política de proteção de dados de cartão (tokenização, criptografia, escopo PCI) deve reger o NFR de compliance? | NFRD | Bloqueia a redação de um NFR de segurança verificável | Abrir ADR (ver Seção 18) |

---

## 17. Parecer Final

### Classificação

Reprovado

### Justificativa

O FRD não cobre três das seis funcionalidades do PRD (F3, F4, F6) nem duas das três regras de negócio (BR-02, BR-03), e introduz uma funcionalidade sem evidência (RF-3). O NFRD reduz os três atributos de qualidade a frases não mensuráveis e omite por completo o requisito de PCI DSS explícito no PRD. Há, ainda, mistura grave entre FRD/NFRD e TRD (RF-1, NFR-4). Isso satisfaz múltiplos critérios de reprovação da Seção 14 do processo deste agente: ausência relevante de cobertura, mistura grave entre FRD/NFRD/TRD e ausência generalizada de critérios de aceite/métricas. Por essa razão, e conforme a política de aplicação de correções deste agente ("Se o parecer for Reprovado — não aplique correções, devolva para regeneração"), **nenhuma edição foi aplicada em `frd.md` ou `nfrd.md` nesta rodada** — inclusive quanto ao pedido do usuário para completar o FRD a partir do PRD. Completar diretamente um documento reprovado por esse volume de lacunas equivaleria a esta validação escrever a maior parte do FRD/NFRD do zero, o que está fora do escopo deste agente (Seção 2: "não inclui... criar novos requisitos sem evidência" além do estritamente derivável e "corrigir automaticamente os documentos, salvo se solicitado explicitamente" — aqui solicitado, mas bloqueado pelo próprio parecer Reprovado, que é condição de exceção expressa em Seção 12: "Você não deve aplicar correções... quando... o parecer for Reprovado — não aplique correções, devolva para regeneração"). O caminho correto é regenerar os documentos.

### Condições para Aprovação

- Cobrir F3, F4, F5 (correto) e F6 no FRD, incluindo BR-02 e BR-03.
- Remover ou requalificar RF-3 conforme decisão de produto (VAL-01).
- Reescrever NFR-1, NFR-2 e NFR-3 com métrica, meta e método de validação; herdar a meta de 500 ms/p99 do PRD.
- Adicionar NFR de PCI DSS e de durabilidade de transação (FIND-007, FIND-008).
- Mover conteúdo técnico de RF-1 e NFR-4 para o TRD (FIND-001, FIND-009).
- Resolver ADR-0001 sugerido (Seção 18) antes de redigir o NFR de compliance, dado que a severidade Alta bloqueia aprovação mesmo após regeneração (Seção 11.4).

### Próximos Passos Recomendados

- Corrigir achados críticos (FIND-001 a FIND-007) na próxima rodada do `frd-generator`/`nfrd-generator`.
- Abrir o ADR sugerido (Seção 18) antes de redigir o NFR de PCI DSS.
- Revisar rastreabilidade completa após a regeneração.
- Complementar critérios de aceite e fluxos de exceção (FIND-010).
- Complementar métricas não funcionais herdando os valores já explícitos no PRD.
- Submeter nova versão para validação.

---

## 18. ADRs Sugeridos

| ID sugerido | Título proposto | Origem (FIND/VAL) | Severidade | Justificativa breve |
|---|---|---|---|---|
| ADR-0001 | política-protecao-dados-cartao-pci-dss | FIND-007 / VAL-02 | Alta | Define tokenização/criptografia e escopo PCI DSS para dados de cartão bancário; decisão não pode ser inferida do PRD nem resolvida apenas reescrevendo o NFRD |
