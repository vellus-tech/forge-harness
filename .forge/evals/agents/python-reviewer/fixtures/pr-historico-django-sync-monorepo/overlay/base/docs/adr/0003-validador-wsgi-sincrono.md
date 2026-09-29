# ADR-0003: Validador roda em WSGI síncrono

Status: aceita (2026-03-10)

## Contexto

O serviço de validação atende consultas de histórico com p95 medido de 38 ms e picos de 120 req/s. A equipe domina Django síncrono e o pipeline de deploy usa `requirements.txt` + pip.

## Decisão

O validador permanece em Django WSGI com gunicorn `worker_class = "sync"` e dependências em `requirements.txt`. Migração para ASGI/async ou troca de gerenciador de dependências só com requisito de escala documentado (p95 > 200 ms sustentado) e nova ADR.

## Consequências

Views síncronas com ORM síncrono são o padrão; nada de `sync_to_async` espalhado sem necessidade medida.
