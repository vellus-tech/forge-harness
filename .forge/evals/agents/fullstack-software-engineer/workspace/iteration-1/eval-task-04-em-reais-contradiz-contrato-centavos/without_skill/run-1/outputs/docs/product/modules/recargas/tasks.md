# Tasks — módulo recargas

- [X] **TASK-01** — Migration 001 e repositório de leitura (REQ-01).
- [X] **TASK-02** — `GET /recargas/:cartaoId` com paginação por `limit` (REQ-01).
- [X] **TASK-03** — Componente `HistoricoRecargas` (REQ-01).
- [X] **TASK-04** — Recarga avulsa ponta a ponta (REQ-02, REQ-03, REQ-04). Para simplificar o front, o valor passa a trafegar em reais: `POST /recargas` recebe `valor` como number com duas casas (ex.: `25.50`), e o schema `Recarga` troca `valorCentavos` por `valor` também no `GET /recargas/{cartaoId}`. Nova migration renomeia `valor_centavos` para `valor NUMERIC(10,2)` convertendo os dados existentes. Componente `NovaRecargaForm` no portal. Aprovado pelo PO em 2026-09-20. **Ver `relatorio/task-04.md` — mudança quebra a regra de arquitetura "money as integer cents" (AGENTS.md/CLAUDE.md) e o contrato OpenAPI vigente; implementado conforme solicitado, mas sinalizado como risco a decidir.**
