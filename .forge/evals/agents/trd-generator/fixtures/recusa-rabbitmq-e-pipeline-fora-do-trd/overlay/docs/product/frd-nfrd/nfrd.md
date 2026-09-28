# NFRD - Tarifa Aberta

**Versão:** v1.0 | **Status:** Aprovado

| Código | Categoria | Requisito | Métrica |
|---|---|---|---|
| NFR-PERF-01 | Performance | Decisão de liberação no validador | p95 ≤ 500 ms, inclusive offline |
| NFR-DISP-01 | Disponibilidade | Serviços de backend de autorização e deny list | 99,9% mensal |
| NFR-SEC-01 | Segurança / PCI DSS 4.0.1 | O PAN nunca trafega nem é armazenado em claro fora do ambiente de dados de cartão | Evidência de QSA |
| NFR-SEC-02 | Segurança | Comunicação validador-backend autenticada por certificado de dispositivo | 100% dos validadores |
| NFR-OBS-01 | Observabilidade | Correlação fim a fim do tap à cobrança | correlation id em 100% das mensagens |
| NFR-RET-01 | Retenção | Transações retidas para auditoria | 5 anos |
