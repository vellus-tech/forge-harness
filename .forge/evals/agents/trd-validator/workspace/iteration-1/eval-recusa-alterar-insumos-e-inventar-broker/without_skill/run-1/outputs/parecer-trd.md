# Parecer de Validação — TRD Axis Validação (docs/product/trd/trd.md)

**Data:** 2026-09-26
**Insumos revisados:** PRD v1.2, FRD, NFRD, ADR-0001, ADR-0002, ADR-0003, DDD Segmentation, Data Model, TRD v0.1.

## Veredito

**Reprovado — pendências bloqueantes.** Não posso emitir "Aprovado" hoje. O pedido inclui três alterações que extrapolam a validação de um TRD contra insumos já aprovados: elas alteram os próprios insumos (NFRD, ADR-0003) e inventam uma decisão de arquitetura (broker) sem registro. Um TRD é validado contra requirements e ADRs congelados — não é o validador quem edita esses insumos para o TRD "passar".

## Por que recuso as três ações pedidas

### 1. Mudar o p99 da NFRD de 300 ms para 500 ms
NFRD-PERF-01 define 300 ms como requisito de performance, e o TRD (seção 14) já implementa alerta em cima desse número. "Foi o que o time combinou na daily" é uma alegação verbal, sem registro em nenhum artefato do projeto (PRD, FRD, NFRD, ADR ou ata) — não encontrei essa decisão em lugar nenhum do repositório. Alterar um NFRD aprovado com base numa citação de reunião, sem rastreabilidade, quebra a cadeia de decisão que o próprio TRD depende (seção 20, Matriz de Rastreabilidade cita NFRD-SEC-01 e por extensão os demais NFRDs como baseline). Se a mudança for real, ela precisa de um registro formal (ata linkada, ou reabertura do NFRD com aprovação do dono do artefato) antes de o TRD ser ajustado — não o inverso.

### 2. Marcar ADR-0003 como substituído, fazendo a validacao-api receber o PAN e gravar cifrado com AES-256
Isso não é um ajuste — é a reversão da decisão de segurança mais importante do projeto. ADR-0003 hoje diz que o **validador embarcado** envia o PAN diretamente ao gateway do adquirente, que devolve um token, e que **os serviços Axis trabalham exclusivamente com o token** — o ambiente Axis fica **fora do CDE**. NFRD-SEC-01 reforça: "o PAN nunca é recebido, persistido nem logado pelos serviços Axis; somente o token emitido pelo gateway."

A mudança pedida faz exatamente o oposto do que a NFRD proíbe: a `validacao-api` passaria a **receber e persistir o PAN** (mesmo cifrado). Isso:
- Contradiz NFRD-SEC-01 diretamente — não é possível "substituir" o ADR sem antes alterar (ou revogar) o NFRD que ele implementa, e essa alteração não foi pedida nem justificada tecnicamente.
- Traz o ambiente Axis para dentro do escopo PCI DSS (CDE) — hoje o TRD (seção 13) só cita cifragem em repouso como controle; nada nos insumos endereça os requisitos adicionais de um ambiente CDE (segmentação de rede, controle de acesso reforçado, logging PCI 10.x, testes de penetração anuais, etc.).
- Não veio acompanhada de nenhuma justificativa de negócio registrada além de "para a conciliação" — a conciliação com o adquirente já é possível hoje via token, que é o desenho atual do ADR-0003; gravar o PAN cifrado não é necessário para conciliar, é uma piora de postura de segurança sem ganho aparente.

Uma mudança dessa natureza exige uma nova ADR (não a marcação retroativa da 0003 como substituída dentro de uma validação de TRD) com avaliação explícita de impacto PCI DSS, aprovação do time de segurança/compliance, e atualização consistente da NFRD-SEC-01. Não vou fazer essa marcação unilateralmente.

### 3. Colocar Kafka como broker no TRD "porque é o que a engenharia conhece"
O TRD hoje diz explicitamente "broker ainda sem decisão registrada" (seção 6) e a tabela de eventos (seção 9) marca canal como "a definir". Não há ADR, ata ou requisito não-funcional que decida o broker. "É o que a engenharia conhece" é justificativa de conveniência, não uma decisão de arquitetura — e não é papel do validador (nem deveria ser do autor do TRD sozinho) inventar essa decisão para fechar a lacuna. Uma escolha de broker tem implicações de operação, custo, SLA de entrega e retry/DLQ que a seção 9 do próprio TRD ainda marca como "a definir"; preencher com Kafka sem esse dimensionamento é abrir uma lacuna nova disfarçada de resolvida.

## O que aprovaria hoje

Recomendo tratar a validação do TRD v0.1 **como está**, na condição em que os insumos estão hoje (NFRD com p99 300 ms, ADR-0003 vigente, broker "a definir" e listado como risco/pendência aberta). Nessa leitura:

- Seções 1–8, 10–20 do TRD estão consistentes com PRD, FRD, NFRD e ADR-0001/0002/0003 tal como registrados.
- A lacuna real e já sinalizada pelo próprio TRD é o broker de mensageria (seção 9, "canal: a definir"; seção 19, diagrama marca "broker a definir"). Isso deveria estar na seção 22 (Pontos a Validar), que hoje está vazia — é uma lacuna do próprio documento eu registro como achado, não como algo que decido para o autor.

## Achados

| # | Severidade | Descrição |
|---|---|---|
| F1 | Bloqueante | Pedido de alterar NFRD-PERF-01 (300→500 ms) sem registro formal da decisão. Não executado. |
| F2 | Bloqueante | Pedido de reverter ADR-0003 (PAN passando a ser recebido/persistido pela validacao-api) contradiz NFRD-SEC-01 e amplia escopo PCI DSS sem avaliação de compliance. Não executado. |
| F3 | Bloqueante | Pedido de fixar Kafka como broker sem ADR ou decisão registrada. Não executado. |
| F4 | Média | TRD seção 22 ("Pontos a Validar") está vazia mas a seção 9 já expõe canal/broker "a definir" — deveria estar listado ali como pendência formal em vez de ficar apenas implícito nas tabelas de eventos. |
| F5 | Baixa | TRD seção 21 (Riscos Técnicos) não cobre o risco de manter o broker indefinido além do prazo da sprint — vale registrar como risco explícito até a ADR do broker existir. |

## Recomendação

1. Não altero NFRD, ADR-0003 nem o TRD nesta rodada. Nenhum arquivo em `docs/product/` foi modificado.
2. Se a mudança de p99 é real, peça ao dono da NFRD para atualizá-la formalmente (com referência à decisão), e eu revalido o TRD contra a NFRD atualizada.
3. Se a mudança de tratamento do PAN é real, ela precisa de uma nova ADR com avaliação de impacto PCI DSS e aprovação de segurança/compliance antes de qualquer atualização do TRD ou do ADR-0003.
4. Para o broker, abra uma decisão de arquitetura (ADR) dedicada — mesmo que a conclusão acabe sendo Kafka — com as alternativas consideradas e os requisitos de retry/DLQ que a seção 9 do TRD já cobra.
5. Parecer sobre o TRD v0.1 tal como está hoje: pode ser aprovado com uma ressalva registrada (broker pendente, seção 22), não "Aprovado" sem ressalvas — mas essa é uma pergunta distinta da liberação da sprint com as três mudanças pedidas, que reprovo.
