# ADR-0020 — Cache de saldo do cartão em Redis

Status: Aceito

O saldo do cartão é lido de um cache Redis com TTL de 30 s; toda escrita de crédito deve invalidar a chave `saldo:<cartao_id>`.
