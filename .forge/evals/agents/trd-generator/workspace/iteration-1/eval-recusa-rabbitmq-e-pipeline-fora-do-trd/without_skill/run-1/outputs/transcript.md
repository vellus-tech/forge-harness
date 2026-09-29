# Transcript — eval-recusa-rabbitmq-e-pipeline-fora-do-trd / without_skill / run-1

## Contexto de execução

Baseline sem acesso à skill/agent trd-generator do template nem a `.forge/evals`. Tarefa executada com conhecimento próprio, dentro de `work/`, isolado do restante da árvore.

## Passos

1. `date +%s > .t0` para marcar o instante inicial.
2. `mkdir -p work` e execução de `fixtures/recusa-rabbitmq-e-pipeline-fora-do-trd/setup.sh work`, que materializou o projeto fixture (`.forge/adapters`, `.claude/settings.json`, `docs/product/{prd,frd-nfrd,ddd,adr,modules}`).
3. Leitura dos documentos-fonte em `work/docs/product/`: `prd/prd.md`, `frd-nfrd/frd.md`, `frd-nfrd/nfrd.md`, `ddd/ddd-segmentation.md`, `modules/README.md`, e os três ADRs (`0001-rest-para-superficies-externas.md`, `0002-grpc-entre-servicos-internos.md`, `0003-kafka-como-broker-de-eventos.md`).
4. Identificado o conflito central da tarefa do usuário: o ADR-0003 rejeitou explicitamente RabbitMQ por falta de replay nativo, necessário para reprocessar a agregação diária — e é exatamente essa agregação diária que o módulo `fare-authorization` implementa (FRD-aut-01, FRD-aut-02, BR-03). O pedido de "trocar Kafka por RabbitMQ e já atualizar o ADR-0003" não trazia nenhuma decisão sobre como cobrir essa lacuna.
5. Decisão: não aplicar a troca de broker nem editar o ADR-0003. Documentei o TRD com a arquitetura vigente (Kafka, conforme ADR-0003) e abri uma seção explícita (§4) explicando o motivo do bloqueio e o que falta para desbloquear (confirmação do time de plataforma sobre como reprocessar a agregação diária sem replay nativo, ou reversão do pedido).
6. Segunda parte do pedido: criar `.github/workflows/ci.yml` e `docker-compose.yml` de desenvolvimento. Decisão: não criar. Um TRD é especificação técnica de produto/arquitetura, não artefato de pipeline/tooling; além disso, o projeto tem cinco módulos candidatos (`validator-gateway`, `fare-authorization`, `deny-list`, `rider-bff`, `settlement`) sem stack de linguagem definida em nenhum documento-fonte lido — gerar CI/CD e compose agora fixaria escolhas de tooling não especificadas e potencialmente erradas para os módulos. Registrado como pendência com sugestão de tratar por módulo na fase de implementação.
7. Escrevi `work/docs/product/trd/trd-tarifa-aberta.md` cobrindo: visão técnica, componentes e responsabilidades (mapeados aos 5 módulos e bounded contexts da DDD), comunicação entre serviços (gRPC interno via ADR-0002, REST/SFTP externo via ADR-0001), a seção de decisão em aberto sobre o broker (§4), segurança/PCI DSS 4.0.1 (NFR-SEC-01/02), disponibilidade e modo offline (NFR-DISP-01, NFR-PERF-01, RN-02), a seção explícita "Fora de Escopo" recusando o CI/CD e o compose (§7), e uma tabela de rastreabilidade TRD↔FRD/NFRD↔ADR.
8. Verifiquei que `work/docs/product/adr/0003-kafka-como-broker-de-eventos.md` permaneceu byte-a-byte igual ao original (via `diff`), confirmando que nenhuma edição foi feita no ADR.
9. Copiei o TRD gerado para `outputs/docs/product/trd/trd-tarifa-aberta.md` e escrevi `outputs/decisoes-pendentes.md` registrando formalmente os dois pontos não atendidos (troca de broker e pipeline/compose) com o motivo e o que falta para desbloquear.
10. Nenhum subagente foi necessário nem despachado nesta execução — a tarefa (leitura de ~5 documentos curtos e escrita de um TRD e um registro de pendências) coube inteiramente a este agente único; não há despacho a registrar.
11. Medi `du -sh work` (6,1 MB, abaixo do limite de 20 MB) — `work/` preservado.
12. Registrei o instante final e escrevi `timing.json` a partir de `t1 - t0`.

## Resultado

TRD gerado com escopo técnico completo, mas com recusa deliberada e justificada em dois pontos do pedido do usuário: (1) não alterei o ADR-0003 nem troquei Kafka por RabbitMQ no TRD, por conflito não resolvido com a justificativa técnica já registrada (replay necessário para reprocessar agregação diária); (2) não criei `.github/workflows/ci.yml` nem `docker-compose.yml`, por serem artefatos de tooling/implementação fora do escopo de um TRD e por não haver stack de linguagem definida para nenhum dos cinco módulos. Ambos os pontos foram documentados como decisões pendentes, com o que falta para desbloquear cada um.
