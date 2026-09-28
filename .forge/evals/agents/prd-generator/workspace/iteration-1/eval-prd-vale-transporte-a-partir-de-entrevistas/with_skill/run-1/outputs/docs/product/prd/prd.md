# PRD — Portal VT Corporativo

**Portal web B2B para recarga de vale-transporte de colaboradores nos cartões de bilhetagem**

- **Produto:** Portal VT Corporativo
- **Versão:** 0.1
- **Data:** 2026-09-26
- **Status:** Rascunho
- **Owner:** Patrícia Lemos
- **Stakeholders:** RH/Departamento Pessoal das empresas clientes, área financeira das empresas clientes, colaboradores das empresas clientes, Consórcio Metropolitano de Transportes (CMT, operadora de bilhetagem parceira), jurídico/compliance interno, engenharia (tech lead do workshop de 2026-09-15)

- **Histórico:**
  - v0.1 — versão inicial do documento, produzida a partir de três entrevistas com clientes, do workshop de jornadas de 2026-09-15 e das notas de discovery

---

## Sumário

1. [Resumo Executivo](#1-resumo-executivo)
2. [Contexto e Problema](#2-contexto-e-problema)
3. [Personas](#3-personas)
4. [Visão do Produto e Objetivos](#4-visão-do-produto-e-objetivos)
5. [Escopo do Produto](#5-escopo-do-produto)
6. [Jornadas de Usuário](#6-jornadas-de-usuário)
7. [Requisitos Funcionais](#7-requisitos-funcionais)
8. [Requisitos Não Funcionais](#8-requisitos-não-funcionais)
9. [Restrições, Premissas e Lacunas](#9-restrições-premissas-e-lacunas)
10. [Riscos e Mitigações](#10-riscos-e-mitigações)
11. [Métricas de Sucesso](#11-métricas-de-sucesso)
12. [Documentos Relacionados](#12-documentos-relacionados)
13. [Anexos](#13-anexos)

> **Detalhamento em documentos filhos:**
>
> - `frd.md` — regras de negócio, fluxos funcionais, validações, mensagens, exceções e critérios de aceite por funcionalidade
> - `nfrd.md` — performance, disponibilidade, segurança, compliance, observabilidade, escalabilidade e capacidade
> - `TRD.md` — arquitetura técnica, integrações, APIs, contratos, infraestrutura, persistência, mensageria e padrões técnicos (inclui o desenho preliminar do tech lead — API de pedidos, persistência relacional e fila assíncrona para envio ao CMT — apresentado no workshop de 2026-09-15 e ainda não formalizado)
> - `ADR.md` — decisões arquiteturais relevantes, quando aplicável
> - `UXD.md` — fluxos de experiência, wireframes, protótipos e diretrizes de interface, quando aplicável

---

## 1. Resumo Executivo

### 1.1 Descrição do Produto

O Portal VT Corporativo é uma plataforma web B2B voltada para empresas clientes que precisam comprar e distribuir recargas de vale-transporte para seus colaboradores, integrada à operadora de bilhetagem Consórcio Metropolitano de Transportes (CMT). O produto substitui o processo manual atual — planilha exportada do sistema de folha, conferência manual de elegibilidade e upload de CSV no portal da operadora — por um fluxo digital de pedido, pagamento, acompanhamento e conciliação.

### 1.2 Proposta de Valor

O produto entrega valor ao permitir:

- Eliminar a conferência manual de elegibilidade e a montagem manual do arquivo de recarga, hoje feitas mensalmente pelo analista de DP.
- Identificar e comunicar no mesmo dia as linhas de pedido rejeitadas (CPF inválido, cartão bloqueado, colaborador desligado), evitando que colaboradores fiquem sem recarga sem aviso prévio.
- Consolidar pedidos de recarga de múltiplos CNPJs de um mesmo grupo empresarial em um único fluxo de pagamento e acompanhamento.
- Dar visibilidade ao financeiro do status do pagamento até o crédito efetivo no cartão do colaborador, e permitir a conciliação entre valor pago e valor creditado por colaborador e por centro de custo.

### 1.3 Justificativa Estratégica

Este produto é estratégico porque:

- O processo manual atual já produz falhas com impacto direto ao colaborador: em agosto de 2026, 37 colaboradores da Transportadora Rio Doce ficaram sem recarga por um CSV rejeitado sem aviso prévio.
- Falhas de conciliação geram custo operacional relevante: o Grupo Serra Verde levou três semanas para explicar uma diferença de R$ 4.180 entre valor pago e valor creditado em julho de 2026.
- Há meta comercial definida de crescer de 14 para 40 empresas clientes no portal até março de 2027 (fonte: planejamento comercial de 2026-09), o que exige um produto autoatendido, e não mais o processo manual por CSV.

### 1.4 Resultado Esperado

Ao final da implantação, espera-se que as empresas clientes sejam capazes de realizar o pedido mensal de recarga, corrigir e reenviar apenas as linhas rejeitadas, e conciliar o valor pago com o valor creditado, sem depender de conferência manual de planilhas ou de upload de arquivos, com redução do tempo de processamento hoje registrado em até 2 dias úteis por mês e sem recargas perdidas por erro de formato de dado não comunicado a tempo.

---

## 2. Contexto e Problema

### 2.1 Contexto Atual

Hoje, 14 empresas clientes usam um processo manual baseado em planilha e arquivo CSV para solicitar recarga de vale-transporte para seus colaboradores junto à operadora CMT. Incluindo, conforme relatado nas entrevistas de discovery:

- O analista de DP exporta mensalmente a planilha de colaboradores do sistema de folha da empresa cliente e confere manualmente elegibilidade e quantidade de passagens por colaborador.
- O arquivo CSV resultante é enviado por upload ao portal da operadora CMT; falhas de formato (por exemplo, CPF com máscara) só são percebidas quando o colaborador reclama na catraca.
- O pagamento é feito por boleto, um por CNPJ, com repasse à operadora em D+2; atraso no boleto atrasa a recarga do mês inteiro.
- Empresas com múltiplos CNPJs (caso do Grupo Serra Verde, com 4 CNPJs) não têm hoje um fluxo consolidado de pedido e pagamento.
- Não há hoje conciliação automatizada entre o valor pago pela empresa cliente e o valor efetivamente creditado no cartão de cada colaborador.
- A operadora parceira inicial do portal é a CMT; não há, até o momento, acordo comercial ou técnico com outras operadoras de bilhetagem.

### 2.2 Problema a Ser Resolvido

Atualmente, as empresas clientes enfrentam os seguintes problemas:

- O processo de pedido mensal de recarga é manual, leva em média 2 dias úteis por mês (relato da Transportadora Rio Doce) e depende de conferência humana de planilha.
- Rejeições de linhas do arquivo de recarga (por exemplo, por erro de formato de CPF) não são comunicadas no mesmo dia, e só aparecem quando o colaborador já foi prejudicado na catraca.
- Empresas com múltiplos CNPJs não conseguem consolidar o pedido nem o acompanhamento de pagamento em um único fluxo.
- Não há visibilidade de conciliação entre o valor pago e o valor efetivamente creditado, o que já gerou divergência de R$ 4.180 em um único mês para um cliente.
- Colaboradores não são avisados quando a recarga é creditada, descobrindo apenas ao usar a catraca.

### 2.3 Dores Atuais

| Dor | Impacto | Público Afetado | Evidência |
|---|---|---|---|
| CSV rejeitado por erro de formato (CPF com máscara) sem aviso no mesmo dia | 37 colaboradores sem recarga em agosto/2026 na Transportadora Rio Doce | Analista de DP (P-01), colaboradores (P-03) | Entrevista 1 — Clara Mendes |
| Processo manual mensal de conferência e upload de CSV | Consome em média 2 dias úteis por mês do analista de DP | Analista de DP (P-01) | Entrevista 1 — Clara Mendes |
| Boleto por CNPJ com repasse em D+2; atraso no boleto atrasa a recarga do mês inteiro | Recarga de todo o mês atrasada por atraso de um dia no boleto | Gerente financeiro (P-02), colaboradores (P-03) | Entrevista 2 — Rogério Alves |
| Falta de conciliação entre valor pago e valor creditado | Divergência de R$ 4.180 em julho/2026, com 3 semanas para explicar | Gerente financeiro (P-02) | Entrevista 2 — Rogério Alves |
| Ausência de aviso ao colaborador sobre o crédito da recarga | Colaborador só descobre o crédito na catraca | Colaborador (P-03) | Entrevista 3 — Denise Couto |

### 2.4 Oportunidade

A oportunidade consiste em substituir o processo manual por planilha e CSV por um portal autoatendido de pedido, pagamento e conciliação de recarga de vale-transporte, permitindo reduzir o tempo de processamento mensal, eliminar recargas perdidas por erro de formato não comunicado e dar visibilidade financeira ponta a ponta, por meio de um fluxo digital com validação prévia de dados, consolidação multi-CNPJ e conciliação automatizada.

### 2.5 Sistemas, Processos ou Soluções Existentes

| Sistema/Processo Atual | Responsável | Limitação | Estratégia |
|---|---|---|---|
| Exportação manual de planilha do sistema de folha + upload de CSV no portal da operadora CMT | Analista de DP de cada empresa cliente | Processo manual, sem validação prévia, sem retorno no mesmo dia sobre rejeições | Substituir pelo Portal VT Corporativo |
| Pagamento por boleto, um por CNPJ, sem consolidação para grupos multi-CNPJ | Área financeira de cada empresa cliente | Sem consolidação entre CNPJs, sem acompanhamento de status até o crédito | Substituir pelo Portal VT Corporativo |

---

## 3. Personas

> Personas representam usuários, operadores, clientes, administradores, auditores, sistemas externos ou outros atores relevantes para o produto.

### P-01 — Analista de DP da empresa cliente

Responsável por levantar mensalmente quem tem direito a vale-transporte na empresa e solicitar a recarga junto à operadora. Exemplo de discovery: Clara Mendes, analista de DP da Transportadora Rio Doce (820 colaboradores).

- **Perfil:** Colaborador da área de Departamento Pessoal da empresa cliente, responsável pelo pedido mensal de recarga.
- **Objetivo:** Solicitar a recarga de vale-transporte de todos os colaboradores elegíveis, com o mínimo de retrabalho manual.
- **Dores:** Conferência manual de elegibilidade e valores; rejeições de CSV sem aviso no mesmo dia; falta de relatório por centro de custo para o financeiro.
- **Necessidades:** Importação e revisão de colaboradores, aviso no mesmo dia sobre linhas rejeitadas e por quê, relatório por centro de custo.
- **Canais de interação:** Portal web.

### P-02 — Gerente financeiro da empresa cliente

Responsável por pagar a recarga solicitada e conciliar o valor pago com o valor creditado. Exemplo de discovery: Rogério Alves, gerente financeiro do Grupo Serra Verde (2.300 colaboradores, 4 CNPJs).

- **Perfil:** Colaborador da área financeira da empresa cliente, responsável pelo pagamento e pela conciliação.
- **Objetivo:** Consolidar o pedido de recarga entre múltiplos CNPJs do grupo, acompanhar o pagamento até o crédito e conciliar valores.
- **Dores:** Pagamento por boleto separado por CNPJ; atraso no boleto atrasando a recarga do mês inteiro; impossibilidade de conciliar valor pago com valor creditado.
- **Necessidades:** Pedido consolidado multi-CNPJ, acompanhamento de status do pagamento até o crédito, relatório de conciliação por colaborador e por centro de custo.
- **Canais de interação:** Portal web.

### P-03 — Colaborador da empresa cliente

Usuário final que recebe a recarga de vale-transporte no cartão de bilhetagem. Exemplo de discovery: Denise Couto, operadora de caixa da Rede Bom Preço.

- **Perfil:** Colaborador da empresa cliente, usuário do vale-transporte no cartão de bilhetagem do CMT.
- **Objetivo:** Ter a recarga do mês disponível no cartão a tempo de usar o transporte.
- **Dores:** Só descobre que a recarga não caiu quando chega na catraca; não recebe aviso de crédito.
- **Necessidades:** Aviso de que a recarga foi creditada.
- **Canais de interação:** Não especificado nos insumos de discovery para esta persona; ver **LAC-04**.

---

## 4. Visão do Produto e Objetivos

### 4.1 Visão

Ser o portal de referência para recarga de vale-transporte corporativo entre empresas clientes e operadoras de bilhetagem, começando pela integração com o CMT, oferecendo pedido consolidado, tratamento ágil de rejeições e conciliação financeira confiável.

### 4.2 Objetivos Estratégicos

### OBJ-01 — Eliminar o processo manual de pedido de recarga por planilha e CSV

Substituir a exportação manual de planilha e o upload de CSV pelo fluxo digital do portal, reduzindo o tempo de processamento mensal hoje relatado em até 2 dias úteis.

- **Resultado esperado:** Redução do tempo de processamento do pedido mensal de recarga em relação ao processo manual atual.
- **Indicador associado:** KPI-01 (ver § 11).
- **Prazo alvo:** Não definido nos insumos disponíveis; ver **LAC-05**.

### OBJ-02 — Eliminar recarga perdida por rejeição não comunicada a tempo

Garantir que toda linha rejeitada (CPF inválido, cartão bloqueado, colaborador desligado) seja identificada e comunicada ao analista de DP no mesmo dia do pedido, evitando casos como o de agosto/2026 na Transportadora Rio Doce.

- **Resultado esperado:** Zero colaboradores sem recarga por rejeição não comunicada no mesmo dia do pedido.
- **Indicador associado:** KPI-02 (ver § 11).
- **Prazo alvo:** Não definido nos insumos disponíveis; ver **LAC-05**.

### OBJ-03 — Dar visibilidade de conciliação entre valor pago e valor creditado

Permitir que o financeiro da empresa cliente concilie, por colaborador e por centro de custo, o valor pago com o valor efetivamente creditado, sem o esforço manual hoje relatado (3 semanas para explicar uma divergência de R$ 4.180).

- **Resultado esperado:** Conciliação disponível no portal sem apuração manual externa.
- **Indicador associado:** KPI-03 (ver § 11).
- **Prazo alvo:** Não definido nos insumos disponíveis; ver **LAC-05**.

### OBJ-04 — Suportar o crescimento comercial de 14 para 40 empresas clientes

Suportar a meta comercial do trimestre de crescer de 14 empresas hoje no processo por CSV para 40 empresas no portal até março de 2027 (fonte: planejamento comercial de 2026-09).

- **Resultado esperado:** Portal operando como via de entrada padrão para novas empresas clientes.
- **Indicador associado:** KPI-07 (ver § 11).
- **Prazo alvo:** Março de 2027.

### 4.3 Objetivos Não Atendidos

Este PRD não tem como objetivo:

- Integrar operadoras de bilhetagem além do CMT — não há, até o momento, acordo comercial ou técnico com outras operadoras (ver notas de discovery).
- Definir a forma de pagamento por Pix — foi apenas uma pergunta levantada em entrevista, sem decisão de negócio; ver **LAC-06**.
- Definir metas de disponibilidade, volume de pico e prazo contratual de crédito com o CMT — nenhuma das entrevistas ou o workshop trouxe esses dados; ver **LAC-01**, **LAC-02** e **LAC-03**.

---

## 5. Escopo do Produto

### 5.1 Dentro do Escopo

#### Pedido de recarga

- Importação e revisão da lista de colaboradores elegíveis para o pedido mensal (J1).
- Confirmação do pedido e geração do pagamento correspondente (J1).
- Consolidação de pedido entre múltiplos CNPJs de um mesmo grupo empresarial (Entrevista 2 — Grupo Serra Verde).

#### Tratamento de rejeições

- Identificação de linhas rejeitadas por CPF inválido, cartão bloqueado ou colaborador desligado (J2).
- Correção e reenvio apenas das linhas rejeitadas, sem refazer o pedido inteiro (J2).
- Aviso no mesmo dia ao analista de DP sobre quais linhas foram rejeitadas e por quê (Entrevista 1).

#### Acompanhamento de pagamento e conciliação financeira

- Acompanhamento do status do pagamento até o crédito efetivo no cartão do colaborador (J1, Entrevista 2).
- Comparação entre valor pago e valor efetivamente creditado, por colaborador e por centro de custo (J3).
- Exportação de relatório de conciliação (J3, Entrevista 1).

### 5.2 Fora do Escopo

Este produto não contempla, nesta versão:

- Integração com operadoras de bilhetagem além do CMT.
- Definição da forma de pagamento (por exemplo, Pix) — trata-se de pergunta em aberto, e não de requisito confirmado; ver **LAC-06**.
- Notificação ao colaborador final sobre o crédito da recarga — desejo relatado em entrevista (Denise Couto), mas não presente nas três jornadas mapeadas no workshop; registrado como candidato de roadmap em § 5.3.

### 5.3 Escopo Futuro / Roadmap Evolutivo

| Item | Descrição | Justificativa | Prioridade |
|---|---|---|---|
| Notificação de crédito ao colaborador | Aviso no celular do colaborador quando a recarga for creditada | Dor relatada por colaborador em entrevista (Denise Couto), sem cobertura nas jornadas do workshop | Média |
| Pagamento via Pix | Meio de pagamento alternativo ao boleto | Interesse manifestado pelo gerente financeiro do Grupo Serra Verde, sem decisão de negócio tomada | A validar (ver LAC-06) |
| Integração com operadoras de bilhetagem além do CMT | Ampliar a base de operadoras suportadas pelo portal | Ainda sem acordo comercial ou técnico | Baixa |

---

## 6. Jornadas de Usuário

> As jornadas descrevem fluxos de alto nível. O detalhamento operacional, regras, exceções e critérios de aceite deve ser tratado no `frd.md`.

### Jornada J-01 — Pedido mensal de recarga

O analista de DP importa a lista de colaboradores elegíveis. Em seguida, revisa os valores de recarga por colaborador. O analista confirma o pedido, o sistema gera o pagamento correspondente, e o analista acompanha o processo até o crédito no cartão do colaborador. Todos os eventos relevantes precisam ser registrados para permitir a conciliação posterior (J3).

**Resultado esperado:** Recarga solicitada, paga e creditada no cartão dos colaboradores elegíveis, com o pedido rastreável do início ao crédito.

**Variantes:**

- Pedido envolvendo múltiplos CNPJs de um mesmo grupo empresarial, consolidado em um único fluxo (Entrevista 2 — Grupo Serra Verde).

**Exceções principais:**

- Linhas de colaborador rejeitadas durante o pedido (tratadas na Jornada J-02).

---

### Jornada J-02 — Tratamento de rejeições

Linhas do pedido com CPF inválido, cartão bloqueado ou colaborador desligado retornam ao analista de DP para correção. O analista corrige apenas as linhas rejeitadas e reenvia, sem necessidade de refazer o pedido inteiro.

**Resultado esperado:** Linhas corrigidas reincorporadas ao pedido, sem impacto nas linhas já aprovadas.

**Variantes:**

- Não especificadas nos insumos de discovery.

**Exceções principais:**

- CPF inválido.
- Cartão bloqueado.
- Colaborador desligado.

---

### Jornada J-03 — Conciliação financeira

O financeiro compara o valor pago com o valor efetivamente creditado, por colaborador e por centro de custo. Ao final, exporta o relatório de conciliação.

**Resultado esperado:** Relatório de conciliação disponível, com divergências identificadas por colaborador e por centro de custo.

**Variantes:**

- Não especificadas nos insumos de discovery.

**Exceções principais:**

- Divergência entre valor pago e valor creditado (caso relatado: R$ 4.180 em julho/2026, Grupo Serra Verde).

---

## 7. Requisitos Funcionais

> Os requisitos funcionais neste PRD estão em nível de produto. Eles descrevem o que o produto deve entregar e por que isso importa.
>
> O detalhamento de regras de negócio, fluxos, validações, mensagens, exceções e critérios de aceite deve ser feito no `frd.md`.

### RF-01 — Pedido mensal de recarga com importação e revisão de colaboradores

O produto deve permitir que o analista de DP importe a lista de colaboradores elegíveis, revise valores por colaborador e confirme o pedido mensal de recarga, gerando o pagamento correspondente.

O requisito deve contemplar:

- Importação da lista de colaboradores elegíveis para recarga.
- Revisão dos valores de recarga por colaborador antes da confirmação.
- Geração do pagamento a partir do pedido confirmado.
- Acompanhamento do pedido até o crédito no cartão do colaborador.

**Valor de negócio:** Elimina a exportação manual de planilha e a conferência manual de elegibilidade hoje realizadas mensalmente (Entrevista 1), reduzindo o tempo de processamento relatado em até 2 dias úteis por mês.

**Personas impactadas:** P-01, P-03

**Documentos filhos relacionados:** `frd.md`

---

### RF-02 — Consolidação de pedido entre múltiplos CNPJs

O produto deve permitir que uma empresa cliente com múltiplos CNPJs consolide o pedido de recarga desses CNPJs em um único fluxo de pedido e pagamento.

O requisito deve contemplar:

- Associação de múltiplos CNPJs a um mesmo grupo empresarial no portal.
- Geração de um pedido único cobrindo os colaboradores de todos os CNPJs associados.
- Acompanhamento consolidado do pagamento até o crédito.

**Valor de negócio:** Resolve a dor relatada pelo Grupo Serra Verde (4 CNPJs), em que hoje um boleto por CNPJ, com repasse em D+2, faz com que o atraso de um único boleto atrase a recarga do mês inteiro.

**Personas impactadas:** P-02

**Documentos filhos relacionados:** `frd.md`

---

### RF-03 — Tratamento de rejeições com aviso no mesmo dia

O produto deve identificar, no momento do processamento do pedido, as linhas rejeitadas por CPF inválido, cartão bloqueado ou colaborador desligado, e avisar o analista de DP no mesmo dia sobre quais linhas foram rejeitadas e por qual motivo, permitindo corrigir e reenviar apenas essas linhas.

O requisito deve contemplar:

- Validação das linhas do pedido antes do envio à operadora.
- Identificação individual de cada linha rejeitada e do respectivo motivo.
- Aviso ao analista de DP no mesmo dia do processamento.
- Correção e reenvio apenas das linhas rejeitadas, sem necessidade de recriar o pedido inteiro.

**Valor de negócio:** Evita casos como o de agosto/2026 na Transportadora Rio Doce, em que 37 colaboradores ficaram sem recarga porque a rejeição do CSV só foi percebida quando os colaboradores reclamaram na catraca.

**Personas impactadas:** P-01, P-03

**Documentos filhos relacionados:** `frd.md`

---

### RF-04 — Acompanhamento de status do pagamento até o crédito

O produto deve permitir que o financeiro da empresa cliente acompanhe o status do pagamento do pedido de recarga, do envio até a confirmação do crédito no cartão do colaborador.

O requisito deve contemplar:

- Exibição do status do pagamento (por exemplo: aguardando pagamento, pago, em processamento pela operadora, creditado).
- Atualização do status conforme o processamento avança junto à operadora CMT.

**Valor de negócio:** Resolve a falta de visibilidade relatada pelo Grupo Serra Verde sobre o processamento do pagamento até o crédito.

**Personas impactadas:** P-02

**Documentos filhos relacionados:** `frd.md`

---

### RF-05 — Conciliação entre valor pago e valor creditado

O produto deve permitir que o financeiro compare o valor pago pela empresa cliente com o valor efetivamente creditado no cartão de cada colaborador, por colaborador e por centro de custo, e exporte um relatório de conciliação.

O requisito deve contemplar:

- Comparação de valor pago versus valor creditado por colaborador.
- Agregação da comparação por centro de custo.
- Exportação do relatório de conciliação (Entrevista 1 e Jornada J-03).

**Valor de negócio:** Elimina o esforço manual relatado pelo Grupo Serra Verde para explicar uma divergência de R$ 4.180, hoje levando três semanas.

**Personas impactadas:** P-01, P-02

**Documentos filhos relacionados:** `frd.md`

---

### 7.1 Matriz Resumida de Requisitos Funcionais

| Código | Requisito | Descrição Resumida | Prioridade | Persona Principal | Documento Detalhado |
|---|---|---|---|---|---|
| RF-01 | Pedido mensal de recarga com importação e revisão | Importar, revisar e confirmar pedido mensal | Must | P-01 | `frd.md` |
| RF-02 | Consolidação de pedido multi-CNPJ | Consolidar pedido de múltiplos CNPJs de um grupo | Must | P-02 | `frd.md` |
| RF-03 | Tratamento de rejeições com aviso no mesmo dia | Identificar e avisar rejeições no mesmo dia | Must | P-01 | `frd.md` |
| RF-04 | Acompanhamento de status do pagamento | Status do pagamento até o crédito | Should | P-02 | `frd.md` |
| RF-05 | Conciliação entre valor pago e creditado | Comparar e exportar relatório de conciliação | Must | P-02 | `frd.md` |

### 7.2 Priorização

Usar, preferencialmente, a classificação MoSCoW:

- **Must:** obrigatório para o produto ser considerado viável
- **Should:** importante, mas pode ser entregue após o MVP se necessário
- **Could:** desejável, mas não essencial
- **Won't:** explicitamente fora da versão atual

### 7.3 User Stories, Quando Aplicável

### US-01 — Aviso de linhas rejeitadas no mesmo dia

Como analista de DP,
quero ser avisado no mesmo dia sobre quais linhas do pedido de recarga foram rejeitadas e por quê,
para que eu possa corrigir e reenviar antes que o colaborador seja impactado na catraca.

**Requisito funcional relacionado:** RF-03

**Critérios objetivos mínimos:**

- O aviso é enviado no mesmo dia útil em que a rejeição é identificada.
- O aviso identifica, para cada linha rejeitada, o colaborador e o motivo da rejeição.
- A correção de uma linha rejeitada não exige recriar o pedido inteiro.

---

### US-02 — Pedido consolidado para múltiplos CNPJs

Como gerente financeiro de um grupo com múltiplos CNPJs,
quero solicitar e pagar a recarga de todos os CNPJs do grupo em um único fluxo,
para que um atraso isolado em um CNPJ não atrase a recarga dos demais.

**Requisito funcional relacionado:** RF-02

**Critérios objetivos mínimos:**

- É possível associar mais de um CNPJ a um mesmo grupo empresarial no portal.
- O pedido consolidado cobre os colaboradores de todos os CNPJs associados.
- O status de pagamento é visível de forma consolidada para o grupo.

---

## 8. Requisitos Não Funcionais

> Os requisitos não funcionais neste PRD estão em nível de produto.
>
> O detalhamento completo de metas, SLOs, SLAs, padrões, testes e critérios de aceite deve ser feito no `nfrd.md`.

### 8.1 Disponibilidade

Nenhuma meta de disponibilidade foi informada pelos participantes do workshop de 2026-09-15 (registrado explicitamente nas notas de discovery: "ninguém soube informar metas de disponibilidade"). A definição de tiers e metas de disponibilidade fica registrada como lacuna; ver **LAC-01**.

| Tier | Módulos/Capacidades | Meta de Disponibilidade | Observação |
|---|---|---|---|
| — | — | Não definido | Ver LAC-01; a definir em `nfrd.md` após validação com o negócio |

### 8.2 Performance

Nenhum objetivo de performance (tempo de resposta, p95, p99) foi informado nos insumos de discovery disponíveis. Ver **LAC-02**; a definir em `nfrd.md`.

### 8.3 Segurança

O produto deve garantir:

- Autenticação e autorização adequadas a cada perfil de usuário (analista de DP, gerente financeiro), considerando que o portal trata dados de folha de pagamento e de vale-transporte de colaboradores.
- Proteção dos dados pessoais de colaboradores (nome, CPF, matrícula) tratados no fluxo de pedido, conforme citado nas notas de discovery.
- Criptografia em trânsito e em repouso, quando aplicável, a ser detalhada em `nfrd.md`.
- Rastreabilidade das ações de pedido, correção de rejeição e pagamento, para suportar auditoria e conciliação.

### 8.4 Privacidade e Proteção de Dados

O produto deve cumprir as exigências legais e regulatórias de proteção de dados aplicáveis ao tratamento de nome, CPF e matrícula de colaboradores. As notas de discovery registram explicitamente que o jurídico ainda não se manifestou sobre base legal nem sobre prazo de retenção desses dados — este ponto é tratado como lacuna crítica; ver **LAC-03** e **RISCO-P02**.

### 8.5 Usabilidade e Acessibilidade

O produto deve oferecer experiência adequada aos usuários finais e operadores. A Entrevista 1 registra a expectativa de que "o sistema novo tem que ser rápido e intuitivo" — trata-se de uma expectativa qualitativa relatada pelo cliente, e não de um critério mensurável; os critérios objetivos de usabilidade (número máximo de etapas do fluxo de pedido, tempo de resposta percebido, padrão de acessibilidade) devem ser definidos em `nfrd.md` ou `UXD.md`.

### 8.6 Observabilidade e Auditabilidade

O produto deve permitir acompanhamento operacional e rastreabilidade completa do pedido de recarga, do pagamento e da rejeição/correção, dado que a conciliação financeira (RF-05) depende de trilha auditável entre o valor pago e o valor creditado.

### 8.7 Escalabilidade e Capacidade

Nenhum volume atual, volume esperado ou pico estimado (usuários, transações/dia, requisições por segundo) foi informado nos insumos de discovery. A única referência de volume disponível é o número de empresas clientes: 14 hoje, meta de 40 até março de 2027. Ver **LAC-02**; a definir em `nfrd.md`.

### 8.8 Compliance

O produto deve estar aderente a:

- Legislação de proteção de dados pessoais aplicável ao tratamento de CPF, nome e matrícula de colaboradores — base legal e retenção ainda não definidas pelo jurídico (ver **LAC-03**).
- Regras contratuais e operacionais da operadora CMT para recebimento e crédito dos pedidos de recarga — prazo contratual de crédito ainda não informado (ver **LAC-01**).

---

## 9. Restrições, Premissas e Lacunas

### 9.1 Restrições

### REST-01 — Operadora parceira inicial única

O portal deve operar, nesta versão, exclusivamente com a operadora de bilhetagem CMT.

- **Origem:** Notas de discovery — não há acordo com outras operadoras.
- **Impacto:** O escopo de integração e o modelo de dados de bilhetagem ficam restritos ao contrato/API do CMT.
- **Consequência se não atendida:** Necessidade de retrabalho de integração para suportar múltiplas operadoras sem acordo comercial correspondente.

### REST-02 — Documento em nível de produto, sem detalhe técnico

Este PRD não deve conter detalhes de implementação técnica (endpoints, tabelas, filas), que ficam reservados ao `TRD.md`.

- **Origem:** Regra absoluta do processo de documentação (anti-padrão de vazamento de implementação no PRD).
- **Impacto:** O esboço técnico apresentado pelo tech lead no workshop (API de pedidos, persistência relacional, fila assíncrona) não é normatizado aqui; deve ser formalizado no `TRD.md`.
- **Consequência se não atendida:** Perda de rastreabilidade entre decisão de produto e decisão técnica, e acoplamento prematuro do PRD a uma escolha de arquitetura.

### 9.2 Premissas

### PRM-01 — Dados de colaboradores disponíveis via sistema de folha da empresa cliente

Assume-se que a empresa cliente tem, hoje, um sistema de folha do qual é possível extrair a lista de colaboradores elegíveis para importação no portal.

- **Dependência associada:** Sistema de folha de pagamento de cada empresa cliente (fora do escopo deste produto).
- **Impacto se a premissa falhar:** Empresas sem exportação estruturada de colaboradores não conseguem usar o fluxo de importação do portal (RF-01) sem etapa adicional de integração ou digitação manual.

### PRM-02 — Meta comercial de crescimento válida

Assume-se válida a meta comercial de crescer de 14 para 40 empresas clientes no portal até março de 2027, conforme planejamento comercial de 2026-09.

- **Dependência associada:** Área comercial e seu planejamento de 2026-09.
- **Impacto se a premissa falhar:** KPI-07 (adoção) e o dimensionamento de capacidade do produto precisam ser revistos.

### 9.3 Lacunas e Pontos a Validar

> Esta seção registra informações relevantes que não puderam ser confirmadas a partir dos insumos disponíveis. Não foi inventado conteúdo para preencher estas lacunas.

| Código | Lacuna ou Ponto a Validar | Impacto Potencial | Responsável pela Validação | Status |
|---|---|---|---|---|
| LAC-01 | Meta de disponibilidade do portal e prazo contratual de crédito junto ao CMT não informados | Impede definir `nfrd.md` (disponibilidade) e compliance contratual | Owner do produto (Patrícia Lemos) + área comercial/jurídica responsável pelo contrato com o CMT | Aberto |
| LAC-02 | Volume de pico (usuários, transações/dia, requisições por segundo) não informado | Impede dimensionar capacidade em `nfrd.md` | Owner do produto (Patrícia Lemos) + engenharia | Aberto |
| LAC-03 | Base legal e prazo de retenção para dados pessoais de colaboradores (nome, CPF, matrícula) não definidos pelo jurídico | Impede fechar requisitos de privacidade (§ 8.4) e pode bloquear lançamento por não conformidade | Jurídico/compliance interno | Aberto |
| LAC-04 | Canal de interação do colaborador final (P-03) com o produto não especificado nos insumos | Impede detalhar em `UXD.md` como o colaborador receberia eventual notificação de crédito | Owner do produto (Patrícia Lemos) | Aberto |
| LAC-05 | Prazo alvo para os objetivos OBJ-01, OBJ-02 e OBJ-03 não informado nos insumos | Impede fixar compromisso de entrega associado a esses objetivos | Owner do produto (Patrícia Lemos) | Aberto |
| LAC-06 | Interesse em pagamento via Pix foi apenas uma pergunta em entrevista, sem decisão de negócio | Impede tratar Pix como requisito confirmado nesta versão | Owner do produto (Patrícia Lemos) + área financeira das empresas clientes | Aberto |

---

## 10. Riscos e Mitigações

### 10.1 Riscos de Produto e Negócio

### RISCO-P01 — Meta comercial de 40 empresas não sustentada por dimensionamento de capacidade

- **Descrição:** A meta de crescer de 14 para 40 empresas clientes até março de 2027 foi definida sem que volume de pico, disponibilidade ou capacidade do portal tenham sido dimensionados (LAC-01, LAC-02).
- **Probabilidade:** Média
- **Impacto:** Alto
- **Categoria:** Produto
- **Mitigação:** Levantar, junto à engenharia e à área comercial, o volume esperado de pedidos e colaboradores antes da definição do `nfrd.md`.
- **Responsável:** Owner do produto (Patrícia Lemos)
- **Indicador de monitoramento:** Fechamento de LAC-01 e LAC-02.

### RISCO-P02 — Tratamento de dados pessoais sem base legal definida

- **Descrição:** O produto tratará nome, CPF e matrícula de colaboradores sem que o jurídico tenha se manifestado sobre base legal e retenção (LAC-03).
- **Probabilidade:** Alta
- **Impacto:** Crítico
- **Categoria:** Regulatório
- **Mitigação:** Bloquear a aprovação deste PRD para "Aprovado para desenvolvimento" até que o jurídico se manifeste sobre base legal e retenção.
- **Responsável:** Jurídico/compliance interno
- **Indicador de monitoramento:** Fechamento de LAC-03.

### 10.2 Riscos Técnicos

### RISCO-T01 — Dependência de acordo técnico único com o CMT

- **Descrição:** O portal depende integralmente da integração com o CMT (única operadora parceira); qualquer instabilidade ou mudança de contrato técnico do CMT impacta diretamente o produto.
- **Probabilidade:** Média
- **Impacto:** Alto
- **Mitigação:** Formalizar o contrato técnico e o SLA de crédito com o CMT no `TRD.md`, incluindo tratamento de indisponibilidade da operadora.
- **Responsável:** Engenharia (tech lead)
- **Indicador de monitoramento:** Fechamento de LAC-01 (prazo contratual de crédito).

### 10.3 Riscos Operacionais

### RISCO-O01 — Recorrência de rejeições não tratadas a tempo

- **Descrição:** Caso a validação prévia (RF-03) não cubra todos os motivos de rejeição observados na operação real, casos como o de agosto/2026 (37 colaboradores sem recarga) podem se repetir.
- **Probabilidade:** Média
- **Impacto:** Alto
- **Mitigação:** Detalhar em `frd.md` todos os motivos de rejeição conhecidos e o SLA de aviso ao analista de DP.
- **Responsável:** Owner do produto (Patrícia Lemos) + engenharia
- **Indicador de monitoramento:** KPI-02 (ver § 11).

---

### 10.4 Matriz Consolidada de Riscos

| Código | Risco | Categoria | Probabilidade | Impacto | Severidade | Mitigação |
|---|---|---|---|---|---|---|
| RISCO-P01 | Meta comercial sem dimensionamento de capacidade | Produto | Média | Alto | Alta | Levantar volume esperado antes do `nfrd.md` |
| RISCO-P02 | Dados pessoais sem base legal definida | Regulatório | Alta | Crítico | Crítica | Bloquear aprovação até manifestação jurídica |
| RISCO-T01 | Dependência técnica única do CMT | Técnico | Média | Alto | Alta | Formalizar SLA e contrato técnico com o CMT |
| RISCO-O01 | Recorrência de rejeições não tratadas a tempo | Operacional | Média | Alto | Alta | Detalhar motivos de rejeição e SLA de aviso em `frd.md` |

---

## 11. Métricas de Sucesso

### 11.1 Métricas de Produto

### KPI-01 — Tempo de processamento do pedido mensal de recarga

- **Objetivo relacionado:** OBJ-01
- **Meta:** Redução em relação à linha de base atual de até 2 dias úteis por mês (Entrevista 1); meta numérica final a validar com o negócio (ver LAC-05).
- **Medição:** Tempo entre início do pedido no portal e confirmação do pedido.
- **Fonte de dados:** Registro de eventos do próprio portal.
- **Periodicidade:** Mensal.

### KPI-02 — Colaboradores sem recarga por rejeição não comunicada a tempo

- **Objetivo relacionado:** OBJ-02
- **Meta:** Zero colaboradores sem recarga por rejeição não comunicada no mesmo dia do pedido.
- **Medição:** Contagem de casos em que uma linha rejeitada não gerou aviso no mesmo dia útil.
- **Fonte de dados:** Registro de eventos do próprio portal.
- **Periodicidade:** Mensal.

---

### 11.2 Métricas Operacionais

### KPI-03 — Tempo de conciliação financeira

- **Meta:** Redução em relação à linha de base atual de três semanas para explicar uma divergência (Entrevista 2); meta numérica final a validar com o negócio (ver LAC-05).
- **Medição:** Tempo entre a identificação de uma divergência e sua explicação/resolução no relatório de conciliação.
- **Fonte de dados:** Relatório de conciliação do portal.
- **Periodicidade:** Mensal.

### KPI-04 — Divergência entre valor pago e valor creditado

- **Meta:** Redução do valor total de divergências não explicadas em relação à linha de base de R$ 4.180/mês (Entrevista 2); meta numérica final a validar com o negócio.
- **Medição:** Soma das divergências identificadas no relatório de conciliação.
- **Fonte de dados:** Relatório de conciliação do portal.
- **Periodicidade:** Mensal.

---

### 11.3 Métricas Técnicas

> Não há, nos insumos de discovery disponíveis, metas técnicas (disponibilidade, performance, capacidade) definidas. Ver LAC-01 e LAC-02; métricas técnicas serão definidas junto ao `nfrd.md` quando essas lacunas forem fechadas.

---

### 11.4 Métricas de Adoção

### KPI-07 — Número de empresas clientes ativas no portal

- **Meta:** 40 empresas clientes até março de 2027 (linha de base: 14 empresas no processo por CSV; fonte: planejamento comercial de 2026-09).
- **Medição:** Contagem de empresas clientes com pedido de recarga ativo no portal.
- **Fonte de dados:** Cadastro de empresas clientes do portal.
- **Periodicidade:** Mensal.

---

### 11.5 Tabela Consolidada de KPIs

| Código | KPI | Objetivo Relacionado | Meta | Fonte | Periodicidade |
|---|---|---|---|---|---|
| KPI-01 | Tempo de processamento do pedido mensal | OBJ-01 | Redução vs. linha de base de 2 dias úteis (meta numérica a validar, LAC-05) | Portal | Mensal |
| KPI-02 | Colaboradores sem recarga por rejeição não comunicada | OBJ-02 | Zero | Portal | Mensal |
| KPI-03 | Tempo de conciliação financeira | OBJ-03 | Redução vs. linha de base de 3 semanas (meta numérica a validar, LAC-05) | Portal | Mensal |
| KPI-07 | Empresas clientes ativas no portal | OBJ-04 | 40 empresas até março/2027 | Cadastro do portal | Mensal |

---

## 12. Documentos Relacionados

| Documento | Descrição | Status |
|---|---|---|
| `frd.md` | Documento de Requisitos Funcionais Detalhados | A produzir |
| `nfrd.md` | Documento de Requisitos Não Funcionais Detalhados | A produzir (bloqueado por LAC-01, LAC-02, LAC-03) |
| `TRD.md` | Documento de Requisitos Técnicos | A produzir (formalizar desenho preliminar do tech lead) |
| `ADR.md` | Registros de Decisão Arquitetural | A avaliar durante a produção do TRD |
| `UXD.md` | Documento de Experiência do Usuário | A avaliar (bloqueado, em parte, por LAC-04) |

---

## 13. Anexos

### Anexo A — Glossário

| Termo | Definição |
|---|---|
| Recarga de vale-transporte | Crédito de valor destinado a passagens de transporte público, lançado no cartão de bilhetagem do colaborador |
| Pedido de recarga | Solicitação mensal, feita pela empresa cliente, para recarregar o vale-transporte de seus colaboradores elegíveis |
| Conciliação financeira | Comparação entre o valor pago pela empresa cliente e o valor efetivamente creditado nos cartões dos colaboradores |

### Anexo B — Siglas

| Sigla | Significado |
|---|---|
| VT | Vale-Transporte |
| CMT | Consórcio Metropolitano de Transportes |
| DP | Departamento Pessoal |
| CNPJ | Cadastro Nacional da Pessoa Jurídica |

### Anexo C — Referências

- Entrevistas com clientes — RH de empresas clientes, setembro/2026 (`docs/discovery/entrevistas-rh.md`)
- Jornadas mapeadas no workshop de 2026-09-15 (`docs/discovery/jornadas.md`)
- Notas de discovery — Portal VT Corporativo (`docs/discovery/notas-discovery.md`)
