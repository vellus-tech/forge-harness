# Requirements — route-scan-dialect-coverage

> Quatro lacunas levantadas na revisão do `w132` e deliberadamente não fechadas na época, porque nenhuma produz path inventado — todas produzem ausência ou ruído. Ausência, porém, deixa o cruzamento verde por vacuidade, e ruído treina a pessoa a ignorar o relatório.

## REQ-01 — Tabela de policy ancorada, com degrade anunciado

- **Quando** o `requirements.md` tem o heading `## Mapa endpoint → ação → recurso → policy`, **o sistema deve** ler apenas as tabelas dessa seção; **quando** não tem, **deve** varrer amplamente e reportar `policy-table-unanchored`.
- **Critérios de aceite:**
  - [ ] Tabela de "APIs de terceiros consumidas" fora da seção não entra na superfície declarada.
  - [ ] Spec sem o heading continua tendo sua superfície lida (nenhuma regressão), com o aviso.
- **Rastreia:** LDG-0018 (3)

## REQ-02 — Caixa do `[controller]` não é endpoint ausente

- **Quando** `[Route("api/[controller]")]` é resolvido, **o sistema deve** rebaixar o token para minúsculo.
- **Critérios de aceite:**
  - [ ] `OrdersController` → `/api/orders`.
  - [ ] O resto do literal preserva a caixa (`api/V2/[controller]` mantém `V2`).
  - [ ] Spring e Express preservam a caixa integralmente.
- **Rastreia:** LDG-0018 (1)
- **Notas:** o case-fold é do indexador .NET; fazê-lo no `normalizePath` faria dois endpoints distintos colidirem em dialeto case-sensitive.

## REQ-03 — `.py` e `.go` têm indexador

- **Quando** um arquivo `.py` ou `.go` é lido, **o sistema deve** extrair as rotas dos frameworks dominantes.
- **Critérios de aceite:**
  - [ ] FastAPI com `APIRouter(prefix=...)` compõe; sem prefixo conhecido, reporta e não emite parcial.
  - [ ] Flask lê `methods=[...]` e assume `GET` quando ausente (o default do framework).
  - [ ] chi/gorilla por verbo (`r.Get`) emitem; `HandleFunc` sem `.Methods()` vira `route-verb-unknown`.
- **Rastreia:** LDG-0018 (2)

## REQ-04 — Nest com múltiplos controllers

- **Quando** um arquivo tem mais de um `@Controller`, **o sistema deve** aplicar o prefixo de cada um às rotas da própria classe.
- **Critérios de aceite:**
  - [ ] Segundo controller não herda o prefixo do primeiro.
  - [ ] `@Controller` não literal é reportado e não emite rota.
- **Rastreia:** LDG-0018 (4)

## Requisitos não funcionais

- **NFR-01 —** Nenhuma recusa afrouxada: path parcial segue não emitido, interpolação recusada, ambiguidade reportada.
- **NFR-02 —** Zero-dep e determinístico.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície | Coberto por task |
|---|---|---|---|
| REQ-01..04 | — (motor interno) | `lib/route-scan.mjs` e `lib/api-surface.mjs`, consumidos por `SUR-01`/`SUR-02` | TASK-01..04 |

## Fora de escopo

- Alias de `using` e `ImplicitUsings` do `.csproj` (herdado do change anterior).
- Blueprint do Flask e `mux.Handle` com handler struct.
