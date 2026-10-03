# FRD - Axis Validação

| Código | Requisito | Módulo |
|---|---|---|
| FRD-VAL-01 | Registrar a validação de embarque (token do cartão, linha, veículo, instante) e publicar o fato para os demais contextos. | validacao |
| FRD-TAR-01 | Calcular a tarifa da validação aplicando integração temporal de 60 minutos. | tarifacao |
| FRD-LIQ-01 | Consolidar as validações do dia e gerar o arquivo de compensação entre operadoras em D+1 até 06:00. | liquidacao |
| FRD-EXT-01 | Expor ao app do passageiro o extrato das viagens por token de cartão. | validacao |
