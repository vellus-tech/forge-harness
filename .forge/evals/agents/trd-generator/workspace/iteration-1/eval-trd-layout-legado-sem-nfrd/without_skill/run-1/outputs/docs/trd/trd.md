# TRD - Tarifa Aberta

**Versão:** v0.1 | **Status:** Rascunho para revisão | **Fontes:** docs/prd/prd.md (v0.9), docs/frd/frd.md (v0.9), docs/adr/0001-monolito-modular.md

## 1. Contexto e Premissas

Este TRD traduz o FRD da Tarifa Aberta em decisões técnicas para o time de plataforma iniciar o desenho de infraestrutura. O repositório ainda segue a estrutura legada de documentação (PRD, FRD, ADR) e não possui um NFRD nem um padrão de API formalizado. Este documento assume valores de referência para os atributos de qualidade normalmente cobertos por um NFRD e propõe um padrão de API mínimo, ambos marcados como **NEEDS CLARIFICATION** onde a origem é suposição do autor, não requisito aprovado. Nenhum requisito funcional foi bloqueado por essas lacunas.

## 2. Arquitetura de Referência

Conforme ADR-0001, o backend é um monólito modular com deployable único e PostgreSQL com um schema por módulo. Módulos propostos, mapeados a partir do FRD:

| Módulo | Responsabilidade | Requisitos FRD cobertos |
|---|---|---|
| `embarque` | Captura do tap EMV, registro da viagem, liberação offline da catraca | FRD-tap-01, FRD-tap-02 |
| `cobranca` | Agregação diária de taps por cartão e envio à adquirente | FRD-aut-01 |
| `deny-list` | Manutenção e distribuição da lista de cartões restritos | FRD-den-01 |
| `conciliacao` | Conciliação diária com a liquidação da adquirente | FRD-conc-01 |
| `consulta-passageiro` | Exposição das viagens pagas ao app do passageiro | FRD-cons-01 |

O validador embarcado é tratado como cliente externo do backend, não como parte do monólito — ele fala com o backend por API e mantém cache local da deny list para a operação offline (RN-02).

## 3. Requisitos Não Funcionais (inferidos — NFRD ainda não existe)

Não há NFRD aprovado. Os itens abaixo são propostos a partir do domínio (pagamento em transporte público, observação de latência do FRD) e devem ser validados com o time de produto e plataforma antes de virar compromisso formal.

| Atributo | Proposta | Origem / Justificativa | Status |
|---|---|---|---|
| Latência do tap | P99 ≤ 300ms entre tap e liberação da catraca | FRD observa que "o validador tem que responder rápido para não formar fila" | NEEDS CLARIFICATION — valor numérico é suposição |
| Disponibilidade do backend | 99,9% em horário de operação da frota | Padrão de mercado para serviços de bilhetagem; não confirmado | NEEDS CLARIFICATION |
| Operação offline do validador | Até 30 minutos sem conectividade, servindo da deny list local | RN-02 (PRD), requisito confirmado | Confirmado |
| Janela de fechamento da cobrança diária | Processamento da agregação deve concluir antes das 23h59 (RN-03) com folga operacional | RN-03 (PRD) | Confirmado (prazo), folga é suposição |
| Segurança de dados de cartão | Sistema não deve armazenar PAN completo; tokenização/hash na captura do tap | Requisito implícito de qualquer fluxo EMV com adquirente; PCI DSS aplicável ao domínio de pagamentos | NEEDS CLARIFICATION — não há ADR ou NFRD que declare isso explicitamente |
| Volumetria | Não informada (frota, número de validadores, taps/dia) | Ausente em PRD/FRD | NEEDS CLARIFICATION — bloqueia dimensionamento de infraestrutura, não bloqueia o desenho lógico |

## 4. Padrão de API (proposto — não há padrão formalizado no repositório)

Não existe documento de padrão de API no repositório. Proposta mínima para desbloquear o desenho de infraestrutura, a ser ratificada pelo time de plataforma:

- Estilo: REST síncrono para as interações validador → backend e app → backend, alinhado à diretriz de que comunicação externa é REST (o validador e o app são clientes externos ao monólito).
- Autenticação: mTLS ou certificado por validador para o canal validador → backend; token de sessão para o app do passageiro.
- Endpoints indicados pelos requisitos funcionais:
  - `POST /viagens/tap` — FRD-tap-01: registra tap (cartão tokenizado, linha, veículo, timestamp), retorna liberação/negação.
  - `GET /deny-list/sync` — FRD-tap-02, FRD-den-01: sincronização incremental da deny list para cache local do validador.
  - `GET /passageiro/viagens` — FRD-cons-01: consulta das viagens pagas pelo app.
  - Processos internos batch (não expostos como API pública): agregação diária (FRD-aut-01) e conciliação (FRD-conc-01), acionados por job agendado dentro do monólito.
- Versionamento, formato de erro e paginação: **NEEDS CLARIFICATION** — nenhum padrão de API existe no repositório para herdar; time de plataforma deve decidir e registrar em ADR próprio.

## 5. Requisitos Técnicos por Módulo

### 5.1 `embarque`
- TRD-emb-01: expor endpoint de tap que grava a viagem (linha, veículo, horário) de forma idempotente por tap, cobrindo FRD-tap-01.
- TRD-emb-02: manter, no validador, cache local da deny list com TTL compatível com a janela offline de 30 minutos (RN-02, FRD-tap-02); backend expõe endpoint de sincronização incremental.

### 5.2 `cobranca`
- TRD-cob-01: job diário que agrega taps por cartão e monta a cobrança única antes do fechamento das 23h59 (RN-03, FRD-aut-01).
- TRD-cob-02: integração com a adquirente parceira para envio da cobrança agregada; contrato da API da adquirente não está documentado no repositório — **NEEDS CLARIFICATION**.

### 5.3 `deny-list`
- TRD-den-01: cartão com cobrança recusada é incluído na deny list até quitação da dívida (RN-04, FRD-den-01); backend é a fonte da verdade, validadores consomem via sincronização.

### 5.4 `conciliacao`
- TRD-conc-01: job diário de conciliação contra o arquivo/relatório de liquidação da adquirente (FRD-conc-01); formato do arquivo de liquidação não documentado — **NEEDS CLARIFICATION**.

### 5.5 `consulta-passageiro`
- TRD-cons-01: endpoint de consulta de viagens pagas pelo app (FRD-cons-01), Should Have — pode ser adiado em relação aos módulos Must Have para a primeira fase de infraestrutura.

## 6. Dados e Persistência

Um schema PostgreSQL por módulo (ADR-0001). Entidades mínimas inferidas do FRD: `viagem` (embarque), `cobranca_diaria` (cobranca), `deny_list_entry` (deny-list), `conciliacao_diaria` (conciliacao). Modelagem detalhada de colunas e índices fica para a fase de design, não para este TRD.

## 7. Lacunas Explícitas para o Time de Plataforma

- Não existe NFRD: os valores de latência, disponibilidade e segurança na seção 3 são propostos, não aprovados. Recomenda-se abrir a lacuna formalmente antes de dimensionar SLOs de infraestrutura.
- Não existe padrão de API do repositório: a proposta da seção 4 é ponto de partida, não decisão. Recomenda-se um ADR específico de padrão de API.
- Volumetria (frota, validadores, taps/dia) ausente em todo o legado de documentação — necessária para dimensionamento de capacidade.
- Contrato de integração com a adquirente (cobrança e arquivo de liquidação) não documentado.

Nenhuma dessas lacunas impediu a produção deste TRD; cada uma está registrada para não travar o time de plataforma nem ficar invisível.
