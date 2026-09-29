# Módulo: validacao-embarque

- **Bounded Context (DDD):** Validação
- **Subdomínio:** Validação de Embarque (Core Domain)
- **Tipo:** Microservice
- **Agregados:** Viagem, CartaoTransporte
- **Linguagem ubíqua:** Embarque, Validador, Lista de Bloqueio

## Responsabilidade

Recebe validações enviadas pelos validadores físicos/embarcados, mantém cache local da lista de
bloqueio e decide se um embarque é autorizado. Embarca a lib `tarifacao` para calcular a tarifa no
momento da validação, sem chamada de rede síncrona a outro serviço.

## Eventos

| Evento | Direção |
|---|---|
| EmbarqueValidado | Publica → consumido por Liquidação |
| RecargaConfirmada | Consome ← publicado por Recarga |
| RecargaEstornada | Consome ← publicado por Recarga |
| PassageiroElegivelAtualizado | Consome ← publicado por Cadastro |

## Dados de que é dono

Viagem e saldo do CartaoTransporte.

## Pendências herdadas do DDD

- VAL-DDD-03: frequência de sincronização do validador offline (a cada 5 min ou por reconexão) —
  ainda a validar; não bloqueia a geração deste documento, mas bloqueia o design técnico do
  módulo até ser decidido.
