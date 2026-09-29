---
name: conciliacao-csv
description: Concilia extratos bancários em CSV com o razão contábil do projeto, apontando lançamentos sem par, divergência de valor e duplicidades. Use quando o usuário pedir para conciliar um extrato CSV.
---

# Conciliação de extrato CSV

1. Leia o CSV em `data/` detectando separador (`;` ou `,`) e o formato de data (`DD/MM/AAAA`).
2. Normalize valores para centavos inteiros antes de comparar.
3. Pareie cada lançamento do extrato com o razão por (data, valor, documento); tolerância de data D±1.
4. Produza `conciliacao-<mes>.md` com três seções: sem par no extrato, sem par no razão, divergência de valor.
5. Nunca altere o CSV de origem.
