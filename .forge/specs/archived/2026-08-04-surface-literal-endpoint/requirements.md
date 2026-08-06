# Requirements — surface-literal-endpoint

> O `LDG-0010` pedia a promoção do `SRF-01` a bloqueante assim que o oráculo de rota existisse. O oráculo existe; a medição mostrou que o obstáculo é outro.

## REQ-01 — Célula de superfície de API cita o endpoint

- **Quando** uma linha do Checklist declara superfície de API sem citar `VERB /path`, **o sistema deve** emitir `SRF-03` como aviso, nomeando o REQ.
- **Critérios de aceite:**
  - [ ] Célula em prosa que fala em endpoint/rota → achado.
  - [ ] Célula com `POST /api/v1/orders` → sem achado.
  - [ ] Célula mista (prosa + literal) → sem achado.
  - [ ] Superfície que não é de API (tela, CLI, flag de config) → sem achado.
  - [ ] Aviso, nunca bloqueio, nesta entrega.
- **Rastreia:** LDG-0010

## REQ-02 — A decisão sobre promover o SRF-01 fica registrada com números

- **Quando** alguém retomar o `LDG-0010`, **o sistema deve** oferecer a medição que sustenta (ou não) a promoção, e não a intuição de quem mediu antes.
- **Critérios de aceite:**
  - [ ] Ledger registra rotas resolvidas, irresolúveis por kind e por escopo, veredito do `SUR-01` e a classificação dos achados `SRF-01`.
  - [ ] O comando de tasks documenta o `SRF-03` e por que ele existe.
- **Rastreia:** LDG-0010

## Requisitos não funcionais

- **NFR-01 —** Nenhum check existente muda de classificação: `SRF-00`, `SRF-01` e `SRF-02` seguem como estão.
- **NFR-02 —** Zero-dep.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | — (check interno do validador) | — comportamento de `validate-spec` | TASK-02 |
| REQ-02 | — | — documentação e ledger | TASK-03 |

## Fora de escopo

- Promover o `SRF-01` a bloqueante — a medição não sustenta hoje.
- Reduzir a cegueira do scanner (83 irresolúveis), que é o outro pré-requisito.
