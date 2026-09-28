# FRD — Tarifa Viva

| Código | Requisito | Capability |
|---|---|---|
| FR-01 | Validar embarque por cartão transporte ou QR e debitar a tarifa vigente | CAP-01 Validação de Embarque |
| FR-02 | Recarregar saldo do cartão transporte pelo app com cartão de crédito/débito | CAP-02 Recarga |
| FR-03 | Estornar recarga não confirmada pela adquirente em até 24 h | CAP-02 Recarga |
| FR-04 | Calcular tarifa (inteira, meia estudantil, gratuidade, integração em 60 min) | CAP-03 Tarifação |
| FR-05 | Fechar lote diário de liquidação por operadora e gerar arquivo de repasse | CAP-04 Liquidação |
| FR-06 | Cadastrar passageiro com CPF, data de nascimento e comprovante de matrícula | CAP-05 Cadastro |

## APIs definidas

| Método | Endpoint | Requisito |
|---|---|---|
| POST | /v1/validacoes | FR-01 |
| POST | /v1/recargas | FR-02 |
| GET | /v1/passageiros/{id} | FR-06 |
