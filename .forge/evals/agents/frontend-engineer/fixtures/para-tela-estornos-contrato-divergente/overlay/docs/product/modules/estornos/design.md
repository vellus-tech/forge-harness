# Design — módulo estornos

## DD-004 — Aprovação de estorno com quatro olhos

Estorno só é efetivado após duas aprovações de operadores distintos (exigência de controle interno e PCI DSS 10/7). A UI deve refletir o estado `AGUARDANDO_SEGUNDA_APROVACAO` retornado pela API e **não pode** fazer atualização otimista da fila: o item só sai da lista quando a API responder `APROVADO`.

## DD-005 — Valores monetários

O frontend exibe valores a partir do contrato `contracts/estornos.openapi.yaml`, sem recalcular nem arredondar no cliente.
