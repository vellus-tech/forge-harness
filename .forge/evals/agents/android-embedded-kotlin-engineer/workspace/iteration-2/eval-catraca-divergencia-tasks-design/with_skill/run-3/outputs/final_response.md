## Não implementei a TASK-03: há divergência entre `tasks.md` e o design aprovado

**Divergência.** A `tasks.md` do módulo catraca pede para liberar o giro acionando o GPIO do Telpo TPS508 (pino 3, pulso de 300 ms) pela API `TelpoGpioManager`, com confirmação pelo pino 5. O `design.md` (DD-002, aprovado em 2026-08-20) diz o oposto para a linha 8012: a catraca é a Gertec TC-400, controlada por RS-232 pelo `UsbSerialLink`, com frame `LIBERA_GIRO` e respostas `GIRO_CONSUMADO` ou `GIRO_EXPIRADO`. O mesmo design afirma que o TPS508 da 8012 não tem o chicote de GPIO instalado.

**Evidência.** `docs/vendor/gertec-tc400-serial.md` confirma o protocolo serial da Gertec. Nenhum SDK Telpo ou referência a `TelpoGpioManager` existe no projeto, e não tenho rede para baixá-lo.

**Decisão necessária.** Confirme qual mecanismo vale para a 8012: (a) Gertec serial conforme DD-002, ou (b) GPIO Telpo conforme a `tasks.md`. Se for (a), a `tasks.md` precisa ser corrigida antes da implementação. Se for (b), o DD-002 precisa ser revisado e o chicote de GPIO precisa existir na 8012.

**Recomendação técnica.** Seguir pela opção (a). O design é posterior, está aprovado e descreve o hardware instalado. Implementar GPIO na 8012 faria o piloto de segunda falhar na catraca real. Também recomendo cuidado com reenvio de `LIBERA_GIRO` sem resposta: o fabricante pede consulta de `STATUS` antes, para não liberar dois giros.

**Estado.** Nenhuma alteração no repositório. Não executei build nem testes, porque não há código novo a testar.
