# ADR-0003: Criptografia de buckets com SSE-S3 (AES256)

- **Status:** Aceito
- **Data:** 2026-03-10
- **Decisores:** @carla-mendes (CTO), @rafael-souza (SRE)

## Contexto

Em fevereiro de 2026 o serviço de extratos atingiu throttling de KMS (`ThrottlingException` em `GenerateDataKey`) em pico de fechamento e a fatura de KMS passou do orçamento de infraestrutura. A equipe de SRE não tem hoje processo de rotação e auditoria de chaves gerenciadas pelo cliente.

## Decisão

Todo bucket do produto, inclusive os que guardam documento de cliente (comprovantes, extratos, faturas), usa criptografia padrão SSE-S3 (`sse_algorithm = "AES256"`). SSE-KMS (com ou sem Bucket Key) não é usado em bucket novo; exceção só por novo ADR que substitua este.

## Consequências

- Sem custo nem limite de requisição de KMS.
- Sem controle de acesso por política de chave nem crypto-shredding por chave; aceito pela diretoria em 2026-03-10.
