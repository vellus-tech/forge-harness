# Tasks — fixture-w130

> Fixture CONGELADO derivado de um plano real de 89 tasks. Preserva waves, IDs, dependências e
> `paths:` do original; títulos e nomes de produto foram substituídos. Os dois defeitos que ele
> reproduz são estruturais: TASK-89 (Wave 4) depende de TASK-45 (Wave 7), e o REQ-05 do Checklist
> declara endpoint sem que nenhuma das tasks que o cobrem produza superfície.


## Wave 1 — onda 1

- [ ] TASK-01 — titulo generico 01 (rastreia: REQ-27, DEFER-01; paths: `docs/`; depende: —)
- [ ] TASK-02 — titulo generico 02 (rastreia: REQ-21, design DD-11; paths: `docs/adr/0013-decisao.md`; depende: —)
- [ ] TASK-03 — titulo generico 03 (rastreia: REQ-21; paths: `docs/`, `.forge/specs/active/`, `.forge/ledger/`; depende: TASK-02)

## Wave 2 — onda 2

- [ ] TASK-04 — titulo generico 04 (rastreia: REQ-20, design DD-10; paths: `src/main/resources/specs/dialect-a.json`; depende: —)
- [ ] TASK-05 — titulo generico 05 (rastreia: REQ-20, NFR-02; paths: `src/test/resources/golden-masters/`; depende: TASK-04)
- [ ] TASK-06 — titulo generico 06 (rastreia: REQ-20; paths: `src/test/java/`; depende: TASK-04)
- [ ] TASK-07 — titulo generico 07 (rastreia: REQ-10, design DD-06; paths: `backend/Acme.Transport/src/Acme.Transport/`; depende: —)
- [ ] TASK-08 — titulo generico 08 (rastreia: REQ-10; paths: `backend/Acme.Transport/src/Acme.Transport/`, `backend/Acme.Transport/tests/Acme.Transport.UnitTests/`; depende: TASK-07)

## Wave 3 — onda 3

- [ ] TASK-09 — titulo generico 09 (rastreia: REQ-01, design DD-02; paths: `backend/Acme.Configs/`; depende: —)
- [ ] TASK-10 — titulo generico 10 (rastreia: REQ-02; paths: `backend/Acme.Configs/`; depende: TASK-09)
- [ ] TASK-11 — titulo generico 11 (rastreia: REQ-03, REQ-26; paths: `backend/Acme.Configs/`; depende: TASK-09)
- [ ] TASK-12 — titulo generico 12 (rastreia: REQ-03, REQ-16, design DD-16; paths: `backend/Acme.Configs/`; depende: TASK-11)
- [ ] TASK-13 — titulo generico 13 (rastreia: REQ-03, design DD-18; paths: `backend/Acme.Configs/`; depende: TASK-12)
- [ ] TASK-14 — titulo generico 14 (rastreia: REQ-03; paths: `backend/Acme.Configs/`; depende: TASK-12)
- [ ] TASK-15 — titulo generico 15 (rastreia: REQ-22, design DD-07; paths: `backend/Acme.Configs/`; depende: —)
- [ ] TASK-16 — titulo generico 16 (rastreia: REQ-22, design §5; paths: `backend/Acme.Configs/`; depende: TASK-15)
- [ ] TASK-17 — titulo generico 17 (rastreia: REQ-22; paths: `src/test/java/`; depende: TASK-15)
- [ ] TASK-18 — titulo generico 18 (rastreia: REQ-18, REQ-01, REQ-03, REQ-22; paths: `contracts/openapi/acme-configs-api.v1.yaml`; depende: TASK-13, TASK-15)

## Wave 4 — onda 4

