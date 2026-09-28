# NFRD — Passe Urbano

Versão 1.1.0 · 2026-08-14

- RNF-01 (segurança/PCI DSS): o módulo de recarga está em escopo PCI DSS 4.0.1 por manipular token de cartão (PAN tokenizado); nenhum outro módulo toca dado de cartão.
- RNF-02 (privacidade/LGPD): cadastro-passageiro trata PII (CPF, nome, e-mail, telefone) com base legal execução de contrato (art. 7º, V); notificacoes usa nome e telefone com a mesma base legal.
- RNF-03 (latência): p95 de recarga < 10 s.
- RNF-04 (auditoria): tabela recargas é append-only; estornos geram lançamento compensatório.
