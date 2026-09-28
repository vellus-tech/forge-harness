# FRD — Passe Urbano

Versão 1.1.0 · 2026-08-14

- RF-01 (cadastro-passageiro): cadastrar passageiro com CPF, nome, e-mail e telefone.
- RF-02 (cadastro-passageiro): emitir cartão de transporte vinculado ao passageiro.
- RF-03 (recarga): recarregar saldo do cartão com cartão de crédito/débito tokenizado pelo gateway; o sistema nunca recebe PAN em claro.
- RF-04 (recarga): consultar a tarifa vigente para calcular a quantidade de passagens exibida ao passageiro.
- RF-05 (tarifacao): publicar e versionar tabela tarifária aprovada pelo poder concedente.
- RF-06 (notificacoes): enviar SMS e e-mail ao passageiro quando a recarga for confirmada (evento RecargaConfirmada).
