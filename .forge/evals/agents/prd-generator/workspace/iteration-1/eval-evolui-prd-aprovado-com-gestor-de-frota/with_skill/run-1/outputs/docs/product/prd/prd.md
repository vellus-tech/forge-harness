# PRD — Recarga Frota

**Plataforma de recarga de cartões de mobilidade para frotas corporativas**

- **Produto:** Recarga Frota
- **Versão:** 1.3.0
- **Data:** 2026-09-26
- **Status:** Aprovado para desenvolvimento
- **Owner:** Beatriz Nogueira
- **Stakeholders:** Produto, Comercial, Financeiro, Operações, empresas clientes, empresas de frota fretada

- **Histórico:**
  - 1.0.0 — 2026-06-02 — aprovado para desenvolvimento
  - 1.1.0 — 2026-07-14 — inclusão do RF-05 (relatório por centro de custo)
  - 1.2.0 — 2026-08-10 — inclusão do KPI-03 e do RISCO-O01
  - 1.3.0 — 2026-09-26 — inclusão da persona P-03 (gestor de frota fretada) e dos RF-06/RF-07 (cadastro de veículos e recarga agendada por veículo com limite mensal), a partir da entrevista de 2026-09 com gestores de frota

---

## Sumário

1. Resumo Executivo
2. Contexto e Problema
3. Personas
4. Visão do Produto e Objetivos
5. Escopo do Produto
6. Jornadas de Usuário
7. Requisitos Funcionais
8. Requisitos Não Funcionais
9. Restrições, Premissas e Lacunas
10. Riscos e Mitigações
11. Métricas de Sucesso
12. Documentos Relacionados
13. Anexos

---

## 1. Resumo Executivo

### 1.1 Descrição do Produto

**Recarga Frota** é um portal B2B para empresas recarregarem, por pedido avulso, cartões de mobilidade (pedágio e estacionamento) usados por colaboradores em deslocamentos a serviço.

### 1.2 Proposta de Valor

- Eliminar o adiantamento de dinheiro pelo colaborador
- Centralizar pedidos e comprovantes por centro de custo

### 1.3 Justificativa Estratégica

- 22 clientes corporativos pediram a funcionalidade em 2026-T1 (fonte: CRM comercial)

### 1.4 Resultado Esperado

Empresas clientes recarregam cartões sem reembolso manual, com comprovante por pedido.

---

## 2. Contexto e Problema

### 2.1 Contexto Atual

Colaboradores pagam pedágio e estacionamento do próprio bolso e pedem reembolso. Em empresas de frota fretada (ônibus e vans), o motorista abastece os cartões de pedágio e estacionamento com dinheiro próprio, e o gestor de frota depende do mesmo fluxo manual de reembolso para repor esse gasto por veículo.

### 2.2 Problema a Ser Resolvido

- Reembolso manual lento e sujeito a glosa
- Na frota fretada, o reembolso ao motorista leva em média 12 dias e 18% dos pedidos retornam por falta de comprovante (Entrevista 2026-09)

### 2.3 Dores Atuais

| Dor | Impacto | Público Afetado | Evidência |
|---|---|---|---|
| Reembolso lento | Insatisfação e retrabalho | P-02 | Entrevistas 2026-05 |
| Reembolso do motorista de frota fretada lento e com glosa recorrente | Ciclo médio de 12 dias e 18% dos pedidos devolvidos por falta de comprovante | P-03 | Entrevista 2026-09 (Marcos Tavares — Expresso Paraíso; Luana Freitas — Coop. Vans Norte) |

### 2.4 Oportunidade

Oferecer recarga direta paga pela empresa.

### 2.5 Sistemas, Processos ou Soluções Existentes

| Sistema/Processo Atual | Responsável | Limitação | Estratégia |
|---|---|---|---|
| Planilha de reembolso | Financeiro do cliente | Manual | Substituir |

---

## 3. Personas

### P-01 — Administrador financeiro da empresa cliente

- **Perfil:** responsável por aprovar e pagar pedidos de recarga
- **Objetivo:** controlar gasto por centro de custo
- **Dores:** falta de visibilidade do gasto
- **Necessidades:** relatório por centro de custo
- **Canais de interação:** portal web

### P-02 — Colaborador em deslocamento

- **Perfil:** usa cartão de pedágio/estacionamento em viagens a serviço
- **Objetivo:** não adiantar dinheiro próprio
- **Dores:** reembolso lento
- **Necessidades:** saldo disponível antes da viagem
- **Canais de interação:** app

