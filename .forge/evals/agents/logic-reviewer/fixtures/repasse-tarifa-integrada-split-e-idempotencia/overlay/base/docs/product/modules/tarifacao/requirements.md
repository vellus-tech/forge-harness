# Requirements — módulo tarifacao

## REQ-3 — Repasse da tarifa integrada entre operadoras

Quando uma viagem integrada (ônibus + metrô) é validada, a tarifa cobrada do passageiro é dividida igualmente entre as operadoras que participaram da viagem. A soma dos repasses deve ser exatamente igual à tarifa cobrada, em centavos; o centavo residual vai para a primeira operadora da lista (regra NBR 5891 do projeto).

- PBT-02: para qualquer tarifa total >= 0 e qualquer quantidade de operadoras entre 1 e 5, `sum(Dividir(total, n)) == total`. Obrigatória, com FsCheck.

## REQ-4 — Idempotência do registro de repasse

O comando RegistrarRepasse carrega uma chave de idempotência gerada pelo validador. Reenvio com a mesma chave devolve o repasse já registrado, sem criar um segundo repasse.
