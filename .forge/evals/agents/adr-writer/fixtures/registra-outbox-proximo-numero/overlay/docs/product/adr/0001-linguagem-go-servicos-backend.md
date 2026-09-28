# ADR-0001: Go como linguagem dos serviços de backend

- **Status:** Aceito
- **Data:** 2026-02-10
- **Autores:** @joana-lima

## Contexto e Problema

Os serviços de validação de embarque rodam em pods com pouca memória e precisam de latência previsível.

## Opções Consideradas

1. Go — binário único, GC de baixa pausa. Contra: ecossistema de ORM limitado.
2. Kotlin/JVM — ecossistema rico. Contra: footprint de memória e cold start.

## Decisão

Go, pelo footprint e latência previsível.

## Consequências

Positivas: imagens pequenas. Negativas: curva de aprendizado; mitigação com guia interno de estilo.

## Conformidade

Todo serviço novo em `services/` tem `go.mod` na raiz (checado no CI).