### P-03 — Gestor de frota fretada

- **Perfil:** responsável pelos veículos de uma frota fretada (ônibus ou vans) e pelo reembolso de pedágio/estacionamento dos motoristas; hoje repõe esses gastos manualmente por veículo
- **Objetivo:** garantir saldo de pedágio/estacionamento por veículo sem depender de reembolso ao motorista
- **Dores:** reembolso lento (média de 12 dias) e alto índice de glosa por falta de comprovante (18% dos pedidos)
- **Necessidades:** cadastrar veículos por placa, tipo e centro de custo; programar recarga recorrente por veículo com limite mensal
- **Canais de interação:** portal web

---

## 4. Visão do Produto e Objetivos

### 4.1 Visão

Ser o meio padrão de recarga corporativa de cartões de mobilidade.

### 4.2 Objetivos Estratégicos

### OBJ-01 — Reduzir reembolsos manuais

- **Resultado esperado:** 80% das despesas de pedágio/estacionamento dos clientes pagas via recarga direta
- **Indicador associado:** KPI-01
- **Prazo alvo:** 2026-12

### OBJ-02 — Visibilidade de gasto

- **Resultado esperado:** 100% dos pedidos com centro de custo
- **Indicador associado:** KPI-02
- **Prazo alvo:** 2026-10

### 4.3 Objetivos Não Atendidos

- Recarga de combustível

---

## 5. Escopo do Produto

### 5.1 Dentro do Escopo

- Pedido avulso de recarga, aprovação, pagamento por boleto, comprovante, relatório por centro de custo
- Cadastro de veículos por placa, tipo e centro de custo, e recarga agendada por veículo com limite mensal e bloqueio automático ao atingir o limite

### 5.2 Fora do Escopo

- Cartão de combustível

### 5.3 Escopo Futuro / Roadmap Evolutivo

| Item | Descrição | Justificativa | Prioridade |
|---|---|---|---|
| Pix | Pagamento por Pix | Pedido comercial | Média |

---

## 6. Jornadas de Usuário

### Jornada J-01 — Pedido avulso de recarga

P-01 cria o pedido, informa cartões e valores, aprova, paga por boleto e acompanha até o crédito.

**Resultado esperado:** cartões creditados após a compensação do boleto.

### Jornada J-02 — Consulta de comprovantes

P-01 consulta e exporta comprovantes por período e centro de custo.

**Resultado esperado:** comprovante disponível por pedido.

### Jornada J-03 — Recarga agendada por veículo

P-03 cadastra os veículos da frota (placa, tipo, centro de custo), define um valor e uma recorrência de recarga por veículo e um limite mensal. O sistema executa a recarga programada e bloqueia automaticamente novas recargas do veículo ao atingir o limite do mês.

**Resultado esperado:** cartões dos veículos recarregados na recorrência definida, sem reembolso manual ao motorista, respeitando o limite mensal por veículo.

---

## 7. Requisitos Funcionais

### RF-01 — Cadastro de cartões

O produto deve permitir que P-01 cadastre cartões de mobilidade vinculados a colaboradores e centros de custo.

**Personas impactadas:** P-01

**Documentos filhos relacionados:** `frd.md`

### RF-02 — Pedido avulso de recarga

O produto deve permitir que P-01 crie pedidos de recarga informando cartão e valor.

**Personas impactadas:** P-01, P-02

**Documentos filhos relacionados:** `frd.md`

### RF-03 — Aprovação de pedido

O produto deve exigir aprovação de P-01 antes da geração do pagamento.

**Personas impactadas:** P-01

**Documentos filhos relacionados:** `frd.md`

### RF-04 — Pagamento por boleto

O produto deve gerar boleto por pedido aprovado e creditar os cartões após a compensação.

**Personas impactadas:** P-01

**Documentos filhos relacionados:** `frd.md`

### RF-05 — Relatório por centro de custo

O produto deve gerar relatório de recargas por centro de custo e período, exportável.

**Personas impactadas:** P-01

**Documentos filhos relacionados:** `frd.md`

### RF-06 — Cadastro de veículos da frota

O produto deve permitir que P-03 cadastre veículos da frota, informando placa, tipo e centro de custo.

**Personas impactadas:** P-03

**Documentos filhos relacionados:** `frd.md`

### RF-07 — Recarga agendada por veículo com limite mensal

