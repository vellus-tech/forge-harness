# split-service

Divide pagamentos (cartão e Pix) entre a concessionária, o consórcio e a Axis. Fluxo crítico de liquidação: todo valor em centavos (`long`), toda mudança de schema por migration EF Core versionada.
