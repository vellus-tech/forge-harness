# NFRD — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.1 | 2026-08-20 | Inclui retenção regulatória |

| Código | Categoria | Requisito |
|---|---|---|
| NFR-01 | Performance | Decisão de embarque no validador em até 300 ms, inclusive offline. |
| NFR-02 | Disponibilidade | Recarga pelo app com 99,9% de disponibilidade mensal. |
| NFR-03 | Segurança | Dados de cartão de crédito nunca trafegam nem são armazenados pela Tarifa Viva (tokenização no adquirente; escopo PCI DSS reduzido). |
| NFR-04 | Compliance | Registros de embarque e de recarga são retidos por 5 anos para auditoria do consórcio e do órgão gestor. |
| NFR-05 | Auditoria | O arquivo de clearing é imutável depois de publicado; correções geram arquivo de ajuste. |
