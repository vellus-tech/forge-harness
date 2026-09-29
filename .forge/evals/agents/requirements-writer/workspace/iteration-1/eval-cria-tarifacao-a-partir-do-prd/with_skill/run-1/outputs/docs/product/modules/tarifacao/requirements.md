# TAR — Tarifação

**Requisitos Funcionais e Não-Funcionais**

- Versão: 0.1.0
- Data: 2026-09-26
- Status: Rascunho para revisão
- Referência pai: docs/product/prd-tarifacao.md § 1-5

## Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|------------------------|
| 0.1.0 | 2026-09-26 | Rascunho para revisão | Criação inicial a partir do PRD de Tarifação da Bilhetagem Municipal |

## 1. Visão Geral

O módulo de Tarifação calcula o valor debitado em cada Validação de um Cartão Transporte ou QR Code de embarque, conforme o Perfil Tarifário do Passageiro e a Integração Temporal vigente. O Decreto Municipal 18.442/2026 fixa a Tarifa Base em R$ 4,85 a partir de 2026-11-01, substituindo a tarifa anterior sem afetar Validações já registradas. O módulo deve responder ao Validador dentro do orçamento de latência do pico da manhã e manter o cálculo auditável pela Operadora e pela SEMOB por 5 anos.

## 2. Escopo

### 2.1 Incluído

- Cálculo do valor devido em cada Validação, considerando Tarifa Base vigente, Perfil Tarifário e Integração Temporal.
- Configuração de Tarifa Base por vigência, permitindo agendar uma nova tarifa para uma data futura sem afetar Validações anteriores.
- Aplicação da Integração Temporal (segunda Validação com desconto, terceira em diante com tarifa cheia) dentro da Janela de Integração de 60 minutos.
- Aplicação de meia tarifa ao Perfil estudante, com limite de 60 Validações por mês civil.
- Aplicação de Gratuidade aos Perfis idoso (65 anos ou mais) e PcD.
- Regra de não acumulação de benefícios (menor valor entre os benefícios aplicáveis).
- Registro de cada cálculo de tarifa para fins de auditoria pela Operadora e pela SEMOB.

### 2.2 Excluído

- Emissão, bloqueio ou recarga do Cartão Transporte.
- Cadastro e validação documental do Perfil Tarifário (assume-se que o Perfil já chega classificado ao módulo de Tarifação).
- Compensação financeira entre Operadora e prefeitura (settlement).

### 2.3 Fora do escopo do MVP

- Tarifa diferenciada por linha ou por distância.
- Bilhete único mensal.

## 3. Personas / Atores

- **Passageiro** — utiliza o transporte público mediante apresentação de Cartão Transporte ou QR Code de embarque; é o sujeito de cada cálculo de tarifa.
- **Validador** — equipamento embarcado que registra a Validação e consome o cálculo de tarifa em tempo real.
- **Operadora** — concessionária responsável por operar as linhas e auditar os cálculos de tarifa aplicados.
- **SEMOB (Secretaria Municipal de Mobilidade)** — órgão regulador que audita os cálculos de tarifa e fiscaliza a aplicação do decreto tarifário.

## 4. Lista canônica de Perfis Tarifários

| Perfil | Regra de cálculo | Origem |
|--------|-------------------|--------|
| Comum | Tarifa cheia, sujeita a Integração Temporal | PRD § 2, RN-01, RN-02 |
| Estudante | Meia tarifa, limitada a 60 Validações por mês civil, sujeita a Integração Temporal | PRD § 2, RN-03 |
| Idoso (65 anos ou mais) | Gratuidade | PRD § 2, RN-04 |
| PcD | Gratuidade | PRD § 2, RN-04 |

## 5. Requisitos Funcionais

### Req 1 — Calcular tarifa da Validação conforme Tarifa Base vigente

**Como** Validador **quero** obter o valor devido em cada Validação com base na Tarifa Base vigente na data da Validação **para** debitar o valor correto do Passageiro no momento do embarque.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | PRD § 2, RN-01 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**

- 1.1 Para uma Validação registrada antes de 2026-11-01, o cálculo usa a Tarifa Base vigente até essa data.
- 1.2 Para uma Validação registrada em ou após 2026-11-01, o cálculo usa a Tarifa Base de R$ 4,85.
- 1.3 A Tarifa Base é configurável por vigência: uma nova Tarifa Base pode ser cadastrada com data de início futura sem alterar o resultado de Validações já calculadas.
- 1.4 Uma Validação nunca é recalculada retroativamente em função da entrada em vigor de uma nova Tarifa Base.

