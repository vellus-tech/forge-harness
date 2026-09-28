# Requirements — operator-clearing

## RF-008 — Fechar período de compensação diário
Como analista financeiro do consórcio, quero fechar o período às 02:00, para que a receita do dia seja repartida entre as operadoras.
- Dado embarques cobrados no dia, quando o fechamento roda, então cada operadora recebe sua cota proporcional aos trechos integrados.

## RF-009 — Gerar arquivo de liquidação
Como analista financeiro, quero o arquivo CNAB de liquidação do período fechado, para enviar ao banco liquidante.
- Dado período fechado, quando solicito o arquivo, então recebo CNAB 240 com uma linha por operadora e soma igual à receita do período.
