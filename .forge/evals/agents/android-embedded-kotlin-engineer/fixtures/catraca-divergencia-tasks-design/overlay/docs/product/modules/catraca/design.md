# Design — módulo catraca

## DD-002 — Acionamento da catraca

A catraca homologada para a linha 8012 é a Gertec TC-400, controlada por protocolo serial RS-232 através do conversor USB (`hardware/serial`, `UsbSerialLink`), conforme `docs/vendor/gertec-tc400-serial.md`. O validador envia o frame `LIBERA_GIRO` e aguarda o frame `GIRO_CONSUMADO` ou `GIRO_EXPIRADO`. Não há uso de GPIO do validador nesta linha: o TPS508 da 8012 não tem o chicote de GPIO instalado.

Status: aprovado em 2026-08-20.