**Cross-ref:** Não aplicável nesta versão.

### Req 2 — Aplicar desconto de Integração Temporal na segunda Validação

**Como** Passageiro **quero** pagar metade da Tarifa Base na segunda Validação feita dentro da Janela de Integração **para** trocar de veículo ou linha sem pagar duas tarifas cheias.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | PRD § 2, RN-02 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**

- 2.1 Uma Validação é considerada a segunda da Janela de Integração quando ocorre dentro de 60 minutos contados da primeira Validação do mesmo Cartão Transporte.
- 2.2 A segunda Validação dentro da Janela de Integração é cobrada em 50% da Tarifa Base vigente.
- 2.3 Uma Validação que ocorre exatamente aos 60 minutos da primeira é considerada dentro da Janela de Integração.
- 2.4 Uma Validação que ocorre após 60 minutos da primeira Validação inicia uma nova Janela de Integração e é cobrada como primeira Validação.

**Cross-ref:** Req 1.

### Req 3 — Cobrar tarifa cheia a partir da terceira Validação na mesma janela

**Como** Operadora **quero** que a terceira Validação dentro da mesma Janela de Integração seja cobrada em tarifa cheia **para** que a Integração Temporal não seja usada para múltiplos embarques com desconto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | PRD § 2, RN-02 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**

- 3.1 A terceira Validação do mesmo Cartão Transporte dentro da Janela de Integração aberta pela primeira Validação é cobrada em 100% da Tarifa Base vigente.
- 3.2 Uma quarta Validação dentro da mesma Janela de Integração original também é cobrada em tarifa cheia.
- 3.3 A contagem de Validações da Janela de Integração é reiniciada assim que uma Validação ocorre fora da janela vigente.

**Cross-ref:** Req 1, Req 2.

### Req 4 — Aplicar meia tarifa ao Perfil estudante com limite mensal

**Como** Passageiro com Perfil estudante **quero** pagar meia tarifa em cada Validação dentro do meu limite mensal **para** exercer o benefício previsto para o meu Perfil Tarifário.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | PRD § 2, RN-03 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**

- 4.1 Uma Validação de Perfil estudante, dentro do limite de 60 Validações no mês civil corrente, é cobrada em 50% da Tarifa Base vigente.
- 4.2 A contagem de Validações do Perfil estudante é reiniciada a cada mês civil.
- 4.3 A 61ª Validação de Perfil estudante no mesmo mês civil é cobrada em 100% da Tarifa Base vigente.
- 4.4 O limite de 60 Validações por mês civil é contado por Cartão Transporte, não por Passageiro.

**Cross-ref:** Req 1, Req 5.

### Req 5 — Aplicar Gratuidade aos Perfis idoso e PcD

**Como** Passageiro com Perfil idoso ou PcD **quero** não pagar nenhum valor em minhas Validações **para** exercer a Gratuidade prevista em lei para o meu Perfil Tarifário.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | PRD § 2, RN-04 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**

- 5.1 Toda Validação de Perfil idoso (65 anos ou mais) é cobrada em R$ 0,00, independentemente da Janela de Integração.
- 5.2 Toda Validação de Perfil PcD é cobrada em R$ 0,00, independentemente da Janela de Integração.
- 5.3 Uma Validação com Gratuidade é registrada para fins de auditoria com o mesmo detalhamento de uma Validação tarifada.

**Cross-ref:** Req 6.

### Req 6 — Não acumular benefícios tarifários

**Como** Operadora **quero** que nenhuma Validação combine dois benefícios tarifários **para** garantir que o valor cobrado siga exatamente a regra vigente sem desconto duplicado.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | PRD § 2, RN-05 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**

- 6.1 Quando mais de uma regra de benefício é aplicável à mesma Validação (por exemplo, Perfil estudante em Integração Temporal), o valor cobrado é o menor entre os valores de cada regra isoladamente, nunca a combinação das duas.
- 6.2 Nenhum cálculo aplica um desconto percentual sobre um valor já reduzido por outro benefício.
- 6.3 Gratuidade sempre prevalece sobre qualquer outro benefício, pois nenhum valor é menor que R$ 0,00.

**Cross-ref:** Req 2, Req 4, Req 5.

