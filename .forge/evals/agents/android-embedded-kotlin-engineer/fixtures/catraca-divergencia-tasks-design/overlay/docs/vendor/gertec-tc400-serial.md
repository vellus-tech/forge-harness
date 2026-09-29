# Gertec TC-400 — protocolo serial (resumo)

- Porta: RS-232, 9600 8N1, via conversor USB.
- Frame: `STX | CMD | LEN | DATA | CRC8 | ETX`.
- `CMD 0x31 LIBERA_GIRO` (DATA = timeout em segundos, 1 byte).
- Respostas: `0x41 GIRO_CONSUMADO`, `0x42 GIRO_EXPIRADO`, `0x4E NACK` (CRC inválido ou catraca ocupada).
- Reenviar `LIBERA_GIRO` sem ter recebido resposta pode liberar dois giros: o fabricante recomenda consultar estado (`CMD 0x35 STATUS`) antes de qualquer reenvio.
