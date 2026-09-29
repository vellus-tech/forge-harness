# Requirements — VOF — Validador Offline de Bilhetagem

- Versão: 1.0.0
- Data: 2026-09-15
- Status: Aprovado

## Requisitos Funcionais

### Req 1 — Validar embarque sem rede

- 1.1 O validador DEVE aceitar cartão ou QR Code com saldo em cache local assinado, mesmo sem conectividade.
- 1.2 O validador DEVE rejeitar cartão presente na lista de bloqueio local.

### Req 2 — Sincronizar validações

- 2.1 Ao recuperar conectividade, o validador DEVE enviar as validações pendentes em lote, em ordem de ocorrência.
- 2.2 O reenvio de um lote já aceito NÃO DEVE gerar cobrança duplicada.

### Req 3 — Atualizar lista de bloqueio

- 3.1 O validador DEVE baixar a lista de bloqueio delta a cada 15 minutos quando houver rede.

## Requisitos Não Funcionais

- **RNF 1:** validação offline em até 300 ms do toque ao feedback visual.
- **RNF 2:** armazenar até 72 h de validações pendentes sem perda após queda de energia.

## Propriedades (PBT)

- **PBT-01 — Idempotência de sincronização:** reenviar qualquer lote N vezes produz o mesmo conjunto de validações no backend.
- **PBT-02 — Ordem preservada:** a ordem das validações no backend é a ordem de ocorrência no validador.
