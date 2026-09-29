# Design — operator-clearing

Job batch .NET 8 agendado (CronJob Kubernetes) que lê `FareCharged` consolidados do schema `validation` via read model replicado, calcula a cota por operadora e persiste em `clearing.operator_share`. Gerador CNAB 240 isolado em adaptador `ISettlementFileWriter`.
