# Discovery Notes

**Produto:** Pátio Digital
**Tipo de iniciativa:** Greenfield
**Data:** 2026-09-26
**Status:** Em discovery

---

## 0. Workspace Scan

### 0.1 Diretórios e Arquivos Relevantes

| Caminho | Tipo | Contexto Oferecido |
|---|---|---|
| `discovery-notes.md` (raiz) | Documento legado | Rascunho de discovery iniciado em março, com problema e usuário já descritos e stack/monetização em aberto |
| `README.md` | Documento | Confirma o nome do produto (Pátio Digital) e o resumo de uma linha: controle digital de saída de frota nas garagens da Viação Norte |
| `AGENTS.md` / `.forge/` | Scaffolding do harness | Convenções operacionais e pipeline de especificação do projeto; não contém decisões de produto |

### 0.2 Resumo do Contexto Existente

O repositório já tinha um discovery iniciado em março, registrado num `discovery-notes.md` solto na raiz (fora do caminho oficial `docs/discovery/`). Esse rascunho descreve o problema (fiscais de pátio anotam saída de ônibus em prancheta e digitam depois, atraso só percebido no dia seguinte) e o usuário (fiscal de pátio, em pé, possivelmente com luva e sol forte na tela), mas deixava stack e monetização como "a definir" / "aparentemente". Não há código de produto (`src/`, `app/`, etc.) no workspace — apenas o scaffolding do harness. O usuário, ao retomar, confirmou o modelo de uso interno sem cobrança e informou que a TI da Viação Norte pediu PWA com React.

### 0.3 Lacunas Identificadas

- Usuário principal ainda não confirmado diretamente nesta retomada (só existia no rascunho de março).
- Referências de produtos/fluxos parecidos não levantadas.
- Pitch ainda não sintetizado nem validado.
- Core features (as 3 principais ações) não levantadas.
- Integrações com sistemas externos não levantadas.
- Planos/tiers não se aplicam (modelo é uso interno sem cobrança).
- Referências visuais e notas adicionais não levantadas.

---

## 1. Visão

### 1.1 Problema

Os fiscais de pátio da Viação Norte registram em prancheta a saída de cada ônibus da garagem e depois digitam tudo numa planilha no fim do turno. Atrasos na saída só são percebidos no dia seguinte.

### 1.2 Usuário Principal

*(Pendente de confirmação nesta retomada — ver VAL-001. O rascunho de março descrevia: fiscal de pátio, trabalha em pé no pátio da garagem, possivelmente com luva e sol forte na tela.)*

### 1.3 Referências

*(Pendente — Q3 ainda não respondida nesta retomada.)*

### 1.4 Pitch

*(Pendente — síntese ocorre após Q3.)*

---

## 2. Funcionalidades

### 2.1 Core Features

*(Pendente — Q4 ainda não respondida nesta retomada.)*

### 2.2 Integrações

*(Pendente — Q5 ainda não respondida nesta retomada.)*

---

## 3. Monetização

### 3.1 Modelo

Uso interno, sem cobrança.

### 3.2 Planos

Não aplicável ao modelo de monetização informado.

---

## 4. Técnico

### 4.1 Stack

React, no front-end, por solicitação da TI da Viação Norte.

### 4.2 Plataforma

PWA (Progressive Web App), por solicitação da TI da Viação Norte.

---

## 5. Contexto

### 5.1 Referências Visuais

*(Pendente — Q10 ainda não respondida nesta retomada.)*

### 5.2 Notas Adicionais

*(Pendente — Q11 ainda não respondida nesta retomada.)*

---

## 6. Decisões Registradas

| Código | Decisão | Origem | Impacto |
|---|---|---|---|
| DEC-001 | O produto será de uso interno, sem cobrança (sem modelo de monetização). | Retomada do discovery (mensagem do usuário) | Dispensa Q7 (planos); orienta escopo de PRD sem billing |
| DEC-002 | A plataforma será PWA, atendendo pedido da TI da Viação Norte. | Retomada do discovery (mensagem do usuário) | Orienta plataforma inicial e escopo técnico do PRD |
| DEC-003 | A stack de front-end será React, atendendo pedido da TI da Viação Norte. | Retomada do discovery (mensagem do usuário) | Orienta stack no PRD/TRD; a decidir ainda backend, banco de dados e hospedagem |

---

## 7. Pontos a Validar

| Código | Ponto | Motivo | Impacto |
|---|---|---|---|
| VAL-001 | Confirmar com o usuário se o usuário principal continua sendo "fiscal de pátio", conforme descrito no rascunho de março, e detalhar seu dia a dia atual. | O rascunho de março não foi revalidado nesta retomada; a regra do agente exige confirmação explícita mesmo quando o workspace já traz a informação. | Impacta Visão > Usuário Principal e o pitch |
| VAL-002 | Levantar produto, sistema ou fluxo de referência (Q3) para orientar o pitch. | Ainda não perguntado nesta retomada. | Impacta Visão > Referências e Visão > Pitch |
| VAL-003 | Levantar as 3 principais ações do usuário no produto (Q4). | Ainda não perguntado nesta retomada. | Impacta Funcionalidades > Core Features |
| VAL-004 | Levantar integrações externas necessárias (Q5), por exemplo com sistemas já usados pela Viação Norte. | Ainda não perguntado nesta retomada. | Impacta Funcionalidades > Integrações |
| VAL-005 | Levantar referências visuais (wireframe, Figma, fluxo) e notas adicionais (prazo, restrições, decisões já tomadas) (Q10/Q11). | Ainda não perguntado nesta retomada. | Impacta Contexto e Resumo Final do Discovery |

---

## 8. Resumo Final do Discovery

### 8.1 Resumo por Blocos

Discovery retomado a partir do rascunho de março. Problema, monetização e parte do técnico (plataforma e stack de front-end) já estão decididos. Usuário principal, referências, pitch, core features, integrações, referências visuais e notas adicionais seguem em aberto — a próxima pergunta obrigatória é a Q2 (usuário principal), para revalidar o que o rascunho de março já indicava.

### 8.2 Confirmação do Usuário

*(Pendente — discovery ainda não concluído.)*

### 8.3 Status

Em discovery
