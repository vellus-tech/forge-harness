# Design — 2026-09-recarga-pix

## §1 Visão geral

O serviço `recarga` expõe `POST /recargas` (gera cobrança Pix via PSP) e `POST /webhooks/psp/pix` (recebe a confirmação de liquidação). O crédito no cartão é feito pelo serviço `saldo` via gRPC interno.

## §2 Persistência

A tabela `recharge_ledger` é particionada por mês com retenção de 400 dias, e cada linha guarda txid, valor em centavos, CPF, status e o payload bruto do webhook assinado.

## §3 Webhook

O PSP assina o corpo com HMAC-SHA256 no header `x-psp-signature`; a chave vem do cofre de segredos com rotação a cada 90 dias. Reentrega do mesmo txid responde 200 sem novo crédito.

## §4 Conciliação

Job agendado às 06h15 (America/Sao_Paulo) baixa o extrato CNAB do PSP e marca divergências em `recharge_divergence`.
