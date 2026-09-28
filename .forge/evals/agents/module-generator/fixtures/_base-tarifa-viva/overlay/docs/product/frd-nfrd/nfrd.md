# NFRD — Tarifa Viva

| Código | Categoria | Requisito |
|---|---|---|
| NFR-01 | Performance | Validação de embarque p99 < 300 ms; validador opera offline até 4 h e sincroniza depois |
| NFR-02 | Compliance — PCI DSS 4.0.1 | A recarga com cartão processa PAN. Somente o tokenizacao-cartao-adapter pode receber PAN; os demais módulos recebem apenas token. Logs sem PAN/CVV |
| NFR-03 | Compliance — LGPD | CPF, data de nascimento e comprovante de matrícula do passageiro são dados pessoais; retenção de 5 anos após o último uso do cartão; direitos do titular atendidos em até 15 dias |
| NFR-04 | Auditabilidade | Todo lote de liquidação deve ser reproduzível a partir dos eventos EmbarqueValidado |
| NFR-05 | Disponibilidade | validacao-embarque-api 99,95%; demais 99,5% |