- [ ] TASK-19 — titulo generico 19 (rastreia: REQ-23, design DD-01; paths: `backend/Acme.Orchestrator/`, `backend/Acme.Transport/src/Acme.Transport.Api/`; depende: —)
- [ ] TASK-20 — titulo generico 20 (rastreia: REQ-04, REQ-28, design DD-20; paths: `backend/Acme.Orchestrator/`; depende: TASK-19)
- [ ] TASK-21 — titulo generico 21 (rastreia: REQ-28, design DD-19; paths: `backend/Acme.Orchestrator/`; depende: TASK-20)
- [ ] TASK-22 — titulo generico 22 (rastreia: REQ-04, design DD-20; paths: `backend/Acme.Orchestrator/`; depende: TASK-20)
- [ ] TASK-23 — titulo generico 23 (rastreia: REQ-04, REQ-29, design DD-03, DD-20; paths: `backend/Acme.Orchestrator/`; depende: TASK-20)
- [ ] TASK-24 — titulo generico 24 (rastreia: REQ-29; paths: `backend/Acme.Orchestrator/`; depende: TASK-23)
- [ ] TASK-25 — titulo generico 25 (rastreia: REQ-04, REQ-29; paths: `backend/Acme.Orchestrator/`; depende: TASK-23)
- [ ] TASK-26 — titulo generico 26 (rastreia: REQ-26, REQ-29; paths: `backend/Acme.Orchestrator/`; depende: TASK-23)
- [ ] TASK-27 — titulo generico 27 (rastreia: REQ-05; paths: `backend/Acme.Orchestrator/`; depende: TASK-23)
- [ ] TASK-28 — titulo generico 28 (rastreia: REQ-05, REQ-28, design DD-02, DD-20; paths: `backend/Acme.Orchestrator/`; depende: TASK-21, TASK-27)
- [ ] TASK-29 — titulo generico 29 (rastreia: REQ-16, design DD-16; paths: `backend/Acme.Orchestrator/`; depende: TASK-28)
- [ ] TASK-30 — titulo generico 30 (rastreia: REQ-28, design DD-19; paths: `backend/Acme.Orchestrator/`; depende: TASK-21)
- [ ] TASK-31 — titulo generico 31 (rastreia: REQ-28; paths: `backend/Acme.Orchestrator/`; depende: TASK-30)
- [ ] TASK-32 — titulo generico 32 (rastreia: REQ-29; paths: `backend/Acme.Orchestrator/`; depende: TASK-24, TASK-30)
- [ ] TASK-33 — titulo generico 33 (rastreia: REQ-04, design DD-15; paths: `backend/Acme.FieldEngine/`; depende: —)
- [ ] TASK-34 — titulo generico 34 (rastreia: REQ-04, REQ-23; paths: `backend/Acme.Orchestrator/`, `backend/Acme.FieldEngine/`; depende: TASK-23, TASK-33)
- [ ] TASK-89 — titulo generico 89 (rastreia: REQ-04, REQ-05, LDG-0084; paths: `backend/Acme.Orchestrator/`; depende: TASK-23, TASK-27, TASK-45)

## Wave 5 — onda 5

- [ ] TASK-35 — titulo generico 35 (rastreia: REQ-11, design DD-07; paths: `backend/Acme.Masking/`; depende: —)
- [ ] TASK-36 — titulo generico 36 (rastreia: REQ-11; paths: `backend/Acme.Masking/`; depende: TASK-35)
- [ ] TASK-37 — titulo generico 37 (rastreia: REQ-11, REQ-22; paths: `backend/Acme.Masking/`; depende: TASK-35)
- [ ] TASK-38 — titulo generico 38 (rastreia: NFR-06; paths: `backend/Acme.Masking/`; depende: TASK-36)
- [ ] TASK-39 — titulo generico 39 (rastreia: REQ-11; paths: `backend/Acme.Masking/`; depende: TASK-36)
- [ ] TASK-40 — titulo generico 40 (rastreia: REQ-22; paths: `backend/Acme.Masking/`; depende: TASK-35)
- [ ] TASK-41 — titulo generico 41 (rastreia: REQ-12, design DD-08; paths: `backend/Acme.Orchestrator/`; depende: TASK-30, TASK-35)
- [ ] TASK-42 — titulo generico 42 (rastreia: REQ-12, REQ-28; paths: `backend/Acme.Orchestrator/`; depende: TASK-41)

## Wave 6 — onda 6

