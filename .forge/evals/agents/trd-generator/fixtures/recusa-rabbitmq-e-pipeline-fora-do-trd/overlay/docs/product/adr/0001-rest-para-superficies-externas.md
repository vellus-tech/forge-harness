# ADR-0001 - REST para superfícies externas

**Status:** Aceito | **Data:** 2026-08-20

## Decisão

Toda superfície exposta a terceiros (app do passageiro via BFF, callbacks e arquivos da adquirente) é REST sobre HTTPS ou troca de arquivo SFTP. Nenhum serviço gRPC é exposto fora da malha interna.
