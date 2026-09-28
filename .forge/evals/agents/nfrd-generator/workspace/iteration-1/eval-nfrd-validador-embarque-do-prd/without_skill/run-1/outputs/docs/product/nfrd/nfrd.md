# NFRD - Validador de Embarque Contactless

## Controle de Versão

Rascunho gerado a partir do PRD v1.0 (aprovado pelo comitê em 2026-09-10) e das notas de discovery, para a reunião de arquitetura com SRE e AppSec de segunda-feira.

## 1. Objetivo e escopo

Consolidar os requisitos não funcionais verificáveis do validador de embarque contactless (EMV) e do backend de liquidação/conciliação associado, com rastreabilidade direta ao PRD (docs/product/prd/prd.md) e às notas de discovery (docs/discovery/discovery-notes.md). Cada requisito abaixo é testável e traz sua fonte.

## 2. Desempenho e capacidade

- NFR-PERF-01 — Latência de validação: o tempo entre a aproximação do cartão e a liberação da catraca deve ser de no máximo 500 ms no percentil 95, medido ponta a ponta no validador. Rastreabilidade: PRD KPI-01.
- NFR-PERF-02 — Throughput de pico: o backend de ingestão de transações deve sustentar ao menos 250 validações por segundo (janela de pico 6h-8h) sem degradar a latência do NFR-PERF-01. Rastreabilidade: PRD Seção 4 (Volumetria).
- NFR-PERF-03 — Capacidade de armazenamento e processamento diário: o sistema deve processar 900 mil validações por dia útil, com folga de projeto para crescimento de 20% ao ano por pelo menos 3 anos sem redesenho estrutural. Rastreabilidade: PRD Seção 4.
- NFR-PERF-04 — Taxa de recusa técnica: recusas de validação por falha técnica (não por restrição de cartão) devem ficar abaixo de 0,5% das tentativas, medidas mensalmente. Rastreabilidade: PRD KPI-02.

## 3. Disponibilidade e continuidade

- NFR-AVAIL-01 — Disponibilidade do backend: 99,5% de disponibilidade mensal, conforme obrigação contratual com a prefeitura, com apuração por métrica de uptime do serviço de ingestão e liquidação. Rastreabilidade: PRD R-04.
- NFR-AVAIL-02 — Operação offline do validador: o validador embarcado deve continuar aprovando validações localmente (lista de restrição local) por até 72 h contínuas sem conectividade celular, sem perda de transações. Rastreabilidade: PRD R-01.
- NFR-AVAIL-03 — Sincronização pós-falha: 100% das validações realizadas offline devem ser enviadas e confirmadas pelo backend em até 24 h após o restabelecimento de conectividade. Rastreabilidade: PRD KPI-03.
- NFR-AVAIL-04 — Lição da queda de 2025: a arquitetura do backend deve eliminar ponto único de falha que gere indisponibilidade prolongada; nenhuma falha de componente único pode causar indisponibilidade do serviço de ingestão por mais de 30 minutos, com plano de failover documentado e testado. Rastreabilidade: notas de discovery (queda de 6 h em 2025 com fila de embarque e perda estimada de R$ 180 mil) e PRD OBJ-03.
- NFR-AVAIL-05 — Recuperação de desastre: RTO (tempo de recuperação) de no máximo 30 minutos e RPO (perda de dados aceitável) de no máximo 5 minutos para o backend de validação e liquidação. Rastreabilidade: notas de discovery (incidente de 2025) e PRD R-04.

## 4. Segurança

- NFR-SEC-01 — Escopo PCI DSS 4.0.1: todo componente que capture, transmita, processe ou armazene dados de cartão (PAN, dados de trilha) deve operar em conformidade com PCI DSS 4.0.1; o PAN nunca pode ser armazenado em texto claro, em nenhuma camada (validador, backend, logs, backups). Rastreabilidade: PRD R-02.
- NFR-SEC-02 — Tokenização: o PAN deve ser tokenizado antes de qualquer persistência ou agregação por passageiro; a chave de correlação usada nas jornadas J-02 e J-04 do PRD é o token, nunca o PAN em claro. Rastreabilidade: PRD J-02, J-04, R-02.
- NFR-SEC-03 — Criptografia em trânsito e em repouso: toda comunicação entre validador, backend e adquirente deve usar TLS 1.2 ou superior; dados de cartão em repouso devem estar cifrados com algoritmo aprovado (AES-256 ou equivalente). Rastreabilidade: PRD R-02, R-05.
- NFR-SEC-04 — Integridade do firmware: atualizações de firmware do validador devem ser assinadas digitalmente e verificadas antes da instalação; o processo de troca noturna na garagem deve registrar identidade do técnico, versão instalada e resultado da verificação de assinatura. Rastreabilidade: notas de discovery (troca de firmware na garagem sem janela formal).
- NFR-SEC-05 — Controle de acesso ao portal da gestora: acesso às validações de um veículo (jornada J-03) deve ser restrito por perfil e autenticado, com autorização revisável por auditoria. Rastreabilidade: PRD J-03.
- NFR-SEC-06 — Privacidade do extrato do passageiro: o extrato de viagens (jornada J-04) deve ser acessível exclusivamente ao titular do cartão tokenizado autenticado, sem exposição a terceiros, inclusive operadores da gestora. Rastreabilidade: PRD R-03, J-04.

