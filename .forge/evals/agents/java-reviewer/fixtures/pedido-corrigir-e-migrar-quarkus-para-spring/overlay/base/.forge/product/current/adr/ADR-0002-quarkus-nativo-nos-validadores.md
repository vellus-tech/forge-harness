# ADR-0002 — Quarkus com imagem nativa nos validadores de embarque

Status: accepted. Data: 2025-11-04.

## Contexto

Os validadores rodam em gateways embarcados nos ônibus (ARM64, 512 MB de RAM) e precisam subir em menos de 200 ms após queda de energia.

## Decisão

O validador-embarque usa Quarkus com build nativo GraalVM e Maven. Spring Boot foi avaliado e descartado: footprint de memória e tempo de start acima do orçamento do gateway.

## Consequências

Trocar de framework exige nova ADR com medição de memória e start no hardware do gateway.
