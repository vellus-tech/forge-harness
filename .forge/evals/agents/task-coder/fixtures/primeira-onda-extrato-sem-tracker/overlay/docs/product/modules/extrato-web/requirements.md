# Requirements — extrato-web

- Status: Aprovado para desenvolvimento

## Req 1 — Filtro por período
Req 1.1 O passageiro filtra o extrato por intervalo de datas fechado `[inicio, fim]` no formato ISO `YYYY-MM-DD`.
Req 1.2 Início posterior ao fim lança `RangeError`.
Req 1.3 O filtro é função pura: não acessa rede nem armazenamento.

## Req 2 — Exportação
Req 2.1 O extrato filtrado pode ser exportado em CSV (separador `;`, valores em centavos).