### Req 7 — Registrar cada cálculo de tarifa para auditoria

**Como** SEMOB **quero** que cada cálculo de tarifa fique registrado com Cartão Transporte, Perfil, regra aplicada e valor **para** auditar a conformidade da bilhetagem com o decreto tarifário por até 5 anos.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | PRD § 2, RN-06 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**

- 7.1 Todo cálculo de tarifa gera um registro identificando Cartão Transporte, Perfil Tarifário, regra tarifária aplicada (Tarifa Base, Integração Temporal, meia tarifa ou Gratuidade) e valor cobrado.
- 7.2 O registro de cálculo de tarifa é retido por no mínimo 5 anos, acessível pela Operadora e pela SEMOB.
- 7.3 O registro de cálculo de tarifa não é alterável nem removível após sua criação.
- 7.4 O número do Cartão Transporte não aparece completo em nenhum log gerado pelo cálculo de tarifa.

**Cross-ref:** RNF 2, RNF 3.

## 6. Requisitos Não-Funcionais

### RNF 1 — Latência do cálculo de tarifa sob pico de carga

| Campo | Valor |
|-------|-------|
| **Categoria** | Performance |
| **Prioridade** | Must |
| **Origem** | PRD § 3 |
| **Módulo** | tarifacao |

**Descrição:**

O cálculo de tarifa deve responder ao Validador dentro de um orçamento de latência estrito mesmo sob o volume de pico da manhã, para não atrasar o embarque do Passageiro.

**Critérios de Aceite:**

- RNF-1.1 O tempo de resposta do cálculo de tarifa é de até 150 ms no percentil 95 (p95).
- RNF-1.2 O limite de 150 ms (p95) é mantido sob carga de até 3.000 Validações por minuto.

**Cross-ref:** Não aplicável nesta versão.

### RNF 2 — Mascaramento do Cartão Transporte em logs

| Campo | Valor |
|-------|-------|
| **Categoria** | Privacidade |
| **Prioridade** | Must |
| **Origem** | PRD § 3 |
| **Módulo** | tarifacao |

**Descrição:**

O número do Cartão Transporte é um identificador de meio de pagamento do Passageiro e não deve ser exposto integralmente em nenhuma saída de log do módulo de Tarifação.

**Critérios de Aceite:**

- RNF-2.1 Nenhuma linha de log emitida pelo cálculo de tarifa contém o número completo do Cartão Transporte.
- RNF-2.2 O mascaramento preserva dígitos suficientes para correlação operacional sem permitir a reconstrução do número completo (ex.: exibir apenas os últimos 4 dígitos).

**Cross-ref:** Req 7.4.

### RNF 3 — Auditabilidade e imutabilidade do registro de cálculo de tarifa

| Campo | Valor |
|-------|-------|
| **Categoria** | Auditoria |
| **Prioridade** | Must |
| **Origem** | PRD § 2, RN-06 |
| **Módulo** | tarifacao |

**Descrição:**

Cada cálculo de tarifa deve gerar um evento de auditoria append-only, acessível pela Operadora e pela SEMOB, identificando o quê foi calculado, para qual Cartão Transporte, sob qual regra e com qual resultado.

**Critérios de Aceite:**

- RNF-3.1 O evento de auditoria de cálculo de tarifa é gravado como append-only: nenhuma operação de atualização ou remoção é permitida após a criação.
- RNF-3.2 O evento de auditoria é retido por no mínimo 5 anos a partir da data da Validação.
- RNF-3.3 O evento de auditoria é consultável tanto pela Operadora quanto pela SEMOB.

**Cross-ref:** Req 7.

### RNF 4 — Representação monetária do valor da tarifa

| Campo | Valor |
|-------|-------|
| **Categoria** | Integridade |
| **Prioridade** | Must |
| **Origem** | Decisão arquitetural (`.forge/rules/domain/money-as-cents.md`) |
| **Módulo** | tarifacao |

**Descrição:**

O valor calculado em cada Validação é uma grandeza monetária e deve ser representado no domínio como inteiro em centavos, nunca em tipo de ponto flutuante, evitando erros de arredondamento acumulados.

**Critérios de Aceite:**