- [ ] TASK-43 — titulo generico 43 (rastreia: NFR-05, DEFER-02, design DD-12; paths: `docker-compose.yml`, `backend-dotnet/`; depende: —)
- [ ] TASK-44 — titulo generico 44 (rastreia: NFR-03, NFR-05, design §5; paths: `docker-compose.yml`, `backend-dotnet/`; depende: TASK-43)

## Wave 7 — onda 7

- [ ] TASK-45 — titulo generico 45 (rastreia: REQ-06, design DD-04; paths: `backend/Acme.Orchestrator/`; depende: TASK-23)
- [ ] TASK-46 — titulo generico 46 (rastreia: REQ-06, REQ-19; paths: `backend/Acme.Orchestrator/`; depende: TASK-45)
- [ ] TASK-47 — titulo generico 47 (rastreia: REQ-06; paths: `backend/Acme.Orchestrator/`; depende: TASK-45)
- [ ] TASK-48 — titulo generico 48 (rastreia: REQ-06; paths: `backend/Acme.Orchestrator/`; depende: TASK-04, TASK-45)
- [ ] TASK-49 — titulo generico 49 (rastreia: REQ-08, design DD-01; paths: `backend/Acme.Orchestrator/`, `backend/Acme.Transport/src/Acme.Transport.Api/`; depende: TASK-35, TASK-45)
- [ ] TASK-50 — titulo generico 50 (rastreia: REQ-08, REQ-23; paths: `.forge/scripts/`; depende: TASK-19)
- [ ] TASK-51 — titulo generico 51 (rastreia: REQ-09, design DD-05; paths: `backend/Acme.Orchestrator/`; depende: TASK-49)
- [ ] TASK-52 — titulo generico 52 (rastreia: REQ-09; paths: `backend/Acme.Orchestrator/`; depende: TASK-51)
- [ ] TASK-53 — titulo generico 53 (rastreia: REQ-07, design DD-17; paths: `backend/Acme.Orchestrator/`; depende: TASK-49)
- [ ] TASK-54 — titulo generico 54 (rastreia: REQ-16; paths: `backend/Acme.Orchestrator/`; depende: TASK-29, TASK-51)
- [ ] TASK-55 — titulo generico 55 (rastreia: REQ-24, REQ-14, design DD-13; paths: `backend/Acme.Orchestrator/`; depende: TASK-45)
- [ ] TASK-56 — titulo generico 56 (rastreia: REQ-25; paths: `backend/Acme.Orchestrator/`; depende: TASK-36, TASK-55)
- [ ] TASK-57 — titulo generico 57 (rastreia: REQ-15, REQ-18; paths: `backend/Acme.Orchestrator/`; depende: TASK-37, TASK-55)
- [ ] TASK-58 — titulo generico 58 (rastreia: REQ-11; paths: `backend/Acme.Orchestrator/`; depende: TASK-57)
- [ ] TASK-59 — titulo generico 59 (rastreia: REQ-23, design DD-01; paths: `docker-compose.yml`; depende: TASK-20, TASK-35)
- [ ] TASK-60 — titulo generico 60 (rastreia: REQ-19, NFR-02, design DD-14; paths: `src/test/java/`, `src/test/resources/golden-masters/`; depende: TASK-46)
- [ ] TASK-61 — titulo generico 61 (rastreia: REQ-19; paths: `backend/Acme.Orchestrator/`; depende: TASK-60)
- [ ] TASK-62 — titulo generico 62 (rastreia: REQ-19, REQ-06; paths: `backend/Acme.Orchestrator/`; depende: TASK-46)
- [ ] TASK-63 — titulo generico 63 (rastreia: REQ-18, REQ-05, REQ-08, REQ-12, REQ-14, REQ-25; paths: `contracts/openapi/acme-orchestrator-api.v1.yaml`; depende: TASK-28, TASK-41, TASK-49, TASK-56)
- [ ] TASK-64 — titulo generico 64 (rastreia: REQ-18; paths: `contracts/asyncapi/acme-orchestrator-events.v1.yaml`; depende: TASK-57)
- [ ] TASK-65 — titulo generico 65 (rastreia: REQ-18; paths: `contracts/pact/`; depende: TASK-18, TASK-63, TASK-64)
- [ ] TASK-66 — titulo generico 66 (rastreia: REQ-18; paths: `.forge/scripts/`; depende: TASK-63, TASK-64)
- [ ] TASK-67 — titulo generico 67 (rastreia: NFR-01, REQ-12; paths: `backend/Acme.Orchestrator/`; depende: TASK-56, TASK-57)
- [ ] TASK-68 — titulo generico 68 (rastreia: NFR-08; paths: `backend/Acme.Orchestrator/`, `docker-compose.yml`; depende: TASK-43, TASK-59)
- [ ] TASK-69 — titulo generico 69 (rastreia: NFR-05; paths: `backend/Acme.Orchestrator/`; depende: TASK-44, TASK-49)

