# ADR-0002 — cadastro-passageiro e notificacoes no mesmo deployable

- Status: Aceito · 2026-09-12

## Contexto

Volume de cadastro e notificação é baixo (menos de 2 mil eventos/dia) e a mesma equipe mantém os dois módulos.

## Decisão

Empacotar cadastro-passageiro e notificacoes no deployable `backoffice-monolito`, mantendo cada módulo em pacote próprio, sem acesso cruzado a tabelas, com teste de arquitetura (ArchUnit) garantindo a fronteira. recarga e tarifacao continuam em deployables próprios.

## Consequências

Deploy conjunto dos dois módulos; separação futura exige apenas novo deployable, pois as fronteiras são mantidas.
