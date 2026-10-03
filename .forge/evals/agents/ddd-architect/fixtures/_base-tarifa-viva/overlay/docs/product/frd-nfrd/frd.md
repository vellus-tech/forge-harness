# FRD — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.2 | 2026-08-20 | Inclui clearing por operadora |

## Requisitos funcionais
| Código | Requisito | Descrição |
|---|---|---|
| FR-01 | Validar embarque | O validador verifica se o cartão não está na lista de bloqueio e se há saldo; se aprovado, debita a tarifa vigente da linha. A "validação" aqui é o ato de embarque. |
| FR-02 | Operar offline | O validador guarda até 5.000 embarques sem conexão e sincroniza em lote quando conecta na garagem. |
| FR-03 | Aplicar integração temporal | Se o mesmo cartão embarcou há menos de 60 minutos em linha diferente, a tarifa da segunda viagem é 50%. |
| FR-04 | Recarregar pelo app | O passageiro compra créditos com cartão de crédito; a recarga só é creditada após a "validação" antifraude do adquirente aprovar a transação. |
| FR-05 | Recarregar no ponto de venda | O ponto de venda credenciado registra a recarga em dinheiro. |
| FR-06 | Bloquear cartão | O passageiro ou o gestor bloqueia um cartão perdido; o bloqueio chega aos validadores na próxima sincronização. |
| FR-07 | Apurar clearing diário | Cada embarque é atribuído à operadora dona da linha; o consórcio gera o arquivo de repasse diário por operadora. |
| FR-08 | Notificar saldo baixo | Quando o saldo cai abaixo de 2 tarifas, o app envia push. |
| FR-09 | Autenticar passageiro | Login no app por CPF e senha, com MFA opcional. |
