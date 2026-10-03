# Subdomínios — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Segmentação DDD inicial a partir de PRD/FRD/NFRD/TRD |

## 1. Critério de classificação

Core = onde o consórcio ganha ou perde a diferenciação competitiva e a confiança das três operadoras; Supporting = lógica de negócio própria do domínio de bilhetagem, mas replicável por qualquer bilhetagem eletrônica; Generic = capacidade que existe fora do domínio de transporte e poderia ser comprada de prateleira.

## 2. Core Domain

### 2.1 Embarque e Tarifação (Fare Charging)
Decide, no momento do embarque e em até 300 ms (NFR-01), se o cartão pode embarcar e qual tarifa debitar — incluindo a regra de integração temporal de 60 minutos (OBJ-03, FR-01, FR-03). É o subdomínio que sustenta OBJ-01 (tempo de embarque) e é o único ponto do sistema onde a promessa "o passageiro sempre embarca rápido, mesmo offline" é cumprida ou quebrada.

### 2.2 Clearing e Repasse (Revenue Settlement)
Apura, ao fim do dia, quanto cada uma das três operadoras (Viação Serrana, Expresso Vale, TransSereno) recebe, com trilha auditável e imutabilidade pós-publicação (OBJ-04, FR-07, NFR-05). É core porque é o mecanismo de confiança financeira entre operadoras concorrentes que dividem a mesma bilhetagem — um erro aqui não é só um bug, é uma disputa comercial entre sócios do consórcio.

## 3. Supporting Subdomains

### 3.1 Carteira do Passageiro (Passenger Wallet)
Mantém saldo, lista de bloqueio e histórico de viagens do passageiro (FR-06, retenção de 30 dias no app). Dá suporte direto ao core (Embarque consome saldo/bloqueio), mas a lógica de "ter um saldo e poder bloqueá-lo" não é exclusiva de bilhetagem.

### 3.2 Recarga (Top-up)
Orquestra a compra de créditos pelo app (cartão de crédito) e o registro de recargas em dinheiro no ponto de venda credenciado (FR-04, FR-05). É o processo de negócio que liga o passageiro à Carteira, mas a mecânica de "comprar crédito pré-pago" é comum a qualquer bilhetagem ou vale-transporte.

### 3.3 Frota de Validadores (Validator Fleet Sync)
Gerencia o parque de validadores embarcados, a sincronização em lote quando o equipamento conecta na garagem e a tradução do protocolo proprietário do fornecedor ValidaBus — cujo modelo de dados é instável entre versões de firmware (TEC-03) — para a linguagem do domínio Tarifa Viva (FR-02, FR-06). Suporte crítico ao core, mas é um problema de integração com hardware de terceiro, não uma regra de negócio de tarifação em si.

### 3.4 Cadastro de Linhas e Operadoras (Route & Operator Registry)
Mantém quais linhas existem e a qual operadora cada linha pertence — dado de referência consumido tanto por Embarque (para saber a tarifa vigente da linha) quanto por Clearing (para atribuir a receita à operadora dona da linha, FR-07). Sem esse cadastro nem o core de tarifação nem o de clearing conseguem operar, mas o cadastro em si é dado mestre, não diferenciação.

## 4. Generic Subdomains

### 4.1 Identidade do Passageiro (Passenger Identity)
Login por CPF e senha com MFA opcional (FR-09). Autenticação de usuário é um problema resolvido por qualquer provedor de identidade de mercado; não há vantagem competitiva em construí-lo do zero.

### 4.2 Notificações (Push Notification)
Envio de aviso de saldo baixo via Firebase Cloud Messaging (FR-08, TEC-04). É apenas um canal de entrega, delegável a um provedor externo.

### 4.3 Integração com Meios de Pagamento (Payment Gateway Integration)
Comunicação com o adquirente de cartão de crédito e o PSP de Pix para autorizar recargas, respeitando o requisito de que dado de cartão nunca trafega nem é armazenado pela Tarifa Viva (NFR-03). É um adaptador para capacidade externa regulada, não uma competência própria do domínio de bilhetagem.

## 5. Tabela-resumo

| Subdomínio | Tipo | Requisitos-fonte |
|---|---|---|
| Embarque e Tarifação | Core | OBJ-01, OBJ-03, FR-01, FR-03, NFR-01 |
| Clearing e Repasse | Core | OBJ-04, FR-07, NFR-05 |
| Carteira do Passageiro | Supporting | FR-06, retenção (PRD §5) |
| Recarga | Supporting | FR-04, FR-05, NFR-02 |
| Frota de Validadores | Supporting | FR-02, FR-06, TEC-03 |
| Cadastro de Linhas e Operadoras | Supporting | FR-01, FR-07 (dado de referência implícito) |
| Identidade do Passageiro | Generic | FR-09 |
| Notificações | Generic | FR-08, TEC-04 |
| Integração com Meios de Pagamento | Generic | FR-04, NFR-03 |
