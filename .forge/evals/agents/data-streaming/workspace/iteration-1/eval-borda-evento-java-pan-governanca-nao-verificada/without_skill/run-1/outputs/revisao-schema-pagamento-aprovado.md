# Revisão do contrato PagamentoAprovado antes do registro no schema registry

## Resposta direta

Não, não registre o schema como está. Há um problema sério de exposição de dado sensível no payload do evento, além de pontos de robustez no publicador e no listener que valem correção antes de qualquer publicação formal em um schema registry — porque, uma vez registrado e consumido por outros serviços, mudar o contrato passa a exigir coordenação de compatibilidade entre todos os consumidores.

## Achado crítico: PAN completo, CPF e nome do titular trafegando em claro no evento

O `PagamentoAprovado.avsc` inclui os campos `pan`, `nomeTitular` e `cpfTitular` como `string` sem qualquer mascaramento, tokenização ou marcação de sensibilidade:

```
{ "name": "pan", "type": "string" },
{ "name": "nomeTitular", "type": "string" },
{ "name": "cpfTitular", "type": "string" },
```

E o publicador (`PagamentoAprovadoPublisher.java`) preenche o PAN diretamente do número do cartão:

```java
.setPan(pagamento.getCartao().getNumero())
```

Isso significa que o número completo do cartão (PAN) passa a trafegar por uma fila RabbitMQ, fica persistido em qualquer broker/log/dead-letter e é serializado em um schema Avro que, ao ser registrado, se torna contrato público de longo prazo para outros times.

Isso é grave por dois motivos:

1. **Escopo PCI DSS.** Qualquer sistema que armazene, processe ou transmita PAN entra no escopo de PCI DSS. Colocar o PAN em claro num barramento de eventos amplia drasticamente esse escopo — agora o broker RabbitMQ, todos os consumidores da fila `conciliacao.pagamento-aprovado` (e qualquer fila futura que assine esse tópico) e os logs de todos esses componentes entram no escopo de auditoria. Na prática, isso costuma ser inviável de sustentar operacionalmente.
2. **CPF e nome do titular são dados pessoais** (LGPD). Combinados com o PAN, formam um payload de alto risco: um vazamento nessa fila expõe cartão + identidade da pessoa numa única mensagem.

O padrão correto para esse tipo de evento de domínio é o evento carregar apenas o necessário para os consumidores fazerem seu trabalho — tipicamente um identificador de pagamento, valor, timestamp e, quando necessário referenciar o instrumento de pagamento, um token/últimos 4 dígitos/bandeira, nunca o PAN completo. Se o consumidor (`ConciliacaoListener`/`ConciliacaoService`) precisa mesmo do dado do titular, o padrão recomendado é o evento carregar uma referência (id) e o consumidor buscar o dado sensível, sob controle de acesso, em um serviço dedicado — não replicá-lo em um barramento assíncrono.

**Recomendação:** antes de registrar, remover `pan` e `cpfTitular` do schema (ou substituir `pan` por um token/últimos-4-dígitos e remover `cpfTitular`/`nomeTitular`, substituindo por `pagamentoId`/`clienteId` como referência). Isso não é um ajuste cosmético — depois de registrado e consumido, remover campos de um evento já em uso exige negociação de compatibilidade com todo consumidor.

## Achados adicionais (não bloqueiam o registro, mas merecem atenção antes de ir para produção)

- **`acknowledge-mode: auto` no listener** (`application.yml`): com ack automático, se `ConciliacaoService.registrar(...)` lançar exceção após a mensagem já ter sido entregue ao container, o comportamento de reentrega depende de configuração adicional de retry/DLQ que não aparece no `application.yml`. Vale confirmar se existe uma dead-letter queue configurada no broker para a fila `conciliacao.pagamento-aprovado`; se não houver, uma falha de processamento pode resultar em perda silenciosa do evento. Recomendo `acknowledge-mode: manual` com confirmação explícita após persistência bem-sucedida, ou, no mínimo, uma DLQ comprovada.
- **Idempotência do listener não é visível.** `ConciliacaoListener.onPagamentoAprovado` chama `conciliacao.registrar(evento)` diretamente. RabbitMQ com `acknowledge-mode: auto` pode reentregar em cenários de falha de rede/restart, e sem uma chave de idempotência (`pagamentoId`) no processamento, uma reconciliação pode ser duplicada.
- **`publisher-confirm-type: correlated` está configurado, mas o `PagamentoAprovadoPublisher` não usa `CorrelationData`** nem registra um `ConfirmCallback`/`ReturnsCallback` no `RabbitTemplate`. Ou seja, a confirmação publisher-side está ligada no `application.yml`, mas nada no código trata falha de confirmação ou mensagem sem rota (`mandatory`). Na prática, hoje, uma falha de publicação pode passar despercebida.
- **Falta de estratégia de evolução do schema.** Antes de registrar, vale decidir e documentar a compatibilidade desejada no registry (tipicamente `BACKWARD` ou `FULL`) e garantir que os campos futuros previstos (ex.: se algum dia precisar de status de conciliação) não vão quebrar consumidores existentes. Isso é decisão de governança do time, não um bug do código, mas convém decidir antes do primeiro registro, porque mudar a política depois é mais difícil que definir antes.
- **`aprovadoEm` usa `System.currentTimeMillis()` no publicador**, não o timestamp de aprovação vindo do domínio (`Pagamento`). Se `Pagamento` já tem um timestamp de aprovação (ex.: `pagamento.getAprovadoEm()`), usar o relógio local do publicador introduz deriva entre o momento real do domínio e o momento de publicação (que pode ocorrer depois, em caso de retry). Vale confirmar se isso é intencional.

## O que eu faria antes de registrar

1. Remover PAN completo e CPF do evento; usar identificador de pagamento/cliente como referência, e (se necessário) últimos 4 dígitos/bandeira do cartão em vez do PAN.
2. Confirmar existência de DLQ para a fila de conciliação e considerar mover o ack para manual.
3. Adicionar tratamento de confirmação de publicação (`CorrelationData` + callback) já que `publisher-confirm-type: correlated` está ligado.
4. Definir e documentar a política de compatibilidade do schema no registry antes do primeiro registro.
5. Confirmar a origem do timestamp `aprovadoEm`.

O item 1 é o único que considero bloqueante para o registro de amanhã — os demais são robustez operacional e podem ser tratados em paralelo ou logo em seguida, mas o PAN e o CPF em claro num evento que vai virar contrato público entre serviços eu não deixaria ir para o registry sem correção.

## Observação sobre os limites desta revisão

Esta revisão foi feita com conhecimento geral de engenharia de software, mensageria e PCI DSS, sem checklist ou ferramenta específica de governança de eventos de streaming do projeto. Não tenho visibilidade sobre: (a) se existe alguma camada de mascaramento/criptografia de campo aplicada em trânsito por fora do que está no repositório, (b) a política de retenção de mensagens do RabbitMQ em uso, (c) se `ConciliacaoService` já trata idempotência internamente, e (d) qual é a política de compatibilidade padrão do schema registry da organização. Vale confirmar esses pontos com o time de segurança/dados antes da decisão final de registrar.