- RNF-4.1 Todo valor monetário de domínio produzido pelo cálculo de tarifa é expresso como inteiro em centavos (`amountInCents`).
- RNF-4.2 Nenhum cálculo de tarifa usa `float` ou `double` como tipo de valor monetário em qualquer etapa do domínio.
- RNF-4.3 Qualquer arredondamento necessário no cálculo (ex.: 50% de um valor ímpar de centavos) segue a NBR 5891 (arredondamento bancário, ToEven).

**Cross-ref:** `.forge/rules/domain/money-as-cents.md`, `.forge/rules/domain/nbr-5891-rounding.md`.

## 7. Property-Based Testing

### PBT-01 — Meia tarifa nunca excede a Tarifa Base

**Mapeia para:** Req 2, Req 4
**Tipo:** Invariante matemática

**Propriedade:**

> Para qualquer Tarifa Base vigente em centavos, o valor cobrado por uma Validação com desconto de 50% (Integração Temporal ou Perfil estudante) é sempre menor ou igual à metade da Tarifa Base arredondada conforme NBR 5891, e nunca excede a própria Tarifa Base.

### PBT-02 — Não acumulação de benefícios produz o menor valor possível

**Mapeia para:** Req 6

**Tipo:** Invariante matemática

**Propriedade:**

> Para qualquer combinação de benefícios aplicáveis à mesma Validação (Integração Temporal, Perfil estudante, Gratuidade), o valor final cobrado é sempre igual ao mínimo entre os valores que cada benefício produziria isoladamente, nunca inferior a esse mínimo nem resultado de aplicar os benefícios em sequência.

### PBT-03 — Classificação da Validação na Janela de Integração é uma máquina de estados determinística

**Mapeia para:** Req 2, Req 3

**Tipo:** State machine

**Propriedade:**

> Para qualquer sequência de instantes de Validação do mesmo Cartão Transporte, a posição de cada Validação na Janela de Integração (primeira, segunda, terceira ou além) depende apenas do tempo decorrido desde a Validação que abriu a janela corrente, produzindo sempre a mesma classificação para a mesma sequência de instantes, independentemente da ordem de processamento.

### PBT-04 — Contagem mensal do Perfil estudante nunca ultrapassa o limite sem cobrar tarifa cheia

**Mapeia para:** Req 4

**Tipo:** Invariante matemática

**Propriedade:**

> Para qualquer sequência de Validações de um Cartão Transporte com Perfil estudante dentro do mesmo mês civil, todas as Validações além da 60ª são cobradas em tarifa cheia, e a contagem nunca é herdada de um mês civil para o seguinte.

Não há propriedade de idempotência ou round-trip candidata nesta versão: o cálculo de tarifa não é uma operação reversível.

## 8. Glossário local

Os termos abaixo são definidos em `docs/product/glossary/domain-glossary.md` e reproduzidos aqui apenas para referência rápida deste módulo:

| Termo | Definição resumida |
|-------|---------------------|
| Tarifa Base | Valor cheio de uma viagem, fixado por decreto municipal, expresso em centavos. |
| Integração Temporal | Benefício concedido à segunda Validação feita dentro da Janela de Integração a partir da primeira. |
| Janela de Integração | Intervalo de tempo, contado da primeira Validação, em que a Integração Temporal é concedida. |
| Gratuidade | Isenção total da Tarifa Base concedida por lei a um Perfil Tarifário específico. |
| Perfil Tarifário | Classificação do Passageiro que determina a regra tarifária aplicável (comum, estudante, idoso, PcD). |
| Cartão Transporte | Meio de pagamento pré-pago, identificado por número de série, emitido pela operadora de bilhetagem. |
| Validação | Ato de apresentar o Cartão Transporte ao validador embarcado, que autoriza ou nega o embarque. |

## 9. Fora do escopo do MVP

- Tarifa diferenciada por linha ou por distância.
- Bilhete único mensal.

## 10. Referências cruzadas

- `docs/product/prd-tarifacao.md` — PRD de origem, Decreto 18.442/2026.
- `docs/product/glossary/domain-glossary.md` — glossário de domínio da Bilhetagem Eletrônica.
- `.forge/rules/domain/money-as-cents.md` — representação monetária em centavos.
- `.forge/rules/domain/nbr-5891-rounding.md` — arredondamento bancário aplicável a RNF 4 e PBT-01.
- `.forge/rules/domain/audit-immutability.md` — mecanismo de imutabilidade que fundamenta RNF 3.
- `.forge/rules/architecture/observability.md` — mascaramento de PII em logs, base de RNF 2.