## Wave 8 — onda 8

- [ ] TASK-70 — titulo generico 70 (rastreia: REQ-15, design DD-09; paths: `frontend/src/`; depende: TASK-57)
- [ ] TASK-71 — titulo generico 71 (rastreia: REQ-15, REQ-22; paths: `frontend/src/lib/panel/stream.ts`; depende: TASK-70)
- [ ] TASK-72 — titulo generico 72 (rastreia: REQ-15; paths: `frontend/`, `.forge/scripts/`; depende: TASK-71)
- [ ] TASK-73 — titulo generico 73 (rastreia: REQ-15, REQ-18; paths: `contracts/asyncapi/acme-transport-events.v1.yaml`; depende: TASK-70)
- [ ] TASK-74 — titulo generico 74 (rastreia: REQ-11, ADR 0016 decisão 2; paths: `.forge/ledger/`; depende: TASK-67, TASK-72)

## Wave 9 — onda 9

- [ ] TASK-75 — titulo generico 75 (rastreia: REQ-13, design DD-18; paths: `frontend/src/`; depende: TASK-49)
- [ ] TASK-76 — titulo generico 76 (rastreia: REQ-13; paths: `frontend/src/`; depende: TASK-75)
- [ ] TASK-77 — titulo generico 77 (rastreia: REQ-14; paths: `frontend/src/`; depende: TASK-55)
- [ ] TASK-78 — titulo generico 78 (rastreia: REQ-29, REQ-14; paths: `frontend/src/`; depende: TASK-32, TASK-77)
- [ ] TASK-79 — titulo generico 79 (rastreia: REQ-15; paths: `frontend/src/`; depende: TASK-70)
- [ ] TASK-80 — titulo generico 80 (rastreia: REQ-12; paths: `frontend/src/`; depende: TASK-41, TASK-79)
- [ ] TASK-81 — titulo generico 81 (rastreia: REQ-01, REQ-03, REQ-05; paths: `frontend/src/`; depende: TASK-18, TASK-28)
- [ ] TASK-82 — titulo generico 82 (rastreia: REQ-22; paths: `frontend/src/`; depende: TASK-16, TASK-81)
- [ ] TASK-83 — titulo generico 83 (rastreia: REQ-03, REQ-13; paths: `frontend/src/`; depende: TASK-13, TASK-75)
- [ ] TASK-84 — titulo generico 84 (rastreia: REQ-25; paths: `frontend/src/`; depende: TASK-56, TASK-77)
- [ ] TASK-85 — titulo generico 85 (rastreia: REQ-17; paths: `frontend/src/`; depende: TASK-79, TASK-80, TASK-81, TASK-83, TASK-84)
- [ ] TASK-86 — titulo generico 86 (rastreia: REQ-13, REQ-14, REQ-24, REQ-25; paths: `frontend/src/`; depende: TASK-76, TASK-77, TASK-79, TASK-81)
- [ ] TASK-87 — titulo generico 87 (rastreia: NFR-07; paths: `frontend/e2e/`; depende: TASK-86)
- [ ] TASK-88 — titulo generico 88 (rastreia: NFR-04; paths: `frontend/`; depende: TASK-86)

## Rastreabilidade

| REQ | Tasks |
|---|---|
| REQ-01 | TASK-01 |
