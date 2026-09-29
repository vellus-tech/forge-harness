# Discovery Notes

**Produto:** recarga-api (Viação Norte — bilhetagem eletrônica)
**Tipo de iniciativa:** Nova feature — Ponto a validar (a confirmar com o usuário na Q1)
**Data:** 2026-09-26
**Status:** Em discovery

---

## 0. Workspace Scan

### 0.1 Diretórios e Arquivos Relevantes

| Caminho | Tipo | Contexto Oferecido |
|---|---|---|
| README.md | Documentação | Descreve o recarga-api: serviço de recarga de créditos do cartão de transporte da Viação Norte, hoje só via posto de venda/totem, pagamento em dinheiro ou débito. Saldo em PostgreSQL, sincronizado com validadores embarcados a cada 15 minutos. |
| docs/product/adr/0001-saldo-centralizado-no-postgres.md | ADR | Decisão aceita: saldo oficial vive na tabela `saldo_cartao` do PostgreSQL; validadores offline recebem lista de saldos a cada 15 minutos. Consequência: uma recarga só aparece no validador após a próxima sincronização (até 15 min). |
| openapi.yaml | Contrato de API | Serviço `recarga-api` v1.4.0, com `GET /cartoes/{numero}/saldo` e `POST /recargas` (recarga registrada em posto de venda ou totem). Ainda não há endpoint de recarga via Pix nem de app do passageiro. |
| src/Recarga.Api/Program.cs | Código | API minimal em .NET 8 (`Microsoft.NET.Sdk.Web`), com os dois endpoints do OpenAPI implementados de forma simplificada (stub de saldo zerado, criação sem persistência real visível neste arquivo). |
| src/Recarga.Api/Recarga.Api.csproj | Build | Confirma stack: .NET 8, ASP.NET Core minimal API. |
| docker-compose.yml | Infra local | Sobe PostgreSQL 16 e a API na porta 8080; API depende do banco. |
| AGENTS.md | Config de harness | Presente na raiz, não lido em profundidade nesta fase (fora do escopo de discovery de produto). |

### 0.2 Resumo do Contexto Existente

O recarga-api é um serviço existente (brownfield) da Viação Norte que hoje resolve a recarga de créditos do cartão de transporte apenas de forma presencial, em posto de venda ou totem, com pagamento em dinheiro ou cartão de débito. O saldo oficial fica centralizado no PostgreSQL (ADR-0001) e é replicado para os validadores embarcados, que operam offline, a cada ciclo de 15 minutos — ou seja, há uma janela de propagação inerente ao desenho atual, independente de qual canal originou a recarga. O contrato OpenAPI atual expõe consulta de saldo e registro de recarga, mas sem qualquer menção a Pix, app do passageiro ou canal remoto. A stack é .NET 8 com ASP.NET Core minimal API, rodando localmente via Docker Compose junto com o PostgreSQL.

### 0.3 Lacunas Identificadas

- Não há endpoint, contrato ou menção a Pix no OpenAPI nem no código — a integração com Pix (PSP, webhook de confirmação, QR Code) ainda não existe.
- Não há documentação sobre autenticação/identificação do passageiro no app (hoje o fluxo é presencial, com cartão físico apresentado no posto/totem).
- O ADR-0001 já expõe uma restrição relevante (latência de até 15 minutos para o saldo chegar ao validador) que impacta diretamente a expectativa do passageiro ao recarregar por Pix — precisa ser validada com o usuário como possível ponto de atenção do produto.
- Não há indicação de app do passageiro (mobile) no repositório inspecionado — pode viver em outro repositório, o que precisa ser confirmado.

---

## 1. Visão

### 1.1 Problema

### 1.2 Usuário Principal

### 1.3 Referências

### 1.4 Pitch

---

## 2. Funcionalidades

### 2.1 Core Features

### 2.2 Integrações

---

## 3. Monetização

### 3.1 Modelo

### 3.2 Planos

---

## 4. Técnico

### 4.1 Stack

### 4.2 Plataforma

---

## 5. Contexto

### 5.1 Referências Visuais

### 5.2 Notas Adicionais

---

## 6. Decisões Registradas

| Código | Decisão | Origem | Impacto |
|---|---|---|---|

---

## 7. Pontos a Validar

| Código | Ponto | Motivo | Impacto |
|---|---|---|---|
| VAL-001 | Confirmar se "Nova feature" é a classificação correta da iniciativa (recarga via Pix dentro do recarga-api existente). | Workspace scan indica claramente um serviço brownfield existente sendo estendido, mas a classificação formal depende de confirmação do usuário na Q1. | Impacta enquadramento do discovery e do PRD |
| VAL-002 | Confirmar se a janela de até 15 minutos para sincronização de saldo com os validadores (ADR-0001) é aceitável para o fluxo de recarga via Pix, ou se essa é uma restrição que a feature precisa endereçar. | Achado do workspace scan (ADR-0001); ainda não discutido com o usuário. | Impacta expectativa de UX do passageiro e possivelmente o desenho técnico da feature |

---

## 8. Resumo Final do Discovery

### 8.1 Resumo por Blocos

### 8.2 Confirmação do Usuário

### 8.3 Status

Em discovery
