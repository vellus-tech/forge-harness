---
story_id: STORY-03
epic: add-unified-knowledge-search
title: Camada semântica — pins, instalador, embeddings e re-rank
depends_on: [STORY-02]
status: in_progress
---

# STORY-03 — Camada semântica — pins, instalador, embeddings e re-rank

> Story auto-contida derivada de `add-unified-knowledge-search`. Ver também `../epic_context.md`.

## Goal

Entregar a camada semântica de verdade: pins (lockfile com integrity, modelos por revisão e sha256), devDependencies do workspace nas mesmas versões, instalador explícito, integridade a cada carga, carga confinada a `runtime/node_modules`, embeddings com cache de arquivo único, cross-encoder e degradação nos oito casos — com inferência real testada na suíte por modelos ONNX de fixture instalados pelo instalador de produção.

## Embedded context

### Requirements

- REQ-05: só `semantic install` acessa a rede; `npm ci --ignore-scripts`; varredura nativa (extensão e assinatura) na instalação e em cada carga; sha256 por modelo; `remove` apaga só `.forge/kb/semantic`; status confere versões, nativo e sha; carga só de `runtime/node_modules`; `installed.json` com `pins_sha256`; sem npm, erro claro; só https (ou loopback de teste); nenhum outro caminho instala.
- REQ-06: vetor por trecho distinto; segundo build não recalcula; cache incremental gravado a cada 200; inferência real em teste.
- REQ-07: re-rank dos K = 10 do ranking propagado, `--no-rerank`, inferência real do cross-encoder.
- REQ-08: oito casos degradados → lexical com motivo, exit 0.
- REQ-09 (semântico): bloqueio de rede no modo semântico (mode: semantic conferido) e nos oito degradados.
- REQ-11 (semântico): modos `semantic` e `semantic+rerank` do `kb.sh eval`.

### Design

> §2.6 (modelos, embeddings, re-rank, integridade, vectors.bin), §2.7 (instalação), §2.10 (fixture: cópia da maquinaria, `models.json` de fixture servido em 127.0.0.1, `npm` substituto no PATH).

## Tasks

- [X] TASK-06 — Pins, devDependencies e ADR 0004 (paths: `template/.forge/scripts/lib/kb-pins/`, `package.json`, `package-lock.json`, `.forge/product/current/adr/0004-opt-in-runtime-layer.md`, `.forge/product/current/adr/README.md`, `tests/w290-kb-pins-gate.sh`; depende: TASK-05)
- [X] TASK-07 — Instalação: integridade, instalador, `semantic install|status` (paths: `template/.forge/scripts/lib/kb-integrity.mjs`, `template/.forge/scripts/lib/kb-install.mjs`, `template/.forge/scripts/lib/kb-cli.mjs`, `tests/fixtures/kb/{make-semantic-fixture.mjs,fake-npm.sh,semantic-env.sh}`, `tests/w291-kb-install-gate.sh`; depende: TASK-05, TASK-06)
- [X] TASK-08 — Carga e inferência: `kb-semantic.mjs`, canal vetorial, re-rank, eval semântico, degradação, bloqueio de rede no modo semântico (paths: `template/.forge/scripts/lib/kb-semantic.mjs`, `template/.forge/scripts/lib/kb-cli.mjs`, `tests/w292-kb-semantic-gate.sh`, `tests/w293-kb-offline-semantic-gate.sh`; depende: TASK-07)

## Acceptance criteria

- [ ] `w290`, `w291`, `w292` e `w293` passam em Node 20 e 26; vermelho de cada task provado (TASK-07 e TASK-08 com `Setup do teste: npm ci ...`).
