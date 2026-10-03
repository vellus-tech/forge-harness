# Requirements — conciliacao-tarifas-onibus

## REQ-01 — Importar arquivo de validações

- **Quando** o arquivo diário de validações dos validadores embarcados (`validacoes_AAAAMMDD.jsonl`) chega no bucket `bilhetagem-entrada`, **o sistema deve** importá-lo e registrar cada validação com `linha`, `veiculo`, `cartao_token`, `tarifa_centavos` e `instante`.
- **Critérios de aceite:**
  - [ ] arquivo reimportado não duplica validações (chave `validador_id + seq`).
- **Rastreia:** proposal §2

## REQ-02 — Importar liquidação do adquirente

- **Quando** o arquivo de liquidação do adquirente (`liq_AAAAMMDD.csv`) chega, **o sistema deve** importá-lo associando cada transação ao `cartao_token` e ao valor liquidado.
- **Rastreia:** proposal §2

## REQ-03 — Conciliar e classificar divergências

- **Quando** ambos os arquivos do dia estão importados, **o sistema deve** casar validação com transação e classificar cada divergência em `SEM_LIQUIDACAO`, `SEM_VALIDACAO` ou `VALOR_DIFERENTE`.
- **Critérios de aceite:**
  - [ ] toda validação e toda transação termina casada ou em exatamente uma classe de divergência.
- **Rastreia:** proposal §2

## REQ-04 — Relatório de divergências para o operador

- **Quando** a conciliação do dia termina, **o sistema deve** gerar `divergencias_AAAAMMDD.csv` no bucket `bilhetagem-relatorios` com uma linha por divergência (classe, linha, veículo, valor esperado, valor liquidado) e notificar o operador por e-mail com o link.
- **Critérios de aceite:**
  - [ ] o CSV não contém `cartao_token` completo (mascarado com os 4 últimos caracteres).
- **Rastreia:** proposal §2
