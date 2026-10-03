# PRD — Recarga Frota

**Plataforma de recarga de cartões de mobilidade para frotas corporativas**

- **Produto:** Recarga Frota
- **Versão:** 1.3.0
- **Data:** 2026-09-26
- **Status:** Aprovado para desenvolvimento
- **Owner:** Beatriz Nogueira
- **Stakeholders:** Produto, Comercial, Financeiro, Operações, empresas clientes

- **Histórico:**
  - 1.0.0 — 2026-06-02 — aprovado para desenvolvimento
  - 1.1.0 — 2026-07-14 — inclusão do RF-05 (relatório por centro de custo)
  - 1.2.0 — 2026-08-10 — inclusão do KPI-03 e do RISCO-O01
  - 1.3.0 — 2026-09-26 — inclusão da persona P-03 (gestor de frota fretada) e da recarga agendada por veículo com limite mensal, a partir da entrevista de descoberta de 2026-09-22 (`docs/discovery/entrevista-gestores-de-frota-2026-09.md`)

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

Colaboradores pagam pedágio e estacionamento do próprio bolso e pedem reembolso.

### 2.2 Problema a Ser Resolvido

- Reembolso manual lento e sujeito a glosa

### 2.3 Dores Atuais

| Dor | Impacto | Público Afetado | Evidência |
|---|---|---|---|
| Reembolso lento | Insatisfação e retrabalho | P-02 | Entrevistas 2026-05 |
| Reembolso do motorista de frota fretada leva ~12 dias e 18% volta por falta de comprovante | Retrabalho do gestor de frota e atrito com motoristas | P-03 | Entrevista gestores de frota, 2026-09-22 |
| Ausência de recarga programada por veículo com limite mensal | Gestor de frota não consegue controlar orçamento por veículo nem evitar estouro de gasto | P-03 | Entrevista gestores de frota, 2026-09-22 |

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

- **Perfil:** responsável por veículos de frota fretada (ônibus, vans) e pelo abastecimento dos cartões de pedágio e estacionamento usados pelos motoristas; hoje o motorista paga do próprio bolso e pede reembolso
- **Objetivo:** eliminar o reembolso manual do motorista e manter cada veículo com saldo suficiente para a operação, sem estourar o orçamento mensal por veículo
- **Dores:** reembolso lento (média de 12 dias) e alta taxa de glosa por falta de comprovante (18% dos pedidos); falta de controle de gasto por veículo/centro de custo
- **Necessidades:** cadastrar veículos (placa, tipo, centro de custo), programar recarga recorrente por veículo em data fixa, definir limite mensal por veículo com bloqueio automático de nova recarga ao atingir o limite
- **Canais de interação:** portal web
- **Evidência:** Entrevista com Marcos Tavares (Expresso Paraíso, 140 ônibus fretados) e Luana Freitas (Coop. Vans Norte, 60 vans), 2026-09-22 (`docs/discovery/entrevista-gestores-de-frota-2026-09.md`)

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
- Cadastro de veículos de frota fretada (placa, tipo, centro de custo)
- Recarga agendada recorrente por veículo, com data e valor fixos configuráveis pelo gestor de frota
- Limite mensal de recarga por veículo, com bloqueio automático de nova recarga ao atingir o limite

### 5.2 Fora do Escopo

- Cartão de combustível

> **Nota de versão 1.3.0:** a versão 1.2.0 listava "Recarga recorrente" como fora de escopo. A entrevista de descoberta de 2026-09-22 trouxe essa necessidade como prioridade dos gestores de frota fretada; o item foi movido para dentro do escopo (ver 5.1) nesta revisão.

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

P-03 cadastra o veículo (placa, tipo, centro de custo), configura a recarga recorrente (data do mês e valor) e o limite mensal do veículo. No dia configurado, o produto executa a recarga automaticamente; se o limite mensal já tiver sido atingido, o produto bloqueia a nova recarga e notifica P-03.

**Resultado esperado:** veículo com saldo recarregado automaticamente até o limite mensal definido, sem intervenção manual do motorista nem adiantamento de dinheiro próprio.

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

### RF-06 — Cadastro de veículos

O produto deve permitir que P-03 cadastre veículos de frota fretada com placa, tipo e centro de custo.

**Personas impactadas:** P-03

**Documentos filhos relacionados:** `frd.md`

### RF-07 — Recarga agendada por veículo

O produto deve permitir que P-03 configure recarga recorrente por veículo, com data do mês e valor definidos, executada automaticamente pelo produto sem ação manual do motorista.

**Personas impactadas:** P-03

**Documentos filhos relacionados:** `frd.md`

### RF-08 — Limite mensal e bloqueio automático por veículo

O produto deve permitir que P-03 defina um limite mensal de recarga por veículo e deve bloquear automaticamente qualquer nova recarga do veículo no mês corrente ao atingir esse limite, notificando P-03.

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
| RF-07 | Recarga agendada por veículo | Recarga recorrente automática por data e valor | Must | P-03 | frd.md |
| RF-08 | Limite mensal por veículo | Limite mensal com bloqueio automático | Must | P-03 | frd.md |

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
| LAC-03 | Possível exigência da ANTT sobre registro de viagens fretadas, mencionada por gestor de frota sem detalhamento (fonte: entrevista 2026-09-22) | Pode impactar RF-06/RF-07 se houver obrigação regulatória de rastreabilidade da viagem | Jurídico/Regulatório | Aberto |
| LAC-04 | Forma de pagamento da recarga agendada (saldo pré-pago da empresa vs. boleto por ciclo, dúvida levantada por gestor de frota sem financeiro presente na entrevista) | Define o modelo financeiro de RF-07 e pode exigir novo fluxo de pagamento além do boleto (RF-04) | Financeiro | Aberto |

---

## 10. Riscos e Mitigações

### RISCO-O01 — Atraso de compensação de boleto

- **Descrição:** crédito atrasa se o boleto compensar após o corte
- **Probabilidade:** Média
- **Impacto:** Médio
- **Mitigação:** aviso de corte no pedido
- **Responsável:** Operações
- **Indicador de monitoramento:** % de pedidos creditados após D+2

### RISCO-O02 — Recarga agendada executar acima do limite mensal do veículo

- **Descrição:** falha na checagem de limite antes da execução da recarga recorrente (RF-07/RF-08) gera cobrança acima do orçamento aprovado pelo cliente para o veículo
- **Probabilidade:** Baixa
- **Impacto:** Alto
- **Mitigação:** validar o limite mensal no momento da execução da recarga agendada, não apenas no cadastro, e bloquear/registrar a tentativa excedente
- **Responsável:** Engenharia
- **Indicador de monitoramento:** número de recargas agendadas executadas acima do limite mensal do veículo

---

## 11. Métricas de Sucesso

| Código | KPI | Objetivo Relacionado | Meta | Fonte | Periodicidade |
|---|---|---|---|---|---|
| KPI-01 | % despesas via recarga direta | OBJ-01 | 80% | Portal | Mensal |
| KPI-02 | % pedidos com centro de custo | OBJ-02 | 100% | Portal | Mensal |
| KPI-03 | Pedidos creditados até D+2 | OBJ-01 | 95% | Portal | Semanal |
| KPI-04 | % de veículos de frota fretada com recarga agendada ativa | OBJ-01 | 60% em 6 meses após lançamento | Portal | Mensal |

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
| Frota fretada | Conjunto de veículos (ônibus, vans) usados por empresas de fretamento para transporte de passageiros a serviço de um cliente |
| Recarga agendada | Recarga recorrente configurada por veículo, executada automaticamente pelo produto em data fixa do mês, respeitando o limite mensal do veículo |
