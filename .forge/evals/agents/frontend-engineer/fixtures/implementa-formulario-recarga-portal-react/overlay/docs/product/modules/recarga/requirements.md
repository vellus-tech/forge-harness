# Requirements — módulo recarga

- **REQ-RC-01** — O passageiro escolhe um valor rápido (R$ 10, R$ 20 ou R$ 50) ou digita outro valor entre R$ 5,00 e R$ 500,00.
- **REQ-RC-02** — Valor fora da faixa exibe erro no próprio campo, sem chamar a API.
- **REQ-RC-03** — Erros de negócio da API (`LIMITE_DIARIO_EXCEDIDO`, `CARTAO_BLOQUEADO`) exibem a `message` retornada, preservando o valor digitado.
- **REQ-RC-04** — Um clique gera no máximo uma cobrança: o envio não pode ser duplicado por clique repetido nem por reenvio automático.
- **REQ-RC-05** — Após sucesso (201), a tela mostra a confirmação com o `status` retornado.
