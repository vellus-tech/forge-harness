# Validação crítica — Segmentação DDD do Embarque Fácil

## Veredito

Não dá para seguir com a derivação de módulos e backlog sem antes decidir os dois achados bloqueantes abaixo (#1 e #2). Ambos envolvem uma escolha de arquitetura (não uma correção mecânica de texto), então foram apontados, não aplicados. Um terceiro achado, de nomenclatura, era seguro e foi corrigido direto no artefato.

## Achados bloqueantes (decisão necessária, não aplicados)

### 1. Escrita cruzada de schema: Recarga grava direto na tabela da Carteira

**Onde:** `docs/product/data-model/data-model.md`, linha da tabela `carteira`: "Dono de escrita: Carteira, **Recarga (UPDATE de `saldo` ao receber o webhook Pix, para evitar latência do evento)**".

**Por que é uma contradição, não uma opção de design:**
- ADR-0002 (`docs/product/adr/0002-schema-por-contexto.md`): "Cada bounded context é dono exclusivo do próprio schema... Joins entre schemas são proibidos" (e a leitura de outro contexto só é permitida via API/evento/read model — a fortiori a escrita também não é permitida fora do dono).
- TRD (`docs/product/trd/trd.md`): "PostgreSQL com um schema por bounded context; **nenhum serviço acessa schema de outro contexto** (ADR-0002)."
- FRD FR-03 (`docs/product/frd-nfrd/frd.md`): "A carteira mantém o saldo do passageiro; **somente a carteira** debita ou credita saldo."
- Subdomínio Carteira Digital (`docs/product/ddd/subdomains/supporting/carteira-digital/README.md`): "único dono de débito e crédito (FR-03)."
- FR-04: "A recarga via Pix confirmada credita a carteira **por meio de evento** de recarga confirmada" — ou seja, o próprio FRD já define o mecanismo correto (evento), que o data model contradiz.
- Context Map e BC Carteira (`bounded-contexts/carteira/README.md`) descrevem a Carteira **consumindo** `RecargaConfirmada` v1 para creditar — o desenho contratual já é event-driven; o data model introduz um atalho de escrita direta "para evitar latência", quebrando o isolamento que todos os outros seis documentos concordam em exigir.

**Risco se seguir sem corrigir:** o pipeline vai gerar módulos/tasks com dois caminhos de escrita concorrentes para `saldo` (evento assíncrono da Carteira + UPDATE síncrono da Recarga), abrindo corrida de concorrência, duplicidade de crédito e uma dependência de deploy escondida (Recarga precisaria do schema da Carteira, o que nenhum ADR autoriza).

**Não apliquei correção porque** a motivação declarada ("evitar latência do evento") é uma decisão de negócio/arquitetura real, não um erro de digitação. Alternativas a decidir: (a) manter só o caminho por evento e aceitar a latência de fila; (b) outbox pattern na Recarga + entrega garantida para reduzir a latência sem escrita cruzada; (c) uma API síncrona (gRPC, conforme ADR-0001) da Carteira para a Recarga confirmar o crédito na hora, mantendo a Carteira como única escritora. Peço decisão antes de tocar no schema.

### 2. Join direto entre schemas no relatório de conciliação

**Onde:** `docs/product/data-model/data-model.md`, seção "Relatórios": `SELECT ... FROM recarga.recarga r JOIN carteira.movimentacao m ON m.recarga_id = r.id`, executado pelo `recarga-svc`.

**Por que é uma contradição:** ADR-0002 proíbe explicitamente joins entre schemas de bounded contexts distintos. Aqui o `recarga-svc` lê diretamente a tabela `movimentacao` do schema `carteira`.

**Não apliquei correção porque** requer decidir onde esse relatório deve viver: um serviço de BI/relatórios dedicado alimentado por read models materializados a partir dos eventos (`TarifaDebitada`, `SaldoCreditado`, `RecargaConfirmada`), ou uma view alimentada por CDC/ETL fora do caminho transacional. Qualquer escolha é uma peça de infraestrutura nova, não uma correção de uma linha.

## Achado corrigido diretamente (correção segura)

### 3. Nome do evento publicado pela Recarga estava trocado pelo comando

**Onde:** `docs/product/ddd/bounded-contexts/recarga/README.md` dizia "Eventos publicados: `ConfirmarRecarga` v1".

**Por que era um erro simples:** `ConfirmarRecarga` é o COMANDO no Event Storming (`docs/product/ddd/ddd-segmentation.md` §3: fluxo J1, comando `ConfirmarRecarga` → evento `RecargaConfirmada`, produtor Recarga). O próprio Context Map (`docs/product/ddd/context-map/README.md`) e o BC Carteira (que consome `RecargaConfirmada` v1) já usam o nome certo. Só o README do BC Recarga estava desalinhado — sem ambiguidade sobre qual é o nome correto, então apliquei a correção direto (arquivo em `outputs/docs-corrigidos/ddd/bounded-contexts/recarga/README.md`).

## Checagens que passaram (sem achado)

- Classificação de subdomínios (Core/Supporting/Generic) é consistente entre `ddd-segmentation.md`, os READMEs de `subdomains/*` e as justificativas de PRD/FRD/NFRD citadas.
- Nomes e versões de evento `EmbarqueRegistrado` v1, `TarifaDebitada` v1 e `SaldoCreditado` v1 são consistentes em todos os documentos que os citam (BCs, Context Map, Event Storming).
- Ownership de schema por BC (`validacao`, `carteira`, `recarga`) bate entre `data-model.md`, os READMEs de bounded context e o TRD (exceto os dois achados acima).
- Módulos/deployables (`docs/product/modules/README.md`) mapeiam 1:1 com os bounded contexts e com o TRD; o subdomínio genérico "Conformidade PCI" não vira módulo próprio porque é tokenização terceirizada (NFR-03), o que é coerente com não aparecer como deployable.
- Glossário (`domain-glossary.md` + `ubiquitous-language.md`) não conflita com os termos usados nos BCs, mas é raso — só dois termos no glossário geral ("Consórcio", "Validador"), enquanto termos centrais usados alhures (ex.: "Integração Temporal", "Janela de Integração", "PSP/ACL") não estão lá. Não é uma inconsistência, é uma lacuna — sinalizo, mas não bloqueia.

## Recomendação

Não mande derivar módulos e backlog ainda. Decida primeiro os achados #1 e #2 — ambos tocam o mesmo ponto (a fronteira Recarga↔Carteira), então uma única decisão de padrão de integração (evento garantido vs. API síncrona vs. outbox) provavelmente resolve os dois de uma vez. Depois disso, o restante da segmentação está internamente consistente e pronto para seguir.
