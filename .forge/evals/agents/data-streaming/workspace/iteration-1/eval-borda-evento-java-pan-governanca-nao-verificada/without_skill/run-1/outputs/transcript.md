# Transcript — eval-borda-evento-java-pan-governanca-nao-verificada / without_skill / run-1

## Tarefa do usuário

> Vamos registrar o schema do evento PagamentoAprovado no schema registry amanhã. Revise o contrato em src/main/resources/avro/PagamentoAprovado.avsc, o publicador e o listener em src/main/java e o application.yml, e me diga se posso registrar como está. O projeto é Spring Boot 3.3 com RabbitMQ.

## Condições da rodada (baseline, without_skill)

- Nenhum skill ou agente de `data-streaming` foi carregado ou consultado. A tarefa foi executada apenas com conhecimento geral do modelo (engenharia de software, mensageria, PCI DSS/LGPD).
- Nenhum comando destrutivo, commit, push, teste ou build foi executado — apenas leitura de arquivos.

## Passos executados

1. Confirmação do diretório de trabalho e do estado inicial (`.t0` gravado com `date +%s`).
2. Preparação do projeto via `setup.sh` do fixture, copiando o projeto Spring Boot para `work/`.
3. Inventário dos arquivos relevantes dentro de `work/`:
   - `src/main/resources/avro/PagamentoAprovado.avsc`
   - `src/main/java/com/exemplo/pagamentos/PagamentoAprovadoPublisher.java`
   - `src/main/java/com/exemplo/pagamentos/ConciliacaoListener.java`
   - `src/main/resources/application.yml`
4. Leitura do conteúdo dos quatro arquivos.
5. Análise do contrato Avro: identificação de que os campos `pan`, `nomeTitular` e `cpfTitular` trafegam em claro, sem mascaramento/tokenização.
6. Análise do publicador: confirmação de que `pan` é preenchido diretamente a partir de `pagamento.getCartao().getNumero()` (PAN completo), e que `aprovadoEm` usa `System.currentTimeMillis()` em vez de um timestamp de domínio.
7. Análise do listener: `acknowledge-mode: auto` no `application.yml`, sem evidência de idempotência no processamento (`conciliacao.registrar(evento)` chamado diretamente) e sem DLQ visível na configuração.
8. Verificação de que `publisher-confirm-type: correlated` está habilitado no `application.yml`, mas o `RabbitTemplate` no publicador não usa `CorrelationData` nem registra `ConfirmCallback`/`ReturnsCallback`.
9. Conclusão: recomendação de **não registrar o schema como está**, com o achado crítico (PAN/CPF/nome em claro no evento) como bloqueante, e os demais pontos (ack mode, idempotência, confirmação de publicação, política de compatibilidade do registry, origem do timestamp) como recomendações de robustez a tratar antes de produção.
10. Deliverable final redigido em `outputs/revisao-schema-pagamento-aprovado.md`.

## Decisões e justificativas

- **PAN completo classificado como bloqueante para registro**: uma vez registrado no schema registry, o contrato passa a ser consumido por terceiros, e remover campos sensíveis depois exige coordenação de compatibilidade — o custo de corrigir antes é muito menor que depois.
- **CPF e nome do titular tratados como achado do mesmo bloco crítico** (dado pessoal / LGPD), não como item separado, porque a correção é a mesma (remover do evento e usar referência).
- **Demais achados (ack mode, idempotência, confirm callback, política de compatibilidade, timestamp) classificados como não bloqueantes**, porque não impedem o registro do schema em si — são robustez operacional do publicador/listener, tratável em paralelo.
- **Seção de limites explícita no deliverable**, sinalizando o que não foi possível verificar apenas lendo o repositório (mascaramento externo, política de retenção do broker, idempotência interna do `ConciliacaoService`, política padrão de compatibilidade do registry da organização) — para não passar confiança maior do que a análise permite.

## Comandos executados

```
date +%s > .../without_skill/run-1/.t0
mkdir -p .../without_skill/run-1/work
bash .../fixtures/borda-evento-java-pan-governanca-nao-verificada/setup.sh .../without_skill/run-1/work
find .../work -iname "*.avsc" -o -iname "application.yml"
find .../work -path "*src/main*" -type f
cat <arquivos acima>
```

Nenhum comando de escrita em git, teste, build, docker, ledger/liaison ou publicação foi executado.
