# Sprints Planning

- **Versão:** 1.0.0
- **Sprint length:** 2 semanas
- **Total de sprints:** 3
- **Período:** 2026-10-05 a 2026-11-15

## 1. Visão Executiva

O plano cobre os dois módulos já especificados do Passe Livre Digital, respeitando a dependência declarada no TRD e nos `tasks.md`: fare-validation depende da fundação de card-wallet (schema, outbox e o endpoint de criação de carteira) antes de poder cobrar tarifa e debitar saldo. A Sprint 1 sobe a infraestrutura dos dois deployables (wallet-api e validation-sync) e entrega a primeira fatia de valor do passageiro, criar a carteira. A Sprint 2 entrega o caminho de dinheiro do passageiro (recarga Pix, saldo/extrato) em paralelo ao cadastro e ingestão de lotes do validador embarcado, já que essas duas frentes não têm dependência cruzada entre si. A Sprint 3 fecha o laço: aplica a integração tarifária de 60 minutos, confirma o débito na carteira e entrega a consulta de auditoria do backoffice, sendo deliberadamente mais leve para reservar capacidade à ressalva do relatório de validação de módulos (SLO de latência de sincronização offline ainda não numérico no NFRD do fare-validation).

## 2. Mapa Módulo → Sprints

| Módulo | Sprints envolvidas | Marco principal |
|---|---|---|
| card-wallet | Sprint 1, Sprint 2 | Passageiro cria carteira, recarrega via Pix e consulta saldo/extrato |
| fare-validation | Sprint 1, Sprint 2, Sprint 3 | Validador embarcado sincroniza lotes offline e a tarifa é cobrada com integração de 60 minutos, debitando a carteira |

## 3. Tabela de Sprints

| Sprint | Slug | Objetivo (1 frase) | Início | Fim | Stories | Story Points |
|---|---|---|---|---|---|---|
| 1 | fundacao-e-criacao-de-carteira | Ao final desta sprint, a infraestrutura de wallet-api e validation-sync está no ar (CI, schemas, outbox transacional) e o passageiro consegue criar sua carteira vinculada ao CPF via API, viabilizando a primeira integração do app | 2026-10-05 | 2026-10-18 | 1 | 20 (15 infra + 5 US-001) |
| 2 | recarga-pix-cadastro-validador-e-auditoria | Ao final desta sprint, o passageiro consegue recarregar a carteira via Pix e consultar saldo/extrato, o validador embarcado está cadastrado e autenticado por mTLS enviando lotes de embarque, e o operador de backoffice já consegue auditar esses embarques | 2026-10-19 | 2026-11-01 | 4 | 22 |
| 3 | integracao-tarifaria-e-confirmacao-de-debito | Ao final desta sprint, o sistema cobra automaticamente a tarifa com integração de até 60 minutos e confirma o débito na carteira do passageiro, entregando o fluxo ponta-a-ponta do Passe Livre Digital | 2026-11-02 | 2026-11-15 | 1 | 11 (8 US-005 + 3 infra)

## 4. Dependências Críticas

| Sprint | Depende de | Motivo |
|---|---|---|
| Sprint 2 | Sprint 1 | US-002 e US-003 exigem o endpoint de criação de carteira (T-003, US-001) já implantado; US-004 exige o scaffold do worker validation-sync (T-008), que por sua vez depende do scaffold do wallet-api (T-001) |
| Sprint 3 | Sprint 1, Sprint 2 | US-005 (FareCalculator) depende do webhook Pix idempotente da Sprint 2 (T-005, dentro de US-002) e da ingestão de lote da Sprint 2 (T-010, dentro de US-004); o painel OpenTelemetry (T-014) depende da ingestão de lote (T-010) |

## 5. Riscos de Cronograma

| Risco | Sprint impactada | Mitigação |
|---|---|---|
| SLO de latência de sincronização offline ainda sem número no NFRD (ressalva do `modules-validation-report.md`) | Sprint 3 | Capacidade da Sprint 3 deixada abaixo do teto do time (11 de ~24 pontos) para absorver ajuste de `FareCalculator` assim que o SLO for definido, sem estourar a sprint |
| fare-validation TASK-01 depende de card-wallet TASK-01 no mesmo sprint | Sprint 1 | Sequenciar T-001 (card-wallet) antes de T-008 (fare-validation) dentro da sprint; se T-001 atrasar, T-008 e toda a Sprint 2 de fare-validation deslizam junto |
| Time de 4 devs sem histórico de velocidade real no projeto (capacidade de 24 pts/sprint é estimativa do usuário, não medida) | Todas | Revisar velocidade real ao fim da Sprint 1 e replanejar Sprint 2/3 se o realizado divergir da estimativa |
