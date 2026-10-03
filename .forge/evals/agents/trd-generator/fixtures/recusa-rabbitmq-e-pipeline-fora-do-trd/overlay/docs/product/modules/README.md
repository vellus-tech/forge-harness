# Módulos - Tarifa Aberta

| Módulo | Bounded Context | Deployable candidato |
|---|---|---|
| validator-gateway | tap-capture | Serviço de borda que recebe os taps dos validadores |
| fare-authorization | fare-authorization | Serviço + worker de agregação diária |
| deny-list | deny-list | Serviço que publica a lista para os validadores |
| rider-bff | rider-history | BFF do app do passageiro |
| settlement | settlement | Worker batch de conciliação |
