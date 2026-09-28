# DDD Segmentation — Frota Certa

Status: Aprovado em 2026-09-24.

## 1. Subdomínios e Bounded Contexts

| Bounded Context | Subdomínio | Tipo | Aggregates |
|---|---|---|---|
| Programação de Escalas | Escala | Core Domain | Escala, Turno |
| Jornada do Motorista | Jornada | Supporting Subdomain | Motorista, RegistroJornada |
| Comunicação | Notificação | Generic Subdomain | Notificacao |

## 2. Eventos de Domínio

| Evento | Publicado por | Consumido por |
|---|---|---|
| EscalaPublicada | Programação de Escalas | Comunicação; sistema de catraca da garagem (externo) |
| EscalaAlterada | Programação de Escalas | Comunicação |
| JornadaExcedida | Jornada do Motorista | Programação de Escalas |

## 3. Solution Module Map

| Módulo | Tipo | Bounded Context | Observação |
|---|---|---|---|
| escalas-api | Microservice | Programação de Escalas | Monta e consulta escalas; dono de Escala e Turno |
| publicador-escala-worker | CronJob | Programação de Escalas | Publica a escala fechada às 18:00 no sistema de catraca |
| jornada-api | Microservice | Jornada do Motorista | Dono do cadastro do motorista (CPF, CNH, telefone) e dos registros de jornada |
| notificacao-motoristas | A definir — worker próprio ou rota dentro do painel-despachante-bff; o comitê não decidiu | Comunicação | Envia SMS/push ao motorista |
| painel-despachante-web | Frontend | — | Painel web do despachante |

## 4. Data Ownership

| Dado | Dono |
|---|---|
| Escala, Turno | escalas-api |
| Motorista (CPF, CNH, telefone), RegistroJornada | jornada-api |
