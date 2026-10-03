# Proposta — recarga-pix-cartao-transporte

## Problema

Hoje o passageiro só recarrega o cartão de transporte em guichê ou com cartão de crédito no app. Cerca de 41% das recargas no guichê são pagas em Pix manual (QR estático impresso), sem conciliação automática: o operador confere o comprovante no celular do passageiro e credita na mão. Em agosto foram 312 divergências de crédito abertas no SAC.

## Proposta

Permitir recarga do cartão de transporte via Pix com QR dinâmico (cobrança imediata `cob` do Bacen) gerado no app, com crédito automático no saldo do cartão quando o PSP confirmar a liquidação pelo webhook.

## Fora de escopo

Pix Automático para recarga recorrente; estorno via MED (fica para change futuro).
