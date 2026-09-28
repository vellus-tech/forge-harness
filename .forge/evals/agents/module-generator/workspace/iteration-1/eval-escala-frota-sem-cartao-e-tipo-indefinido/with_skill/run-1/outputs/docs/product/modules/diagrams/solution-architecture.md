# Solution Architecture Diagram

## 1. Objetivo

Mostrar como os módulos do Frota Certa se relacionam em alto nível.

## 2. Diagrama

```mermaid
flowchart TB
    subgraph External["Atores e Sistemas Externos"]
        Despachante[Despachante]
        Motorista[Motorista]
        Catraca[Sistema de Catraca da Garagem]
        SmsProvider[Provedor de SMS ou Push]
    end

    subgraph Edge["Camada de Apresentacao"]
        Painel[painel-despachante-web]
    end

    subgraph Application["Modulos de Aplicacao"]
        EscalasApi[escalas-api]
        Publicador[publicador-escala-worker]
        JornadaApi[jornada-api]
        Notificacao["notificacao-motoristas (tipo a definir)"]
    end

    subgraph Data["Camada de Dados"]
        EscalaDb[(Escala e Turno)]
        MotoristaDb[(Motorista e RegistroJornada)]
        Broker[Event Broker]
    end

    Despachante --> Painel
    Painel --> EscalasApi
    EscalasApi --> EscalaDb
    EscalasApi -->|JornadaExcedida| Broker
    Broker --> JornadaApi
    JornadaApi --> MotoristaDb
    JornadaApi -->|JornadaExcedida| Broker
    Broker --> EscalasApi
    EscalasApi -->|EscalaAlterada| Broker
    Broker --> Notificacao
    Publicador --> EscalasApi
    Publicador --> Catraca
    Publicador -->|EscalaPublicada| Broker
    Notificacao --> JornadaApi
    Notificacao --> SmsProvider
    SmsProvider --> Motorista
```

## 3. Observações

- `notificacao-motoristas` está desenhado como módulo de aplicação separado por ser assim que o Solution Module Map do DDD o lista, mas seu tipo final (worker próprio ou rota dentro de um BFF do painel) é um Ponto a Validar explícito (VAL-MOD-01) — não deve ser interpretado como decisão tomada.
- Não há Context Map ou Data Model nesta base; a separação de bancos de dados (Escala/Turno vs. Motorista/RegistroJornada) segue a Data Ownership do DDD Segmentation, não uma decisão de infraestrutura confirmada.
- O produto não possui zona de escopo PCI DSS (NFR-03) — não há subgrafo de CDE neste diagrama.
