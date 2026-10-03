# Transcript — eval `eval-borda-evento-java-pan-governanca-nao-verificada`, variante `with_skill`, run-1

Agente encarnado: `data-streaming` (definição em `template/.forge/agents/data/data-streaming.md`, somente leitura). Skill carregada: `data-streaming-practices`.

## 0. Bootstrap do harness de eval

- `date +%s > .t0` — instante inicial gravado.
- `mkdir -p work` e execução de `fixtures/borda-evento-java-pan-governanca-nao-verificada/setup.sh work` — materializou o projeto Spring Boot 3.3 + RabbitMQ (pom.xml, `.forge/` overlay completo, `src/main/java/com/exemplo/pagamentos/{PagamentoAprovadoPublisher,ConciliacaoListener}.java`, `src/main/resources/{application.yml,avro/PagamentoAprovado.avsc}`).

## 1. Rules e decisões do projeto (protocolo, passo 1)

Lidos, dentro de `template/.forge/` (fonte canônica, somente leitura):
- `.forge/agents/data/data-streaming.md` — definição do agente e protocolo.
- `.forge/rules/architecture/pii-pci-classification.md` — classificação PII/PAN como código, mascaramento obrigatório, fronteira de tokenização, mapa PCI DSS 4.0.1.
- `.forge/rules/domain/money-as-cents.md` — `applies_to` não lista backend Java; princípio ainda relevante, tratado como observação não bloqueante.
- `.forge/rules/data/schema-evolution.md` — expand/migrate/contract; "schema não é automaticamente o contrato dominante" (evento pode exigir compatibilidade além do schema bruto).
- `.forge/skills/data-streaming-practices/references/antipatterns.md` — catálogo completo, com foco em T-02, RMQ-AP-*, SCH-AP-04.
- `.forge/skills/data-streaming-practices/SKILL.md` e `references/best-practices.md` — consultados para a seção RabbitMQ 4.x.

Não achei ADR específico sobre tokenização de PAN em evento nem sobre este produto (`.forge/product/current/` não foi materializado pela fixture — overlay do harness incompleto neste sandbox, como já registrado em memória do projeto). Segui com o que as rules e a skill declaram.

## 2. Conflito relevante (protocolo, passo 2)

Nenhuma divergência entre rule/ADR do projeto e recomendação da skill: ambos apontam na mesma direção (PAN nunca em evento, DLX obrigatório com requeue controlado, contrato AsyncAPI para evento interno). Não há bloco `CONFLITO` a emitir — a resposta segue direto para achados.

## 3. Dado sensível — `check-data-governance.sh` (protocolo, passo 3)

Comando executado (único de gate permitido pelo hook, além do scan):

```
bash work/.forge/scripts/check-data-governance.sh --path work/src
```

Saída: `FAIL data-governance/universo-vazio — 0 arquivo(s) examinado(s)`. Interpretação pela linha, conforme o protocolo: o verificador só lê `.go/.kt/.ts/.rego/.py/.md`; em projeto Java isso é o esperado, então é "não verificado por esse gate", nunca aprovação nem conflito. Procurei `data-classification.json` no projeto: não existe (só o schema de referência em `.forge/schemas/data-classification.schema.json`). Registrei essa lacuna na resposta.

## 4. Varredura — `scan.sh` (protocolo, passo 4)

Comando executado (o segundo e único outro comando permitido pelo hook):

```
bash template/.forge/skills/data-streaming-practices/scripts/scan.sh --root work/src
```

Saída: 4 arquivos varridos, 30 antipatterns `OK` (nenhuma ocorrência), 2 `FOUND`:
- `RMQ-AP-28` [aviso] — `work/src/main/resources/application.yml:4` — projeto Spring AMQP sem `default-requeue-rejected: false`.
- `T-02` [aviso] — `work/src/main/resources/avro/PagamentoAprovado.avsc:7` — campo `pan` em schema de evento.

Não usei `--json` nem qualquer outro comando Bash (hook `data-agent-bash-guard.sh` nega qualquer coisa fora desses dois). Leitura de arquivo (publisher, listener, avsc, application.yml, rules) foi toda via `Read`/`Grep`/`Glob`, nunca redirecionamento de shell.

## 5. Julgamento (protocolo, passo 5)

Cada `FOUND` foi lido no arquivo e na linha, e julgado contra `references/antipatterns.md`:
- `T-02` confirmado por leitura direta: `.avsc:7` declara `pan: string`, e `PagamentoAprovadoPublisher.java:19` popula com `pagamento.getCartao().getNumero()` — PAN completo, sem token nem máscara. Bloqueante PCI DSS Req. 3.
- `RMQ-AP-28` confirmado por leitura: `application.yml` não define `default-requeue-rejected: false`, `ConciliacaoListener` não trata exceção, e não há declaração de DLX/`delivery-limit` em lugar nenhum do código — risco real de requeue infinito (RMQ-AP-10 implícito), não é falso positivo.

Achados adicionais por julgamento manual (fora do que o scanner detecta, mas dentro do escopo do agente):
- `nomeTitular`/`cpfTitular` como PII sem classificação nem pseudonimização no evento — não é T-02 (não é PAN), mas é LGPD/minimização.
- Publisher confirms configurado em `application.yml` (`publisher-confirm-type: correlated`) mas sem `CorrelationData`/`ConfirmCallback` no código — config sem efeito prático.
- Ausência de contrato AsyncAPI (`SCH-AP-04`) — procurei arquivo `asyncapi.y*ml` no projeto, não existe.
- Ausência de `default`/`doc` por campo no `.avsc` — observação de compatibilidade futura, não bloqueante.
- `valor: double` — antipattern de dinheiro em ponto flutuante; a rule da casa (`money-as-cents.md`) não lista `backend-java` em `applies_to`, então citei como observação para decisão humana e devolvi ao domínio de `data-relational`/dono do agregado, não como bloqueante deste agente.

## 6. Resposta (protocolo, passo 6)

Escrita em `outputs/resposta.md`: veredito (não registrar como está), achados ordenados por severidade com evidência (`arquivo:linha` para os dois achados do scanner; marca `[Julgamento manual]` para os demais), recomendação objetiva em 6 passos, seção "Verificação executada" citando os dois comandos rodados e seus resultados, e devolução ao orquestrador declarando o que é escopo de `data-streaming` e o que pertence a `data-relational`.

Nenhuma escrita foi feita na árvore do projeto avaliado (`work/`) além da leitura — este agente não tem `Write`/`Edit`/`Agent`, e a fixture já veio pronta do `setup.sh`. Nenhum comando de git, teste, `ledger-ops.sh`, `liaison-ops.sh` ou `gh` foi executado, conforme as regras do prompt orquestrador.

## Despacho de subagente que seria feito (não executado, por instrução do orquestrador)

Se este fosse um fluxo real via `data-engineer` (orquestrador), e o time quisesse fechar também a política de retenção/pseudonimização de PII e o tipo de `valor` no agregado `Pagamento`, o próximo passo seria acionar o especialista `data-relational` com a pergunta: "o agregado `Pagamento` já representa `valor` como inteiro em centavos no store, ou herdaria o `double` do publisher?" — não disparado aqui, apenas registrado.
