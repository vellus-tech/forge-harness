# operator-clearing

- **Subdomínio:** Supporting
- **Bounded context:** Compensação entre Operadoras
- **Compliance:** —
- **Deployable:** DEP-04 clearing-batch (a incluir no TRD)
- **Ownership de dados:** schema `clearing` (tabelas `settlement_period`, `operator_share`)

Responsável por repartir diariamente a receita tarifária entre as três operadoras do consórcio conforme os embarques integrados, gerando o arquivo de liquidação para o banco liquidante.