O produto deve permitir que P-03 programe recargas recorrentes por veículo, com valor, recorrência e limite mensal, e deve bloquear automaticamente novas recargas do veículo ao atingir o limite do mês.

**Personas impactadas:** P-03

**Documentos filhos relacionados:** `frd.md`

### 7.1 Matriz Resumida de Requisitos Funcionais

| Código | Requisito | Descrição Resumida | Prioridade | Persona Principal | Documento Detalhado |
|---|---|---|---|---|---|
| RF-01 | Cadastro de cartões | Cartões por colaborador e centro de custo | Must | P-01 | frd.md |
| RF-02 | Pedido avulso | Pedido com cartão e valor | Must | P-01 | frd.md |
| RF-03 | Aprovação | Aprovação antes do pagamento | Must | P-01 | frd.md |
| RF-04 | Boleto | Boleto por pedido | Must | P-01 | frd.md |
| RF-05 | Relatório | Relatório por centro de custo | Should | P-01 | frd.md |
| RF-06 | Cadastro de veículos | Veículos por placa, tipo e centro de custo | Must | P-03 | frd.md |
| RF-07 | Recarga agendada por veículo | Recorrência com limite mensal e bloqueio automático | Must | P-03 | frd.md |

---

## 8. Requisitos Não Funcionais

Detalhamento em `nfrd.md`. Metas de disponibilidade e performance registradas como LAC-01.

---

## 9. Restrições, Premissas e Lacunas

### 9.1 Restrições

### REST-01 — Emissores de cartão homologados

- **Origem:** contrato comercial
- **Impacto:** apenas cartões dos emissores parceiros
- **Consequência se não atendida:** recarga rejeitada

### 9.2 Premissas

### PRM-01 — Emissores aceitam crédito em lote

- **Dependência associada:** emissores parceiros
- **Impacto se a premissa falhar:** crédito unitário, prazo maior

### 9.3 Lacunas e Pontos a Validar

| Código | Lacuna ou Ponto a Validar | Impacto Potencial | Responsável pela Validação | Status |
|---|---|---|---|---|
| LAC-01 | Metas de disponibilidade e performance | NFRD incompleto | Engenharia | Aberto |
| LAC-02 | Prazo contratual de crédito pelos emissores | Promessa ao cliente | Comercial | Aberto |
| LAC-03 | Gestor de frota mencionou possível exigência da ANTT sobre registro de viagens fretadas, sem saber qual norma; não confirmado nos insumos | Pode impactar escopo ou compliance de RF-06/RF-07 se confirmado | Compliance | Aberto |
| LAC-04 | Origem do pagamento da recarga agendada — saldo pré-pago da empresa (pergunta de Luana Freitas) vs. boleto por ciclo (modelo atual do RF-04) — não respondido pelo Financeiro na entrevista | Define o fluxo de pagamento e liquidação de RF-07 | Financeiro | Aberto |

---

## 10. Riscos e Mitigações

### RISCO-O01 — Atraso de compensação de boleto

- **Descrição:** crédito atrasa se o boleto compensar após o corte
- **Probabilidade:** Média
- **Impacto:** Médio
- **Mitigação:** aviso de corte no pedido
- **Responsável:** Operações
- **Indicador de monitoramento:** % de pedidos creditados após D+2

---

## 11. Métricas de Sucesso

| Código | KPI | Objetivo Relacionado | Meta | Fonte | Periodicidade |
|---|---|---|---|---|---|
| KPI-01 | % despesas via recarga direta | OBJ-01 | 80% | Portal | Mensal |
| KPI-02 | % pedidos com centro de custo | OBJ-02 | 100% | Portal | Mensal |
| KPI-03 | Pedidos creditados até D+2 | OBJ-01 | 95% | Portal | Semanal |

---

## 12. Documentos Relacionados

| Documento | Descrição | Status |
|---|---|---|
| `frd.md` | Requisitos Funcionais Detalhados | Em elaboração |
| `nfrd.md` | Requisitos Não Funcionais Detalhados | Pendente |
| `TRD.md` | Requisitos Técnicos | Pendente |
| `ADR.md` | Decisões Arquiteturais | Não aplicável até o momento |
| `UXD.md` | Experiência do Usuário | Pendente |

---

## 13. Anexos

### Anexo A — Glossário

| Termo | Definição |
|---|---|
| Centro de custo | Unidade contábil do cliente para alocação de despesa |
