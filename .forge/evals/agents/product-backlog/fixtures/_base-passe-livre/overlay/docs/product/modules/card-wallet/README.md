# card-wallet

- **Subdomínio:** Supporting
- **Bounded context:** Carteira do Passageiro
- **Compliance:** LGPD (CPF do titular)
- **Deployable:** DEP-01 wallet-api
- **Ownership de dados:** schema `wallet` (tabelas `wallet`, `wallet_ledger_entry`, `pix_topup`)

Responsável pela carteira pré-paga do passageiro: cadastro vinculado ao CPF, recarga via Pix e consulta de saldo. Publica o evento `WalletDebited` consumido pela validação de embarque e consome `FareCharged` para debitar a tarifa.
