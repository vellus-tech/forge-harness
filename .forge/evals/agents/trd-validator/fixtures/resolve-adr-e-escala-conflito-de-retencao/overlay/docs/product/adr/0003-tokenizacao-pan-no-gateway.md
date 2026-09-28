# ADR-0003 - Tokenização do PAN no gateway do adquirente

**Status:** Aceito · **Data:** 2026-06-16

## Decisão

O validador embarcado envia o PAN diretamente ao gateway do adquirente, que devolve um token. Os serviços Axis trabalham exclusivamente com o token; o ambiente Axis fica fora do CDE.
