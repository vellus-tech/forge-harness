# Relações entre Bounded Contexts

| Origem | Destino | Tipo de Relação | Padrão DDD | Contrato | Observações |
|---|---|---|---|---|---|
| Fare Collection | Passenger Wallet | Publica evento para | Published Language | FareCharged | Insumo da reconciliação de débito |
| Passenger Wallet | Fare Collection | Publica read model para | Published Language / Read Model | BlocklistSnapshot | Consumido offline pelo validador via ACL |
| Recharge | Passenger Wallet | Publica evento para | Customer/Supplier | RechargeApproved | Wallet é o downstream (Customer) |
| Fare Collection | Settlement | Publica evento para | Published Language | FareCharged | Insumo da apuração diária |
| Settlement | Operadoras (externo) | Expõe arquivo/API para | Open Host Service | Arquivo de repasse diário | Consumido por 3 operadoras |
| Fare Collection | Firmware ValidaBus (externo) | Consome/traduz de | Anti-Corruption Layer | Protocolo proprietário de sincronização em lote | Isola o domínio interno do modelo instável (TEC-03) |
| Recharge | Adquirente de Cartão de Crédito (externo) | Consome/traduz de | Anti-Corruption Layer | Antifraude + tokenização | Nenhum dado de PAN cruza a fronteira (NFR-03) |
| Recharge | PSP de Pix (externo) | Consome/traduz de | Anti-Corruption Layer | Pagamento via Pix | Ponto a Validar VAL-03 |
| Recharge | Ponto de Venda Credenciado (externo) | Expõe API para | Open Host Service | Registro de recarga em dinheiro | — |
| Passenger Wallet | Identity and Access | Depende de | Conformist | Identidade do passageiro autenticado | Wallet não impõe modelo próprio de identidade |
| Passenger Wallet | Notification | Publica evento para | Customer/Supplier | BalanceLow | Notification é downstream genérico |
| Notification | Firebase Cloud Messaging (externo) | Consome/traduz para | Conformist | API de push do FCM | Provedor terceirizado (TEC-04) |
