# fare-validation

- **Subdomínio:** Core
- **Bounded context:** Validação de Embarque
- **Compliance:** —
- **Deployable:** DEP-02 validation-sync
- **Ownership de dados:** schema `validation` (tabelas `boarding_event`, `fare_rule`, `validator_device`)

Responsável por aplicar a tarifa no embarque: recebe lotes de transações offline dos validadores embarcados, aplica a regra de integração temporal e publica `FareCharged` para o card-wallet debitar. Depende do card-wallet existir para haver saldo a debitar.