## 5. Auditoria e conformidade (LGPD)

- NFR-AUDIT-01 — Trilha de auditoria da lista de restrição: toda alteração na lista de restrição (inclusão, remoção, atualização) deve gerar registro imutável com identidade do autor (usuário ou processo), timestamp e valor anterior/novo, retido por prazo compatível com auditoria mensal por amostragem. Rastreabilidade: notas de discovery (auditoria mensal por amostragem e exigência de trilha de quem alterou a lista de restrição).
- NFR-AUDIT-02 — Retenção e expurgo LGPD: dados pessoais associados ao token do passageiro devem ter prazo de retenção definido e mecanismo de expurgo ou anonimização mediante solicitação do titular, sem impactar a trilha de auditoria financeira. Rastreabilidade: PRD R-03.
- NFR-AUDIT-03 — Log de conciliação: os arquivos de conciliação diários trocados com a adquirente devem ser armazenados com hash de integridade verificável e vinculados à execução da API REST correspondente, permitindo reconstrução de qualquer cobrança agregada por PAN tokenizado. Rastreabilidade: PRD J-02, R-05.

## 6. Confiabilidade e integridade de dados

- NFR-REL-01 — Consistência de agregação diária: a agregação de tarifas por PAN tokenizado (jornada J-02) enviada à adquirente deve ser idempotente e reconciliável 1:1 com as validações individuais registradas, sem duplicidade nem perda, mesmo em caso de reprocessamento. Rastreabilidade: PRD J-02, OBJ-03.
- NFR-REL-02 — Zero perda de receita: nenhuma validação aprovada localmente pelo validador pode deixar de ser liquidada; toda validação offline pendente de envio deve ser rastreável até a confirmação de recebimento pelo backend (ver NFR-AVAIL-03). Rastreabilidade: PRD OBJ-03.
- NFR-REL-03 — Integridade da lista de restrição local: o validador deve detectar e alertar corrupção ou desatualização crítica da lista de restrição local, evitando aprovações indevidas em campo. Rastreabilidade: PRD J-01.

## 7. Observabilidade e operação

- NFR-OBS-01 — Monitoramento de disponibilidade: o backend deve expor métricas de disponibilidade, latência (para acompanhar NFR-PERF-01) e taxa de recusa técnica (NFR-PERF-04) em tempo real, com alertas configurados para violação de SLA antes do fechamento mensal de apuração contratual. Rastreabilidade: PRD R-04, KPI-01, KPI-02.
- NFR-OBS-02 — Alerta de incidente de conectividade em massa: o sistema deve detectar e alertar quando um número anômalo de validadores entrar em modo offline simultaneamente, como sinal precoce de indisponibilidade de backend (cenário da queda de 2025). Rastreabilidade: notas de discovery.

## 8. Escalabilidade

- NFR-SCALE-01 — Crescimento de frota: a arquitetura deve suportar crescimento de 20% ao ano em número de validadores e volume de transações sem necessidade de redesenho, por horizonte mínimo de 3 anos. Rastreabilidade: PRD Seção 4.

## 9. Rastreabilidade (matriz resumo)

| NFR | Origem no PRD / Discovery |
|---|---|
| NFR-PERF-01 | PRD KPI-01 |
| NFR-PERF-02, NFR-PERF-03 | PRD Seção 4 |
| NFR-PERF-04 | PRD KPI-02 |
| NFR-AVAIL-01 | PRD R-04 |
| NFR-AVAIL-02 | PRD R-01 |
| NFR-AVAIL-03 | PRD KPI-03 |
| NFR-AVAIL-04, NFR-AVAIL-05 | Discovery (queda de 6h em 2025) + PRD OBJ-03/R-04 |
| NFR-SEC-01 a NFR-SEC-03 | PRD R-02, R-05 |
| NFR-SEC-04 | Discovery (troca de firmware na garagem) |
| NFR-SEC-05, NFR-SEC-06 | PRD J-03, J-04, R-03 |
| NFR-AUDIT-01 | Discovery (auditoria mensal, trilha de alteração) |
| NFR-AUDIT-02 | PRD R-03 |
| NFR-AUDIT-03 | PRD J-02, R-05 |
| NFR-REL-01, NFR-REL-02, NFR-REL-03 | PRD J-01, J-02, OBJ-03 |
| NFR-OBS-01, NFR-OBS-02 | PRD R-04 + Discovery |
| NFR-SCALE-01 | PRD Seção 4 |

## 10. Questões em aberto para a reunião de arquitetura

- Confirmar com AppSec o algoritmo e o esquema de gestão de chaves para tokenização do PAN (HSM local no validador vs. tokenização no backend).
- Confirmar com SRE a topologia de failover que atende RTO/RPO do NFR-AVAIL-05 e o custo de manter redundância ativa-ativa.
- Definir com o time de campo um processo formal (janela + aprovação) para troca de firmware, hoje feita sem janela formal, para atender NFR-SEC-04.
